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

# 2. Verify and remove CLI shortcut (strict ownership check)
QIS_BIN="${HOME}/.local/bin/qis"
if [[ -L "${QIS_BIN}" ]]; then
  target_link="$(readlink -f "${QIS_BIN}" 2>/dev/null || true)"
  if [[ "${target_link}" == "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" ]]; then
    rm -f "${QIS_BIN}"
    echo "  [OK] Verified QIS CLI symlink removed from ${QIS_BIN}"
  else
    echo "  [SKIP] ${QIS_BIN} points to '${target_link}' (not this QIS installation), leaving in place."
  fi
elif [[ -e "${QIS_BIN}" ]]; then
  echo "  [SKIP] ${QIS_BIN} is a regular user command/file, leaving in place."
fi

# 3. Verify and remove Plugin Directory (strict manifest id check)
if [[ -d "${TARGET_PLUGIN_DIR}" ]]; then
  MANIFEST_FILE="${TARGET_PLUGIN_DIR}/manifest.json"
  is_verified=0
  if [[ -f "${MANIFEST_FILE}" ]]; then
    if command -v jq >/dev/null 2>&1; then
      if [[ "$(jq -r '.id // empty' "${MANIFEST_FILE}" 2>/dev/null)" == "simonez.qwenimage" ]]; then
        is_verified=1
      fi
    elif grep -q '"id"[[:space:]]*:[[:space:]]*"simonez\.qwenimage"' "${MANIFEST_FILE}" 2>/dev/null; then
      is_verified=1
    fi
  fi

  if [[ "$is_verified" -eq 1 ]]; then
    echo "-> Verified plugin directory ownership at ${TARGET_PLUGIN_DIR}. Removing..."
    rm -rf "${TARGET_PLUGIN_DIR}"
    echo "  [OK] Plugin directory removed"
  else
    echo "  [SKIP] ${TARGET_PLUGIN_DIR} does not contain verified QIS manifest, leaving in place to prevent deleting unowned files."
  fi
fi

# 3. Reload / Restart Shell
echo "-> Restarting Omarchy Shell..."
if [[ -x "/usr/share/omarchy/bin/omarchy-restart-shell" ]]; then
  /usr/share/omarchy/bin/omarchy-restart-shell || true
elif command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins || true
fi

echo "=== QIS uninstalled successfully! ==="
