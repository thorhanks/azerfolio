# Azerfolio — agent instructions

Completionist dashboard addon for World of Warcraft: Forever. Personal project, built entirely by AI agents; the owner runs the game.

Read before working: [project-spec.md](project-spec.md) (what), [project-implementation-plan.md](project-implementation-plan.md) (how, phases, decision log), [docs/implementation-status.md](docs/implementation-status.md) (where we are), [docs/research/client-capabilities.md](docs/research/client-capabilities.md) (what the client can do).

## Environment

- Game: `C:\Program Files (x86)\World of Warcraft\_forever_` — flavor `wowf`, interface `16001`.
- Addon folders in this repo (`Azerfolio/`, `AzerfolioDiag/`) are junctioned into `<game>\Interface\AddOns` by `tools/link-addons.ps1`. Edits in the repo are live after `/reload` in game.
- SavedVariables: `<game>\WTF\Account\COMPUTERWISPERER\SavedVariables\<Addon>.lua`. Written on `/reload` or logout. Read them to get in-game results.
- Shell is Windows PowerShell 5.1. PowerShell variable names are case-insensitive. No Python; git isn't on PATH.
- LuaJIT: `C:\Users\thorh\AppData\Local\Programs\LuaJIT\bin\luajit.exe` (on the user PATH; a shell started before install may need it added).

## Hard rules

- **Honest data:** never display a count, state, total, percentage, or timestamp the game didn't confirm. Unknown stays unknown.
- **No new dependencies** (addons, embedded libraries, dev tools) without the owner's explicit approval.
- **Verify client APIs** before relying on them; guard with existence checks and `pcall`. Retail/Classic docs are only hints. Tag research findings with evidence levels (plan §2.2).
- **UI never calculates progress**; the progression service does.
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
