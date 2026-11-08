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
    factionSource = "Warcraft Wiki, each zone's (Classic) page",
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

    -- Faction territory, curated by hand (unofficial; owner-approved 2026-11-07). The client
    -- has none (no GetZonePVPInfo) [verified-ingame]. Source: each zone's warcraft.wiki.gg
    -- "<Zone> (Classic)" page (capitals: the plain page), infobox "PvP status", else
    -- "Affiliation" when it names a faction (Forsaken counted as Horde); fetched 2026-11-07.
    -- Only Alliance or Horde territory is ever hidden from the other faction ("Relevant to
    -- me"); Contested and zones without an entry are shown to both.
    -- Judgement calls, marked "Contested" instead of the wiki's Affiliation (which names who
    -- holds the zone, not PvP territory) because both factions quest there in Classic:
    -- Ashenvale (Affiliation: Alliance), The Hinterlands (Alliance), Dustwallow Marsh
    -- (Alliance), Swamp of Sorrows (Horde). Westfall: Affiliation "Independent", but the
    -- infobox notes "Alliance" in game, so Alliance. Thousand Needles: no field; the page's
    -- prose says contested. Forever-only zones (Zephras Isle, Riverglades, Shen'dralas,
    -- Mount Hyjal): no source, no entry.
    faction = {
        -- Eastern Kingdoms
        [1416] = "Contested", -- Alterac Mountains (Affiliation: Crushridge, Syndicate, ...)
        [1417] = "Contested", -- Arathi Highlands (Affiliation: Syndicate)
        [1418] = "Contested", -- Badlands (Affiliation: Dark Iron dwarf)
        [1419] = "Contested", -- Blasted Lands (Affiliation: The Burning Legion)
        [1428] = "Contested", -- Burning Steppes (Affiliation: Black dragonflight ...)
        [1430] = "Contested", -- Deadwind Pass (PvP status: Contested territory)
        [1426] = "Alliance",  -- Dun Morogh (Affiliation: Alliance)
        [1431] = "Alliance",  -- Duskwood (Affiliation: Alliance)
        [1423] = "Contested", -- Eastern Plaguelands (Affiliation: Argent Crusade, Scourge)
        [1429] = "Alliance",  -- Elwynn Forest (PvP status: Alliance territory)
        [1424] = "Contested", -- Hillsbrad Foothills (Affiliation: Contested)
        [1432] = "Alliance",  -- Loch Modan (Affiliation: Alliance)
        [1433] = "Alliance",  -- Redridge Mountains (Affiliation: Alliance)
        [1427] = "Contested", -- Searing Gorge (PvP status: Contested territory)
        [1421] = "Horde",     -- Silverpine Forest (Affiliation: Forsaken)
        [1434] = "Contested", -- Stranglethorn Vale (Affiliation: Independent)
        [1435] = "Contested", -- Swamp of Sorrows (Affiliation: Horde; judgement call, see above)
        [1425] = "Contested", -- The Hinterlands (Affiliation: Alliance; judgement call)
        [1420] = "Horde",     -- Tirisfal Glades (PvP status: Horde territory)
        [1436] = "Alliance",  -- Westfall (Affiliation: Independent, "Alliance" in game)
        [1422] = "Contested", -- Western Plaguelands (Affiliation: Scourge)
        [1437] = "Alliance",  -- Wetlands (Affiliation: Alliance)
        [1453] = "Alliance",  -- Stormwind City (PvP status: Alliance territory)
        [1455] = "Alliance",  -- Ironforge (PvP status: Alliance territory)
        [1458] = "Horde",     -- Undercity (PvP status: Horde territory)
        -- Kalimdor
        [1440] = "Contested", -- Ashenvale (Affiliation: Alliance; judgement call)
        [1447] = "Contested", -- Azshara (Affiliation: Contested)
        [1439] = "Alliance",  -- Darkshore (Affiliation: Alliance)
        [1443] = "Contested", -- Desolace (PvP status: Contested territory)
        [1411] = "Horde",     -- Durotar (Affiliation: Horde)
        [1445] = "Contested", -- Dustwallow Marsh (Affiliation: Alliance; judgement call)
        [1448] = "Contested", -- Felwood (Affiliation: Burning Legion)
        [1444] = "Contested", -- Feralas (Affiliation: Contested)
        [1450] = "Contested", -- Moonglade (PvP status: Contested territory)
        [1412] = "Horde",     -- Mulgore (Affiliation: Horde)
        [1451] = "Contested", -- Silithus (Affiliation: None)
        [1442] = "Contested", -- Stonetalon Mountains (Affiliation: Contested)
        [1446] = "Contested", -- Tanaris (PvP status: Contested territory)
        [1438] = "Alliance",  -- Teldrassil (Affiliation: Alliance)
        [1413] = "Contested", -- The Barrens (PvP status: Contested territory)
        [1441] = "Contested", -- Thousand Needles (no field; prose: contested)
        [1449] = "Contested", -- Un'Goro Crater (Affiliation: None)
        [1452] = "Contested", -- Winterspring (Affiliation: None)
        [1457] = "Alliance",  -- Darnassus (PvP status: Alliance territory)
        [1454] = "Horde",     -- Orgrimmar (PvP status: Horde territory)
        [1456] = "Horde",     -- Thunder Bluff (PvP status: Horde territory)
    },
}
