# Open in-game checks

Things built and tested offline that only real play can confirm. Most need a moment you can't set up on demand: a first-time faction, a level-60 character, the last area of a zone. Revisit them while playing; nothing here blocks using the addon.

**How to use this list:**
- Playing: when one of these moments comes up, note it (or take `/azf shot`) and tell the agent. Most need debug mode on (`/azf debug`) so the trace records it, then `/reload`.
- Agents: when a check can't be done now, add it here (ID, what, when it comes up, how to check, where the result goes). When one is confirmed, move it to "Done" with the date and evidence, and update the doc it came from.

## Reputation (Phase 11)

Phase 11 (v1.3) stays open until R1 and R2 are done: its "done when" asks for game-confirmed standing on both characters.

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| R1 | A met zone faction shows the same reaction and numbers as the game's Reputation window | The first quest that raises a zone faction. Neither character has one near home (checked 2026-11-14; owner chose to wait for Thragor). Thragor from level 9: "Wharfmaster Dizzywig" (1492, Horde, +50 Ratchet, Crossroads to Ratchet) or Gazlowe's "Southsea Freebooters" (887, +75, then 890/892). Every other low zone faction quest needs level 23+, except Zephras Isle's Nightclaw Druids (req 8), if a non-Skyborn can get there | Before turning in: `/azf debug reputation 1413 1492` (or `887`). After: open The Barrens in Azerfolio and the game's Reputation window (U), `/azf shot` each. The ledger line should drop "Not met yet" and the bar should show full colour in Azerfolio and the game's Reputation window (U), `/azf shot` each. The ledger line should drop "Not met yet" and the bar should show full colour |
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
| J9 | Start here and givers for other races (Phase 15 step 5): a lead-in row merges the versions of one breadcrumb with your home's giver first, other routes' and races' lead-ins are left out, and a quest with several givers names one friendly to your side (`qdb.lua class starts` lists the cases: Torwa Pathfinder gave Thunder Bluff to Alliance druids, A Simple Request Stormwind to Horde rogues, a Human warrior's Dun Morogh and Teldrassil stance starts) | A character of another race or class (Thragor checks the Horde Warrior side) | `/azf debug class`, `/reload`, `trace-report.lua class`: the "givers" lines; `/azf shots class` for the Start here rows |
| J8 | The other 16 roads look right in game: the strip, the road along its lane, stops by their landmarks, the class coin, milestones once the trainer is opened (seen so far: Paladin Alliance on Gideon, Warrior Horde on Thragor; the rest only in the mockup's Road switch and the tests). Druid Horde's first panel was repainted at Phase 15 step 10 (the poison stop is a savanna outpost, not a bog): check that stop sits by the outpost | A character of another class and side | `/reload`, wait a few seconds, `/azf shots class`; open the class trainer once first for the milestones |

## Professions (Phase 14)

| ID | Check | When | How |
|---|---|---|---|
| G1 | The skill each gathering node needs on Forever, where the guides disagree (Bruiseweed 85 or 100, Small Thorium 245 or 250, Rich Thorium 275 or 295) and for Forever's new nodes (Heavy Thorium, Marefoil, Demonsage, Death Lotus...); also whether a node stops giving skill 100 points past its requirement (`greyAfter`, a Classic rule) | Mousing over such a node or herb; gathering a node well past its skill | `/azf shot` of its tooltip ("Requires Mining (n)"); update `Data/Gathering.lua` and `docs/research/professions.md` § Gathering table |
| G2 | A learned recipe's tooltip says "Already known" (vendor and bag), so known state can be read for recipe items too | Any vendor recipe or recipe item you already know | `/azfdiag profs` with the vendor open or the item in your bags, `/reload`, `luajit tools/diag-report.lua profs` |
| G5 | A recipe's skill-up colour (Recipes view) follows a skill-up without opening the profession window (yellow turns green at the game's threshold) | When a skill-up moves a known recipe across a colour | Before: note a recipe's colour in Recipes; gain skill with the window shut; check the colour again (the game's window shows the truth) |
| G4 | A Horde character's trainers and gathering zones come Horde-first (trainers of your side, nearest first; Durotar before Elwynn) | When Thragor (or another Horde character) has a profession | `/azf shots professions` on that character, then read the Journey's Next up line and the Gather view |

## Exploration zone map (Phase 15 step 6)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| X1 | A partly explored zone: the lit pieces sit where the discovered areas are, the rest under fog (seen so far only on Elwynn, fully explored, and Alterac, 0/15) | Any time: Westfall (3/14 on Gideon) | Open Westfall's Exploration page and take `/azf shot`; compare with the game's world map (M) |
| X2 | A new area's piece appears on the map without `/reload` | Discovering a new area with the Exploration page open, or opening it right after | `/azf shot` before and after |

## A living Atlas (Phase 15 step 7)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| A1 | A claimed zone's tile shows the painted standard in its top-right corner (Atlas 16×32, Overview thumbnail 9×18), full colour and the gold edge, no "Claimed" word; Thragor's is the Horde cloth (Gideon has no claimed zone yet) | The first zone claimed on any character | `/azf shots` (zones, atlas; overview), then read the tile |

## Faction crests (Phase 15 step 8)

IDs F1/F2 (renamed from C1/C2 at the Phase 15 close: the Phase 10 celebrations below use C1/C2).

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| F1 | The Horde capitals' crests (Orgrimmar 76, Thunder Bluff 81, Undercity 68, Darkspear Trolls 530) show on Thragor's Reputation tab, faction pages and ledgers; Gideon only shows the Alliance four and the neutrals | Next time Thragor is played | On Thragor: `/azf shots reputation`, then read the Home rows and a capital's page |
| F2 | A met neutral faction's crest in full colour (Steamwheedle, Argent Dawn, Cenarion Circle, Timbermaw); so far every neutral is greyed (not met yet) | The first neutral faction met | `/azf shots reputation`, then read its row and page |

## Celebrations (Phase 10)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| C1 | A real category completion plays its celebration (so far only previews, `/azf debug celebrate`) | The last area, last quest or last flight path of a zone | It plays over the window, or an alert shows when the window is closed and the celebration plays on the next open |
| C2 | A real zone claim plays the claim | Every category of a zone done | Same |

## More celebrations and sound (Phase 15 step 9)

So far only previews (`/azf debug celebrate stop|road|rank|mastered|rep|exalted`, `/azf shots celebrations`).

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| K1 | A real class road stop walked plays its celebration (the class coin strikes gold) and the quest-complete chime, once | Turning in a stop's last quest (Gideon: The Tome of Divinity at 12) | It plays over the window, or the alert with the window closed; with `/azf debug`, the trace's `celebrate` entry (`trace-report.lua kind celebrate`) |
| K2 | A real profession rank trained plays "Journeyman <noun>" with the bronze coin: the cap read by `GetProfessionInfo` rises at the trainer while you play | Training Journeyman (Gideon's Mining or First Aid at 50) | Same |
| K3 | A real reputation rank-up shows the toast and the reputation chime, once; does the game itself also play a sound or show its own message for it (two sounds)? | The next reaction reached (Gideon: Stormwind Honored) | The toast under the header; listen; the trace's `celebrate` entry |
| K4 | Mastered and the road walked for real (a profession at 300, a class road finished) | Much later | Same as K1 |

## Quests (Phase 9)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| Q1 | Quest difficulty colours match the game's quest log (Azerfolio uses the client's `GetQuestGreenRange` when it exists, else the classic table) | Any time, best at several levels | Compare a zone's Ready now chip colours with the same quests in the quest log or Questie's tracker |
| Q2 | Skyborne race bits in QuestieDB's race masks (2^32 Alliance, 2^33 Horde) map to a Skyborne character's quests correctly | A Skyborne character | `/azf debug quests`, then compare the zone's quest list with Questie on that character |

## Dungeons research (2026-11-15)

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| D2 | Inside a dungeon: the current instance, whether the encounter journal fills there (outside it's empty, D1), its map encounters | Entering any dungeon | `/azfdiag dungeons`, wait for "second pass", `/reload`; `luajit tools/diag-report.lua dungeons inside` |
| D4 | Whether `C_TransmogCollection.PlayerHasTransmog` turns true for gear the character has owned (an honest "collected" state for loot) | Any time: add the item IDs of a few pieces Gideon wears or has sold to `DUNGEON_ITEM_IDS` in `AzerfolioDiag/Diag.lua` | `/azfdiag dungeons`, `/reload`, report `dungeons outside`: `hasTransmog {true}` for those items |
| D3 | Whether killing a boss fires `ENCOUNTER_END` / `BOSS_KILL` with an encounter ID that matches the journal, and whether a lockout appears | The first boss kill in a dungeon, with AzerfolioDiag enabled | After the run, `/azfdiag dungeons`, `/reload`; the report's event list and saved list |
| D5 | The dungeon build's first run after logging in stays near the 4 ms frame budget (Phase 16 task 3: once 14.8 ms on a cold login; 5.9-6.9 ms on later `/reload`s at item batch 500, now 250) | Any fresh login (not `/reload`) with debug on | Log in, wait 20 s, `/reload`; `luajit tools/trace-report.lua dungeons`: the latest build's max step and longest stretch per phase |
| D6 | A dungeon quest's turn-in marks it done without `/reload` (Systems/Dungeons reads Quests' completed list, `AZF_DUNGEONS_UPDATED` "quests") | Gideon's first dungeon quest turn-in (Deadmines' quests open at 14-15; he's 10) | After the turn-in, `/azf debug dungeons deadmines`, `/reload`; `trace-report.lua dungeons deadmines`: that quest `done` and the count up by one |
| D8 | A Dungeons card with every quest done shows the gold edge and ✓, and one with some done the orange edge; its bracket header counts it ("every quest done in 1 of n") (Phase 16 task 4; tested only with fixtures) | Gideon's first dungeon with all its quests done (the Deadmines' open at 14-15) | `/azf shots dungeons`; read the Cards shots |
| D7 | Horde quests and places (Ragefire Chasm and Shadowfang Keep say "none for your side" on Gideon) | Thragor, task 8 | On Thragor: `/azf debug dungeons ragefire`, `/reload`; `trace-report.lua dungeons ragefire`: quests counted, givers in Orgrimmar |
| D9 | The page's quests seal (`cel-seal-quests`, tilted with `SetRotation`) beside the score, and To do / Done with real counts, once an instance has every quest done (Phase 16 task 5; tested only with fixtures) | Gideon's first dungeon with all its quests done | Open its page; `/azf shots dungeons` or `/azf shot` |
| D11 | On the Road, a medallion with every quest done wears the gold ring (`medallion-ring-gold`) with ✓ and the gold glow; one with some done the orange glow; the gold progress runs the painted road (stamps turned with `SetRotation`) as far as You past several instances (Phase 16 task 6; at level 10 You sits before the first medallion, so the gold is a few px long) | Gideon's first dungeon with quests done, and a higher level | `/azf shots dungeons`; read the "road" shots |
| D12 | After the task 7 check: the instance page's banner button reads "Zone" / "Reputation" when opened from there, and a Zone Detail tile's quest line sits clear of frame A's bottom band (`dunTile.footY` 14) | Any time | `/azf shots links`; read the "dungeon opened from the zone" and "zone detail, the other capital" shots |
| D13 | A claimed zone's Zones card: full colour, the painted standard top right, gold "✓ 100%", gold edge (Phase 16 task 7; Gideon has no claimed zone yet, tested with fixtures) | Gideon's first claimed zone | `/azf shots links`; read the cards shots |
| D10 | Loot and keys repaint live: a dropped or bought item gets the "in your bags" check (and a key "Have") without `/reload` (`AZF_DUNGEONS_UPDATED` "bags") | Gideon picks up a boss item or a key (the Workshop Key for Gnomeregan) with the page open | Look at that boss's loot or the keys row; `/azf shot` |

## Performance

| ID | What to confirm | When it comes up | How to check |
|---|---|---|---|
| P1 | Which work caused the 39.5 ms peak frame seen in Phase 8 (window open, a page build, or shots) | Any session with debug on | `/azf debug perf`, `/reload`, `luajit tools/trace-report.lua perf` |

## Done

- 2026-11-15: D1, the client's dungeon APIs outside an instance (`/azfdiag dungeons`, two runs, Gideon in Elwynn): the encounter journal, entrances and map encounters are empty; the dungeon finder lists 28 classic dungeons and raids with one level each and placeholder bosses; `C_Item` gives quality, slot and counts; no lockouts saved. Details in `docs/research/dungeons.md`.
- 2026-11-14: K5, the celebration flashes animate on textures in this client: the Explored seal and the claim seal caught mid-flash, the class and profession coins gold after the strike (`/azf shots celebrations`, `WoWScrnShot_111426_224137`-`224201`).
- 2026-11-14: G3, the game tracks a recipe you haven't learned: `/azf debug professions track 3276` (Heavy Linen Bandage, not learned) put "Heavy Linen Bandage · Linen Cloth: 4/2" in the objective tracker (`WoWScrnShot_111426_115828`); the game reported tracked, then not tracked after the second call (trace-report professions). `SetRecipeTracked` needs three arguments here (recipeID, tracked, isRecraft).

- 2026-11-09: J1, a done class quest reads as done: Gideon's 3101 Consecrated Letter completed, the road's first stop "done", road 1/5, 1/37 quests, completed list known (`/azf debug class 3101 1641`, trace-report class, report #100).
- 2026-11-09: J2, all 653 curated quest IDs exist in QuestieDB's in-game view (corrections applied), 142 of them newer IDs (78xxx, 9xxxx). Same report.
- 2026-11-09: J3, the in-game corrections don't link A Strange Artifact either (78088-78093: no pre, no next), so its order stays inferred. Horde chains not checked (no Horde Paladin). Same report.

- 2026-11-09: T1, X on a met faction (Stormwind) puts it on the experience bar via `C_Reputation.SetWatchedFactionByID` (owner, in game: "Watching worked" after the set-and-clear steps; no trace saved, as there was no `/reload` after).
- 2026-11-08: both characters get the same zone factions and standing, and the other side's factions are hidden (Phase 11 task 5, `docs/research/reputation.md`).
