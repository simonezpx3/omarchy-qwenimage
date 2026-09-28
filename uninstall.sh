#!/usr/bin/env bash
# QIS (Qwen Image Studio) — Uninstallation Script for Omarchy Linux
set -euo pipefail

TARGET_PLUGIN_DIR="${TARGET_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/simonez.qwenimage}"
SHELL_CONFIG="${SHELL_CONFIG:-${HOME}/.config/omarchy/shell.json}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"

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
QIS_BIN="${BIN_DIR}/qis"
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

# 3. Verify and remove only installer-owned, unmodified plugin files
if [[ -d "${TARGET_PLUGIN_DIR}" && ! -L "${TARGET_PLUGIN_DIR}" ]]; then
  TARGET_REAL="$(realpath -q "${TARGET_PLUGIN_DIR}" 2>/dev/null || true)"
  MANIFEST_FILE="${TARGET_PLUGIN_DIR}/manifest.json"

  if [[ -n "${TARGET_REAL}" && -f "${MANIFEST_FILE}" && ! -L "${MANIFEST_FILE}" ]]; then
    is_qis=0
    if command -v jq >/dev/null 2>&1; then
      if [[ "$(jq -r '.id // empty' "${MANIFEST_FILE}" 2>/dev/null)" == "simonez.qwenimage" ]]; then
        is_qis=1
      fi
    elif grep -q '"id"[[:space:]]*:[[:space:]]*"simonez\.qwenimage"' "${MANIFEST_FILE}" 2>/dev/null; then
      is_qis=1
    fi

    if [[ "$is_qis" -eq 1 ]]; then
      echo "-> Verifying content identity and removing unmodified installer-owned files..."
      HASHES_FILE="${TARGET_PLUGIN_DIR}/.installed_hashes"

      # Fixed whitelist of allowed relative paths deployed by installer
      known_files=(
        "manifest.json"
        "BarWidget.qml"
        "Panel.qml"
        "settings.json"
        "bin/qwen-bridge"
        "scripts/qis-stack.sh"
        "views/CivitaiView.qml"
        "views/CompareView.qml"
        "views/HistoryView.qml"
        "views/qmldir"
        "views/StudioView.qml"
        "assets/qwen-color.svg"
        "assets/qwen-heretic.svg"
        "assets/qwen-mono.svg"
      )

      # Build expected hash map if .installed_hashes is present and safe
      declare -A expected_hashes=()
      if [[ -f "${HASHES_FILE}" && ! -L "${HASHES_FILE}" && -O "${HASHES_FILE}" ]]; then
        while read -r hash rel || [[ -n "$hash" ]]; do
          [[ -z "$hash" || -z "$rel" ]] && continue
          # Strip leading ./, *, and whitespace
          rel="${rel#\./}"
          rel="${rel#\*}"
          rel="${rel#"${rel%%[![:space:]]*}"}"
          rel="${rel%"${rel##*[![:space:]]}"}"
          expected_hashes["$rel"]="$hash"
        done < "${HASHES_FILE}"
      fi

      for rel_path in "${known_files[@]}"; do
        # Enforce path traversal protection: reject '..' or leading '/'
        if [[ "$rel_path" == /* || "$rel_path" == *..* ]]; then
          continue
        fi

        candidate="${TARGET_PLUGIN_DIR}/${rel_path}"

        # Must exist as a regular file and NOT a symlink
        if [[ ! -f "$candidate" || -L "$candidate" ]]; then
          continue
        fi

        # Canonical path must strictly reside inside TARGET_REAL
        candidate_real="$(realpath -q "$candidate" 2>/dev/null || true)"
        if [[ -z "$candidate_real" || "$candidate_real" != "${TARGET_REAL}/"* ]]; then
          continue
        fi

        # Parent directory must not be a symlink
        parent_real="$(dirname "$candidate_real")"
        if [[ -L "$parent_real" ]]; then
          continue
        fi

        # Fail-Closed Content Identity verification:
        # Require a trusted recorded hash from installation. If absent, modified, or pre-existing,
        # fail closed and leave the file completely untouched.
        exp_hash="${expected_hashes["$rel_path"]:-}"
        if [[ -z "$exp_hash" ]]; then
          echo "  [SKIP] No trusted hash recorded for ${rel_path}, leaving intact."
          continue
        fi

        curr_hash="$(sha256sum "$candidate_real" 2>/dev/null | awk '{print $1}')"
        if [[ "$curr_hash" != "$exp_hash" ]]; then
          echo "  [SKIP] Modified content detected in ${rel_path} (${curr_hash:0:8} != ${exp_hash:0:8}), leaving intact."
          continue
        fi

        rm -f "$candidate_real"
        echo "  [OK] Removed verified unmodified installer file: ${rel_path}"
      done

      # Remove hashes file after processing
      rm -f "${HASHES_FILE}" "${TARGET_PLUGIN_DIR}/.installed_files" 2>/dev/null || true

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
