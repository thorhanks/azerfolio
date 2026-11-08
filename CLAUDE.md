# Azerfolio — agent instructions

Completionist dashboard addon for World of Warcraft: Forever. Personal project, built entirely by AI agents; the owner runs the game.

Read before working:
- [project-spec.md](project-spec.md): what we're building.
- [project-implementation-plan.md](project-implementation-plan.md): how, the phases, and the decision log.
- [docs/implementation-status.md](docs/implementation-status.md): where we are and what's next.
- [docs/research/client-capabilities.md](docs/research/client-capabilities.md) and [docs/research/exploration-validation.md](docs/research/exploration-validation.md): verified client facts (APIs, exploration, gamepad, art formats).
- [mockups/DESIGN.md](mockups/DESIGN.md): **the approved UI design** (design system, screens, gamepad map). The Lua UI must follow it; the mockup at http://localhost:8765 is the visual reference.
- [art/style-guide.md](art/style-guide.md): zone art rules and pipeline.

## Current state (2026-11-08)

- Phases 0–5 done. The window has the **native Forever look** (`PortraitFrameTemplate` and the atlases in `mockups/DESIGN.md` § Native look), gamepad focus, Zones list / Zone Detail / wide split view (window ≥ 1440), launchers (minimap button, addon compartment; no key binding, removed 2026-11-08). Exploration: generated catalogue (`Data/Exploration.lua`, regenerate with `luajit tools/gen-exploration.lua`), `Systems/Objectives`, `Progression` (all counts), `Exploration` (tracker, live refresh, `AZF_EXPLORATION_UPDATED`), `Milestones` (per-character baseline, `AZF_MILESTONE`). **Phase 6 done** (Zones catalogue: cards/list, status/Show/Level/Sort, search, X/Y; Zone Detail with progress banner, unknown areas, notes, world map on X; `Systems/Zones`, account schema 4). The client has no level ranges or faction, so both come from the hand-curated, unofficial `Data/Zones.lua` (Warcraft Wiki + the owner). `/azf debug zones` traces the catalogue. **Phase 7 done** (Overview: `Systems/Overview.lua` picks, `UI/Pages/Overview.lua`, visit tracker in `recentZones`, `/azf debug overview`). **Phase 8 done; v1 closed 2026-11-08 as version 1.0.0** (every spec §12 v1 criterion met, `docs/testing.md` § Phase 8). Known: the 39.5 ms peak frame isn't attributed yet. **Next: Phase 9** (Quests, v1.1): first decide the QuestieDB integration (plan Phase 9 task 1).
- Debug mode (`/azf debug`) writes a capped trace to `AzerfolioDB.trace`; read it after `/reload`. `/azf debug exploration` prints the current zone, the total and milestones. `RECEIVED_ACHIEVEMENT_LIST` doesn't fire on `/reload`.
- Banner crop offsets: `Theme.bannerFocus`; check with `/azf shots banners`.
- In game, the owner may still have **Azerfolio Diagnostics** enabled with its event sniffer on. Ask them to turn it off (`/azfdiag sniff`, then untick the addon) when it's no longer needed.

## How the owner likes to work

- Plays with a **gamepad** on a **3440×1440** screen; characters: Gideon (Alliance Paladin, main test character) and Thragor (Horde).
- Wants thorough reviews with concrete measurements, and evidence before claims (in-game checks via SavedVariables files and screenshots the agent reads itself).
- Approves work step by step; commit after each completed step with a descriptive message. The owner pushes from GitHub Desktop.
- Design iterations go through the mockup first, then Lua.

## Environment

- Game: `C:\Program Files (x86)\World of Warcraft\_forever_` — flavor `wowf`, interface `16001`.
- Addon folders in this repo (`Azerfolio/`, `AzerfolioDiag/`) are junctioned into `<game>\Interface\AddOns` by `tools/link-addons.ps1`. Edits in the repo are live after `/reload` in game.
- SavedVariables: account-wide `<game>\WTF\Account\COMPUTERWISPERER\SavedVariables\<Addon>.lua`; per character `<game>\WTF\Account\COMPUTERWISPERER\91\<Character-Realm>\SavedVariables\<Addon>.lua` (e.g. `Gideon-Everhope`). Written on `/reload` or logout. Read them to get in-game results.
- Screenshots: `<game>\Screenshots\WoWScrnShot_MMDDYY_HHMMSS.jpg`. The owner's display is 3440×1440 (ultrawide), and they play with a gamepad.
- Shell is Windows PowerShell 5.1. PowerShell variable names are case-insensitive. No Python; git isn't on PATH.
- LuaJIT: `C:\Users\thorh\AppData\Local\Programs\LuaJIT\bin\luajit.exe` (on the user PATH; a shell started before install may need it added).

## Hard rules

- **Honest data:** never display a count, state, total, percentage, or timestamp the game didn't confirm. Unknown stays unknown.
- **No new dependencies** (addons, embedded libraries, dev tools) without the owner's explicit approval.
- **Verify client APIs** before relying on them; guard with existence checks and `pcall`. Retail/Classic docs are only hints. Tag research findings with evidence levels (plan §2.2).
- **UI never calculates progress**; the progression service does.
- **Never commit** `AzerfolioDiag.lua` dumps or other SavedVariables files: they can contain chat and friend-list data.
- **Don't copy code** from other addons; reading them to learn API usage is fine.
- Lua 5.1 only. No `goto`, no integer division `//`, no `table.unpack` in addon code (use `unpack`).
- Modules with pure logic must not touch WoW globals at load time, so tests can load them.

## Working with the owner

- Give numbered, minimal in-game steps with exact slash commands. Ask for `/reload` when you need SavedVariables.
- Prefer reading files over asking the owner to copy text.
- After each phase, update `docs/implementation-status.md` and the plan's decision log.

## Commands

- Link addons: `powershell -File tools/link-addons.ps1` (`-Unlink` to remove)
- Tests: `luajit tests/run.lua` (from repo root)
- Read the diagnostic dump: `luajit tools/diag-report.lua [summary|env|explore|criteria <achID>|maps|zone|events|log [n]|quests|art|ns <filter>|errors]`
- Diagnostics in game: `/azfdiag` (help), `/azfdiag all`, `/azfdiag zone`, `/azfdiag zones` (level ranges, map rects; report `zones`), `/azfdiag sniff`, `/azfdiag art`, `/azfdiag skin` (native frame textures; report `skin [tree [filter]]`)
- Addon in game: `/azf help`, `/azf status`, `/azf debug [zone|exploration|zones|overview|perf]`, `/azf refresh`, `/azf shot`, `/azf shots` (screenshots every tab and state), `/azf shots banners`
- Mockups: start the `mockups` preview (`.claude/launch.json`, serves `mockups/` on http://localhost:8765 via `tools/serve-mockups.ps1`). Regenerate zone data with `luajit tools/export-mock-data.lua | Out-File -Encoding utf8 mockups/data.js`. Mockup state (Gideon's progress, level ranges, factions) is sample data in `mockups/app.js`, not addon data.
- Zone art: owner saves generated images as `art/source/<mapID>-<slug>.png` (prompts in `art/prompts.md`, rules in `art/style-guide.md`), then `powershell -File tools/process-art.ps1`. This writes `Azerfolio/Media/Zones/<mapID>.blp` (1024×512 BLP2 DXT1 + mips, via `tools/Blp.cs`), the mockup PNGs, and `Azerfolio/Data/Art.lua`. Never hand-edit `Data/Art.lua`. Use the `.blp` extension in texture paths. Review with `tools/art-contact-sheet.ps1`. Only BLPs are committed; `art/source/` and mockup PNGs are git-ignored.
- Git: not on PATH; use `C:\Users\thorh\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`. Pass commit messages with `-F <file>` (PowerShell 5.1 mangles quotes in arguments). Pushing needs the owner (GitHub Desktop holds the login).

## Code layout

- `Azerfolio/Core/` — `Init` (namespace `ns`), `Config` (defaults/enums/ranges), `SavedVariables` (pure: validate/migrate), `Debug` (`Try`, error log), `Events` (dispatcher, `On`/`Send` messages, `Debounce`), `Character`, `Commands`, `Lifecycle` (loaded last).
- `Azerfolio/Systems/` — `Maps` (zone list from the client's map tree), `Objectives`, `Progression`, `Exploration`, `Milestones`, `Zones` (catalogue entries, filters, sorts, sections), `Overview` (dashboard picks, visit tracker).
- `Azerfolio/UI/` — `Theme` (all style constants and native atlases), `FocusGrid` (pure focus logic), `MainWindow` (`ns.UI`: native frame, tabs via `UI.RegisterTab`, legend, geometry), `Gamepad` (addon-owned input layer), `Focus` (per-tab focus, chevron, scroll into view), `Widgets` (shared scroll, header, focus row, control, pips, level bar), `Pages/` (one file per tab, plus `ZonesCatalogue`; `page:GetFocusRows()` opts into focus, `page:OnButton` takes X/Y, `page:GetHints` adds hints), `Shots` (`/azf shots`).
- New files go in the TOC in dependency order; `tests/addon_smoke_test.lua` loads the addon from the TOC, so a missing file fails the tests.
- Internal messages are named `AZF_*`. Startup: `ADDON_LOADED` → `PLAYER_LOGIN` → `AZF_READY`.
