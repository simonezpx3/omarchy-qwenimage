#!/usr/bin/env bash
# ==============================================================================
# QIS (Qwen Image Studio) — Universal Installation & Lifecycle Profiler
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="${TARGET_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/simonez.qwenimage}"
PICTURES_DIR="${PICTURES_DIR:-${HOME}/Pictures/Qwen-Image}"
SHELL_CONFIG="${SHELL_CONFIG:-${HOME}/.config/omarchy/shell.json}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"

NO_RESTART=0
for arg in "$@"; do
  if [[ "$arg" == "--no-restart" ]]; then
    NO_RESTART=1
  fi
done

# ---------------------------------------------------------
# CLI Routing for Lifecycle & Updates (Whitelisted arguments)
# ---------------------------------------------------------
case "${1:-}" in
  --update|update)
    shift || true
    target_sub="${1:-all}"
    case "${target_sub}" in
      plugin|comfy|models|all)
        exec "${SCRIPT_DIR}/scripts/qis-stack.sh" update "${target_sub}"
        ;;
      *)
        echo "[ERROR] Neplatný cíl aktualizace: ${target_sub}. Povolené cíle: plugin, comfy, models, all." >&2
        exit 1
        ;;
    esac
    ;;
  --status|status)
    exec "${SCRIPT_DIR}/scripts/qis-stack.sh" status
    ;;
  --rollback|rollback)
    exec "${SCRIPT_DIR}/scripts/qis-stack.sh" rollback
    ;;
  --full)
    exec "${SCRIPT_DIR}/scripts/qis-stack.sh" --full
    ;;
  --stack)
    exec "${SCRIPT_DIR}/scripts/qis-stack.sh"
    ;;
  --no-restart|"")
    # Pokračovat na standardní instalaci
    ;;
  *)
    echo "[ERROR] Neznámý parametr: ${1}. Povolené volby: update, status, rollback, --full, --stack, --no-restart" >&2
    exit 1
    ;;
esac

echo "=== Installing QIS (Qwen Image Studio) ==="

# ---------------------------------------------------------
# 1. Hardware & VRAM Capability Profiler
# ---------------------------------------------------------
echo "-> Detecting GPU and hardware capabilities..."
GPU_NAME="Generic / Unknown GPU"
VRAM_MB=0

if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1 | xargs)
  VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | xargs)
elif command -v rocm-smi >/dev/null 2>&1; then
  GPU_NAME="AMD Radeon (ROCm)"
  VRAM_MB=8192
elif [[ -d "/sys/class/drm" ]]; then
  GPU_NAME="Integrated / Standard Linux DRM"
  VRAM_MB=4096
fi

VRAM_GB=$(( VRAM_MB / 1024 ))
echo "  [HW] Detected: ${GPU_NAME} (${VRAM_MB} MB / ~${VRAM_GB} GB VRAM)"

if (( VRAM_MB >= 14000 )); then
  TIER="Tier S (High-End: >=16 GB VRAM)"
  PROFILE_HINT="Recommended: Full FP8/BF16 models, zero offload needed."
elif (( VRAM_MB >= 7500 )); then
  TIER="Tier A (Performance: 8-12 GB VRAM)"
  PROFILE_HINT="Recommended: GGUF Q4_K_M DiT + Qwen3-VL 8B TE with async VRAM offload."
elif (( VRAM_MB >= 5000 )); then
  TIER="Tier B (Balanced: 6 GB VRAM)"
  PROFILE_HINT="Recommended: GGUF Q3_K_S DiT + Qwen2.5-VL 3B TE with sequential CPU offload."
else
  TIER="Tier C (Entry / iGPU: <=4 GB VRAM)"
  PROFILE_HINT="Recommended: Remote LAN Cluster node or light CPU drafting."
fi

echo "  [Tier] Profile: ${TIER}"
echo "  [Hint] ${PROFILE_HINT}"

# ---------------------------------------------------------
# 2. Check for missing ComfyUI / Models on New Hardware
# ---------------------------------------------------------
COMFY_DIR="${HOME}/.local/share/comfyui"
if [[ ! -d "$COMFY_DIR" || ! -f "${COMFY_DIR}/main.py" ]]; then
  echo ""
  echo "  [!] Nebyl nalezen lokální ComfyUI backend v ${COMFY_DIR}."
  if [[ -t 0 ]]; then
    read -rp "  Chcete nyní automaticky nainstalovat ComfyUI, nody a modely pro ${TIER}? [A/n]: " ans
    if [[ "$ans" =~ ^[AaYy]$ || -z "$ans" ]]; then
      "${SCRIPT_DIR}/scripts/qis-stack.sh" --full
      echo "=== Pokračuji v nasazení QIS pluginu... ==="
    fi
  else
    echo "  Pro instalaci backendu spusťte: ./install.sh --full"
  fi
fi

# ---------------------------------------------------------
# 3. Ensure Directories & Verify Safe Ownership
# ---------------------------------------------------------
ensure_safe_dir() {
  local dir="$1"
  if [[ -L "$dir" ]]; then
    echo "  [ERROR] Directory target is a symlink: $dir" >&2
    exit 1
  fi
  if [[ -e "$dir" ]]; then
    if [[ ! -d "$dir" ]]; then
      echo "  [ERROR] Target exists and is not a directory: $dir" >&2
      exit 1
    fi
    if [[ ! -O "$dir" ]]; then
      echo "  [ERROR] Target directory is not owned by current user: $dir" >&2
      exit 1
    fi
  else
    mkdir -p "$dir"
  fi
}

# Verify plugin directory: must not be a symlink and must be owned by user
if [[ -L "${TARGET_PLUGIN_DIR}" ]]; then
  echo "  [ERROR] Refusing installation: TARGET_PLUGIN_DIR is a symlink (${TARGET_PLUGIN_DIR})" >&2
  exit 1
fi
if [[ -e "${TARGET_PLUGIN_DIR}" ]]; then
  if [[ ! -d "${TARGET_PLUGIN_DIR}" ]]; then
    echo "  [ERROR] Refusing installation: TARGET_PLUGIN_DIR exists and is not a directory." >&2
    exit 1
  fi
  if [[ ! -O "${TARGET_PLUGIN_DIR}" ]]; then
    echo "  [ERROR] Refusing installation: TARGET_PLUGIN_DIR is not owned by current user." >&2
    exit 1
  fi
  # If non-empty, ensure it is not a foreign directory
  if [[ -f "${TARGET_PLUGIN_DIR}/manifest.json" ]]; then
    if ! grep -q '"id": *"simonez.qwenimage"' "${TARGET_PLUGIN_DIR}/manifest.json" 2>/dev/null; then
      echo "  [ERROR] Target directory contains a foreign plugin manifest. Refusing to overwrite." >&2
      exit 1
    fi
  elif [[ ! -f "${TARGET_PLUGIN_DIR}/.installed_hashes" ]]; then
    # Neither manifest nor .installed_hashes exists.
    # Check if there are foreign files other than settings.json
    foreign_items=()
    while IFS= read -r item; do
      [[ -n "$item" && "$item" != "settings.json" ]] && foreign_items+=("$item")
    done < <(ls -A "${TARGET_PLUGIN_DIR}" 2>/dev/null || true)

    if [[ ${#foreign_items[@]} -gt 0 ]]; then
      echo "  [ERROR] Target directory contains unverified foreign files (${foreign_items[*]}). Refusing to overwrite." >&2
      exit 1
    fi
  fi
fi

ensure_safe_dir "${TARGET_PLUGIN_DIR}"
ensure_safe_dir "${PICTURES_DIR}"
ensure_safe_dir "${BIN_DIR}"

# ---------------------------------------------------------
# 4. Deploy Plugin Files
# ---------------------------------------------------------
copy_if_changed() {
  local src="$1"
  local dst="$2"

  # Refuse symlinked targets (catches valid and dangling symlinks)
  if [[ -L "$dst" ]]; then
    echo "  [ERROR] Refusing to overwrite symlinked target: $dst" >&2
    exit 1
  fi

  # If destination exists, verify it is a regular file and owned by current user
  if [[ -e "$dst" ]]; then
    if [[ ! -f "$dst" ]]; then
      echo "  [ERROR] Destination exists and is not a regular file: $dst" >&2
      exit 1
    fi
    if [[ ! -O "$dst" ]]; then
      echo "  [ERROR] Destination is not owned by current user: $dst" >&2
      exit 1
    fi
  fi

  if [[ ! -e "$dst" ]] || ! cmp -s "$src" "$dst"; then
    cp --remove-destination --no-dereference "$src" "$dst"
  fi
}

echo "-> Deploying plugin files to ${TARGET_PLUGIN_DIR}..."
copy_if_changed "${SCRIPT_DIR}/manifest.json" "${TARGET_PLUGIN_DIR}/manifest.json"
copy_if_changed "${SCRIPT_DIR}/BarWidget.qml" "${TARGET_PLUGIN_DIR}/BarWidget.qml"
copy_if_changed "${SCRIPT_DIR}/Panel.qml" "${TARGET_PLUGIN_DIR}/Panel.qml"

ensure_safe_dir "${TARGET_PLUGIN_DIR}/views"
ensure_safe_dir "${TARGET_PLUGIN_DIR}/assets"
for f in "${SCRIPT_DIR}"/views/*; do
  [[ -f "$f" ]] && copy_if_changed "$f" "${TARGET_PLUGIN_DIR}/views/$(basename "$f")"
done
for f in "${SCRIPT_DIR}"/assets/*; do
  [[ -f "$f" ]] && copy_if_changed "$f" "${TARGET_PLUGIN_DIR}/assets/$(basename "$f")"
done

ensure_safe_dir "${TARGET_PLUGIN_DIR}/bin"
ensure_safe_dir "${TARGET_PLUGIN_DIR}/scripts"
copy_if_changed "${SCRIPT_DIR}/scripts/qis-stack.sh" "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
chmod +x "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"

# ---------------------------------------------------------
# 5. Native Bridge Binary (Source Compilation & Cache)
# ---------------------------------------------------------
echo "-> Setting up native Rust bridge..."
if [[ -f "${SCRIPT_DIR}/bin/qwen-bridge" ]]; then
  echo "  [OK] Found local binary"
  copy_if_changed "${SCRIPT_DIR}/bin/qwen-bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
elif [[ -f "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" ]]; then
  echo "  [OK] Found compiled target binary"
  copy_if_changed "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
elif command -v cargo >/dev/null 2>&1 && [[ -d "${SCRIPT_DIR}/rust-bridge" ]]; then
  echo "  -> Compiling rust-bridge from source (release mode)..."
  (cd "${SCRIPT_DIR}/rust-bridge" && cargo build --release)
  copy_if_changed "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
  echo "  [OK] Compiled release binary successfully"
else
  echo "  [ERROR] Rust toolchain (cargo) required to build native bridge on first install!" >&2
  exit 1
fi

chmod 0755 "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"

# ---------------------------------------------------------
# 6. Deploy CLI Tool `qis` into ~/.local/bin
# ---------------------------------------------------------
echo "-> Setting up 'qis' CLI command in ${BIN_DIR}/qis..."
ensure_safe_dir "${BIN_DIR}"
if [[ -L "${BIN_DIR}/qis" ]]; then
  target_link="$(readlink -f "${BIN_DIR}/qis" 2>/dev/null || true)"
  if [[ "${target_link}" == "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" ]]; then
    # Already points to this exact QIS installation, refresh symlink safely
    ln -sf "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
    echo "  [OK] Refreshed existing QIS CLI symlink in ${BIN_DIR}/qis"
  else
    echo "  [SKIP] Pre-existing symlink at ${BIN_DIR}/qis points to '${target_link}'. Leaving foreign path in place."
    echo "         To invoke QIS directly, run: ${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
  fi
elif [[ -e "${BIN_DIR}/qis" ]]; then
  echo "  [SKIP] Pre-existing user command/file detected at ${BIN_DIR}/qis. Leaving foreign path in place."
  echo "         To invoke QIS directly, run: ${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
else
  ln -s "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
  echo "  [OK] Created QIS CLI symlink in ${BIN_DIR}/qis"
fi

# ---------------------------------------------------------
# 7. Initialize Settings & Content Identity Receipt
# ---------------------------------------------------------
SETTINGS_FILE="${TARGET_PLUGIN_DIR}/settings.json"
SETTINGS_NEWLY_CREATED=0

# Refuse symlinked settings target (catches both valid and dangling symlinks)
if [[ -L "$SETTINGS_FILE" ]]; then
  echo "  [ERROR] Refusing symlinked settings target: $SETTINGS_FILE" >&2
  exit 1
fi

if [[ -e "$SETTINGS_FILE" ]]; then
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "  [ERROR] Existing settings path is not a regular file: $SETTINGS_FILE" >&2
    exit 1
  fi
  if [[ ! -O "$SETTINGS_FILE" ]]; then
    echo "  [ERROR] Existing settings file is not owned by current user: $SETTINGS_FILE" >&2
    exit 1
  fi
  echo "  [INFO] Preserving pre-existing user settings in settings.json"
else
  echo '{"language": "cs", "backend_url": "http://127.0.0.1:8188"}' > "$SETTINGS_FILE"
  chmod 0600 "$SETTINGS_FILE"
  echo "  [OK] Initialized default settings (0600)"
  SETTINGS_NEWLY_CREATED=1
fi

# Generate cryptographic content identity hashes for only files actually created/replaced by this installer
(
  cd "${TARGET_PLUGIN_DIR}"
  hash_files=(
    manifest.json
    BarWidget.qml
    Panel.qml
    bin/qwen-bridge
    scripts/qis-stack.sh
    views/*
    assets/*
  )
  if [[ "$SETTINGS_NEWLY_CREATED" -eq 1 ]]; then
    hash_files+=(settings.json)
  fi
  sha256sum "${hash_files[@]}" > .installed_hashes
  chmod 0600 .installed_hashes
)

# Permissions Hardening
find "${TARGET_PLUGIN_DIR}" -type d -exec chmod 0755 {} +
find "${TARGET_PLUGIN_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 "${TARGET_PLUGIN_DIR}/bin/qwen-bridge" "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
chmod 0600 "${SETTINGS_FILE}" "${TARGET_PLUGIN_DIR}/.installed_hashes"

# ---------------------------------------------------------
# 8. Validate Plugin Schema
# ---------------------------------------------------------
echo "-> Validating plugin schema with Omarchy CLI..."
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "${TARGET_PLUGIN_DIR}"
  echo "  [OK] Plugin manifest validated (0 errors)"
fi

# ---------------------------------------------------------
# 9. Register in shell.json if not present
# ---------------------------------------------------------
NEWLY_REGISTERED=0
if [[ -f "$SHELL_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  # Ensure no rogue duplicates in center or left
  tmp_json=$(mktemp)
  chmod 0600 "$tmp_json"
  jq '
    if .bar.layout.center then .bar.layout.center |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end |
    if .bar.layout.left then .bar.layout.left |= map(select((type == "object" and .id != "simonez.qwenimage") or (type == "string" and . != "simonez.qwenimage"))) else . end
  ' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"

  if ! jq -e '.bar.layout.right[]? | select((.id? == "simonez.qwenimage") or (. == "simonez.qwenimage"))' "$SHELL_CONFIG" >/dev/null 2>&1; then
    echo "-> Adding simonez.qwenimage to bar.layout.right in shell.json..."
    tmp_json=$(mktemp)
    chmod 0600 "$tmp_json"
    jq '.bar.layout.right = [{"id": "simonez.qwenimage"}] + .bar.layout.right' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"
    echo "  [OK] shell.json updated"
    NEWLY_REGISTERED=1
  fi
fi

# ---------------------------------------------------------
# 10. Reload / Refresh Shell
# ---------------------------------------------------------
echo "-> Refreshing Omarchy Shell..."
if [[ "${NEWLY_REGISTERED}" == "1" ]] && [[ "${NO_RESTART}" != "1" ]] && [[ -x "/usr/share/omarchy/bin/omarchy-restart-shell" ]]; then
  echo "  [OK] Initial install: restarting shell to display new bar item..."
  /usr/share/omarchy/bin/omarchy-restart-shell || true
elif [[ "${NO_RESTART}" != "1" ]] && command -v omarchy-shell >/dev/null 2>&1; then
  echo "  [OK] Soft refreshing plugin in active shell session..."
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy-shell simonez.qwenimage refresh >/dev/null 2>&1 || true
else
  echo "  [OK] In-app update mode: skipping shell rescan to preserve active panel."
fi

echo "=== QIS (Qwen Image Studio) installed successfully! ==="
echo "Tip: Run 'qis' or 'qis update' anytime to manage your AI stack."
