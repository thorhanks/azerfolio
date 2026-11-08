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

**A, runtime optional dependency.** QuestieDB is already installed and enabled for Questie, so it costs nothing extra to load. It has a versioned public API built for other addons, and only the runtime view includes the Forever corrections, which matter for honest numbers. Build-time extraction would either lose the corrections or need an in-game dump plus a generator, and it would go stale.

Guards: everything behind `pcall`; a missing addon or a contract mismatch makes the quest category "unavailable" with the reason, never zero. Exploration never depends on it. For the area → zone mapping, use QuestieDB's support table when present, but check it against the client (`C_Map.GetAreaInfo` names) or keep our own small table for our 50 zones, since it's private.

**Before deciding, measure in game** (a probe in AzerfolioDiag): `LibQuestieDB` present, contract, read mode; the time and memory to read the needed fields for every quest; a sample of composed vs base values (do the corrections change zone or flags?); the race and class masks the client uses; and the areaID → uiMap table for our 50 zones.
