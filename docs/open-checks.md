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

## Overview round 3 (2026-11-13)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| O1 | The new Overview in the wide window. Confirmed 2026-11-13: Gideon (`WoWScrnShot_111326_200950`, `200956`; a smaller window `210844`: fits, the caption's Next line ellipsized, full text in the info line) and Thragor (`211156`: The Warrior's Road on the Horde strip, his portrait on the road, only Simple Parchment named, no trainer line while nothing can be trained) | Whenever the wide window is used | `/azf shots` with the window wide (the "overview" and "overview, class road" shots) |

## Class tab (Phase 13)

`/azf debug class [questID ...]` (debug on), `/reload`, then `luajit tools/trace-report.lua class`. J1-J3 are done (see Done); these wait on play. The tab is closed (2026-11-13); these don't reopen it.

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| J4 | Whether the game flags repeatable-flagged chain quests as completed (1641 Tome of Divinity start, 1442 Kor Gem, 1655 Bailor's Ore) | Gideon doing the Tome of Divinity (12) and Tome of Valor (20) | `/azf debug class 1641 1442 1655`: completed=true after turning them in. If so they could count |
| J5 | Skyborne race ID and race bit, so Skyborne intros can show | A Skyborne character logs in | `/azf debug class`: raceID, raceFile, raceBit (nil today) |
| J6 | Whether a Warlock can do both Succubus routes or only one | A Warlock at 20 | Either way one route finishes the stop; note it in docs/research/class-quests.md |
| J7 | Whether the newer-ID quests are offered in game (A Strange Artifact 78088 for Gideon) | Gideon at 22, in Ashenvale | Find the object and take the quest; QuestieDB having them (J2) doesn't prove the game does |
| J8 | The other 16 roads look right in game: the strip, the road along its lane, stops by their landmarks, the class coin, milestones once the trainer is opened (seen so far: Paladin Alliance on Gideon, Warrior Horde on Thragor; the rest only in the mockup's Road switch and the tests) | A character of another class and side | `/reload`, wait a few seconds, `/azf shots class`; open the class trainer once first for the milestones |

## Professions (research, 2026-11-13)

| ID | Check | When | How |
|---|---|---|---|
| G1 | The skill each gathering node needs on Forever, where the guides disagree (Bruiseweed 85 or 100, Small Thorium 245 or 250, Rich Thorium 275 or 295) and for Forever's new nodes (Heavy Thorium, Marefoil, Demonsage, Death Lotus...); also whether a node stops giving skill 100 points past its requirement (`greyAfter`, a Classic rule) | Mousing over such a node or herb; gathering a node well past its skill | `/azf shot` of its tooltip ("Requires Mining (n)"); update `Data/Gathering.lua` and `docs/research/professions.md` § Gathering table |
| G2 | A learned recipe's tooltip says "Already known" (vendor and bag), so known state can be read for recipe items too | Any vendor recipe or recipe item you already know | `/azfdiag profs` with the vendor open or the item in your bags, `/reload`, `luajit tools/diag-report.lua profs` |

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

- 2026-11-14: G3, the game tracks a recipe you haven't learned: `/azf debug professions track 3276` (Heavy Linen Bandage, not learned) put "Heavy Linen Bandage · Linen Cloth: 4/2" in the objective tracker (`WoWScrnShot_111426_115828`); the game reported tracked, then not tracked after the second call (trace-report professions). `SetRecipeTracked` needs three arguments here (recipeID, tracked, isRecraft).

- 2026-11-09: J1, a done class quest reads as done: Gideon's 3101 Consecrated Letter completed, the road's first stop "done", road 1/5, 1/37 quests, completed list known (`/azf debug class 3101 1641`, trace-report class, report #100).
- 2026-11-09: J2, all 653 curated quest IDs exist in QuestieDB's in-game view (corrections applied), 142 of them newer IDs (78xxx, 9xxxx). Same report.
- 2026-11-09: J3, the in-game corrections don't link A Strange Artifact either (78088-78093: no pre, no next), so its order stays inferred. Horde chains not checked (no Horde Paladin). Same report.

- 2026-11-09: T1, X on a met faction (Stormwind) puts it on the experience bar via `C_Reputation.SetWatchedFactionByID` (owner, in game: "Watching worked" after the set-and-clear steps; no trace saved, as there was no `/reload` after).
- 2026-11-08: both characters get the same zone factions and standing, and the other side's factions are hidden (Phase 11 task 5, `docs/research/reputation.md`).
