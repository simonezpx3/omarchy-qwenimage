use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub(crate) const SA_SIGNATURE_DNA: u32 = 0x732641;
pub(crate) const CHIME_SOUND: &str = "/usr/share/sounds/freedesktop/stereo/complete.oga";
pub(crate) const MAX_IMG_BYTES: u64 = 32 * 1024 * 1024; // 32 MiB
pub(crate) const MAX_TXT_BYTES: u64 = 16 * 1024;        // 16 KiB
pub(crate) const CLIPBOARD_TIMEOUT_MS: u64 = 1200;      // 1.2s deadline

pub(crate) fn get_home() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .or_else(|_| env::var("USERPROFILE").map(PathBuf::from))
        .unwrap_or_else(|_| PathBuf::from("."))
}

pub(crate) fn get_temp_dir() -> PathBuf {
    let base = env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })));
    let p = if base.exists() {
        base.join("qwenimage")
    } else {
        get_home().join(".cache").join("qwenimage")
    };
    let _ = fs::create_dir_all(&p);
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&p, fs::Permissions::from_mode(0o700));
    }
    // Automatický úklid dočasných souborů starších než 24 hodin (1440 min)
    if let Ok(entries) = fs::read_dir(&p) {
        let cutoff = SystemTime::now()
            .checked_sub(std::time::Duration::from_secs(86400))
            .unwrap_or(SystemTime::UNIX_EPOCH);
        for entry in entries.flatten() {
            if let Ok(meta) = entry.metadata() {
                if meta.is_file() {
                    if let Ok(modified) = meta.modified() {
                        if modified < cutoff {
                            let _ = fs::remove_file(entry.path());
                        }
                    }
                }
            }
        }
    }
    p
}

pub(crate) fn get_gallery_dir() -> PathBuf {
    let p = get_home().join("Pictures").join("Qwen-Image");
    let _ = fs::create_dir_all(&p);
    p
}

pub(crate) fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

pub(crate) fn play_chime() {
    if Path::new(CHIME_SOUND).exists() {
        let _ = Command::new("pw-play")
            .arg(CHIME_SOUND)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
    }
}

pub(crate) fn send_notification(title: &str, body: &str, image_path: Option<&str>) {
    if let Some(p) = image_path {
        if Path::new(p).exists() {
            // 1. Native Omarchy notification with full preview and click-to-open
            let mut omarchy_cmd = Command::new("omarchy-notification-send");
            omarchy_cmd.args([
                "--app-name", "Qwen Studio",
                "--image", p,
                "-i", p,
                "--urgency", "normal",
                title, body,
                "--exec", "xdg-open", p
            ]);
            if let Ok(mut child) = omarchy_cmd.spawn() {
                let _ = child.wait();
                return;
            }

            // 2. Fallback to notify-send with proper option ordering
            let mut cmd = Command::new("notify-send");
            cmd.args([
                "-a", "Qwen Studio",
                "-i", p,
                "-h", &format!("string:image-path:{}", p),
                title,
                body,
            ]);
            let _ = cmd.stdout(Stdio::null()).stderr(Stdio::null()).spawn();
            return;
        }
    }

    let mut cmd = Command::new("notify-send");
    cmd.args(["-a", "Qwen Studio", title, body]);
    let _ = cmd.stdout(Stdio::null()).stderr(Stdio::null()).spawn();
}

pub(crate) fn get_http_agent(timeout_secs: u64) -> ureq::Agent {
    let config = ureq::config::Config::builder()
        .timeout_global(Some(Duration::from_secs(timeout_secs)))
        .build();
    ureq::Agent::new_with_config(config)
}

pub(crate) fn get_is_cs() -> bool {
    false
}

pub(crate) fn decode_percent_str(s: &str) -> String {
    let mut bytes = Vec::new();
    let mut chars = s.as_bytes().iter();
    while let Some(&b) = chars.next() {
        if b == b'%' {
            if let (Some(&h1), Some(&h2)) = (chars.next(), chars.next()) {
                if let Ok(val) = u8::from_str_radix(std::str::from_utf8(&[h1, h2]).unwrap_or(""), 16) {
                    bytes.push(val);
                    continue;
                }
            }
        }
        bytes.push(b);
    }
    String::from_utf8_lossy(&bytes).to_string()
}

pub(crate) fn bounded_cmd(cmd: &str, args: &[&str], max_bytes: u64, timeout: Duration) -> Option<Vec<u8>> {
    use std::io::Read;
    let mut child = Command::new(cmd)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    let mut stdout = child.stdout.take()?;
    let (tx, rx) = mpsc::channel();

    thread::spawn(move || {
        let mut buf = Vec::new();
        let r = (&mut stdout).take(max_bytes + 1).read_to_end(&mut buf);
        let _ = tx.send(r.map(|_| buf));
    });

    let res = rx.recv_timeout(timeout);
    let _ = child.kill();
    let _ = child.wait();

    match res {
        Ok(Ok(b)) if (b.len() as u64) <= max_bytes => Some(b),
        _ => None,
    }
}
