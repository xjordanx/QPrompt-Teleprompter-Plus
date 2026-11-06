# Intelliprompter (QPrompt fork): project brief for Claude Code

> **Status (2026-11-06):** Decision made: **fork QPrompt** (C++/QML, Qt 6 + KDE Kirigami, GPL-3) and add a live **talking-point checklist** to it. This folder is a git checkout of upstream QPrompt with our work on branch `intelliprompter`. The user's fork is `origin` = https://github.com/xjordanx/QPrompt-Teleprompter-Plus (branch `intelliprompter` pushed). Qt 6.12.0 is installed and **stock QPrompt builds and runs** via `scripts/build.ps1` (Step 1 done on our side; the user still needs to confirm it on the 7" monitor). **Next step: §10 Step 2, parser + checklist display.** The user is using stock QPrompt for recording in the meantime. Gamepad support is deferred; SDL3 is prepared but off (§7).

A Windows teleprompter for recording the **VNA-TDR Video Series**:

1. **Scripted text** scrolls exactly as in QPrompt: manual velocity control (keyboard, mouse wheel, global hotkeys, clickers/macro pads). No voice-paced scrolling.
2. **Checklist blocks** (delimited in the script markdown) appear inline in the scroll as checkable items. While a block is on the reading line, the app listens to a dedicated mic, transcribes live (ElevenLabs), and ticks each item when TypeSafe **Jev** scores it as covered.

The coverage design comes from the TypeSafe cookbook "Intelliprompter" (https://docs.typesafe.ai/cookbooks/intelliprompter). Read it before working on the coverage engine.

---

## 1. Repo, branches and upstream

- `upstream` = https://github.com/Cuperino/QPrompt-Teleprompter (default branch `main`). `origin` = the user's fork https://github.com/xjordanx/QPrompt-Teleprompter-Plus (remote URL includes `xjordanx@` so Git Credential Manager finds the stored token; the fork has only `main`, which is fine).
- Local `main` mirrors `upstream/main`, so never commit to it. All our work goes on `intelliprompter`, and we merge `upstream/main` into it periodically.
- **Keep the merge surface small.** Our code lives in `src/intelliprompter/` and `tests/intelliprompter/`. Edits to upstream files are minimal hooks, each marked with a `// INTELLIPROMPTER:` (or `// INTELLIPROMPTER:` in QML) comment so merges are easy to review.
- QPrompt's bundled deps are git submodules in `3rdparty/` (Kirigami, KCoreAddons, KGlobalAccel, KCrash, ECM, breeze-icons, QHotkey, hunspell). Run `git submodule update --init` after cloning.
- **License:** GPL-3. Our files carry the GPL-3 header. If a build is shared, its source must be offered. Do **not** open PRs to upstream without asking the user (upstream requires a CLA).
- Q: is a filesystem without ownership info, so `safe.directory` is set globally for `Q:/vibe/Intelliprompter`, and the repo uses `http.sslBackend=schannel`.
- Large binary fixtures (`fixtures/audio/*.wav`) are git-ignored. Tests that need them skip if they're missing.

## 2. What the cookbook provides (and what we build)

| Cookbook provides | We build |
|---|---|
| Coverage loop: cumulative transcript → one `Score` question per *unchecked* criterion → `system_one` | Live mic capture + ElevenLabs streaming STT (cookbook skips this) |
| 5-level rubric `"Not mentioned at all"` … `"Covered well and with useful detail"` → 1–5, covered at `COVERED_AT = 2.5` | Markdown delimiter parser, inline checklist rendering in QPrompt's document |
| One-way state: checked stays checked | Throttling/cost control, credentials, packaging |
| Poll every 0.5 s, call Jev only when transcript changed | Activation tied to scroll position (only listen while a block is active) |

The cookbook is Python. There is **no C++ SDK**, so call the REST API directly with `QNetworkAccessManager`: `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer <key>`. The OpenAPI spec is at https://api.typesafe.ai/openapi.json. **Check request/response shapes against the spec and the JS SDK docs (https://docs.typesafe.ai/sdk/javascript/api) before coding; do not rely on memory.** Score results run 0..(n-1); use `score + 1` to compare with the 1–5 threshold.

## 3. Requirements (source of truth)

- **R1 Display.** Provided by QPrompt: fullscreen on a chosen screen, mirroring, reading region, themes. Verify it all works on the target **7" 1024×800 monitor under beam-splitter glass** (hardware mirror, so software mirror stays off). Don't rebuild what QPrompt already does.
- **R1b Dedicated prompter mic.** The Windows default input is used for recording. The app picks its **own** input device (`QMediaDevices::audioInputs()`), persists device id + description, falls back gracefully if missing, shows a level meter in settings and a small mic/listening indicator in the prompter.
- **R1c Manual control.** QPrompt's velocity scrolling, keyboard, wheel and global hotkeys are unchanged. New bindable actions: *mark current item covered*, *un-mark*, *skip block*. **Gamepad: deferred** (prep only, §7). SpaceExplorer works via 3DxWare keystroke mapping.
- **R2 Checklist blocks.** Delimited sections (§4) render inline as hierarchical checklists. **Leaf items are the checkable/scored units.** A parent item ticks automatically once all its children are ticked. Ticks are one-way during a session (manual un-mark allowed).
- **R3 Activation and listening.** A block becomes *active* when its first line reaches the reading region and stays active until its end passes the reading line (or the user skips). STT + Jev run only while a block is active (plus a short pre-roll). Optional `holdAtBlockEnd`: stop scrolling at the end of the block until all leaves are covered or the user pushes on.
- **R4 Markdown input.** Open `Episode N - Script.md` from `E:\GDRIVE\Vibe Project LLM Chats\VNA-TDR-Video-Series\Episode N\` (Episodes 1–15, read-only). QPrompt already opens `.md` (via Qt's markdown importer). We pre-process the file first so the delimiters and checklist structure survive.
- **R5 Portable Windows build.** `windeployqt` folder zipped as `Intelliprompter-<ver>-win64.zip`. No installer, no admin rights. Our settings in `intelliprompter.json` beside the exe.
- **R6 Per-user credentials.** Each user supplies their own TypeSafe and ElevenLabs keys. They're never bundled, never in config, never logged, and never exposed to QML. See §6.
- **R7 Theme.** Checklist colors (pending, covered, parent-rollup, verify chip) are configurable and default to readable-on-black.

## 4. Script markup: checklist delimiters

The user's scripts are markdown. Checklist blocks are wrapped in HTML comments, which are invisible in Obsidian, GitHub and QPrompt:

```markdown
<!-- checklist: Segment A — What TDR actually measures -->
- **Reflections reveal impedance.** A fast step goes out; impedance changes send part of it back.
  - Tie it to the 50 Ω reference
  - Say: "Every bump on this trace is the cable telling you something."
- **Rise time sets resolution.**
  - `[VERIFY rise time on the DNA6264]`
<!-- /checklist -->
```

Rules:

| Markup | Meaning |
|---|---|
| `<!-- checklist: Title -->` … `<!-- /checklist -->` | One checklist block. Title is optional. Unclosed block → ends at the next `#`/`##` heading, with a parse warning. Nested blocks are an error (warn, treat as flat). |
| `- ` bullets at any depth | Items. **Leaves are scored.** Parents are roll-ups. |
| `**Bold lead.**` at the start of an item | Short display label. The rest is the description. |
| Jev criterion for a leaf | Leaf text, with its ancestors' labels as context (e.g. "Reflections reveal impedance › Tie it to the 50 Ω reference"). |
| `Say: "…"` / `Say on camera: "…"` | Must-say quote, shown in scripted-text style. It's still a leaf and still scored. |
| `` `[VERIFY …]` `` | Warning chip. **Never** sent to Jev. An item that contains only a VERIFY chip is not checkable. |
| Everything outside blocks | Normal QPrompt scripted text (stage directions like `**[Cut to Cam 1]**` stay as-is). |

**Fallback for undelimited scripts:** if a file has no `<!-- checklist -->` markers, treat each `###` under a `## Between: must-say bullet points` heading as a block (the existing Episode 1–15 convention). Explicit delimiters always win. `## Episode summary`, `## Scene list`, `## Bench checklist`, `## Notes for Ben` are not prompted.

Snapshot-test the parsed output of all 15 episodes (read-only source; tests skip if `E:\GDRIVE\...` is missing).

## 5. Architecture & stack (decided)

- **Qt 6** (minimum 6.8.2 per upstream CMake; upstream `setup.sh` targets **6.12.0**), **MSVC 2022 x64**, CMake + Ninja, KF6 frameworks from the bundled submodules. The user's machine has VS 2022 Professional at `C:\DevTools\Microsoft Visual Studio\2022\Professional` (C++ desktop, ATL, Windows SDK 10.0.26100; found via `vswhere`), and Qt 6.12.0 at `C:\Qt\6.12.0\msvc2022_64`, with Qt's CMake and Ninja in `C:\Qt\Tools`.
- New Qt modules we add on top of upstream: **Qt Multimedia** (mic). Upstream already pulls in Qt WebSockets, Network, Quick, QuickControls2, Svg, ShaderTools and LinguistTools. Tests use **Qt Test** via CTest.
- Secrets and network calls stay in C++. QML only receives state (items, covered flags, status, call counts), never keys.

### 5.1 Qt online installer selection

Qt **6.12.x** (or the closest available ≥ 6.8.2; record which one is used here): **MSVC 2022 64-bit**, **Qt Multimedia**, **Qt WebSockets**, **Qt Shader Tools**, and **Qt Image Formats** (optional). Under *Build Tools*: **CMake**, **Ninja**. Optional: **Qt Creator** + **Qt Debugging Tools / CDB** for QML debugging. Skip: Sources, Debug Information Files, Android/WASM, and other compilers. Expected prefix: `C:\Qt\<ver>\msvc2022_64`.

### 5.2 Layout of our code

```
src/intelliprompter/
  script/      # markdown pre-processor: delimiters → ChecklistBlock tree + cleaned markdown for QPrompt (Qt Core only, no GUI)
  coverage/    # CoverageEngine (cookbook port) + TypeSafeClient (REST, QNetworkAccessManager)
  stt/         # SttProvider interface; ElevenLabs (QWebSocket, scribe_v2_realtime); Replay (timed JSON)
  audio/       # mic capture (QAudioSource), device picker, resample → 16 kHz mono PCM16
  secrets/     # DPAPI (CryptProtectData) vault at %APPDATA%\Intelliprompter\credentials.bin (+ optional passphrase/scrypt)
  input/       # gamepad (SDL3), compiled only with INTELLIPROMPTER_GAMEPAD=ON
  qml/         # checklist overlay/decoration, settings pages, setup wizard
tests/intelliprompter/   # Qt Test: parser snapshots, coverage logic with mocked client, replay STT
fixtures/                # episode snapshots, transcript replays, audio (wav git-ignored)
```

`script/` and the decision logic in `coverage/` (throttle, one-way state, roll-up, score mapping) must not depend on GUI or network. They're the most likely to be wrong and must be fully unit-tested.

### 5.3 Integration with QPrompt's document (verify in Step 2)

QPrompt shows the whole script as one rich-text `QTextDocument` in a `Flickable` (`src/prompter/Prompter.qml`, `src/documenthandler.cpp`). It already uses anchors for its markers. Plan: the pre-processor emits each checklist item as a list entry prefixed with ☐ and tagged with an anchor name `ip:<blockId>/<itemId>`. When an item is covered, a C++ helper finds the anchor and updates glyph and color via `QTextCursor` (no re-layout of the rest of the document). Block activation is computed from the anchor positions vs. the Flickable's position and the reading-region offset. Confirm this approach against the actual code before building on it, including what happens when the user edits or saves (QPrompt saves HTML, so anchors must survive a round-trip).

## 6. Credentials

- First run (or no stored keys): a setup wizard asks for the TypeSafe key, then the ElevenLabs key, and validates each with a cheap authenticated call before saving.
- Stored encrypted with **Windows DPAPI** (`CryptProtectData`, bound to the Windows user) in `%APPDATA%\Intelliprompter\credentials.bin`. Never beside the exe, so copying the folder never carries keys.
- Optional passphrase lock: additionally encrypt with a scrypt-derived key and prompt at launch.
- Settings has "Forget keys". Never log keys, never pass them to QML, redact them in errors.

## 7. Gamepad (deferred, prepared)

- Library: **SDL3** (`release-3.4.20`), vendored as a shallow submodule at `3rdparty/SDL` and built via CMake only when `-DINTELLIPROMPTER_GAMEPAD=ON` (default **OFF**). Only the gamepad/joystick/HID subsystems are needed: no SDL video window, events pumped from a Qt timer.
- Why SDL3 over raw XInput: it covers XInput, DirectInput, Bluetooth and generic HID controllers with one mapping DB. Why not Qt Gamepad: it was dropped in Qt 6.
- Interface stub: `src/intelliprompter/input/gamepadinput.h`. Planned mapping: stick/trigger → QPrompt velocity step (deadzone + expo), buttons → pause, next/prev marker, mark covered, nudge.

## 8. Speech-to-text

- **Primary: ElevenLabs Scribe v2 Realtime** (WebSocket, `scribe_v2_realtime`, partial + committed transcripts). Verify event names against https://elevenlabs.io/docs/developers/guides/cookbooks/speech-to-text/streaming.
- **Replay provider** for tests and offline rehearsal (timed transcript JSON → partial/final events).
- **Wispr Flow is not used** (no official streaming API). Keep `SttProvider` pluggable. Local whisper.cpp is a possible later option.

## 9. Our settings (`intelliprompter.json` beside the exe)

```json
{
  "audio": { "inputDeviceId": "", "inputDeviceLabel": "", "preRollMs": 1500 },
  "checklist": { "holdAtBlockEnd": false, "colors": { "pending": "#FFFFFF", "covered": "#3FB950", "parentRollup": "#8FD19E", "verify": "#E3B341" } },
  "stt": { "provider": "elevenlabs", "language": "en", "model": "scribe_v2_realtime" },
  "coverage": { "model": "jev-latest", "coveredAt": 2.5, "minIntervalMs": 1500, "minNewWords": 4 },
  "scriptsRoot": "E:\\GDRIVE\\Vibe Project LLM Chats\\VNA-TDR-Video-Series",
  "hotkeys": { "markCovered": "", "unmarkCovered": "", "skipBlock": "" }
}
```

QPrompt's own settings stay in QPrompt's storage, untouched.

## 10. Build plan

1. **Build stock QPrompt on Windows (gate). Done 2026-11-06.** Run `pwsh scripts/build.ps1`. It configures if needed, then builds, runs `cmake --install` and `windeployqt`. Use `-Step build` for incremental builds and `-Gamepad` to enable SDL3. Output: `build\install\bin\QPrompt.exe`. Notes:
   - **Don't use upstream `setup.sh` on Windows.** It copies ECM/QHotkey output into the Qt prefix. The root CMakeLists already builds ECM, KCoreAddons, Kirigami, QHotkey and Hunspell from the submodules, so configuring against the Qt prefix is enough.
   - Configure warnings are benign: Vulkan headers, KF6Crash (optional) and IcoTool (exe icon only) are not found.
   - A clean build is about 865 Ninja steps. The deployed tree is **1.9 GB**, mostly the FluentWinUI3 Controls style (428 MB) and the QML tree deployed twice (`bin\qml` and `qml`). Trim it in Step 4.
   - The fork shares QPrompt's settings storage with any stock QPrompt install (same app/org name). Consider renaming the app identity before the user runs both side by side.
2. **Parser + checklist display with a fake scorer.** `script/` with Qt Test snapshots of all 15 episodes. Render blocks in the prompter. A debug hotkey ticks the next leaf. Verify the anchor/edit/save behavior (§5.3).
3. **Live coverage.** Mic + device picker, ElevenLabs adapter, Replay provider, TypeSafe client, CoverageEngine (throttle, one-way, roll-up, segment scoping, backoff), DPAPI vault + setup wizard, debug overlay with call counts. The user creates keys at this point.
4. **Package + smoke test.** Portable zip, smoke checklist for the user, session logs to `logs/session-<ts>.json` (no keys, no audio).
5. **Later:** gamepad (§7), remote control, offline STT.

Parallel subagents (in git worktrees) make sense from Step 2/3 on: parser, coverage engine, STT/audio, secrets/wizard are independent once their interfaces are committed.

## 11. Working rules for agents

- Work only inside this folder. `E:\GDRIVE\Vibe Project LLM Chats\VNA-TDR-Video-Series` is **read-only** input.
- Never commit to `main`. Commit on `intelliprompter` (or worktree branches off it). Mark upstream-file edits with `INTELLIPROMPTER:` comments.
- Every new dependency needs a one-line justification in the commit message. Prefer Qt modules already in use.
- A task is done only when it builds and `ctest` passes (once Step 1 establishes the build).
- No real API keys in code, fixtures, logs or snapshots. Live tests only run when `TYPESAFE_API_KEY` / `ELEVENLABS_API_KEY` env vars are set.

## 12. Open questions for the user (ask, don't guess)

- STT fallback if ElevenLabs is unavailable (Deepgram, local whisper)?
- Should the next block's first item be previewed?
- Remote control (phone or Stream Deck via local HTTP) for skip/mark?

## 13. History

- 2026-11-06: Original plan was a custom Electron app with voice-paced scrolling. The user rejected the off-the-shelf voice-scroll prompters (Speakflow, PromptSmart, Teleprompter.com) and preferred QPrompt's manual scroll control, so we forked QPrompt instead. The voice aligner was dropped. Note: QPrompt has **no** native gamepad support (keyboard, wheel and global hotkeys only).
