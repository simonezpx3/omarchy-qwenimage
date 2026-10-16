# QIS (Qwen Image Studio)

[![Version](https://img.shields.io/badge/version-1.2.2-3b82f6.svg)](https://github.com/simonezpx3/omarchy-qwenimage/releases/tag/v1.2.2)
[![QIS CI](https://github.com/simonezpx3/omarchy-qwenimage/actions/workflows/ci.yml/badge.svg)](https://github.com/simonezpx3/omarchy-qwenimage/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Omarchy%20Linux%20%7C%20Hyprland-teal.svg)](#)
[![UI Engine](https://img.shields.io/badge/UI-Quickshell%200.3+-purple.svg)](#)
[![Native Core](https://img.shields.io/badge/Native%20Bridge-Rust%20(sub--ms)-orange.svg)](#)
[![Local Inference](https://img.shields.io/badge/Inference-100%25%20Local%20(Zero%20API%20Cost)-success.svg)](#)

Universal Local-first Generative AI Studio for **Linux** (Wayland // Quickshell // Omarchy).

Engineered for high-performance local diffusion inference with zero cloud dependencies and zero API costs.

![QIS Studio](docs/screenshots/qis-studio.png)

---

## Architecture Overview

QIS connects the reactive QtQuick/QML interface with a native Rust orchestration layer and local AI engines:

```mermaid
graph LR
    subgraph UI ["Linux Desktop (Wayland / Hyprland)"]
        Bar["Quickshell Bar Widget"]
        Panel["QIS Studio Panel (QML / #screens)"]
    end

    subgraph Core ["Native Performance Layer"]
        Bridge["Rust Bridge (bin/qwen-bridge)"]
        CLI["Lifecycle Manager (qis CLI)"]
    end

    subgraph Backend ["Local AI Engines (NVIDIA CUDA / ROCm)"]
        Comfy["ComfyUI Backend (DiT Q4_K_M GGUF)"]
        Ollama["Ollama / Vision (Prompt Optimizer & WD14)"]
    end

    Bar <--> Panel
    Panel <--> Bridge
    CLI <--> Bridge
    Bridge <--> Comfy
    Bridge <--> Ollama
```

---

## Interface Tour

| Studio & Canvas | Prompt & Inspiration Explorer | History & Local Archive |
|---|---|---|
| ![Studio View](docs/screenshots/qis-studio.png) | ![CivitAI Explorer](docs/screenshots/qis-civitai.png) | ![Generation History](docs/screenshots/qis-history.png) |

---

## Features

- **Text-to-Image (DiT Diffusion):** Native high-resolution generation via a local ComfyUI backend.
- **SageAttention 2 Acceleration:** Hardware-accelerated INT8 Tensor Core matrix operations (`sm_86` Ampere and newer) reducing attention memory footprint and delivering 25–35% faster sampling without altering GGUF model weights.
- **POSIX Shared Memory Previews (`/dev/shm`):** Live step previews written directly to an isolated RAM disk (`/dev/shm/qis_preview_${UID}/`) with atomic file replacement, eliminating disk I/O latency and micro-stutter on high-refresh-rate Wayland compositors.
- **Process Lifecycle Hardening & Zombie Protection:** Kernel-level process tracking via `libc::prctl(PR_SET_PDEATHSIG, SIGKILL)` and transient systemd scopes (`systemd-run --user --scope`), ensuring immediate GPU VRAM eviction and zero orphan processes if the parent bridge terminates.
- **Complete Bilingual Parity (EN // CS):** Dynamic language switcher with full localization across UI labels, tooltips, bridge error messages, and desktop notifications.
- **Turbo Mode (Viggle Turbo DMD):** 6-step Distribution Matching Distillation (DMD) with zero-redundancy MLP hooks yielding ~5s generation on consumer GPUs (8 GB+ VRAM, enforcing a strict 1.8 GB VRAM system reserve), toggleable directly from the bottom action bar.
- **Neural Super-Resolution (4X Upscalers):** Integrated local super-resolution suite executed within ComfyUI:
  - `4X ESRGAN` (RealESRGAN_x4plus) — General photographic and cinematic restoration with grain denoising.
  - `4X ULTRA` (4x-UltraSharp) — Micro-contrast and high-frequency texture preservation.
  - `4X ANIME` (4x-AnimeSharp) — Clean cell-shaded and vector-like linework without ringing artifacts.
  - `0.5X` & `FIT 1K` — Instant downsampling and viewport boundary fitting.
- **SIMD Lanczos Resizer:** CPU SIMD-accelerated image resampling (AVX2, NEON, and portable fallback in Rust) via `bin/qwen-bridge scale-lanczos`, delivering deterministic high-fidelity scaling without Python or GPU runtime overhead.
- **Low-Memory UI Texture Pipeline:** Adaptive `sourceSize` viewport constraint in QML decoupling physical canvas dimensions from render textures, reducing UI RAM/VRAM consumption from ~92 MB to ~4 MB while preserving original aspect ratios.
- **Automated Tmpfs Housekeeping:** Native Rust garbage collection sweeping runtime preview artifacts older than 24 hours, paired with a 10 MB circular log rotator on ComfyUI execution streams.
- **Screen Area Snip & Reference Buffer Controls:** Direct geometry screen capture (`grim` + `slurp`) into runtime tmpfs buffers via `SNIP`, paired with instant one-click buffer eviction (`CLEAR`) without polluting the system clipboard.
- **Interactive History & Wayland Fullscreen Viewer:** Direct ingestion of past generations back into the Studio reference buffer (`COPY TO BUFFER`) and zero-latency fullscreen inspection (`VIEW`) powered by `imv` (`imv -i imv-fullscreen -f -c "bind <Escape> quit"`).
- **A/B Compare Interactive Splitter:** Dedicated dual-buffer inspection view (`views/CompareView.qml`) with a real-time split slider to optically evaluate generation quality, prompts, and aspect scaling variations side-by-side.
- **Hardened Wayland Sandbox & Input Isolation:** Strictly bounded Wayland clipboard intake (16 KiB text/URI metadata ceiling, bounded 32 MiB image stream buffer, 1.2s timeout with `SIGKILL` fallback) and `FocusScope` event interception neutralizing foreign MIME starvation, DoS freezes, and primary selection leaks.
- **Heretic LoRA (Abliterated Uncensored Latent):** Dedicated uncensored diffusion adapter with a dynamic LoRA weight governor preventing tensor saturation.
- **Anatomical Safety Guard:** Automated anatomy preservation enforcing a standard resolution floor (1024 px) and adaptive Euler sampling profile when human subjects or portraits are detected in draft mode.
- **Live TAEQI 2.1 Previews:** Real-time intermediate diffusion preview streaming over WebSocket directly from ComfyUI (zero VRAM overhead, decoded via lightweight TAEQI into RAM-disk tmpfs).
- **Quick Step Presets:** Instant step selection (`15`, `25`, `35`) with active state highlight and live elapsed timer.
- **Universal Wayland Clipboard Engine:** Native Rust integration decoding raw image formats (PNG, JPEG, WebP, BMP, TIFF), file manager URIs (`file://` from Nemo, Thunar, Nautilus), and web image URLs directly into the reference buffer.
- **Instant Generation Interrupt & Cancel:** Dynamic `CANCEL // Xs` button during active diffusion paired with a dedicated `interrupt_comfyui()` routine and `isCancelling` state machine in the Rust bridge, immediately halting the diffusion loop in ComfyUI and releasing GPU memory.
- **Image-to-Image & Aspect Ratio Overrides:** Automatic aspect ratio extraction when set to `auto`, and explicit user aspect ratio enforcement (`21:9`, `16:9`, `16:10`, `4:3`, `1:1`, `3:4`, `9:16`) with center-crop scaling.
- **Anime LoRA & Adaptive Resolution Profiling:** Instant anime style injection and VRAM-aware resolution presets (`standard`, `performance`, `high`).
- **WD14 Tag Interrogator:** Fast Danbooru tag extraction via ONNX / ViT models.
- **Vision Prompt Engineering:** Reverse-engineering existing reference scenes into structured diffusion prompts.
- **Civitai Explorer:** Curated prompts, negative prompts, and generation settings browser with single-click apply and double-click instant generation.
- **Hardened Rust Bridge & Regression Suite:** Native bridge (`bin/qwen-bridge`) equipped with a 4096-character prompt buffer clamp, automated LLM JSON prompt envelope unpacking, foreign tag sanitization (`<lora:...>`, `<embedding:...>`), and an automated unit test suite.
- **Dynamic Output Node Resolution:** Resilient backend listener that dynamically resolves `SaveImage` nodes across custom workflows instead of relying on fixed node indices.
- **Omarchy Instrumental UI Architecture:** Consistent geometric alignment with `Style.cornerRadius`, concentric surface depth, precision corner accents, and minimal frame overhead.
- **Tabular Numerals & Optical Stability:** OpenType `tnum` tabular numerals across diffusion step badges, timers, and VRAM telemetry eliminating horizontal layout jitter.
- **Clean Live System Telemetry:** Header telemetry indicators displaying connected Qwen model, ComfyUI (v0.41.2), Ollama, CUDA, Quickshell, and real-time VRAM utilization (including the 1.8 GB safety reserve).
- **In-Button Live Timers:** Dynamic second counters inside active operation buttons (`GENERATE`, `OPTIMIZE`, `TAGS`, `SCALE`).
- **Wallpaper Integration:** One-click wallpaper deployment to Omarchy and Hyprland.

---

## Interactive Controls & Shortcuts

| Action / Gesture | Trigger | Result |
|---|---|---|
| **Toggle Studio Panel** | Click on bar widget or `omarchy-shell simonez.qwenimage toggle` | Opens or closes the floating studio window |
| **Instant Generation** | `Ctrl + Enter` in prompt or negative prompt | Immediately launches diffusion synthesis |
| **Turbo Mode Toggle** | Click on `TURBO: ON // OFF` in bottom bar | Toggles 6-step DMD acceleration (~5s) vs standard 28-step Euler sampling |
| **Heretic LoRA Toggle** | Click on `HERETIC: ON // OFF` in bottom bar | Toggles uncensored latent diffusion adapter |
| **Anime LoRA Toggle** | Click on `ANIME: ON // OFF` in bottom bar | Toggles anime and illustration stylization adapter |
| **Paste Reference Image** | Click on reference preview box, `Ctrl + V`, or `Super + V` | Decodes image stream or local file URI from Wayland clipboard |
| **Screen Area Snip** | Click on `SNIP` in Studio reference box | Interactively captures screen geometry (`slurp` + `grim`) into reference buffer |
| **Clear Reference Buffer** | Click on `CLEAR` next to `SNIP` | Immediately clears the active reference image from the Studio buffer |
| **History to Reference Buffer** | Click on `COPY TO BUFFER` in History view | Loads a previously generated image directly into the Studio reference buffer |
| **Fullscreen Image View** | Click on `VIEW` in History view | Opens the generated image in a native Wayland fullscreen viewer (`imv`, press `Esc` to quit) |
| **A/B Compare View** | Click on `COMPARE` in Studio bottom bar | Opens dual-buffer interactive slider compare view |
| **CivitAI Quick Apply** | Single click on any prompt card | Loads prompt and parameters into Studio |
| **CivitAI Direct Synthesize** | Double click on any prompt card | Loads prompt and triggers immediate generation |
| **Return to Studio** | `Esc` from A/B Compare or History views | Navigates back to main Studio view |
| **Close Studio** | `Esc` or click outside | Closes the window and releases viewport textures |
| **CLI & Stack Update** | `qis update [all\|plugin\|comfy\|models]` | Updates plugin, Rust bridge, ComfyUI core, or models via CLI |
| **Live Telemetry** | Automatic background polling (default: 3s) | Updates hardware and VRAM header telemetry automatically |

---

## Hardware Tier Profiling

QIS automatically profiles system hardware during installation and configures the optimal runtime tier:

| Tier | VRAM | Recommended Configuration |
|---|---|---|
| **Tier S** | $\ge$ 16 GB | Full FP8 / BF16 direct weights, maximum generation speed. |
| **Tier A** | 8 – 12 GB | GGUF Q4_K_M DiT + Qwen3-VL 8B Text Encoder with dynamic VRAM management and SageAttention 2 acceleration. |
| **Tier B** | 6 GB | GGUF Q3_K_S DiT + Qwen2.5-VL 3B Text Encoder with sequential CPU offload. |
| **Tier C** | $\le$ 4 GB / iGPU | Remote LAN execution via external network ComfyUI backend (local UI client mode). |

---

## Installation & Setup

### Option A: Omarchy Plugin Manager (Recommended)
```bash
omarchy plugin add https://github.com/simonezpx3/omarchy-qwenimage.git
```
*Note: `omarchy plugin add` automatically triggers an in-place execution of `install.sh`.*

### Option B: Standalone / Manual Setup
```bash
git clone https://github.com/simonezpx3/omarchy-qwenimage.git
cd omarchy-qwenimage
chmod +x install.sh
./install.sh
```

During installation (both automatic in-place and manual), `install.sh` will:
1. Profile GPU vendor (NVIDIA, AMD, Intel) and detect available VRAM.
2. Check for ComfyUI and diffusion models; if missing, offer automated stack installation.
3. Deploy and verify the native bridge binary `bin/qwen-bridge`.
4. Deploy the `qis` management CLI into `~/.local/bin/qis`.
5. Validate plugin schema via `omarchy plugin validate` (when running on Omarchy).
6. Register the plugin into the bar layout and perform a safe IPC hot-reload.

---

## Lifecycle & Updater CLI (`qis`)

Manage the entire local ecosystem using the `qis` command:

```bash
qis                                     # Interactive management menu (Setup, Update, Models, Rollback)
qis start [--bg]                        # Start the QIS backend stack (use --bg to run as background scope)
qis stop                                # Gracefully stop running ComfyUI and release GPU VRAM
qis status                              # Display dependency health matrix, VRAM reserve, and hardware profile
qis setup                               # Automated installation of ComfyUI (v0.41.2), custom nodes, and models
qis update [all|plugin|comfy|models]    # Granular or full update of QIS plugin, ComfyUI core, or models
qis models                              # List and manage installed diffusion checkpoints, GGUF weights, and LoRAs
qis rollback                            # Revert ComfyUI to previous working commit state
```

---

## Security & Supply-Chain Baseline

This plugin complies with the Omarchy Marketplace Security Baseline:
- **Pinned Git Commits:** ComfyUI core (v0.41.2) and all custom nodes are pinned to immutable commit SHAs.
- **Cryptographic Hash Verification:** All Python packages and sub-dependencies are locked with strict SHA-256 hashes (`pip install --require-hashes`) across CUDA 12.8, ROCm 6.2, and CPU architectures in `locks/`. Precompiled native binaries are verified via `bin/qwen-bridge.sha256`.
- **Zero Unpinned Execution:** No unhashed or arbitrary code is downloaded during clone, install, or update operations.
- **Hardware VRAM Reserve:** System reserve defaults to 1.8 GB on 8 GB GPUs (protecting Wayland desktop compositors and active applications), dynamically configurable via `QIS_VRAM_RESERVE_GB`.
- **Bounded Clipboard & POSIX Shared Memory:** Wayland text/URI clipboard intake is capped at 16 KiB with a 1.2s timeout; previews use user-isolated RAM disks (`/dev/shm/qis_preview_${UID}`) with mode `0700` permissions and automatic eviction on service stop.

---

## Uninstallation

```bash
# Via Omarchy plugin manager:
omarchy plugin remove simonez.qwenimage

# Or directly via uninstaller script:
./uninstall.sh [--purge-settings | --purge-all]
```
- `./uninstall.sh` — Removes plugin registration, CLI symlink, and Bar widget while keeping user configurations and models intact.
- `./uninstall.sh --purge-settings` — Additionally removes user configuration files and state caches.
- `./uninstall.sh --purge-all` — Complete teardown: removes plugin, settings, local ComfyUI environment, and all downloaded AI models.

---

## Acknowledgments & Upstream Credits

QIS builds upon the work of open-source creators and AI researchers whose technologies make local inference possible:

- **[ComfyUI](https://github.com/comfyanonymous/ComfyUI)** by [@comfyanonymous](https://github.com/comfyanonymous) – Node-based execution engine powering the local diffusion pipeline.
- **[ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF)** by [@city96](https://github.com/city96) – GGUF quantization loader enabling DiT models to run within consumer VRAM limits.
- **[Qwen-Image / Qwen2.5-VL](https://github.com/QwenLM)** by the **Qwen Team (Alibaba Cloud)** – Foundation models for generative image synthesis and visual understanding.
- **[Viggle AI](https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo)** by [@Viggle](https://viggle.ai/) – 6-step DMD (Distribution Matching Distillation) LoRA architecture and custom scheduler.
- **[chfm](https://huggingface.co/chfm/Qwen-Image-2.1-Text-Encoder-Heretic-GGUF)** – Qwen3-VL 8B Heretic GGUF text encoder reducing false-positive prompt refusals while maintaining semantic alignment.
- **[abenzerps](https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-GGUF)** – Uncensored latent LoRA adapter.
- **[WarmBloodAban](https://huggingface.co/WarmBloodAban/Qwen-Image-2.1-LoRAs)** – Anime consistency LoRA adapter.
- **[Quickshell](https://github.com/outfoxxed/quickshell)** by [@outfoxxed](https://github.com/outfoxxed) – Reactive QtQuick/Wayland shell environment.
- **[WD14 Tagger](https://github.com/pythongosssss/ComfyUI-WD14-Tagger)** by [@pythongosssss](https://github.com/pythongosssss) & [@SmilingWolf](https://github.com/SmilingWolf) – Anime and photography tag interrogation models.
- **[TAEQI / Tiny AutoEncoder](https://github.com/madebyollin/taesd)** by [@madebyollin](https://github.com/madebyollin) – Lightweight latent autoencoder powering real-time step previews.
- **[Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)** by [@xinntao](https://github.com/xinntao) & **[Comfy-Org](https://huggingface.co/Comfy-Org/Real-ESRGAN_repackaged)** – Super-resolution architecture and repackaged weights.
- **[4x-UltraSharp & 4x-AnimeSharp](https://huggingface.co/Kim2091)** by [@Kim2091](https://huggingface.co/Kim2091) – Super-resolution checkpoints for micro-contrast and linework restoration.
- **[Civitai](https://civitai.com/)** – Community platform for prompt engineering and open model sharing.
- **[Omarchy Linux & Hyprland](https://github.com/hyprwm/Hyprland)** – Wayland tiling desktop ecosystem.

---

## License

[MIT License](LICENSE). Developed by simonez & Arci.

---

## Disclaimer

QIS is an independent open-source project and is not affiliated with, sponsored, or endorsed by Alibaba Group, Google, or ComfyUI.
