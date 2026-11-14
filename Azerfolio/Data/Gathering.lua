-- Where to gather: a hand-curated, unofficial guide (plan §8 provenance: curated). The client
-- has no node -> skill table and QuestieDB's node objects have almost no spawn points
-- (docs/research/professions.md § Gathering table). Owner-approved 2026-11-13 as a guide, like
-- Data/Zones.lua; the UI labels it "a guide, not game data".
--
-- Sources (fetched 2026-11-14 unless noted):
--   FG  wow-professions.com/forever/mining-leveling-guide and /forever/herbalism-leveling-guide
--       (Forever, "based on the beta"; zones are given per skill bracket, so a node's zones are
--       those of the brackets that name it)
--   KL  kami-labs.fr Forever mining list (2026-11-13)
--   GF  gfinityesports.com Forever herb guide (2026-11-13; matches Classic)
--   CL  Classic-era guides (Jukaar, rankedboost, wow-professions classic; 2026-11-13)
--   WT  warcrafttavern.com/forever guides (2026-11-13)
--   OW  the approved mockup's table (mockups/app.js GATHER, 2026-11-14), itself from CL
-- A skill of nil means no source gives it; `alt` lists the other values a source gives (open
-- check G1: a node's tooltip "Requires Mining (n)" settles it). zones are mapIDs (names in
-- comments); an empty list means no source names zones. items: what the node gives (item IDs,
-- checked against QuestieDB by `luajit tools/qdb.lua gather check`), used to say where an
-- ingredient comes from.
local _, ns = ...

-- Zone shorthands (mapIDs as in Data/Zones.lua).
local ELWYNN, DUNMOROGH, TELDRASSIL, DUROTAR, MULGORE, TIRISFAL, ZEPHRAS =
    1429, 1426, 1438, 1411, 1412, 1420, 2521
local SILVERPINE, LOCHMODAN, DARKSHORE, WESTFALL, WETLANDS, BARRENS = 1421, 1432, 1439, 1436, 1437, 1413
local HILLSBRAD, ASHENVALE, STONETALON = 1424, 1440, 1442
local ARATHI, NEEDLES, DESOLACE, STRANGLETHORN, DUSTWALLOW = 1417, 1441, 1443, 1434, 1445
local HINTERLANDS, TANARIS, SEARING, BURNING, BLASTED = 1425, 1446, 1427, 1428, 1419
local UNGORO, FELWOOD, EPL, WPL, WINTERSPRING, FERALAS = 1449, 1448, 1423, 1422, 1452, 1444
local RIVERGLADES, SHENDRALAS, HYJAL, STORMWIND = 2548, 2652, 2482, 1453

local STARTERS = { DUROTAR, MULGORE, TIRISFAL, ZEPHRAS, ELWYNN, DUNMOROGH, TELDRASSIL }

ns.GatheringData = {
    source = "Hand-curated from Forever and Classic profession guides (unofficial)",

    -- A node gives skill until this many points past the skill it needs (orange, yellow, green,
    -- then grey at +100). CL; no Forever source states it, so the UI says "a guide".
    greyAfter = 100,

    mining = {
        { name = "Copper Vein", skill = 1, zones = STARTERS, items = { 2770, 2835 }, src = "FG (Forever adds a Poor Copper Vein in starter zones, WT)" },
        { name = "Tin Vein", skill = 65, items = { 2771, 2836 }, src = "FG",
          zones = { WETLANDS, SILVERPINE, WESTFALL, HILLSBRAD, BARRENS, ASHENVALE, STONETALON } },
        { name = "Incendicite Mineral Vein", skill = 65, zones = {}, items = { 3340 }, src = "KL" },
        { name = "Silver Vein", skill = 75, items = { 2775 }, src = "FG",
          zones = { WETLANDS, SILVERPINE, WESTFALL, HILLSBRAD, BARRENS, ASHENVALE, STONETALON } },
        { name = "Lesser Bloodstone Deposit", skill = 75, zones = {}, items = { 4278 }, src = "KL" },
        { name = "Iron Deposit", skill = 125, zones = { ARATHI, NEEDLES, DESOLACE }, items = { 2772, 2838 }, src = "FG" },
        { name = "Indurium Mineral Vein", skill = 150, zones = {}, items = { 5833 }, src = "KL" },
        { name = "Gold Vein", skill = 155, zones = { ARATHI, NEEDLES, DESOLACE }, items = { 2776 }, src = "FG" },
        { name = "Mithril Deposit", skill = 175, zones = { HINTERLANDS, TANARIS }, items = { 3858, 7912 }, src = "FG" },
        { name = "Truesilver Deposit", skill = 230, zones = { HINTERLANDS, TANARIS }, items = { 7911 }, src = "FG" },
        { name = "Dark Iron Deposit", skill = 230, zones = { SEARING, BURNING }, items = { 11370 }, src = "KL; zones OW (not in FG)" },
        { name = "Small Thorium Vein", skill = 245, alt = { 250 }, zones = { UNGORO, BLASTED, FELWOOD }, items = { 10620, 12365 },
          src = "FG, KL (250 in CL)" },
        { name = "Rich Thorium Vein", skill = 275, alt = { 295 }, zones = { UNGORO, EPL, WINTERSPRING, BURNING }, items = { 10620, 12365 },
          src = "FG (WT says 295, unclear)" },
        { name = "Heavy Thorium Vein", skill = nil, zones = {}, items = {}, src = "WT, Forever-only; skill unknown" },
    },

    herbalism = {
        { name = "Peacebloom", skill = 1, zones = STARTERS, items = { 2447 }, src = "FG, GF" },
        { name = "Silverleaf", skill = 1, zones = STARTERS, items = { 765 }, src = "FG, GF" },
        { name = "Earthroot", skill = 15, zones = STARTERS, items = { 2449 }, src = "FG, GF" },
        { name = "Mageroyal", skill = 50, zones = { SILVERPINE, LOCHMODAN, DARKSHORE }, items = { 785 }, src = "GF; zones FG" },
        { name = "Briarthorn", skill = 70, zones = { SILVERPINE, LOCHMODAN, DARKSHORE }, items = { 2450 }, src = "GF; zones FG" },
        { name = "Stranglekelp", skill = 85, zones = { SILVERPINE, LOCHMODAN, DARKSHORE, HILLSBRAD, STONETALON }, items = { 3820 }, src = "FG, GF" },
        { name = "Bruiseweed", skill = 85, alt = { 100 }, zones = { HILLSBRAD, STONETALON }, items = { 2453 }, src = "GF (100 in CL); zones FG" },
        { name = "Wild Steelbloom", skill = 115, zones = { HILLSBRAD, STONETALON }, items = { 3355 }, src = "GF; zones FG" },
        { name = "Grave Moss", skill = 120, zones = {}, items = { 3369 }, src = "GF" },
        { name = "Kingsblood", skill = 125, zones = { HILLSBRAD, STONETALON, STRANGLETHORN, ARATHI, RIVERGLADES }, items = { 3356 },
          src = "FG, GF; Riverglades GF" },
        { name = "Liferoot", skill = 150, zones = { HILLSBRAD, STONETALON, STRANGLETHORN, ARATHI, RIVERGLADES }, items = { 3357 },
          src = "FG, GF; Riverglades GF" },
        { name = "Fadeleaf", skill = 160, zones = { STRANGLETHORN, ARATHI }, items = { 3818 }, src = "GF; zones FG" },
        { name = "Goldthorn", skill = 170, zones = { STRANGLETHORN, ARATHI }, items = { 3821 }, src = "GF; zones FG" },
        { name = "Khadgar's Whisker", skill = 185, zones = { STRANGLETHORN, ARATHI, SHENDRALAS }, items = { 3358 },
          src = "FG, GF; Shen'dralas GF" },
        { name = "Wintersbite", skill = 195, zones = {}, items = { 3819 }, src = "CL" },
        { name = "Firebloom", skill = 205, zones = { TANARIS, SEARING }, items = { 4625 }, src = "CL; zones FG" },
        { name = "Purple Lotus", skill = 210, zones = { TANARIS, SEARING, HINTERLANDS }, items = { 8831 }, src = "CL; zones FG" },
        { name = "Arthas' Tears", skill = 220, zones = {}, items = { 8836 }, src = "CL" },
        { name = "Sungrass", skill = 230, zones = { HINTERLANDS, FELWOOD }, items = { 8838 }, src = "GF; zones FG" },
        { name = "Blindweed", skill = 235, zones = {}, items = { 8839 }, src = "GF" },
        { name = "Ghost Mushroom", skill = 245, zones = { HINTERLANDS }, items = { 8845 }, src = "FG, GF" },
        { name = "Gromsblood", skill = 250, zones = { FELWOOD }, items = { 8846 }, src = "GF; zones FG" },
        { name = "Golden Sansam", skill = 260, zones = { HINTERLANDS, FELWOOD }, items = { 13464 }, src = "GF; zones FG" },
        { name = "Dreamfoil", skill = 270, zones = { FELWOOD }, items = { 13463 }, src = "GF; zones FG" },
        { name = "Mountain Silversage", skill = 280, zones = { FELWOOD, HYJAL }, items = { 13465 }, src = "GF; zones FG, Hyjal GF" },
        { name = "Plaguebloom", skill = 285, zones = { FELWOOD }, items = { 13466 }, src = "GF; zones FG" },
        { name = "Icecap", skill = 290, zones = {}, items = { 13467 }, src = "GF" },
        { name = "Black Lotus", skill = 300, zones = { HYJAL }, items = { 13468 }, src = "GF" },
        { name = "Marefoil", skill = nil, zones = {}, items = {}, src = "WT, Forever-only; skill unknown" },
        { name = "Demonsage", skill = nil, zones = {}, items = {}, src = "WT, Forever-only; skill unknown" },
        { name = "Death Lotus", skill = nil, zones = {}, items = {}, src = "WT, Forever-only; skill unknown" },
    },

    -- Skinning needs no table: the highest mob level you can skin is skill / 10 + 10 up to skill
    -- 100, then skill / 5 (wow-professions.com Classic guide, 2026-11-13). ProfessionRules turns
    -- that and Data/Zones.lua's level ranges into a zone's skinning range.
    skinning = { lowUntil = 100, lowDiv = 10, lowAdd = 10, highDiv = 5, src = "wow-professions.com Classic skinning guide" },

    -- Fishing has no skill per zone in any source, only brackets: good places to fish from
    -- that skill, not a requirement (wow-professions.com Classic fishing guide; OW).
    fishing = {
        { name = "Starting zones", skill = 1, zones = { ELWYNN, DUNMOROGH, TELDRASSIL, DUROTAR, MULGORE, TIRISFAL } },
        { name = "Second zones and capitals", skill = 75, zones = { WESTFALL, LOCHMODAN, DARKSHORE, BARRENS, SILVERPINE, STORMWIND } },
        { name = "Open waters", skill = 150, zones = { DUSTWALLOW, ARATHI, STRANGLETHORN, DESOLACE, NEEDLES } },
        { name = "Deep waters", skill = 225, zones = { FERALAS, TANARIS, HINTERLANDS, UNGORO, FELWOOD, WPL } },
    },
}
