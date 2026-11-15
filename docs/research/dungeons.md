# Dungeons tab: data sources

Research for the Dungeons tab (started 2026-11-15). Evidence levels as in plan §2.2.

## Sources

- **No other addon at runtime.** ForeverDungeonJournal (no licence) is being uninstalled by the owner; it was read only to learn which client APIs exist. ItemTree is "All Rights Reserved". Neither is a source.
- **Hand-curated data** (like `Data/Zones.lua`) may be built from public online references (boss lists, levels, notable loot) where the client and QuestieDB fall short. Mark it unofficial, as with the level ranges.

## QuestieDB (offline, `luajit tools/qdb.lua drops [npcID...]`) [verified-files]

- Item rows carry `npcDrops` (field 2): 6,032 of 23,862 items have NPC drops, 663 weapons and 1,974 armour. About 530 weapons and armour drop from boss or rare-elite NPCs.
- Classic bosses look right (VanCleef 639: Cruel Barb, Cape of the Brotherhood, Blackened Defias Armor; Drakkisath 10363: tier-0 chests; Thaurissan 9019: Ironfoe, Hand of Justice). Forever's new dungeons are in (Hall of Thanes, Faldrim Anvilmar 261306: 3 items).
- No drop chances (only quest items have rates), no quality, no slot. Lists are noisy: Mutanus 3654 has 34 items, mostly trade goods and world-drop patterns. Needs filtering (weapons and armour, level near the boss) and quality and slot from the game.
- No "bosses of this dungeon" grouping: NPC rank 3 (boss) is set on some bosses only (VanCleef is rank 2, Thaurissan rank 1).
- Dungeon and raid quests are already indexed per instance area (`Data/QuestAreas.lua`, `docs/research/quest-data.md`).

## Client (to probe: `/azfdiag dungeons`, open checks D1-D3)

- Known [verified-ingame, 2026-11-08]: `C_EncounterJournal` exists; the Encounter Journal UI isn't loaded; no dungeon maps among map IDs 1-3000.
- Seen used by another addon [inferred-files]: `EJ_GetInstanceByIndex`, `EJ_SelectInstance`, `EJ_GetEncounterInfoByIndex`, `EJ_GetCreatureInfo` (boss portraits), events `ENCOUNTER_END`, `BOSS_KILL`, `LOOT_OPENED`. It keeps its own loot tables, which hints that journal loot may be empty on Forever.
- The probe records: every EJ global and the `C_EncounterJournal`, `C_RaidLocks`, `C_LFGInfo`, `C_Item`, `C_TransmogCollection` members; each tier, instance (with `dungeonAreaMapID` and its map info), encounter, creature and loot row (loot read again after 3 s); `GetLFGDungeonInfo` for IDs 1-3000 (level ranges); saved lockouts and their encounters; the current instance; item info and quality for five known drops. Dungeon events are logged with their arguments during play.

### First run, outside, Gideon in Elwynn (2026-11-15) [verified-ingame]

- **Encounter journal:** every `EJ_*` function the probe looks for exists except `EJ_GetLootInfo(ByIndex)`, `EJ_GetSectionInfo`, `EJ_GetCurrentInstance`. `C_EncounterJournal` has `GetLootInfoByIndex`, `InstanceHasLoot`, `IsEncounterComplete`, `GetDungeonEntrancesForMap`, `GetEncountersOnMap`, `GetInstanceForGameMap`. But `EJ_GetNumTiers` is 0, so the first probe scanned nothing. ForeverDungeonJournal scans with no tier selected in that case, and says Forever's new dungeons sit in their own tier. Probe round 2 does the same, then tries loading `Blizzard_EncounterJournal`.
- **Dungeon finder list (`GetLFGDungeonInfo`, IDs 1-3000):** 67 rows. 28 are dungeons and raids (odd IDs 1-49; typeID 0), with one level each (min = max = recommended: Deadmines 16, Wailing Caverns 17, Scholomance 57, raids 60). The other 39 are zones (type 4) and battlegrounds (type 5). **Forever's new dungeons aren't in it** (no Hall of Thanes or Ruins of Lordaeron), and Zul'Farrak is spelled "Zul'Farak". Bosses per row (`GetLFGDungeonEncounterInfo`) come in round 2.
- **Lockouts:** `GetNumSavedInstances` is 0 for Gideon (no lockouts yet), so the shape is unknown. `UPDATE_INSTANCE_INFO` and `INSTANCE_LOCK_STOP` fire on login and zoning, with no arguments.
- **Items:** the globals `GetItemInfo`, `GetItemCount` and `GetItemQualityColor` are gone. `C_Item` has them. `C_Item.GetItemQualityByID` works, and items not yet cached return nil first and a value after loading (Ironfoe nil → 4 epic, Hand of Justice nil → 3 rare; Cruel Barb and Hall of Thanes items 3). So quality comes from the game, not curated data. `C_TransmogCollection` exists: round 2 asks whether it knows collected appearances.
- `C_LootHistory` (group loot history) and `C_LFGInfo.GetLevelUpInstances` exist; round 2 reads them.

### Second run, outside (2026-11-15) [verified-ingame]

- **The encounter journal is empty outside instances.** Scanning with no tier selected gives 0 instances too. No errors were recorded: the calls run and return nothing. `C_AddOns.LoadAddOn("Blizzard_EncounterJournal")` fails with `WRONG_GAME_TYPE`. `GetDungeonEntrancesForMap`, `GetEncountersOnMap` and `GetInstanceForGameMap` return nothing for any of the client's maps (1-3000). Whether the journal fills inside a dungeon is check D2. Until then: **no boss lists, dungeon entrances or loot from the client.**
- **Dungeon-finder bosses are placeholders:** every dungeon row has one encounter, "No Longer in Use". The rows give only a name and one recommended level.
- **Items work through `C_Item`:** `C_Item.GetItemInfo` returns name, link, quality, item level, required level, type and subtype. `C_Item.GetItemInventoryTypeByID` gives the slot, and `C_Item.GetItemCount(id, true)` the count in bags and bank (0 for all five; Gideon owns none of them). So slot, quality and level come from the game and need no curated data.
- **Transmog data exists:** `C_TransmogCollection.GetItemInfo` returns an appearance and source ID for weapons and armour (Ironfoe 66536/160306, Cruel Barb 63793/158044), and nothing for jewellery (Hand of Justice, Ephemeral Choker). `PlayerHasTransmog` is false for all five, which is expected. Whether it turns true for items Gideon has owned is check D4; if it does, it's an honest "collected" state.
- `C_LootHistory.GetAllEncounterInfos` and `C_LFGInfo.GetLevelUpInstances` return empty tables.

### Where that leaves the data

| What | Source |
|---|---|
| Dungeon list, levels | Curated `Data/Dungeons.lua` (from online references, unofficial). The dungeon finder's 28 rows can cross-check the classic levels; Forever's new dungeons are curated only |
| Bosses | Curated: name and NPC ID per boss; the NPC IDs link to QuestieDB |
| Loot per boss | QuestieDB `npcDrops` for the boss's NPC ID, filtered to weapons and armour near the boss's level; quality, slot and level from `C_Item` |
| Quests | QuestieDB per instance area (`Data/QuestAreas.lua`) |
| Owned or collected | `C_Item.GetItemCount` (bags and bank now); transmog if D4 confirms it |
| Boss kills | Only live (`ENCOUNTER_END` / `BOSS_KILL`, D3) and lockouts while saved; no history before install |

## Open questions

- Does the journal list Forever's new dungeons, and does it give loot?
- Can a boss kill be confirmed after the fact (lockout encounter state), or only live (events)? Unknown stays unknown: no "bosses killed" count the game didn't confirm.
- What does "collected" mean for loot (in bags or bank via `GetItemCount`, equipped, ever looted)? Owner's call once the probe is in.
