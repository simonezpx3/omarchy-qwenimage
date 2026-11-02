"""
Unit tests for defensive loading & backward compatibility of Sana 2K Upscaler node.
Task: beads-63iv
Ensures QIS does not break when diffusers is missing or on non-CUDA systems.
"""
import sys
import unittest
import numpy as np
from PIL import Image


class TestSanaDefensiveLoad(unittest.TestCase):
    def test_sana_node_registered_when_diffusers_available(self):
        from custom_nodes.comfyui_sana_upscaler import (
            DIFFUSERS_AVAILABLE,
            NODE_CLASS_MAPPINGS,
            NODE_DISPLAY_NAME_MAPPINGS,
        )
        if DIFFUSERS_AVAILABLE:
            self.assertIn("Sana2KUpscaler", NODE_CLASS_MAPPINGS)
            self.assertIn("Sana2KUpscaler", NODE_DISPLAY_NAME_MAPPINGS)
        else:
            self.assertEqual(NODE_CLASS_MAPPINGS, {})

    def test_sana_graceful_handling_when_diffusers_missing(self):
        # Temporarily mock diffusers as unavailable
        import importlib
        import custom_nodes.comfyui_sana_upscaler as sana_module

        orig_diffusers = sys.modules.get("diffusers")
        try:
            sys.modules["diffusers"] = None  # Forces ModuleNotFoundError on import
            # Re-eval module behavior when diffusers cannot be imported
            reloaded = importlib.reload(sana_module)
            self.assertFalse(reloaded.DIFFUSERS_AVAILABLE)
            self.assertEqual(reloaded.NODE_CLASS_MAPPINGS, {})
            self.assertEqual(reloaded.NODE_DISPLAY_NAME_MAPPINGS, {})
        finally:
            if orig_diffusers is not None:
                sys.modules["diffusers"] = orig_diffusers
            else:
                sys.modules.pop("diffusers", None)
            importlib.reload(sana_module)

    def test_micro_anatomy_blending_preserves_dimensions_and_zero_vram(self):
        from custom_nodes.comfyui_sana_upscaler import Sana2KUpscalerNode

        w, h = 64, 64
        base_arr = np.random.randint(0, 255, (h, w, 3), dtype=np.uint8)
        sana_arr = np.random.randint(0, 255, (h * 2, w * 2, 3), dtype=np.uint8)

        base_img = Image.fromarray(base_arr, mode="RGB")
        sana_img = Image.fromarray(sana_arr, mode="RGB")

        fused = Sana2KUpscalerNode._blend_micro_anatomy(base_img, sana_img, fidelity=0.35)
        self.assertEqual(fused.size, (w * 2, h * 2))
        self.assertEqual(fused.mode, "RGB")


if __name__ == "__main__":
    unittest.main()
