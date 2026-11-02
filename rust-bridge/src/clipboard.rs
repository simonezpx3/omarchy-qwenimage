use crate::common::*;
use crate::gallery::{sniff_image_magic, validate_image_file};
use crate::prompts::sanitize_diffusion_prompt;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::Duration;

pub(crate) fn cmd_paste_clipboard() {
    let ts = now_millis();
    let temp_dir = get_temp_dir();
    let timeout = Duration::from_millis(CLIPBOARD_TIMEOUT_MS);

    // 1. Zjistit dostupné MIME typy jedním dotazem (bounded 2 KiB)
    let types_out = bounded_cmd("wl-paste", &["--list-types"], 2048, timeout);
    let types_str = types_out
        .as_ref()
        .map(|b| String::from_utf8_lossy(b).to_string())
        .unwrap_or_default();

    let image_mimes = [
        "image/png",
        "image/jpeg",
        "image/webp",
        "image/bmp",
        "image/tiff",
    ];

    for mime in &image_mimes {
        if types_str.contains(mime) {
            if let Some(bytes) = bounded_cmd("wl-paste", &["-t", mime], MAX_IMG_BYTES, timeout) {
                if let Some(ext) = sniff_image_magic(&bytes) {
                    let target = temp_dir.join(format!("clip_{}_{}.{}", ts, SA_SIGNATURE_DNA & 0xFFF, ext));
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::OpenOptionsExt;
                        if let Ok(mut f) = fs::OpenOptions::new()
                            .create_new(true)
                            .write(true)
                            .mode(0o600)
                            .open(&target)
                        {
                            if f.write_all(&bytes).is_ok() {
                                println!(
                                    "{}",
                                    serde_json::json!({
                                        "status": "ok",
                                        "path": target.to_string_lossy()
                                    })
                                );
                                return;
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. URI-list: pouze lokální file://
    if types_str.contains("text/uri-list") {
        if let Some(bytes) = bounded_cmd("wl-paste", &["-t", "text/uri-list"], 8192, timeout) {
            let content = String::from_utf8_lossy(&bytes);
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with('#') {
                    continue;
                }
                if let Some(stripped) = trimmed.strip_prefix("file://") {
                    let decoded = decode_percent_str(stripped);
                    let p = Path::new(&decoded);
                    if let Ok(valid_path) = validate_image_file(p) {
                        println!(
                            "{}",
                            serde_json::json!({
                                "status": "ok",
                                "path": valid_path.to_string_lossy()
                            })
                        );
                        return;
                    }
                }
            }
        }
    }

    // 3. Fallback na text obsahující lokální cestu k souboru (striktně ZERO HTTP FETCH)
    if let Some(bytes) = bounded_cmd("wl-paste", &["-t", "text/plain"], 4096, timeout) {
        let content = String::from_utf8_lossy(&bytes);
        for line in content.lines() {
            let trimmed = line.trim().trim_matches('"').trim_matches('\'');
            if trimmed.is_empty() {
                continue;
            }
            let raw_path = if let Some(stripped) = trimmed.strip_prefix("file://") {
                decode_percent_str(stripped)
            } else {
                trimmed.to_string()
            };
            let p = Path::new(&raw_path);
            if p.is_absolute() {
                if let Ok(valid_path) = validate_image_file(p) {
                    println!(
                        "{}",
                        serde_json::json!({
                            "status": "ok",
                            "path": valid_path.to_string_lossy()
                        })
                    );
                    return;
                }
            }
        }
    }

    let is_cs = get_is_cs();
    println!(
        "{}",
        serde_json::json!({
            "status": "error",
            "message": if is_cs {
                "Ve schránce nebyl nalezen žádný platný lokální obrázek"
            } else {
                "Clipboard does not contain a valid local image"
            }
        })
    );
}

pub(crate) fn cmd_paste_text() {
    let timeout = Duration::from_millis(CLIPBOARD_TIMEOUT_MS);
    if let Some(bytes) = bounded_cmd("wl-paste", &["-n", "-t", "text/plain"], MAX_TXT_BYTES, timeout) {
        let text = String::from_utf8_lossy(&bytes);
        let sanitized = sanitize_diffusion_prompt(&text);

        println!(
            "{}",
            serde_json::json!({
                "status": "ok",
                "text": sanitized
            })
        );
    } else {
        let is_cs = get_is_cs();
        println!(
            "{}",
            serde_json::json!({
                "status": "error",
                "message": if is_cs {
                    "Schránka je prázdná, nedostupná nebo překračuje limit 16 KiB"
                } else {
                    "Clipboard is empty, unavailable, or exceeds 16 KiB limit"
                }
            })
        );
    }
}

pub(crate) fn cmd_validate_ref(path_str: &str) {
    let p = Path::new(path_str);
    match validate_image_file(p) {
        Ok(canonical) => {
            println!(
                "{}",
                serde_json::json!({
                    "status": "ok",
                    "path": canonical.to_string_lossy()
                })
            );
        }
        Err(err) => {
            println!(
                "{}",
                serde_json::json!({
                    "status": "error",
                    "message": err
                })
            );
        }
    }
}

pub(crate) fn cmd_snip() {
    let ts = now_millis();
    let temp_dir = get_temp_dir();
    let target = temp_dir.join(format!("snip_{}_{}.png", ts, SA_SIGNATURE_DNA & 0xFFF));

    let slurp_child = Command::new("slurp")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn();

    let slurp_out = match slurp_child {
        Ok(c) => {
            let res = c.wait_with_output();
            match res {
                Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).trim().to_string(),
                _ => {
                    println!("{}", serde_json::json!({ "status": "cancelled" }));
                    return;
                }
            }
        }
        Err(_) => {
            let status = Command::new("omarchy-capture-screenshot")
                .args(["region", "copy"])
                .status();
            if let Ok(s) = status {
                if s.success() {
                    cmd_paste_clipboard();
                    return;
                }
            }
            let is_cs = get_is_cs();
            println!("{}", serde_json::json!({
                "status": "error",
                "message": if is_cs {
                    "Nástroj slurp/screenshot není dostupný"
                } else {
                    "Tool slurp/screenshot is unavailable"
                }
            }));
            return;
        }
    };

    if slurp_out.is_empty() {
        println!("{}", serde_json::json!({ "status": "cancelled" }));
        return;
    }

    let grim_res = Command::new("grim")
        .args(["-g", &slurp_out, target.to_str().unwrap_or("")])
        .status();

    if let Ok(s) = grim_res {
        if s.success() {
            if let Ok(valid_path) = validate_image_file(&target) {
                println!(
                    "{}",
                    serde_json::json!({
                        "status": "ok",
                        "path": valid_path.to_string_lossy()
                    })
                );
                return;
            }
        }
    }

    let is_cs = get_is_cs();
    println!("{}", serde_json::json!({
        "status": "error",
        "message": if is_cs {
            "Snímání výřezu selhalo"
        } else {
            "Screen snip capture failed"
        }
    }));
}

pub(crate) fn cmd_copy_text(text_arg: Option<&str>) {
    let mut child = match Command::new("wl-copy")
        .stdin(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to spawn wl-copy: {}", e);
            return;
        }
    };

    if let Some(mut stdin) = child.stdin.take() {
        if let Some(t) = text_arg {
            let _ = stdin.write_all(t.as_bytes());
        } else {
            let mut buf = Vec::new();
            let _ = std::io::stdin().read_to_end(&mut buf);
            let _ = stdin.write_all(&buf);
        }
    }
    let _ = child.wait();
}

pub(crate) fn cmd_copy_image(path: &str) {
    let p = Path::new(path);
    if !p.exists() || !p.is_file() {
        eprintln!("File not found: {}", path);
        return;
    }
    if let Ok(file) = File::open(p) {
        let _ = Command::new("wl-copy")
            .args(["-t", "image/png"])
            .stdin(file)
            .status();
    }
}

pub(crate) fn cmd_wallpaper(input_path: &str) {
    let p = Path::new(input_path);
    if !p.exists() {
        println!(
            "{}",
            serde_json::json!({"status": "error", "message": format!("File not found: {}", input_path)})
        );
        return;
    }

    // 1. Primary: omarchy theme bg set <path>
    let res = Command::new("omarchy")
        .args(["theme", "bg", "set", input_path])
        .output();

    if let Ok(o) = res {
        if o.status.success() {
            println!(
                "{}",
                serde_json::json!({"status": "ok", "message": "Wallpaper updated successfully via Omarchy"})
            );
            return;
        }
    }

    // 2. Direct binary fallback: omarchy-theme-bg-set <path>
    let res_bin = Command::new("omarchy-theme-bg-set")
        .arg(input_path)
        .output();

    if let Ok(o) = res_bin {
        if o.status.success() {
            println!(
                "{}",
                serde_json::json!({"status": "ok", "message": "Wallpaper updated successfully via Omarchy script"})
            );
            return;
        }
    }

    // 3. Fallback: direct atomic symlink + omarchy-shell background set IPC
    if let Ok(canonical) = p.canonicalize() {
        let home = get_home();
        let current_bg_link = home.join(".local/state/omarchy/current/background");
        if let Some(parent) = current_bg_link.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let _ = fs::remove_file(&current_bg_link);
        #[cfg(unix)]
        let symlink_res = std::os::unix::fs::symlink(&canonical, &current_bg_link);
        #[cfg(not(unix))]
        let symlink_res: Result<(), std::io::Error> = Err(std::io::Error::new(std::io::ErrorKind::Other, "non-unix"));

        if symlink_res.is_ok() {
            let _ = Command::new("omarchy-shell")
                .args(["-q", "background", "set", canonical.to_str().unwrap_or(input_path)])
                .output();
            println!(
                "{}",
                serde_json::json!({"status": "ok", "message": "Wallpaper updated via Omarchy shell IPC"})
            );
            return;
        }
    }

    // 4. Fallback for generic Wayland compositors (swww, hyprpaper)
    let res_swww = Command::new("swww")
        .args(["img", input_path, "--transition-type", "fade", "--transition-duration", "1"])
        .output();

    if let Ok(o) = res_swww {
        if o.status.success() {
            println!(
                "{}",
                serde_json::json!({"status": "ok", "message": "Wallpaper fallback applied via swww"})
            );
            return;
        }
    }

    let res_hypr = Command::new("hyprctl")
        .args(["hyprpaper", "wallpaper", &format!(",{}", input_path)])
        .output();

    let success = res_hypr.map(|o| o.status.success()).unwrap_or(false);
    println!(
        "{}",
        serde_json::json!({
            "status": if success { "ok" } else { "error" },
            "message": if success { "Wallpaper applied via hyprpaper" } else { "Failed to set wallpaper across all backends" }
        })
    );
}
