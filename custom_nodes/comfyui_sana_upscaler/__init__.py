import gc
import inspect
import torch
import numpy as np
from PIL import Image
from diffusers import DiffusionPipeline
import comfy.model_management as mm


class Sana2KUpscalerNode:
    """
    Produkční ComfyUI node pro 2K upscaling pomocí Nvidia Sana a Modular Diffusers 0.40.0+.
    Optimalizováno pro 8GB VRAM (RTX 3070) s prevencí VRAM swapu a OOM.
    """

    def __init__(self):
        self.pipe = None
        self.current_config = None

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "image": ("IMAGE",),  # ComfyUI standard: [B, H, W, C], float32, 0..1
                "model_id": ("STRING", {"default": "Efficient-Large-Model/Sana_1600M_2Kpx_BF16_diffusers"}),
                "prompt": ("STRING", {"default": "high quality, highly detailed, sharp 2k, ultra realistic", "multiline": True}),
                "negative_prompt": ("STRING", {"default": "blurry, lowres, artifacts, distortion, noise", "multiline": True}),
                "upscale_factor": ("FLOAT", {"default": 2.0, "min": 1.0, "max": 4.0, "step": 0.25}),
                "strength": ("FLOAT", {"default": 0.35, "min": 0.05, "max": 1.0, "step": 0.05}),
                "steps": ("INT", {"default": 20, "min": 1, "max": 50}),
                "guidance_scale": ("FLOAT", {"default": 4.5, "min": 1.0, "max": 15.0, "step": 0.1}),
                "offload_mode": (["sequential_cpu_offload", "model_cpu_offload"], {"default": "sequential_cpu_offload"}),
                "seed": ("INT", {"default": 42, "min": 0, "max": 0xffffffffffffffff}),
            }
        }

    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("upscaled_image",)
    FUNCTION = "upscale"
    CATEGORY = "Sana/Upscaling"

    def _ensure_pipeline(self, model_id: str, offload_mode: str):
        config_key = (model_id, offload_mode)
        if self.pipe is not None and self.current_config == config_key:
            return self.pipe

        self._unload()

        # Načtení přes Modular Diffusers API
        # Zkoušíme specializované img2img pipeline nebo generickou DiffusionPipeline
        pipe = None
        try:
            from diffusers import SanaSprintImg2ImgPipeline
            pipe = SanaSprintImg2ImgPipeline.from_pretrained(
                model_id,
                torch_dtype=torch.float16,
                use_safetensors=True,
            )
        except Exception:
            pipe = DiffusionPipeline.from_pretrained(
                model_id,
                torch_dtype=torch.float16,
                use_safetensors=True,
            )

        # Kritické pro 2K rozlišení na 8GB VRAM: VAE Tiling a Slicing
        if hasattr(pipe, "vae") and pipe.vae is not None:
            if hasattr(pipe.vae, "enable_tiling"):
                pipe.vae.enable_tiling()
            if hasattr(pipe.vae, "enable_slicing"):
                pipe.vae.enable_slicing()

        # Attention slicing jako pojistka
        if hasattr(pipe, "enable_attention_slicing"):
            pipe.enable_attention_slicing("max")

        # Offload strategie: Nikdy nevolat pipe.to("cuda") před offloadem!
        if offload_mode == "sequential_cpu_offload":
            pipe.enable_sequential_cpu_offload()
        else:
            pipe.enable_model_cpu_offload()

        self.pipe = pipe
        self.current_config = config_key
        return self.pipe

    def _unload(self):
        if self.pipe is not None:
            del self.pipe
            self.pipe = None
            self.current_config = None
            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    @staticmethod
    def _bhwc_to_pil(tensor_img: torch.Tensor) -> Image.Image:
        arr = (tensor_img.cpu().numpy() * 255.0).clip(0, 255).astype(np.uint8)
        return Image.fromarray(arr, mode="RGB")

    @staticmethod
    def _pil_to_bhwc(pil_img: Image.Image) -> torch.Tensor:
        arr = np.array(pil_img.convert("RGB"), dtype=np.float32) / 255.0
        return torch.from_numpy(arr)

    def upscale(
        self,
        image: torch.Tensor,
        model_id: str,
        prompt: str,
        negative_prompt: str,
        upscale_factor: float,
        strength: float,
        steps: int,
        guidance_scale: float,
        offload_mode: str,
        seed: int,
    ):
        # 1. Uvolnění VRAM držené samotným ComfyUI (prevence kolize s předchozími uzly)
        mm.unload_all_models()
        mm.soft_empty_cache()

        if torch.cuda.is_available():
            torch.cuda.reset_peak_memory_stats()

        pipe = self._ensure_pipeline(model_id, offload_mode)
        out_tensors = []
        call_params = inspect.signature(pipe.__call__).parameters

        # 2. Zpracování po jednotlivých snímcích v batchi (garance B=1 ve VRAM)
        for i in range(image.shape[0]):
            pil_in = self._bhwc_to_pil(image[i])
            target_w = int((pil_in.width * upscale_factor) // 32 * 32)
            target_h = int((pil_in.height * upscale_factor) // 32 * 32)
            pil_resized = pil_in.resize((target_w, target_h), Image.Resampling.LANCZOS)

            generator = torch.Generator(device="cpu").manual_seed(seed + i)

            with torch.inference_mode():
                if "image" in call_params:
                    # Pipeline nativně podporuje img2img (např. SanaSprintImg2ImgPipeline)
                    kwargs = {
                        "prompt": prompt,
                        "image": pil_resized,
                        "strength": strength,
                        "num_inference_steps": steps,
                        "guidance_scale": guidance_scale,
                        "width": target_w,
                        "height": target_h,
                        "generator": generator,
                    }
                    if "negative_prompt" in call_params:
                        kwargs["negative_prompt"] = negative_prompt
                    res = pipe(**kwargs)
                    result_pil = res.images[0]
                else:
                    # Pipeline je generická text2img (např. standardní SanaPipeline)
                    # Použijeme VAE encode + latent blending pro zachování struktury předlohy
                    # Vstup do VAE: BCHW normalizovaný na [-1, 1]
                    img_np = (np.array(pil_resized.convert("RGB"), dtype=np.float32) / 127.5) - 1.0
                    img_t = torch.from_numpy(img_np).permute(2, 0, 1).unsqueeze(0).to(dtype=torch.float16)
                    
                    # Offload bezpečné kódování
                    vae_device = getattr(pipe.vae, "device", torch.device("cpu"))
                    latents = pipe.vae.encode(img_t.to(vae_device)).latent
                    scaling = getattr(pipe.vae.config, "scaling_factor", 1.0)
                    latents = latents * scaling

                    noise = torch.randn(latents.shape, generator=generator, device=latents.device, dtype=latents.dtype)
                    noisy_latents = (1.0 - strength) * latents + strength * noise

                    kwargs = {
                        "prompt": prompt,
                        "latents": noisy_latents,
                        "num_inference_steps": steps,
                        "guidance_scale": guidance_scale,
                        "width": target_w,
                        "height": target_h,
                        "generator": generator,
                    }
                    if "negative_prompt" in call_params:
                        kwargs["negative_prompt"] = negative_prompt
                    res = pipe(**kwargs)
                    result_pil = res.images[0]

            out_tensors.append(self._pil_to_bhwc(result_pil))

        # 3. Telemetrie VRAM pro verifikaci 8GB VRAM stropu
        if torch.cuda.is_available():
            peak_mb = torch.cuda.max_memory_allocated() / (1024 ** 2)
            reserved_mb = torch.cuda.max_memory_reserved() / (1024 ** 2)
            print(f"Sana2KUpscaler // Peak VRAM Allocated: {peak_mb:.1f} MB | Reserved: {reserved_mb:.1f} MB (offload: {offload_mode})")

        return (torch.stack(out_tensors, dim=0),)


NODE_CLASS_MAPPINGS = {"Sana2KUpscaler": Sana2KUpscalerNode}
NODE_DISPLAY_NAME_MAPPINGS = {"Sana2KUpscaler": "Sana 2K Upscaler (Diffusers 0.40)"}
