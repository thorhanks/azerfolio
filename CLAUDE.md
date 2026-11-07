# Azerfolio — agent instructions

Completionist dashboard addon for World of Warcraft: Forever. Personal project, built entirely by AI agents; the owner runs the game.

Read before working: [project-spec.md](project-spec.md) (what), [project-implementation-plan.md](project-implementation-plan.md) (how, phases, decision log), [docs/implementation-status.md](docs/implementation-status.md) (where we are), [docs/research/client-capabilities.md](docs/research/client-capabilities.md) (what the client can do).

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
- Diagnostics in game: `/azfdiag` (help), `/azfdiag all`, `/azfdiag zone`, `/azfdiag sniff`, `/azfdiag art`
- Addon in game: `/azf help`, `/azf status`, `/azf debug [zone]`, `/azf refresh`, `/azf shot`
- Mockups: start the `mockups` preview (`.claude/launch.json`, serves `mockups/` on http://localhost:8765 via `tools/serve-mockups.ps1`). Regenerate zone data with `luajit tools/export-mock-data.lua | Out-File -Encoding utf8 mockups/data.js`. Mockup state (Gideon's progress, level ranges, factions) is sample data in `mockups/app.js`, not addon data.
- Zone art: owner saves generated images as `art/source/<mapID>-<slug>.png` (prompts in `art/prompts.md`, rules in `art/style-guide.md`), then `powershell -File tools/process-art.ps1`. This writes `Azerfolio/Media/Zones/<mapID>.png` (1024×512), regenerates `Azerfolio/Data/Art.lua`, and updates the mockup. Never hand-edit `Data/Art.lua`.
- Git: not on PATH; use `C:\Users\thorh\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`. Pass commit messages with `-F <file>` (PowerShell 5.1 mangles quotes in arguments). Pushing needs the owner (GitHub Desktop holds the login).

## Code layout

- `Azerfolio/Core/` — `Init` (namespace `ns`), `Config` (defaults/enums/ranges), `SavedVariables` (pure: validate/migrate), `Debug` (`Try`, error log), `Events` (dispatcher, `On`/`Send` messages, `Debounce`), `Character`, `Commands`, `Lifecycle` (loaded last).
- New files go in the TOC in dependency order; `tests/addon_smoke_test.lua` loads the addon from the TOC, so a missing file fails the tests.
- Internal messages are named `AZF_*`. Startup: `ADDON_LOADED` → `PLAYER_LOGIN` → `AZF_READY`.
