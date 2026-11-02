use crate::common::*;
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;

pub(crate) fn get_legacy_settings_path() -> PathBuf {
    get_home()
        .join(".config")
        .join("omarchy")
        .join("plugins")
        .join("simonez.qwenimage")
        .join("settings.json")
}

pub(crate) fn get_settings_path() -> PathBuf {
    let base = std::env::var("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| get_home().join(".config"));
    base.join("qwenimage").join("settings.json")
}

pub(crate) fn load_settings() -> serde_json::Value {
    let p = get_settings_path();
    if let Ok(content) = fs::read_to_string(&p) {
        if let Ok(val) = serde_json::from_str(&content) {
            return val;
        }
    }
    let legacy_p = get_legacy_settings_path();
    if legacy_p.exists() {
        if let Ok(content) = fs::read_to_string(&legacy_p) {
            if let Ok(val) = serde_json::from_str(&content) {
                let _ = save_settings(&val);
                let _ = fs::remove_file(&legacy_p);
                return val;
            }
        }
    }
    serde_json::json!({})
}

pub(crate) fn save_settings(val: &serde_json::Value) -> Result<(), std::io::Error> {
    let p = get_settings_path();
    if let Some(parent) = p.parent() {
        let _ = fs::create_dir_all(parent);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(parent, fs::Permissions::from_mode(0o700));
        }
    }
    let s = serde_json::to_string_pretty(val)
        .map_err(std::io::Error::other)?;
    let tmp = p.with_extension("tmp");
    let mut f = File::create(&tmp)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = f.set_permissions(fs::Permissions::from_mode(0o600));
    }
    f.write_all(s.as_bytes())?;
    f.sync_all()?;
    fs::rename(&tmp, &p)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&p, fs::Permissions::from_mode(0o600));
    }
    let legacy_p = get_legacy_settings_path();
    if legacy_p.exists() {
        let _ = fs::remove_file(&legacy_p);
    }
    Ok(())
}

pub(crate) fn cmd_settings_get() {
    let mut val = load_settings();
    if !val.is_object() {
        val = serde_json::json!({});
    }
    let obj = val.as_object_mut().unwrap();
    let lang = obj.get("language").and_then(|v| v.as_str()).unwrap_or("en");
    let nsfw = obj.get("nsfw").and_then(|v| v.as_bool()).unwrap_or(false);

    let parse_level = |v: Option<&serde_json::Value>| -> String {
        match v {
            Some(serde_json::Value::String(s)) => {
                let sl = s.to_lowercase();
                if sl == "soft" || sl == "full" { sl } else { "off".to_string() }
            }
            Some(serde_json::Value::Bool(b)) => {
                if *b { "full".to_string() } else { "off".to_string() }
            }
            _ => "off".to_string(),
        }
    };

    let anime_mode = parse_level(obj.get("anime_mode").or_else(|| obj.get("anime_lora")).or_else(|| obj.get("anime")));
    let uncensored_mode = parse_level(obj.get("uncensored_mode").or_else(|| obj.get("heretic_mode")).or_else(|| obj.get("uncensored")).or_else(|| obj.get("heretic")));
    let anatomy_mode = parse_level(obj.get("anatomy_mode").or_else(|| obj.get("anatomy_lora")).or_else(|| obj.get("anatomy")));

    let anime_bool = anime_mode != "off";
    let uncensored_bool = uncensored_mode != "off";
    let anatomy_bool = anatomy_mode != "off";

    let turbo = obj.get("turbo").and_then(|v| v.as_bool()).unwrap_or(true);
    let auto_expand = obj.get("auto_expand").and_then(|v| v.as_bool()).unwrap_or(false);
    let res_mode = obj.get("res_mode").and_then(|v| v.as_str()).unwrap_or("standard");

    println!("{}", serde_json::json!({
        "status": "ok",
        "lang": lang,
        "nsfw": nsfw,
        "anime": anime_bool,
        "anime_mode": anime_mode,
        "turbo": turbo,
        "uncensored": uncensored_bool,
        "uncensored_mode": uncensored_mode,
        "heretic_mode": uncensored_mode,
        "anatomy": anatomy_bool,
        "anatomy_mode": anatomy_mode,
        "auto_expand": auto_expand,
        "res_mode": res_mode,
        "settings": val
    }));
}

pub(crate) fn cmd_settings_set(key: &str, value: &str) {
    let mut val = load_settings();
    if !val.is_object() {
        val = serde_json::json!({});
    }
    if let Some(map) = val.as_object_mut() {
        match key {
            "anime_mode" | "anime_lora" | "anime" => {
                let norm = match value.to_lowercase().as_str() {
                    "soft" | "low" | "1" => "soft",
                    "full" | "high" | "hard" | "true" | "2" => "full",
                    _ => "off",
                };
                map.insert("anime_mode".to_string(), serde_json::json!(norm));
                map.insert("anime_lora".to_string(), serde_json::json!(norm != "off"));
            }
            "uncensored_mode" | "heretic_mode" | "uncensored" | "heretic" => {
                let norm = match value.to_lowercase().as_str() {
                    "soft" | "low" | "1" => "soft",
                    "full" | "high" | "hard" | "true" | "2" => "full",
                    _ => "off",
                };
                map.insert("uncensored_mode".to_string(), serde_json::json!(norm));
                map.insert("heretic_mode".to_string(), serde_json::json!(norm));
                map.insert("uncensored".to_string(), serde_json::json!(norm != "off"));
            }
            "anatomy_mode" | "anatomy_lora" | "anatomy" => {
                let norm = match value.to_lowercase().as_str() {
                    "soft" | "low" | "1" => "soft",
                    "full" | "high" | "hard" | "true" | "2" => "full",
                    _ => "off",
                };
                map.insert("anatomy_mode".to_string(), serde_json::json!(norm));
                map.insert("anatomy_lora".to_string(), serde_json::json!(norm != "off"));
            }
            "nsfw" | "turbo" | "auto_expand" => {
                let b = value.eq_ignore_ascii_case("true") || value == "1";
                map.insert(key.to_string(), serde_json::json!(b));
            }
            "language" | "lang" => {
                map.insert("language".to_string(), serde_json::json!("en"));
            }
            "res_mode" => {
                map.insert("res_mode".to_string(), serde_json::json!(value));
            }
            other => {
                map.insert(other.to_string(), serde_json::json!(value));
            }
        }
    }
    match save_settings(&val) {
        Ok(_) => println!("{}", serde_json::json!({"status": "ok", "key": key, "value": value})),
        Err(e) => println!("{}", serde_json::json!({"status": "error", "message": format!("{}", e)})),
    }
}
