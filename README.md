# QIS (Qwen Image Studio)

Universal native Generative AI Studio for **Omarchy Linux** and **Quickshell** (Wayland / Hyprland).

Designed for high-performance local diffusion inference with zero cloud dependencies and zero token costs.

---

## Features

- **Text-to-Image (DiT Diffusion):** Native high-resolution generation via ComfyUI backend.
- **Image-to-Image & Auto Aspect Match:** Automatic aspect ratio extraction (`21:9`, `16:9`, `4:3`, `1:1`, `3:4`, `9:16`) preventing image distortion.
- **WD14 Tag Interrogator:** Fast Danbooru tag extraction via ONNX / ViT.
- **Vision Prompt Engineering:** Reverse-engineering scenes into rich diffusion prompts.
- **Civitai Explorer:** Curated prompts and settings browser.
- **Fast Rust Bridge:** High-performance native bridge (`bin/qwen-bridge`) executing telemetry, PNG metadata chunk manipulation, and system monitoring in sub-millisecond speeds.
- **Live System Telemetry:** Header badges showing connected Qwen model, ComfyUI, Ollama, CUDA, Quickshell, and VRAM utilization.
- **Wallpaper Integration:** One-click wallpaper deployment to Omarchy and Hyprland.

---

## Hardware Tier Profiling

QIS automatically profiles your hardware on installation and suggests the optimal runtime configuration:

| Tier | VRAM | Recommended Configuration |
|---|---|---|
| **Tier S** | $\ge$ 16 GB | Full FP8 / BF16 direct weights, maximum generation speed. |
| **Tier A** | 8 – 12 GB | GGUF Q4_K_M DiT + Qwen3-VL 8B Text Encoder with asynchronous VRAM offloading (`--async-offload 2`). |
| **Tier B** | 6 GB | GGUF Q3_K_S DiT + Qwen2.5-VL 3B Text Encoder with sequential CPU offload. |
| **Tier C** | $\le$ 4 GB / iGPU | Remote LAN cluster execution via network ComfyUI backend. |

---

## Installation

```bash
git clone https://github.com/simonezpx3/omarchy-qwenimage.git
cd omarchy-qwenimage
chmod +x install.sh
./install.sh
```

The installer will:
1. Profile GPU vendor (NVIDIA, AMD, Intel) and detect available VRAM.
2. Deploy the verified native bridge binary `bin/qwen-bridge` (or compile from source if on a different architecture).
3. Validate plugin schema via `omarchy plugin validate`.
4. Register the plugin into Omarchy bar layout.
5. Hot-reload the shell.

---

## Uninstallation

```bash
cd omarchy-qwenimage
chmod +x uninstall.sh
./uninstall.sh
```

---

## License

MIT License. Developed by simonez.
