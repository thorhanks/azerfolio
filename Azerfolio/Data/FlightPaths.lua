-- Which zone each flight path belongs to (spec §8.5). The flight paths themselves come from the
-- client (C_TaxiMap.GetTaxiNodesForMap); a node's name is "Place, Zone" [verified-ingame,
-- /azfdiag taxi 2026-11-08], and the zone part is a short form ("Redridge", "Arathi") that
-- this table turns into a mapID. Hand-curated from the probe; unofficial.
local _, ns = ...

ns.FlightPathData = {
    -- Zone part of the node name -> mapID.
    zones = {
        ["Elwynn"] = 1429, ["Westfall"] = 1436, ["Redridge"] = 1433, ["Dun Morogh"] = 1426,
        ["Wetlands"] = 1437, ["Loch Modan"] = 1432, ["Silverpine Forest"] = 1421, ["Tirisfal"] = 1420,
        ["Duskwood"] = 1431, ["Hillsbrad"] = 1424, ["Arathi"] = 1417, ["Stranglethorn"] = 1434,
        ["Badlands"] = 1418, ["The Hinterlands"] = 1425, ["Blasted Lands"] = 1419,
        ["Swamp of Sorrows"] = 1435, ["Western Plaguelands"] = 1422, ["Eastern Plaguelands"] = 1423,
        ["Burning Steppes"] = 1428, ["Searing Gorge"] = 1427, ["Riverglades"] = 2548,
        ["Mulgore"] = 1412, ["Durotar"] = 1411, ["The Barrens"] = 1413, ["Darkshore"] = 1439,
        ["Teldrassil"] = 1438, ["Ashenvale"] = 1440, ["Stonetalon Mountains"] = 1442,
        ["Thousand Needles"] = 1441, ["Feralas"] = 1444, ["Dustwallow Marsh"] = 1445,
        ["Desolace"] = 1443, ["Tanaris"] = 1446, ["Azshara"] = 1447, ["Felwood"] = 1448,
        ["Winterspring"] = 1452, ["Moonglade"] = 1450, ["Silithus"] = 1451,
        ["Un'Goro Crater"] = 1449, ["Mount Hyjal"] = 2482,
    },
    -- Nodes whose flight master stands in a capital, not the zone their name gives.
    overrides = {
        [2] = 1453,  -- Stormwind, Elwynn -> Stormwind City
        [6] = 1455,  -- Ironforge, Dun Morogh -> Ironforge
        [11] = 1458, -- Undercity, Tirisfal -> Undercity
        [22] = 1456, -- Thunder Bluff, Mulgore -> Thunder Bluff
        [23] = 1454, -- Orgrimmar, Durotar -> Orgrimmar
    },
    -- Nodes that aren't flight paths a character learns: the Eastern Plaguelands towers
    -- (neutral, but Stormwind's flight master didn't list them).
    excluded = { [84] = true, [85] = true, [86] = true, [87] = true },
    -- Leftover nodes the client still returns (zzOLD...) are dropped by name.
    obsoletePrefix = "zzOLD",
}
