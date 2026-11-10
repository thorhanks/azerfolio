# Implementation status

v1 (Phases 0-8) is done: version 1.0.0, closed 2026-11-08. Its history is in [history/v1-phases.md](history/v1-phases.md).

v1.1 (Phase 9, quests, flight paths, combined zone completion, the zone dashboard) is done: version 1.1.0, closed 2026-11-08. Its history is in [history/v1.1-phase9.md](history/v1.1-phase9.md).

v1.2 (Phase 10, celebrations and the Atlas) is done: version 1.2.0, closed 2026-11-08. Its history is in [history/v1.2-phase10.md](history/v1.2-phase10.md). Known item: the 39.5 ms peak frame isn't attributed yet.

Phase 12 (the Reputation tab, v1.4) is done, closed 2026-11-09. Its history is in [history/v1.4-phase12.md](history/v1.4-phase12.md). Open checks T2 and T3 wait on play. The version stays 1.2.0 until Phase 11 (v1.3) closes.

Keep this file short: one compact entry per step, with measurements. When a phase closes, move it to `docs/history/`.

In-game checks that wait on real play (a first-time faction, a level-60 character, a real zone completion) are listed in [open-checks.md](open-checks.md). Phase 11 closes when its R1 and R2 are done.

## Next

**Phase 11: zone reputation (v1.3)**, plan §6 Phase 11, spec §7.8 and §8.9. Next: task 5, checking on both characters and settling the open questions.

- 2026-11-08, task 1, reputation research (done): owner chose reputation next. Zone factions come from quest reputation rewards (`qdb.lua reps`). Forever has only `C_Reputation`: the met list holds 5 factions for Gideon, and by-ID reads also cover unmet factions (38 of 52 IDs). Findings and open questions in [research/reputation.md](research/reputation.md). Decided: zone factions derived from quests (`qdb.lua reps rule`, 21 zones), not a completion category, section hidden where there's none.

- 2026-11-08, task 2, reputation mockup (approved): a Reputation ledger under Next up, one line per faction (name and tags, reaction, an eight-step reaction ladder, n / m). Painted ladder from new art (`frame-step`, `bar-fill-white` tinted; brighter tints because multiply darkens). Tags: Not met yet, At war, Rival (`qdb.lua reps rivals`: Booty Bay ⇄ Bloodsail, Gelkis ⇄ Magram). A opens a faction page with the zone's quests that raise it (`qdb.lua reps quests`). Fits the 740 px window (475 / 475 px); wide split 509 / 429. Round 1 (cards with a per-reaction bar) replaced: the bar misread at Hated. Spec in `mockups/DESIGN.md`.

- 2026-11-08, task 3, reputation systems (in-game check pending): `Systems/ReputationRules` (pure rule, rivals, display order) and `Systems/Reputation` (`ForZone`, `Faction`: reaction, into / span, met true/false/unknown, at war, rivals with data, the zone's raising quests with Quests' state and base amount; nil without QuestieDB). Met list opens collapsed headers and closes them bottom-up; its own `UPDATE_FACTION` doesn't re-expand (2 s quiet). Repeatables count (without them Feralas and Wintersaber Trainers drop out), so Quests' index keeps their IDs and the details pass reads them plus `reputationReward`. `qdb.lua reps check`: 21 zones, 0 mismatches with `reps rule`; same with excluded quests left out. Tests 250 pass. In game (Gideon, `trace-report.lua reputation`): 20 zones, 19 factions, 15 with data (none: 471, 910, 2778, 2787, as the probe); QuestieDB's in-game corrections differ from the base rows: Feralas has no faction, The Barrens adds Powderfuse 2827 (3) and Ratchet 27. A collapsed header was opened once on `UPDATE_FACTION`; the follow-up refresh opened none (no loop).

- 2026-11-08, task 4, reputation UI (done, awaiting approval): the ledger under Next up (gold title over the painted divider, one line per faction with tags, reaction, the notched bar `Widgets.RepBar`, n / m; wide split 64 / 148 / 92; each faction a focus stop with the specified info line) and the faction page (`rep:<factionID>`: banner with the reaction, summary with "n to <next>", rival note, chips by difficulty with "~+amount" and the Quests page's states, Up to your level / Later on LT/RT, footer; B back to the same faction). `Reputation` now passes each quest's `kind`. `/azf debug reputation [mapID|questID]` + `trace-report.lua reputation`: the corrections give rewards to Barrens quests 97003/97005, which raises Steamwheedle's total to 9, so Feralas' 4 fall under the 50% share ([research](research/reputation.md)). `/azf shots reputation` (4 shots). In game (Gideon, Stranglethorn, `WoWScrnShot_110826_222704`-`222709`): fits 740 px and the wide split. Fixed after: ⚔/⇄ drawn as boxes (dropped), the current step's glow read as a hard box (now fades), "35,500 / 36,000" cut in the wide split (the numbers column grows to its text), "Locked" repeated under Later, the info line too long. Round 3 (owner: the pill boxes didn't appeal): the ladder became one gilded bar notched at each reaction change (equal eighths; true scale tried in the mockup and dropped), checked in game `WoWScrnShot_110826_224134`-`224139` (`Texture:SetRotation` works: diamond caps). Tests 253 pass.

- 2026-11-08, minimum window size (owner's shot `WoWScrnShot_110826_224414`: the ledger fell off the bottom, the pole poked out): the dashboard's right column (tiles, Next up, Reputation) scrolls and follows focus; the standard refits on every resize (scale floor 0.2); the ledger uses the compact columns below 640 wide and a row with wrapped tags grows to fit. `/azf shots reputation` adds the minimum size (5 shots). Checked in game `WoWScrnShot_110826_225321`-`225328`.

- 2026-11-08, task 5, both characters (approval pending): Thragor and Gideon get the same 20 zones and the same standing for shared factions; side factions follow the side (Thragor 2778, 2787; Gideon 2779, 589). Each game Reputation window shows only home factions, which agrees with "Not met yet" everywhere. Settled: 471 and Brood of Nozdormu hidden (no data), Zephras Isle one faction per side, Feralas keeps the rule (owner). Still open: a met zone faction against the game's window and a refresh after a zone-faction turn-in (neither character has one). `trace-report.lua reputation` now prints the standing that changed between refreshes. Shots `WoWScrnShot_110826_225848`-`230104`.

## Class tab (planned)

- 2026-11-09, task 1, class quest research (in progress): owner chose a Class tab, designed as a class-themed journey map with nodes (strip on the left, stop details on the right). `qdb.lua class [name [race]]`: 93-144 class-restricted quests per class (base rows), dense at 10-29 and sparse at 30-49. Forever adds race/class pairs (Horde Paladin, Dwarf Shaman), Skyborne intros, and trainer ability quests. Gideon's road comes out at about 7 stops, plus about 40 raid gear quests (for the Dungeons tab). Base chain links are incomplete, so the proposal is a curated `Data/ClassJourneys.lua`. In-game checks and owner questions in [research/class-quests.md](research/class-quests.md).

## Tooling (2026-11-08)

- `luajit tools/trace-report.lua [summary|last [n]|quests|zone <mapID>|perf|kind <name> [n]]` reads `AzerfolioDB.trace` compactly. Use it instead of ad hoc scripts.
- `luajit tools/qdb.lua [quest <id>...|area <areaID>|name <text>|stats|npc|rares|objects|recipes|class|reps]` looks up QuestieDB's base rows offline (no corrections).
- `/azfdiag reps` + `luajit tools/diag-report.lua reps`: reputation APIs, met factions, lookups by ID.
- `/azf debug quests [full]`: reasons grouped ("level"); `full` saves every zone's checklist.
- `/azf debug perf gc`: memory after a full garbage collection.
- `powershell -File tools/commit.ps1 -MessageFile <file> [-All] [-Paths ...]`.
