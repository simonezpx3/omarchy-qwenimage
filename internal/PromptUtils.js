.pragma library

function sanitizePromptText(text) {
  if (!text) return "";
  var s = String(text);
  s = s.replace(/[\uFFF9-\uFFFB\uFFFD]/g, "");
  s = s.replace(/[\uFEFF\u200B-\u200D\u2060\u00AD]/g, "");
  s = s.replace(/[\u202A-\u202E\u2066-\u2069\u200E\u200F]/g, "");
  s = s.replace(/[\uE000-\uF8FF]/g, "");
  s = s.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, "");
  s = s.replace(/[ \t]+/g, " ");
  s = s.replace(/,\s*,+/g, ", ");
  return s.trim();
}

function _tokenizeWords(text) {
  return String(text || "").toLowerCase().split(/[\s,.;:!?_"'`\(\)\[\]\{\}\/\\~-]+/).filter(Boolean);
}

function detectHumanSubject(text) {
  var kw = [
    "woman", "women", "man", "men", "girl", "girls", "boy", "boys",
    "person", "people", "human", "body", "nude", "naked", "erotic",
    "portrait", "skin", "breasts", "legs", "face", "buttocks", "ass",
    "waist", "hips", "thighs", "female", "male", "model", "hand", "hands",
    "finger", "fingers", "child", "children", "character", "warrior", "elf",
    "slim", "petite", "slender",
    "dívka", "dívky", "žena", "ženy", "muž", "muži", "tělo", "nahá", "nahý",
    "nahé", "akt", "ruce", "ruka", "prsty", "prst", "obličej", "tvář", "postava"
  ];
  var words = _tokenizeWords(text);
  for (var i = 0; i < words.length; ++i) {
    if (kw.indexOf(words[i]) !== -1) return true;
  }
  return false;
}

function detectExplicitNudity(text) {
  var p = String(text || "").toLowerCase();
  var kw = [
    "nude", "nudity", "naked", "topless", "bottomless", "nsfw", "explicit", "uncensored",
    "genitals", "genitalia", "vulva", "vagina", "pussy", "clitoris", "labia",
    "penis", "cock", "dick", "testicles", "nipple", "nipples", "areola", "areolas",
    "pubic", "crotch", "groin", "intercourse", "sex", "porn", "erotic", "hentai",
    "undressed", "unclothed", "barebreasted",
    "nahá", "nahý", "nahé", "nahota", "nahou", "nahého", "akt", "akty",
    "genitálie", "přirození", "bradavky", "bradavka", "rozkrok", "roznožená",
    "svlečená", "svlečený", "erotická", "erotický", "erotické"
  ];
  var words = _tokenizeWords(p);
  for (var i = 0; i < words.length; ++i) {
    if (kw.indexOf(words[i]) !== -1) return true;
  }
  return p.indexOf("full frontal") !== -1
    || p.indexOf("bare breasts") !== -1
    || p.indexOf("exposed breasts") !== -1
    || p.indexOf("spread legs") !== -1
    || p.indexOf("no clothes") !== -1
    || p.indexOf("without clothes") !== -1
    || p.indexOf("bez oblečení") !== -1
    || p.indexOf("úplně nahá") !== -1
    || p.indexOf("úplně nahý") !== -1;
}

function isAnatomyGateDeferred(text, isAutoExpandEnabled) {
  var trimmed = String(text || "").trim();
  if (trimmed === "" || isAutoExpandEnabled) return true;
  return /[^\x00-\x7FěščřžýáíéúůťďňóĚŠČŘŽÝÁÍÉÚŮŤĎŇÓ]/.test(trimmed);
}

function buildGenerationArgs(service, trimmedPrompt) {
  var actualSeed = service.seedLocked ? Number(service.seedVal) : -1;
  var args = [
    service.bridgeBin,
    "generate",
    trimmedPrompt,
    service.aspectRatio,
    String(service.steps),
    String(service.cfg),
    String(actualSeed),
    service.negativePromptText
  ];

  if (service.referencePath !== "") {
    args.push(service.referencePath);
    var clampedDenoise = Math.min(0.95, Math.max(0.05, service.denoise));
    args.push(String(clampedDenoise));
    if (service.inpaintMode && service.activeMaskCanvas) {
      var tmpMask = "/tmp/qis_inpaint_mask_" + Date.now() + ".png";
      if (service.activeMaskCanvas.save(tmpMask)) {
        args.push("--mask");
        args.push(tmpMask);
      }
    }
  }

  if (service.animeMode && service.animeMode !== "off") {
    args.push("--anime", service.animeMode);
  }
  if (service.isTurboEnabled) {
    args.push("--turbo");
  }
  if (service.hereticMode && service.hereticMode !== "off") {
    args.push("--heretic", service.hereticMode);
  }
  if (service.anatomyMode && service.anatomyMode !== "off") {
    args.push("--anatomy", service.anatomyMode);
  }

  args.push("--anatomy-guard", service.anatomyGuardMode || "auto");

  if (service.isAutoExpandEnabled) {
    args.push("--expand");
  }
  if (service.resMode && service.resMode !== "") {
    args.push("--res", service.resMode);
  }
  return args;
}

function applyGenerationEvent(service, line) {
  if (!service) return;
  var trimmed = (line || "").trim();
  if (!trimmed || trimmed.length > 65536) return;
  try {
    var res = JSON.parse(trimmed);
    if (res.event === "preview") {
      service.livePreviewPath = res.path || "";
      service.livePreviewStep = res.step || 0;
      service.livePreviewMaxSteps = res.max_steps || service.steps;
      service.livePreviewTick += 1;
    } else if (res.event === "prompt_expanded") {
      if (typeof res.prompt === "string" && res.prompt.trim() !== "") {
        var safePrompt = sanitizePromptText(res.prompt.slice(0, 8192));
        if (safePrompt !== "") service.promptText = safePrompt;
      }
      if (typeof res.negative === "string" && res.negative.trim() !== "" && service.negativePromptText === "") {
        service.negativePromptText = sanitizePromptText(res.negative.slice(0, 4096));
      }
    } else if (res.status === "ok" && res.path) {
      service.isGenerating = false;
      service.currentScaleFactor = 0.0;
      service.livePreviewPath = "";
      service.previousGeneratedPath = service.generatedPath;
      service.generatedPath = res.path;
      service.baseGeneratedPath = res.path;
      var elapsedSec = (typeof res.elapsed === "number") ? res.elapsed.toFixed(1) : String(res.elapsed || "0");
      service.generationTelemetry = (res.ratio || "1:1") + " | " + (res.steps || service.steps) + " STEPS | " + elapsedSec + "s | SEED: " + (res.seed >= 0 ? res.seed : "RANDOM");
      service.fetchHistory();
    } else if (res.status === "error") {
      service.isGenerating = false;
      service.currentScaleFactor = 0.0;
      service.livePreviewPath = "";
      service.generationTelemetry = "ERROR: " + (res.message || "Generation failed");
    }
  } catch (e) {}
}

function applyOptResult(service, raw) {
  if (!service || !raw || raw.length > 65536) return;
  try {
    var res = JSON.parse(raw);
    if (res.rewritten_prompt && res.rewritten_prompt.trim() !== "") {
      service.promptText = res.rewritten_prompt.trim();
    } else if (res.optimized_prompt && res.optimized_prompt.trim() !== "") {
      service.promptText = res.optimized_prompt.trim();
    }
    if (res.negative_prompt && res.negative_prompt.trim() !== "") {
      service.negativePromptText = res.negative_prompt.trim();
    }
    if (res.wh_ratio && res.wh_ratio.trim() !== "") {
      var ratio = res.wh_ratio.trim();
      var validRatios = ["16:10", "16:9", "1:1", "9:16", "21:9", "4:3", "3:4", "3:2", "2:3"];
      if (validRatios.indexOf(ratio) !== -1) service.aspectRatio = ratio;
    }
  } catch (e) {
    service.promptText = raw;
  }
}
