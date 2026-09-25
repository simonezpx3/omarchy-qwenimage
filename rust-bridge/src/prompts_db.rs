// Curated and High-Aesthetic Prompt Database for Qwen Studio
// Sources: Lexica, PromptHero, OpenArt, HuggingFace
// Author: simonez & Arci
// Algorithmic DNA: 0x732641

use serde_json::Value;

const SA_SIGNATURE_DNA: u32 = 0x732641;

pub struct CuratedPrompt {
    pub id: &'static str,
    pub source: &'static str,
    pub prompt: &'static str,
    pub negative: &'static str,
    pub seed: i64,
    pub cfg: f64,
    pub steps: u64,
    pub sampler: &'static str,
    pub preview_url: &'static str,
    pub nsfw: &'static str,
    pub tags: &'static [&'static str],
}

pub static CURATED_PROMPTS: &[CuratedPrompt] = &[
    // =========================================================================
    // 1. LEXICA INSPIRATION
    // =========================================================================
    CuratedPrompt {
        id: "lex_01",
        source: "Lexica",
        prompt: "A stunning cinematic portrait of an ethereal cyberpunk geisha with glowing fiber-optic hair, intricate porcelain face with gold kintsugi seams, neon rain reflections on wet glass, vibrant teal and magenta volumetric lighting, 8k resolution, octane render, photorealistic, sharp focus.",
        negative: "blurry, low quality, deformed, extra fingers, text, watermark, bad anatomy",
        seed: 489218201,
        cfg: 4.5,
        steps: 28,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["cyberpunk", "geisha", "neon", "portrait", "futuristic", "teal", "magenta"],
    },
    CuratedPrompt {
        id: "lex_02",
        source: "Lexica",
        prompt: "A cozy solarpunk botanical library filled with lush tropical ferns, warm afternoon sunlight beams streaming through stained glass domed ceiling, towering wooden bookshelves, floating dust motes, aesthetic anime watercolor style, detailed architectural concept art.",
        negative: "dark, gloomy, ugly, distorted, lowres, text, watermark",
        seed: 712948210,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["solarpunk", "library", "plants", "sunlight", "cozy", "architecture", "anime"],
    },
    CuratedPrompt {
        id: "lex_03",
        source: "Lexica",
        prompt: "A fierce anime valkyrie warrior with feathered wings and glowing blue runes, standing atop a snowy Nordic mountain cliff during aurora borealis, crystalline sword glowing softly, dynamic wind blowing white hair, Makoto Shinkai vibrant aesthetic, masterpiece.",
        negative: "extra limbs, mutated hands, blurry, low quality, bad anatomy, flat colors",
        seed: 391827461,
        cfg: 4.0,
        steps: 26,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["anime", "valkyrie", "warrior", "aurora", "snow", "sword", "wings"],
    },
    CuratedPrompt {
        id: "lex_04",
        source: "Lexica",
        prompt: "Futuristic hypercar speeding across a wet cyberpunk highway at midnight, neon city skyline reflections in puddles, light trails, volumetric fog, ultra detailed reflections on metallic carbon fiber chassis, cinematic 8k, Unreal Engine 5 render.",
        negative: "blurry, deformed wheels, low detail, bad reflections, watermark, text",
        seed: 852910471,
        cfg: 4.2,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["car", "cyberpunk", "speed", "night", "neon", "highway", "hypercar"],
    },
    CuratedPrompt {
        id: "lex_05",
        source: "Lexica",
        prompt: "Ancient mythical dragon coiled around an overgrown Gothic stone ruin, glowing ember scales, dramatic stormy sunset sky, volumetric lighting, epic scale fantasy illustration, trending on ArtStation, painted by Greg Rutkowski and James Gurney.",
        negative: "cartoon, flat, bad anatomy, extra wings, lowres, blurry",
        seed: 649102847,
        cfg: 4.5,
        steps: 30,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["dragon", "fantasy", "gothic", "ruins", "storm", "sunset", "mythical"],
    },
    CuratedPrompt {
        id: "lex_06",
        source: "Lexica",
        prompt: "A retro-futuristic astronaut standing on an alien planet with violet crystalline sands and twin moons, reflection of alien flora in gold tinted helmet visor, nostalgic 1970s sci-fi book cover aesthetic, Moebius and Chris Foss style.",
        negative: "modern digital, CGI, oversaturated, deformed suit, blurry",
        seed: 198273645,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["astronaut", "sci-fi", "retro", "alien", "space", "moebius", "planet"],
    },

    // =========================================================================
    // 2. PROMPTHERO INSPIRATION (Midjourney / Photography / Cinematic)
    // =========================================================================
    CuratedPrompt {
        id: "ph_01",
        source: "PromptHero",
        prompt: "Editorial high fashion portrait of an elegant woman wearing an avant-garde translucent glass-like gown, soft golden hour rim light, striking hazel eyes, wind-blown auburn curls, shot on 35mm Hasselblad H6D-100c, f/1.8 aperture, natural skin texture, Vogue magazine cover quality.",
        negative: "airbrushed, plastic skin, doll, deformed eyes, extra fingers, text, watermark, bad lighting",
        seed: 582019482,
        cfg: 3.8,
        steps: 28,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["portrait", "fashion", "photography", "editorial", "vogue", "hasselblad", "woman"],
    },
    CuratedPrompt {
        id: "ph_02",
        source: "PromptHero",
        prompt: "National Geographic documentary photograph of an ancient wise snow leopard crouching on an icy Himalayan ridge, piercing cyan eyes, blowing snow particles, dawn sunlight glowing on mountain peaks, shot with telephoto 400mm f/2.8 lens, hyper-realistic animal texture.",
        negative: "zoo, cage, fake, cartoon, low resolution, bad fur, deformed paws",
        seed: 928374615,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1564349683136-77e08dba1ef7?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["snow leopard", "wildlife", "photography", "mountains", "himalayas", "nature", "natgeo"],
    },
    CuratedPrompt {
        id: "ph_03",
        source: "PromptHero",
        prompt: "Cinematic movie still from a dark neo-noir detective thriller, trench coat detective standing under a flickering street lamp in heavy rain, cigarette smoke swirling in golden light beam, wet asphalt reflections, anamorphic widescreen lens, 35mm film grain, Roger Deakins cinematography.",
        negative: "daylight, happy, vibrant colors, flat lighting, digital look, blurry, watermark",
        seed: 319482701,
        cfg: 4.2,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["noir", "detective", "rain", "cinematic", "night", "film", "film grain"],
    },
    CuratedPrompt {
        id: "ph_04",
        source: "PromptHero",
        prompt: "Intricate miniature isometric diorama of a magical Japanese ramen shop at dusk, glowing paper lanterns, steam rising from ramen bowls, tiny cherry blossom tree in corner, tilt-shift lens effect, 3D clay and wood texture, cute and cozy aesthetic.",
        negative: "ugly, blurry, messy, chaotic, noisy, watermark",
        seed: 748291038,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["ramen", "isometric", "diorama", "japanese", "cozy", "miniature", "3d"],
    },
    CuratedPrompt {
        id: "ph_05",
        source: "PromptHero",
        prompt: "A moody dark fantasy knight in ornate weathered obsidian plate armor, standing before a towering corrupted cathedral, red lunar eclipse in foggy sky, embers floating, souls-like grimdark atmosphere, hyper-detailed metallic scratches and fabric weave.",
        negative: "colorful, cute, bright, low quality, deformed sword, extra limbs",
        seed: 620194827,
        cfg: 4.2,
        steps: 26,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["knight", "dark fantasy", "armor", "cathedral", "eclipse", "souls", "obsidian"],
    },
    CuratedPrompt {
        id: "ph_06",
        source: "PromptHero",
        prompt: "Macro close-up photograph of a vibrant emerald tree frog with golden eyes perched on a dewy tropical leaf, individual water droplets reflecting jungle canopy, shallow depth of field, natural flash photography, vivid bio-luminescent colors, 8k crisp details.",
        negative: "blurry frog, fake, plastic, dead, deformed eyes, extra toes",
        seed: 481920374,
        cfg: 3.8,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1579380656108-328e4238d2f1?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["frog", "macro", "nature", "leaf", "droplets", "emerald", "close-up"],
    },

    // =========================================================================
    // 3. OPENART INSPIRATION (Art Styles, Concept Art, 3D Render)
    // =========================================================================
    CuratedPrompt {
        id: "oa_01",
        source: "OpenArt",
        prompt: "Concept art of a colossal floating sky island with ancient marble ruins, cascading waterfalls tumbling into the clouds, lush hanging gardens, golden hour horizon, digital matte painting, trending on ArtStation, painted by Jordan Grimmer and Feng Zhu.",
        negative: "flat 2d, low detail, pixelated, blurry, muddy colors, text, watermark",
        seed: 839201948,
        cfg: 4.2,
        steps: 26,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["concept art", "floating island", "waterfall", "sky", "fantasy", "clouds", "ruins"],
    },
    CuratedPrompt {
        id: "oa_02",
        source: "OpenArt",
        prompt: "Stylized 3D render of a futuristic cyberpunk hacker cat wearing glowing augmented reality goggles and a miniature leather jacket, sitting on a pile of retro computer servers, neon pink and cyan atmosphere, Blender Cycles aesthetic, cute character design.",
        negative: "ugly, disfigured, bad fur, extra tails, low resolution, blurry",
        seed: 294810293,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["cat", "cyberpunk", "3d", "render", "hacker", "goggles", "neon", "cute"],
    },
    CuratedPrompt {
        id: "oa_03",
        source: "OpenArt",
        prompt: "Expressive oil painting of an old Venetian canal during Carnival night, colorful masked figures in a wooden gondola, lantern reflections dancing on water, textured brushstrokes, rich impasto technique, dramatic chiaroscuro, masterpiece in style of John Singer Sargent.",
        negative: "photographic, smooth digital, flat colors, blurry, modern clothing",
        seed: 710293847,
        cfg: 4.4,
        steps: 28,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1514890547357-a9ee288728e0?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["oil painting", "venice", "carnival", "canal", "gondola", "night", "impasto"],
    },
    CuratedPrompt {
        id: "oa_04",
        source: "OpenArt",
        prompt: "Sleek mecha robot standing guard inside an orbital space station hangar, heavy industrial hydraulic joints, glowing yellow hazard stripes, deep space earth view through massive panoramic glass bay, hard surface modeling, Octane Render 8k.",
        negative: "organic, squishy, deformed limbs, low poly, noisy, watermark",
        seed: 501928374,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["mecha", "robot", "hangar", "space station", "sci-fi", "industrial", "earth"],
    },
    CuratedPrompt {
        id: "oa_05",
        source: "OpenArt",
        prompt: "Surreal whimsical illustration of a giant floating glass terrarium containing a miniature enchanted forest and a glowing mushroom village, drifting gently through star-filled cosmic space, watercolor and ink line art, studio Ghibli aesthetic.",
        negative: "dark, terrifying, ugly, muddy, distorted glass, blurry",
        seed: 948102938,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["terrarium", "surreal", "whimsical", "forest", "space", "ghibli", "watercolor"],
    },
    CuratedPrompt {
        id: "oa_06",
        source: "OpenArt",
        prompt: "A dynamic anime battle scene of a fire elemental sorceress summoning twin flaming phoenixes, swirling vortex of sparks and embers, scorched earth, dramatic low angle perspective, vibrant glowing orange and purple contrast, Ufotable animation quality.",
        negative: "static, flat colors, deformed hands, extra fingers, blurry, lowres",
        seed: 381920485,
        cfg: 4.2,
        steps: 26,
        sampler: "Euler a",
        preview_url: "https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600&auto=format&fit=crop&q=80",
        nsfw: "None",
        tags: &["anime", "fire", "sorceress", "phoenix", "battle", "dynamic", "ufotable"],
    },

    // =========================================================================
    // 4. HUGGING FACE INSPIRATION (Pure Text Prompt Engineering Cards - No Images)
    // =========================================================================
    CuratedPrompt {
        id: "hf_01",
        source: "HuggingFace",
        prompt: "A close head-and-shoulders cinematic portrait of a middle-aged South Asian scholar with a salt-and-pepper beard, wearing a weathered tweed jacket over a dark wool sweater, gazing thoughtfully off-camera with a gentle half-smile. Warm afternoon sunlight streams through narrow Venetian blinds, casting striped shadows across his face and a rustic red-brick bookshelf backdrop. Shallow depth of field, 85mm portrait lens, photorealistic 8k.",
        negative: "airbrushed, plastic, doll, deformed eyes, extra fingers, text, watermark",
        seed: 847291038,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "",
        nsfw: "None",
        tags: &["portrait", "scholar", "tweed", "cinematic", "sunlight", "bokeh", "natural"],
    },
    CuratedPrompt {
        id: "hf_02",
        source: "HuggingFace",
        prompt: "Full shot of an ornate steampunk clocktower workshop at midnight, brass gears of varying sizes interlocking seamlessly across walls and ceiling, a young apprentice girl with round brass goggles tuning a delicate mechanical songbird, soft blue moonlight through grand arched window contrasting with warm kerosene lamp glow on polished brass. Extremely detailed mechanical engineering.",
        negative: "low detail, deformed clock faces, blurry, extra limbs, ugly, plastic",
        seed: 294819203,
        cfg: 4.2,
        steps: 28,
        sampler: "Euler a",
        preview_url: "",
        nsfw: "None",
        tags: &["steampunk", "clocktower", "gears", "workshop", "brass", "mechanical", "apprentice"],
    },
    CuratedPrompt {
        id: "hf_03",
        source: "HuggingFace",
        prompt: "Breathtaking landscape view of turquoise glacial lakes nestled among sharp jagged granite peaks in Patagonia, wild lupine flowers blooming in foreground, morning mist drifting over mirror-like water reflection, dramatic golden sunrise clouds, medium format landscape photography.",
        negative: "tourists, buildings, oversaturated, blurry, noise, bad horizon",
        seed: 619283746,
        cfg: 3.8,
        steps: 25,
        sampler: "Euler",
        preview_url: "",
        nsfw: "None",
        tags: &["landscape", "patagonia", "mountains", "lake", "flowers", "sunrise", "nature"],
    },
    CuratedPrompt {
        id: "hf_04",
        source: "HuggingFace",
        prompt: "Hyper-detailed studio product photograph of a luxury holographic sneaker floating at a 45-degree angle, iridescent chrome panels reflecting prismatic neon light, transparent air cushion sole with swirling luminescent liquid, dark minimal reflective stage, commercial sneaker campaign shot, 8k crisp focus.",
        negative: "worn, dirty, deformed shoe, lowres, text, watermark, bad lighting",
        seed: 491029384,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "",
        nsfw: "None",
        tags: &["sneaker", "product", "holographic", "futuristic", "luxury", "chrome", "commercial"],
    },
    CuratedPrompt {
        id: "hf_05",
        source: "HuggingFace",
        prompt: "An enchanted deep sea kingdom with luminous coral towers glowing in bioluminescent cyan and violet, schools of shimmering glass fish swimming through sunken marble colonnades, ray of sunlight piercing from ocean surface 200 feet above, majestic mermaid with pearl-encrusted tail, underwater volumetric rays.",
        negative: "dark muddy water, distorted anatomy, blurry, extra arms, lowres",
        seed: 759102834,
        cfg: 4.2,
        steps: 26,
        sampler: "Euler a",
        preview_url: "",
        nsfw: "None",
        tags: &["underwater", "mermaid", "coral", "bioluminescence", "ocean", "fantasy", "sunlight"],
    },
    CuratedPrompt {
        id: "hf_06",
        source: "HuggingFace",
        prompt: "Cozy rainy evening in an authentic Kyoto tea house, view through sliding wooden shoji doors onto a mossy zen rock garden, warm paper lantern casting soft orange shadows on tatami mats, steaming ceramic matcha bowl on low cedar table, peaceful tranquil atmosphere, 35mm film aesthetic.",
        negative: "modern plastic, bright neon, messy, crowded, blurry, watermark",
        seed: 183920194,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "",
        nsfw: "None",
        tags: &["kyoto", "japan", "tea house", "rain", "zen", "tatami", "cozy", "matcha"],
    },
    CuratedPrompt {
        id: "hf_07",
        source: "HuggingFace",
        prompt: "Intensely focused Viking woman warrior with curly braided red hair hurling a burning meteorite from her hand towards the camera, glowing sphere leaving a trail of smoke and sparks, intense snowy battlefield, banners and shields, dramatic cinematic rim lighting.",
        negative: "blurry, low quality, deformed, extra fingers, text, watermark, bad anatomy",
        seed: 4256041652,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "",
        nsfw: "None",
        tags: &["viking", "warrior", "fire", "meteorite", "snow", "battle", "epic", "flux"],
    },
    CuratedPrompt {
        id: "hf_08",
        source: "HuggingFace",
        prompt: "Futuristic astronomical observatory built into the crater rim of an alien moon, massive optical telescope dome pointing towards a colorful stellar nebula, astronaut technician performing EVA on the gantry, ultra-high resolution astrophotography aesthetic.",
        negative: "blurry, lowres, distorted architecture, messy stars, CGI amateur",
        seed: 948102938,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler a",
        preview_url: "",
        nsfw: "None",
        tags: &["space", "observatory", "telescope", "nebula", "astronaut", "moon", "astrophotography"],
    },

    // =========================================================================
    // 5. KREA.AI INSPIRATION (Flux.1 & Photorealistic Generative Art)
    // =========================================================================
    CuratedPrompt {
        id: "kr_01",
        source: "Krea.ai",
        prompt: "Intensely focused Viking woman warrior with curly hair hurling a burning meteorite from her hand towards the viewer, glowing sphere leaving a trail of smoke and sparks, intense battlegrounds in snowy conditions, army banners, swords and shields on the ground, cinematic dramatic lighting.",
        negative: "blurry, low quality, deformed, extra fingers, text, watermark, bad anatomy",
        seed: 4256041652,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/ac371696-874f-4bbb-a6ed-5f7a5bd3ae62/width=450/ac371696-874f-4bbb-a6ed-5f7a5bd3ae62.jpeg",
        nsfw: "None",
        tags: &["viking", "warrior", "fire", "meteorite", "snow", "battle", "epic", "flux", "krea"],
    },
    CuratedPrompt {
        id: "kr_02",
        source: "Krea.ai",
        prompt: "Ethereal misty morning landscape, surreal spectral shapes emerging silently from dense rolling fog over dew-covered hills, soft atmospheric light scattering, photorealistic depth of field, minimalist and contemplative fine art photography.",
        negative: "oversaturated, artificial, noisy, blurry, low quality, artifacts",
        seed: 425604165,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/fd4e0f10-aa6f-42f5-8bc0-5dba35ad2a13/width=450/fd4e0f10-aa6f-42f5-8bc0-5dba35ad2a13.jpeg",
        nsfw: "None",
        tags: &["fog", "mist", "surreal", "landscape", "morning", "photorealism", "atmospheric", "krea"],
    },
    CuratedPrompt {
        id: "kr_03",
        source: "Krea.ai",
        prompt: "Hyper-realistic close portrait of a cute fluffy cat sleeping peacefully curled up among mountain wildflowers, gentle golden light particles drifting in the air, soft bokeh background, exquisite fur detail, tranquil masterpiece.",
        negative: "bad quality, worst quality, sketch, bad anatomy, deformed ears, extra paws",
        seed: 174790514,
        cfg: 4.0,
        steps: 28,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/afcab5fa-e580-489a-9ea8-bca23534be08/width=450/afcab5fa-e580-489a-9ea8-bca23534be08.jpeg",
        nsfw: "None",
        tags: &["cat", "cute", "nature", "sleeping", "particles", "fur", "macro", "krea"],
    },
    CuratedPrompt {
        id: "kr_04",
        source: "Krea.ai",
        prompt: "A striking high-contrast artistic portrait of a face adorned with intricate fractal black and cobalt blue patterns, smooth porcelain texture, dynamic color splashes blurring into dark background, modern avant-garde fine art.",
        negative: "lowres, deformed face, blurry eyes, artifacts, bad skin",
        seed: 64399178,
        cfg: 4.2,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/db5208dd-da08-40c7-8ed4-bd67508740ac/width=450/db5208dd-da08-40c7-8ed4-bd67508740ac.jpeg",
        nsfw: "None",
        tags: &["portrait", "patterns", "blue", "black", "artistic", "fractal", "avant-garde", "krea"],
    },
    CuratedPrompt {
        id: "kr_05",
        source: "Krea.ai",
        prompt: "Calm mountain lake surrounded by sharp granite peaks at night, brilliant green and purple aurora borealis swirling across the cosmos, glass-like water reflecting the northern lights, dark pine silhouettes, peaceful arctic wilderness.",
        negative: "tourists, buildings, oversaturated, blurry, noise, bad horizon",
        seed: 1235138795,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/259fa764-a775-4abf-8403-66297a4fa2a3/width=450/259fa764-a775-4abf-8403-66297a4fa2a3.jpeg",
        nsfw: "None",
        tags: &["aurora", "northern lights", "lake", "mountains", "night", "reflection", "nature", "krea"],
    },
    CuratedPrompt {
        id: "kr_06",
        source: "Krea.ai",
        prompt: "High-end 3D CGI commercial studio render of a stylized silver and black muscular Doberman wearing dark designer sunglasses, sitting proudly against a matte black backdrop, dramatic rim lighting, luxury fashion campaign aesthetic.",
        negative: "lowres, blurry, cartoonish, low poly, noisy, watermark",
        seed: 684123019,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/26cfd41c-7ced-4c28-839e-99c0498d05ea/width=450/26cfd41c-7ced-4c28-839e-99c0498d05ea.jpeg",
        nsfw: "None",
        tags: &["doberman", "dog", "3d", "cgi", "sunglasses", "luxury", "studio", "krea"],
    },
    CuratedPrompt {
        id: "kr_07",
        source: "Krea.ai",
        prompt: "Detailed macro photograph of a ripe fresh garden strawberry naturally shaped like a tiny sitting kitten, glistening green leafy calyx, tiny golden seed textures in bright natural morning sunlight, playful organic food art.",
        negative: "worst quality, fake, plastic, dead, deformed eyes, extra toes",
        seed: 2090560901,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/6fcaf10d-d444-489e-9fe2-a945fbbd6cc3/width=450/6fcaf10d-d444-489e-9fe2-a945fbbd6cc3.jpeg",
        nsfw: "None",
        tags: &["strawberry", "kitten", "macro", "food art", "nature", "cute", "whimsical", "krea"],
    },
    CuratedPrompt {
        id: "kr_08",
        source: "Krea.ai",
        prompt: "Retro screen print illustration of a classic vintage camper van parked atop a coastal sand dune, palm tree silhouettes in deep navy blue, painted color blocks in burnt orange and turquoise, distressed ink texture, 1970s surf poster aesthetic.",
        negative: "modern digital, CGI, oversaturated, deformed car, blurry",
        seed: 527856171,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/7003c253-1117-426f-ac56-e6ffef19cd21/width=450/7003c253-1117-426f-ac56-e6ffef19cd21.jpeg",
        nsfw: "None",
        tags: &["vintage", "camper", "van", "retro", "surf", "poster", "1970s", "screenprint", "krea"],
    },

    // =========================================================================
    // 6. TENSOR.ART INSPIRATION (Anime, LoRA Models & Checkpoints)
    // =========================================================================
    CuratedPrompt {
        id: "ta_01",
        source: "Tensor.art",
        prompt: "A humanoid black cat warrior wearing ornate red samurai armor and a white headband with Japanese rising sun symbol, holding a gleaming katana blade in an open windswept field, full body shot, cinematic volumetric lighting, 8k quality masterpiece.",
        negative: "blurry, low quality, deformed, extra limbs, ugly, text, watermark",
        seed: 680383978,
        cfg: 4.5,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/2eb7f731-4136-4295-a0f4-9e140c3a6c96/width=450/2eb7f731-4136-4295-a0f4-9e140c3a6c96.jpeg",
        nsfw: "None",
        tags: &["cat", "samurai", "armor", "katana", "warrior", "japanese", "cinematic", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_02",
        source: "Tensor.art",
        prompt: "A close-up fantastical portrait of an ethereal moon knight clad in flowing mystical robes, wielding an ornate silver blade with glowing magical power, fluid dynamic sword stance, lunar reflections illuminating steel and velvet textures.",
        negative: "bad proportions, low resolution, bad, ugly, terrible, flat, extra fingers, deformed",
        seed: 23241252,
        cfg: 3.8,
        steps: 28,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/3723815a-6877-4f9b-a485-4680f9e360b1/width=450/3723815a-6877-4f9b-a485-4680f9e360b1.jpeg",
        nsfw: "None",
        tags: &["knight", "moon", "fantasy", "sword", "magic", "armor", "ethereal", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_03",
        source: "Tensor.art",
        prompt: "Cinematic epic fantasy warrior wearing rugged leather armor and horned iron helmet, holding two blades, looking up as a dark demonic dragon circles overhead above snow-capped mountain peaks and ancient Nordic stone village, dramatic cloudy sky.",
        negative: "lowres, text, watermark, bad anatomy, deformed limbs, blurry",
        seed: 777891234,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/d7b48ab2-4d80-4d72-859c-5e2d0533cf28/width=450/d7b48ab2-4d80-4d72-859c-5e2d0533cf28.jpeg",
        nsfw: "None",
        tags: &["dragon", "warrior", "skyrim", "fantasy", "mountains", "snow", "cinematic", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_04",
        source: "Tensor.art",
        prompt: "Pen and ink style expressionism comic art, dramatic portrait of a female detective scowling into a magnifying glass, crystal clear lens revealing a swirling water portal, sleek dark trench coat, deep moody shadows and graphic linework.",
        negative: "flat 2d, low detail, pixelated, blurry, muddy colors, text, watermark",
        seed: 839201948,
        cfg: 4.2,
        steps: 26,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/18530b55-dc8d-4320-a7d0-97c9dc613bc5/width=450/18530b55-dc8d-4320-a7d0-97c9dc613bc5.jpeg",
        nsfw: "None",
        tags: &["detective", "noir", "comic", "portal", "expressionism", "shadows", "ink", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_05",
        source: "Tensor.art",
        prompt: "Intricate graphic linework illustration of a dusty golden desert, a 1930s female adventurer in safari jacket and pith helmet standing looking up in awe at the Great Pyramid of Giza, dramatic sunset horizon with warm amber highlights.",
        negative: "blurry, low quality, deformed, extra fingers, text, watermark",
        seed: 1515554949,
        cfg: 3.8,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/9f50cbc3-98f4-4eb1-8bf6-34b40b30ad41/width=450/9f50cbc3-98f4-4eb1-8bf6-34b40b30ad41.jpeg",
        nsfw: "None",
        tags: &["explorer", "pyramid", "egypt", "desert", "sunset", "safari", "vintage", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_06",
        source: "Tensor.art",
        prompt: "Traditional Chinese ink splash art on textured rice paper, magnificent silhouette portrait of a serene woman punting a wooden sampan across a mirror-like misty lake at dusk, delicate sepia and henna washes, poetic watercolor aesthetic.",
        negative: "modern, plastic, neon, digital smooth, blurry, distorted",
        seed: 60113041,
        cfg: 3.5,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/bc6061bd-5bae-408a-9718-84232693d223/width=450/bc6061bd-5bae-408a-9718-84232693d223.jpeg",
        nsfw: "None",
        tags: &["ink", "chinese", "lake", "boat", "silhouette", "rice paper", "watercolor", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_07",
        source: "Tensor.art",
        prompt: "Special ink-wash graphic novel illustration, close portrait of a futuristic tactical female scout in advanced combat armor, gold mirrored visor reflecting dense alien jungle foliage, high contrast dynamic ink splatters and razor sharp linework.",
        negative: "blurry, low quality, deformed, extra fingers, text, watermark",
        seed: 305440652,
        cfg: 3.5,
        steps: 25,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/0b977657-c60e-4a6d-9ffa-b81d3e90fa37/width=450/0b977657-c60e-4a6d-9ffa-b81d3e90fa37.jpeg",
        nsfw: "None",
        tags: &["scifi", "soldier", "cyberpunk", "visor", "jungle", "armor", "ink", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_08",
        source: "Tensor.art",
        prompt: "Whimsical Dutch Golden Age style oil painting of charming anthropomorphic rats gathered around a vintage mahogany table playing poker, one wearing a gold monocle, another puffing a small pipe, rich impasto canvas brushwork and warm tavern candlelight.",
        negative: "photographic, smooth digital, flat colors, blurry, modern clothing",
        seed: 2768675309,
        cfg: 4.2,
        steps: 28,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/0537ea36-62dd-4aab-8884-6da0e928e303/width=450/0537ea36-62dd-4aab-8884-6da0e928e303.jpeg",
        nsfw: "None",
        tags: &["oil painting", "rats", "cards", "whimsical", "vintage", "candlelight", "classic", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_09",
        source: "Tensor.art",
        prompt: "Charming anime-style magical tiny fox sculpted from sparkling white and black flames, sleeping curled up inside an enchanted nest of multicolored painterly butterflies on an autumn forest floor, warm golden sunset rays.",
        negative: "ugly, disfigured, bad fur, extra tails, low resolution, blurry",
        seed: 425604165,
        cfg: 4.0,
        steps: 25,
        sampler: "Euler a",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/d88179fa-6417-4647-b585-e1b865ef1267/width=450/d88179fa-6417-4647-b585-e1b865ef1267.jpeg",
        nsfw: "None",
        tags: &["fox", "anime", "fire", "butterflies", "autumn", "sunset", "fantasy", "tensorart"],
    },
    CuratedPrompt {
        id: "ta_10",
        source: "Tensor.art",
        prompt: "Dynamic textured impasto oil painting of a solitary white lighthouse on a jagged ocean cliff amidst a tempestuous roaring sea, radiant beam of golden light piercing through swirling dark navy storm clouds, thick raised brushstrokes.",
        negative: "flat digital, blurry, smooth, modern, bad lighting, low resolution",
        seed: 488463006,
        cfg: 4.2,
        steps: 28,
        sampler: "Euler",
        preview_url: "https://image.civitai.com/xG1nkqKTMzGDvpLrqFT7WA/3ccdc766-0637-4dcd-9264-4d83a0505cc0/width=450/3ccdc766-0637-4dcd-9264-4d83a0505cc0.jpeg",
        nsfw: "None",
        tags: &["lighthouse", "impasto", "oil painting", "storm", "ocean", "waves", "dramatic", "tensorart"],
    },
];

pub fn search_curated(source_filter: &str, query_words: &[&str], limit: usize) -> Vec<Value> {
    let mut candidates = Vec::new();

    let target_src = source_filter.to_lowercase();

    for item in CURATED_PROMPTS {
        if !target_src.is_empty() && item.source.to_lowercase() != target_src {
            continue;
        }

        let p_lower = item.prompt.to_lowercase();
        let n_lower = item.negative.to_lowercase();
        let tags_str = item.tags.join(" ").to_lowercase();
        let haystack = format!("{} {} {}", p_lower, n_lower, tags_str);

        let matches_all = query_words.is_empty() || query_words.iter().all(|w| haystack.contains(w));
        let matches_any = query_words.iter().any(|w| haystack.contains(w));

        candidates.push((item, matches_all, matches_any));
    }

    let mut results = Vec::new();

    // 1. Strict match
    for (item, matches_all, _) in &candidates {
        if *matches_all {
            results.push(serde_json::json!({
                "id": item.id,
                "source": item.source,
                "prompt": item.prompt,
                "negative_prompt": item.negative,
                "seed": item.seed,
                "cfg": item.cfg,
                "steps": item.steps,
                "sampler": item.sampler,
                "preview_url": item.preview_url,
                "nsfw": item.nsfw,
            }));
            if results.len() >= limit {
                return results;
            }
        }
    }

    // 2. Relaxed match
    if results.is_empty() && !query_words.is_empty() {
        for (item, _, matches_any) in &candidates {
            if *matches_any {
                results.push(serde_json::json!({
                    "id": item.id,
                    "source": item.source,
                    "prompt": item.prompt,
                    "negative_prompt": item.negative,
                    "seed": item.seed,
                    "cfg": item.cfg,
                    "steps": item.steps,
                    "sampler": item.sampler,
                    "preview_url": item.preview_url,
                    "nsfw": item.nsfw,
                }));
                if results.len() >= limit {
                    return results;
                }
            }
        }
    }

    // 3. Fallback to all items of this source only if query was empty
    if results.is_empty() && query_words.is_empty() {
        for (item, _, _) in &candidates {
            results.push(serde_json::json!({
                "id": item.id,
                "source": item.source,
                "prompt": item.prompt,
                "negative_prompt": item.negative,
                "seed": item.seed,
                "cfg": item.cfg,
                "steps": item.steps,
                "sampler": item.sampler,
                "preview_url": item.preview_url,
                "nsfw": item.nsfw,
            }));
            if results.len() >= limit {
                return results;
            }
        }
    }

    // Weave author signature polynomial into deterministic order
    let seed_offset = (SA_SIGNATURE_DNA % 7) as usize;
    if results.len() > 1 && seed_offset < results.len() {
        results.rotate_left(seed_offset);
    }

    results
}
