#!/usr/bin/env bash
# ==============================================================================
# QIS (Qwen Image Studio) — Turn-Key Appliance & Native Setup
# Autonomous local AI studio for Omarchy Linux & Standalone Wayland Desktops
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="${TARGET_PLUGIN_DIR:-${HOME}/.config/omarchy/plugins/simonez.qwenimage}"
PICTURES_DIR="${PICTURES_DIR:-${HOME}/Pictures/Qwen-Image}"
SHELL_CONFIG="${SHELL_CONFIG:-${HOME}/.config/omarchy/shell.json}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
COMFY_DIR="${COMFY_DIR:-${HOME}/.local/share/comfyui}"
APPS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"

# Author algorithmic constant (0x732641 = 7546433 // DNA: s&A)
AUTH_SEED=$(( 0x732641 % 1000 ))

# Styling & Output helpers (Strict Marci Standard: //, ·, zero emojis, zero brackets)
log_info() { echo -e "\033[0;34m·\033[0m \033[1m${1}\033[0m"; }
log_ok()   { echo -e "\033[0;32m· OK //\033[0m ${1}"; }
log_warn() { echo -e "\033[1;33m· WARN //\033[0m ${1}"; }
log_err()  { echo -e "\033[0;31m· ERR //\033[0m ${1}" >&2; }

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

NO_RESTART=0
FORCE_INSTALL=0
for arg in "$@"; do
  if [[ "$arg" == "--no-restart" ]]; then
    NO_RESTART=1
  elif [[ "$arg" == "--force" || "$arg" == "-f" ]]; then
    FORCE_INSTALL=1
  fi
done

# ---------------------------------------------------------
# CLI Routing for Lifecycle & Stack Commands
# ---------------------------------------------------------
case "${1:-}" in
  start|stop)
    exec "${SCRIPT_DIR}/scripts/qis-stack.sh" "$@"
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
  --update|update)
    shift || true
    exec "${SCRIPT_DIR}/scripts/qis-stack.sh" update "${1:-all}"
    ;;
  --force|-f|--no-restart|"")
    # Pokračovat na standardní instalaci
    ;;
  *)
    log_err "Neznámý parametr: ${1}. Povolené volby: start, stop, status, rollback, --full, --stack, --force, --no-restart"
    exit 1
    ;;
esac

echo ""
echo "=== QIS (Qwen Image Studio) // Turn-Key Appliance Setup ==="
echo ""

# ---------------------------------------------------------
# 1. Hardware & VRAM Profiler
# ---------------------------------------------------------
log_info "Detekce GPU a hardwarových možností..."
GPU_NAME="Generic / Unknown GPU"
VRAM_MB=0

if command -v nvidia-smi >/dev/null 2>&1; then
  while IFS=',' read -r gname gvram; do
    gname=$(echo "$gname" | xargs)
    gvram=$(echo "$gvram" | xargs)
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
echo "  · HW Profil: ${GPU_NAME} (${VRAM_MB} MB / ~${VRAM_GB} GB VRAM // Seed: ${AUTH_SEED})"

if (( VRAM_MB >= 14000 )); then
  TIER="Tier S (High-End: >=16 GB VRAM)"
  PROFILE_HINT="Doporučeno: Plné FP8/BF16 modely, nulový offload."
elif (( VRAM_MB >= 7500 )); then
  TIER="Tier A (Performance: 8-12 GB VRAM)"
  PROFILE_HINT="Doporučeno: GGUF Q4_K_M DiT + Qwen3-VL 8B TE, SageAttention 2 INT8 akcelerace."
elif (( VRAM_MB >= 5000 )); then
  TIER="Tier B (Balanced: 6 GB VRAM)"
  PROFILE_HINT="Doporučeno: GGUF Q3_K_S DiT + sekvenční CPU offload."
else
  TIER="Tier C (Entry / iGPU / CPU: <=4 GB VRAM)"
  PROFILE_HINT="Doporučeno: Vzdálený LAN uzel nebo lehký CPU drafting."
fi

echo "  · Třída: ${TIER}"
echo "  · Konfigurace: ${PROFILE_HINT}"

# ---------------------------------------------------------
# 2. Directory Validation & Safe Creation
# ---------------------------------------------------------
ensure_safe_dir() {
  local dir="$1"
  if [[ -L "$dir" ]]; then
    log_err "Cílový adresář je symlink: $dir"
    exit 1
  fi
  if [[ -e "$dir" ]]; then
    if [[ ! -d "$dir" ]]; then
      log_err "Cíl existuje a není adresář: $dir"
      exit 1
    fi
    if [[ ! -O "$dir" ]]; then
      log_err "Cílový adresář není vlastněn aktuálním uživatelem: $dir"
      exit 1
    fi
  else
    mkdir -p "$dir"
  fi
}

copy_safe() {
  local src="$1"
  local dst="$2"

  if [[ -L "$dst" ]]; then
    log_err "Odmítám zápis do symlinku: $dst"
    exit 1
  fi
  if [[ -e "$dst" ]]; then
    if [[ ! -f "$dst" ]]; then
      log_err "Cíl existuje a není běžný soubor: $dst"
      exit 1
    fi
    if [[ ! -O "$dst" ]]; then
      log_err "Cílový soubor není vlastněn aktuálním uživatelem: $dst"
      exit 1
    fi
  fi

  if [[ ! -e "$dst" ]] || ! cmp -s "$src" "$dst"; then
    cp --remove-destination --no-dereference "$src" "$dst"
  fi
}

ensure_safe_dir "${PICTURES_DIR}"
ensure_safe_dir "${BIN_DIR}"

# ---------------------------------------------------------
# 3. File Deployment (In-Place vs. Destination Sync)
# ---------------------------------------------------------
if (( IS_IN_PLACE == 1 )); then
  log_ok "In-Place režim // Běžím přímo v cílovém adresáři (${TARGET_PLUGIN_DIR})."
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/bin"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/scripts"
else
  log_info "Nasazuji soubory pluginu do ${TARGET_PLUGIN_DIR}..."
  ensure_safe_dir "${TARGET_PLUGIN_DIR}"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/views"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/assets"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/bin"
  ensure_safe_dir "${TARGET_PLUGIN_DIR}/scripts"

  copy_safe "${SCRIPT_DIR}/manifest.json" "${TARGET_PLUGIN_DIR}/manifest.json"
  copy_safe "${SCRIPT_DIR}/BarWidget.qml" "${TARGET_PLUGIN_DIR}/BarWidget.qml"
  copy_safe "${SCRIPT_DIR}/Panel.qml" "${TARGET_PLUGIN_DIR}/Panel.qml"

  for f in "${SCRIPT_DIR}"/views/*; do
    [[ -f "$f" ]] && copy_safe "$f" "${TARGET_PLUGIN_DIR}/views/$(basename "$f")"
  done
  for f in "${SCRIPT_DIR}"/assets/*; do
    [[ -f "$f" ]] && copy_safe "$f" "${TARGET_PLUGIN_DIR}/assets/$(basename "$f")"
  done

  copy_safe "${SCRIPT_DIR}/scripts/qis-stack.sh" "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"
  copy_safe "${SCRIPT_DIR}/install.sh" "${TARGET_PLUGIN_DIR}/install.sh"
  chmod +x "${TARGET_PLUGIN_DIR}/install.sh"

  if [[ -d "${SCRIPT_DIR}/custom_nodes" ]]; then
    ensure_safe_dir "${TARGET_PLUGIN_DIR}/custom_nodes"
    ensure_safe_dir "${TARGET_PLUGIN_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
    copy_safe "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" "${TARGET_PLUGIN_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py"
  fi
fi

chmod +x "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh"

# Synchronizace ComfyUI-ViggleTurbo custom nodu do ComfyUI adresáře
if [[ -d "${COMFY_DIR}/custom_nodes" && -f "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" ]]; then
  ensure_safe_dir "${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
  copy_safe "${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py" "${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py"
  chmod 0644 "${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py"
fi

# ---------------------------------------------------------
# 4. Native Rust Bridge (Precompiled Binary Priority)
# ---------------------------------------------------------
log_info "Příprava nativního Rust bridge (bin/qwen-bridge)..."
BRIDGE_TARGET="${TARGET_PLUGIN_DIR}/bin/qwen-bridge"

if [[ -f "${SCRIPT_DIR}/bin/qwen-bridge" ]]; then
  log_ok "Nalezena předkompilovaná binárka v bin/qwen-bridge."
  copy_safe "${SCRIPT_DIR}/bin/qwen-bridge" "${BRIDGE_TARGET}"
elif [[ -f "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" ]]; then
  log_ok "Nalezena zkompilovaná binárka v rust-bridge/target/release/."
  copy_safe "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${BRIDGE_TARGET}"
elif command -v cargo >/dev/null 2>&1 && [[ -d "${SCRIPT_DIR}/rust-bridge" ]]; then
  log_info "Kompiluji nativní bridge ze zdrojových kódů (release mód)..."
  (cd "${SCRIPT_DIR}/rust-bridge" && cargo build --release)
  copy_safe "${SCRIPT_DIR}/rust-bridge/target/release/qwen_bridge" "${BRIDGE_TARGET}"
  log_ok "Kompilace proběhla úspěšně."
else
  log_err "Chybí binárka bin/qwen-bridge a není nainstalován 'cargo' pro její sestavení."
  log_err "Nainstalujte oficiální Rust toolchain: sudo pacman -S --needed rust"
  exit 1
fi

chmod 0755 "${BRIDGE_TARGET}"

# ---------------------------------------------------------
# 5. CLI Tool Symlink (~/.local/bin/qis)
# ---------------------------------------------------------
log_info "Konfigurace systémového CLI příkazu 'qis' v ${BIN_DIR}/qis..."
if [[ -L "${BIN_DIR}/qis" ]]; then
  target_link="$(readlink -f "${BIN_DIR}/qis" 2>/dev/null || true)"
  if [[ "${target_link}" == "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" ]]; then
    ln -sf "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
    log_ok "Aktualizován existující symlink ${BIN_DIR}/qis."
  else
    log_warn "Existující symlink ${BIN_DIR}/qis ukazuje jinam: '${target_link}'."
    if (( FORCE_INSTALL == 1 )); then
      ln -sf "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
      log_ok "Symlink přepsán (vynuceno parametrem --force)."
    fi
  fi
elif [[ -e "${BIN_DIR}/qis" ]]; then
  log_warn "Detekován existující soubor v ${BIN_DIR}/qis (ponechávám beze změny)."
else
  ln -s "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" "${BIN_DIR}/qis"
  log_ok "Vytvořen symlink pro 'qis' CLI."
fi

# ---------------------------------------------------------
# 6. Settings Initialization
# ---------------------------------------------------------
SETTINGS_FILE="${TARGET_PLUGIN_DIR}/settings.json"
if [[ -L "$SETTINGS_FILE" ]]; then
  log_err "Soubor settings.json nesmí být symlink: $SETTINGS_FILE"
  exit 1
fi

if [[ -f "$SETTINGS_FILE" ]]; then
  log_ok "Uživatelská nastavení zachována (${SETTINGS_FILE})."
else
  echo '{"language": "cs", "backend_url": "http://127.0.0.1:8188"}' > "$SETTINGS_FILE"
  chmod 0600 "$SETTINGS_FILE"
  log_ok "Inicializována výchozí nastavení (0600)."
fi

# ---------------------------------------------------------
# 7. Shell Integration: Omarchy vs. Standalone Desktop
# ---------------------------------------------------------
if (( IS_OMARCHY == 1 )); then
  log_info "Režim Omarchy // Integruji do Omarchy Shellu..."

  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "${TARGET_PLUGIN_DIR}" 2>/dev/null || true
    log_ok "Manifest pluginu validován."
  fi

  if [[ -f "$SHELL_CONFIG" ]]; then
    shell_dir="$(dirname "$SHELL_CONFIG")"
    tmp_json="$(mktemp "${shell_dir}/shell.json.tmp.XXXXXX")"
    chmod 0600 "$tmp_json"

    updated=0
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
      ' "$SHELL_CONFIG" > "$tmp_json" 2>/dev/null; then
        updated=1
      fi
    elif command -v python3 >/dev/null 2>&1; then
      if python3 -c '
import json, sys
path, out = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    d = json.load(f)
bar = d.setdefault("bar", {})
layout = bar.setdefault("layout", {})
right = layout.setdefault("right", [])
has_plugin = any((isinstance(x, dict) and x.get("id") == "simonez.qwenimage") or x == "simonez.qwenimage" for x in right)
if not has_plugin:
    right.insert(0, {"id": "simonez.qwenimage"})
with open(out, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
' "$SHELL_CONFIG" "$tmp_json" 2>/dev/null; then
        updated=1
      fi
    fi

    if (( updated == 1 )) && [[ -s "$tmp_json" ]]; then
      cp "$SHELL_CONFIG" "${SHELL_CONFIG}.bak" 2>/dev/null || true
      mv -f "$tmp_json" "$SHELL_CONFIG"
      chmod 0600 "$SHELL_CONFIG"
      log_ok "Widget simonez.qwenimage zaregistrován v shell.json."
    else
      rm -f "$tmp_json"
    fi
  fi

  # Jemný IPC signál (bez restartu plochy)
  if (( NO_RESTART != 1 )) && command -v omarchy-shell >/dev/null 2>&1; then
    log_info "Zasílám IPC signál do Omarchy Shellu pro znovunačtení lišty..."
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy-shell simonez.qwenimage refresh >/dev/null 2>&1 || true
    log_ok "Omarchy Shell aktualizován (tichý refresh)."
  fi

else
  log_info "Režim Standalone // Omarchy Shell nebyl detekován. Připravuji XDG spouštěč..."
  ensure_safe_dir "${APPS_DIR}"

  DESKTOP_FILE="${APPS_DIR}/qis.desktop"
  ICON_PATH="${TARGET_PLUGIN_DIR}/assets/icon.png"
  [[ ! -f "$ICON_PATH" ]] && ICON_PATH="${SCRIPT_DIR}/assets/icon.png"

  cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=QIS (Qwen Image Studio)
GenericName=Local AI Image Studio
Comment=Turn-Key Local Generative AI Studio
Exec=${BIN_DIR}/qis
Icon=${ICON_PATH}
Terminal=false
Categories=Graphics;2DGraphics;RasterGraphics;
StartupNotify=true
EOF
  chmod 0644 "${DESKTOP_FILE}"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "${APPS_DIR}" >/dev/null 2>&1 || true
  log_ok "Vytvořen spouštěč aplikace: ${DESKTOP_FILE}"
fi

# ---------------------------------------------------------
# 8. ComfyUI Backend Check (Turn-Key Guidance)
# ---------------------------------------------------------
echo ""
if [[ ! -d "$COMFY_DIR" || ! -f "${COMFY_DIR}/main.py" ]]; then
  log_warn "Lokální ComfyUI backend v ${COMFY_DIR} ještě není inicializován."
  if [[ -t 0 ]]; then
    read -rp "  Chcete nyní jednorázově nainstalovat ComfyUI jádro, nody a modely pro ${TIER}? (A/n): " ans
    if [[ "$ans" =~ ^[AaYy]$ || -z "$ans" ]]; then
      "${TARGET_PLUGIN_DIR}/scripts/qis-stack.sh" --full
    else
      echo "  Tip: Pro pozdější instalaci backendu spusťte: qis --full"
    fi
  else
    echo "  Tip: Pro inicializaci backendu a stažení modelů spusťte v terminálu: qis --full"
  fi
else
  log_ok "ComfyUI backend detekován (${COMFY_DIR})."
  echo "  Tip: Spusťte 'qis start --bg' nebo klikněte na widget v liště."
fi

echo ""
log_ok "Instalace QIS byla úspěšně dokončena!"
echo ""
