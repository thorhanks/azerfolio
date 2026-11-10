# Class quests (research, 2026-11-09)

Research for the Class tab. Owner's direction (2026-11-09): a class-themed journey map, a strip on the left with one node per class quest stop, the selected stop's details on the right, and a completion state at the end of the road. Evidence levels as in plan §2.2.

Tool: `luajit tools/qdb.lua class [name [race]]` (QuestieDB base rows, no corrections). Without arguments it prints counts per class; with a class it prints that class's quests grouped into chains with their starters; with a race as well, only the quests that race can take.

## How many class quests there are

A quest counts as a class quest when `requiredClasses` (field 7) is set and isn't every class [verified-files]. Base rows:

| Class | All | Repeatable | 1-9 | 10-19 | 20-29 | 30-39 | 40-49 | 50-59 | 60 | Class sort | Core | Newer IDs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Warrior | 117 | 15 | 11 | 26 | 28 | 7 | 0 | 16 | 29 | -81 | 73 | 2 |
| Paladin | 134 | 23 | 14 | 39 | 23 | 0 | 3 | 12 | 43 | -141 | 86 | 36 |
| Hunter | 94 | 14 | 9 | 39 | 0 | 0 | 0 | 15 | 31 | -261 | 52 | 11 |
| Rogue | 102 | 15 | 10 | 30 | 21 | 0 | 0 | 15 | 26 | -162 | 62 | 10 |
| Priest | 127 | 14 | 18 | 41 | 22 | 0 | 0 | 15 | 31 | -262 | 85 | 18 |
| Shaman | 122 | 22 | 22 | 22 | 24 | 12 | 0 | 15 | 27 | -82 | 73 | 42 |
| Mage | 93 | 14 | 9 | 17 | 8 | 12 | 0 | 15 | 32 | -161 | 51 | 4 |
| Warlock | 144 | 15 | 11 | 10 | 24 | 32 | 5 | 18 | 44 | -61 | 101 | 1 |
| Druid | 97 | 14 | 5 | 38 | 10 | 0 | 0 | 15 | 29 | -263 | 55 | 17 |

Level means `requiredLevel`. "Core" means the one-time quests in the class's quest sort (`zoneOrSort`, e.g. -141 Paladin). "Newer IDs" are IDs from 78000 to 79999 or from 90000 up, beyond the 1.12 range. There are no Death Knight or Monk quests.

What the shape shows:
- **Class quests fill the whole road, but unevenly.** They are dense from 10 to 29, sparse from 30 to 49 (zero for most classes), and pick up again at 50-60. The 60 column is mostly raid gear, not a journey (see below).
- **The table counts every variant**, both sides and every race and trainer city. One character sees far fewer: a Human Paladin can take 89 (including raid gear), an Orc Warrior 75, a Dwarf Shaman 44, a Gnome Mage 72.

## Forever's changes [verified-files]

Forever reworks class quests, mostly at low levels:
- **New race/class pairs**, e.g. Horde Paladins (Tirisfal and Silverpine chains, 909xx-96xxx: "Rediscovering the Light", "A Lesson in Divinity", Lumina Windsinger's quests at 18-26) and Alliance Shamans (Dwarf: "Call of Earth" in Dun Morogh, "Call of Fire" from Ironforge into Loch Modan, 94xxx).
- **The Skyborne start**: Zephras Isle class intros at level 2 ("The Way of the Hunter", "A Student of Nature", "At Home in the Shadows", 9248x) and race-masked level-10 quests (masks 2^32 / 2^33).
- **Ability quests per trainer** at 10 ("Divine Grace", "Confounding Flash" for Priests: one quest per trainer city, all exclusive to each other).
- **New mid-level chains**: a Rogue chain in Alterac Mountains from 24 to 36 (9677x), and Season-of-Discovery-range IDs such as Paladin "A Strange Artifact" → "Return to Delgren" (78088-78093, 22/30) and Rogue "The Eye of Bhossca" (78676, 25/35). Whether these are live in Forever needs an in-game check.

## A Human Paladin's road (Gideon), base rows

The class-sort quests he can take, as stops:

| Stop | Req | Where it starts | Quests |
|---|---|---|---|
| Consecrated Letter | 1 | Marshal McBride, Elwynn Forest | 1 |
| The Tome of Divinity (Redemption) | 12 | Duthorian Rall, Stormwind (Brother Wilhelm, Elwynn, as an alternative) | ~9 |
| The Tome of Valor (Verigan's Fist) | 20 | Duthorian Rall, Stormwind → Westfall, Dun Morogh | ~7 |
| A Strange Artifact (newer ID) | 22 | an object in Ashenvale → Delgren the Purifier, Stormwind | 6 |
| The Tome of Nobility (warhorse) | 40 | Duthorian Rall, Stormwind (or Ironforge) | 1 of 3 |
| Dispelling Evil / Forging the Mightstone | 50 | Commander Ashlam Valorfist, Western Plaguelands | 4 |
| The Charger | 60 | Lord Grayson Shadowbreaker, Stormwind | ~12 |

That gives **7 stops** for the main road, which fits a map strip well. Besides that, 40-odd class-restricted quests are raid or dungeon gear (Zul'Gurub brands and Paragons, Ahn'Qiraj, Naxxramas Redemption, Dire Maul books, Quel'Serrar for Warriors and Paladins). They belong on the Dungeons tab, not on the road.

## What this means for the design

1. **The base data doesn't give clean chains.** The chain grouper (pre-quests, next in chain, exclusives, parent) makes 45 groups for a Human Paladin. Links are missing (78088-78093 come out as six separate quests), alternatives show up as separate quests (Tome of Divinity has a Human and a Dwarf version, plus a start per trainer city), and some starters are items or objects. Grouping by name and NPC wouldn't be reliable either.
   - **Proposal:** a hand-curated `Data/ClassJourneys.lua` (like `Data/Zones.lua`): per class, the ordered stops with their name, level, starter text and quest IDs, including per-race or per-side variants. Completion still comes only from the game, never from the file. A `qdb.lua class check` mode would test that file against QuestieDB (every ID exists, has the right class, and no core quest is missed).
2. **Honest completion.** A stop is done when all its required quests are flagged completed by the game, with exclusive alternatives counted as one. The road's total is the stops this character can take (race, side, class through `QuestRules`). Repeatables and turn-in variants never count. A stop with no data for this character is left off the road, never shown as 0.
3. **What counts toward "complete".** Two candidate rules: (a) the main road only, levels 1-60 through the class mount or epic (Charger, Dreadsteed, Rhok'delar…), with raid gear on the Dungeons tab; or (b) the road plus an "Epic" branch at 60. Decision for the owner.
4. **Stops per class** will be about 5-10 (estimated from the table; to be counted per class while curating). With 5 stops the strip has room for art, and with 10 it's still readable at 512×1024 if it scrolls.

## Curated journeys (2026-11-09)

`Azerfolio/Data/ClassJourneys.lua` holds the structure (stops, their quests in order, side paths, extras that don't count); `luajit tools/qdb.lua class check` tests it against the base rows. Race versions of a stop share its key, so the quest rules pick the one that suits the character (race masks separate them: 1641-1788 Human 1, 1645-1785 Dwarf 4) [verified-files].

All nine classes, both sides (`class check`: OK; every one-time class-sort quest is on a road, in an extra, or ignored with a reason). Stops count each key once; quests count race versions together and the longest route of a stop.

| Journey | Road stops (level) | Side paths | Quests | Class-sort quests |
|---|---|---|---|---|
| Warrior, A | intro 1, Defensive Stance 10 (4 routes: Stormwind, Ironforge, Darnassus, Zephras Isle), The Shieldsmith 20, The Affray 30 (Berserker Stance), Whirlwind Weapon 30, Voodoo Feathers 50 | 3 armour chains off the Shieldsmith | 30 | 46 |
| Warrior, H | intro, Defensive Stance 10 (Barrens, Tirisfal, Zephras), Trial at the Field of Giants 20, The Affray, Whirlwind Weapon, Voodoo Feathers | Brutal Gauntlets, Helm, Legguards | 28 | 39 |
| Paladin, A | letter/rune 1, Tome of Divinity 12, Tome of Valor 20, Tome of Nobility 40, the Charger 60 | A Strange Artifact 22, Forging the Mightstone 50 | 46 | 56 |
| Paladin, H (Forsaken) | A Difficult Path 1, Rediscovering the Light 2, Bandarion Keep 7, A Lesson in Divinity 12, Diplomatic Incident 18, The Moonsilver Blade 20 | A Second Home 8 | 30 | 30 |
| Hunter, A / H | intro, Taming the Beast 10 (routes per starting area), The Green Drake 50 | none | 12 / 20 | 30 / 27 |
| Rogue, A | intro, Thieves' Errand 10 (3 routes), Lockpicking Trial 16 (3 routes), The Touch of Zanzil 20, Ravenholdt 24, The Syndicate Sting 24 (Forever), The Azure Key 50 | The Eye of Bhossca 25 | 27 | 38 |
| Rogue, H | intro, The Shattered Hand / The Deathstalkers 10, Lockpicking Trial 16 (2 routes), Hinott's Assistance 20, Ravenholdt, The Syndicate Sting, The Azure Key | The Eye of Bhossca | 31 | 38 |
| Priest, A | intro, Garments 5, racial spell 10 (Desperate Prayer, Stars of Elune, Confounding Flash), Divine Grace 10 (Human, Forever), racial spell 20 (Fear Ward, Elune's Grace, Feedback, Contingency Plan), Blood of Morphaz 50, The Balance of Light and Shadow 60 | none | 20 | 57 |
| Priest, H | intro, Garments 5, Hex / Touch of Weakness 10, Shadowguard / Dark Sacrifice 20, Blood of Morphaz 50, Balance of Light and Shadow 60 | none | 13 | 28 |
| Shaman, A (Dwarf) | Archaic Rune 1, Call of Earth 4, Fire 10, Water 20, Air 30, The Tempest's Weapons 30 | none | 21 | 25 |
| Shaman, H | intro, Call of Earth 4, Fire 10, Water 20, Air 30 (each with Durotar / Mulgore / Zephras versions), The Tempest's Weapons 30, Da Voodoo 50, The Darkreaver Menace 58 | none | 30 | 49 |
| Mage, A / H | intro, First Errand 10 (routes), robe 15, robe 26, Mage's Wand 30, Celestial Power 35, Destroy Morphaz 50, Fragmented Magic 60 | none | 26 / 26 | 34 / 33 |
| Warlock, A / H | intro, First Lessons 1, Voidwalker 10, Succubus 20 (routes: the 1.12 chain or Classic Era's 655xx/656xx), Felhunter 30, Felsteed 40, Trolls of a Feather 50, Dreadsteed 60 | Orb of Soran'ruk, The Completed Robe, Orb of Orahil, Kroshius' Infernal Core, Suppression | 46 / 55 | 62 / 77 |
| Druid, A / H | intro, Bear Form 10 (Moonglade or Zephras Isle), Power over Poison 14, Aquatic Form 16, Cat Form 20 (routes), A Better Ingredient 50 | Child of Nature 10 (Skyborne) | 27 / 27 | 31 / 31 |

Format additions found while curating: **routes** (the stop is done when any one route is; for home-city chains whose race masks all suit the side, and the two Succubus paths), **raceMask** (the Skyborne intros, which QuestieDB opens to every race but which sit behind Zephras Isle's 92461), and **ignore** per class with a reason (Priest `<NYI>` placeholders 5691-5693 and 5704-5706, Mage 97286 behind 40 Season of Discovery quests and 7463 in Dire Maul, Hunter Rhok'delar 7632-7636 from a Molten Core drop). `class check` now also reports race versions that share a key and both suit one race: 62 such overlaps were found and turned into routes. One quest sits in the wrong sort: 92479 A Scribbled Letter (Human Hunter) is filed under the Warrior sort, so the check can't see it; it's on the Hunter road by hand.

Thin roads: the Hunter has only three stops (no class-sort quests between 10 and 50, and Rhok'delar is a raid quest), the Priest has no side paths.

Curating rules learned on the way:
- **Repeatable-flagged chain quests don't count.** QuestieDB flags some chain starters and sub-quests as repeatable (1641 and 1645, the Tome starts; 1442 Kor Gem and 1655 Bailor's Ore, 1654's child quests; 7645, 7643's child). The game may never flag those as completed, so they're `extra`: shown, not counted. Whether `IsQuestFlaggedCompleted` reports them is an in-game check.
- **Exclusive versions are one step**: `{ 1661, 4485, 4486 }` (the warhorse from any of three trainers), `{ 7638, 7670 }` (the Charger's start in Stormwind or Ironforge).
- **Breadcrumbs are extras** (2998/3681, 2997/2999/3000, 8415).
- **The Horde Paladin road has no level 40 or 60 stops**: QuestieDB has no such quests yet, though Warcraft Tavern says the Horde mount is a long chain. The road ends at The Moonsilver Blade until QuestieDB or the game shows more; nothing is invented.
- **Unlinked Forever chains** (Diplomatic Incident, The Moonsilver Blade, A Strange Artifact) are ordered by quest level and marked `order = "inferred"`.
- **Not class quests despite the mask**: 792 Vile Familiars (a Valley of Trials quest for several classes) and 8767 A Gently Shaken Gift (Winter Veil) sit outside the class sort, so the check doesn't ask for them.

## Checked in game (2026-11-09, Gideon, `/azf debug class`)

- A done class quest reads as done: 3101 completed, the first stop done; the other stops are "later", locked by level [verified-ingame].
- All 653 curated IDs exist in QuestieDB's in-game view, 142 of them newer IDs [verified-ingame]. That's QuestieDB, not proof the game offers them (open check J7).
- The corrections don't link 78088-78093 either; the order stays inferred [verified-ingame].

## Still to check in game

- **Forever's corrections:** do the in-game QuestieDB rows link the chains that the base rows don't (78088-78093, the Horde Paladin quests)? Needs a probe in `/azfdiag questdb` or `/azf debug`.
- **Are the newer-ID quests live** for Gideon (e.g. 78088 "A Strange Artifact")?
- **Completion read** of an already-done class quest for Gideon (e.g. 3101, Consecrated Letter), the same way Quests already does it.
- **Skyborne race:** the race ID and token, and whether its bits are 2^32 (Alliance) / 2^33 (Horde); `QuestRules.RaceBit` returns nil for it today, so `raceMask` stops can't be shown to a Skyborne character until then.
- **Succubus routes:** can a Warlock still take the 1.12 chain (1738) and the Classic Era one (65602) both, or only one? Either way the stop is done by one route.
- **Repeatable-flagged chain quests:** does the game report 1641 (the Tome of Divinity start) as completed once done? If so, it could count.

## Third-party guides (2026-11-09)

Forever guides for curating the journey file. These are web sources, so their facts are [unverified] until QuestieDB or the game agrees.
- Read: Warcraft Tavern [Skyborne Druid quests](https://www.warcrafttavern.com/forever/guides/skyborne-druid-quests/), [Dwarf Shaman totem quests](https://www.warcrafttavern.com/forever/guides/dwarf-shaman-totem-quests/), [Undead Paladin](https://www.warcrafttavern.com/forever/guides/undead-paladin/) (an overview: most Forsaken Paladin class quests are in Bandarion Keep, Tirisfal, and the level-60 mount is a long chain), [class trainers](https://www.warcrafttavern.com/forever/guides/class-trainers/) (class quests mostly come from the trainer at set levels), and the wiki's [Zephras Isle storyline](https://warcraft.wiki.gg/wiki/Zephras_Isle_storyline) (level-2 class intros: Druid, Hunter, Mage (Alliance), Rogue, Shaman (Horde), Warrior; none for Paladin, Priest or Warlock).
- Refused automated reading (HTTP 403): Icy Veins' Forever class quest guides ([paladin](https://www.icy-veins.com/wow-forever/paladin-class-quests), [priest](https://www.icy-veins.com/wow-forever/priest-class-quests)) and [Mobalytics](https://mobalytics.gg/wow-forever/quests). If the owner wants them used, they could save a page from their browser.
- Classic-era guides (Wowhead, Icy Veins Classic, Warcraft Tavern's Paladin epic mount guide) cover the unchanged 1.12 chains.

The guides agree with QuestieDB [verified-files]:
- **Dwarf Shaman:** Call of Earth at 4 (94373-94375, Earth Sapta 94472), Call of Fire at 10 (94449, 94465-94468: Bruegs Kindleborn, then Braldir Ashmantle in Loch Modan), Call of Water at 20 (94494-94505, a long trip through Wetlands, Redridge, Ashenvale and Westfall, about 2 hours), Call of Air at 30 (94789, Veyric in Arathi).
- **Skyborne Druid:** Bear Form at 10 (94006 The Great Ursera Spirit, 94638 Strength and Mercy) and Cat Form at 20 through Moonglade (98341, 98404, 98738 and the trainer quests).
- **Level-2 intros:** 92481 A Student of the Arcane, 92532 The Warrior's Path, and the others listed above.

Two things to watch for when curating:
- **Some class quests have no `requiredClasses`.** The Skyborne Cat Form steps (98341, 98404, 98738) and 96136 Call of Air (Horde Skyborne) have no class mask, so `qdb.lua class` misses them. Curating must start from the chains, not only from the class filter. These quests are class-only in practice because they're reached through the class chain.
- **Skyborne sides are race bits 2^32 and 2^33.** Alliance masks are 77 + 2^32 and Horde masks 178 + 2^33, so 2^32 is the Alliance Skyborne and 2^33 the Horde Skyborne [inferred]. `QuestRules.RaceBit` doesn't map them yet (race ID unknown), so a Skyborne character's road needs that settled in game.

## Owner decisions (2026-11-09)

1. **Main road only.** Raid and dungeon class quests (gear turn-ins, Quel'Serrar, Dire Maul books) aren't on the road; they're for the Dungeons tab.
2. **Optional side quests become side paths**: each one is a short spur that branches off the main road and ends in a dead end. The aim is to show as many stops and quests on the map as is reasonable.
3. **Hand-curated journey file is fine**, cross-checked with third-party guides on class quest chains as well as QuestieDB.
4. **One painted strip per class and side** (18), so the map matches the character. Size is fine: about 683 KB each (512×2048 DXT1 with mips), 12 MB at most for all of them.
