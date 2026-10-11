# Changelog — QIS (Qwen Image Studio)

Všechny významné změny, audity a bezpečnostní opravy projektu jsou zaznamenávány v tomto souboru. Formát vychází z [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) a dodržuje [Semantic Versioning](https://semver.org/).

---

## [1.1.6] — 2026-10-11

### Security & Hardening (Omarchy Marketplace Audit — Issue #10447)
- **Eliminace Qt Wayland Clipboard readeru v Civitai vyhledávání:** Vyhledávací pole `searchField` v `views/CivitaiView.qml` bylo přebudováno z nativního `TextField` (dědícího `QQuickTextInput` s implicitním C++ napojením na `QClipboard::dataChanged`) na zakázkový `FocusScope`. V C++ Qt vrstvě tak vůbec nevzniká žádný `QQuickTextInput` objekt.
- **Nulové spojení se systémovou schránkou uvnitř shellu:** Nové vyhledávací pole nemá žádné kontextové menu, žádné automatické `canPaste` dotazování a žádné nekontrolované streamování dat z Wayland schránky.
- **Bezpečné vkládání přes izolovaný Rust bridge:** Klávesové zkratky pro vložení (`Super + V`, `Ctrl + V`, `Shift + Insert`) jsou zachyceny a směrovány výhradně do našeho Rust bridge (`bin/qwen-bridge paste-text`) s pevným deadlinem 1,2 s a limitem 16 KiB.
- **Blokace Wayland Primary Selection:** Zablokováno vkládání prostředním tlačítkem myši (`Qt.MiddleButton`), které na Waylandu četlo neomezený primary selection stream.

---

## [1.1.5] — 2026-10-11

### Security & Hardening (Omarchy Marketplace Audit — Issue #10447)
- **Neutralizace nekontrolovaného Qt Clipboard streamu:** V `views/StudioView.qml` bylo deaktivováno nativní kontextové menu v textových editorech (`ContextMenu.menu: null`), čímž se zamezilo volání nativního Qt clipboard readeru.
- **Podpora Omarchy klávesových zkratek:** Do `Keys.onShortcutOverride` a `Keys.onPressed` implementována podpora pro systémové vložení přes **`Super + V`** (MetaModifier) i standardní `Ctrl + V` a `Shift + Insert`.
- **Ochrana před Middle-Click DoS:** Zablokováno vkládání prostředním tlačítkem myši (`Qt.MiddleButton`), které na Waylandu četlo neomezený primary selection stream.
- **Bounded Stream Reader (`rust-bridge`):** Zavedena funkce `bounded_cmd` s nekompromisním paměťovým limitem **16 KiB** a deadlinem **1,2 s** na čtení `wl-paste` s okamžitým procesním ukončením při překročení.
- **Eliminace odchozího síťového provozu:** Z bridge bylo kompletně odstraněno stahování HTTP/HTTPS odkazů nalezených ve schránce (100% local-first standard).
- **Eliminace zranitelnosti DropArea (Qt Wayland MIME Reader):** Komponenta `DropArea` byla z QML kompletně odstraněna. Přístup k `drag.urls` v Qt Wayland synchronně načítal neomezený MIME stream až do EOF už při hoveru myši. Odstraněním DropArea byl tento DoS vektor definitivně eliminován; vkládání referencí probíhá bezpečně přes tlačítko Vložit (`Super+V`/`Ctrl+V`) a Výřez (`SNIP`) s 16KiB/32MB stropy.
- **Zabezpečené runtime úložiště:** Dočasné buffery se ukládají do `$XDG_RUNTIME_DIR/qwenimage` s právy `0700` a soubory s `0600`.

### Fixes & Enhancements
- **Oprava funkce SNIP:** V `views/StudioView.qml` opraven překlep z neexistujícího `snipScreenArea()` na existující `triggerScreenSnip()` a v `Panel.qml` zaveden zpětný alias. Výřez nyní spolehlivě snímá oblast přes `slurp` + `grim`.
- **Dynamická verze v patičce:** Text verze v zápatí panelu navázán na dynamickou vlastnost `pluginVersion` namísto statického textu.
- **IPC VRAM Guard:** Atomický souborový zámek (`fs2::FileExt::try_lock_exclusive`) chránící GPU před souběžnými generovacími požadavky.
- **Turbo CFG Guard:** Omezení CFG na 1.0 a 6 kroků při aktivním Turbo DMD módu.

---

## [1.1.4] — 2026-10-09

### Independence & Self-Contained Runtime
- **Odstranění externích helperů:** Zcela eliminována závislost na skriptech v `~/.local/bin/qwen-image` a `prompt-opt`.
- **Nativní Prompt Optimizer:** Implementováno přímé HTTP volání lokální Ollamy s optimalizovaným system promptem přímo v Rust bridge (`cmd_optimize_prompt`).
- **Nativní ComfyUI Engine:** Přímé řízení ComfyUI grafu přes WebSocket streaming a TaeQI náhledy kroků.

---

## [1.1.3] — 2026-10-04

### Performance & Resource Optimization
- **Optimalizace VRAM:** Adaptivní polling pro CivitAI data a zamezení zbytečného držení textových modelů v paměti.
- **Nativní Settings Bridge:** Ukládání a načítání konfigurace studia přes Rust bridge do `settings.json`.

---

## [1.1.2] — 2026-10-04

### UI Stability
- **Oprava historie:** Stabilizace rozložení karet v HistoryView a ošetření DPI škálování.

---

## [1.1.1] — 2026-10-03

### Security
- **Základní hardening schránky:** Úvodní ošetření binárních MIME typů pro schránku.

---

## [1.1.0] — 2026-10-02

### Features
- **TAEQI Real-Time Previews:** Zobrazení živého průběhu difuze s nulovou VRAM režií.
- **Adaptivní rozlišení:** Automatická kalibrace rozlišení a kroků dle hardwarového profilu (Tier S, A, B).

---

## [1.0.0] — 2026-09-29

### Initial Release
- První produkční vydání nativního Generative AI Studia pro Omarchy Linux & Quickshell.
