#!/usr/bin/env bash
# ==============================================================================
# QIS (Qwen Image Studio) — Safe Uninstaller & Cleanup
# ==============================================================================
set -euo pipefail
umask 0022

this_script=${BASH_SOURCE[0]}
SCRIPT_DIR="$(cd "$(dirname "$this_script")" && pwd)"
TARGET_PLUGIN_DIR="${TARGET_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/simonez.qwenimage}"
SHELL_CONFIG="${SHELL_CONFIG:-${HOME}/.config/omarchy/shell.json}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
COMFY_DIR="${COMFY_DIR:-${HOME}/.local/share/comfyui}"
APPS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"

log_info() { echo -e "\033[0;34m·\033[0m \033[1m${1}\033[0m"; }
log_ok()   { echo -e "\033[0;32m· OK //\033[0m ${1}"; }
log_warn() { echo -e "\033[1;33m· WARN //\033[0m ${1}"; }
log_err()  { echo -e "\033[0;31m· ERR //\033[0m ${1}" >&2; }

if (( EUID == 0 )); then
  log_err "Uninstallation must not be executed as root (EUID 0). Please run the script as a regular user."
  exit 1
fi

if [[ -z "${HOME:-}" || "${HOME}" == "/" ]]; then
  log_err "Environment variable HOME is not validly set (${HOME:-unset})."
  exit 1
fi

PURGE_SETTINGS=0
PURGE_COMFY=0
NO_RESTART=0

for arg in "$@"; do
  case "$arg" in
    --purge-settings)
      PURGE_SETTINGS=1
      ;;
    --purge-all)
      PURGE_SETTINGS=1
      PURGE_COMFY=1
      ;;
    --no-restart)
      NO_RESTART=1
      ;;
    *)
      log_err "Unknown argument: ${arg}. Allowed options: --purge-settings, --purge-all, --no-restart"
      exit 1
      ;;
  esac
done

echo ""
echo "=== QIS (Qwen Image Studio) // Uninstallation ==="
echo ""

# ---------------------------------------------------------
# 1. Stop Running Backend Stack
# ---------------------------------------------------------
STACK_SCRIPT="${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
[[ ! -x "$STACK_SCRIPT" && -x "${SCRIPT_DIR}/scripts/qis-stack.sh" ]] && STACK_SCRIPT="${SCRIPT_DIR}/scripts/qis-stack.sh"

if [[ -x "$STACK_SCRIPT" ]]; then
  log_info "Stopping running QIS backend processes..."
  "$STACK_SCRIPT" stop >/dev/null 2>&1 || true
  log_ok "Backend processes stopped."
fi

# ---------------------------------------------------------
# 2. Remove CLI Symlink (~/.local/bin/qis)
# ---------------------------------------------------------
CLI_LINK="${BIN_DIR}/qis"
if [[ -L "$CLI_LINK" ]]; then
  link_target="$(readlink -f "$CLI_LINK" 2>/dev/null || true)"
  expected_target="$(readlink -f "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" 2>/dev/null || echo "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh")"
  alt_target="$(readlink -f "${SCRIPT_DIR}/scripts/qis-stack.sh" 2>/dev/null || echo "${SCRIPT_DIR}/scripts/qis-stack.sh")"

  if [[ "$link_target" == "$expected_target" || "$link_target" == "$alt_target" || "$link_target" == *"simonez.qwenimage"* ]]; then
    rm -f "$CLI_LINK"
    log_ok "Removed CLI symlink: ${CLI_LINK}"
  else
    log_warn "Symlink ${CLI_LINK} points to another target (${link_target}) // Left unchanged."
  fi
fi

# ---------------------------------------------------------
# 3. Remove Standalone Desktop Entry
# ---------------------------------------------------------
DESKTOP_FILE="${APPS_DIR}/qis.desktop"
if [[ -f "$DESKTOP_FILE" && ! -L "$DESKTOP_FILE" ]]; then
  rm -f "$DESKTOP_FILE"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPS_DIR}" >/dev/null 2>&1 || true
  fi
  log_ok "Removed XDG desktop entry: ${DESKTOP_FILE}"
fi

# ---------------------------------------------------------
# 4. Deregister Widget from Omarchy shell.json
# ---------------------------------------------------------
remove_from_shell_json() {
  local cfg="$1"
  [[ -f "$cfg" && ! -L "$cfg" && -O "$cfg" ]] || return 0

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
      if .bar.layout.right then .bar.layout.right |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end
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
layout = d.get("bar", {}).get("layout", {})
for section in ("left", "center", "right"):
    if isinstance(layout.get(section), list):
        layout[section] = [
            x for x in layout[section]
            if not ((isinstance(x, dict) and x.get("id") == "simonez.qwenimage") or x == "simonez.qwenimage")
        ]
with open(out, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
' "$cfg" "$tmp_json" 2>/dev/null; then
      if [[ -s "$tmp_json" ]]; then
        updated=1
      fi
    fi
  fi

  if (( updated == 1 )); then
    cp --no-dereference "$cfg" "${cfg}.bak" 2>/dev/null || true
    mv -f "$tmp_json" "$cfg"
    chmod 0600 "$cfg"
    log_ok "Widget simonez.qwenimage removed from ${cfg}."
  else
    rm -f "$tmp_json"
  fi
}

if [[ -f "$SHELL_CONFIG" ]]; then
  if command -v flock >/dev/null 2>&1; then
    (
      flock -w 5 200 || exit 0
      remove_from_shell_json "$SHELL_CONFIG"
    ) 200>"${SHELL_CONFIG}.lock"
    rm -f "${SHELL_CONFIG}.lock" 2>/dev/null || true
  else
    remove_from_shell_json "$SHELL_CONFIG"
  fi
fi

# ---------------------------------------------------------
# 5. Clean ComfyUI Custom Node
# ---------------------------------------------------------
VIGGLE_NODE_DIR="${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
if [[ -d "$VIGGLE_NODE_DIR" && ! -L "$VIGGLE_NODE_DIR" && -O "$VIGGLE_NODE_DIR" ]]; then
  rm -rf "$VIGGLE_NODE_DIR"
  log_ok "Removed custom node: ${VIGGLE_NODE_DIR}"
fi

# ---------------------------------------------------------
# 6. Safe Plugin Directory Cleanup (Git & In-Place Protection)
# ---------------------------------------------------------
if [[ -e "$TARGET_PLUGIN_DIR" ]]; then
  if [[ -L "$TARGET_PLUGIN_DIR" || ! -d "$TARGET_PLUGIN_DIR" || ! -O "$TARGET_PLUGIN_DIR" ]]; then
    log_err "Refusing to remove ${TARGET_PLUGIN_DIR} (it is a symlink or not owned by the current user)."
    exit 1
  fi

  if [[ -d "${TARGET_PLUGIN_DIR}/.git" ]]; then
    log_warn "Git repository detected in ${TARGET_PLUGIN_DIR} (In-Place development mode)."
    log_info "Removing generated artifacts only (bin/qwen-bridge), preserving source code..."
    rm -f "${TARGET_PLUGIN_DIR}/bin/qwen-bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge.sha256"
    if (( PURGE_SETTINGS == 1 )); then
      rm -f "${TARGET_PLUGIN_DIR}/settings.json"
      log_ok "Removed settings.json."
    fi
  elif [[ -f "${TARGET_PLUGIN_DIR}/manifest.json" || -f "${TARGET_PLUGIN_DIR}/Panel.qml" ]]; then
    if (( PURGE_SETTINGS == 0 )) && [[ -f "${TARGET_PLUGIN_DIR}/settings.json" ]]; then
      BACKUP_SETTINGS="${HOME}/.config/omarchy/qis-settings.json.bak"
      cp --no-dereference "${TARGET_PLUGIN_DIR}/settings.json" "$BACKUP_SETTINGS" 2>/dev/null || true
      chmod 0600 "$BACKUP_SETTINGS" 2>/dev/null || true
      log_info "User settings backed up to: ${BACKUP_SETTINGS}"
    fi
    rm -rf "$TARGET_PLUGIN_DIR"
    log_ok "Removed plugin directory: ${TARGET_PLUGIN_DIR}"
  else
    log_err "Directory ${TARGET_PLUGIN_DIR} does not contain manifest.json // Refusing rm -rf for safety."
    exit 1
  fi
fi

# ---------------------------------------------------------
# 7. Optional Full ComfyUI Purge
# ---------------------------------------------------------
if (( PURGE_COMFY == 1 )) && [[ -d "$COMFY_DIR" && ! -L "$COMFY_DIR" && -O "$COMFY_DIR" ]]; then
  if [[ -f "${COMFY_DIR}/main.py" ]]; then
    rm -rf "$COMFY_DIR"
    log_ok "Completely removed ComfyUI backend: ${COMFY_DIR}"
  fi
fi

# ---------------------------------------------------------
# 8. Notify Omarchy Shell
# ---------------------------------------------------------
if (( NO_RESTART != 1 )) && command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  log_ok "Omarchy Shell updated."
fi

echo ""
log_ok "QIS uninstallation completed successfully."
echo ""
