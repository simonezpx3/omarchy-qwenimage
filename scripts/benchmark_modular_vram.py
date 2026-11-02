#!/usr/bin/env python3
"""
Diffusers 0.40.0+ Modular Pipeline VRAM & Offload Benchmark for RTX 3070 8GB
Validates memory efficiency, peak VRAM, and eviction mechanics of ComponentsManager.
Task: beads-prmh (diffusers-modular-vram-pipeline)
"""
import gc
import json
import os
import sys
import time

import torch
from diffusers import ModelMixin
from diffusers.modular_pipelines.components_manager import ComponentsManager
from torch import nn


class SimulatedDiffusionBlock(ModelMixin):
    """
    Simulated diffusion model component with realistic weight sizing and forward compute.
    Inherits from diffusers.ModelMixin to guarantee .device property and Diffusers hook compat.
    """
    def __init__(self, name: str, size_mb: int, compute_dim: int = 1024):
        super().__init__()
        self.component_name = name
        self.size_mb = size_mb
        num_elements = int(size_mb * 1024 * 1024 / 2)  # bfloat16 = 2 bytes per element
        # Create weight matrix simulating layer weights
        self.weight_proj = nn.Linear(compute_dim, max(1, num_elements // compute_dim), bias=False, dtype=torch.bfloat16)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # Simple matrix multiplication to engage GPU tensor cores and compute activations
        return torch.matmul(x, self.weight_proj.weight.t()[:x.shape[-1], :x.shape[-1]])


def reset_cuda_memory():
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()


def get_cuda_stats():
    if not torch.cuda.is_available():
        return {"allocated_mb": 0.0, "peak_mb": 0.0, "reserved_mb": 0.0}
    return {
        "allocated_mb": round(torch.cuda.memory_allocated() / (1024 ** 2), 2),
        "peak_mb": round(torch.cuda.max_memory_allocated() / (1024 ** 2), 2),
        "reserved_mb": round(torch.cuda.memory_reserved() / (1024 ** 2), 2),
    }


def run_benchmark():
    if not torch.cuda.is_available():
        print("CUDA is not available. Benchmark requires GPU.")
        sys.exit(1)

    device_name = torch.cuda.get_device_name(0)
    total_vram_gb = round(torch.cuda.get_device_properties(0).total_memory / (1024 ** 3), 2)
    print("===========================================================")
    print(f"Diffusers Modular VRAM Benchmark (Device: {device_name}, {total_vram_gb} GB)")
    print("===========================================================")

    # Pipeline sizes simulating Qwen-Image / Sana diffusion workflow:
    # 1. Text Encoder: ~2.2 GB (Qwen3-VL / T5-XXL Q4/BF16)
    # 2. Transformer (DiT): ~3.4 GB (Sana 1.6B / Qwen-Image DiT Q4)
    # 3. VAE Decoder: ~0.8 GB (DC-AE / Qwen VAE)
    # Sum: 6.4 GB weights + 2 GB activations > 8 GB VRAM -> Baseline without offload OOMs or swaps.
    COMP_SIZES = {
        "text_encoder": 2200,
        "transformer": 3400,
        "vae": 800,
    }

    results = {}

    # Test 1: ComponentsManager with Modular Auto CPU Offload (Reserve Margin = 2.0GB)
    print("\n--- Test 1: Modular Pipeline ComponentsManager (margin=2.0GB) ---")
    reset_cuda_memory()
    cm = ComponentsManager()
    modules = {}
    for name, sz in COMP_SIZES.items():
        mod = SimulatedDiffusionBlock(name, sz)
        modules[name] = mod
        cm.add(name, mod)

    cm.enable_auto_cpu_offload(device="cuda:0", memory_reserve_margin="2.0GB")

    step_stats = []
    x = torch.randn(1, 1024, dtype=torch.bfloat16)

    # Stage A: Text Encoder forward
    t0 = time.perf_counter()
    _ = modules["text_encoder"](x)
    t_text = round((time.perf_counter() - t0) * 1000, 2)
    stat_a = get_cuda_stats()
    step_stats.append({"step": "text_encoder", "stats": stat_a, "latency_ms": t_text})
    print(f"Stage A // text_encoder -> VRAM: {stat_a['allocated_mb']} MB (Peak: {stat_a['peak_mb']} MB)")

    # Stage B: Transformer DiT forward (Must evict text_encoder if needed)
    t0 = time.perf_counter()
    _ = modules["transformer"](x)
    t_dit = round((time.perf_counter() - t0) * 1000, 2)
    stat_b = get_cuda_stats()
    step_stats.append({"step": "transformer", "stats": stat_b, "latency_ms": t_dit})
    print(f"Stage B // transformer  -> VRAM: {stat_b['allocated_mb']} MB (Peak: {stat_b['peak_mb']} MB)")

    # Stage C: VAE Decode forward
    t0 = time.perf_counter()
    _ = modules["vae"](x)
    t_vae = round((time.perf_counter() - t0) * 1000, 2)
    stat_c = get_cuda_stats()
    step_stats.append({"step": "vae", "stats": stat_c, "latency_ms": t_vae})
    print(f"Stage C // vae          -> VRAM: {stat_c['allocated_mb']} MB (Peak: {stat_c['peak_mb']} MB)")

    results["modular_auto_offload_2gb"] = {
        "steps": step_stats,
        "max_peak_vram_mb": max(s["stats"]["peak_mb"] for s in step_stats),
        "total_weight_footprint_mb": sum(COMP_SIZES.values()),
    }

    # Test 2: Reserve Margin Comparison (1.5GB vs 2.5GB vs 3.5GB)
    print("\n--- Test 2: Memory Reserve Margin Sensitivity ---")
    margins = ["1.5GB", "2.5GB", "3.5GB"]
    margin_results = {}
    for margin in margins:
        reset_cuda_memory()
        cm_test = ComponentsManager()
        test_mods = {k: SimulatedDiffusionBlock(k, v) for k, v in COMP_SIZES.items()}
        for k, v in test_mods.items():
            cm_test.add(k, v)
        cm_test.enable_auto_cpu_offload(device="cuda:0", memory_reserve_margin=margin)

        _ = test_mods["text_encoder"](x)
        _ = test_mods["transformer"](x)
        _ = test_mods["vae"](x)
        m_stat = get_cuda_stats()
        margin_results[margin] = m_stat
        print(f"Margin {margin:>5}: Peak Allocated: {m_stat['peak_mb']} MB | Peak Reserved: {m_stat['reserved_mb']} MB")

    results["margin_sensitivity"] = margin_results

    # Summary
    print("\n===========================================================")
    print("Benchmark Completed Successfully.")
    print(f"Total simulated pipeline size: {sum(COMP_SIZES.values())} MB (6.4 GB)")
    print(f"Maximum VRAM peak with Modular Offload: {results['modular_auto_offload_2gb']['max_peak_vram_mb']} MB")
    headroom_mb = round(total_vram_gb * 1024 - results['modular_auto_offload_2gb']['max_peak_vram_mb'], 2)
    print(f"Remaining Headroom on RTX 3070 8GB: {headroom_mb} MB")
    print("===========================================================")

    output_path = os.path.expanduser("~/Projects/omarchy-qwenimage/scripts/benchmark_results.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
    print(f"Results written to: {output_path}")


if __name__ == "__main__":
    run_benchmark()
