# Implementation status

v1 (Phases 0-8) is done: version 1.0.0, closed 2026-11-08. Its history is in [history/v1-phases.md](history/v1-phases.md).

v1.1 (Phase 9, quests, flight paths, combined zone completion, the zone dashboard) is done: version 1.1.0, closed 2026-11-08. Its history is in [history/v1.1-phase9.md](history/v1.1-phase9.md).

v1.2 (Phase 10, celebrations and the Atlas) is done: version 1.2.0, closed 2026-11-08. Its history is in [history/v1.2-phase10.md](history/v1.2-phase10.md). Known item: the 39.5 ms peak frame isn't attributed yet.

Keep this file short: one compact entry per step, with measurements. When a phase closes, move it to `docs/history/`.

## Next

**Phase 11: zone reputation (v1.3)**, plan §6 Phase 11, spec §7.8 and §8.9. Next: task 3, systems (zone-faction rule, rivals, `Systems/Reputation`); the faction page also needs the zone's quests matched to the factions they raise.

- 2026-11-08, task 1, reputation research (done): owner chose reputation next. Zone factions come from quest reputation rewards (`qdb.lua reps`). Forever has only `C_Reputation`: the met list holds 5 factions for Gideon, and by-ID reads also cover unmet factions (38 of 52 IDs). Findings and open questions in [research/reputation.md](research/reputation.md). Decided: zone factions derived from quests (`qdb.lua reps rule`, 21 zones), not a completion category, section hidden where there's none.

- 2026-11-08, task 2, reputation mockup (approved): a Reputation ledger under Next up, one line per faction (name and tags, reaction, an eight-step reaction ladder, n / m). Painted ladder from new art (`frame-step`, `bar-fill-white` tinted; brighter tints because multiply darkens). Tags: Not met yet, At war, Rival (`qdb.lua reps rivals`: Booty Bay ⇄ Bloodsail, Gelkis ⇄ Magram). A opens a faction page with the zone's quests that raise it (`qdb.lua reps quests`). Fits the 740 px window (475 / 475 px); wide split 509 / 429. Round 1 (cards with a per-reaction bar) replaced: the bar misread at Hated. Spec in `mockups/DESIGN.md`.

## Tooling (2026-11-08)

- `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]` reads `AzerfolioDB.trace` compactly. Use it instead of ad hoc scripts.
- `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats|npc|rares|objects|recipes|reps]` looks up QuestieDB's base rows offline (no corrections).
- `/azfdiag reps` + `luajit tools/diag-report.lua reps`: reputation APIs, met factions, lookups by ID.
- `/azf debug quests [full]`: reasons grouped ("level"); `full` saves every zone's checklist.
- `/azf debug perf gc`: memory after a full garbage collection.
- `powershell -File tools/commit.ps1 -MessageFile <file> [-All] [-Paths ...]`.
