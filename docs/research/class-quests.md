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

## Still to check in game

- **Forever's corrections:** do the in-game QuestieDB rows link the chains that the base rows don't (78088-78093, the Horde Paladin quests)? Needs a probe in `/azfdiag questdb` or `/azf debug`.
- **Are the newer-ID quests live** for Gideon (e.g. 78088 "A Strange Artifact")?
- **Completion read** of an already-done class quest for Gideon (e.g. 3101, Consecrated Letter), the same way Quests already does it.

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
