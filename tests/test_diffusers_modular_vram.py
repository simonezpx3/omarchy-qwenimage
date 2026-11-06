"""
Unit test for Diffusers 0.40+ Modular Pipeline VRAM management and offload hooks.
Task: beads-prmh
"""
import gc
import unittest

import torch
from diffusers import ModelMixin
from diffusers.modular_pipelines.components_manager import ComponentsManager
from torch import nn


class DummyBlock(ModelMixin):
    def __init__(self, size_mb: int = 100):
        super().__init__()
        num_elements = int(size_mb * 1024 * 1024 / 2)
        self.proj = nn.Linear(512, max(1, num_elements // 512), bias=False, dtype=torch.bfloat16)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return torch.matmul(x, self.proj.weight.t()[:x.shape[-1], :x.shape[-1]])


class TestDiffusersModularVram(unittest.TestCase):
    def setUp(self):
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.reset_peak_memory_stats()

    def test_components_manager_registration(self):
        cm = ComponentsManager()
        mod_a = DummyBlock(10)
        mod_b = DummyBlock(20)

        id_a = cm.add("text_encoder", mod_a)
        id_b = cm.add("transformer", mod_b)

        self.assertIn(id_a, cm.components)
        self.assertIn(id_b, cm.components)
        self.assertEqual(len(cm.components), 2)

    def test_modular_auto_cpu_offload_eviction_under_pressure(self):
        if not torch.cuda.is_available():
            self.skipTest("CUDA not available for VRAM test")

        free_bytes = torch.cuda.mem_get_info()[0]
        if free_bytes < 250 * 1024 * 1024:
            self.skipTest("Insufficient free VRAM for testing (<250MB)")

        cm = ComponentsManager()
        # Use compact 40MB blocks to test eviction logic reliably without OOM
        block_mb = 40
        mod_a = DummyBlock(block_mb)
        mod_b = DummyBlock(block_mb)

        cm.add("text_encoder", mod_a)
        cm.add("transformer", mod_b)

        # Set reserve margin equal to current free memory so any active model
        # is evicted to CPU when a new model requires GPU headroom.
        # Use exact byte count or MiB (binary prefix) to avoid decimal MB mismatch in accelerate.
        margin = free_bytes

        cm.enable_auto_cpu_offload(device="cuda:0", memory_reserve_margin=margin)

        # Models start on CPU
        self.assertEqual(mod_a.device.type, "cpu")
        self.assertEqual(mod_b.device.type, "cpu")

        # Call mod_a -> loaded to CUDA
        x = torch.randn(1, 512, dtype=torch.bfloat16)
        _ = mod_a(x)
        self.assertEqual(mod_a.device.type, "cuda")
        self.assertEqual(mod_b.device.type, "cpu")

        # Call mod_b -> mod_a evicted to CPU under memory pressure
        _ = mod_b(x)
        self.assertEqual(mod_a.device.type, "cpu")
        self.assertEqual(mod_b.device.type, "cuda")


if __name__ == "__main__":
    unittest.main()
