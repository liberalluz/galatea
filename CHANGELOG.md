# Changelog

<!-- Released versions, newest first. The release tool owns this file. -->

## v0.2.0 - 2026-11-21

### Added
- New requirements `REQ-031`–`REQ-035` (two-tab navigation, the Me-tab four pages, the first-run hint, the shared quiz page, the handwriting overlay) with matching test cases `TC-NAV-001`, `TC-ME-001`, `TC-ME-002`, `TC-QUIZ-008` and `TC-TRACE-003`; the iOS confirmation (`REQ-025`) moves to a v0.2.x patch per the product ruling.
- The bottom bar shows exactly two tabs — 音标 / 我 (`REQ-031`); the practice tab is removed and quiz, review, settings and about become drill-downs (the practice entry returns with B27 as the chart's row-select flow).
- REQ-015 amended to the single-row ruling (2026-11-21): the chart's right-bottom floating button enters an in-page row-select state where exactly one row is selected at a time — default first row, tapping another row moves the selection — and confirm practices that row; the standalone range screen is abolished (Changed for the REQ-015 / TC-QUIZ-001 wording across the controlled set).
- The shared quiz page (`REQ-034`): one page hosts the quiz session for both the new-practice source (the selected row) and the review source (the due queue); only the item source differs.
- The handwriting overlay (`REQ-035`): the top-right pen control opens a free-tracing board covering the detail page — grey model, cross guides, clear-and-rewrite, done returns — with no route change and never a score or verdict.
- The Me tab grows into its four pages (REQ-032): the home is rebuilt as the mastery statistics card plus the review status strip (due count, hidden when none is due) and three drill-down entries to review, settings and about.
- The review drill-down (REQ-034) lists the due queue in due order with the fixed review-empty state and starts the shared quiz page over the review source; the chart status strip deep-links straight into it.
- Settings (SDD §3.8): the language switch applies zh-CN/en-US to all copy immediately through the new app-wide copy table, and the audio toggle keeps the pronunciation button and listening tasks visible with playback as a fixed-notice no-op when off.
- The About page (REQ-001) carries the version, the single source label with the ISBN slot reserved in the data structure (contingency public-tables labelling until licensed), the oss note, feedback and the device-only disclosure.

### Changed
- The controlled spec set (SRS/SDD/STD/STP) restates the v0.2.0 interaction revamp confirmed on 2026-11-21: two coarse chart groups, two-tab navigation, chart floating-button row-select practice entry, same-row detail circles, review entry in the Me tab, shared quiz page, non-scored handwriting overlay, on-device realtime audio synthesis without cache and the placeholder-delivery wording for mouth-shape and example images.
- The chart renders only the 元音 / 辅音 coarse group headers (`REQ-002`): the fine place-of-articulation labels are data-only, and the shared row model (`row_model.dart`) splits each coarse group into rows of 5 — 24 vowels in five rows ending at 4, 24 consonants in five rows ending at 4, 48 phonemes in total.
- The direct-read hint strip is permanently part of the chart scaffold, grey-on-grey, visible only while the toggle is on, and its tap switches to the Me tab (`REQ-005`, `REQ-022` landing).
- The chart carries no source footer (`REQ-001`, decision 7): the book title + ISBN attribution moves to the About page with B29.
- `REQ-020` batch label: the top-right label now shows the selected row's coarse group (元音 / 辅音) or 复习 for a review session, replacing the phoneme-count denominator text.
- The chart gains the practice floating button, the 请选择 select bar and the green whole-row highlight; the fine group title map is gone.
- The switcher becomes same-row member circles from the shared row model (`REQ-011`): five circles, the last row at its actual count, defaulting to the tapped phoneme; navigation never crosses rows and the ends of a row do not wrap (the chip strip and the catalog-order prev/next arrows are gone).
- The zone order follows wireframe P3 (`SDD §3.3`): mouth-shape slot beside the single writing grid, pronunciation button below, then the 2×2 example cards; the per-zone duplicate glyph display is dropped and the star row is reduced.
- The stroke order auto-plays once when a phoneme appears and tapping the writing grid replays it with pronunciation (decision 13); the separate play control is gone, the stroke-pending state is unchanged.
- The v0.2.0 flows complete end-to-end on the release Web build in a browser session (`TC-PLATFORM-001`): the chart flow with the notation switch re-rendering the grid, the detail flow with the same-row circles, the wireframe zone order and the handwriting overlay, the practice flow with the single-row select and the confirm feedback, and the review chain with the due strip, the queue page and the review-source hand-off.
- The four browser-level quality evidences were re-captured in the same session: IPA-only symbols render without tofu (`TC-QUAL-001`), a 360 px viewport keeps the 5-column grid intact with practice options above the 44 pt floor (`TC-QUAL-002`), data and texts keep working with the network disabled after first load and the audio behaviour stays a fixed non-blocking state (`TC-QUAL-003`), and semantic labels surface in the accessibility tree with Tab traversal and Enter activation operating the chart (`TC-QUAL-004`).
- The Pages site is redeployed to the v0.2.0 build (orphan `gh-pages` branch, `--base-href /galatea/`), pending the product owner's explicit go for the external push.

## v0.1.0 - 2026-11-21

### Added
- Flutter client scaffold (`app/`, web platform) with an empty shell page and the smoke test
- The detail writing zone hosts a tracing area over the handwritten glyph; pointer strokes render in ink over the faint model, are kept when input is interrupted, stay after finishing, and clear with the restart control (`REQ-008`, `TC-TRACE-001`).
- The stroke-order control plays the handwritten glyph stroke by stroke and can replay, ending on the complete glyph; phonemes without stroke data show the fixed preparing label with the control disabled, independent of the tracing area (`REQ-009`, `TC-TRACE-002`).
- New bundled, versioned glyph data file `assets/content/glyphs.v1.json` (48 phonemes × ordered simplified strokes as normalized polylines, ED draft) with the handwritten model fed to the tracing area and the stroke-order animation (`REQ-013`, `ADR-0003`).
- The practice tab's new-practice mode hosts the range selection screen: a category tag row (`all` plus the 11 category tags sharing the chart page's Chinese group titles) filters the phoneme set, and the 5-column grid multi-selects and deselects phonemes, with the selection kept across tag switches (`REQ-015`, `TC-QUIZ-001`).
- The confirm control is gated: it stays disabled with the fixed "请先选择音位" hint while nothing is selected, and shows the selection count once at least one phoneme is selected; the confirmed range is consumed by the quiz session shell in `B12`.
- A filter with no matching phonemes shows the fixed "该类别暂无音位" empty state with a clear-filter control (ux-flows empty branch).
- Confirming the practice range selection now enters the quiz session shell: the session view with the top bar and the task area replaces the range selection grid (`REQ-020`, `REQ-021`).
- The top bar shows the progress bar, the completion rate beside it (visible from 0% onward) and the range label top-right showing the selected phoneme count, matching the progress denominator (`TC-QUIZ-006`, `TC-QUIZ-007`).
- The progress advances per answered item and reaches 100% when every phoneme in the range has been answered at least once, regardless of verdicts (PRD 完成判定); feedback appears immediately after each answer.
- A zero denominator hides the progress bar and shows the fixed "范围暂不可用" hint instead of 0/0 (ux-flows failure branch).
- The item slot ships as a fixed-verdict placeholder task driving the session state machine; the four real task types replace it from `B13` on.
- The quiz session item slot now renders the recognition task (`REQ-016`, `TC-QUIZ-002`): the print-glyph stem with exactly 4 letter-spelling options, exactly 1 correct; selecting one and submitting shows the immediate verdict feedback through the session shell.
- The options come from the catalog's existing letter spellings: the phoneme's own spelling plus three deterministic distractors in catalog order (wrapping), so the same phoneme yields the same option set on every visit and the exactly-one-correct invariant holds by data (all 48 spellings are unique).
- The item slot is a task registry: this batch registers the recognition task only; the listening, writing and matching tasks register into the same registry from `B14` on without changing the shell.
- A phoneme with fewer than 4 distinct spellings renders the fixed "题目准备中" state with a skip control instead of an under-filled option row (ux-flows R16 failure branch); a skipped item advances without entering the completion rate.
- The quiz session item slot now renders the listening task (`REQ-017`, `TC-QUIZ-003`): the audio stem with exactly 2 symbol options, exactly 1 correct; the selected option highlights before confirm, and submitting shows the immediate verdict feedback through the session shell.
- The options come from the catalog's existing `kk` symbols: the phoneme's own symbol plus one deterministic distractor in catalog order (wrapping), so the same phoneme yields the same option pair on every visit and the exactly-one-correct invariant holds by data (all 48 symbols are unique).
- The stem drives the `B7` audio layer (ADR-0002): the session hands its audio service to the task, and the play control plays the current phoneme with the same call shape the detail page uses.
- Playback failure follows the ux-flows R17 ladder: the first failure offers replay, a repeated failure offers the fixed "题目准备中" state with a skip control; a skipped item advances without entering the completion rate.
- The task registry now carries the recognition and listening tasks; the writing and matching tasks register into the same registry from `B15` on without changing the shell.
- The quiz session item slot now renders the writing task (`REQ-018`, `TC-QUIZ-004`, ux-flows R18): the handwritten sample above and a blank tracing area below, the ✓/× verdict for a traced input, and the empty submit showing the trace-first hint without a verdict — an empty submit is never judged ×.
- The verdict is the recorded stroke-overlap threshold (the ED-stage leniency R18 allows): sampled user points within 0.09 of the model polylines must reach 0.7 coverage for ✓; the judgement is a pure function of (model strokes, user strokes) and deterministic.
- The tracing canvas and the handwriting painter moved to the shared `lib/ui/writing/` component: the detail handwriting zone delegates to it with unchanged behavior (`REQ-009`), so capture and rendering have one source.
- The task registry now carries the recognition, listening and writing tasks; the matching task registers into the same registry from `B16` on without changing the shell.
- The matching task (`TC-QUIZ-005`, `REQ-019`): three pronunciation play controls on the left and three DJ symbols on the right; pairing connects one pair at a time, matched pairs grey out inert and mispairs snap back without counting as completion.
- The deterministic pair-set builder: the current phoneme plus the next distinct-DJ catalog entries (wrapping), the right column in a fixed rotated order so no pair aligns by position; the bundled table's duplicate DJ glyphs are skipped to keep the right column unambiguous.
- The mastery engine (`TC-REVIEW-001`, `REQ-022`): the star ladder (start 0, +1 per correct answer capped at 3, −1 per wrong answer floored at 0) and the review queue (a wrong answer queues at interval 1, consecutive correct review answers advance the 1/2/4/7/15-day intervals, a wrong review answer resets to interval 1).
- The mastery store with the preferences-backed production store (`shared_preferences`, covering Web/mobile/desktop) and the in-memory test store; the state persists as one JSON document keyed by phoneme id, and stars carry no per-notation dimension (ADR-0001).
- The review mode in the practice tab: the new/review mode switch, the queue listing with today/N-days-later due labels, the due-today count, the start control over the due-today subset in ascending due order, and the fixed empty state when nothing is due.
- A store write failure keeps the in-memory star change and shows the fixed notice that the review queue is not yet updated.
- The Me tab statistics (`TC-REVIEW-002`, `REQ-023`): the mastered 3★ / learning 1–2★ / unmastered 0★ summary rows over the catalog denominator 48, the total line, and the fixed empty notice shown before the first practice.
- The KK/DJ/IPA display filter chips — switching the notation changes nothing by design; the shared stars make the counts identical under every filter.
- The detail page star rating row: the phoneme's 0–3 stars with the mastery label; a degraded mastery state shows the fixed data-sync marker with 0 stars, never inventing stars.
- The offline behaviour tests: the zero-network scan (no network package in the dependency set, no network client import in `app/lib`) and two failure-path pins — the pronunciation button shows the fixed retry state from the first frame with the other detail sections unaffected, and the listening stem's ladder (replay, then skip) keeps the session advancing offline.
- Bundled phoneme catalog dataset (`assets/content/phoneme_catalog.v1.json`, 48 entries: 24 vowels + 24 consonants) with category groups, KK print glyphs and the booklet source label
- Content-layer loader `lib/content/phoneme_catalog.dart` with tests pinning the 48-entry contract
- The bundled font fallback chain (`TC-QUAL-001`, `REQ-027`): Noto Sans Regular (OFL licence shipped alongside) registered in pubspec and applied as the head of the theme's fontFamilyFallback chain, so the IPA symbols ʃ θ ŋ ɚ render from the bundled file on Web and iOS instead of gambling on system fonts; the chain falls back to system defaults and never blocks the first frame.
- Accessibility labels on the phonetic symbol texts (chart cells, detail sections, task stems, matching pair labels) with the phoneme id fallback, per TC-QUAL-004 / REQ-030.
- `infra/tool/check/check_doc_ids.py` — the bilingual delivery audit is a repeatable command: every controlled document in `docs/specs/controlled/` is paired with its `.zh-CN.md` translation and the id sets (`REQ-NNN`, `TC-NNN`, `ADR-NNNN`) are compared per pair; a differing set, a missing translation or a translation without a source exits non-zero. The checker is verified in both directions — a seeded mismatch fixture fails, the real tree passes (`TC-DOC-001`, `REQ-026`).
- The controlled-set declaration in `docs/README.md` now lists the four existing controlled documents; SCMP is ruled out of the v0.1.0 controlled set (no frozen baseline, `governance: small` — ruling 2026-11-21).
- The browser end-to-end confirmation (`TC-PLATFORM-001`, `REQ-024`): the Flutter Web release build completes the chart, detail, practice and review flows in a real browser session, with the four browser-level quality evidences captured in the same session — IPA-only symbols render without tofu (`TC-QUAL-001`), a 350 px viewport scrolls the grid horizontally with no column wrap and no clipping (`TC-QUAL-002`), the SPA keeps the chart, correspondence data and texts working with the network disabled after first load (`TC-QUAL-003`), and the accessibility tree exposes every visible chart cell with its spoken label plus the notation buttons, tabs and the reading-mode switch (`TC-QUAL-004`).
- Bundled KK/DJ/IPA correspondence table (`assets/content/correspondence.v1.json`, 48 mappings keyed by the catalog phoneme ids) compiled from public correspondence tables with a labelled source
- Content-layer loader `lib/content/correspondence.dart` with tests pinning the external-data contract: editing the data file changes the loaded mapping without a code change
- App shell with three fixed tabs (chart / practice / me), chart as the default (`S3`, wireframe P0); practice and me are placeholders for later batches
- Chart page: 5-column print-glyph grid grouped by phonetic category (11 groups, no row crossing a group boundary, last row left-aligned), 48 phonemes each once (`REQ-002`, wireframe P1)
- Default-state navigation: tapping a symbol opens the detail placeholder route for that phoneme (`REQ-004`)
- Labelled data source line on the chart page (booklet ISBN), per `REQ-012` visibility
- Notation switch (KK / DJ / IPA) at the top of the chart page, KK as the default on first launch (`REQ-003`, `TC-CHART-003`, wireframe P1)
- Switching to DJ or IPA re-renders the grid symbols from the bundled correspondence data (B3) while the phoneme identities stay the same
- Selected-phoneme state on the chart grid: the highlighted phoneme survives notation switches and route round-trips
- Domain glyph resolver with the SDD §3.2 missing-glyph fallback: a phoneme missing in the target notation keeps the previous notation's glyph (unit-tested)
- Detail shell hosting the zone skeleton in the fixed section order: switcher → 发音区 → 口型区 → 书写区 → 例词例句 (wireframe P3, SDD layout)
- Horizontal phoneme switcher at the top of the detail page: a strip of phoneme chips with the current chip highlighted plus prev/next arrows (`REQ-011`, wireframe P3)
- prev/next move to the adjacent phoneme in catalog order and refresh every section; the ends are disabled and do not wrap (`TC-DETAIL-004`)
- Chart grid navigation passes the full catalog to the detail route so the switcher can walk the catalog order
- Pronunciation button in the detail audio zone: play goes through the ADR-0002 audio service interface; the browser synthesizes the phoneme audio via Web Speech (`REQ-006`)
- The button exposes the four fixed states loading / ready / playing / failed (`TC-DETAIL-001`); on failure it shows the fixed `audio-failed` copy and tapping it retries playback
- Audio failure stays inside the audio zone; the other detail sections and the switcher keep working
- Speakable text per phoneme in the catalog (`tts` field, 48 entries): English approximations so the TTS engines can read what the phonetic glyphs cannot express
- Switching phonemes stops playback and resets the button to the ready state
- The chart reading mode: a top-right switch on the chart tab; on, the fixed hint line shows above the grid, tapping a phoneme plays its audio through the audio service and stays on the chart (a failed playback shows the short failure notice with a retry action and never navigates), and off, taps open the detail page as before.
- The detail page mouth zone shows a mouth-shape slot per phoneme; while the licensed artwork is missing it renders the fixed `口型图准备中` placeholder at the same size, never a blank area (`REQ-007`).
- The detail page words zone shows 4 example cards in a 2×2 grid, each with an image slot and a word/sentence and no translation text (`REQ-010`).
- A card whose image is missing keeps the word/sentence visible and renders the fixed same-size image placeholder; cards are never hidden (`REQ-014`).
- New bundled, versioned examples data file `assets/content/examples.v1.json` (48 phonemes × 4 word/sentence pairs, ED draft) with optional asset paths; missing or unloadable paths fall back to the placeholders.

### Changed
- The session reports every verdict to the engine regardless of the practice mode.
- The shell owns one mastery controller and hands the same instance to the practice tab, the Me tab and the detail page; the preferences load with the timeout fallback moved from the practice tab to the shell.
- The audio layer documents the offline ruling (`REQ-029`): the Web Speech provider synthesizes on-device with no network dependency; the ADR-0002 cache seam stays behind the interface for a future provider — no cache implementation ships.
- The chart grid keeps 5 columns with a per-cell minimum width and scrolls horizontally on viewports of 360 px or narrower instead of clipping or folding — no column is dropped and all 48 phonemes stay reachable (`TC-QUAL-002`, `REQ-028`).
- The practice options' 48 px minimum height stays above the 44 pt tap-target floor (`TC-QUAL-002`).
- None.

### Fixed
- None.
- `batch.py pr <id> --prepare` no longer self-rejects its own body: the project render hook now emits the fixed three-line Self-check shape (the `- Batch: <id>` line first, then the commit-trailer line and the no-secret line), so the prepared body names the batch and passes the body validator without hand-editing.
- The scope qualifier on the batch line comes from the batch-local pr-notes `## self-check` slot; without the slot the line falls back to the bare `- Batch: <id>`, which still names the batch.
