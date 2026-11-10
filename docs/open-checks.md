# Open in-game checks

Things built and tested offline that only real play can confirm. Most need a moment you can't set up on demand: a first-time faction, a level-60 character, the last area of a zone. Revisit them while playing; nothing here blocks using the addon.

**How to use this list:**
- Playing: when one of these moments comes up, note it (or take `/azf shot`) and tell the agent. Most need debug mode on (`/azf debug`) so the trace records it, then `/reload`.
- Agents: when a check can't be done now, add it here (ID, what, when it comes up, how to check, where the result goes). When one is confirmed, move it to "Done" with the date and evidence, and update the doc it came from.

## Reputation (Phase 11)

Phase 11 (v1.3) stays open until R1 and R2 are done: its "done when" asks for game-confirmed standing on both characters.

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| R1 | A met zone faction shows the same reaction and numbers as the game's Reputation window | The first quest that raises a zone faction (Thragor: Ratchet quests in The Barrens, around level 15) | Open the zone in Azerfolio and the game's Reputation window (U), `/azf shot` each. The ledger line should drop "Not met yet" and the bar should show full colour |
| R2 | The ledger updates after that turn-in, without `/reload` | Same turn-in, with the zone's dashboard open (or opened right after) | `/reload`, then `luajit tools/trace-report.lua reputation`: an `UPDATE_FACTION` refresh with the faction's standing change |
| R3 | Brood of Nozdormu (910) reads at level 60 or once met; today the game returns nothing, so Silithus shows only Cenarion Circle | A level-60 character, or meeting the faction | `/azf debug reputation`, `/reload`, trace-report: 910 no longer "none" |
| R4 | What faction 471 is on Forever (Wetlands, Hinterlands); the game returns nothing for it on either side, so it's hidden | Any time it starts returning data (a patch, a quest) | Same as R3 |
| R5 | "At war" follows the game's At War box | Ticking At War on a met zone faction in the game's window | `/azf shot` of the ledger: the red "At war" tag appears |
| R6 | Exalted shows no numbers and the marker at the end of the bar | A zone faction at Exalted | `/azf shot` of the ledger |

## Reputation tab (Phase 12)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| T2 | "+n today" shows a gain seen this session, and nothing after a `/reload` | A quest turn-in that raises any faction | Turn in, open the tab: the tag on that faction; trace-report reputation shows the `+n` |
| T3 | Whether an unmet faction can be watched (the addon offers X only for met ones) | Any time | Same as T1 on Booty Bay, with the check lifted, or ask the game's Reputation window |

## Class tab (Phase 13)

`/azf debug class [questID ...]` (debug on), `/reload`, then `luajit tools/trace-report.lua class`. C1-C3 can be checked any time; C4-C6 wait on play.

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| C1 | A done class quest reads as done (Gideon: 3101 Consecrated Letter) and the road's first stop is "done" | Any time | trace-report class: `01 intro ... done`, completed list known |
| C2 | Which curated IDs QuestieDB's in-game view lacks, and whether the newer IDs (78088-78093, 9xxxx) are there | Any time | trace-report class: "not in QuestieDB" list and the newer-ID count |
| C3 | Whether the in-game corrections link the chains ordered by level (A Strange Artifact; Horde: Diplomatic Incident, Moonsilver Blade) | Any time (Horde ones on Thragor only if he's a Paladin) | trace-report class: "order inferred" lines with pre/next |
| C4 | Whether the game flags repeatable-flagged chain quests as completed (1641 Tome of Divinity start, 1442 Kor Gem, 1655 Bailor's Ore) | Gideon doing the Tome of Divinity (12) and Tome of Valor (20) | `/azf debug class 1641 1442 1655`: completed=true after turning them in. If so they could count |
| C5 | Skyborne race ID and race bit, so Skyborne intros can show | A Skyborne character logs in | `/azf debug class`: raceID, raceFile, raceBit (nil today) |
| C6 | Whether a Warlock can do both Succubus routes or only one | A Warlock at 20 | Either way one route finishes the stop; note it in docs/research/class-quests.md |

## Celebrations (Phase 10)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| C1 | A real category completion plays its celebration (so far only previews, `/azf debug celebrate`) | The last area, last quest or last flight path of a zone | It plays over the window, or an alert shows when the window is closed and the celebration plays on the next open |
| C2 | A real zone claim plays the claim | Every category of a zone done | Same |

## Quests (Phase 9)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| Q1 | Quest difficulty colours match the game's quest log (Azerfolio uses the client's `GetQuestGreenRange` when it exists, else the classic table) | Any time, best at several levels | Compare a zone's Ready now chip colours with the same quests in the quest log or Questie's tracker |
| Q2 | Skyborne race bits in QuestieDB's race masks (2^32 Alliance, 2^33 Horde) map to a Skyborne character's quests correctly | A Skyborne character | `/azf debug quests`, then compare the zone's quest list with Questie on that character |

## Performance

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| P1 | Which work caused the 39.5 ms peak frame seen in Phase 8 (window open, a page build, or shots) | Any session with debug on | `/azf debug perf`, `/reload`, `luajit tools/trace-report.lua perf` |

## Done

- 2026-11-09: T1, X on a met faction (Stormwind) puts it on the experience bar via `C_Reputation.SetWatchedFactionByID` (owner, in game: "Watching worked" after the set-and-clear steps; no trace saved, as there was no `/reload` after).
- 2026-11-08: both characters get the same zone factions and standing, and the other side's factions are hidden (Phase 11 task 5, `docs/research/reputation.md`).
