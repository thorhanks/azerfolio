-- Quest areas: what each QuestieDB quest area (`zoneOrSort` > 0, an AreaTable ID) is to
-- Azerfolio. Hand-curated and unofficial, owner-approved (2026-11-08, quest model in
-- docs/research/quest-data.md). Built from the in-game probe (/azfdiag questdb, 100 quest
-- areas, each with QuestieDB's area -> uiMap mapping and the client's map name and type)
-- [verified-ingame]; it doesn't read QuestieDB's private zone tables at runtime.
--
--   zone[areaID] = mapID       the area's quests count in that zone (subzones to their zone)
--   dungeon[areaID] = true     dungeon quests: not in zone counts; kept for a Dungeons tab later
--   raid[areaID] = true        raid quests: same
--   battleground[areaID] = true  battleground quests: left out
-- Any other area is "unmapped": left out of zone counts and counted for the coverage note.
-- Left unmapped on purpose (not clearly one zone): 25 Blackrock Mountain, 2257 Deeprun Tram,
-- 16544 City of Dalaran, 16611 Ruins of Lordaeron, 16919 The Hall of Thanes, 16941 Crafting.
local _, ns = ...

ns.QuestAreaData = {
    zone = {
        -- Eastern Kingdoms
        [1] = 1426,     -- Dun Morogh
        [77] = 1426,    -- Anvilmar
        [131] = 1426,   -- Kharanos
        [132] = 1426,   -- Coldridge Valley
        [3] = 1418,     -- Badlands
        [4] = 1419,     -- Blasted Lands
        [8] = 1435,     -- Swamp of Sorrows
        [9] = 1429,     -- Northshire Valley
        [12] = 1429,    -- Elwynn Forest
        [24] = 1429,    -- Northshire Abbey
        [10] = 1431,    -- Duskwood
        [11] = 1437,    -- Wetlands
        [16732] = 1437, -- Excavation Site: Wetlands (no map in QuestieDB; curated)
        [28] = 1422,    -- Western Plaguelands
        [33] = 1434,    -- Stranglethorn Vale
        [36] = 1416,    -- Alterac Mountains
        [38] = 1432,    -- Loch Modan
        [146] = 1432,   -- Stonewrought Dam
        [40] = 1436,    -- Westfall
        [44] = 1433,    -- Redridge Mountains
        [45] = 1417,    -- Arathi Highlands
        [46] = 1428,    -- Burning Steppes
        [47] = 1425,    -- The Hinterlands
        [51] = 1427,    -- Searing Gorge
        [85] = 1420,    -- Tirisfal Glades
        [154] = 1420,   -- Deathknell
        [130] = 1421,   -- Silverpine Forest
        [139] = 1423,   -- Eastern Plaguelands
        [267] = 1424,   -- Hillsbrad Foothills
        [16591] = 2548, -- Riverglades
        [1497] = 1458,  -- Undercity
        [1519] = 1453,  -- Stormwind City
        [1537] = 1455,  -- Ironforge
        -- Kalimdor
        [14] = 1411,    -- Durotar
        [363] = 1411,   -- Valley of Trials
        [15] = 1445,    -- Dustwallow Marsh
        [2079] = 1445,  -- Alcaz Island
        [16] = 1447,    -- Azshara
        [17] = 1413,    -- The Barrens
        [141] = 1438,   -- Teldrassil
        [188] = 1438,   -- Shadowglen
        [702] = 1438,   -- Rut'theran Village
        [148] = 1439,   -- Darkshore
        [215] = 1412,   -- Mulgore
        [220] = 1412,   -- Red Cloud Mesa
        [221] = 1412,   -- Camp Narache
        [331] = 1440,   -- Ashenvale
        [357] = 1444,   -- Feralas
        [1116] = 1444,  -- Feathermoon Stronghold
        [361] = 1448,   -- Felwood
        [1769] = 1448,  -- Timbermaw Hold
        [400] = 1441,   -- Thousand Needles
        [405] = 1443,   -- Desolace
        [406] = 1442,   -- Stonetalon Mountains
        [440] = 1446,   -- Tanaris
        [490] = 1449,   -- Un'Goro Crater
        [493] = 1450,   -- Moonglade
        [618] = 1452,   -- Winterspring
        [1377] = 1451,  -- Silithus
        [16651] = 2652, -- Shen'dralas
        [1637] = 1454,  -- Orgrimmar
        [1638] = 1456,  -- Thunder Bluff
        [1657] = 1457,  -- Darnassus
        -- Other places
        [16593] = 2521, -- Zephras Isle
    },
    dungeon = {
        [133] = true,   -- Gnomeregan (QuestieDB maps it onto Dun Morogh)
        [209] = true,   -- Shadowfang Keep
        [717] = true,   -- The Stockade
        [718] = true,   -- Wailing Caverns
        [719] = true,   -- Blackfathom Deeps
        [722] = true,   -- Razorfen Downs
        [796] = true,   -- Scarlet Monastery
        [978] = true,   -- Zul'Farrak (QuestieDB maps it onto Tanaris)
        [1417] = true,  -- Sunken Temple
        [1517] = true,  -- Uldaman (QuestieDB maps it onto Badlands)
        [1581] = true,  -- The Deadmines
        [1583] = true,  -- Blackrock Spire
        [1584] = true,  -- Blackrock Depths
        [1717] = true,  -- Razorfen Kraul (QuestieDB maps it onto The Barrens)
        [2017] = true,  -- Stratholme
        [2057] = true,  -- Scholomance
        [2100] = true,  -- Maraudon
        [2437] = true,  -- Ragefire Chasm
        [2557] = true,  -- Dire Maul
    },
    raid = {
        [1977] = true,  -- Zul'Gurub
        [2159] = true,  -- Onyxia's Lair
        [2677] = true,  -- Blackwing Lair
        [2717] = true,  -- Molten Core
        [3428] = true,  -- Ahn'Qiraj
        [3429] = true,  -- Ruins of Ahn'Qiraj
        [3456] = true,  -- Naxxramas
    },
    battleground = {
        [2597] = true,  -- Alterac Valley
        [3277] = true,  -- Warsong Gulch
        [3358] = true,  -- Arathi Basin
        [16606] = true, -- Darkspear Islands: a PvP battleground (map type 6, level-bracket PvP
                        -- quests per faction); left out, owner 2026-11-08
    },
}
