# QIS — Qwen Image Studio

[![Omarchy Marketplace](https://img.shields.io/badge/Marketplace-Published%20%26%20Verified-10b981?style=flat-square&logo=checkmarx&logoColor=white)](https://omarchyplugins.com/plugin.html?id=simonez.qwenimage)
[![Version](https://img.shields.io/badge/version-1.2.8-3b82f6.svg)](https://github.com/simonezpx3/omarchy-qwenimage/releases/tag/v1.2.8)
[![QIS CI](https://github.com/simonezpx3/omarchy-qwenimage/actions/workflows/ci.yml/badge.svg)](https://github.com/simonezpx3/omarchy-qwenimage/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![UI Engine](https://img.shields.io/badge/UI-Quickshell%200.3+-purple.svg)](#architecture)
[![Native Bridge](https://img.shields.io/badge/Bridge-Rust%20(sub--ms)-orange.svg)](#architecture)

## TL;DR

**QIS** is a local-first generative AI studio for **Omarchy Linux / Hyprland (Wayland)** combining a lazy-loaded **Quickshell (QtQuick/QML)** interface, a native **Rust** orchestration bridge (`bin/qwen-bridge`), and a **ComfyUI (DiT Q4_K_M GGUF) + Ollama** backend—with zero cloud dependencies and zero API costs.

> [!IMPORTANT]
> **Built for `<= 8 GB` VRAM GPUs.** `QISVramBudget` dynamically reserves `0.9–1.6 GB` for the Wayland compositor, bypasses `EasyCache` when LoRAs are active (preventing 192 MiB SwiGLU collisions), and falls back to `VAEDecodeTiled` (`512px` tiles, `64px` overlap) to drop peak VAE decode memory from `576 MiB` to `< 80 MiB`.

> [!TIP]
> **Zero-stutter live previews.** TAEQI 2.1 WebSocket previews stream atomically into `/dev/shm/qis_preview_${UID}/`, and `Panel.qml` unmounts its QML tree when closed (`active: root.opened`) to minimize resident shell memory.

## Interface Tour

| Studio & Canvas | Civitai Explorer | Generation History |
| :--- | :--- | :--- |
| ![Studio View](docs/screenshots/qis-studio.png) | ![CivitAI Explorer](docs/screenshots/qis-civitai.png) | ![Generation History](docs/screenshots/qis-history.png) |

## Architecture

```mermaid
flowchart LR
    Bar["Quickshell BarWidget.qml\nLazy Panel.qml"] <--> Svc["Quattro Service.qml\nPersistent State"]
    Svc <--> Bridge["Rust Bridge (bin/qwen-bridge)\nSIMD Lanczos · Wayland Clipboard"]
    CLI["qis CLI"] <--> Bridge
    Bridge <--> Comfy["ComfyUI Backend\nDiT Q4_K_M GGUF · QISVramBudget"]
    Bridge <--> Ollama["Ollama / Vision\nQwen3-VL · WD14 ONNX"]
```

## Key Capabilities

| Area | Implementation |
| :--- | :--- |
| **Diffusion & Speed** | DiT Q4_K_M GGUF via ComfyUI, PyTorch 2.x SDPA (optional SageAttention 2), **6-step Turbo DMD** (~5s), instant `CANCEL` with VRAM release |
| **Adapters & Upscaling** | Tri-state LoRAs (`Heretic`, `Anime`, `Anatomy`: `OFF / SOFT / FULL`), `4X ESRGAN / UltraSharp / AnimeSharp`, Rust **SIMD Lanczos** (`AVX2`/`NEON`) |
| **Prompt & Vision Tools** | **WD14** Danbooru tagger, **Qwen3-VL** vision reverse-engineering, **Civitai Explorer** (1-click apply / 2-click generate) |
| **Wayland & Inspection** | `slurp` + `grim` screen `SNIP`, universal clipboard intake (`16 KiB` text / `32 MiB` image bounds), `imv` fullscreen viewer, A/B split compare |
| **Process Hardening** | `PR_SET_PDEATHSIG` (`SIGKILL`), `systemd-run --user --scope`, `flock` cooperative GPU lock (`VramLockGuard`), 24h tmpfs GC |

## Quickstart & Hardware Tiers

```bash
# 1. Install via Omarchy Plugin Manager (recommended — runs install.sh in-place)
omarchy plugin add https://github.com/simonezpx3/omarchy-qwenimage.git

# 2. Or install manually
git clone https://github.com/simonezpx3/omarchy-qwenimage.git && cd omarchy-qwenimage
git checkout v1.2.8 && ./install.sh

# 3. Manage backend, models, and updates via CLI
qis start --bg                          # Start backend scope
qis status                              # Health matrix, VRAM reserve & tier
qis update [all|plugin|comfy|models]    # Granular stack updates
```

| Tier | VRAM | Profile |
| :--- | :--- | :--- |
| **Tier S** | `>= 16 GB` | Full FP8 / BF16 weights |
| **Tier A** | `8 – 12 GB` | GGUF `Q4_K_M` DiT + Qwen3-VL 8B + `QISVramBudget` |
| **Tier B** | `6 GB` | GGUF `Q3_K_S` DiT + Qwen2.5-VL 3B + sequential CPU offload |
| **Tier C** | `<= 4 GB` / iGPU | Remote LAN ComfyUI backend (local UI client mode) |

## Security, Controls & Credits

<details>
<summary><strong>Supply-Chain Security, Shortcuts, Uninstall & Upstream Credits</strong></summary>

- **Supply-Chain Baseline:** ComfyUI (`v0.41.2`) and custom nodes pinned to commit SHAs; Python deps locked via `pip install --require-hashes` (`locks/`); native binary verified via `bin/qwen-bridge.sha256`.
- **Key Shortcuts:** `Ctrl + Enter` (Generate) · `Ctrl + V` / `Super + V` (Paste reference) · `Esc` (Close / back to Studio).
- **Uninstall:** `omarchy plugin remove simonez.qwenimage` or `./uninstall.sh [--purge-settings | --purge-all]`.
- **Upstream:** ComfyUI, ComfyUI-GGUF, Qwen2.5/3-VL, Viggle Turbo DMD, Quickshell, WD14 Tagger, TAEQI, Real-ESRGAN, 4x-UltraSharp/AnimeSharp, Hyprland.

</details>

## License

[MIT License](LICENSE)
