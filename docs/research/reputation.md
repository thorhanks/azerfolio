# Reputation (research, 2026-11-08)

Research for a reputation feature: per zone, the factions that matter there, with the character's standing. Owner's direction (2026-11-08): work on reputation next. Evidence levels as in plan §2.2.

## Zone → faction: from quest rewards

QuestieDB quests carry `reputationReward` (field 26, `{{factionID, amount}, ...}`). `luajit tools/qdb.lua reps [zone filter]` adds them up per Azerfolio zone, through our own `Data/QuestAreas.lua` [verified-files, base rows without corrections]. Each zone's quests clearly point to its own factions:

| Zone (uiMap) | Zone faction: quests |
|---|---|
| Felwood 1448 | Timbermaw Hold 576: 12 |
| Silithus 1451 | Cenarion Circle 609: 101; Brood of Nozdormu 910: 8 |
| Winterspring 1452 | Everlook 577: 18; Wintersaber Trainers 589: 3 |
| Desolace 1443 | Gelkis Clan Centaur 92: 12; Magram Clan Centaur 93: 11 (rivals) |
| Shen'dralas 2652 | Magram 93: 11; Gelkis 92: 8 |
| Searing Gorge 1427 | Thorium Brotherhood 59: 12 |
| Stranglethorn Vale 1434 | Booty Bay 21: 43; Bloodsail Buccaneers 87: 41 |
| Tanaris 1446 | Gadgetzan 369: 28; Brood of Nozdormu 910: 26 |
| The Barrens 1413 | Ratchet 470: 25 |
| W/E Plaguelands 1422/1423 | Argent Dawn 529: 36 / 65 |
| Moonglade 1450 | Cenarion Circle 609: 7 |
| The Hinterlands 1425, Wetlands 1437 | 471 (no name in QuestieDB's enum, and the game returns nothing for it): 10 / 6 |
| Zephras Isle 2521 | Windshapers 2778: 59; High Order 2779: 55; Nightclaw Druids 2758: 11 |
| Mulgore 1412 | Earthen Ring (Forever) 2787: 4; Windshapers 2778: 2 |
| Alterac Mountains 1416 | High Order 2779: 2; Kirin Tor (Forever) 2740: 2 |

- Every zone also rewards the capital factions (Stormwind 72, Ironforge 47, Orgrimmar 76, ...), so "zone faction" needs a rule. For example: leave out the player's racial and capital factions (the Alliance/Horde group), and keep factions where most of their quests come from this zone.
- Dungeons and raids have their own (Zul'Gurub → Zandalar Tribe 270: 81; Naxxramas → Argent Dawn: 77; Dire Maul → Shen'dralar 809: 14; Ahn'Qiraj → Brood 910 and Cenarion Circle).
- Forever's "Crafting" area 16941 (unmapped): Azeroth Commerce Authority 2586: 150 and Durotar Supply and Logistics 2587: 149, so these look like Forever's profession factions, one per side [inferred].
- Amounts are base values from QuestieDB. The game may add bonuses (Human diplomacy), so amounts must never be shown as exact.

## Client API (probe `/azfdiag reps`, Gideon, Elwynn, 2026-11-08) [verified-ingame]

Report: `luajit tools/diag-report.lua reps`. 0 errors.

- **Only the modern `C_Reputation` API exists.** The classic globals (`GetNumFactions`, `GetFactionInfo`, `GetFactionInfoByID`, `ExpandFactionHeader`, `GetWatchedFactionInfo`, ...) are all `nil`.
- `C_Reputation` has `GetNumFactions`, `GetFactionDataByIndex`, `GetFactionDataByID`, `Expand/CollapseFactionHeader`, `Expand/CollapseAllFactionHeaders`, `IsFactionActive`, `IsAccountWideReputation`, `GetWatchedFactionData`, plus retail paragon, major-faction and legacy functions. `C_GossipInfo.GetFriendshipReputation` exists.
- Faction data is a table: `name, factionID, reaction, currentStanding, currentReactionThreshold, nextReactionThreshold, isHeader, isHeaderWithRep, isChild, isCollapsed, isWatched, atWarWith, canToggleAtWar, canSetInactive, isAccountWide, hasBonusRepGain, description`.
- **Standing is absolute**: `currentStanding` runs from -42000 to 42000, and the thresholds bound the current reaction. Example: Stormwind reaction 5 (Friendly), standing 6600, thresholds 3000..9000, so 3,600 / 6,000 into Friendly. Progress = standing − currentThreshold, out of next − current.
- Reaction labels: `FACTION_STANDING_LABEL1..8` = Hated, Hostile, Unfriendly, Neutral, Friendly, Honored, Revered, Exalted.
- **The index list holds only the factions the character has met**: Gideon (level 9) has 5 entries, the Alliance header (with its own standing, 3312) plus Darnassus, Gnomeregan Exiles, Ironforge and Stormwind. Nothing was collapsed.
- **`GetFactionDataByID` also reads factions the character hasn't met**, with their starting standing: Booty Bay, Ratchet, Gadgetzan and Everlook at Neutral 500; Timbermaw Hold at Hostile −3500 (at war); Bloodsail at −6500; Gelkis and Magram at Neutral 2000 (at war). Forever's: Barkskin Burrow Hostile −3400 (at war), Cenarion Scouts 500, Powderfuse 2827 at 500, High Order, Nightclaw Druids, The Watchers, Guardians of Hyjal and Kirin Tor at 0, Brotherhood of the Horse at 1. 2798 is Darkspear Raiders and 2799 Theramore Expeditionary Force (the Darkspear Islands battleground sides).
- **No data for 14 IDs**: the Horde factions (67, 68, 76, 81, 530, 889), Forever factions likely on the Horde side (2587 Durotar Supply and Logistics, 2778 Windshapers, 2782 Bolderok Clan, 2787 Earthen Ring), and four neutral ones: 270 Zandalar Tribe, 471, 749 Hydraxian Waterlords, 910 Brood of Nozdormu. The Horde pattern suggests `GetFactionDataByID` returns nothing for the other side's factions [inferred]; why the four neutral ones are missing is [unverified] (check on Thragor, and on Gideon after meeting one).
- So "met" = in the index list, and "standing" = by ID. An unmet faction's standing is the game's own value, so it can be shown, but it should be marked as not met yet.
- Events: `UPDATE_FACTION` fires (5 times this session; 93 in the earlier sniffer run), as do `CHAT_MSG_COMBAT_FACTION_CHANGE` and `FACTION_STANDING_CHANGED` (sniffer, once each) [verified-ingame]. Reading every faction by ID on `UPDATE_FACTION`, debounced, is enough.
- Probe gap: header expansion used the classic globals, so it did nothing. Nothing was collapsed this time; a feature must use `C_Reputation.ExpandFactionHeader` (or read by ID only) and restore the player's collapsed headers.

## Zone-faction rule (decided 2026-11-08: derive from quests)

Owner's choice: derive from quest rewards, with no hand-curated table. Draft rule, checked offline with `luajit tools/qdb.lua reps rule` (base rows) [verified-files]:

- Count, per zone and faction, the quests that **raise** the faction (amount > 0). Bloodsail's 41 Stranglethorn quests are mostly losses, and only 3 raise it.
- Leave out **home factions** (capitals and races, the Alliance/Horde groups: 47, 54, 69, 72, 469, 67, 68, 76, 81, 530) and **battleground factions** (509, 510, 729, 730, 889, 890).
- Keep a faction when the zone has **≥ 5 raising quests**, or **≥ 3 when the zone holds ≥ 50%** of the faction's raising quests across all zones.
- Result: 21 zones with factions. Mulgore → Earthen Ring; Barrens → Ratchet; Arathi → Booty Bay; Tirisfal and both Plaguelands → Argent Dawn; Hinterlands and Wetlands → 471; Searing Gorge → Thorium Brotherhood; Stranglethorn → Booty Bay, Bloodsail; Thousand Needles and Stonetalon → Ratchet; Desolace and Shen'dralas → Gelkis, Magram; Feralas → Steamwheedle Cartel; Tanaris → Gadgetzan, Brood of Nozdormu; Felwood → Timbermaw Hold; Moonglade and Silithus → Cenarion Circle (Silithus also Brood); Winterspring → Everlook, Wintersaber Trainers; Zephras Isle → Windshapers, High Order, Nightclaw Druids.
- Dropped by the rule: Ratchet in Durotar and Desolace (4 quests, 8%), Brood of Nozdormu in Moonglade (3, 8%).
- The other 30 zones (most leveling zones and the capitals) get no zone faction.
- Repeatable quests count (the rule above includes them): without them Feralas (Steamwheedle 4 → 0) and Wintersaber Trainers (3 → 0) drop out, and Silithus' Cenarion Circle falls from 101 to 47. `luajit tools/qdb.lua reps check` runs Azerfolio's `Systems/ReputationRules.lua` on the same rows (0 mismatches, 21 zones) and on the runtime input (curated excluded quests left out: no change) [verified-files].
- At runtime: read `reputationReward` from QuestieDB's composed view for the zone's quests, then keep only factions the game returns data for (`GetFactionDataByID`). That drops the other side's factions, such as Windshapers for Gideon [inferred from the probe].

## In game (Systems/Reputation, Gideon, 2026-11-08) [verified-ingame]

- With QuestieDB's corrections (composed view), the rule gives **20 zones** and 19 factions, not the base rows' 21: Feralas loses Steamwheedle Cartel (base rows: quests 7003, 7721, 7725, 7726), and The Barrens gains Powderfuse 2827 (3 quests; base rows: 1, quest 97253) with Ratchet at 27 (base 25). Cause (task 4, `/azf debug reputation` + `trace-report.lua reputation`, Gideon) [verified-ingame]: the corrections give reputation rewards to two Forever Barrens quests that have none in the base rows, "Chol'aruk the Ravener" 97003 (Horde) and 97005 (Alliance): each raises Ratchet 150, Steamwheedle Cartel 169, Gadgetzan, Booty Bay, Everlook and Powderfuse by 75 (and its side's home factions). The Barrens thus gains two Powderfuse and two Ratchet quests (with 97253: 3 and 27). Steamwheedle Cartel's all-zones count goes from 7 to 9, so Feralas' 4 (7003, 7721, plus the repeatables 7725, 7726, read the same as the base rows) fall to 44%, under the rule's 50% share, and the faction drops. The Feralas quests themselves are unchanged. The 97003 and 97005 corrections also give fractional amounts (37.5, 2.5) for home factions.
- No data for 471, 910, 2778 and 2787, as in the probe; every zone faction is unmet for Gideon, with the probe's starting standings (Bloodsail Hated 35,500 / 36,000, Timbermaw Hostile 2,500 / 3,000 at war).

## Task 5: both characters (2026-11-08) [verified-ingame]

- Thragor (level 1 Orc, Durotar) and Gideon (level 10 Human): same rule result (20 zones, 19 factions) and the same standing for every shared zone faction (all at their starting standing, none met). Side-specific factions follow the side: Thragor reads 2778 and 2787, not 2779 or Wintersaber Trainers 589; Gideon the reverse. So the other side's factions drop out on their own.
- The game's Reputation window lists only each character's home factions (four each), so "Not met yet" on every zone faction agrees with it. A met zone faction's numbers against the window, and a refresh after a turn-in that raises a zone faction, are still unchecked: neither character has one yet.
- Thragor's ledger in Stranglethorn: the Horde standard, Booty Bay and Bloodsail as for Gideon, 86 quests counted for the Horde side.

## Reputation tab catalogue (Phase 12, offline, 2026-11-09) [verified-files]

`luajit tools/qdb.lua reps tab` runs `ReputationRules.Catalogue` and `GroupOf` over every quest with a reward (base rows, both sides): 51 factions raised by quests. Home 10 (the home factions and both side headers), Zones 21, Dungeons & raids 3 (Brood of Nozdormu: Ahn'Qiraj 52 against 34 in zones; Zandalar Tribe; Shen'dralar), Battlegrounds 8, Professions 7 (Azeroth Commerce Authority and Durotar Supply and Logistics from Forever's Crafting area 16941; five Leatherworking/Engineering factions 83, 86, 549, 550, 551 with 1-2 quests), Class and events 2 (Darkmoon Faire, Ravenholdt). Argent Dawn is Zones (107 zone quests against 92 in Naxxramas and dungeons), as the mockup had it. Quest sorts come from QuestieDB's `sortKeys` enum (`src/corrections/enum/quests.lua`). Factions no quest raises (Barkskin Burrow, Cenarion Scouts, ...) come only from the seed list and show as "No known quests".

## Open questions

1. *(Decided: derive from quest rewards, rule above.)*
2. *(Settled 2026-11-08: hidden.)* Faction 471 (Wetlands, Hinterlands): the game returns nothing for it on either side, so it never shows. What it is on Forever stays unknown.
3. *(Settled 2026-11-08 for now.)* Zandalar Tribe and Hydraxian Waterlords aren't zone factions under the rule, so they never come up. Brood of Nozdormu 910 (Silithus) returns nothing on either character at levels 1 and 10, so it's hidden; whether it reads at 60 can't be checked yet.
4. *(Settled 2026-11-08: one per side.)* Zephras Isle: Thragor reads 2778, Gideon 2779.
6. *(Decided 2026-11-08, owner: keep the rule.)* Feralas loses Steamwheedle Cartel to the in-game corrections (above). No hand-made exception: Feralas has no Reputation section.
5. *(Decided 2026-11-08: reputation stays out of combined zone completion. It has no "done" state below Exalted, so it's shown as progress beside the categories.)*
