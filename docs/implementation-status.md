# Implementation status

v1 (Phases 0-8) is done: version 1.0.0, closed 2026-11-08. Its history is in [history/v1-phases.md](history/v1-phases.md). Known item: the 39.5 ms peak frame isn't attributed yet.

Keep this file short: one compact entry per step, with measurements. When a phase closes, move it to `docs/history/`.

## Phase 9 — Quests (v1.1): in progress

Research and decisions: [research/quest-data.md](research/quest-data.md). Decision log: plan §Decision log (2026-11-08 rows).

1. **QuestieDB integration** — done. Read at runtime as an optional dependency (`## OptionalDeps: QuestieDB`, `RequireContract(4)`). Probe (`/azfdiag questdb`): contract 4 OK; only the runtime view has the Forever corrections (43 quests change zone).
2. **Quest catalogue** — done. `Systems/Quests.lua` builds a per-zone index from QuestieDB in batches after `AZF_READY` (+5 s); areas map to zones through our own curated `Data/QuestAreas.lua` (64 zone areas, 19 dungeons, 7 raids, 4 battlegrounds incl. Darkspear Islands). Left out of zone counts and counted by reason: repeatable (incl. daily/weekly/monthly), quest sorts, no zone, dungeon, raid, battleground, unmapped, errors. Dungeon and raid quests are kept per instance for a later Dungeons tab.
   - In game (Gideon, 11:49): 5,233 quests, 2,688 in zone counts; left out: sort 1,067, repeatable 739, dungeon 278, unmapped 191, battleground 125, raid 123, no zone 22, errors 0. 50 zones listed; Deadwind Pass and Mount Hyjal have no quests.
3. **Completion and eligibility** — done. `Systems/QuestRules.lua` (pure): race/faction and class masks, level (locked) and max level, exclusive choices, chains, breadcrumbs, parent quests, recursive prerequisites. Profession, reputation and spell requirements and races past 9 are unknown (left out of totals). Completed list from `C_QuestLog.GetAllCompletedQuestIDs`, re-read 1 s after `QUEST_TURNED_IN` and on `/azf refresh`; re-evaluated on level change. `Quests.ForZone` / `Quests.Overall` return quest objectives and `ns.Progression` counts.
   - In game (Gideon, Human Paladin 10): all zones 42/1,651 done; Elwynn 42/68 (61%), checklist checked by hand; Horde zones all unavailable; a turn-in updated the counts after the debounce. 42 of 87 completed quests count in zones, 43 are quest sorts, 2 aren't in QuestieDB. Build 73 ms of work over 38 frames, slowest frame 3.5 ms (one earlier build hit 15.7 ms; details batch now 50 per frame, not yet checked in game). Evaluating every zone at once: 30 ms in one frame (debug report only; step 5 must spread it). Addon memory after a full GC: 6.3 MB.
   - Open: QuestieDB has no list of quests that can't be obtained. Candidate: "Welcome!" (5805, started by the Northshire Gift Voucher item).
4. **Zone Detail quest section** — next. Mockup first, then Lua.
5. **Overview** — quest stat card and quest suggestions.
6. **In-game check** of spec §12 "v1.1 Quests".

## Tooling (2026-11-08)

- `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]` reads `AzerfolioDB.trace` compactly. Use it instead of ad hoc scripts.
- `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats]` looks up QuestieDB's base rows offline (no corrections).
- `/azf debug quests [full]`: reasons grouped ("level"); `full` saves every zone's checklist.
- `/azf debug perf gc`: memory after a full garbage collection.
- `powershell -File tools/commit.ps1 -MessageFile <file> [-All] [-Paths ...]`.
