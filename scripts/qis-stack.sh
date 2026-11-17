#!/usr/bin/env bash
# ==============================================================================
# QIS Stack Manager & Lifecycle Updater (Omarchy Linux)
# Handles automated setup, dependency installation, model downloads, and updates
# for QIS (Qwen Image Studio) and ComfyUI ecosystem.
# ==============================================================================
set -euo pipefail

if (( EUID == 0 )); then
    echo -e "\033[0;31m· ERR //\033[0m Running as root (EUID 0) is forbidden. Run this script as a regular user." >&2
    exit 1
fi

_self_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$_self_path")/.." && pwd)"
COMFY_DIR="${COMFY_DIR:-${HOME}/.local/share/comfyui}"
if [[ -d "${COMFY_DIR}/.venv" && ! -d "${COMFY_DIR}/venv" ]]; then
    COMFY_VENV="${COMFY_DIR}/.venv"
else
    COMFY_VENV="${COMFY_VENV:-${COMFY_DIR}/venv}"
fi
CHECKPOINT_DIR="${CHECKPOINT_DIR:-${COMFY_DIR}/.qis_checkpoints}"

# Deterministic & pinned upstream revisions (Omarchy Marketplace Security Baseline)
COMFY_PINNED_COMMIT="b53f77a74e21091cbdebfdf7b85fc80326932646" # ComfyUI v0.41.2
NODE_GGUF_COMMIT="6ea2651e7df66d7585f6ffee804b20e92fb38b8a"
NODE_QWEN3VL_COMMIT="1f52b004e3ff096491f5d0067c6fef72992df841"
NODE_WD14_COMMIT="9e0a6e700299182fc05c58b62e7ad9f72182a78b"
NODE_AUTOCOMPLETE_COMMIT="9cfd2aceb0205132942b6dc1e237a2377de92018"

# Pinned Hugging Face model revisions & digests (Marketplace Supply Chain Baseline)
HF_DIT_COMMIT="c9dd12108f53974cd1e0abd708df042d6df0ca8d"
HF_DIT_Q4_SHA256="dc956c958fbfa1d5c64ec316d7e865283d17d97a9eb332a4a74a4d63afaae9a5"
HF_DIT_Q3_SHA256="dc34f493dd56fdd665922163c94d51fbe28d2a1f61a941060e167b3a58b00167"

HF_TE_COMMIT="4b783256015cca4020842afb7e636f24e0f8d447"
HF_TE_SHA256="1338274ac7a6344f262a16c7a52d1bd7fe789307d252733b23ea421126e5d343"

HF_VAE_COMMIT="9a44dbdb47cefd046be9c0a13476192f34c8db8e"
HF_VAE_SHA256="bb21f7473051e1ac368515dd3f2e15cd44d7a11748ee8823e1ddca3e4876b7c9"

# LoRA Adapters & Acceleration Nodes (Marketplace Supply Chain Baseline)
HF_VIGGLE_COMMIT="009a44a895ef85f7e643c80fdca9543795248867"
HF_VIGGLE_NODE_SHA256="0592defd8ee6555b8c02bd9b287514849b1d46f579f47f8c7f711e6411f89587"
HF_VIGGLE_TURBO_LORA_SHA256="0c98591700346f9777051d4e6fa29aa94519abec0d85b1f1f672a2a3db8c94b3"

HF_UNCENSORED_COMMIT="6b34e59458d3eb7ba6a6f86a116aed5253dc02c3"
HF_UNCENSORED_LORA_SHA256="00ee2cb7f00a37b097640c1880ed0d17e368e30599f34bb348fee0e8c2cc4ca1"

HF_ANIME_COMMIT="c4ab5473bfdf585fc19cfd1e280f79d2b0c79947"
HF_ANIME_LORA_SHA256="0c171eb802ea8051b511f2d93c1743eeadd030316255aa98fa65d40809366752"

# Neural AI Upscale Models (RealESRGAN_x4plus, 4x-UltraSharp, 4x-AnimeSharp)
HF_ESRGAN_COMMIT="5fd49b7b278836f48af63ecd314d0f98ab336105"
HF_ESRGAN_SHA256="37f9a931c215f040aa6d50f711f2cb115f713c46df1d0d6469a8bd7bfe9a60bb"
HF_ULTRASHARP_COMMIT="69c656372579df646399b3353982e0fb5cfcbb79"
HF_ULTRASHARP_SHA256="36a340b5509b699d2c06cb445ddc1d3d39199ac734d889ed6d7915f60e05bcbc"
HF_ANIMESHARP_COMMIT="94d4d8ef55601dfa83d73507b538ef8d910feea0"
HF_ANIMESHARP_SHA256="7fc60054d291579acac4fb537efd91c80611cbd281ef8b90f434048cc1313b39"

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
    GPU_VENDOR="cpu"

    if command -v nvidia-smi >/dev/null 2>&1; then
        while IFS=',' read -r gname gvram; do
            gname=$(echo "$gname" | xargs)
            gvram=$(echo "$gvram" | xargs)
            if [[ "$gvram" =~ ^[0-9]+$ ]] && (( gvram > VRAM_MB )); then
                VRAM_MB=$gvram
                GPU_NAME="$gname"
                GPU_VENDOR="nvidia"
            fi
        done < <(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null || true)
    fi

    if (( VRAM_MB == 0 )) && command -v rocm-smi >/dev/null 2>&1; then
        GPU_VENDOR="amd"
        GPU_NAME="AMD Radeon (ROCm)"
        for vram_file in /sys/class/drm/card*/device/mem_info_vram_total; do
            if [[ -f "$vram_file" ]]; then
                local bytes
                bytes=$(cat "$vram_file" 2>/dev/null || echo 0)
                if [[ "$bytes" =~ ^[0-9]+$ ]] && (( bytes > 0 )); then
                    local mb=$(( bytes / 1048576 ))
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
                local bytes
                bytes=$(cat "$vram_file" 2>/dev/null || echo 0)
                if [[ "$bytes" =~ ^[0-9]+$ ]] && (( bytes > 0 )); then
                    local mb=$(( bytes / 1048576 ))
                    if (( mb > VRAM_MB )); then
                        VRAM_MB=$mb
                        GPU_NAME="Linux DRM Device (${mb} MB)"
                        GPU_VENDOR="drm"
                    fi
                fi
            fi
        done
    fi

    if (( VRAM_MB == 0 )); then
        GPU_VENDOR="cpu"
        GPU_NAME="CPU / Standard System Memory"
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
        TIER_DESC="Tier C (<=4 GB VRAM / iGPU / CPU: Remote LAN Cluster or Light CPU)"
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
    echo -e "  Allocation: ${CYAN}${TIER_DESC}${RESET}\n"

    echo -e "${BOLD}Core Applications:${RESET}"
    if command -v quickshell >/dev/null 2>&1; then
        QS_VER=$(quickshell --version 2>/dev/null | awk '{print $2}' || echo "installed")
        echo -e "  OK // Quickshell: ${GREEN}${QS_VER}${RESET}"
    else
        echo -e "  ERR // Quickshell: ${RED}Not found${RESET}"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        HYPR_VER=$(hyprctl version 2>/dev/null | awk '{print $2}' | head -n 1 || echo "installed")
        echo -e "  OK // Hyprland: ${GREEN}${HYPR_VER}${RESET}"
    else
        echo -e "  ERR // Hyprland: ${RED}Not found${RESET}"
    fi

    if command -v ollama >/dev/null 2>&1; then
        OLLAMA_VER=$(ollama --version 2>/dev/null | awk '{print $NF}' || echo "installed")
        echo -e "  OK // Ollama: ${GREEN}${OLLAMA_VER}${RESET}"
    else
        echo -e "  ERR // Ollama: ${RED}Not found${RESET}"
    fi

    echo -e "\n${BOLD}ComfyUI Diffusion Backend:${RESET}"
    if [[ -d "${COMFY_DIR}" && -f "${COMFY_DIR}/main.py" ]]; then
        echo -e "  OK // ComfyUI Engine: ${GREEN}${COMFY_DIR}${RESET}"
    else
        echo -e "  ERR // ComfyUI Engine: ${RED}Nenalezeno (${COMFY_DIR})${RESET}"
    fi

    local nodes=("ComfyUI-GGUF" "ComfyUI-GGUF-Qwen3VL-TE" "ComfyUI-WD14-Tagger" "ComfyUI-Autocomplete-Plus" "ComfyUI-ViggleTurbo")
    for node in "${nodes[@]}"; do
        if [[ -d "${COMFY_DIR}/custom_nodes/${node}" ]]; then
            echo -e "  OK // Node: ${node}: ${GREEN}Active${RESET}"
        else
            echo -e "  ERR // Node: ${node}: ${RED}Missing${RESET}"
        fi
    done

    echo -e "\n${BOLD}AI Models (Qwen-Image):${RESET}"
    local dit_model="${COMFY_DIR}/models/diffusion_models/qwen_image_2.1_Q4_K_M.gguf"
    local te_model="${COMFY_DIR}/models/text_encoders/qwen3vl_8b_heretic-Q4_K_M.gguf"
    local vae_model="${COMFY_DIR}/models/vae/qwen_image_2.1_vae_bf16.safetensors"

    if [[ -f "$dit_model" ]]; then
        local sz
        sz=$(du -h "$dit_model" | awk '{print $1}')
        echo -e "  OK // DiT Model: ${GREEN}qwen_image_2.1_Q4_K_M.gguf (${sz})${RESET}"
    else
        echo -e "  ERR // DiT Model: ${RED}Missing (${dit_model})${RESET}"
    fi

    if [[ -f "$te_model" || -L "$te_model" ]]; then
        echo -e "  OK // Text Encoder: ${GREEN}qwen3vl_8b_heretic-Q4_K_M.gguf${RESET}"
    else
        echo -e "  ERR // Text Encoder: ${RED}Missing (${te_model})${RESET}"
    fi

    if [[ -f "$vae_model" ]]; then
        echo -e "  OK // VAE: ${GREEN}qwen_image_2.1_vae_bf16.safetensors${RESET}"
    else
        echo -e "  ERR // VAE: ${RED}Missing (${vae_model})${RESET}"
    fi

    echo -e "\n${BOLD}LoRA Adapters & Acceleration:${RESET}"
    local turbo_lora="${COMFY_DIR}/models/loras/qwen-image-2.1-viggle-turbo.safetensors"
    local uncensored_lora="${COMFY_DIR}/models/loras/qwen-image-2.1-uncensored-lora.safetensors"
    local anime_lora="${COMFY_DIR}/models/loras/qwen-image-2.1-anime-lora.safetensors"
    local anatomy_lora="${COMFY_DIR}/models/loras/Genitalia-Anatomy-2.1-v1.safetensors"

    if [[ -f "$turbo_lora" || -L "$turbo_lora" ]]; then
        local sz_turbo
        sz_turbo=$(du -hL "$turbo_lora" | awk '{print $1}')
        echo -e "  OK // Viggle Turbo (DMD 6-Step): ${GREEN}qwen-image-2.1-viggle-turbo.safetensors (${sz_turbo})${RESET}"
    else
        echo -e "  ERR // Viggle Turbo (DMD 6-Step): ${RED}Missing (${turbo_lora})${RESET}"
    fi

    if [[ -f "$uncensored_lora" ]]; then
        local sz_uncensored
        sz_uncensored=$(du -h "$uncensored_lora" | awk '{print $1}')
        echo -e "  OK // Heretic Uncensored: ${GREEN}qwen-image-2.1-uncensored-lora.safetensors (${sz_uncensored})${RESET}"
    else
        echo -e "  ERR // Heretic Uncensored: ${RED}Missing (${uncensored_lora})${RESET}"
    fi

    if [[ -f "$anime_lora" ]]; then
        local sz_anime
        sz_anime=$(du -h "$anime_lora" | awk '{print $1}')
        echo -e "  OK // Anime Consistency: ${GREEN}qwen-image-2.1-anime-lora.safetensors (${sz_anime})${RESET}"
    else
        echo -e "  ERR // Anime Consistency: ${RED}Missing (${anime_lora})${RESET}"
    fi

    if [[ -f "$anatomy_lora" ]]; then
        local sz_anatomy
        sz_anatomy=$(du -h "$anatomy_lora" | awk '{print $1}')
        echo -e "  OK // Anatomy Fidelity: ${GREEN}Genitalia-Anatomy-2.1-v1.safetensors (${sz_anatomy})${RESET}"
    else
        echo -e "  ERR // Anatomy Fidelity: ${RED}Missing (${anatomy_lora})${RESET}"
    fi

    echo -e "\n${BOLD}Neural AI Upscalers (4X Super-Resolution):${RESET}"
    local esrgan_model="${COMFY_DIR}/models/upscale_models/RealESRGAN_x4plus.safetensors"
    local ultrasharp_model="${COMFY_DIR}/models/upscale_models/4x-UltraSharp.safetensors"
    local animesharp_model="${COMFY_DIR}/models/upscale_models/4x-AnimeSharp.safetensors"

    if [[ -f "$esrgan_model" ]]; then
        local sz_esrgan
        sz_esrgan=$(du -h "$esrgan_model" | awk '{print $1}')
        echo -e "  · OK · 4X ESRGAN (Denoise): ${GREEN}RealESRGAN_x4plus.safetensors (${sz_esrgan})${RESET}"
    else
        echo -e "  · ERR · 4X ESRGAN (Denoise): ${RED}Missing (${esrgan_model})${RESET}"
    fi

    if [[ -f "$ultrasharp_model" ]]; then
        local sz_ultra
        sz_ultra=$(du -h "$ultrasharp_model" | awk '{print $1}')
        echo -e "  · OK · 4X ULTRA (Textures): ${GREEN}4x-UltraSharp.safetensors (${sz_ultra})${RESET}"
    else
        echo -e "  · ERR · 4X ULTRA (Textures): ${RED}Missing (${ultrasharp_model})${RESET}"
    fi

    if [[ -f "$animesharp_model" ]]; then
        local sz_anime_up
        sz_anime_up=$(du -h "$animesharp_model" | awk '{print $1}')
        echo -e "  · OK · 4X ANIME (Contours): ${GREEN}4x-AnimeSharp.safetensors (${sz_anime_up})${RESET}"
    else
        echo -e "  · ERR · 4X ANIME (Contours): ${RED}Missing (${animesharp_model})${RESET}"
    fi
}

# ---------------------------------------------------------
# Step 1: Install System Dependencies (Strictly Official Arch - NO AUR)
# ---------------------------------------------------------
install_system_deps() {
    log_info "Installing core system dependencies (official Arch repositories)..."
    local pkgs=("curl" "jq" "imagemagick" "rsync" "git" "python" "python-pip")
    local needed=()
    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            needed+=("$pkg")
        fi
    done

    if (( ${#needed[@]} > 0 )); then
        echo "Packages required for installation: ${needed[*]}"
        sudo pacman -S --needed --noconfirm "${needed[@]}"
        log_ok "System packages installed successfully."
    else
        log_ok "All system packages are already present."
    fi
}

# ---------------------------------------------------------
# Step 2: Install / Setup ComfyUI & Custom Nodes
# ---------------------------------------------------------
install_comfyui() {
    log_info "Preparing ComfyUI in ${COMFY_DIR}..."
    mkdir -p "${COMFY_DIR}" "${COMFY_DIR}/models/diffusion_models" "${COMFY_DIR}/models/text_encoders" "${COMFY_DIR}/models/vae" "${COMFY_DIR}/models/loras" "${COMFY_DIR}/custom_nodes"

    if [[ ! -f "${COMFY_DIR}/main.py" ]]; then
        log_info "Cloning official ComfyUI repository at pinned commit ${COMFY_PINNED_COMMIT:0:7}..."
        git clone --no-checkout https://github.com/comfyanonymous/ComfyUI.git "${COMFY_DIR}" && \
            git -C "${COMFY_DIR}" checkout --detach b53f77a74e21091cbdebfdf7b85fc80326932646
    else
        git -C "${COMFY_DIR}" checkout --detach b53f77a74e21091cbdebfdf7b85fc80326932646 2>/dev/null || true
    fi

    local actual_comfy
    actual_comfy=$(git -C "${COMFY_DIR}" rev-parse HEAD 2>/dev/null || echo "")
    if [[ "${actual_comfy}" != "${COMFY_PINNED_COMMIT}" ]]; then
        log_err "ComfyUI integrity check failed! Expected commit ${COMFY_PINNED_COMMIT}, found ${actual_comfy}."
        return 1
    fi
    log_ok "ComfyUI core verified at pinned commit (${actual_comfy:0:7})."

    if [[ ! -d "${COMFY_VENV}" ]]; then
        log_info "Creating isolated Python virtual environment (${COMFY_VENV})..."
        python3 -m venv "${COMFY_VENV}"
        
        detect_hardware
        local lock_file=""
        if [[ "$GPU_VENDOR" == "nvidia" ]]; then
            lock_file="${SCRIPT_DIR}/locks/requirements-lock-cu128.txt"
            log_info "Selected lockfile for NVIDIA CUDA (cu128, hash-verified)."
        elif [[ "$GPU_VENDOR" == "amd" ]]; then
            lock_file="${SCRIPT_DIR}/locks/requirements-lock-rocm.txt"
            log_info "Selected lockfile for AMD ROCm (rocm6.2, hash-verified)."
        else
            lock_file="${SCRIPT_DIR}/locks/requirements-lock-cpu.txt"
            log_info "Selected lockfile for CPU (hash-verified)."
        fi

        if [[ ! -f "$lock_file" ]]; then
            log_err "Dependency lockfile not found: ${lock_file}"
            return 1
        fi

        log_info "Installing deterministic dependencies with SHA-256 verification (pip install --require-hashes)..."
        if ! "${COMFY_VENV}/bin/pip" install --require-hashes -r "$lock_file"; then
            log_err "Critical integrity error: downloaded package SHA-256 hash does not match lockfile in locks/!"
            log_err "Installation aborted for security reasons to prevent running unverified code."
            return 1
        fi
        log_ok "All Python dependencies verified and installed from immutable hash lockfile."
    fi

    # Clone required custom nodes (pinned to verified immutable commit hashes)
    local nodes=(
        "ComfyUI-GGUF|https://github.com/city96/ComfyUI-GGUF.git|${NODE_GGUF_COMMIT}"
        "ComfyUI-GGUF-Qwen3VL-TE|https://github.com/pottokao-dotcom/ComfyUI-GGUF-Qwen3VL-TE.git|${NODE_QWEN3VL_COMMIT}"
        "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|${NODE_WD14_COMMIT}"
        "ComfyUI-Autocomplete-Plus|https://github.com/newtextdoc1111/ComfyUI-Autocomplete-Plus.git|${NODE_AUTOCOMPLETE_COMMIT}"
    )

    for item in "${nodes[@]}"; do
        IFS="|" read -r node_name node_url node_commit <<< "$item"
        local target_node="${COMFY_DIR}/custom_nodes/${node_name}"
        if [[ ! -d "$target_node" ]]; then
            log_info "Cloning node ${node_name} at pinned commit ${node_commit:0:7}..."
            git clone --no-checkout "$node_url" "$target_node" && \
                git -C "$target_node" checkout --detach "$node_commit"
            log_ok "Dependencies for node ${node_name} are covered by the hash-verified lockfile."
        else
            git -C "$target_node" checkout --detach "$node_commit" 2>/dev/null || true
        fi

        local actual_node_commit
        actual_node_commit=$(git -C "$target_node" rev-parse HEAD 2>/dev/null || echo "")
        if [[ "${actual_node_commit}" != "${node_commit}" ]]; then
            log_err "Integrity check failed for node ${node_name}! Expected ${node_commit}, found ${actual_node_commit}."
            return 1
        fi
        log_ok "Node ${node_name} verified at pinned commit (${node_commit:0:7})."
    done

    # Setup ComfyUI-ViggleTurbo custom node (runtime LoRA & DMD 6-step scheduler)
    local viggle_dir="${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
    mkdir -p "${viggle_dir}"
    local viggle_init="${viggle_dir}/__init__.py"
    local local_viggle="${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py"

    if [[ -f "${local_viggle}" ]]; then
        log_info "Installing ComfyUI-ViggleTurbo from local repository..."
        cp -f "${local_viggle}" "${viggle_init}"
        chmod 0644 "${viggle_init}"
        log_ok "ComfyUI-ViggleTurbo integrated from local package."
    else
        log_info "Fetching ComfyUI-ViggleTurbo from Hugging Face at pinned commit ${HF_VIGGLE_COMMIT:0:7}..."
        safe_download_model "${viggle_dir}" "__init__.py" \
            "https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo/resolve/${HF_VIGGLE_COMMIT}/comfyui/viggle_turbo.py" \
            "ComfyUI-ViggleTurbo Node" "${HF_VIGGLE_NODE_SHA256}"
    fi

    log_ok "ComfyUI and custom nodes are ready at approved commits."
}

# ---------------------------------------------------------
# Step 3: Download Diffusion Models (Hugging Face with Resume)
# ---------------------------------------------------------
# Low-level binary header inspection for model files (Magic Bytes Guard)
verify_model_magic_bytes() {
    local file_path="$1"
    if [[ ! -f "${file_path}" ]]; then
        log_err "SECURITY REJECT // Model file does not exist: ${file_path}"
        return 1
    fi

    # Read first 16 bytes in hex format
    local hex_header
    hex_header=$(od -N 16 -t x1 -An "${file_path}" 2>/dev/null | tr -d ' \n' | awk '{print tolower($0)}')

    # 1. Immediately block Python Pickle (protocols 2, 3, 4, 5: 0x80 0x02..0x05)
    if [[ "${hex_header}" =~ ^800[2-5] ]]; then
        log_err "SECURITY CRITICAL // Rejected unsafe Python Pickle file (RCE vector)!"
        return 1
    fi

    # 2. Blokace ZIP / PyTorch .bin archivu (PK\x03\x04 = 504b0304)
    if [[ "${hex_header}" =~ ^504b0304 ]]; then
        log_err "SECURITY CRITICAL // Rejected compressed ZIP/PyTorch archive disguised as a model!"
        return 1
    fi

    # 3. Validace GGUF (0x47 0x47 0x55 0x46 = "GGUF")
    if [[ "${hex_header}" =~ ^47475546 ]]; then
        log_ok "Magic Bytes // Valid GGUF tensor format identified."
        return 0
    fi

    # 4. Validate Safetensors (8-byte uint64 header length followed by 0x7B '{')
    local ninth_byte
    ninth_byte=$(od -j 8 -N 1 -t x1 -An "${file_path}" 2>/dev/null | tr -d ' \n' | awk '{print tolower($0)}')
    if [[ "${ninth_byte}" == "7b" ]]; then
        log_ok "Magic Bytes // Valid Safetensors format identified (JSON header '{' confirmed)."
        return 0
    fi

    log_err "SECURITY REJECT // Unknown or disallowed binary format. Only GGUF and Safetensors are permitted."
    return 1
}

# Helper: Safe model downloader refusing symlinks, using exclusive tempfiles and verifying SHA-256
safe_download_model() {
    local target_dir="$1"
    local file_name="$2"
    local url="$3"
    local desc="$4"
    local expected_sha256="${5:-}"
    local p2p_source="${6:-}"

    # Strict Anti-Pickle Rule (AGENTS.md Security Policy):
    # Only pure tensor containers (GGUF and safetensors) are allowed for models.
    # Executable Python pickle formats (.bin, .pt, .pth, .ckpt) are strictly forbidden.
    if [[ "$file_name" != "__init__.py" ]]; then
        case "$file_name" in
            *.gguf|*.safetensors)
                ;;
            *.bin|*.pt|*.pth|*.ckpt)
                log_err "SECURITY POLICY VIOLATION // Forbidden executable pickle format detected: ${file_name}"
                log_err "Only safe tensor containers (GGUF and safetensors) are permitted."
                return 1
                ;;
            *)
                log_err "SECURITY WARNING // Disallowed model weight format: ${file_name}"
                return 1
                ;;
        esac
    fi

    if [[ -L "$target_dir" ]]; then
        log_err "Target models directory is a symlink: $target_dir"
        return 1
    fi
    mkdir -p "$target_dir"
    if [[ ! -O "$target_dir" ]]; then
        log_err "Target models directory is not owned by the current user: $target_dir"
        return 1
    fi

    local target_path="${target_dir}/${file_name}"
    local real_target="$target_path"
    if [[ -L "$target_path" ]]; then
        real_target="$(realpath -q "$target_path" || true)"
        if [[ -z "$real_target" || ! -f "$real_target" ]]; then
            log_err "Target model path is an invalid symlink: $target_path. Aborting download."
            return 1
        fi
        if [[ ! -O "$real_target" ]]; then
            log_err "Symlink target is not owned by the current user: $real_target"
            return 1
        fi
        log_info "Target model is an existing symlink pointing to: $real_target"
    fi

    if [[ -f "$real_target" ]]; then
        if [[ -n "$expected_sha256" ]]; then
            local curr_sha
            curr_sha="$(sha256sum "$real_target" | awk '{print $1}')"
            if [[ "$curr_sha" == "$expected_sha256" ]]; then
                log_ok "${desc} (${file_name}) is already downloaded and verified (SHA-256 OK)."
                return 0
            else
                log_err "Target model ${real_target} already exists with a different checksum. Refusing to overwrite existing user file."
                return 1
            fi
        else
            log_ok "${desc} (${file_name}) is already downloaded."
            return 0
        fi
    fi

    log_info "Downloading ${desc} (${file_name})..."
    local tmp_part
    tmp_part="$(mktemp "${target_dir}/${file_name}.part.XXXXXX")"
    chmod 0644 "$tmp_part"

    local download_success=0

    # 1. Primary download: Official HTTPS (curl with resume -C -)
    if curl -L --fail -C - --progress-bar -o "$tmp_part" "$url"; then
        download_success=1
    elif [[ -n "$p2p_source" ]]; then
        # 2. P2P Fallback (BitTorrent / WebSeed via aria2c with mandatory encryption)
        if command -v aria2c >/dev/null 2>&1; then
            log_warn "Primary HTTPS failed. Starting P2P fallback via aria2c (--bt-require-crypto=true)..."
            if aria2c --bt-require-crypto=true \
                      --summary-interval=5 \
                      --max-connection-per-server=4 \
                      --split=4 \
                      --dir="$target_dir" \
                      --out="$(basename "$tmp_part")" \
                      "$p2p_source"; then
                download_success=1
            fi
        else
            log_warn "HTTPS failed and aria2c is unavailable for P2P fallback."
        fi
    fi

    if (( download_success == 1 )); then
        # Cryptographic SHA-256 verification (Strict Ingestion Guard)
        if [[ -n "$expected_sha256" ]]; then
            local downloaded_sha
            downloaded_sha="$(sha256sum "$tmp_part" | awk '{print $1}')"
            if [[ "$downloaded_sha" != "$expected_sha256" ]]; then
                log_err "Critical integrity error: checksum for ${desc} does not match expected digest!"
                log_err "Expected SHA-256: ${expected_sha256}"
                log_err "Actual SHA-256:   ${downloaded_sha}"
                rm -f "$tmp_part"
                return 1
            fi
            log_ok "Cryptographic digest for ${desc} verified (SHA-256 OK)."
        fi

        # Low-level binary magic bytes check (Magic Bytes Security Guard)
        if [[ "$file_name" != "__init__.py" ]]; then
            if ! verify_model_magic_bytes "$tmp_part"; then
                log_err "SECURITY REJECT // Binary file header failed security validation!"
                rm -f "$tmp_part"
                return 1
            fi
        fi

        # Mandatory AI payload inspection (Google Magika Anomaly Detection):
        # Detect hidden executable polyglots before moving into production directories
        if command -v magika >/dev/null 2>&1 && [[ "$file_name" != "__init__.py" ]]; then
            local magika_type
            magika_type=$(magika --json "$tmp_part" 2>/dev/null | grep -o '"label": *"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "unknown")
            if [[ "$magika_type" =~ elf|pebin|mach-o|python|sh|bash|powershell|jar ]]; then
                log_err "SECURITY ALERT // Google Magika AI detected an executable payload disguised as a model: ${magika_type}"
                rm -f "$tmp_part"
                return 1
            fi
            log_ok "Google Magika AI inspection: ${magika_type} (no polyglot anomalies)."
        fi

        mv -f "$tmp_part" "$target_path"
        chmod 0644 "$target_path"
        log_ok "${desc} downloaded and integrated successfully."
    else
        log_err "Error downloading ${desc}!"
        rm -f "$tmp_part"
        return 1
    fi
}

download_models() {
    detect_hardware
    log_info "Checking and downloading optimized models for profile ${HW_TIER}..."

    local diff_dir="${COMFY_DIR}/models/diffusion_models"
    local te_dir="${COMFY_DIR}/models/text_encoders"
    local vae_dir="${COMFY_DIR}/models/vae"

    # 1. DiT Model (Q4_K_M for Tier S/A, Q3_K_M for Tier B) - pinned to commit c9dd121
    local dit_file="qwen_image_2.1_Q4_K_M.gguf"
    local dit_url="https://huggingface.co/Abiray/Qwen-Image-2.1-GGUF/resolve/${HF_DIT_COMMIT}/qwen_image_2.1_Q4_K_M.gguf"
    local dit_sha="${HF_DIT_Q4_SHA256}"
    if [[ "$HW_TIER" == "B" ]]; then
        dit_file="qwen_image_2.1_Q3_K_M.gguf"
        dit_url="https://huggingface.co/Abiray/Qwen-Image-2.1-GGUF/resolve/${HF_DIT_COMMIT}/qwen_image_2.1_Q3_K_M.gguf"
        dit_sha="${HF_DIT_Q3_SHA256}"
    fi
    safe_download_model "$diff_dir" "$dit_file" "$dit_url" "DiT model" "$dit_sha"

    # Save environment configuration for rust-bridge and runtime
    local cfg_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/qwenimage"
    mkdir -p "$cfg_dir"
    chmod 0700 "$cfg_dir"
    cat <<EOF > "${cfg_dir}/env.conf"
# QIS Hardware & Model Environment Configuration
QIS_VRAM_TIER=${HW_TIER}
QIS_DIT_MODEL=${dit_file}
EOF
    chmod 0600 "${cfg_dir}/env.conf"

    # 2. Text Encoder (Qwen3-VL 8B Heretic Q4_K_M) - pinned to commit 4b78325
    local te_file="qwen3vl_8b_heretic-Q4_K_M.gguf"
    local te_url="https://huggingface.co/chfm/Qwen-Image-2.1-Text-Encoder-Heretic-GGUF/resolve/${HF_TE_COMMIT}/qwen3vl_8b_heretic-Q4_K_M.gguf"
    safe_download_model "$te_dir" "$te_file" "$te_url" "Text Encoder" "${HF_TE_SHA256}"

    # 3. VAE (BF16 Safetensors) - pinned to commit 9a44dbd
    local vae_file="qwen_image_2.1_vae_bf16.safetensors"
    local vae_url="https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/${HF_VAE_COMMIT}/vae/qwen_image_2.1_vae_bf16.safetensors"
    safe_download_model "$vae_dir" "$vae_file" "$vae_url" "VAE" "${HF_VAE_SHA256}"

    # 4. Viggle Turbo LoRA (6-step DMD distillation) - pinned to commit 009a44a
    local loras_dir="${COMFY_DIR}/models/loras"
    mkdir -p "${loras_dir}"
    local turbo_file="Qwen-Image-2.1-viggle-turbo-v0.3-6step-lora-r128.safetensors"
    local turbo_url="https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo/resolve/${HF_VIGGLE_COMMIT}/Qwen-Image-2.1-viggle-turbo-v0.3-6step-lora-r128.safetensors"
    safe_download_model "$loras_dir" "$turbo_file" "$turbo_url" "Viggle Turbo LoRA" "${HF_VIGGLE_TURBO_LORA_SHA256}"
    if [[ ! -e "${loras_dir}/qwen-image-2.1-viggle-turbo.safetensors" || -L "${loras_dir}/qwen-image-2.1-viggle-turbo.safetensors" ]]; then
        ln -sf "$turbo_file" "${loras_dir}/qwen-image-2.1-viggle-turbo.safetensors"
    fi

    # 5. Heretic Uncensored LoRA (33 MB) - pinned to commit 6b34e59
    local uncensored_file="qwen-image-2.1-uncensored-lora.safetensors"
    local uncensored_url="https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-GGUF/resolve/${HF_UNCENSORED_COMMIT}/qwen-image-2.1-uncensored-lora.safetensors"
    safe_download_model "$loras_dir" "$uncensored_file" "$uncensored_url" "Heretic Uncensored LoRA" "${HF_UNCENSORED_LORA_SHA256}"

    # 6. Anime Consistency LoRA (160 MB) - pinned to commit c4ab547
    local anime_file="qwen-image-2.1-anime-lora.safetensors"
    local anime_url="https://huggingface.co/WarmBloodAban/Qwen-Image-2.1-LoRAs/resolve/${HF_ANIME_COMMIT}/Qwen2.1_Anime_consistency.safetensors"
    safe_download_model "$loras_dir" "$anime_file" "$anime_url" "Anime Consistency LoRA" "${HF_ANIME_LORA_SHA256}"

    # 7. Neural AI Upscale Models (RealESRGAN_x4plus, 4x-UltraSharp, 4x-AnimeSharp)
    local upscale_dir="${COMFY_DIR}/models/upscale_models"
    mkdir -p "${upscale_dir}"
    local esrgan_file="RealESRGAN_x4plus.safetensors"
    local esrgan_url="https://huggingface.co/Comfy-Org/Real-ESRGAN_repackaged/resolve/${HF_ESRGAN_COMMIT}/RealESRGAN_x4plus.safetensors"
    safe_download_model "$upscale_dir" "$esrgan_file" "$esrgan_url" "RealESRGAN_x4plus Neural Upscaler" "${HF_ESRGAN_SHA256}"

    local ultrasharp_file="4x-UltraSharp.safetensors"
    local ultrasharp_url="https://huggingface.co/Kim2091/UltraSharp/resolve/${HF_ULTRASHARP_COMMIT}/4x-UltraSharp.safetensors"
    safe_download_model "$upscale_dir" "$ultrasharp_file" "$ultrasharp_url" "4x-UltraSharp Neural Upscaler" "${HF_ULTRASHARP_SHA256}"

    local animesharp_file="4x-AnimeSharp.safetensors"
    local animesharp_url="https://huggingface.co/Kim2091/AnimeSharp/resolve/${HF_ANIMESHARP_COMMIT}/4x-AnimeSharp.safetensors"
    safe_download_model "$upscale_dir" "$animesharp_file" "$animesharp_url" "4x-AnimeSharp Neural Upscaler" "${HF_ANIMESHARP_SHA256}"
}

# ---------------------------------------------------------
# Step 4: Setup Ollama Local Translation Assistant
# ---------------------------------------------------------
setup_ollama_models() {
    if command -v ollama >/dev/null 2>&1; then
        log_info "Checking local Ollama models for translation and prompt optimization..."
        if ! curl -s http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
            log_warn "Ollama server is not running on port 11434. Models will be checked on startup."
            return 0
        fi

        local models=("qwen2.5-coder:7b")
        for m in "${models[@]}"; do
            if ! ollama list 2>/dev/null | grep -q "${m%:*}"; then
                log_info "Pulling model ${m}..."
                ollama pull "$m" || log_warn "Failed to pull ${m}, attempting to continue."
            fi
        done
        log_ok "Ollama models verified."
    fi
}

# ---------------------------------------------------------
# UPDATER 1: Update QIS Plugin
# ---------------------------------------------------------
update_qis_plugin() {
    log_info "Checking and updating QIS plugin..."
    local target_dir="${HOME}/.config/omarchy/plugins/simonez.qwenimage"

    # Identify source repository
    local src_dir="${SCRIPT_DIR}"
    if [[ ! -d "${src_dir}/.git" ]] && [[ -d "${HOME}/Projects/omarchy-qwenimage/.git" ]]; then
        src_dir="${HOME}/Projects/omarchy-qwenimage"
    fi

    # Detect intentional dev symlink mode (target_dir -> src_dir owned by user)
    local norm_src norm_target is_dev_symlink=0
    norm_src="$(readlink -f "${src_dir}" 2>/dev/null || echo "${src_dir}")"
    norm_target="$(readlink -f "${target_dir}" 2>/dev/null || echo "${target_dir}")"
    if [[ -L "${target_dir}" ]]; then
        if [[ "${norm_src}" == "${norm_target}" && -O "${target_dir}" ]]; then
            is_dev_symlink=1
            log_info "Dev symlink mode (${target_dir} -> ${src_dir})."
        else
            log_err "Target plugin directory is an unrecognized symlink: ${target_dir}. Update aborted."
            return 1
        fi
    fi

    # In developer workspace, sync directly to user config (unless dev symlink already points to src_dir)
    if (( is_dev_symlink == 0 )) && [[ -d "${src_dir}" && "${norm_src}" != "${norm_target}" && -d "${target_dir}" ]]; then
        log_info "Syncing local repository (${src_dir}) to target (${target_dir})..."
        rsync -a --exclude='.git/' --exclude='target/' --exclude='*.tmp*' --exclude='bin/' \
            "${src_dir}/" "${target_dir}/"
    elif (( is_dev_symlink == 0 )) && command -v omarchy >/dev/null 2>&1 && omarchy plugin list --json 2>/dev/null | grep -q "simonez.qwenimage"; then
        log_info "Updating plugin via official Omarchy manager..."
        omarchy plugin update simonez.qwenimage --yes 2>/dev/null || true
    fi

    if [[ -d "${src_dir}/rust-bridge" ]] && command -v cargo >/dev/null 2>&1; then
        local build_dir="${target_dir}"
        if (( is_dev_symlink == 1 )); then
            build_dir="${src_dir}"
        fi
        local target_bin="${build_dir}/bin/qwen-bridge"
        local target_bin_dir="${build_dir}/bin"

        # Verify target plugin directory
        if (( is_dev_symlink == 0 )) && [[ -L "${build_dir}" ]]; then
            log_err "Target plugin directory is a symlink: ${build_dir}. Update aborted."
            return 1
        fi
        if [[ -e "${build_dir}" ]]; then
            if [[ ! -d "${build_dir}" || ! -O "${build_dir}" ]]; then
                log_err "Target plugin directory is not owned by the current user: ${build_dir}"
                return 1
            fi
        fi

        # Verify target bin directory
        if [[ -L "${target_bin_dir}" ]]; then
            log_err "Plugin bin/ directory is a symlink: ${target_bin_dir}. Update aborted."
            return 1
        fi
        if [[ -e "${target_bin_dir}" ]]; then
            if [[ ! -d "${target_bin_dir}" || ! -O "${target_bin_dir}" ]]; then
                log_err "Plugin bin/ directory is not owned by the current user: ${target_bin_dir}"
                return 1
            fi
        else
            mkdir -p "${target_bin_dir}"
        fi

        # Verify target binary
        if [[ -L "${target_bin}" ]]; then
            log_err "Target binary is a symlink: ${target_bin}. Update aborted."
            return 1
        fi

        local newer_src=""
        if [[ -f "${target_bin}" ]]; then
            newer_src="$(find "${src_dir}/rust-bridge/src" "${src_dir}/rust-bridge/Cargo.toml" -type f -newer "${target_bin}" -print -quit 2>/dev/null || true)"
        fi
        if [[ ! -f "${target_bin}" ]] || [[ -n "${newer_src}" ]]; then
            log_info "Updating native Rust bridge..."
            (cd "${src_dir}/rust-bridge" && cargo build --release)
            local compiled_bin="${src_dir}/rust-bridge/target/release/qwen_bridge"
            if [[ -f "$compiled_bin" ]]; then
                local tmp_bin
                tmp_bin="$(mktemp "${target_bin_dir}/qwen-bridge.tmp.XXXXXX")"
                cp --remove-destination --no-dereference "$compiled_bin" "$tmp_bin"
                chmod 0755 "$tmp_bin"
                mv -f "$tmp_bin" "${target_bin}"
                chmod 0755 "${target_bin}"

                local new_hash
                new_hash="$(sha256sum "${target_bin}" | awk '{print $1}')"
                printf '%s  qwen-bridge\n' "${new_hash}" > "${target_bin_dir}/qwen-bridge.sha256"

                # Update hash in .installed_hashes if receipt exists
                local receipt="${build_dir}/.installed_hashes"
                if [[ -f "$receipt" && ! -L "$receipt" && -O "$receipt" ]]; then
                    local new_hash
                    new_hash="$(sha256sum "${target_bin}" | awk '{print $1}')"
                    local tmp_receipt
                    tmp_receipt="$(mktemp "${target_dir}/.installed_hashes.tmp.XXXXXX")"
                    while IFS= read -r rline || [[ -n "$rline" ]]; do
                        [[ -z "$rline" ]] && continue
                        read -r _ rpath <<< "$rline"
                        rpath="${rpath#\./}"
                        rpath="${rpath#\*}"
                        rpath="${rpath#"${rpath%%[![:space:]]*}"}"
                        rpath="${rpath%"${rpath##*[![:space:]]}"}"
                        if [[ "$rpath" == "bin/qwen-bridge" ]]; then
                            echo "${new_hash}  bin/qwen-bridge" >> "$tmp_receipt"
                        else
                            echo "$rline" >> "$tmp_receipt"
                        fi
                    done < "$receipt"
                    chmod 0600 "$tmp_receipt"
                    mv -f "$tmp_receipt" "$receipt"
                    chmod 0600 "$receipt"
                fi
            fi
        fi
    fi

    log_ok "QIS plugin and native components are up to date."
}

# ---------------------------------------------------------
# UPDATER 2: Update ComfyUI & Custom Nodes with Rollback Checkpoint
# ---------------------------------------------------------
update_comfyui() {
    if [[ ! -d "${COMFY_DIR}/.git" ]]; then
        log_warn "ComfyUI directory is not a git repository (${COMFY_DIR})."
        return 0
    fi

    log_info "Creating checkpoint before updating ComfyUI..."
    if [[ -L "${CHECKPOINT_DIR}" ]]; then
        log_err "CHECKPOINT_DIR is a symlink: ${CHECKPOINT_DIR}. Aborting."
        return 1
    fi
    mkdir -p "${CHECKPOINT_DIR}"
    if [[ ! -O "${CHECKPOINT_DIR}" ]]; then
        log_err "CHECKPOINT_DIR is not owned by the current user: ${CHECKPOINT_DIR}"
        return 1
    fi

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local cur_commit
    cur_commit=$(git -C "${COMFY_DIR}" rev-parse HEAD)

    write_checkpoint() {
        local target="$1"
        local data="$2"
        if [[ -L "$target" ]]; then
            log_err "Refusing to write checkpoint to symlink: $target"
            return 1
        fi
        local tmp_file
        tmp_file="$(mktemp "${CHECKPOINT_DIR}/cp.tmp.XXXXXX")"
        chmod 0600 "$tmp_file"
        echo "$data" > "$tmp_file"
        mv -f "$tmp_file" "$target"
        chmod 0600 "$target"
    }

    write_checkpoint "${CHECKPOINT_DIR}/comfy_last_known_good_${ts}.txt" "$cur_commit" || return 1
    write_checkpoint "${CHECKPOINT_DIR}/latest_checkpoint.txt" "$cur_commit" || return 1

    log_info "Verifying ComfyUI core integrity at pinned commit ${COMFY_PINNED_COMMIT:0:7}..."
    git -C "${COMFY_DIR}" fetch --depth 1 origin b53f77a74e21091cbdebfdf7b85fc80326932646 && \
        git -C "${COMFY_DIR}" checkout --detach b53f77a74e21091cbdebfdf7b85fc80326932646

    local actual_comfy
    actual_comfy=$(git -C "${COMFY_DIR}" rev-parse HEAD 2>/dev/null || echo "")
    if [[ "${actual_comfy}" != "${COMFY_PINNED_COMMIT}" ]]; then
        log_err "ComfyUI integrity check failed after update! Expected commit ${COMFY_PINNED_COMMIT}, found ${actual_comfy}."
        return 1
    fi

    log_info "Verifying custom nodes integrity..."
    local nodes=(
        "ComfyUI-GGUF|https://github.com/city96/ComfyUI-GGUF.git|${NODE_GGUF_COMMIT}"
        "ComfyUI-GGUF-Qwen3VL-TE|https://github.com/pottokao-dotcom/ComfyUI-GGUF-Qwen3VL-TE.git|${NODE_QWEN3VL_COMMIT}"
        "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|${NODE_WD14_COMMIT}"
        "ComfyUI-Autocomplete-Plus|https://github.com/newtextdoc1111/ComfyUI-Autocomplete-Plus.git|${NODE_AUTOCOMPLETE_COMMIT}"
    )

    for item in "${nodes[@]}"; do
        IFS="|" read -r node_name node_url node_commit <<< "$item"
        local node_dir="${COMFY_DIR}/custom_nodes/${node_name}"
        if [[ -d "${node_dir}/.git" ]]; then
            log_info "  -> ${node_name} (pinned at ${node_commit:0:7})"
            git -C "$node_dir" fetch --depth 1 origin "$node_commit" && \
                git -C "$node_dir" checkout --detach -q "$node_commit"

            local actual_node_commit
            actual_node_commit=$(git -C "$node_dir" rev-parse HEAD 2>/dev/null || echo "")
            if [[ "${actual_node_commit}" != "${node_commit}" ]]; then
                log_err "Integrity check failed for node ${node_name} after update! Expected ${node_commit}, found ${actual_node_commit}."
                return 1
            fi
        fi
    done

    # Synchronizace ComfyUI-ViggleTurbo
    local viggle_dir="${COMFY_DIR}/custom_nodes/ComfyUI-ViggleTurbo"
    mkdir -p "${viggle_dir}"
    local viggle_init="${viggle_dir}/__init__.py"
    local local_viggle="${SCRIPT_DIR}/custom_nodes/ComfyUI-ViggleTurbo/__init__.py"

    if [[ -f "${local_viggle}" ]]; then
        cp -f "${local_viggle}" "${viggle_init}"
        chmod 0644 "${viggle_init}"
        log_ok "ComfyUI-ViggleTurbo synced from local repository."
    elif [[ ! -f "${viggle_init}" ]]; then
        safe_download_model "${viggle_dir}" "__init__.py" \
            "https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo/resolve/${HF_VIGGLE_COMMIT}/comfyui/viggle_turbo.py" \
            "ComfyUI-ViggleTurbo Node" "${HF_VIGGLE_NODE_SHA256}"
    fi

    # Sync and verify hash-locked dependencies
    detect_hardware
    local lock_file=""
    if [[ "$GPU_VENDOR" == "nvidia" ]]; then
        lock_file="${SCRIPT_DIR}/locks/requirements-lock-cu128.txt"
    elif [[ "$GPU_VENDOR" == "amd" ]]; then
        lock_file="${SCRIPT_DIR}/locks/requirements-lock-rocm.txt"
    else
        lock_file="${SCRIPT_DIR}/locks/requirements-lock-cpu.txt"
    fi

    if [[ -f "$lock_file" && -x "${COMFY_VENV}/bin/pip" ]]; then
        log_info "Verifying and syncing dependencies against immutable hash lockfile..."
        if ! "${COMFY_VENV}/bin/pip" install --require-hashes -r "$lock_file"; then
            log_err "Critical error: invalid dependency hash detected while updating ComfyUI!"
            log_err "Update aborted for security reasons."
            return 1
        fi
        log_ok "ComfyUI and node dependencies match verified hashes in locks/."
    fi

    log_ok "ComfyUI and custom nodes are locked and verified at approved commits."
}

# ---------------------------------------------------------
# Rollback ComfyUI to Previous Checkpoint
# ---------------------------------------------------------
rollback_comfyui() {
    local cp_file="${CHECKPOINT_DIR}/latest_checkpoint.txt"
    if [[ -f "$cp_file" ]]; then
        local target_commit
        target_commit=$(xargs < "$cp_file")
        log_warn "Rolling back ComfyUI to checkpoint: ${target_commit}..."
        git -C "${COMFY_DIR}" checkout "$target_commit"
        log_ok "ComfyUI rolled back to previous working state."
    else
        log_err "No previous checkpoint found in ${CHECKPOINT_DIR}."
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
        echo -e "  ${BOLD}1 ·${RESET} ${BOLD}Full installation${RESET} // Packages, ComfyUI, nodes, models"
        echo -e "  ${BOLD}2 ·${RESET} ${BOLD}Update EVERYTHING${RESET} // QIS plugin, ComfyUI, nodes, models"
        echo -e "  ${BOLD}3 ·${RESET} Update QIS Plugin only // UI and Rust bridge"
        echo -e "  ${BOLD}4 ·${RESET} Update ComfyUI Engine and Custom Nodes only"
        echo -e "  ${BOLD}5 ·${RESET} Download / Verify AI Models // HuggingFace"
        echo -e "  ${BOLD}6 ·${RESET} Show status and dependency matrix"
        echo -e "  ${BOLD}7 ·${RESET} Emergency ComfyUI Rollback // Restore working checkpoint"
        echo -e "  ${BOLD}0 ·${RESET} Exit\n"

        read -rp "Enter choice (0-7): " choice
        case "$choice" in
            1)
                install_system_deps
                install_comfyui
                download_models
                setup_ollama_models
                "${SCRIPT_DIR}/install.sh"
                log_ok "Full installation complete!"
                ;;
            2)
                update_qis_plugin
                update_comfyui
                setup_ollama_models
                log_ok "Everything updated successfully!"
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
                echo "Invalid choice."
                ;;
        esac
    done
}

# ---------------------------------------------------------
# Lifecycle Management (Start / Stop Backend)
# ---------------------------------------------------------
start_comfyui() {
    local bg=0
    for arg in "$@"; do
        [[ "$arg" == "--bg" || "$arg" == "-b" ]] && bg=1
    done

    if curl -sf "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1; then
        log_ok "ComfyUI server is already running on http://127.0.0.1:8188."
        return 0
    fi

    detect_hardware
    log_info "Starting ComfyUI backend (Profile: ${TIER_DESC})..."

    local py_bin="${COMFY_VENV}/bin/python"
    if [[ ! -f "$py_bin" ]]; then
        py_bin="${COMFY_DIR}/.venv/bin/python"
    fi
    if [[ ! -f "$py_bin" ]]; then
        log_err "Nenalezen Python venv ComfyUI v ${COMFY_DIR}/venv ani .venv."
        log_err "Run: qis setup"
        return 1
    fi

    local args=("--listen" "127.0.0.1" "--port" "8188" "--preview-method" "auto" "--disable-cuda-malloc" "--cache-classic")
    if [[ "$HW_TIER" == "B" ]]; then
        args+=("--lowvram" "--enable-dynamic-vram")
    elif [[ "$HW_TIER" == "C" ]]; then
        args+=("--cpu")
    else
        local reserve_val="0.5"
        if [[ -n "${QIS_VRAM_RESERVE_GB:-}" ]]; then
            reserve_val="${QIS_VRAM_RESERVE_GB}"
        fi
        args+=("--reserve-vram" "${reserve_val}" "--enable-dynamic-vram" "--fp8_e4m3fn-text-enc")
    fi

    # Accelerate attention layers via SageAttention 2 on Ampere sm_86
    if [[ "$HW_TIER" != "C" ]] && "$py_bin" -c "import sageattention" >/dev/null 2>&1; then
        args+=("--use-sage-attention")
    fi

    # Allocation and runtime guards (expandable_segments, lazy loading, single-CCD threading)
    export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,garbage_collection_threshold:0.8"
    export CUDA_MODULE_LOADING="LAZY"
    export OMP_NUM_THREADS="8"
    export MKL_NUM_THREADS="8"
    export OPENBLAS_NUM_THREADS="8"

    local log_file="${COMFY_DIR}/comfyui.log"
    local pid_file="${COMFY_DIR}/comfyui.pid"

    # Rotate ComfyUI log when exceeding 10 MB (keeping last 10,000 lines)
    if [[ -f "$log_file" ]] && ! [[ -L "$log_file" ]]; then
        local log_sz
        log_sz=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        if (( log_sz > 10485760 )); then
            local tmp_log
            tmp_log=$(mktemp "${COMFY_DIR}/comfyui.log.tmp.XXXXXX")
            tail -n 10000 "$log_file" > "$tmp_log" 2>/dev/null || true
            chmod 0600 "$tmp_log"
            mv -f "$tmp_log" "$log_file"
        fi
    fi

    if (( bg == 1 )); then
        if [[ -f "${HOME}/.config/systemd/user/comfyui.service" ]] && command -v systemctl >/dev/null 2>&1 && systemctl --user is-system-running >/dev/null 2>&1; then
            systemctl --user restart "comfyui.service" >/dev/null 2>&1 || true
        elif command -v systemd-run >/dev/null 2>&1 && systemctl --user is-system-running >/dev/null 2>&1; then
            systemctl --user stop "qis-comfyui-${UID}.service" 2>/dev/null || true
            systemd-run --user --unit="qis-comfyui-${UID}" "$py_bin" "${COMFY_DIR}/main.py" "${args[@]}" >/dev/null 2>&1 || true
        else
            nohup "$py_bin" "${COMFY_DIR}/main.py" "${args[@]}" > "$log_file" 2>&1 &
            local pid=$!
            echo "$pid" > "$pid_file"
        fi
        log_info "Waiting for ComfyUI to start in background..."
        local started=0
        for (( i=1; i<=45; i++ )); do
            sleep 1
            if curl -sf "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1; then
                started=1
                break
            fi
        done
        if (( started == 1 )); then
            log_ok "ComfyUI backend started successfully on http://127.0.0.1:8188."
        else
            log_warn "ComfyUI started in background, but port 8188 is not responding yet (45s timeout)."
        fi
    else
        exec "$py_bin" "${COMFY_DIR}/main.py" "${args[@]}"
    fi
}

stop_comfyui() {
    log_info "Zastavuji ComfyUI backend..."
    local pid_file="${COMFY_DIR}/comfyui.pid"
    local stopped=0

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
            stopped=1
        fi
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user stop "comfyui.service" "qis-comfyui-${UID}.service" "qis-comfyui-${UID}.scope" 2>/dev/null || true
    fi

    if command -v fuser >/dev/null 2>&1; then
        if fuser -k 8188/tcp >/dev/null 2>&1; then
            stopped=1
        fi
    fi

    # Clean up temporary previews in /dev/shm
    local shm_dir="/dev/shm/qis_preview_${UID}"
    if [[ -d "$shm_dir" && ! -L "$shm_dir" && -O "$shm_dir" ]]; then
        rm -rf "$shm_dir"
        log_ok "Temporary previews in ${shm_dir} cleaned up."
    fi

    if (( stopped == 1 )) || ! curl -sf "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1; then
        log_ok "ComfyUI server stopped successfully."
    else
        log_warn "Failed to stop ComfyUI server."
    fi
}

show_help() {
    echo "QIS (Qwen Image Studio) — Stack & Lifecycle CLI"
    echo ""
    echo "Usage: qis <COMMAND>"
    echo ""
    echo "Commands:"
    echo "  status                       Show ecosystem health matrix, VRAM tier & models"
    echo "  start <--bg>                 Start ComfyUI backend (foreground or --bg)"
    echo "  stop                         Stop ComfyUI backend and clean /dev/shm previews"
    echo "  setup | install | --full     Full stack setup (deps, ComfyUI, models, plugin)"
    echo "  update <all|plugin|comfy|models>"
    echo "                               Update QIS components (default: all)"
    echo "  models                       Download / verify AI models"
    echo "  rollback                     Roll back ComfyUI to last working checkpoint"
    echo "  help | -h | --help           Show this help message"
    echo ""
    echo "Run without arguments to open the interactive menu."
}

# ---------------------------------------------------------
# CLI Router
# ---------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        help|-h|--help|--h)
            show_help
            ;;
        status)
            check_status
            ;;
        start)
            shift || true
            start_comfyui "$@"
            ;;
        stop)
            stop_comfyui
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
        "")
            interactive_menu
            ;;
        *)
            log_err "Unknown command: ${1}. Run 'qis --help' for usage."
            exit 1
            ;;
    esac
fi
