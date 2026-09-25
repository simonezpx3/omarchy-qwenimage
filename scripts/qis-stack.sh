#!/usr/bin/env bash
# ==============================================================================
# QIS Stack Manager & Lifecycle Updater (Omarchy Linux)
# Handles automated setup, dependency installation, model downloads, and updates
# for QIS (Qwen Image Studio) and ComfyUI ecosystem.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMFY_DIR="${HOME}/.local/share/comfyui"
COMFY_VENV="${COMFY_DIR}/venv"
CHECKPOINT_DIR="${COMFY_DIR}/.qis_checkpoints"

# Colors & Formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info() { echo -e "${BLUE}ℹ${RESET} ${BOLD}${1}${RESET}"; }
log_ok()   { echo -e "${GREEN}✔${RESET} ${1}"; }
log_warn() { echo -e "${YELLOW}⚠${RESET} ${1}"; }
log_err()  { echo -e "${RED}✖${RESET} ${1}"; }

# ---------------------------------------------------------
# Hardware & VRAM Profiling
# ---------------------------------------------------------
detect_hardware() {
    GPU_NAME="Unknown GPU"
    VRAM_MB=0

    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1 | xargs)
        VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 | xargs)
        GPU_VENDOR="nvidia"
    elif command -v rocm-smi >/dev/null 2>&1; then
        GPU_NAME="AMD Radeon (ROCm)"
        VRAM_MB=8192
        GPU_VENDOR="amd"
    elif [[ -d "/sys/class/drm" ]]; then
        GPU_NAME="Standard Linux DRM / iGPU"
        VRAM_MB=4096
        GPU_VENDOR="drm"
    else
        GPU_VENDOR="cpu"
    fi

    if (( VRAM_MB >= 14000 )); then
        HW_TIER="S"
        TIER_DESC="Tier S (>=16 GB VRAM: Full FP8/BF16 weights)"
    elif (( VRAM_MB >= 7500 )); then
        HW_TIER="A"
        TIER_DESC="Tier A (8-12 GB VRAM: GGUF Q4_K_M + Async VRAM Offload)"
    elif (( VRAM_MB >= 5000 )); then
        HW_TIER="B"
        TIER_DESC="Tier B (6 GB VRAM: GGUF Q3_K_S + Sequential Offload)"
    else
        HW_TIER="C"
        TIER_DESC="Tier C (<=4 GB VRAM / iGPU: Remote LAN Cluster or Light CPU)"
    fi
}

# ---------------------------------------------------------
# Inspection & Health Matrix
# ---------------------------------------------------------
check_status() {
    detect_hardware
    echo -e "\n${BOLD}========================================================================${RESET}"
    echo -e "       ${CYAN}QIS (Qwen Image Studio) — Ecosystem Status & Health Matrix${RESET}"
    echo -e "${BOLD}========================================================================${RESET}\n"

    echo -e "${BOLD}Hardware Profile:${RESET}"
    echo -e "  GPU: ${GREEN}${GPU_NAME}${RESET} (${VRAM_MB} MB VRAM)"
    echo -e "  Alokace: ${CYAN}${TIER_DESC}${RESET}\n"

    echo -e "${BOLD}Core Applications:${RESET}"
    if command -v quickshell >/dev/null 2>&1; then
        QS_VER=$(quickshell --version 2>/dev/null | awk '{print $2}' || echo "installed")
        echo -e "  [✔] Quickshell: ${GREEN}${QS_VER}${RESET}"
    else
        echo -e "  [✖] Quickshell: ${RED}Nenalezeno${RESET}"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        HYPR_VER=$(hyprctl version 2>/dev/null | awk '{print $2}' | head -n 1 || echo "installed")
        echo -e "  [✔] Hyprland: ${GREEN}${HYPR_VER}${RESET}"
    else
        echo -e "  [✖] Hyprland: ${RED}Nenalezeno${RESET}"
    fi

    if command -v ollama >/dev/null 2>&1; then
        OLLAMA_VER=$(ollama --version 2>/dev/null | awk '{print $NF}' || echo "installed")
        echo -e "  [✔] Ollama: ${GREEN}${OLLAMA_VER}${RESET}"
    else
        echo -e "  [✖] Ollama: ${RED}Nenalezeno${RESET}"
    fi

    echo -e "\n${BOLD}ComfyUI Diffusion Backend:${RESET}"
    if [[ -d "${COMFY_DIR}" && -f "${COMFY_DIR}/main.py" ]]; then
        echo -e "  [✔] ComfyUI Engine: ${GREEN}${COMFY_DIR}${RESET}"
    else
        echo -e "  [✖] ComfyUI Engine: ${RED}Nenalezeno (${COMFY_DIR})${RESET}"
    fi

    local nodes=("ComfyUI-GGUF" "ComfyUI-GGUF-Qwen3VL-TE" "ComfyUI-WD14-Tagger" "ComfyUI-Autocomplete-Plus")
    for node in "${nodes[@]}"; do
        if [[ -d "${COMFY_DIR}/custom_nodes/${node}" ]]; then
            echo -e "  [✔] Node: ${node}: ${GREEN}Aktivní${RESET}"
        else
            echo -e "  [✖] Node: ${node}: ${RED}Chybí${RESET}"
        fi
    done

    echo -e "\n${BOLD}AI Models (Qwen-Image):${RESET}"
    local dit_model="${COMFY_DIR}/models/diffusion_models/qwen_image_2.1_Q4_K_M.gguf"
    local te_model="${COMFY_DIR}/models/text_encoders/qwen3vl_8b_heretic-Q4_K_M.gguf"
    local vae_model="${COMFY_DIR}/models/vae/qwen_image_2.1_vae_bf16.safetensors"

    if [[ -f "$dit_model" ]]; then
        local sz
        sz=$(du -h "$dit_model" | awk '{print $1}')
        echo -e "  [✔] DiT Model: ${GREEN}qwen_image_2.1_Q4_K_M.gguf (${sz})${RESET}"
    else
        echo -e "  [✖] DiT Model: ${RED}Chybí (${dit_model})${RESET}"
    fi

    if [[ -f "$te_model" || -L "$te_model" ]]; then
        echo -e "  [✔] Text Encoder: ${GREEN}qwen3vl_8b_heretic-Q4_K_M.gguf${RESET}"
    else
        echo -e "  [✖] Text Encoder: ${RED}Chybí (${te_model})${RESET}"
    fi

    if [[ -f "$vae_model" ]]; then
        echo -e "  [✔] VAE: ${GREEN}qwen_image_2.1_vae_bf16.safetensors${RESET}"
    else
        echo -e "  [✖] VAE: ${RED}Chybí (${vae_model})${RESET}"
    fi
}

# ---------------------------------------------------------
# Step 1: Install System Dependencies (Strictly Official Arch - NO AUR)
# ---------------------------------------------------------
install_system_deps() {
    log_info "Instaluji základní systémové závislosti (oficiální Arch repozitáře)..."
    local pkgs=("curl" "jq" "imagemagick" "rsync" "git" "python" "python-pip")
    local needed=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            needed+=("$pkg")
        fi
    done

    if (( ${#needed[@]} > 0 )); then
        echo "Vyžadována instalace balíčků: ${needed[*]}"
        sudo pacman -S --needed --noconfirm "${needed[@]}"
        log_ok "Systémové balíčky úspěšně nainstalovány."
    else
        log_ok "Všechny systémové balíčky jsou již přítomny."
    fi
}

# ---------------------------------------------------------
# Step 2: Install / Setup ComfyUI & Custom Nodes
# ---------------------------------------------------------
install_comfyui() {
    log_info "Příprava ComfyUI v ${COMFY_DIR}..."
    mkdir -p "${COMFY_DIR}" "${COMFY_DIR}/models/diffusion_models" "${COMFY_DIR}/models/text_encoders" "${COMFY_DIR}/models/vae" "${COMFY_DIR}/custom_nodes"

    if [[ ! -f "${COMFY_DIR}/main.py" ]]; then
        log_info "Klonuji oficiální ComfyUI repozitář..."
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFY_DIR}"
    fi

    if [[ ! -d "${COMFY_VENV}" ]]; then
        log_info "Vytvářím izolované virtuální prostředí Pythonu (${COMFY_VENV})..."
        python3 -m venv "${COMFY_VENV}"
        "${COMFY_VENV}/bin/pip" install --upgrade pip
        
        detect_hardware
        if [[ "$GPU_VENDOR" == "nvidia" ]]; then
            log_info "Instaluji PyTorch s akcelerací NVIDIA CUDA..."
            "${COMFY_VENV}/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
        elif [[ "$GPU_VENDOR" == "amd" ]]; then
            log_info "Instaluji PyTorch s akcelerací AMD ROCm..."
            "${COMFY_VENV}/bin/pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
        else
            log_info "Instaluji standardní PyTorch..."
            "${COMFY_VENV}/bin/pip" install torch torchvision torchaudio
        fi

        log_info "Instaluji požadavky ComfyUI..."
        "${COMFY_VENV}/bin/pip" install -r "${COMFY_DIR}/requirements.txt"
    fi

    # Clone required custom nodes
    local nodes=(
        "ComfyUI-GGUF|https://github.com/city96/ComfyUI-GGUF.git"
        "ComfyUI-GGUF-Qwen3VL-TE|https://github.com/pottokao-dotcom/ComfyUI-GGUF-Qwen3VL-TE.git"
        "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git"
        "ComfyUI-Autocomplete-Plus|https://github.com/newtextdoc1111/ComfyUI-Autocomplete-Plus.git"
    )

    for item in "${nodes[@]}"; do
        IFS="|" read -r node_name node_url <<< "$item"
        local target_node="${COMFY_DIR}/custom_nodes/${node_name}"
        if [[ ! -d "$target_node" ]]; then
            log_info "Klonuji uzel ${node_name}..."
            git clone "$node_url" "$target_node"
            if [[ -f "${target_node}/requirements.txt" ]]; then
                "${COMFY_VENV}/bin/pip" install -r "${target_node}/requirements.txt" || true
            fi
        else
            log_ok "Uzel ${node_name} je přítomen."
        fi
    done
    log_ok "ComfyUI a custom nody jsou připraveny."
}

# ---------------------------------------------------------
# Step 3: Download Diffusion Models (Hugging Face with Resume)
# ---------------------------------------------------------
download_models() {
    detect_hardware
    log_info "Kontrola a stahování optimalizovaných modelů pro profil ${HW_TIER}..."

    local diff_dir="${COMFY_DIR}/models/diffusion_models"
    local te_dir="${COMFY_DIR}/models/text_encoders"
    local vae_dir="${COMFY_DIR}/models/vae"
    mkdir -p "$diff_dir" "$te_dir" "$vae_dir"

    # 1. DiT Model (Q4_K_M for Tier S/A, Q3_K_S for Tier B)
    local dit_file="qwen_image_2.1_Q4_K_M.gguf"
    local dit_url="https://huggingface.co/city96/Qwen-Image-2.1-GGUF/resolve/main/qwen_image_2.1_Q4_K_M.gguf"
    if [[ "$HW_TIER" == "B" ]]; then
        dit_file="qwen_image_2.1_Q3_K_S.gguf"
        dit_url="https://huggingface.co/city96/Qwen-Image-2.1-GGUF/resolve/main/qwen_image_2.1_Q3_K_S.gguf"
    fi

    if [[ ! -f "${diff_dir}/${dit_file}" ]]; then
        log_info "Stahuji DiT model ${dit_file} (~3.9 GB)..."
        curl -L -C - --progress-bar -o "${diff_dir}/${dit_file}" "${dit_url}"
        log_ok "DiT model stažen."
    else
        log_ok "DiT model ${dit_file} je již stažen."
    fi

    # 2. Text Encoder (Qwen3-VL 8B Heretic)
    local te_file="qwen3vl_8b_heretic-Q4_K_M.gguf"
    local te_url="https://huggingface.co/maternion/Qwen3-VL-8B-Heretic-GGUF/resolve/main/qwen3vl_8b_heretic-Q4_K_M.gguf"
    if [[ ! -f "${te_dir}/${te_file}" ]]; then
        log_info "Stahuji Text Encoder ${te_file} (~4.7 GB)..."
        curl -L -C - --progress-bar -o "${te_dir}/${te_file}" "${te_url}"
        log_ok "Text Encoder stažen."
    else
        log_ok "Text Encoder ${te_file} je již stažen."
    fi

    # 3. VAE (BF16 Safetensors)
    local vae_file="qwen_image_2.1_vae_bf16.safetensors"
    local vae_url="https://huggingface.co/Comfy-Org/Qwen-Image-2.1_repackaged/resolve/main/split_files/vae/qwen_image_2.1_vae_bf16.safetensors"
    if [[ ! -f "${vae_dir}/${vae_file}" ]]; then
        log_info "Stahuji VAE ${vae_file} (~644 MB)..."
        curl -L -C - --progress-bar -o "${vae_dir}/${vae_file}" "${vae_url}"
        log_ok "VAE staženo."
    else
        log_ok "VAE ${vae_file} je již staženo."
    fi
}

# ---------------------------------------------------------
# Step 4: Setup Ollama Local Translation Assistant
# ---------------------------------------------------------
setup_ollama_models() {
    if command -v ollama >/dev/null 2>&1; then
        log_info "Kontrola lokálních modelů Ollama pro překlad CZ➔EN a prompt-opt..."
        if ! curl -s http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
            log_warn "Ollama server právě neběží na portu 11434. Modely zkontroluji při spuštění."
            return 0
        fi

        local models=("mimo:latest" "qwen2.5-coder:7b")
        for m in "${models[@]}"; do
            log_info "Stahuji/aktualizuji model ${m}..."
            ollama pull "$m" || log_warn "Nepodařilo se stáhnout ${m}, zkusím pokračovat."
        done
        log_ok "Ollama modely ověřeny."
    fi
}

# ---------------------------------------------------------
# UPDATER 1: Update QIS Plugin
# ---------------------------------------------------------
update_qis_plugin() {
    log_info "Aktualizuji QIS Plugin z repozitáře..."
    local src_dir="${SCRIPT_DIR}"
    if [[ ! -d "${src_dir}/.git" ]]; then
        if [[ -d "${HOME}/Projects/omarchy-qwenimage/.git" ]]; then
            src_dir="${HOME}/Projects/omarchy-qwenimage"
        fi
    fi

    if [[ -d "${src_dir}/.git" ]]; then
        git -C "${src_dir}" pull --ff-only || log_warn "Nepodařilo se provést fast-forward git pull."
    fi

    if [[ -x "${src_dir}/install.sh" ]]; then
        log_info "Překládám a instaluji novou verzi pluginu z ${src_dir}..."
        "${src_dir}/install.sh"
    elif [[ -x "${SCRIPT_DIR}/install.sh" ]]; then
        log_info "Překládám a instaluji novou verzi pluginu..."
        "${SCRIPT_DIR}/install.sh"
    fi
    log_ok "QIS Plugin byl úspěšně aktualizován."
}

# ---------------------------------------------------------
# UPDATER 2: Update ComfyUI & Custom Nodes with Rollback Checkpoint
# ---------------------------------------------------------
update_comfyui() {
    if [[ ! -d "${COMFY_DIR}/.git" ]]; then
        log_warn "ComfyUI adresář není git repozitář (${COMFY_DIR})."
        return 0
    fi

    log_info "Vytvářím kontrolní bod před aktualizací ComfyUI..."
    mkdir -p "${CHECKPOINT_DIR}"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local cur_commit
    cur_commit=$(git -C "${COMFY_DIR}" rev-parse HEAD)
    echo "$cur_commit" > "${CHECKPOINT_DIR}/comfy_last_known_good_${ts}.txt"
    echo "$cur_commit" > "${CHECKPOINT_DIR}/latest_checkpoint.txt"

    log_info "Aktualizuji ComfyUI jádro..."
    git -C "${COMFY_DIR}" pull --ff-only || log_warn "ComfyUI core pull narazil na změny."

    log_info "Aktualizuji custom nody..."
    for node_dir in "${COMFY_DIR}/custom_nodes"/*; do
        if [[ -d "${node_dir}/.git" ]]; then
            local nname
            nname=$(basename "$node_dir")
            log_info "  -> ${nname}"
            git -C "$node_dir" pull --ff-only || true
            if [[ -f "${node_dir}/requirements.txt" && -x "${COMFY_VENV}/bin/pip" ]]; then
                "${COMFY_VENV}/bin/pip" install -U -r "${node_dir}/requirements.txt" || true
            fi
        fi
    done

    # Re-install core requirements
    if [[ -f "${COMFY_DIR}/requirements.txt" && -x "${COMFY_VENV}/bin/pip" ]]; then
        "${COMFY_VENV}/bin/pip" install -U -r "${COMFY_DIR}/requirements.txt" || true
    fi

    log_ok "ComfyUI a nody byly aktualizovány na nejnovější verzi."
}

# ---------------------------------------------------------
# Rollback ComfyUI to Previous Checkpoint
# ---------------------------------------------------------
rollback_comfyui() {
    local cp_file="${CHECKPOINT_DIR}/latest_checkpoint.txt"
    if [[ -f "$cp_file" ]]; then
        local target_commit
        target_commit=$(cat "$cp_file" | xargs)
        log_warn "Vracím ComfyUI do kontrolního bodu: ${target_commit}..."
        git -C "${COMFY_DIR}" checkout "$target_commit"
        log_ok "ComfyUI bylo úspěšně vráceno do předchozího funkčního stavu."
    else
        log_err "Nenalezen žádný předchozí kontrolní bod v ${CHECKPOINT_DIR}."
    fi
}

# ---------------------------------------------------------
# Interactive Menu
# ---------------------------------------------------------
interactive_menu() {
    while true; do
        detect_hardware
        echo -e "\n${BOLD}========================================================================${RESET}"
        echo -e "         ${CYAN}QIS (Qwen Image Studio) — Setup & Lifecycle Manager${RESET}"
        echo -e "${BOLD}========================================================================${RESET}"
        echo -e "Hardware: ${GREEN}${GPU_NAME}${RESET} | Profil: ${CYAN}${TIER_DESC}${RESET}\n"
        echo -e "  ${BOLD}[1]${RESET} 🚀 ${BOLD}Kompletní instalace všeho${RESET} (Balíčky, ComfyUI, nody, modely)"
        echo -e "  ${BOLD}[2]${RESET} 🔄 ${BOLD}Aktualizovat VŠECHNO${RESET} (QIS plugin, ComfyUI, nody, modely)"
        echo -e "  ${BOLD}[3]${RESET} 🎨 Aktualizovat pouze QIS Plugin (UI a Rust bridge)"
        echo -e "  ${BOLD}[4]${RESET} 🧩 Aktualizovat pouze ComfyUI Engine a Custom Nody"
        echo -e "  ${BOLD}[5]${RESET} 📦 Stáhnout / Zkontrolovat AI Modely (HuggingFace)"
        echo -e "  ${BOLD}[6]${RESET} 📊 Zobrazit stav a matici závislostí"
        echo -e "  ${BOLD}[7]${RESET} ⏪ Záchranný Rollback ComfyUI (návrat do funkčního bodu)"
        echo -e "  ${BOLD}[0]${RESET} 🚪 Ukončit\n"

        read -rp "Zadejte volbu [0-7]: " choice
        case "$choice" in
            1)
                install_system_deps
                install_comfyui
                download_models
                setup_ollama_models
                "${SCRIPT_DIR}/install.sh"
                log_ok "Kompletní instalace dokončena!"
                ;;
            2)
                update_qis_plugin
                update_comfyui
                setup_ollama_models
                log_ok "Vše bylo úspěšně aktualizováno!"
                ;;
            3)
                update_qis_plugin
                ;;
            4)
                update_comfyui
                ;;
            5)
                download_models
                ;;
            6)
                check_status
                ;;
            7)
                rollback_comfyui
                ;;
            0)
                echo "Nashledanou!"
                exit 0
                ;;
            *)
                echo "Neplatná volba."
                ;;
        esac
    done
}

# ---------------------------------------------------------
# CLI Router
# ---------------------------------------------------------
case "${1:-}" in
    status)
        check_status
        ;;
    setup|install|--full)
        install_system_deps
        install_comfyui
        download_models
        setup_ollama_models
        "${SCRIPT_DIR}/install.sh"
        ;;
    update|--update)
        case "${2:-all}" in
            plugin)
                update_qis_plugin
                ;;
            comfy)
                update_comfyui
                ;;
            models)
                download_models
                ;;
            all|*)
                update_qis_plugin
                update_comfyui
                setup_ollama_models
                ;;
        esac
        ;;
    rollback)
        rollback_comfyui
        ;;
    models)
        download_models
        ;;
    *)
        interactive_menu
        ;;
esac
