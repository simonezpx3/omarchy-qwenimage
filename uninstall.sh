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

# 3. Verify and remove only installer-owned plugin files
if [[ -d "${TARGET_PLUGIN_DIR}" && ! -L "${TARGET_PLUGIN_DIR}" ]]; then
  MANIFEST_FILE="${TARGET_PLUGIN_DIR}/manifest.json"
  if [[ -f "${MANIFEST_FILE}" && ! -L "${MANIFEST_FILE}" ]]; then
    is_qis=0
    if command -v jq >/dev/null 2>&1; then
      if [[ "$(jq -r '.id // empty' "${MANIFEST_FILE}" 2>/dev/null)" == "simonez.qwenimage" ]]; then
        is_qis=1
      fi
    elif grep -q '"id"[[:space:]]*:[[:space:]]*"simonez\.qwenimage"' "${MANIFEST_FILE}" 2>/dev/null; then
      is_qis=1
    fi

    if [[ "$is_qis" -eq 1 ]]; then
      echo "-> Removing verified installer-owned files..."
      receipt_file="${TARGET_PLUGIN_DIR}/.installed_files"
      if [[ -f "${receipt_file}" && ! -L "${receipt_file}" ]]; then
        while IFS= read -r rel_path || [[ -n "$rel_path" ]]; do
          [[ -z "$rel_path" || "$rel_path" == \#* ]] && continue
          target_path="${TARGET_PLUGIN_DIR}/${rel_path}"
          if [[ -f "${target_path}" && ! -L "${target_path}" ]]; then
            rm -f "${target_path}"
          fi
        done < "${receipt_file}"
      fi

      # Also remove known default installer files in case receipt was deleted
      for known_rel in \
        "manifest.json" "BarWidget.qml" "Panel.qml" "settings.json" \
        "bin/qwen-bridge" "scripts/qis-stack.sh" \
        "views/CivitaiView.qml" "views/CompareView.qml" "views/HistoryView.qml" \
        "views/qmldir" "views/StudioView.qml" \
        "assets/qwen-color.svg" "assets/qwen-heretic.svg" "assets/qwen-mono.svg" \
        ".installed_files"; do
        target_path="${TARGET_PLUGIN_DIR}/${known_rel}"
        if [[ -f "${target_path}" && ! -L "${target_path}" ]]; then
          rm -f "${target_path}"
        fi
      done

      # Clean empty directories only (leaves foreign or user-created files intact)
      rmdir "${TARGET_PLUGIN_DIR}/bin" 2>/dev/null || true
      rmdir "${TARGET_PLUGIN_DIR}/scripts" 2>/dev/null || true
      rmdir "${TARGET_PLUGIN_DIR}/views" 2>/dev/null || true
      rmdir "${TARGET_PLUGIN_DIR}/assets" 2>/dev/null || true

      if rmdir "${TARGET_PLUGIN_DIR}" 2>/dev/null; then
        echo "  [OK] Plugin directory cleanly removed"
      else
        echo "  [INFO] User-created or modified files remain in ${TARGET_PLUGIN_DIR}, preserving intact."
      fi
    else
      echo "  [SKIP] ${MANIFEST_FILE} is not a verified QIS manifest, leaving directory intact."
    fi
  else
    echo "  [SKIP] ${TARGET_PLUGIN_DIR} does not contain a regular manifest.json, leaving directory intact."
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
