.pragma library

function sourceDisplayName(src) {
  switch (String(src).toLowerCase()) {
    case "civitai": return "CivitAI";
    case "midlibrary":
    case "midlibrary.io": return "Midlibrary.io (Styles & Lenses)";
    case "diffusiondb": return "DiffusionDB (14M Dataset)";
    case "seaart":
    case "seaart.ai": return "SeaArt.ai (Anime & LoRA)";
    case "shakker":
    case "shakker.ai": return "Shakker AI (Flux & DiT)";
    case "playground":
    case "playground.com": return "Playground.com (Styles & Art)";
    case "lexica": return "Lexica.art";
    case "prompthero": return "PromptHero";
    case "openart": return "OpenArt.ai";
    case "huggingface": return "Hugging Face (Text Prompt Card)";
    case "krea": return "Krea.ai (Flux & Enhancer)";
    case "tensorart": return "Tensor.art (Models & LoRA)";
    default:
      if (src && String(src).trim().length > 0) {
        var s = String(src).trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
      }
      return "Unknown Source";
  }
}

function sourceIcon(src) {
  return "";
}

function sourcePlaceholder(src) {
  var isCs = false;
  switch (String(src).toLowerCase()) {
    case "civitai":
      return isCs ? "Hledat v CivitAI (např. cyberpunk girl, fantasy portrét, noc)..." : "Search Civitai (e.g. cyberpunk girl, fantasy portrait, night)...";
    case "midlibrary":
    case "midlibrary.io":
      return isCs ? "Hledat v Midlibrary (malíři, optika, kinofilmy, žánry, architekti)..." : "Search Midlibrary (artists, lenses, film stocks, genres, architects)...";
    case "diffusiondb":
      return isCs ? "Hledat v DiffusionDB (fotorealismus, mecha, sci-fi, koncepty)..." : "Search DiffusionDB (photorealism, mecha, sci-fi, concepts)...";
    case "seaart":
    case "seaart.ai":
      return isCs ? "Hledat v SeaArt (anime, fantasy, stylizace, herní postavy)..." : "Search SeaArt (anime, fantasy, stylized, game characters)...";
    case "shakker":
    case "shakker.ai":
      return isCs ? "Hledat v Shakker (Flux, DiT, realistické scény, moderní design)..." : "Search Shakker (Flux, DiT, realistic scenes, modern design)...";
    case "playground":
    case "playground.com":
      return isCs ? "Hledat v Playground (filmové, retro synthwave, surrealismus, pop-art)..." : "Search Playground (cinematic, retro synthwave, surrealism, pop-art)...";
    case "lexica":
      return isCs ? "Hledat v Lexica (např. cinematic lighting, 8k portrait, sci-fi)..." : "Search Lexica (e.g. cinematic lighting, 8k portrait, sci-fi)...";
    case "prompthero":
      return isCs ? "Hledat v PromptHero (např. midjourney style, fashion, macro)..." : "Search PromptHero (e.g. midjourney style, fashion, macro)...";
    case "openart":
      return isCs ? "Hledat v OpenArt (např. concept art, digital painting, 3D render)..." : "Search OpenArt (e.g. concept art, digital painting, 3D render)...";
    case "huggingface":
      return isCs ? "Hledat v Hugging Face (textové prompty, scholar, steampunk, landscape)..." : "Search Hugging Face (text prompts, scholar, steampunk, landscape)...";
    case "krea":
      return isCs ? "Hledat v Krea.ai (např. photorealistic, cinematic, aurora, doberman)..." : "Search Krea.ai (e.g. photorealistic, cinematic, aurora, doberman)...";
    case "tensorart":
      return isCs ? "Hledat v Tensor.art (např. anime, samurai, knight, ink art, dragon)..." : "Search Tensor.art (e.g. anime, samurai, knight, ink art, dragon)...";
    default:
      return isCs ? ("Hledat v " + sourceDisplayName(src) + "...") : ("Search " + sourceDisplayName(src) + "...");
  }
}

function spectralColor(hue, sat, bgLightness, accentColor) {
  var darkTheme = bgLightness < 0.52;
  var val = darkTheme ? 0.94 : 0.65;
  var chroma = darkTheme ? sat : Math.min(0.82, sat * 1.1);
  return Qt.tint(Qt.hsva(hue, chroma, val, 1), Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12));
}

function sourceColor(src, bgLightness, accentColor, urgentColor) {
  switch (String(src).toLowerCase()) {
    case "civitai": return spectralColor(0.60, 0.65, bgLightness, accentColor);
    case "midlibrary":
    case "midlibrary.io": return spectralColor(0.75, 0.60, bgLightness, accentColor);
    case "diffusiondb": return spectralColor(0.42, 0.65, bgLightness, accentColor);
    case "seaart":
    case "seaart.ai": return spectralColor(0.52, 0.68, bgLightness, accentColor);
    case "shakker":
    case "shakker.ai": return spectralColor(0.11, 0.72, bgLightness, accentColor);
    case "playground":
    case "playground.com": return spectralColor(0.92, 0.65, bgLightness, accentColor);
    case "lexica": return spectralColor(0.66, 0.60, bgLightness, accentColor);
    case "prompthero": return urgentColor;
    case "openart": return spectralColor(0.48, 0.65, bgLightness, accentColor);
    case "huggingface": return spectralColor(0.13, 0.75, bgLightness, accentColor);
    case "krea": return spectralColor(0.78, 0.65, bgLightness, accentColor);
    case "tensorart": return spectralColor(0.55, 0.68, bgLightness, accentColor);
    default: return accentColor;
  }
}

function sourceCardBadge(src) {
  var isCs = false;
  switch (String(src).toLowerCase()) {
    case "civitai": return isCs ? "CIVITAI KARTA" : "CIVITAI CARD";
    case "midlibrary":
    case "midlibrary.io": return "MIDLIBRARY";
    case "diffusiondb": return "DIFFUSIONDB";
    case "seaart":
    case "seaart.ai": return "SEAART AI";
    case "shakker":
    case "shakker.ai": return "SHAKKER AI";
    case "playground":
    case "playground.com": return "PLAYGROUND";
    case "lexica": return "LEXICA ART";
    case "prompthero": return "PROMPT HERO";
    case "openart": return "OPENART";
    case "huggingface": return "HUGGING FACE";
    case "krea": return "KREA AI";
    case "tensorart": return "TENSOR ART";
    default: return isCs ? "PROMPT KARTA" : "PROMPT CARD";
  }
}

function sourceCardSubtitle(src) {
  var isCs = false;
  switch (String(src).toLowerCase()) {
    case "civitai": return isCs ? "KOMUNITNÍ LORA & SD" : "COMMUNITY LORA / SD";
    case "midlibrary":
    case "midlibrary.io": return isCs ? "OPTIKA & KINOFILM" : "OPTICS & FILM STYLES";
    case "diffusiondb": return isCs ? "14M DATASET ARCHIV" : "14M DATASET ARCHIVE";
    case "seaart":
    case "seaart.ai": return isCs ? "ANIME & POSTAVY" : "ANIME & CHARACTER";
    case "shakker":
    case "shakker.ai": return isCs ? "FLUX & MODERNÍ DIT" : "FLUX & MODERN DIT";
    case "playground":
    case "playground.com": return isCs ? "STYLY & ILUSTRACE" : "STYLES & ARTWORKS";
    case "lexica": return "STABLE DIFFUSION";
    case "prompthero": return "MIDJOURNEY / FLUX";
    case "openart": return isCs ? "KONCEPTY & 3D ART" : "CONCEPT & DIGITAL ART";
    case "huggingface": return "FLUX / SD 3.5 TEXT";
    case "krea": return isCs ? "FOTOREÁL & ENHANCER" : "PHOTOREAL & ENHANCER";
    case "tensorart": return isCs ? "MODELY & LORA ART" : "MODELS & LORA ART";
    default: return "FLUX / SD 3.5";
  }
}
