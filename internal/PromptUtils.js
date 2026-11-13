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
