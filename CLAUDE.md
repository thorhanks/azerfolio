# Azerfolio — agent instructions

Completionist dashboard addon for World of Warcraft: Forever. Personal project, built entirely by AI agents; the owner runs the game.

Read before working:
- [project-spec.md](project-spec.md): what we're building.
- [project-implementation-plan.md](project-implementation-plan.md): how, the phases, and the decision log.
- [docs/implementation-status.md](docs/implementation-status.md): where we are and what's next.
- [docs/research/client-capabilities.md](docs/research/client-capabilities.md) and [docs/research/exploration-validation.md](docs/research/exploration-validation.md): verified client facts (APIs, exploration, gamepad, art formats).
- [mockups/DESIGN.md](mockups/DESIGN.md): **the approved UI design** (design system, screens, gamepad map). The Lua UI must follow it; the mockup at http://localhost:8765 is the visual reference.
- [art/style-guide.md](art/style-guide.md): zone art rules and pipeline.

## Current state (2026-11-08, v1.2.0)

- v1 (1.0.0) and v1.1 (1.1.0, Phase 9: quests via QuestieDB, flight paths, combined zone completion, zone dashboard, Overview) closed 2026-11-08; v1.2 (1.2.0, Phase 10: celebrations and the Atlas) closed the same day. **Next:** Phase 11, zone reputation (v1.3); tasks 1 (research) and 2 (mockup, approved) done, task 3 (systems) next. History in `docs/history/`.
- Level ranges and factions come from the hand-curated, unofficial `Data/Zones.lua`; quest areas from `Data/QuestAreas.lua`. Dungeon and raid quests are kept per instance for a later Dungeons tab.
- Debug mode (`/azf debug`) writes a capped trace to `AzerfolioDB.trace`; read it after `/reload` with `luajit tools/trace-report.lua` (not ad hoc scripts). `/azf debug exploration` prints the current zone and the total. `RECEIVED_ACHIEVEMENT_LIST` doesn't fire on `/reload`.
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
- Read the addon's trace: `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]`
- QuestieDB offline (base rows, no corrections): `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats|npc <id>...|rares [areaID|all]|objects <text|*> [areaID]|recipes [areaID]|reps [zone filter|rule|rivals|quests <zone> <factionID>]]`
- Read the diagnostic dump: `luajit tools/diag-report.lua [summary|env|explore|criteria <achID>|maps|zone|events|log [n]|quests|questdb [areas]|art|ns <filter>|reps|errors]`
- Diagnostics in game: `/azfdiag` (help), `/azfdiag all`, `/azfdiag zone`, `/azfdiag zones` (level ranges, map rects; report `zones`), `/azfdiag questdb` (QuestieDB API, read cost, corrections, race masks, quest areas; report `questdb [areas]`), `/azfdiag reps` (faction APIs and list; report `reps`), `/azfdiag sniff`, `/azfdiag art`, `/azfdiag skin` (native frame textures; report `skin [tree [filter]]`)
- Addon in game: `/azf help`, `/azf status`, `/azf debug [zone|exploration|zones|overview|quests [full]|perf [gc|reset]]`, `/azf refresh`, `/azf shot`, `/azf shots` (screenshots every tab and state), `/azf shots banners`
- Mockups: start the `mockups` preview (`.claude/launch.json`, serves `mockups/` on http://localhost:8765 via `tools/serve-mockups.ps1`). Regenerate zone data with `luajit tools/export-mock-data.lua | Out-File -Encoding utf8 mockups/data.js`. Mockup state (Gideon's progress, level ranges, factions) is sample data in `mockups/app.js`, not addon data.
- Zone art: owner saves generated images as `art/source/<mapID>-<slug>.png` (prompts in `art/prompts.md`, rules in `art/style-guide.md`), then `powershell -File tools/process-art.ps1`. This writes `Azerfolio/Media/Zones/<mapID>.blp` (1024×512 BLP2 DXT1 + mips, via `tools/Blp.cs`), the mockup PNGs, and `Azerfolio/Data/Art.lua`. Never hand-edit `Data/Art.lua`. Use the `.blp` extension in texture paths. Review with `tools/art-contact-sheet.ps1`. Only BLPs are committed; `art/source/` and mockup PNGs are git-ignored.
- Commit: write the message to a scratch file, then `powershell -File tools/commit.ps1 -MessageFile <file> -All` (or `-Paths a,b`). Git isn't on PATH; the script holds the path (`C:\Users\thorh\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`). Pushing needs the owner (GitHub Desktop holds the login).

## Keeping token use down

- Read in-game results with `tools/trace-report.lua` and `tools/diag-report.lua`; extend those tools instead of writing one-off scripts.
- Read only the part of a file you need (Grep, then Read with offset/limit).
- Keep `docs/implementation-status.md` short (one compact entry per step); move closed phases to `docs/history/`.
- Start a new session for each Phase step; this file and the status doc are the handoff.

## Code layout

- `Azerfolio/Core/` — `Init` (namespace `ns`), `Config` (defaults/enums/ranges), `SavedVariables` (pure: validate/migrate), `Debug` (`Try`, error log), `Events` (dispatcher, `On`/`Send` messages, `Debounce`), `Character`, `Commands`, `Lifecycle` (loaded last).
- `Azerfolio/Systems/` — `Maps` (zone list from the client's map tree), `Objectives`, `Progression`, `Exploration`, `FlightPaths`, `Zones` (catalogue entries, filters, sorts, sections), `Atlas` (zone places and the tile layout), `Celebrations` (in-session completions), `Overview` (dashboard picks, tracked completion, visit tracker), `QuestRules` (pure quest eligibility), `Quests` (QuestieDB quest index per zone, completion, quest objectives).
- `Azerfolio/UI/` — `Theme` (all style constants and native atlases), `FocusGrid` (pure focus logic), `MainWindow` (`ns.UI`: native frame, tabs via `UI.RegisterTab`, legend, geometry), `Gamepad` (addon-owned input layer), `Focus` (per-tab focus, chevron, scroll into view), `Widgets` (shared scroll, header, focus row, control, pips, level bar), `Pages/` (one file per tab, plus `ZonesCatalogue`; `page:GetFocusRows()` opts into focus, `page:OnButton` takes X/Y, `page:GetHints` adds hints), `Shots` (`/azf shots`).
- New files go in the TOC in dependency order; `tests/addon_smoke_test.lua` loads the addon from the TOC, so a missing file fails the tests.
- Internal messages are named `AZF_*`. Startup: `ADDON_LOADED` → `PLAYER_LOGIN` → `AZF_READY`.
