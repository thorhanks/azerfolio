# Quest data: QuestieDB (Phase 9, step 1)

Research for plan Phase 9 task 1: should Azerfolio read QuestieDB at runtime as an optional dependency, or extract its data at build time? Evidence levels as in plan §2.2.

## What is installed (2026-11-08)

- `Interface\AddOns\QuestieDB`, version 1.0.12, `## X-Flavor: Forever`, `## X-Mode: baked`, `## X-Contract-Version: 4` [verified-files]. Enabled on Gideon, together with Questie 12.6.4 and QuestieTrace (`AddOns.txt`) [verified-files]. Not load-on-demand.
- Licence GPL-3.0 (`LICENSE.md`).
- Two identical TOCs (`QuestieDB_Forever.toc`, `QuestieDB_Camelot.toc`), 15.5 MB each, 116,560 lines. Lua code: 58 files, 1.5 MB.

## How the data is stored

- **The entity data lives in the TOC's metadata**, not in Lua files: one `## X-<Entity>-<id>-<field>` line per value, base64. Counts of metadata lines: Quest 30,438, Npc 28,921, Item 38,389, Object 13,947, localization 4,781 [verified-files].
- Per quest: a scalar row `X-Quest-<id>-S` (CBOR map: field index → value, plus a presence bitmask `p` for table fields), and one line per table field (`X-Quest-<id>-<fieldIndex>`, CBOR). The ID list `X-Quest-IDS` is chunked and compressed (`C_EncodingUtil.DecompressString`) [verified-files, `src/read/baked.lua`].
- Reads are lazy: `C_AddOns.GetAddOnMetadata` and then `C_EncodingUtil.DecodeBase64` / `DeserializeCBOR`, both native, run only for the quests and fields asked for. Only the ID list is decoded at load [verified-files].
- **Corrections are applied at runtime.** `src/corrections/Forever/foreverQuestFixes.lua` (32 KB) and the classic fixes are composed over the baked rows when the addon loads (`ApplyRegisteredCorrections`). The baked TOC rows alone are the *uncorrected* base data [verified-files, `src/api.lua`].

## Public API (contract 4)

- Global `LibQuestieDB` (plus `QuestDB`, `NpcDB`, `ItemDB`, `ObjectDB`).
- `LibQuestieDB.RequireContract(n)` → `ok, message`: range check against `contractVersion` / `minSupportedContract`, made for consumers like us.
- `QuestDB.GetAllIds()`, `QuestDB.Exists(id)`, `QuestDB.Get(id, field)`, `QuestDB.GetAll(id, fields)`, and one function per field (`QuestDB.name(id)`, `QuestDB.zoneOrSort(id)`, ...). Values are the corrected, composed view.
- Quest fields (36, `src/meta/questMeta.lua`), the ones Azerfolio needs: `name`, `questLevel`, `requiredLevel`, `requiredMaxLevel`, `requiredRaces`, `requiredClasses`, `zoneOrSort` (positive AreaTable ID, or negative quest-sort ID), `startedBy`, `preQuestGroup` / `preQuestSingle`, `exclusiveTo`, `nextQuestInChain`, `specialFlags` (repeatable and event flags), `requiredSkill`, `requiredMinRep` / `requiredMaxRep`, `breadcrumbForQuestId`, `availableUntilCompleted`.
- Zone mapping: `LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId` (a Lua source string, `return { [areaID] = uiMapID, ... }`, plus an override string). It maps e.g. 12 → 1429 Elwynn Forest, 40 → 1436 Westfall, 16593 → 2521 Zephras Isle, 16651 → 2652 Shen'dralas [verified-files]. It is under `private`, so it isn't part of the contract.

## Survey of the base data (offline decode of the scalar rows)

A throwaway LuaJIT script decoded every `X-Quest-<id>-S` row (base, without corrections) [verified-files]:

- **5,233 quests**, 0 decode errors.
- `zoneOrSort`: 3,910 positive (an area), 1,258 negative (a quest sort: class, profession, holiday...), 65 missing. 100 distinct areas.
- Areas include battlegrounds and raids (Alterac Valley 2597: 86, Warsong Gulch 3277: 62, Arathi Basin 3358: 60, Naxxramas 3456: 91, Ahn'Qiraj 3428: 79) and 16941 (`CRAFTING` in `enum/zones.lua`, 150 quests), so they need filtering out of zone counts.
- 739 quests have the repeatable bit in `specialFlags`, so they're left out of totals (spec §7.3).
- `requiredRaces` values go beyond the classic bits (quest 2: 8589934770), so Forever's race bitmask needs checking against the client's races before we judge eligibility [unverified].
- `requiredClasses` is set on 989 quests, `requiredLevel` on nearly all, `nextQuestInChain` on 2,055.
- Darkspear Islands (uiMap 2524, area 16606, 18 quests) is in QuestieDB's map but not in Azerfolio's zone list. Worth checking whether `Systems/Maps` misses a zone.

## In-game probe (2026-11-08, Gideon in Elwynn Forest)

`/azfdiag questdb`, file written 09:31:58; report `luajit tools/diag-report.lua questdb areas`. All seven stages ran, 0 errors [verified-ingame].

- **API:** `LibQuestieDB` loaded (Questie loaded too), version 1.0.12, flavor Forever, read mode baked, contract 4 (min 1); `RequireContract(4)` returns true. `C_EncodingUtil` and `debugprofilestop` exist [verified-ingame].
- **Cost of a full read** (5,233 quests; QuestieDB's cache was already warm from Questie for some quests, so these numbers are a lower bound):

  | Pass | Reads | Time | QuestieDB memory |
  |---|---|---|---|
  | `GetAllIds` | 1 | 0.00 ms | - |
  | 13 scalar fields | 68,029 | 36.0 ms (again: 27.2 ms) | +0.9 MB (37.1 → 38.1 MB) |
  | 7 table fields | 36,631 | 54.5 ms | +3.8 MB (→ 41.8 MB) |
  | composed vs base, 8 fields | 83,728 | 146 ms | - |

  So a per-zone index from the scalar fields costs about 36 ms once, split across frames (about 500 quests per frame ≈ 3.5 ms), and under 1 MB, held by QuestieDB's cache rather than Azerfolio. Table fields (prerequisites, exclusive groups, starters) should be read only for the zone being shown. For scale, the whole Lua heap is 363 MB, and QuestieDB alone 37 MB before the probe.
- **Corrections matter:** the composed view differs from the base rows in `zoneOrSort` for 43 quests (all moved to Stormwind City 1519, from 0 or -284). No other compared field changed. A build-time extraction from the TOC would have put these 43 quests in no zone [verified-ingame].
- **Completion coverage:** Gideon has 85 completed quests (`GetAllCompletedQuestIDs`); QuestieDB knows 83 of them. 98289 and 99582 aren't in it.
- **Zones:** of 100 quest areas, 67 map to a zone map (subzones to their parent: Northshire Valley 9 → Elwynn 1429, Coldridge Valley → Dun Morogh, Valley of Trials → Durotar). Capitals have quests (Stormwind 131, Orgrimmar 92, Ironforge 84). QuestieDB maps some dungeons onto their outdoor zone (Gnomeregan 27 → Dun Morogh, Zul'Farrak → Tanaris, Uldaman → Badlands, Razorfen Kraul → The Barrens). The other dungeons and raids map to maps the client doesn't have, or to none. Battlegrounds map to type 6 maps. Not mapped: Blackrock Mountain (15), Sunken Temple (9), City of Dalaran (8), Ruins of Lordaeron (13), **Excavation Site: Wetlands (14)**, The Hall of Thanes (3), Crafting 16941 (150).
- **Darkspear Islands** (uiMap 2524, 18 quests) is map type 6, not 3. That's why `Systems/Maps` (zone maps only) doesn't list it. Same for Alterac Valley, Warsong Gulch and Arathi Basin.
- **Quest sorts:** 1,258 quests in 30 negative sorts (class, profession, holiday, ...); 27 have no zone or sort.
- **Repeatable:** 739 (`specialFlags` bit 1).
- **Races:** QuestieDB race bit = 2^(raceID - 1) for the classic races (HUMAN 1, ORC 2, DWARF 4, NIGHT_ELF 8, UNDEAD 16, TAUREN 32, GNOME 64, TROLL 128, GOBLIN 256), plus `SKYBORNE_ALLIANCE` = 2^32 and `SKYBORNE_HORDE` = 2^33; `ALL_ALLIANCE` = 4294967373, `ALL_HORDE` = 8589934770. Gideon is race 1 (Human). The client's `C_CreatureInfo.GetRaceInfo` lists races 1-37, and none of them is Skyborne, so the Skyborne race ID and how it maps to those two bits are [unverified] (a Skyborne character would be needed). Masks above 2^31 need care in Lua 5.1 (no `bit` on doubles above 32 bits; use arithmetic).
- **Classes:** class bit = 2^(classID - 1) (WARRIOR 1, PALADIN 2, HUNTER 4, ROGUE 8, PRIEST 16, SHAMAN 64, MAGE 128, WARLOCK 256, DRUID 1024); the client lists the 9 classic classes; Gideon is class 2 (Paladin) [verified-ingame].
- Probe bug: the samples came from Northshire Abbey (area 24, 1 quest) instead of Elwynn Forest (area 12), because it picked any area mapped to the current map. Not worth a re-run.

## Options

| | A. Runtime, optional dependency | B. Build-time extraction |
|---|---|---|
| How | `## OptionalDeps: QuestieDB`; at login check `LibQuestieDB` and `RequireContract(4)`; read `QuestDB` fields | A tool decodes the data into `Azerfolio/Data/Quests.lua` |
| Corrections | Included (composed view) | **Missing** if decoded from the TOC; to keep them we'd dump the composed view from the game (AzerfolioDiag) and generate from that |
| Freshness | Follows every QuestieDB update | Stale until regenerated |
| Without QuestieDB | Quests show "unavailable: needs QuestieDB"; exploration unaffected | Works standalone |
| Repo / addon size | Nothing added | A large generated file (GPL data) in the repo, loaded into memory at login |
| Cost | Lazy, native decode; we read about 10 scalar fields × ~5,200 quests once to build a per-zone index (time to measure in game) | Plain Lua tables; load time and memory for the whole set |
| Risk | Contract changes (versioned, range-checked); `areaIdToUiMapId` is private | Decoder and generator to maintain; must match the corrections by hand |

## Recommendation

**Decided 2026-11-08 (owner approved): A, runtime optional dependency.** QuestieDB is already installed and enabled for Questie, so it costs nothing extra to load. It has a versioned public API built for other addons, and only the runtime view includes the Forever corrections, which matter for honest numbers. Build-time extraction would either lose the corrections or need an in-game dump plus a generator, and it would go stale.

Guards: everything behind `pcall`; a missing addon or a contract mismatch makes the quest category "unavailable" with the reason, never zero. Exploration never depends on it. For the area → zone mapping, use QuestieDB's support table when present, but check it against the client (`C_Map.GetAreaInfo` names) or keep our own small table for our 50 zones, since it's private.

**The probe confirms it:** the API works under contract 4, the corrections change which zone 43 quests count in, and a full scalar read costs about 36 ms once (spread over frames) and under 1 MB.

Open questions for the quest model (later Phase 9 steps, owner's call):
1. Do dungeon quests that QuestieDB maps onto an outdoor zone (Gnomeregan, Zul'Farrak, Uldaman, Razorfen Kraul) count in that zone?
2. Do capitals get a quest section? They have many quests but no exploration.
3. What happens to the quests in unmapped areas, for example "Excavation Site: Wetlands" (14), which looks like part of Wetlands? Options: a small hand-curated area → zone table of our own, or leave them out with a coverage note.
4. Class, profession and holiday quests (negative sorts) have no zone. Leave them out of zone counts, with a coverage note?
5. Darkspear Islands (map type 6) has 18 quests and isn't in Azerfolio's zone list. Add it?
