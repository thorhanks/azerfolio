# Implementation status

v1 (Phases 0-8) is done: version 1.0.0, closed 2026-11-08. Its history is in [history/v1-phases.md](history/v1-phases.md).

v1.1 (Phase 9, quests, flight paths, combined zone completion, the zone dashboard) is done: version 1.1.0, closed 2026-11-08. Its history is in [history/v1.1-phase9.md](history/v1.1-phase9.md). Known item: the 39.5 ms peak frame isn't attributed yet.

Keep this file short: one compact entry per step, with measurements. When a phase closes, move it to `docs/history/`.

## Next

Not planned yet. Candidates are in spec §3 "Later". Start a new phase in the plan before building.

## Tooling (2026-11-08)

- `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]` reads `AzerfolioDB.trace` compactly. Use it instead of ad hoc scripts.
- `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats]` looks up QuestieDB's base rows offline (no corrections).
- `/azf debug quests [full]`: reasons grouped ("level"); `full` saves every zone's checklist.
- `/azf debug perf gc`: memory after a full garbage collection.
- `powershell -File tools/commit.ps1 -MessageFile <file> [-All] [-Paths ...]`.
