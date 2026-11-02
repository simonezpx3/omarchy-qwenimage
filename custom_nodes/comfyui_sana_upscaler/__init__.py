import gc
import torch
import numpy as np
from PIL import Image, ImageFilter
try:
    from diffusers import DiffusionPipeline
    DIFFUSERS_AVAILABLE = True
except (ImportError, ModuleNotFoundError):
    DIFFUSERS_AVAILABLE = False
    DiffusionPipeline = None
try:
    import comfy.model_management as mm
except (ImportError, ModuleNotFoundError):
    mm = None


class Sana2KUpscalerNode:
    """
    Produkční ComfyUI node pro 2K upscaling pomocí Nvidia Sana a Modular Diffusers 0.40.0+.
    Optimalizováno pro 8GB VRAM (RTX 3070) s prevencí VRAM swapu a OOM.
    Používá korektní flow matching / diffusion img2img denoise cyklus.
    """

    def __init__(self):
        self.pipe = None
        self.current_config = None

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "image": ("IMAGE",),  # ComfyUI standard: (B, H, W, C), float32, 0..1
                "model_id": ("STRING", {"default": "Efficient-Large-Model/Sana_1600M_2Kpx_BF16_diffusers"}),
                "prompt": ("STRING", {"default": "high quality, highly detailed, sharp 2k, ultra realistic", "multiline": True}),
                "negative_prompt": ("STRING", {"default": "blurry, lowres, artifacts, distortion, noise", "multiline": True}),
                "upscale_factor": ("FLOAT", {"default": 2.0, "min": 1.0, "max": 4.0, "step": 0.25}),
                "strength": ("FLOAT", {"default": 0.16, "min": 0.05, "max": 1.0, "step": 0.01}),
                "steps": ("INT", {"default": 20, "min": 1, "max": 50}),
                "guidance_scale": ("FLOAT", {"default": 4.5, "min": 1.0, "max": 15.0, "step": 0.1}),
                "offload_mode": (["modular_cpu_offload", "sequential_cpu_offload", "model_cpu_offload"], {"default": "modular_cpu_offload"}),
                "seed": ("INT", {"default": 42, "min": 0, "max": 0xffffffffffffffff}),
            },
            "optional": {
                "anatomy_fidelity": ("FLOAT", {"default": 0.35, "min": 0.0, "max": 1.0, "step": 0.05}),
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
        # Model vyžaduje bfloat16: ve float16 dochází k overflow attention logitů a vzniku NaN
        if torch.cuda.is_available():
            target_device = "cuda:0"
            dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float32
        else:
            target_device = "cpu"
            dtype = torch.float32

        load_kwargs = {"torch_dtype": dtype, "use_safetensors": True}
        if "bf16" in model_id.lower() and dtype == torch.bfloat16:
            load_kwargs["variant"] = "bf16"

        try:
            pipe = DiffusionPipeline.from_pretrained(model_id, **load_kwargs)
        except Exception:
            load_kwargs.pop("variant", None)
            pipe = DiffusionPipeline.from_pretrained(model_id, **load_kwargs)

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
        if offload_mode == "modular_cpu_offload":
            modular_ok = False
            if target_device.startswith("cuda"):
                try:
                    from diffusers.modular_pipelines.components_manager import ComponentsManager
                    cm = ComponentsManager()
                    for name, comp in pipe.components.items():
                        if isinstance(comp, torch.nn.Module):
                            cm.add(name, comp)
                    cm.enable_auto_cpu_offload(device=target_device, memory_reserve_margin="2.0GB")
                    pipe._components_manager = cm
                    modular_ok = True
                except Exception as e:
                    print(f"Sana2KUpscaler // Warning: modular offload init failed ({e}), falling back to sequential offload")

            if not modular_ok:
                if hasattr(pipe, "enable_sequential_cpu_offload"):
                    pipe.enable_sequential_cpu_offload()
                elif hasattr(pipe, "enable_model_cpu_offload"):
                    pipe.enable_model_cpu_offload()
        elif offload_mode == "sequential_cpu_offload":
            if hasattr(pipe, "enable_sequential_cpu_offload"):
                pipe.enable_sequential_cpu_offload()
            elif hasattr(pipe, "enable_model_cpu_offload"):
                pipe.enable_model_cpu_offload()
        else:
            if hasattr(pipe, "enable_model_cpu_offload"):
                pipe.enable_model_cpu_offload()

        self.pipe = pipe
        self.current_config = config_key
        return self.pipe

    def _unload(self):
        if self.pipe is not None:
            if hasattr(self.pipe, "_components_manager"):
                try:
                    self.pipe._components_manager.disable_auto_cpu_offload()
                except Exception:
                    pass
                del self.pipe._components_manager
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

    @staticmethod
    def _blend_micro_anatomy(pil_base: Image.Image, pil_sana: Image.Image, fidelity: float) -> Image.Image:
        """
        Hybrid High-Frequency Detail Blending (beads-qis-sana-micro-anatomy-repair-nl7h).
        DC-AE autoencoder (32x downsampling) destroys sub-token micro-anatomy (pupils, irises, ear cartilage, fingers).
        This isolates the high-frequency structural luminance edges from the Lanczos-upscaled original
        and injects them into Sana's luminance (Y) channel in YCbCr color space.
        Zero chromatic aberration, locks micro-anatomy contours, 0 MB GPU VRAM overhead.
        """
        try:
            base_rgb = pil_base.convert("RGB")
            sana_rgb = pil_sana.convert("RGB")

            if base_rgb.size != sana_rgb.size:
                base_rgb = base_rgb.resize(sana_rgb.size, Image.Resampling.LANCZOS)

            sana_ycbcr = sana_rgb.convert("YCbCr")
            base_ycbcr = base_rgb.convert("YCbCr")

            y_base_img = base_ycbcr.getchannel("Y")
            y_sana_img = sana_ycbcr.getchannel("Y")

            y_base_low = y_base_img.filter(ImageFilter.GaussianBlur(radius=2.0))
            y_base_arr = np.array(y_base_img, dtype=np.float32)
            y_base_low_arr = np.array(y_base_low, dtype=np.float32)
            y_base_high = y_base_arr - y_base_low_arr

            y_sana_arr = np.array(y_sana_img, dtype=np.float32)
            y_fused = np.clip(y_sana_arr + (y_base_high * fidelity), 0.0, 255.0).astype(np.uint8)

            fused_y = Image.fromarray(y_fused, mode="L")
            return Image.merge("YCbCr", (fused_y, sana_ycbcr.getchannel("Cb"), sana_ycbcr.getchannel("Cr"))).convert("RGB")
        except Exception as e:
            print(f"Sana2KUpscaler // Warning: micro-anatomy blending fallback: {e}")
            return pil_sana

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
        anatomy_fidelity: float = 0.35,
    ):
        if not DIFFUSERS_AVAILABLE or DiffusionPipeline is None:
            raise RuntimeError(
                "Sana 2K Upscaler requires 'diffusers>=0.40.0', which is not installed in the ComfyUI environment."
            )

        # 1. Uvolnění VRAM držené samotným ComfyUI (prevence kolize s předchozími uzly)
        if mm is not None:
            mm.unload_all_models()
            mm.soft_empty_cache()

        if torch.cuda.is_available():
            torch.cuda.reset_peak_memory_stats()

        pipe = self._ensure_pipeline(model_id, offload_mode)
        device = pipe._execution_device
        do_cfg = guidance_scale > 1.0
        out_tensors = []

        # 2. Text encode promptu (jednorázově pro celý batch)
        with torch.inference_mode():
            (
                prompt_embeds,
                prompt_attention_mask,
                neg_prompt_embeds,
                neg_prompt_attention_mask,
            ) = pipe.encode_prompt(
                prompt=prompt,
                do_classifier_free_guidance=do_cfg,
                negative_prompt=negative_prompt,
                num_images_per_prompt=1,
                device=device,
            )
            if do_cfg:
                prompt_embeds = torch.cat([neg_prompt_embeds, prompt_embeds], dim=0)
                prompt_attention_mask = torch.cat([neg_prompt_attention_mask, prompt_attention_mask], dim=0)

        # 3. Zpracování po jednotlivých snímcích v batchi (garance B=1 ve VRAM)
        for i in range(image.shape[0]):
            pil_in = self._bhwc_to_pil(image[i])
            target_w = int((pil_in.width * upscale_factor) // 32 * 32)
            target_h = int((pil_in.height * upscale_factor) // 32 * 32)
            pil_resized = pil_in.resize((target_w, target_h), Image.Resampling.LANCZOS)

            with torch.inference_mode():
                # Naplánování timesteps a určení počátečního kroku podle strength
                pipe.scheduler.set_timesteps(steps, device=device)
                init_timestep = min(int(steps * strength), steps)
                t_start = max(steps - init_timestep, 0)
                timesteps = pipe.scheduler.timesteps[t_start:]
                pipe.scheduler.set_begin_index(t_start)

                # Vstup do VAE: BCHW normalizovaný na (-1, 1), bfloat16
                img_np = (np.array(pil_resized.convert("RGB"), dtype=np.float32) / 127.5) - 1.0
                img_t = torch.from_numpy(img_np).permute(2, 0, 1).unsqueeze(0).to(device=device, dtype=pipe.vae.dtype)
                init_latents = pipe.vae.encode(img_t).latent * pipe.vae.config.scaling_factor

                # Exaktní flow matching / diffusion noising pro daný počáteční časový krok
                gen_device = init_latents.device.type
                generator = torch.Generator(device=gen_device).manual_seed(seed + i)
                noise = torch.randn(init_latents.shape, generator=generator, device=init_latents.device, dtype=init_latents.dtype)
                latents = pipe.scheduler.add_noise(init_latents, noise, timesteps[:1])

                # Denoising cyklus výhradně přes zbývající timesteps
                latent_channels = pipe.transformer.config.in_channels
                transformer_dtype = pipe.transformer.dtype
                attention_kwargs = getattr(pipe, "attention_kwargs", None)

                for step_idx, t in enumerate(timesteps):
                    latent_model_input = torch.cat([latents] * 2) if do_cfg else latents
                    timestep = t.expand(latent_model_input.shape[0]) * pipe.transformer.config.timestep_scale

                    noise_pred = pipe.transformer(
                        latent_model_input.to(dtype=transformer_dtype),
                        encoder_hidden_states=prompt_embeds.to(dtype=transformer_dtype),
                        encoder_attention_mask=prompt_attention_mask,
                        timestep=timestep,
                        return_dict=False,
                        attention_kwargs=attention_kwargs,
                    )[0].float()

                    if do_cfg:
                        noise_pred_uncond, noise_pred_text = noise_pred.chunk(2)
                        noise_pred = noise_pred_uncond + guidance_scale * (noise_pred_text - noise_pred_uncond)

                    if pipe.transformer.config.out_channels // 2 == latent_channels:
                        noise_pred = noise_pred.chunk(2, dim=1)[0]

                    latents = pipe.scheduler.step(noise_pred, t, latents, return_dict=False)[0]

                # Dekódování latentů přes tiled VAE
                latents = latents.to(pipe.vae.dtype)
                decoded = pipe.vae.decode(latents / pipe.vae.config.scaling_factor, return_dict=False)[0]
                result_pil = pipe.image_processor.postprocess(decoded, output_type="pil")[0]

                if hasattr(pipe, "maybe_free_model_hooks"):
                    pipe.maybe_free_model_hooks()

                # Hybrid High-Frequency Detail Blending (beads-qis-sana-micro-anatomy-repair-nl7h)
                # DC-AE 32x downsampling destroys sub-token micro-anatomy (eyes, pupils, fingers).
                # Re-inject high-frequency luminance edge details from Lanczos-scaled input.
                if anatomy_fidelity > 0.0:
                    result_pil = self._blend_micro_anatomy(pil_resized, result_pil, anatomy_fidelity)

            out_tensors.append(self._pil_to_bhwc(result_pil))

        # 4. Telemetrie VRAM pro verifikaci 8GB VRAM stropu
        if torch.cuda.is_available():
            peak_mb = torch.cuda.max_memory_allocated() / (1024 ** 2)
            reserved_mb = torch.cuda.max_memory_reserved() / (1024 ** 2)
            print(f"Sana2KUpscaler // Peak VRAM Allocated: {peak_mb:.1f} MB | Reserved: {reserved_mb:.1f} MB (offload: {offload_mode})")

        return (torch.stack(out_tensors, dim=0),)


if DIFFUSERS_AVAILABLE:
    NODE_CLASS_MAPPINGS = {"Sana2KUpscaler": Sana2KUpscalerNode}
    NODE_DISPLAY_NAME_MAPPINGS = {"Sana2KUpscaler": "Sana 2K Upscaler (Diffusers 0.40)"}
else:
    NODE_CLASS_MAPPINGS = {}
    NODE_DISPLAY_NAME_MAPPINGS = {}
    print("Sana2KUpscaler // Notice: 'diffusers' package is not installed. Sana 2K Upscaler node skipped gracefully.")
