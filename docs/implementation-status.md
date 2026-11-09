# Implementation status

v1 (Phases 0-8) is done: version 1.0.0, closed 2026-11-08. Its history is in [history/v1-phases.md](history/v1-phases.md).

v1.1 (Phase 9, quests, flight paths, combined zone completion, the zone dashboard) is done: version 1.1.0, closed 2026-11-08. Its history is in [history/v1.1-phase9.md](history/v1.1-phase9.md).

v1.2 (Phase 10, celebrations and the Atlas) is done: version 1.2.0, closed 2026-11-08. Its history is in [history/v1.2-phase10.md](history/v1.2-phase10.md). Known item: the 39.5 ms peak frame isn't attributed yet.

Keep this file short: one compact entry per step, with measurements. When a phase closes, move it to `docs/history/`.

## Next

**Phase 11: zone reputation (v1.3)**, plan §6 Phase 11, spec §7.8 and §8.9. Next: task 2, the mockup of the reputation section on the zone dashboard (owner review before Lua).

- 2026-11-08, task 1, reputation research (done): owner chose reputation next. Zone factions come from quest reputation rewards (`qdb.lua reps`). Forever has only `C_Reputation`: the met list holds 5 factions for Gideon, and by-ID reads also cover unmet factions (38 of 52 IDs). Findings and open questions in [research/reputation.md](research/reputation.md). Decided: zone factions derived from quests (`qdb.lua reps rule`, 21 zones), not a completion category, section hidden where there's none.

## Tooling (2026-11-08)

- `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]` reads `AzerfolioDB.trace` compactly. Use it instead of ad hoc scripts.
- `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats|npc|rares|objects|recipes|reps]` looks up QuestieDB's base rows offline (no corrections).
- `/azfdiag reps` + `luajit tools/diag-report.lua reps`: reputation APIs, met factions, lookups by ID.
- `/azf debug quests [full]`: reasons grouped ("level"); `full` saves every zone's checklist.
- `/azf debug perf gc`: memory after a full garbage collection.
- `powershell -File tools/commit.ps1 -MessageFile <file> [-All] [-Paths ...]`.
