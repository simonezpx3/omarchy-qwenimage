#!/usr/bin/env bash
# QIS (Qwen Image Studio) — Universal Installation & Hardware Profiler for Omarchy Linux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/simonez.qwenimage"
PICTURES_DIR="${HOME}/Pictures/Qwen-Image"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"

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
# 2. Ensure Directories
# ---------------------------------------------------------
mkdir -p "${TARGET_PLUGIN_DIR}" "${PICTURES_DIR}"

# ---------------------------------------------------------
# 3. Deploy Plugin Files
# ---------------------------------------------------------
echo "-> Deploying plugin files to ${TARGET_PLUGIN_DIR}..."
cp "${SCRIPT_DIR}/manifest.json" "${TARGET_PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/BarWidget.qml" "${TARGET_PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/Panel.qml" "${TARGET_PLUGIN_DIR}/"
cp -r "${SCRIPT_DIR}/views" "${TARGET_PLUGIN_DIR}/"
cp -r "${SCRIPT_DIR}/assets" "${TARGET_PLUGIN_DIR}/"
mkdir -p "${TARGET_PLUGIN_DIR}/bin"

# ---------------------------------------------------------
# 4. Native Bridge Binary (Source Compilation & Cache)
# ---------------------------------------------------------
echo "-> Setting up native Rust bridge..."
if [[ -f "${SCRIPT_DIR}/bin/qwen-bridge" ]]; then
  echo "  [OK] Found local binary"
  cp "${SCRIPT_DIR}/bin/qwen-bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
elif [[ -f "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" ]]; then
  echo "  [OK] Found compiled target binary"
  cp "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
elif command -v cargo >/dev/null 2>&1 && [[ -d "${SCRIPT_DIR}/rust-bridge" ]]; then
  echo "  -> Compiling rust-bridge from source (release mode)..."
  (cd "${SCRIPT_DIR}/rust-bridge" && cargo build --release)
  cp "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
  echo "  [OK] Compiled release binary successfully"
else
  echo "  [ERROR] Rust toolchain (cargo) required to build native bridge on first install!" >&2
  exit 1
fi

chmod 0755 "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"

# ---------------------------------------------------------
# 5. Initialize Settings
# ---------------------------------------------------------
SETTINGS_FILE="${TARGET_PLUGIN_DIR}/settings.json"
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo '{"language": "cs", "backend_url": "http://127.0.0.1:8188"}' > "$SETTINGS_FILE"
  chmod 0600 "$SETTINGS_FILE"
  echo "  [OK] Initialized default settings (0600)"
fi

# Permissions Hardening
find "${TARGET_PLUGIN_DIR}" -type d -exec chmod 0755 {} +
find "${TARGET_PLUGIN_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 "${TARGET_PLUGIN_DIR}/bin/qwen-bridge"
chmod 0600 "${SETTINGS_FILE}"

# ---------------------------------------------------------
# 6. Validate Plugin Schema
# ---------------------------------------------------------
echo "-> Validating plugin schema with Omarchy CLI..."
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "${TARGET_PLUGIN_DIR}"
  echo "  [OK] Plugin manifest validated (0 errors)"
fi

# ---------------------------------------------------------
# 7. Register in shell.json if not present
# ---------------------------------------------------------
if [[ -f "$SHELL_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  if ! jq -e '.bar.layout.right[]? | select((.id? == "simonez.qwenimage") or (. == "simonez.qwenimage"))' "$SHELL_CONFIG" >/dev/null 2>&1; then
    echo "-> Adding simonez.qwenimage to bar.layout.right in shell.json..."
    tmp_json=$(mktemp)
    chmod 0600 "$tmp_json"
    jq '.bar.layout.right = [{"id": "simonez.qwenimage"}] + .bar.layout.right' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"
    echo "  [OK] shell.json updated"
  fi
fi

# ---------------------------------------------------------
# 8. Reload / Restart Shell
# ---------------------------------------------------------
echo "-> Reloading Omarchy Shell..."
if [[ -x "/usr/share/omarchy/bin/omarchy-restart-shell" ]]; then
  /usr/share/omarchy/bin/omarchy-restart-shell || true
elif command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins || true
  omarchy-shell simonez.qwenimage refresh || true
fi

echo "=== QIS (Qwen Image Studio) installed successfully! ==="
