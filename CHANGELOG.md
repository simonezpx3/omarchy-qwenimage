# Changelog — QIS (Qwen Image Studio)

Všechny významné změny, audity a bezpečnostní opravy projektu jsou zaznamenávány v tomto souboru. Formát vychází z [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) a dodržuje [Semantic Versioning](https://semver.org/).

---

## [1.2.0] — 2026-10-14

### Added & Enhanced
- **Pillar 1 // Zero-Copy Preview Pipeline via POSIX Shared Memory (`/dev/shm`):**
  - Směrování ukládání živých náhledů do vyhrazeného RAM disku `/dev/shm/qis_preview_${UID}/` (0700). Zápis probíhá atomickým přejmenováním (`tmp` -> `target`), což eliminuje jakékoliv zpoždění z diskového I/O.
  - V `views/StudioView.qml` přepnuta komponenta `Image` na `asynchronous: true` s parametrem `?t=${livePreviewTick}` pro plynulé načítání náhledů na 144Hz Wayland kompozitoru bez mikrozáseků UI.
- **Pillar 2 // Process Lifecycle Hardening & Zombie Prevention (`PR_SET_PDEATHSIG`):**
  - V `rust-bridge/src/comfy.rs` implementována nízkoúrovňová pojistka přes `libc::prctl(PR_SET_PDEATHSIG, SIGKILL)` s detekcí fork-race stavu (`getppid() != parent_pid`). Při nečekaném pádu či ukončení bridge jádro okamžitě ukončí child proces ComfyUI a uvolní VRAM.
  - V `scripts/qis-stack.sh` doplněna procesní izolace přes transient cgroup `systemd-run --user --scope --unit=qis-comfyui-${UID}` a její čisté zastavení při `qis stop`.
- **Pillar 3 // Attention Acceleration with SageAttention 2 (`sm_86` Ampere INT8):**
  - Integrována automatická detekce a aktivace `--use-sage-attention` pro ComfyUI na kartách architektury Ampere. Využívá hardwarové INT8 Tensor Cores pro pozornostní matice s FP16 akumulací bez změny GGUF Q4_K_M vah modelu, čímž přináší 25–35% zrychlení a redukuje špičkovou spotřebu paměti.
  - Do instalačního skriptu doplněna instalace `sageattention` do virtuálního prostředí.
- **Pillar 4 // Memory Allocation Safeguards & Hardware Stability:**
  - Odstraněn nestabilní přepínač `--async-offload 1`, který byl identifikován jako příčina proudových transientů a pádů PCIe sběrnice (Xid 79) při zátěžovém upscalingu.
  - Zavedena globální alokační konfigurace `PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,garbage_collection_threshold:0.8"` eliminující fragmentaci VRAM na 8GB GPU.
  - CPU runtime optimalizace pro Ryzen 7800X3D: `OMP_NUM_THREADS=8` zamezující SMT thrashingu na 1 CCD při AVX-512 operacích a `CUDA_MODULE_LOADING=LAZY`.

---

## [1.1.9] — 2026-10-13
 
### Added & Enhanced
- **Neural Super-Resolution Engine (4X AI Upscalers in ComfyUI):**
  - Integrována trojice špičkových modelů pro super-rozlišení (`RealESRGAN_x4plus`, `4x-UltraSharp`, `4x-AnimeSharp`) s ověřenými SHA-256 hashy a commit pinningem.
  - V UI přidána nová lišta pro volbu upscaleru (`4X ESRGAN`, `4X ULTRA`, `4X ANIME`, `0.5X`, `FIT 1K`) včetně zachování nativních parametrů SIMD škálování.
- **Pillar 1 // UI Texture RAM & VRAM Optimization (`views/StudioView.qml`):**
  - Implementováno adaptivní omezování `sourceSize: Qt.size(Math.min(Math.max(width * dpr, 1280), 2560), 0)` pro hlavní i živý náhled a `sourceSize: Qt.size(512, 0)` pro referenční náhled. Nastavení výšky na `0` v QtQuick zaručuje přesné zachování poměru stran bez deformace a snižuje paměťovou zátěž z ~92 MB na ~4 MB při načítání 6K snímků.
- **Pillar 2 // Rust Release Profile Hardening (`rust-bridge/Cargo.toml`):**
  - Zaveden produkční release profil (`opt-level = 3`, `lto = "thin"`, `codegen-units = 1`, `panic = "unwind"`, `strip = "debuginfo"`). Binárka dosahuje minimální velikosti, zrychlené exekuce a zároveň zabraňuje neočekávaným pádům procesu při chybách WebSocket rámců.
- **Pillar 3 // Tmpfs Garbage Collection & Circular Log Rotation (`rust-bridge`, `scripts/qis-stack.sh`):**
  - Do `rust-bridge` doplněn automatický úklid dočasných souborů v `$XDG_RUNTIME_DIR/qwenimage/` starších než 24 hodin (1440 min).
  - V `scripts/qis-stack.sh` zavedena rotace logu `comfyui.log` při překročení 10 MB se zachováním posledních 10 000 řádků.
- **Pillar 4 // Pre-Release CI Parity & Security Hardening:**
  - 100% úspěšnost v lokální CI paritě (`cargo clippy -- -D warnings`, `cargo test` 16/16, `shellcheck`, `omarchy plugin validate .`).

### Fixed & Enhanced
- **Live Preview Engine (`rust-bridge`, `qis-stack.sh` & `StudioView.qml`):**
  - **ComfyUI Preview Pipeline:** Do konfigurace spuštění ComfyUI (`qis-stack.sh`, `~/.local/bin/comfy` i `rust-bridge`) sjednocen přepínač `--preview-method auto`. Backend tím na RTX 3070 automaticky aktivuje bleskový `Latent2RGB` vzorkovač s režií <50 MB VRAM a odesílá binární JPEG snímky přes WebSocket.
  - **Ping-Pong Buffer & Magic Bytes Parser:** V `rust-bridge/src/comfy.rs` implementována robustní detekce začátku JPEG streamu (`[0xFF, 0xD8]`) i PNG (`[0x89, 0x50, 0x4E, 0x47]`) eliminující závislost na offsetu hlavičky. Náhledy se atomicky zapisují do střídavého ping-pong bufferu (`qis_live_preview_0.jpg` <-> `qis_live_preview_1.jpg`) v `$XDG_RUNTIME_DIR/qwenimage/` (0700).
  - **Přirozená QtQuick Invalidace:** V `StudioView.qml` je vlastnost `source` navázána přímo na střídající se cestu. Díky změně URL na každém kroku difúze QtQuick okamžitě a spolehlivě obnovuje texturu bez uvíznutí v mezipaměti a bez nutnosti hacků s `?v=`.
- **Image-to-Image Aspect Ratio Overdrive (`assets/qwen_edit_workflow_api.json`):**
  - **Sjednocení rozměrů kondicionování:** Uzel 4 (`TextEncodeQwenImageEditPlus`) přepojen na vstup `image1` z uzlu 5 (`ImageScale` s center crop) namísto syrového uzlu 9.
  - Tím je zaručeno, že `reference_latents` přesně lícují s rozměry a poměrem stran cílového latentu z uzlu 5b a nevznikají geometrické deformace ani nechtěný návrat k původnímu poměru předlohy.
- **Tiled VAE Decoder Stabilizace (`rust-bridge/src/comfy.rs`):**
  - Doplněna povinná pole `temporal_size: 64` a `temporal_overlap: 8` do uzlu `VAEDecodeTiled`, čímž byla odstraněna chyba validace parametrů v ComfyUI při dekódování velkých pláten s úsporou VRAM.
- **UI Ergonomie & Text Labels (`Panel.qml` & `views/StudioView.qml`):**
  - Odstraněn přetékající statický text `CTRL+ENTER RUN` z prompt karty, který kolidoval a překrýval tlačítko `OPTIMISE`.
  - Tlačítko automatického rozšiřování promptu upraveno na přehledný štítek `Expand: ON` / `Expand: OFF`.
- **Refaktor Anatomical Guardu (`rust-bridge`, `Panel.qml` & `views/StudioView.qml`):**
  - **Čistá negativní ochrana:** Anatomical guard byl zjednodušen výhradně na automatické doplnění negativního promptu s anatomickou ochranou (`bad anatomy`, `extra limbs`, `extra fingers`, `fused fingers`, `deformed hands...`).
  - **Odstranění restriktivních overridů:** Zrušeno veškeré nucené přenastavování uživatelských parametrů — žádné vnucování kroků (28 st), CFG (4.0), rozlišení (přepisování Draft na Standard) ani vynucený pád Turba do Standardu.
  - **Žlutá vizuální varování (#screens standard):** U problematických kombinací parametrů při detekci lidského subjektu (nízký počet kroků bez Turba, nízké rozlišení Draft) se v UI zobrazuje čisté informační varování ve žluté barvě (`#f59e0b`), bez blokování či přepisování voleb uživatele.
- **XDG Persistence & Eliminace Nechtěného Hot-Reloadu (`rust-bridge/src/main.rs`):**
  - Ukládání uživatelských nastavení (`settings.json`) bylo přesunuto ze složky pluginu do standardní XDG cesty `~/.config/qwenimage/settings.json` (0600) s automatickou bezešvou migrací a vyčištěním starého souboru.
  - Tím bylo zcela eliminováno nežádoucí zachytávání změn systémovým `inotifywait` hlídačem v Omarchy shellu a plugin se již nerestartuje při přepínání voleb (Turbo, Expand, Anime LoRA apod.).

---

## [1.1.8] — 2026-10-12

### Added & Enhanced
- **Abliterated & Uncensored Vision & Prompt Optimizer (`heretic-v`):**
  - Prioritizace abliterovaného modelu `heretic-v:latest` (`maternion/mimo-v2.6-heretic:9b`) pro vizuální analýzu referenčních obrázků (`cmd_vision`) i optimalizaci promptů (`cmd_optimize_prompt`).
  - Odstranění korporátní RLHF cenzury a odmítání uměleckého či dospělého obsahu při lokálním generování.
- **Ořezávání myšlenkových bloků (`<think>` Stripping):**
  - Implementováno automatické odstraňování interních uvažovacích značek `<think>...</think>` z výstupů reasoning modelů před předáním textu do editoru studia.
- **Inteligentní Refusal Guard & Fallback:**
  - Detekce a neutralizace moralizujících odmítacích hlášek externích nebo cenzurovaných modelů (*"I can't...", "violates safety policy"*).
  - V případě odmítnutí optimalizátorem je aktivován bezpečný fallback: původní zadání uživatele se nepřepíše chybovou zprávou, ale je v plném rozsahu zachováno pro odeslání do difuzního enginu.
- **Konceptuální soulad & Podpora nízké VRAM (Tier B / 4 GB hardware):**
  - **Svrchovaný Local-first princip:** 100% soulad s filozofií studia — žádné poučování ani umělá cloudová cenzura na vlastním hardwaru.
  - **Nenásilná detekce (`/api/tags`):** Modely nejsou vynucovány natvrdo; systém se adaptivně přizpůsobuje modelům, které má uživatel reálně nainstalované. Uživatelé bez `heretic-v` hladce propadávají na standardní modely.
- **Anatomical Router & Stabilizace tělesných proporcí (Slim / Curvy Guard):**
  - **Kalibrace vah adaptérů v ComfyUI grafu (`comfy.rs`):** Síla Uncensored LoRA snížena z přestřelených `0.85` na optimálních `0.50` (a `0.45` v Turbu). Tím je zachována 100% necenzurovaná anatomie bez deformace pasu a vnitřního biasu Civitai datasetu do nadváhy. Anime LoRA zastropována na `0.65`.
  - **Detekce konstituce postavy (`detect_slim_subject` & `detect_curvy_subject`):** Rozšířen analyzátor promptů v Rust bridge o rozpoznávání štíhlosti (`slim`, `petite`, `slender`, `skinny`, `lean`, `štíhlá`, `hubená`, `drobná`, `úzký pas`) a plnoštíhlých požadavků (`curvy`, `chubby`, `plus size`, `boubelatá`).
  - **Zachování uživatelské volby:** Vzorkovací podlaha 28 kroků a CFG 4.0 se vynucuje výhradně při automatickém přechodu z Turba (`anatomical_fallback`); ruční volba kroků i CFG ve Standard režimu zůstává plně respektována.
  - **Eliminace skrytého body-type biasu:** Negativní filtry pasu se aplikují cíleně pro výslovně štíhlé linie (`is_slim`), nikoli paušálně pro všechny lidské postavy.
  - **Inteligentní optimalizace negativního promptu (Optimizer Negative Engine):**
    - Prompt Optimizer (`cmd_optimize_prompt`) v jednom průchodu analyzuje scénu a vedle pozitivního promptu generuje i **vycizelovaný negativní prompt šitý na míru**.
    - Automaticky filtruje zastaralé tagy jiných architektur (`score_1, score_2...`), odstraňuje zdvojené čárky a překlepy a přidává ochranu specifickou pro žánr (ochrana před fotorealismem u anime, ochrana před kresbou/CGI u fotek, plná anatomická ochrana končetin a pasu).
    - Výsledek se okamžitě propisuje do pole negativního promptu v UI.
  - **Ergonomie UI řádky Seed, Steps a nápověda pro Turbo:**
    - Odstraněn redundantní text `SEED // ZAMČENÝ` – tlačítko zobrazuje čistý instrumentální stav `AUTO` vs čisté číslo seedu (`1083174851`), stav uzamčení je vysvětlen v dolní liště nápovědy.
    - Zkrácena šířka Seedu (110 px) a předvoleb Kroků (28 px), čímž bylo 100% eliminováno přetékání řádky mimo 460px panel.
    - Rozšířena dynamická nápověda pro tlačítko Turbo s detailním popisem chování Anatomical Guardu (přepínání na Euler 28 st pro vrstvenou LoRA/slim, 7 st solo člověk, 6 st krajiny).
- **Multi-Hardware Portabilita & Systémové zpevnění (Arci Council Audit B1, B2, B3, B4):**
  - **B1 // ComfyUI Launcher & Multi-stage Cold Start:** `ensure_comfyui_running()` v `rust-bridge` rozšířen o vícestupňový start (zkouší launchery `comfy` a `qis` v `~/.local/bin` nebo v PATH a při jejich absenci na čisté instalaci přímo nastartuje Python runtime z `${COMFY_DIR}/venv/bin/python main.py`). Do `qis-stack.sh` a `install.sh` přidány CLI příkazy `start [--bg]` a `stop`. Limit pro studený start prodloužen na 45 sekund pro spolehlivý náběh na libovolném úložišti.
  - **B2 // Dynamická substituce DiT modelu v RAM:** Implementována funkce `resolve_dit_model_name()` v `comfy.rs`, která dynamicky detekuje přítomnost modelů v `models/diffusion_models/` (`Q4_K_M` vs `Q3_K_M` vs `FP8/BF16`) nebo proměnné `QIS_DIT_MODEL`. V grafech (T2I i I2I) se uzel `"1"` (`UnetLoaderGGUF`) upravuje v paměti před odesláním, čímž je zaručen bezchybný běh na Tier B (6 GB VRAM) sestavách bez chybějícího souboru.
  - **B3 // Bezpečné XDG runtime cesty & eliminace hardcoded UID:** Odstraněna napevno zadrátovaná cesta `/run/user/1000` z `comfy.rs` i `Panel.qml`. Živý náhled nyní striktně využívá POSIX standard `$XDG_RUNTIME_DIR/qwenimage/` s fallbackem na privátní `$HOME/.cache/qwenimage/` s explicitními právy `0700` (ochrana před únikem dat na multi-user systémech).
  - **B4 // Multi-GPU & Sysfs DRM profilace hardwaru:** `install.sh` i `qis-stack.sh` v `detect_hardware()` procházejí všechny GPU a vybírají kartu s nejvyšší VRAM; pro AMD a Linux DRM čtou reálnou kapacitu paměti ze sysfs (`/sys/class/drm/card*/device/mem_info_vram_total`). Pro CPU / iGPU (Tier C) instalátor zobrazuje jasné varování o očekávané latenci (~30-60s/krok) a doporučuje remote LAN node.
- **Okamžité přerušení generování & Reset (`/interrupt` & `isCancelling`):**
  - **ComfyUI REST Interrupt:** V `comfy.rs` implementována funkce `interrupt_comfyui()`, volající standardní endpoint `POST http://127.0.0.1:8188/interrupt` (timeout 1.2s), a uvolnění paměti GPU přes `/free`.
  - **CLI příkaz `interrupt` / `cancel`:** Rust bridge vystavuje příkaz pro okamžité ukončení difuzního výpočtu a uvolnění VRAM.
  - **Dynamické tlačítko PŘERUŠIT:** Během generování se tlačítko GENERATE v `StudioView.qml` změní na aktivní tlačítko `PŘERUŠIT // Xs` (v barvě `Color.urgent`), které okamžitě zastaví výpočet i lokální proces.
  - **Stavový zámek `isCancelling`:** V `Panel.qml` zaveden zámek proti race conditions a klikacímu spamu; zabraňuje vícenásobnému volání přerušení a atomicky se resetuje až v `onExited` procesů.
  - **Okamžité přerušení tlačítkem RESET:** Funkce `resetForm()` automaticky volá `cancelGeneration()`, pokud zrovna běží generování.
- **Oprava poměrů stran v Image-to-Image (Aspect Ratio Override):**
  - V `calculate_dimensions()` opraveno přebírání nativních rozměrů předlohy: aplikuje se výhradně při explicitní volbě `ratio == "auto"`.
  - Při volbě konkrétního formátu (např. `3:4`, `16:9`, `1:1`, `4:3`) generátor vynutí zvolený poměr stran a uzel `ImageScale` ořízne předlohu přes `crop: center`.
- **Zapouzdření posuvníku kroků (Steps Slider Layout Container):**
  - V `StudioView.qml` zapouzdřen `PanelSlider` do striktního `Item` s `Layout.fillWidth: true`, `Layout.minimumWidth: Style.space(80)`, pevnou výškou a `clip: true`, čímž bylo trvale odstraněno přetékání jezdce při animaci vysunutí/zasunutí panelu.
- **Zarovnání do Marci Aesthetic & Omarchy Plugin Standardu:**
  - Odstranění všech hranatých a kulatých závorek z akčních tlačítek a stavových indikátorů: přechod na čistou instrumentální typografii s oddělovačem `//` (`PŘERUŠIT // Xs`, `QIS // READY`, `QIS // BUSY`, `QIS // LOCKED`, `QIS // OFFLINE`).
  - 100% soulad s Omarchy plugin schématem ověřen přes `omarchy plugin validate .` (0 chyb).
- **P0 Verifikační opravy pro v1.1.8 (Arci Council Supreme Arbitráž):**
  - **F1 // Robustní try_wait launcher kontrola:** `ensure_comfyui_running()` ověřuje stav launcheru přes `try_wait()` v 1.5s okně. Pokud proces launcheru havaruje nebo skončí chybou (např. nekompatibilní cizí nástroj `comfy` v PATH), okamžitě přechází na Stage 2 (přímý Python runtime venv ComfyUI) bez 45s marného čekání.
  - **F4 + F5 // Čtení env.conf a Tier-aware model selection:** Rust bridge načítá konfigurační soubor `~/.config/omarchy/plugins/simonez.qwenimage/env.conf`. Funkce `resolve_dit_model_name()` respektuje detekovaný hardwarový tier (`QIS_VRAM_TIER`): pro Tier B (6 GB) a Tier C prioritizuje `qwen_image_2.1_Q3_K_M.gguf` pro ochranu před OOM, pro Tier A/S prioritizuje `Q4_K_M`.
  - **F6 // GGUF validace loaderu:** Z kandidátů `UnetLoaderGGUF` byly striktně vyřazeny nekompatibilní safetensors soubory; povoleny jsou výhradně `.gguf` váhy.

---

## [1.1.7] — 2026-10-11

### Documentation & Platform Alignment
- **Aktualizace identity na Local-first, Turbo a ComfyUI:**
  - V `manifest.json`, repozitáři na GitHubu i v `README.md` nastavena přesná inženýrská definice studia: `Local-first generative AI studio (Text-to-Image, Image-to-Image, Turbo diffusion, WD14 Danbooru interrogator, Qwen3-VL vision reverse-engineering, Civitai explorer, SIMD Lanczos resizer, ComfyUI backend)`.
  - Zkrácený widget popis v liště upraven na: `Local-first generative AI studio (Turbo, Text2Img, Img2Img, WD14, Civitai, ComfyUI)`.
  - Doplněna nová témata na GitHubu (`local-first`, `turbo`, `civitai`, `qwen-vl`, `wd14-tagger`, `simd-acceleration`).
- **Kompletace sekce Features a klávesových zkratek v README.md:**
  - Zdokumentován *SIMD Lanczos Resizer* (hardwarově akcelerované převzorkování AVX2/NEON v Rust bridge).
  - Zdokumentován *Screen Area Snip Tool* (přímý výřez plochy přes `grim` + `slurp` bez znečištění schránky).
  - Zdokumentován *A/B Compare Interactive Splitter* (interaktivní porovnávací posuvník v `views/CompareView.qml`).
  - Zdokumentován *Hardened Wayland Sandbox* (16 KiB limit, 1,2s deadline, SIGKILL a `FocusScope` izolace schránky).
  - Rozšířena tabulka zkratek o `Super + V`, `SNIP` a `COMPARE`.

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
