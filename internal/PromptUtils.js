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
