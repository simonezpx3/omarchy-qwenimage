pub(crate) fn is_czech_text(s: &str) -> bool {
    let mut cz_chars = 0;
    for c in s.chars() {
        if "ěščřžýáíéúůťďňóĚŠČŘŽÝÁÍÉÚŮŤĎŇÓ".contains(c) {
            cz_chars += 1;
        }
    }
    if cz_chars >= 2 {
        return true;
    }

    let cz_words = [
        "a", "i", "v", "s", "z", "k", "o", "u", "se", "si", "na", "do", "od", "po", "za", "pro",
        "ve", "ze", "ke", "ku", "to", "ta", "ten", "ti", "ty", "je", "jsou", "byl", "byla", "bylo",
        "bude", "budou", "jako", "jak", "ale", "nebo", "ani", "když", "protože", "který", "která",
        "které", "kteří", "co", "kdo", "kde", "kam", "odkud", "kdy", "proč", "jaký", "jaká", "jaké",
        "obraz", "fotka", "žena", "muž", "dívka", "chlapec", "auto", "les", "strom", "dům", "město",
        "kočka", "pes", "styl", "barva", "světlo", "stín", "detail", "pozadí", "popředí", "krásný",
        "krásná", "krásné", "velký", "velká", "malý", "malá", "černý", "bílý", "červený", "modrý",
        "zelený", "žlutý", "zlatý", "stříbrný", "portrét", "krajina", "digitální", "malba", "kresba",
    ];

    let en_words = [
        "the", "and", "in", "of", "to", "a", "is", "that", "for", "it", "as", "was", "with",
        "on", "at", "by", "this", "be", "are", "from", "or", "an", "not", "but", "what", "all",
        "were", "when", "we", "there", "can", "an", "your", "which", "their", "if", "do", "will",
        "each", "about", "how", "up", "out", "them", "then", "she", "many", "some", "so", "these",
        "would", "other", "into", "has", "more", "her", "two", "like", "him", "see", "time",
        "could", "no", "make", "than", "first", "been", "its", "who", "now", "people", "my",
        "made", "over", "did", "down", "only", "way", "find", "use", "may", "water", "long",
        "very", "after", "words", "called", "just", "where", "most", "know", "portrait", "photo",
        "photograph", "cinematic", "lighting", "ultra", "realistic", "detailed", "render",
        "digital", "art", "style", "illustration", "concept", "octane", "unreal", "engine",
    ];

    let lower = s.to_lowercase();
    let words: Vec<&str> = lower
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .collect();

    if words.is_empty() {
        return false;
    }

    let mut cz_count = 0;
    let mut en_count = 0;

    for w in &words {
        if cz_words.contains(w) {
            cz_count += 1;
        }
        if en_words.contains(w) {
            en_count += 1;
        }
    }

    if cz_chars > 0 && en_count == 0 {
        return true;
    }
    cz_count > en_count
}

pub(crate) fn contains_cyrillic(s: &str) -> bool {
    s.chars()
        .any(|c| matches!(c, '\u{0400}'..='\u{04FF}' | '\u{0500}'..='\u{052F}'))
}

pub(crate) fn needs_english_translation(s: &str) -> bool {
    if contains_cyrillic(s) {
        return false;
    }
    if is_czech_text(s) {
        return true;
    }

    let non_ascii_alpha = s.chars().filter(|c| c.is_alphabetic() && !c.is_ascii()).count();
    let lower = s.to_lowercase();
    let words: Vec<&str> = lower
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .collect();

    if words.is_empty() {
        return false;
    }

    let en_markers = [
        "the", "and", "in", "of", "to", "a", "is", "that", "for", "it", "as", "with",
        "on", "at", "by", "this", "an", "from", "portrait", "photo", "photograph",
        "cinematic", "lighting", "realistic", "detailed", "digital", "art", "style",
    ];
    let en_count = words.iter().filter(|w| en_markers.contains(*w)).count();

    if non_ascii_alpha >= 2 || (non_ascii_alpha >= 1 && en_count < 2) {
        return true;
    }

    let foreign_ascii_markers = [
        "der", "die", "das", "und", "mit", "ein", "eine", "einen", "einer", "auf", "aus", "im",
        "le", "la", "les", "des", "une", "avec", "pour", "dans", "sur", "est", "sont",
        "el", "los", "las", "con", "por", "para", "una", "del", "en",
        "il", "lo", "gli", "di", "che", "non", "nel", "nella",
        "jest", "nie", "tak", "dla", "przez", "jako", "som", "ako", "pre",
    ];
    let foreign_count = words.iter().filter(|w| foreign_ascii_markers.contains(*w)).count();
    foreign_count > en_count
}
