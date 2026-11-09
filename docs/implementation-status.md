# Implementation status

v1 (Phases 0-8) is done: version 1.0.0, closed 2026-11-08. Its history is in [history/v1-phases.md](history/v1-phases.md).

v1.1 (Phase 9, quests, flight paths, combined zone completion, the zone dashboard) is done: version 1.1.0, closed 2026-11-08. Its history is in [history/v1.1-phase9.md](history/v1.1-phase9.md). Known item: the 39.5 ms peak frame isn't attributed yet.

Keep this file short: one compact entry per step, with measurements. When a phase closes, move it to `docs/history/`.

## Phase 10 — Celebrations and the Atlas (v1.2): in progress

0. Small fixes: the six "Welcome!" voucher quests left out (Elwynn now 43 of 67); right stick stays with the camera (owner).
1. **Celebrations** — done (mockup approved 2026-11-08). `Systems/Celebrations.lua` (pure Snapshot/Diff; live: first snapshot 8 s after ready, then compares after updates; queue), `UI/Celebration.lua` (overlay with still rays, motes, the painted frame; category medal with the streamer, claim with the hoisted standard; A/B continue via `UI.modal`; on-screen alert with the window closed). `/azf debug celebrate explore|quests|flights|claim [mapID]`. In game (19:01): alert, claim, Explored and Westfall flight path previews render; A and B continue.
2. **Atlas** — done (mockup approved 2026-11-08). `Systems/Atlas.lua`: zone rectangles from `C_Map.GetMapRectOnMap` (read once per session), pure `Layout` (one tile size at each true centre, pushed apart until none overlap; 0 overlaps on the real Eastern Kingdoms data, 40+ before). `UI/AtlasChart.lua`: the painted sea chart (`Media\Chrome\atlas-backdrop`, owner's art) in the frame; Kalimdor left, Eastern Kingdoms right; Zephras Isle (no rectangle on any map, `/azfdiag zones` world probe) in the sea as "Uncharted waters". Zones tab: Y cycles Cards, List, Atlas. Overview: Atlas panel with art blocks; A opens the Atlas on your zone. In game (19:41): both render; filters dim; A opens a zone. Fixed after: "Open Atlas" was under the Eastern Kingdoms' tiles (not re-checked).

## Tooling (2026-11-08)

- `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]` reads `AzerfolioDB.trace` compactly. Use it instead of ad hoc scripts.
- `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats]` looks up QuestieDB's base rows offline (no corrections).
- `/azf debug quests [full]`: reasons grouped ("level"); `full` saves every zone's checklist.
- `/azf debug perf gc`: memory after a full garbage collection.
- `powershell -File tools/commit.ps1 -MessageFile <file> [-All] [-Paths ...]`.
