#!/usr/bin/env bash
# ==============================================================================
# QIS (Qwen Image Studio) — Turn-Key Appliance & Native Setup
# Autonomous local AI studio for Omarchy Linux & Standalone Wayland Desktops
# ==============================================================================
set -euo pipefail
umask 0022

this_script=${BASH_SOURCE[0]}
SCRIPT_DIR="$(cd "$(dirname "$this_script")" && pwd)"
TARGET_PLUGIN_DIR="${TARGET_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/simonez.qwenimage}"
PICTURES_DIR="${PICTURES_DIR:-${HOME}/Pictures/Qwen-Image}"
SHELL_CONFIG="${SHELL_CONFIG:-${HOME}/.config/omarchy/shell.json}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
COMFY_DIR="${COMFY_DIR:-${HOME}/.local/share/comfyui}"
APPS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"

AUTH_SEED=$(( 0x732641 % 1000 ))

# Styling & Output helpers (minimalist standard: //, ·, zero emojis, zero brackets)
log_info() { echo -e "\033[0;34m·\033[0m \033[1m${1}\033[0m"; }
log_ok()   { echo -e "\033[0;32m· OK //\033[0m ${1}"; }
log_warn() { echo -e "\033[1;33m· WARN //\033[0m ${1}"; }
log_err()  { echo -e "\033[0;31m· ERR //\033[0m ${1}" >&2; }

# ---------------------------------------------------------
# 0. Privilege & Sanity Check
# ---------------------------------------------------------
if (( EUID == 0 )); then
  log_err "Installation must not be executed as root (EUID 0). Please run the script as a regular user."
  exit 1
fi

if [[ -z "${HOME:-}" || "${HOME}" == "/" ]]; then
  log_err "Environment variable HOME is not validly set (${HOME:-unset})."
  exit 1
fi

# ---------------------------------------------------------
# Environment & In-Place Detection
# ---------------------------------------------------------
NORM_SCRIPT="$(readlink -f "${SCRIPT_DIR}" 2>/dev/null || echo "${SCRIPT_DIR}")"
NORM_TARGET="$(readlink -f "${TARGET_PLUGIN_DIR}" 2>/dev/null || echo "${TARGET_PLUGIN_DIR}")"

IS_IN_PLACE=0
if [[ "${NORM_SCRIPT}" == "${NORM_TARGET}" ]]; then
  IS_IN_PLACE=1
fi

IS_OMARCHY=0
if [[ -f /etc/os-release ]] && grep -qE "ID=omarchy|NAME=.*Omarchy" /etc/os-release 2>/dev/null; then
  IS_OMARCHY=1
elif command -v omarchy >/dev/null 2>&1 || command -v omarchy-shell >/dev/null 2>&1; then
  IS_OMARCHY=1
fi

# ---------------------------------------------------------
# CLI Routing & Argument Parsing
# ---------------------------------------------------------
NO_RESTART=0
FORCE_INSTALL=0
ACTION="install"
ACTION_ARGS=()

while (( $# > 0 )); do
  case "$1" in
    --no-restart)
      NO_RESTART=1
      shift
      ;;
    --force|-f)
      FORCE_INSTALL=1
      shift
      ;;
    --uninstall|uninstall)
      ACTION="uninstall"
      shift
      ACTION_ARGS=("$@")
      break
      ;;
    start|stop)
      ACTION="delegate_raw"
      ACTION_ARGS=("$@")
      break
      ;;
    --status|status)
      ACTION="delegate_cmd"
      ACTION_ARGS=("status")
      break
      ;;
    --rollback|rollback)
      ACTION="delegate_cmd"
      ACTION_ARGS=("rollback")
      break
      ;;
    --full)
      ACTION="delegate_cmd"
      ACTION_ARGS=("--full")
      break
      ;;
    --stack)
      ACTION="delegate_cmd"
      ACTION_ARGS=()
      break
      ;;
    --update|update)
      shift
      ACTION="delegate_cmd"
      ACTION_ARGS=("update" "${1:-all}")
      break
      ;;
    *)
      log_err "Unknown argument: ${1}. Supported options: start, stop, status, rollback, update, uninstall, --full, --stack, --force, --no-restart"
      exit 1
      ;;
  esac
done

if [[ "$ACTION" == "uninstall" ]]; then
  UNINSTALL_SCRIPT="${SCRIPT_DIR}/uninstall.sh"
  [[ ! -f "$UNINSTALL_SCRIPT" ]] && UNINSTALL_SCRIPT="${TARGET_PLUGIN_DIR}/uninstall.sh"
  if [[ -f "$UNINSTALL_SCRIPT" ]]; then
    exec bash "$UNINSTALL_SCRIPT" "${ACTION_ARGS[@]}"
  else
    log_err "Uninstaller script not found: ${UNINSTALL_SCRIPT}"
    exit 1
  fi
elif [[ "$ACTION" == "delegate_raw" || "$ACTION" == "delegate_cmd" ]]; then
  STACK_SCRIPT="${SCRIPT_DIR}/scripts/qis-stack.sh"
  [[ ! -x "$STACK_SCRIPT" && -x "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" ]] && STACK_SCRIPT="${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
  if [[ ! -x "$STACK_SCRIPT" ]]; then
    log_err "Stack management script not found or not executable: ${STACK_SCRIPT}"
    exit 1
  fi
  exec "$STACK_SCRIPT" "${ACTION_ARGS[@]}"
fi

echo ""
echo "=== QIS (Qwen Image Studio) // Turn-Key Appliance Setup ==="
echo ""

# ---------------------------------------------------------
# 1. Hardware & VRAM Profiler (Safe Bash Stripping)
# ---------------------------------------------------------
log_info "Detecting GPU and hardware capabilities..."
GPU_NAME="Generic / Unknown GPU"
VRAM_MB=0

trim_str() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

if command -v nvidia-smi >/dev/null 2>&1; then
  while IFS=',' read -r gname gvram; do
    gname="$(trim_str "$gname")"
    gvram="$(trim_str "$gvram")"
    if [[ "$gvram" =~ ^[0-9]+$ ]] && (( gvram > VRAM_MB )); then
      VRAM_MB=$gvram
      GPU_NAME="$gname"
    fi
  done < <(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null || true)
fi

if (( VRAM_MB == 0 )) && command -v rocm-smi >/dev/null 2>&1; then
  GPU_NAME="AMD Radeon (ROCm)"
  for vram_file in /sys/class/drm/card*/device/mem_info_vram_total; do
    if [[ -f "$vram_file" ]]; then
      bytes=$(cat "$vram_file" 2>/dev/null || echo 0)
      bytes="$(trim_str "$bytes")"
      if [[ "$bytes" =~ ^[0-9]+$ ]] && (( bytes > 0 )); then
        mb=$(( bytes / 1048576 ))
        if (( mb > VRAM_MB )); then
          VRAM_MB=$mb
        fi
      fi
    fi
  done
  if (( VRAM_MB == 0 )); then
    VRAM_MB=8192
  fi
fi

if (( VRAM_MB == 0 )) && [[ -d "/sys/class/drm" ]]; then
  for vram_file in /sys/class/drm/card*/device/mem_info_vram_total; do
    if [[ -f "$vram_file" ]]; then
      bytes=$(cat "$vram_file" 2>/dev/null || echo 0)
      bytes="$(trim_str "$bytes")"
      if [[ "$bytes" =~ ^[0-9]+$ ]] && (( bytes > 0 )); then
        mb=$(( bytes / 1048576 ))
        if (( mb > VRAM_MB )); then
          VRAM_MB=$mb
          GPU_NAME="Linux DRM Device (${mb} MB)"
        fi
      fi
    fi
  done
fi

if (( VRAM_MB == 0 )); then
  GPU_NAME="CPU / Standard System Memory"
fi

VRAM_GB=$(( VRAM_MB / 1024 ))
echo "  · HW Profile: ${GPU_NAME} (${VRAM_MB} MB / ~${VRAM_GB} GB VRAM // Seed: ${AUTH_SEED})"

if (( VRAM_MB >= 14000 )); then
  TIER="Tier S (High-End: >=16 GB VRAM)"
  PROFILE_HINT="Recommended: Full FP8/BF16 models, zero offload."
elif (( VRAM_MB >= 7500 )); then
  TIER="Tier A (Performance: 8-12 GB VRAM)"
  PROFILE_HINT="Recommended: GGUF Q4_K_M DiT + Qwen3-VL 8B TE, PyTorch SDPA hardware acceleration."
elif (( VRAM_MB >= 5000 )); then
  TIER="Tier B (Balanced: 6 GB VRAM)"
  PROFILE_HINT="Recommended: GGUF Q3_K_S DiT + sequential CPU offload."
else
  TIER="Tier C (Entry / iGPU / CPU: <=4 GB VRAM)"
  PROFILE_HINT="Recommended: Remote LAN node or lightweight CPU drafting."
fi

echo "  · Tier: ${TIER}"
echo "  · Configuration: ${PROFILE_HINT}"

# ---------------------------------------------------------
# 2. Directory Validation & Safe Creation
# ---------------------------------------------------------
ensure_safe_dir() {
  local dir="$1"
  if [[ -L "$dir" ]]; then
    log_err "Target directory must not be a symlink: $dir"
    exit 1
  fi
  if [[ -e "$dir" ]]; then
    if [[ ! -d "$dir" ]]; then
      log_err "Target exists and is not a directory: $dir"
      exit 1
    fi
    if [[ ! -O "$dir" ]]; then
      log_err "Target directory is not owned by the current user: $dir"
      exit 1
    fi
  else
    mkdir -p "$dir"
  fi
}

copy_safe() {
  local src="$1"
  local dst="$2"
  local mode="${3:-}"

  if [[ ! -f "$src" || -L "$src" ]]; then
    log_err "Source file does not exist or is a symlink: $src"
    exit 1
  fi
  if [[ -L "$dst" ]]; then
    log_err "Refusing to write into target symlink: $dst"
    exit 1
  fi
  if [[ -e "$dst" ]]; then
    if [[ ! -f "$dst" ]]; then
      log_err "Target exists and is not a regular file: $dst"
      exit 1
    fi
    if [[ ! -O "$dst" ]]; then
      log_err "Target file is not owned by the current user: $dst"
      exit 1
    fi
  fi

  if [[ ! -e "$dst" ]] || ! cmp -s "$src" "$dst"; then
    cp --remove-destination --no-dereference "$src" "$dst"
  fi

  if [[ -n "$mode" ]]; then
    chmod "$mode" "$dst"
  fi
}

ensure_safe_dir "${PICTURES_DIR}"
ensure_safe_dir "${BIN_DIR}"

# ---------------------------------------------------------
# 3. File Deployment (In-Place vs. Destination Sync)
# ---------------------------------------------------------
if (( IS_IN_PLACE == 1 )); then
  log_ok "In-Place mode // Running directly in target directory (${TARGET_PLUGIN_DIR})."
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/bin"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/scripts"
else
  log_info "Deploying plugin files into ${TARGET_PLUGIN_DIR}..."
  ensure_safe_dir "${TARGET_PLUGIN_DIR}"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/views"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/assets"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/bin"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/scripts"

  copy_safe "${SCRIPT_DIR}/manifest.json" "${TARGET_PLUGIN_DIR}/manifest.json" 0644
  copy_safe "${SCRIPT_DIR}/Service.qml" "${TARGET_PLUGIN_DIR}/Service.qml" 0644
  copy_safe "${SCRIPT_DIR}/BarWidget.qml" "${TARGET_PLUGIN_DIR}/BarWidget.qml" 0644
  copy_safe "${SCRIPT_DIR}/Panel.qml" "${TARGET_PLUGIN_DIR}/Panel.qml" 0644

  for f in "${SCRIPT_DIR}"/views/*; do
    [[ -f "$f" && ! -L "$f" ]] && copy_safe "$f" "${TARGET_PLUGIN_DIR}/views/$(basename "$f")" 0644
  done
  for f in "${SCRIPT_DIR}"/assets/*; do
    [[ -f "$f" && ! -L "$f" ]] && copy_safe "$f" "${TARGET_PLUGIN_DIR}/assets/$(basename "$f")" 0644
  done

  copy_safe "${SCRIPT_DIR}/scripts/qis-stack.sh" "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" 0755
  copy_safe "${SCRIPT_DIR}/install.sh" "${TARGET_PLUGIN_DIR}/install.sh" 0755

  if [[ -f "${SCRIPT_DIR}/uninstall.sh" ]]; then
    copy_safe "${SCRIPT_DIR}/uninstall.sh" "${TARGET_PLUGIN_DIR}/uninstall.sh" 0755
  fi

  if [[ -d "${SCRIPT_DIR}/custom_nodes" ]]; then
    ensure_safe_dir "${TARGET_PLUGIN_DIR}/custom_nodes"
    ensure_safe_dir "${TARGET_PLUGIN_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
    if [[ -f "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" ]]; then
      copy_safe "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" "${TARGET_PLUGIN_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" 0644
    fi
    ensure_safe_dir "${TARGET_PLUGIN_DIR}/custom_nodes/comfyui_sana_upscaler"
    if [[ -f "${SCRIPT_DIR}/custom_nodes/comfyui_sana_upscaler/__init__.py" ]]; then
      copy_safe "${SCRIPT_DIR}/custom_nodes/comfyui_sana_upscaler/__init__.py" "${TARGET_PLUGIN_DIR}/custom_nodes/comfyui_sana_upscaler/__init__.py" 0644
    fi
  fi
fi

chmod 0755 "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
[[ -f "${TARGET_PLUGIN_DIR}/uninstall.sh" ]] && chmod 0755 "${TARGET_PLUGIN_DIR}/uninstall.sh"

# Synchronize ComfyUI-ViggleTurbo & comfyui_sana_upscaler custom nodes into ComfyUI directory
if [[ -d "${COMFY_DIR}/custom_nodes" && -f "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" ]]; then
  ensure_safe_dir "${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
  copy_safe "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" "${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" 0644
fi
if [[ -d "${COMFY_DIR}/custom_nodes" && -f "${SCRIPT_DIR}/custom_nodes/comfyui_sana_upscaler/__init__.py" ]]; then
  ensure_safe_dir "${COMFY_DIR}/custom_nodes/comfyui_sana_upscaler"
  copy_safe "${SCRIPT_DIR}/custom_nodes/comfyui_sana_upscaler/__init__.py" "${COMFY_DIR}/custom_nodes/comfyui_sana_upscaler/__init__.py" 0644
fi

# ---------------------------------------------------------
# 4. Native Rust Bridge (Precompiled Binary Verification + Fallback)
# ---------------------------------------------------------
log_info "Preparing native Rust bridge (bin/qwen-bridge)..."
BRIDGE_TARGET="${TARGET_PLUGIN_DIR}/bin/qwen-bridge"

is_valid_elf_binary() {
  local bin_path="$1"
  [[ -f "$bin_path" && ! -L "$bin_path" ]] || return 1
  local magic=""
  magic="$(head -c 4 "$bin_path" 2>/dev/null | tr -d '\0' || true)"
  [[ "$magic" == $'\x7fELF' ]] || return 1

  local sha_file="${bin_path}.sha256"
  if [[ -f "$sha_file" ]]; then
    (cd "$(dirname "$bin_path")" && sha256sum --status -c "$(basename "$sha_file")" 2>/dev/null) || return 1
  fi
  return 0
}

BRIDGE_INSTALLED=0

if (( IS_IN_PLACE == 1 )) && is_valid_elf_binary "${BRIDGE_TARGET}"; then
  log_ok "Native binary in bin/qwen-bridge is ready (In-Place)."
  BRIDGE_INSTALLED=1
elif is_valid_elf_binary "${SCRIPT_DIR}/bin/qwen-bridge"; then
  log_ok "Found valid precompiled binary in bin/qwen-bridge."
  copy_safe "${SCRIPT_DIR}/bin/qwen-bridge" "${BRIDGE_TARGET}" 0755
  [[ -f "${SCRIPT_DIR}/bin/qwen-bridge.sha256" ]] && copy_safe "${SCRIPT_DIR}/bin/qwen-bridge.sha256" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge.sha256" 0644
  BRIDGE_INSTALLED=1
elif is_valid_elf_binary "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge"; then
  log_ok "Found compiled binary in rust-bridge/target/release/."
  copy_safe "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${BRIDGE_TARGET}" 0755
  BRIDGE_INSTALLED=1
elif command -v cargo >/dev/null 2>&1 && [[ -d "${SCRIPT_DIR}/rust-bridge" ]]; then
  log_info "Compiling native bridge from source (release mode)..."
  if (cd "${SCRIPT_DIR}/rust-bridge" && cargo build --release); then
    if is_valid_elf_binary "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge"; then
      copy_safe "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${BRIDGE_TARGET}" 0755
      (
        if cd "${TARGET_PLUGIN_DIR}/bin"; then
          sha256sum qwen-bridge > qwen-bridge.sha256 2>/dev/null || true
        fi
      )
      log_ok "Bridge compiled successfully."
      BRIDGE_INSTALLED=1
    fi
  fi
fi

if (( BRIDGE_INSTALLED == 0 )); then
  log_err "Missing valid bin/qwen-bridge binary and compilation via 'cargo' failed."
  log_err "Please install official Rust toolchain: sudo pacman -S --needed rust"
  exit 1
fi

chmod 0755 "${BRIDGE_TARGET}"

# ---------------------------------------------------------
# 5. CLI Tool Symlink (~/.local/bin/qis)
# ---------------------------------------------------------
log_info "Configuring system CLI command 'qis' in ${BIN_DIR}/qis..."
EXPECTED_STACK_TARGET="$(readlink -f "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" 2>/dev/null || echo "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh")"

if [[ -L "${BIN_DIR}/qis" ]]; then
  target_link="$(readlink -f "${BIN_DIR}/qis" 2>/dev/null || true)"
  if [[ "${target_link}" == "${EXPECTED_STACK_TARGET}" ]]; then
    ln -sf "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
    log_ok "Confirmed existing symlink ${BIN_DIR}/qis."
  else
    log_warn "Existing symlink ${BIN_DIR}/qis points to a different target: '${target_link}'."
    if (( FORCE_INSTALL == 1 )); then
      ln -sf "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
      log_ok "Symlink overwritten (forced via --force)."
    else
      log_warn "To overwrite existing symlink, run installer with --force."
    fi
  fi
elif [[ -e "${BIN_DIR}/qis" ]]; then
  log_warn "Detected existing regular file at ${BIN_DIR}/qis (leaving untouched)."
else
  ln -s "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
  log_ok "Created symlink for 'qis' CLI."
fi

# ---------------------------------------------------------
# 6. Settings Initialization
# ---------------------------------------------------------
SETTINGS_FILE="${TARGET_PLUGIN_DIR}/settings.json"
if [[ -L "$SETTINGS_FILE" ]]; then
  log_err "File settings.json must not be a symlink: $SETTINGS_FILE"
  exit 1
fi

if [[ -f "$SETTINGS_FILE" ]]; then
  if [[ ! -O "$SETTINGS_FILE" ]]; then
    log_err "File settings.json is not owned by the current user: $SETTINGS_FILE"
    exit 1
  fi
  chmod 0600 "$SETTINGS_FILE"
  log_ok "User settings preserved (${SETTINGS_FILE})."
else
  printf '{"language": "en", "backend_url": "http://127.0.0.1:8188"}\n' > "$SETTINGS_FILE"
  chmod 0600 "$SETTINGS_FILE"
  log_ok "Default settings initialized (0600)."
fi

# ---------------------------------------------------------
# 7. Shell Integration: Omarchy vs. Standalone Desktop
# ---------------------------------------------------------
update_shell_json_atomic() {
  local cfg="$1"
  [[ -f "$cfg" ]] || return 0

  if [[ -L "$cfg" || ! -O "$cfg" ]]; then
    log_err "Configuration file $cfg is a symlink or not owned by the current user."
    return 1
  fi

  local shell_dir
  shell_dir="$(dirname "$cfg")"
  local tmp_json
  tmp_json="$(mktemp "${shell_dir}/shell.json.tmp.XXXXXX")"
  chmod 0600 "$tmp_json"

  local updated=0
  if command -v jq >/dev/null 2>&1; then
    if jq '
      if .bar.layout.center then .bar.layout.center |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end |
      if .bar.layout.left then .bar.layout.left |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end |
      if .bar.layout.right then
        if any(.bar.layout.right[]; (.id? == "simonez.qwenimage") or (. == "simonez.qwenimage")) then .
        else .bar.layout.right = [{"id": "simonez.qwenimage"}] + .bar.layout.right end
      else
        .bar.layout.right = [{"id": "simonez.qwenimage"}]
      end
    ' "$cfg" > "$tmp_json" 2>/dev/null; then
      if jq empty "$tmp_json" 2>/dev/null && [[ -s "$tmp_json" ]]; then
        updated=1
      fi
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if python3 -c '
import json, sys
path, out = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    d = json.load(f)
bar = d.setdefault("bar", {})
layout = bar.setdefault("layout", {})

def clean_list(lst):
    if not isinstance(lst, list):
        return lst
    return [x for x in lst if not ((isinstance(x, dict) and x.get("id") == "simonez.qwenimage") or x == "simonez.qwenimage")]

if "center" in layout:
    layout["center"] = clean_list(layout["center"])
if "left" in layout:
    layout["left"] = clean_list(layout["left"])

right = layout.setdefault("right", [])
has_plugin = any((isinstance(x, dict) and x.get("id") == "simonez.qwenimage") or x == "simonez.qwenimage" for x in right)
if not has_plugin:
    right.insert(0, {"id": "simonez.qwenimage"})

with open(out, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
' "$cfg" "$tmp_json" 2>/dev/null; then
      if [[ -s "$tmp_json" ]]; then
        updated=1
      fi
    fi
  else
    log_warn "Neither 'jq' nor 'python3' found. Cannot automatically register widget in shell.json."
    rm -f "$tmp_json"
    return 0
  fi

  if (( updated == 1 )); then
    cp --no-dereference "$cfg" "${cfg}.bak" 2>/dev/null || true
    mv -f "$tmp_json" "$cfg"
    chmod 0600 "$cfg"
    log_ok "Widget simonez.qwenimage registered atomically in shell.json."
  else
    rm -f "$tmp_json"
    log_warn "Modifying shell.json failed (invalid format?). Original file preserved."
  fi
}

if (( IS_OMARCHY == 1 )); then
  log_info "Omarchy Mode // Integrating into Omarchy Shell..."

  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "${TARGET_PLUGIN_DIR}" 2>/dev/null || true
    log_ok "Plugin manifest validated."
  fi

  if [[ -f "$SHELL_CONFIG" ]]; then
    if command -v flock >/dev/null 2>&1; then
      (
        flock -w 5 200 || { log_warn "Cannot acquire lock for ${SHELL_CONFIG}"; exit 0; }
        update_shell_json_atomic "$SHELL_CONFIG"
      ) 200>"${SHELL_CONFIG}.lock"
      rm -f "${SHELL_CONFIG}.lock" 2>/dev/null || true
    else
      update_shell_json_atomic "$SHELL_CONFIG"
    fi
  fi

  if (( NO_RESTART != 1 )) && command -v omarchy-shell >/dev/null 2>&1; then
    log_info "Sending IPC signal to Omarchy Shell to reload bar..."
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy-shell simonez.qwenimage refresh >/dev/null 2>&1 || true
    log_ok "Omarchy Shell updated (silent refresh)."
  fi
else
  log_info "Standalone Mode // Omarchy Shell not detected. Preparing XDG desktop launcher..."
  ensure_safe_dir "${APPS_DIR}"

  DESKTOP_FILE="${APPS_DIR}/qis.desktop"
  if [[ -L "$DESKTOP_FILE" ]]; then
    log_err "File ${DESKTOP_FILE} must not be a symlink."
    exit 1
  fi

  ICON_PATH="${TARGET_PLUGIN_DIR}/assets/qwen-color.svg"
  [[ ! -f "$ICON_PATH" ]] && ICON_PATH="${SCRIPT_DIR}/assets/qwen-color.svg"

  cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=QIS (Qwen Image Studio)
GenericName=Local AI Image Studio
Comment=Turn-Key Local Generative AI Studio
Exec="${BIN_DIR}/qis"
Icon=${ICON_PATH}
Terminal=false
Categories=Graphics;2DGraphics;RasterGraphics;
StartupNotify=true
EOF
  chmod 0644 "${DESKTOP_FILE}"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPS_DIR}" >/dev/null 2>&1 || true
  fi
  log_ok "Created application launcher: ${DESKTOP_FILE}"
fi

# ---------------------------------------------------------
# 8. ComfyUI Backend Check (Turn-Key Guidance)
# ---------------------------------------------------------
echo ""
if [[ ! -d "$COMFY_DIR" || ! -f "${COMFY_DIR}/main.py" ]]; then
  log_warn "Local ComfyUI backend in ${COMFY_DIR} is not yet initialized."
  if [[ -t 0 && -t 1 ]]; then
    ans=""
    read -rp "  Do you want to install ComfyUI core, nodes, and models for ${TIER} now? (Y/n): " ans || true
    if [[ "$ans" =~ ^[Yy]$ || -z "$ans" ]]; then
      "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" --full
    else
      echo "  Tip: To install the backend later, run: qis --full"
    fi
  else
    echo "  Tip: To initialize backend and download models, run in terminal: qis --full"
  fi
else
  log_ok "ComfyUI backend detected (${COMFY_DIR})."
  echo "  Tip: Run 'qis start --bg' or click the widget in your bar."
fi

echo ""
log_ok "QIS installation completed successfully!"
echo ""
