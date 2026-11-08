-- Zone level ranges, curated by hand (plan §8 provenance: curated, unofficial).
-- The client gives none: C_Map.GetMapLevels returns 0,0,0,0 for every zone [verified-ingame,
-- /azfdiag zones]. The owner approved an unofficial zone guide (2026-11-07).
-- Source: https://warcraft.wiki.gg/wiki/Zones_by_level_(Classic), last edited 24 September 2026,
-- fetched 2026-11-07. Forever may differ from Classic; the UI labels these as a guide.
-- Forever-only zones the page doesn't list: ranges from the owner (2026-11-07), marked below.
-- Capitals have no entry and stay unknown. Keyed by mapID; names are comments only.
local _, ns = ...

ns.ZoneData = {
    source = "Warcraft Wiki, Zones by level (Classic); Forever-only zones from the owner",
    levels = {
        -- Eastern Kingdoms
        [1416] = { 30, 40 }, -- Alterac Mountains
        [1417] = { 30, 40 }, -- Arathi Highlands
        [1418] = { 35, 45 }, -- Badlands
        [1419] = { 45, 55 }, -- Blasted Lands
        [1428] = { 50, 58 }, -- Burning Steppes
        [1430] = { 55, 60 }, -- Deadwind Pass
        [1426] = { 1, 10 },  -- Dun Morogh
        [1431] = { 18, 30 }, -- Duskwood
        [1423] = { 53, 60 }, -- Eastern Plaguelands
        [1429] = { 1, 10 },  -- Elwynn Forest
        [1424] = { 20, 35 }, -- Hillsbrad Foothills
        [1432] = { 10, 20 }, -- Loch Modan
        [1433] = { 15, 25 }, -- Redridge Mountains
        [1427] = { 45, 50 }, -- Searing Gorge
        [1421] = { 10, 20 }, -- Silverpine Forest
        [1434] = { 30, 45 }, -- Stranglethorn Vale
        [1435] = { 35, 45 }, -- Swamp of Sorrows
        [1425] = { 40, 50 }, -- The Hinterlands
        [1420] = { 1, 10 },  -- Tirisfal Glades
        [1436] = { 10, 20 }, -- Westfall
        [1422] = { 51, 58 }, -- Western Plaguelands
        [1437] = { 20, 30 }, -- Wetlands
        -- Kalimdor
        [1440] = { 18, 30 }, -- Ashenvale
        [1447] = { 45, 55 }, -- Azshara
        [1439] = { 10, 20 }, -- Darkshore
        [1443] = { 30, 40 }, -- Desolace
        [1411] = { 1, 10 },  -- Durotar
        [1445] = { 35, 45 }, -- Dustwallow Marsh
        [1448] = { 48, 55 }, -- Felwood
        [1444] = { 40, 50 }, -- Feralas
        [1450] = { 55, 60 }, -- Moonglade
        [1412] = { 1, 10 },  -- Mulgore
        [1451] = { 55, 60 }, -- Silithus
        [1442] = { 15, 27 }, -- Stonetalon Mountains
        [1446] = { 40, 50 }, -- Tanaris
        [1438] = { 1, 10 },  -- Teldrassil
        [1413] = { 10, 25 }, -- The Barrens
        [1441] = { 25, 35 }, -- Thousand Needles
        [1449] = { 48, 55 }, -- Un'Goro Crater
        [1452] = { 53, 60 }, -- Winterspring
        -- Forever-only zones (owner, 2026-11-07)
        [2521] = { 1, 12 },  -- Zephras Isle: the Skyborn starting zone
        [2548] = { 35, 45 }, -- Riverglades
        [2652] = { 35, 45 }, -- Shen'dralas
        [2482] = { 60, 60 }, -- Mount Hyjal: a level 60 zone
    },
}
