#!/usr/bin/env bash
# QIS (Qwen Image Studio) — Uninstallation Script for Omarchy Linux
set -euo pipefail

TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/simonez.qwenimage"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"

echo "=== Uninstalling QIS (Qwen Image Studio) ==="

# 1. Remove from shell.json
if [[ -f "$SHELL_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  echo "-> Removing simonez.qwenimage from shell.json..."
  tmp_json=$(mktemp)
  chmod 0600 "$tmp_json"
  jq '
    if .bar.layout.right then .bar.layout.right |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end |
    if .bar.layout.center then .bar.layout.center |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end |
    if .bar.layout.left then .bar.layout.left |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end
  ' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"
  echo "  [OK] shell.json updated"
fi

# 2. Remove Plugin Directory & CLI shortcut (with ownership verification)
QIS_BIN="${HOME}/.local/bin/qis"
if [[ -L "${QIS_BIN}" ]]; then
  target_link="$(readlink -f "${QIS_BIN}" 2>/dev/null || true)"
  if [[ "${target_link}" == "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" || "${target_link}" == *"/simonez.qwenimage/scripts/qis-stack.sh" ]]; then
    rm -f "${QIS_BIN}"
    echo "  [OK] Verified QIS CLI symlink removed from ${QIS_BIN}"
  else
    echo "  [SKIP] ${QIS_BIN} points to '${target_link}' (not QIS), keeping intact."
  fi
elif [[ -e "${QIS_BIN}" ]]; then
  echo "  [SKIP] ${QIS_BIN} is a regular file/command, keeping intact."
fi

if [[ -d "${TARGET_PLUGIN_DIR}" ]]; then
  echo "-> Removing plugin files at ${TARGET_PLUGIN_DIR}..."
  rm -rf "${TARGET_PLUGIN_DIR}"
  echo "  [OK] Plugin directory removed"
fi

# 3. Reload / Restart Shell
echo "-> Restarting Omarchy Shell..."
if [[ -x "/usr/share/omarchy/bin/omarchy-restart-shell" ]]; then
  /usr/share/omarchy/bin/omarchy-restart-shell || true
elif command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins || true
fi

echo "=== QIS uninstalled successfully! ==="
