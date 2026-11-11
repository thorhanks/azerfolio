/* Azerfolio mockup behavior. Design reference only; the addon implements this in Lua. */
(function () {
  "use strict";

  // =====================================================================================
  // Static data
  // =====================================================================================

  // Zone metadata: classic level ranges and faction territory. SAMPLE DATA for the mockup;
  // the addon needs a verified source before showing these (spec P1).
  const META = {
    "Elwynn Forest": [1, 10, "Alliance"], "Dun Morogh": [1, 10, "Alliance"], "Teldrassil": [1, 10, "Alliance"],
    "Durotar": [1, 10, "Horde"], "Mulgore": [1, 10, "Horde"], "Tirisfal Glades": [1, 10, "Horde"],
    "Westfall": [10, 20, "Alliance"], "Loch Modan": [10, 20, "Alliance"], "Darkshore": [10, 20, "Alliance"],
    "The Barrens": [10, 25, "Horde"], "Silverpine Forest": [10, 20, "Horde"], "Redridge Mountains": [15, 25, "Contested"],
    "Stonetalon Mountains": [15, 27, "Contested"], "Ashenvale": [18, 30, "Contested"], "Duskwood": [18, 30, "Contested"],
    "Wetlands": [20, 30, "Contested"], "Hillsbrad Foothills": [20, 30, "Contested"], "Thousand Needles": [25, 35, "Contested"],
    "Alterac Mountains": [30, 40, "Contested"], "Arathi Highlands": [30, 40, "Contested"], "Desolace": [30, 40, "Contested"],
    "Stranglethorn Vale": [30, 45, "Contested"], "Dustwallow Marsh": [35, 45, "Contested"], "Badlands": [35, 45, "Contested"],
    "Swamp of Sorrows": [35, 45, "Contested"], "Feralas": [40, 50, "Contested"], "The Hinterlands": [40, 50, "Contested"],
    "Tanaris": [40, 50, "Contested"], "Searing Gorge": [43, 50, "Contested"], "Azshara": [45, 55, "Contested"],
    "Blasted Lands": [45, 55, "Contested"], "Un'Goro Crater": [48, 55, "Contested"], "Felwood": [48, 55, "Contested"],
    "Burning Steppes": [50, 58, "Contested"], "Western Plaguelands": [51, 58, "Contested"],
    "Eastern Plaguelands": [53, 60, "Contested"], "Winterspring": [53, 60, "Contested"], "Deadwind Pass": [55, 60, "Contested"],
    "Silithus": [55, 60, "Contested"], "Moonglade": [null, null, "Sanctuary"],
  };
  const UNTRACKED = [
    { mapID: 1453, name: "Stormwind City", continent: "Eastern Kingdoms", faction: "Alliance" },
    { mapID: 1455, name: "Ironforge", continent: "Eastern Kingdoms", faction: "Alliance" },
    { mapID: 1457, name: "Darnassus", continent: "Kalimdor", faction: "Alliance" },
    { mapID: 1454, name: "Orgrimmar", continent: "Kalimdor", faction: "Horde" },
    { mapID: 1456, name: "Thunder Bluff", continent: "Kalimdor", faction: "Horde" },
    { mapID: 1458, name: "Undercity", continent: "Eastern Kingdoms", faction: "Horde" },
    { mapID: 2521, name: "Zephras Isle", continent: "Azeroth", faction: "Unknown" },
  ];
  // Atlas positions: atlas-rects.js (the client's zone rectangles; Phase 10).

  const now = new Date();
  const ago = (days, h, m) => { const d = new Date(now); d.setDate(d.getDate() - days); d.setHours(h, m, 0, 0); return d; };
  const firstN = (zoneName, n) => window.AZF_ZONES.find(z => z.name === zoneName).criteria.slice(0, n).map(c => c.name);
  const all = (zoneName) => firstN(zoneName, 999);
  const GIDEON_ELWYNN = ["Jerod's Landing", "Northshire Valley", "Goldshire", "Fargodeep Mine", "Crystal Lake", "Forest's Edge", "Brackwell Pumpkin Patch"];

  const SCENARIOS = {
    today: () => ({
      char: { name: "Gideon", level: 10, race: "Human", className: "Paladin", faction: "Alliance", xp: 273, xpMax: 7600, zone: "Elwynn Forest", subzone: "Goldshire" },
      done: { "Elwynn Forest": GIDEON_ELWYNN.slice() },
      flights: ["Stormwind", "Sentinel Hill"], questScale: 1, // flight paths: real, from the flight master (2026-11-08)
      flightsRead: ["Eastern Kingdoms"], // continents whose flight master list was read (Kalimdor not yet in game)
      rep: REP_PROBE, // zone reputation: the in-game probe
      milestones: [
        { t: ago(0, 11, 26), kind: "area", area: "Forest's Edge", zone: "Elwynn Forest" },
        { t: ago(0, 11, 30), kind: "area", area: "Brackwell Pumpkin Patch", zone: "Elwynn Forest" },
      ],
    }),
    almost: () => {
      const s = SCENARIOS.today();
      s.done["Elwynn Forest"] = all("Elwynn Forest").filter(n => n !== "Tower of Azora");
      ["Eastvale Logging Camp", "Ridgepoint Tower", "Stone Cairn Lake", "Stormwind City"].forEach((a, i) =>
        s.milestones.push({ t: ago(0, 12, 5 + i * 7), kind: "area", area: a, zone: "Elwynn Forest" }));
      return s;
    },
    veteran: () => ({
      char: { name: "Gideon", level: 32, race: "Human", className: "Paladin", faction: "Alliance", xp: 41200, xpMax: 62300, zone: "Duskwood", subzone: "Darkshire" },
      done: { "Elwynn Forest": all("Elwynn Forest"), "Westfall": all("Westfall"), "Loch Modan": all("Loch Modan"),
        "Dun Morogh": firstN("Dun Morogh", 12), "Redridge Mountains": firstN("Redridge Mountains", 9),
        "Duskwood": firstN("Duskwood", 7), "Wetlands": firstN("Wetlands", 4), "Darkshore": firstN("Darkshore", 3) },
      flights: ["Stormwind", "Ironforge", "Sentinel Hill", "Lakeshire", "Darkshire", "Thelsamar", "Menethil Harbor", "Auberdine"],
      questScale: "veteran", flightsRead: ["Eastern Kingdoms", "Kalimdor"], rep: REP_VETERAN,
      repGains: { 21: 350, 72: 75, 529: 250 }, watched: 21, // SAMPLE: gains the addon saw this session, the XP-bar faction
      milestones: [
        { t: ago(12, 20, 10), kind: "zone", zone: "Elwynn Forest" }, { t: ago(9, 21, 40), kind: "zone", zone: "Westfall" },
        { t: ago(6, 19, 5), kind: "zone", zone: "Loch Modan" }, { t: ago(4, 22, 15), kind: "area", area: "Lakeridge Highway", zone: "Redridge Mountains" },
        { t: ago(3, 18, 30), kind: "area", area: "Three Corners", zone: "Redridge Mountains" }, { t: ago(1, 20, 0), kind: "area", area: "Raven Hill", zone: "Duskwood" },
        { t: ago(0, 21, 12), kind: "area", area: "Darkshire", zone: "Duskwood" }, { t: ago(0, 21, 30), kind: "area", area: "Manor Mistmantle", zone: "Duskwood" },
      ],
    }),
    fresh: () => ({
      char: { name: "Elowen", level: 1, race: "Human", className: "Paladin", faction: "Alliance", xp: 0, xpMax: 400, zone: "Elwynn Forest", subzone: "Northshire Abbey" },
      done: {}, milestones: [], flights: [], questScale: 0, flightsRead: [], rep: REP_PROBE,
    }),
  };
  // Quests (Phase 9): Gideon's Elwynn Forest checklist as Quests.ForZone gave it in game
  // (trace, Human Paladin 10, before one turn-in; 5545 marked done here to match 42/68).
  // [id, name, questLevel, reqLevel, completion, eligibility, reason, prerequisite names]
  // SAMPLE DATA: other zones have none in the mockup.
  const C = "complete", I = "incomplete";
  const ELWYNN_QUESTS = [
    [6, "Bounty on Garrick Padfoot", 5, 2, C, "eligible", "completed"], [7, "Kobold Camp Cleanup", 2, 1, C, "eligible", "completed"],
    [11, "Riverpaw Gnoll Bounty", 10, 6, I, "eligible"], [15, "Investigate Echo Ridge", 3, 1, C, "eligible", "completed"],
    [18, "Brotherhood of Thieves", 4, 2, C, "eligible", "completed"], [21, "Skirmish at Echo Ridge", 5, 1, C, "eligible", "completed"],
    [33, "Wolves Across the Border", 2, 1, C, "eligible", "completed"], [35, "Further Concerns", 10, 7, I, "eligible"],
    [37, "Find the Lost Guards", 10, 7, I, "locked", "prerequisite", ["Further Concerns"]],
    [39, "Deliver Thomas' Report", 10, 7, I, "locked", "prerequisite", ["Report to Thomas"]],
    [40, "A Fishy Peril", 10, 7, C, "eligible", "completed"],
    [45, "Discover Rolf's Fate", 10, 7, I, "locked", "prerequisite", ["Find the Lost Guards"]],
    [46, "Bounty on Murlocs", 10, 7, I, "locked", "prerequisite", ["Deliver Thomas' Report"]],
    [47, "Gold Dust Exchange", 7, 4, C, "eligible", "completed"], [52, "Protect the Frontier", 10, 7, I, "eligible"],
    [54, "Report to Goldshire", 5, 1, C, "eligible", "completed"],
    [59, "Cloth and Leather Armor", 10, 7, I, "locked", "prerequisite", ["Deliver Thomas' Report"]],
    [60, "Kobold Candles", 7, 3, C, "eligible", "completed"], [61, "Shipment to Stormwind", 7, 3, I, "eligible"],
    [62, "The Fargodeep Mine", 7, 4, C, "eligible", "completed"],
    [71, "Report to Thomas", 10, 7, I, "locked", "prerequisite", ["Discover Rolf's Fate"]],
    [76, "The Jasperlode Mine", 10, 4, C, "eligible", "completed"], [83, "Red Linen Goods", 9, 4, I, "eligible"],
    [84, "Back to Billy", 6, 5, C, "eligible", "completed"], [85, "Lost Necklace", 6, 5, C, "eligible", "completed"],
    [86, "Pie for Billy", 6, 5, C, "eligible", "completed"], [87, "Goldtooth", 8, 5, C, "eligible", "completed"],
    [88, "Princess Must Die!", 9, 6, I, "eligible"], [106, "Young Lovers", 6, 5, C, "eligible", "completed"],
    [107, "Note to William", 6, 5, C, "eligible", "completed"], [109, "Report to Gryan Stoutmantle", 10, 9, I, "eligible"],
    [111, "Speak with Gramma", 6, 5, C, "eligible", "completed"], [112, "Collecting Kelp", 7, 5, C, "eligible", "completed"],
    [114, "The Escape", 7, 5, C, "eligible", "completed"], [123, "The Collector", 10, 7, I, "eligible"],
    [147, "Manhunt", 10, 7, I, "locked", "prerequisite", ["The Collector"]],
    [176, "WANTED: \"Hogger\"", 11, 5, I, "eligible"], [239, "Westbrook Garrison Needs Help!", 10, 6, I, "eligible"],
    [783, "A Threat Within", 1, 1, C, "eligible", "completed"], [2158, "Rest and Relaxation", 5, 1, C, "eligible", "completed"],
    [3903, "Milly Osworth", 4, 2, C, "eligible", "completed"], [3904, "Milly's Harvest", 4, 2, C, "eligible", "completed"],
    [3905, "Grape Manifest", 4, 2, C, "eligible", "completed"],
    [5261, "Eagan Peltskinner", 2, 1, I, "unavailable", "chain moved on"],
    [5545, "A Bundle of Trouble", 9, 5, C, "eligible", "completed"], [5805, "Welcome!", 1, 1, I, "eligible"],
    [91723, "Delicate Instruments", 8, 7, I, "eligible"],
    [91724, "Delicate Instruments", 10, 7, I, "locked", "prerequisite", ["Delicate Instruments"]],
    [91725, "Stolen Enchanting Supplies", 10, 7, I, "eligible"], [91732, "Good Steel", 7, 7, I, "eligible"],
    [91733, "Downstream", 10, 7, I, "eligible"], [91738, "An Apple Treat", 10, 7, I, "eligible"],
    [91740, "Croaky's Head", 11, 7, I, "eligible"], [91741, "Nibbled-On Book", 2, 1, C, "eligible", "completed"],
    [91743, "Rascally Rodents", 2, 1, C, "eligible", "completed"], [91745, "Mining Consultant", 3, 1, C, "eligible", "completed"],
    [91746, "Elmpaw's Head", 12, 7, I, "eligible"],
    [91751, "Rough Wolf Pelts", 8, 5, I, "unknown", "profession not checked"],
    [91752, "The Big Picture", 3, 1, C, "eligible", "completed"],
    [91753, "An Enchanting Lesson", 7, 5, I, "unknown", "profession not checked"],
    [91758, "Follow That Kobold!", 4, 1, C, "eligible", "completed"], [91772, "Shhh! We're Hunting Kobolds", 4, 1, C, "eligible", "completed"],
    [91775, "Book Return", 6, 1, C, "eligible", "completed"], [91777, "Rare Books", 7, 1, C, "eligible", "completed"],
    [92124, "Book Inventory", 2, 1, C, "eligible", "completed"], [99127, "A Net Disaster", 7, 4, C, "eligible", "completed"],
    [99128, "Slimy Menace", 7, 4, C, "eligible", "completed"], [99129, "A Man About a Murloc", 7, 4, C, "eligible", "completed"],
    [99130, "An Enticing Offer", 7, 4, C, "eligible", "completed"], [99131, "Baited for Success", 7, 4, C, "eligible", "completed"],
    [99143, "Bottles and Baubles", 7, 4, C, "eligible", "completed"],
  ];
  const QUEST_SAMPLES = { "Elwynn Forest": { quests: ELWYNN_QUESTS, repeatable: 4 } };
  // Quest data states for the dev bar: QuestieDB loaded, loaded for a Horde character, still
  // reading, not installed.
  const QUEST_MODES = { loaded: "QuestieDB loaded", horde: "Loaded, as Thragor (Horde)", building: "Reading QuestieDB", missing: "QuestieDB not installed" };
  // Chain links for the Elwynn sample (QuestieDB base rows, tools/qdb.lua): quest -> prerequisite
  // quests. The addon builds storylines from preQuestSingle/preQuestGroup/nextQuestInChain.
  const ELWYNN_PREREQS = {
    6: [18], 7: [783], 11: [76, 239], 15: [7], 18: [783], 21: [15], 54: [21], 35: [40], 37: [35], 39: [71], 45: [37], 46: [39],
    59: [39], 61: [60], 71: [45], 76: [62], 239: [76], 84: [86], 86: [85], 87: [84], 107: [111], 111: [106], 112: [107],
    114: [112], 147: [123], 92124: [91741], 91743: [92124], 91745: [91743], 91752: [91745], 91758: [91752], 91772: [91758],
    91775: [91772], 91777: [91775], 3903: [18], 3904: [18, 3903], 3905: [3904], 99128: [99127], 99129: [99128],
    99130: [99129], 99131: [99130], 91724: [91723], 5261: [783], 33: [5261],
  };
  // Gideon's quest counts per zone from the in-game report (Human Paladin 10): [completed,
  // counted, eligibility unknown, repeatable]. Zones missing here had no counted quests.
  const QUEST_COUNTS = {
    "Alterac Mountains": [0, 17, 0, 0], "Arathi Highlands": [0, 30, 0, 0], "Badlands": [0, 30, 0, 3], "Blasted Lands": [0, 17, 0, 7],
    "Burning Steppes": [0, 17, 0, 5], "Dun Morogh": [0, 57, 1, 6], "Duskwood": [0, 73, 1, 1], "Eastern Plaguelands": [0, 42, 11, 44],
    "Elwynn Forest": [42, 68, 2, 4], "Hillsbrad Foothills": [0, 16, 0, 0], "Ironforge": [0, 50, 0, 5], "Loch Modan": [0, 42, 1, 0],
    "Redridge Mountains": [0, 41, 1, 0], "Searing Gorge": [0, 27, 0, 4], "Stormwind City": [0, 125, 1, 2],
    "Stranglethorn Vale": [0, 91, 3, 6], "Swamp of Sorrows": [0, 15, 0, 1], "The Hinterlands": [0, 15, 0, 1],
    "Western Plaguelands": [0, 50, 2, 12], "Westfall": [0, 47, 4, 1], "Wetlands": [0, 70, 2, 0], "Ashenvale": [0, 48, 0, 4],
    "Azshara": [0, 18, 2, 3], "Darkshore": [0, 74, 0, 2], "Darnassus": [0, 21, 0, 4], "Desolace": [0, 44, 10, 1],
    "Durotar": [0, 2, 0, 4], "Dustwallow Marsh": [0, 24, 0, 0], "Felwood": [0, 26, 8, 43], "Feralas": [0, 44, 0, 7],
    "Moonglade": [0, 5, 3, 0], "Silithus": [0, 36, 14, 60], "Stonetalon Mountains": [0, 26, 0, 0], "Tanaris": [0, 44, 29, 12],
    "Teldrassil": [0, 64, 1, 0], "The Barrens": [0, 20, 0, 8], "Thousand Needles": [0, 36, 0, 2], "Un'Goro Crater": [0, 41, 0, 7],
    "Winterspring": [0, 33, 2, 14], "Zephras Isle": [0, 85, 0, 1],
  };
  // Flight paths an Alliance character can use, per zone: the client's own node list
  // (C_TaxiMap.GetTaxiNodesForMap, faction 2 plus neutral Ratchet and Marshal's Refuge),
  // probed 2026-11-08. Eastern Kingdoms also confirmed by Stormwind's flight master.
  const FLIGHTS = {
    "Stormwind City": ["Stormwind"], "Ironforge": ["Ironforge"], "Westfall": ["Sentinel Hill"], "Redridge Mountains": ["Lakeshire"],
    "Duskwood": ["Darkshire"], "Loch Modan": ["Thelsamar"], "Wetlands": ["Menethil Harbor"], "Hillsbrad Foothills": ["Southshore"],
    "Arathi Highlands": ["Refuge Pointe"], "The Hinterlands": ["Aerie Peak"], "Stranglethorn Vale": ["Booty Bay"],
    "Blasted Lands": ["Nethergarde Keep"], "Burning Steppes": ["Morgan's Vigil"], "Searing Gorge": ["Thorium Point"],
    "Eastern Plaguelands": ["Light's Hope Chapel"], "Western Plaguelands": ["Chillwind Camp"], "Teldrassil": ["Rut'theran Village"],
    "Darkshore": ["Auberdine"], "Ashenvale": ["Astranaar"], "Stonetalon Mountains": ["Stonetalon Peak"],
    "Desolace": ["Nijel's Point"], "Dustwallow Marsh": ["Theramore"], "Feralas": ["Feathermoon", "Thalanaar"],
    "Tanaris": ["Gadgetzan"], "Felwood": ["Talonbranch Glade"], "Winterspring": ["Everlook"], "Silithus": ["Cenarion Hold"],
    "Un'Goro Crater": ["Marshal's Refuge"], "Azshara": ["Talrendis Point"], "The Barrens": ["Ratchet"], "Moonglade": ["Nighthaven"],
  };
  // Zone reputation (Phase 11, spec §7.8, §8.9). Zone factions: the rule's offline result
  // (`luajit tools/qdb.lua reps rule`, base rows): [factionID, raising quests in the zone].
  // Faction 471 (no name, no game data) and Horde-side factions are left out further down, the
  // way the addon drops factions GetFactionDataByID returns nothing for.
  const REP_ZONES = {
    "Mulgore": [[2787, 4]], "The Barrens": [[470, 25]], "Arathi Highlands": [[21, 9]], "Tirisfal Glades": [[529, 6]],
    "Western Plaguelands": [[529, 36]], "Eastern Plaguelands": [[529, 65]], "The Hinterlands": [[471, 10]], "Wetlands": [[471, 6]],
    "Searing Gorge": [[59, 12]], "Stranglethorn Vale": [[21, 40], [87, 3]], "Thousand Needles": [[470, 7]], "Stonetalon Mountains": [[470, 6]],
    "Desolace": [[92, 10], [93, 9]], "Feralas": [[169, 4]], "Tanaris": [[369, 28], [910, 26]], "Felwood": [[576, 12]],
    "Moonglade": [[609, 7]], "Silithus": [[609, 101], [910, 8]], "Winterspring": [[577, 18], [589, 3]],
    "Zephras Isle": [[2778, 59], [2779, 55], [2758, 11]],
  };
  const REP_NAMES = { 21: "Booty Bay", 59: "Thorium Brotherhood", 87: "Bloodsail Buccaneers", 92: "Gelkis Clan Centaur", 93: "Magram Clan Centaur",
    169: "Steamwheedle Cartel", 369: "Gadgetzan", 470: "Ratchet", 529: "Argent Dawn", 576: "Timbermaw Hold", 577: "Everlook",
    589: "Wintersaber Trainers", 609: "Cenarion Circle", 910: "Brood of Nozdormu", 2758: "Nightclaw Druids", 2779: "High Order" };
  const REACTIONS = ["", "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"]; // FACTION_STANDING_LABEL1..8
  const REP_BOUNDS = [null, [-42000, -6000], [-6000, -3000], [-3000, 0], [0, 3000], [3000, 9000], [9000, 21000], [21000, 42000], [42000, 42999]];
  // Gideon's standing by faction ID: [standing, met, atWar]. "Gideon today" is the in-game
  // probe (/azfdiag reps, Gideon level 9, 2026-11-08): every zone faction unmet, at the game's
  // starting standing; no data for Brood of Nozdormu, 471 or the Horde side, so they're absent.
  const REP_PROBE = { 21: [500, false, false], 59: [0, false, false], 87: [-6500, false, true], 92: [2000, false, true], 93: [2000, false, true],
    169: [500, false, false], 369: [500, false, false], 470: [500, false, false], 529: [200, false, false], 576: [-3500, false, true],
    577: [500, false, false], 589: [0, false, false], 609: [0, false, false], 2758: [0, false, false], 2779: [0, false, false],
    // The rest of the probe (home factions are the met list; every other one unmet):
    72: [6600, true, false], 47: [3112, true, false], 69: [3112, true, false], 54: [3112, true, false],
    2586: [0, false, false], 2719: [500, false, false], 2740: [0, false, false], 2747: [-3400, false, true], 2765: [0, false, false],
    2799: [0, false, false], 2819: [0, false, false], 2826: [1, false, false], 2827: [500, false, false], 349: [0, false, false],
    509: [0, false, false], 730: [0, false, false], 809: [0, false, false], 890: [0, false, false], 909: [0, false, false] };
  // The veteran's standing is invented for design review: Booty Bay met mid-Friendly, Ratchet
  // Honored, Cenarion Circle met, Brood of Nozdormu readable (unmet, Hated, its classic start).
  const REP_VETERAN = { ...REP_PROBE, 21: [7200, true, false], 470: [11350, true, false], 87: [-6500, false, true],
    609: [1250, true, false], 910: [-42000, false, false], 369: [2150, true, false],
    72: [42999, true, false] /* Exalted, to show its gold */, 47: [9800, true, false], 69: [5400, true, false], 54: [8850, true, false], 529: [3400, true, false], 509: [1100, true, false] };
  // Rivals: pairs of the zone's factions where a quest here raises one and lowers the other
  // (`qdb.lua reps rivals`, base rows). The addon derives these from negative reputationReward.
  const REP_RIVALS = { "Stranglethorn Vale": [[21, 87]], "Desolace": [[92, 93]] };
  // The zone's quests that raise a faction (`qdb.lua reps quests <zone> <factionID>`, base rows):
  // [questID, name, questLevel, reqLevel, base amount]. SAMPLE: only these zone/faction pairs.
  const REP_QUESTS = {
    "Felwood|576": [[8460, "Timbermaw Ally", 48, 45, 150], [6031, "Runecloth", 55, 50, 100], [6032, "Sacred Cloth", 55, 50, 100],
      [8461, "Deadwood of the North", 55, 45, 150], [8462, "Speak to Nafien", 55, 45, 25], [8465, "Speak to Salfa", 55, 45, 25],
      [8466, "Feathers for Grazle", 55, 45, 50], [8467, "Feathers for Nafien", 55, 45, 50], [8470, "Deadwood Ritual Totem", 55, 45, 150],
      [8469, "Beads for Salfa", 56, 50, 50], [8464, "Winterfall Activity", 58, 45, 150], [8481, "The Root of All Evil", 60, 45, 200]],
    "Stranglethorn Vale|21": [[575, "Supply and Demand", 31, 26, 100], [201, "Investigate the Camp", 32, 28, 50], [189, "Bloodscalp Ears", 35, 30, 100],
      [605, "Singing Blue Shards", 35, 30, 100], [213, "Hostile Takeover", 36, 31, 100], [577, "Some Assembly Required", 36, 31, 100],
      [210, "Krazek's Cookery", 37, 32, 50], [578, "The Stone of the Tides", 37, 32, 100], [601, "Water Elementals", 37, 32, 100],
      [603, "Ansirem's Key", 37, 32, 50], [627, "Favor for Krazek", 37, 32, 75], [628, "Excelsior", 38, 31, 100],
      [610, "\"Pretty Boy\" Duncan", 39, 32, 100], [611, "The Curse of the Tides", 40, 32, 150], [95384, "Partial Mystical Notes", 40, 32, 50],
      [587, "Up to Snuff", 41, 37, 100], [595, "The Bloodsail Buccaneers", 41, 37, 75], [597, "The Bloodsail Buccaneers", 41, 37, 75],
      [599, "The Bloodsail Buccaneers", 41, 37, 25], [600, "Venture Company Mining", 41, 30, 100], [606, "Scaring Shaky", 41, 30, 25],
      [607, "Return to MacKinley", 41, 30, 75], [209, "Skullsplitter Tusks", 42, 37, 100], [576, "Keep An Eye Out", 42, 37, 150],
      [604, "The Bloodsail Buccaneers", 43, 37, 100], [617, "Akiris by the Bundle", 43, 38, 100], [623, "Akiris by the Bundle", 43, 38, 150],
      [609, "Voodoo Dues", 44, 30, 100], [613, "Cracking Maury's Foot", 44, 30, 150], [621, "Zanzil's Secret", 44, 35, 100],
      [348, "Stranglethorn Fever", 45, 40, 200], [608, "The Bloodsail Buccaneers", 45, 37, 150], [8551, "The Captain's Chest", 47, 35, 75],
      [580, "Whiskey Slim's Lost Grog", 50, 40, 100], [618, "Facing Negolash", 50, 40, 200], [3721, "An OOX of Your Own", 50, 45, 200],
      [8552, "The Monogrammed Sash", 50, 40, 50], [8554, "Facing Negolash", 50, 40, 200], [614, "The Captain's Chest", 51, 35, 75],
      [9259, "Traitor to the Bloodsail", 60, 30, 499]],
    "Stranglethorn Vale|87": [[9272, "Dressing the Part", 55, 49, 10], [1036, "Avast Ye, Scallywag", 60, 55, 25], [4621, "Avast Ye, Admiral!", 60, 55, 200]],
    "Desolace|92": [[1368, "Gelkis Alliance", 33, 30, 100], [1382, "Strange Alliance", 35, 30, 100], [92755, "Mysterious Mysticism", 35, 30, 1000],
      [92814, "I Need a Tailor", 35, 30, 1000], [92817, "Leather Technique", 35, 30, 1000], [93044, "A Cleansing Cry", 38, 30, 500],
      [93128, "Khan Jehn", 42, 30, 6000], [93227, "Buying Friendship: Gelkis", 45, 30, 3000], [94873, "Buying Friendship: Gelkis", 45, 30, 3000],
      [92812, "Economic Warfare", 60, 1, 750]],
    "Desolace|93": [[1367, "Magram Alliance", 33, 30, 100], [1385, "Brutal Politics", 35, 30, 100], [92754, "A New Need for Shadow Protection", 35, 30, 1000],
      [92818, "Big, No, MASSIVE Iron Axes", 35, 30, 1000], [92743, "A Conqueror's Crown", 40, 30, 1000], [93196, "Khan Jehn", 42, 30, 6000],
      [93226, "Buying Friendship: Magram", 45, 30, 3000], [94872, "Buying Friendship: Magram", 45, 30, 3000], [92811, "Economic Warfare", 60, 1, 750]],
    "Silithus|910": [[8286, "What Tomorrow Brings", 60, 60, 100], [8301, "The Path of the Righteous", 60, 60, 200], [8302, "The Hand of the Righteous", 60, 60, 200],
      [8303, "Anachronos", 60, 60, 200], [8305, "Long Forgotten Memories", 60, 60, 50], [8519, "A Pawn on the Eternal Board", 60, 60, 100],
      [8743, "Bang a Gong!", 60, 60, 200], [8745, "Treasure of the Timeless One", 60, 60, 200]],
  };
  // ---- Reputation tab (Phase 12 proposal) ----
  // Every faction the game returns data for (GetFactionDataByID, probe 2026-11-08: 38 IDs for
  // Gideon). The other side's battleground factions also return data (The Defilers, Frostwolf
  // Clan, Darkspear Raiders: Hated, at war), so the addon leaves them out by side; the Alliance
  // header (469) is a header, not a row. Group: where most of the faction's raising quests are
  // (QuestieDB, `qdb.lua reps`), derived, not hand-sorted. Sources: [kind, place, quests, ~total,
  // forYou] from the base rows (both sides' quests, so SAMPLE counts). home: the zone whose art
  // makes the faction's banner. rpt: repeatable turn-ins among them (SAMPLE), left out of the reach.
  const REP_GROUPS = [["home", "Home"], ["zones", "Zones"], ["instances", "Dungeons & raids"], ["bgs", "Battlegrounds"],
    ["profs", "Professions"], ["other", "Class and events"], ["none", "No known quests"]];
  const REP_ALL = [
    { id: 72, name: "Stormwind", group: "home", home: "Elwynn Forest", src: [["zone", "Elwynn Forest", 61, 4375], ["zone", "Duskwood", 49, 3125], ["zone", "Stormwind City", 43, 4020], ["zone", "Redridge Mountains", 35, 3150], ["zone", "Westfall", 32, 2320], ["zone", "Wetlands", 17, 950], ["dungeon", "The Stockade", 5, 600], ["dungeon", "The Deadmines", 4, 450]] },
    { id: 47, name: "Ironforge", group: "home", home: "Dun Morogh", src: [["zone", "Dun Morogh", 50, 4088], ["zone", "Loch Modan", 40, 3385], ["zone", "Wetlands", 24, 2225], ["zone", "Ironforge", 23, 2005], ["zone", "Badlands", 13, 1100], ["dungeon", "Uldaman", 8, 1000], ["bg", "Alterac Valley", 33, 2695]] },
    { id: 69, name: "Darnassus", group: "home", home: "Teldrassil", src: [["zone", "Darkshore", 59, 4860], ["zone", "Teldrassil", 57, 5315], ["zone", "Ashenvale", 42, 3775], ["zone", "Feralas", 32, 2375], ["zone", "Darnassus", 18, 1335]] },
    { id: 54, name: "Gnomeregan Exiles", group: "home", home: "Dun Morogh", src: [["zone", "Dun Morogh", 47, 3888], ["zone", "Loch Modan", 10, 475], ["zone", "Stonetalon Mountains", 10, 900], ["zone", "Ironforge", 10, 1100], ["dungeon", "Gnomeregan", 10, 870]] },
    { id: 21, name: "Booty Bay", group: "zones", home: "Stranglethorn Vale", src: [["zone", "Stranglethorn Vale", 40, 4499], ["zone", "Arathi Highlands", 9, 875], ["zone", "Azshara", 2, 300], ["zone", "The Hinterlands", 2, 250], ["zone", "Tanaris", 2, 250], ["zone", "Badlands", 2, 225], ["dungeon", "Uldaman", 1, 150]] },
    { id: 87, name: "Bloodsail Buccaneers", group: "zones", home: "Stranglethorn Vale", src: [["zone", "Stranglethorn Vale", 3, 235]] },
    { id: 470, name: "Ratchet", group: "zones", home: "The Barrens", src: [["zone", "The Barrens", 27, 2594], ["zone", "Thousand Needles", 7, 375], ["zone", "Stonetalon Mountains", 6, 525], ["zone", "Durotar", 4, 400], ["zone", "Desolace", 4, 350], ["dungeon", "Razorfen Kraul", 2, 250], ["dungeon", "Wailing Caverns", 2, 200]] },
    { id: 369, name: "Gadgetzan", group: "zones", home: "Tanaris", src: [["zone", "Tanaris", 28, 3154], ["dungeon", "Zul'Farrak", 3, 325]] },
    { id: 577, name: "Everlook", group: "zones", home: "Winterspring", src: [["zone", "Winterspring", 18, 1899]] },
    { id: 59, name: "Thorium Brotherhood", group: "zones", home: "Searing Gorge", rpt: 4, src: [["zone", "Searing Gorge", 12, 900], ["raid", "Molten Core", 5, 800], ["dungeon", "Blackrock Depths", 1, 200], ["prof", "Blacksmithing quests", 8, 1150, false]] },
    { id: 576, name: "Timbermaw Hold", group: "zones", home: "Felwood", rpt: 5, src: [["zone", "Felwood", 12, 1200], ["zone", "Winterspring", 1, 150]] },
    { id: 529, name: "Argent Dawn", group: "zones", home: "Eastern Plaguelands", rpt: 6, src: [["zone", "Eastern Plaguelands", 65, 6680], ["zone", "Western Plaguelands", 36, 2670], ["zone", "Tirisfal Glades", 6, 850], ["raid", "Naxxramas", 77, 15400], ["dungeon", "Stratholme", 7, 1149], ["dungeon", "Blackfathom Deeps", 4, 700], ["dungeon", "Scholomance", 4, 375]] },
    { id: 609, name: "Cenarion Circle", group: "zones", home: "Silithus", rpt: 12, src: [["zone", "Silithus", 101, 7760], ["zone", "Moonglade", 7, 800], ["raid", "Ahn'Qiraj", 31, 3298], ["dungeon", "Maraudon", 3, 450], ["class", "Druid quests", 42, 2320, false]] },
    { id: 92, name: "Gelkis Clan Centaur", group: "zones", home: "Desolace", src: [["zone", "Desolace", 10, 16450], ["zone", "Shen'dralas", 8, 3625]] },
    { id: 93, name: "Magram Clan Centaur", group: "zones", home: "Desolace", src: [["zone", "Desolace", 9, 15950], ["zone", "Shen'dralas", 11, 5125]] },
    { id: 589, name: "Wintersaber Trainers", group: "zones", home: "Winterspring", rpt: 3, src: [["zone", "Winterspring", 3, 150]] },
    { id: 169, name: "Steamwheedle Cartel", group: "zones", home: "Feralas", src: [["zone", "Feralas", 4, 350], ["dungeon", "Dire Maul", 4, 450], ["dungeon", "Blackrock Spire", 2, 350]] },
    { id: 2779, name: "High Order", group: "zones", home: "Zephras Isle", src: [["zone", "Zephras Isle", 55, 2860], ["zone", "Alterac Mountains", 2, 300]] },
    { id: 2758, name: "Nightclaw Druids", group: "zones", home: "Zephras Isle", src: [["zone", "Zephras Isle", 11, 5400]] },
    { id: 2740, name: "Kirin Tor", group: "zones", home: "Alterac Mountains", src: [["zone", "Alterac Mountains", 2, 20], ["zone", "Stormwind City", 1, 100], ["dungeon", "Scarlet Monastery", 1, 100]] },
    { id: 2827, name: "Powderfuse", group: "zones", home: "The Barrens", src: [["zone", "The Barrens", 3, 200]] },
    { id: 809, name: "Shen'dralar", group: "instances", home: null, src: [["dungeon", "Dire Maul", 14, 2800], ["raid", "Onyxia's Lair", 1, 200]] },
    { id: 509, name: "The League of Arathor", group: "bgs", home: "Arathi Highlands", src: [["bg", "Arathi Basin", 29, 3655]] },
    { id: 730, name: "Stormpike Guard", group: "bgs", home: "Alterac Mountains", src: [["bg", "Alterac Valley", 28, 4455]] },
    { id: 890, name: "Silverwing Sentinels", group: "bgs", home: "Ashenvale", src: [["bg", "Warsong Gulch", 29, 2905]] },
    { id: 2799, name: "Theramore Expeditionary Force", group: "bgs", home: null, src: [["bg", "Darkspear Islands", 8, 1300]] },
    { id: 2586, name: "Azeroth Commerce Authority", group: "profs", home: null, rpt: 20, src: [["prof", "Crafting orders", 150, 19875]] },
    { id: 909, name: "Darkmoon Faire", group: "other", home: null, rpt: 29, src: [["event", "Darkmoon Faire", 29, 2900]] },
    { id: 349, name: "Ravenholdt", group: "other", home: "Alterac Mountains", src: [["class", "Rogue quests", 11, 1210, false]] },
    { id: 2747, name: "Barkskin Burrow", group: "none", home: null, src: [] },
    { id: 2719, name: "Cenarion Scouts", group: "none", home: null, src: [] },
    { id: 2765, name: "Guardians of Hyjal", group: "none", home: null, src: [] },
    { id: 2819, name: "The Watchers", group: "none", home: null, src: [] },
    { id: 2826, name: "Brotherhood of the Horse", group: "none", home: null, src: [] },
  ];
  REP_ALL.forEach(f => { if (!REP_NAMES[f.id]) REP_NAMES[f.id] = f.name; });
  const REP_RIVAL_OF = { 21: 87, 87: 21, 92: 93, 93: 92 };
  // Stand-in text for the game's own faction description (`description` in the faction data);
  // written for the mockup, not the client's wording.
  const REP_DESC = {
    21: "The goblin port at the tip of Stranglethorn, and the Steamwheedle Cartel's busiest harbour.",
    87: "Pirates who prey on the Cartel's ships along the southern coast.",
    576: "Furbolgs of Felwood who held on to their minds when the rest of their kind fell to corruption.",
    529: "A brotherhood sworn to drive the Scourge from the Plaguelands.",
    609: "Druids who watch over the balance of nature from Moonglade to the deserts of Silithus.",
    92: "Earth-spirit centaur of southern Desolace, bitter enemies of the Magram.", 93: "Centaur of eastern Desolace, at war with the Gelkis.",
    72: "The human kingdom and its capital, heart of the Alliance.",
  };
  const CATS = { explore: { label: "Exploration", icon: "◎", unit: "areas" }, quests: { label: "Quests", icon: "!", unit: "quests" },
    flights: { label: "Flight paths", icon: "✈", unit: "flight paths" } };


  // =====================================================================================
  // Model (in the addon this is the Progression service)
  // =====================================================================================
  let S;      // scenario data
  let CHAR;   // character
  let zones, byName, tracked, totals;

  function buildModel() {
    zones = window.AZF_ZONES.map(z => {
      const m = META[z.name] || [null, null, "Unknown"];
      const doneSet = new Set(S.done[z.name] || []);
      const criteria = z.criteria.map(c => ({ ...c, done: doneSet.has(c.name) }));
      const done = criteria.filter(c => c.done).length;
      const total = criteria.length;
      return { ...z, minLevel: m[0], maxLevel: m[1], faction: m[2], criteria, done, total };
    }).concat(UNTRACKED.map(u => ({ ...u, minLevel: null, maxLevel: null, criteria: [], done: 0, total: 0 })));
    zones.forEach(applyCategories);
    byName = Object.fromEntries(zones.map(z => [z.name, z]));
    tracked = zones.filter(z => z.tracked);
    totals = {
      areas: tracked.reduce((s, z) => s + z.total, 0), done: tracked.reduce((s, z) => s + z.done, 0),
      complete: tracked.filter(z => z.state === "complete").length, progress: tracked.filter(z => z.state === "progress").length,
      untouched: tracked.filter(z => z.state === "untouched").length,
    };
    totals.cats = trackedCompletion();
  }
  // Tracked completion (spec §5.2, v1.1; in the addon: ns.Progression over every relevant
  // zone): each category's confirmed done / counted across the zones you can do, and the
  // headline as the equal-weight average of the categories that have data. A category without
  // data is listed with its reason and left out of the average, never shown as 0%.
  function trackedCompletion() {
    const mine = tracked.filter(relevant);
    const sum = (key, f) => mine.reduce((acc, z) => {
      const c = catOf(z, key); if (c && f(z)) { acc.done += c.done; acc.total += c.total; acc.unchecked += c.unchecked || 0; acc.zones++; } return acc;
    }, { done: 0, total: 0, unchecked: 0, zones: 0 });
    const read = new Set(S.flightsRead || []);
    const cats = [
      { key: "explore", ...(sum("explore", () => true) || {}) },
      ui.quests === "building" ? { key: "quests", pending: "Reading quests..." }
        : ui.quests === "missing" ? { key: "quests", pending: "Needs the QuestieDB addon" }
        : { key: "quests", ...(sum("quests", () => true) || {}) },
      { key: "flights", ...(sum("flights", z => read.has(z.continent)) || {}) },
    ];
    const unreadFlights = ["Eastern Kingdoms", "Kalimdor"].filter(c => !read.has(c));
    cats.forEach(c => {
      Object.assign(c, { label: CATS[c.key].label, unit: CATS[c.key].unit });
      if (!c.pending && !c.total) c.pending = c.key === "flights" ? "Talk to a flight master" : "No data yet";
      c.pct = c.pending ? null : c.done / c.total;
      if (c.key === "flights" && !c.pending && unreadFlights.length) c.note = `${unreadFlights.join(" and ")}: talk to a flight master there`;
      if (c.key === "quests" && c.unchecked) c.note = `${c.unchecked} can't be checked yet`;
    });
    const counted = cats.filter(c => c.pct != null);
    return { list: cats, pct: counted.length ? counted.reduce((s, c) => s + c.pct, 0) / counted.length : null };
  }
  // Zone completion (spec §7.7; in the addon: ns.Progression). Each category that applies to
  // the zone (at least one counted objective) gets completed / counted / %; the zone's % is the
  // equal-weight average; a category that doesn't apply is left out, never 0%. Gold (complete)
  // only when every applying category is at 100% with nothing unchecked.
  function applyCategories(z) {
    const cats = [];
    if (z.total) cats.push({ key: "explore", done: z.done, total: z.total });
    const qc = QUEST_COUNTS[z.name];
    z.questsMissing = ui.quests === "missing" || ui.quests === "building";
    const horde = ui.quests === "horde"; // dev bar: Elwynn as seen by a Horde character
    if (qc && qc[1] > 0 && !z.questsMissing && !horde) {
      // Sample: "Gideon today" is real; the veteran's quest progress is invented from exploration.
      const done = S.questScale === "veteran" ? Math.round(qc[1] * (z.total ? z.done / z.total : 0) * 0.8) : qc[0] * S.questScale;
      cats.push({ key: "quests", done, total: qc[1], unchecked: qc[2], repeatable: qc[3] });
    }
    const fl = FLIGHTS[z.name];
    if (fl && CHAR.faction === "Alliance" && !horde) {
      const known = new Set(S.flights || []);
      cats.push({ key: "flights", done: fl.filter(n => known.has(n)).length, total: fl.length, nodes: fl.map(n => ({ name: n, known: known.has(n) })) });
    }
    cats.forEach(c => { Object.assign(c, CATS[c.key]); c.pct = c.done / c.total; });
    z.cats = cats;
    z.tracked = cats.length > 0;
    z.pct = cats.length ? cats.reduce((s, c) => s + c.pct, 0) / cats.length : null;
    z.unchecked = cats.some(c => c.unchecked);
    z.left = cats.reduce((s, c) => s + c.total - c.done, 0);
    z.state = !cats.length ? "untracked" : cats.every(c => c.pct >= 1) && !z.unchecked ? "complete"
      : cats.some(c => c.done > 0) ? "progress" : "untouched";
  }
  const catOf = (z, key) => (z.cats || []).find(c => c.key === key);
  const catState = (c) => c.pct >= 1 && !c.unchecked ? "complete" : c.done > 0 ? "progress" : "untouched";
  // One thin bar per category (catalogue cards and rows, Overview).
  function catbars(z, size = "") {
    if (!z.cats.length) return `<div class="bar unknown small"></div>`;
    // One fixed slot per category, so columns line up; a category that doesn't apply leaves its slot empty.
    return `<div class="catbars ${size}">${Object.keys(CATS).map(k => { const c = catOf(z, k);
      return c ? `<div class="catbar ${catState(c)}">${catIcon(c.key)}
      <span class="ctrack"><i style="width:${(c.pct * 100).toFixed(1)}%"></i></span><span class="cn">${c.done}/${c.total}</span></div>` : `<div class="catbar na"></div>`; }).join("")}</div>`;
  }
  // A zone's quests the way Quests.ForZone will return them (Systems/Quests.lua plus
  // ns.Progression): counts, the Ready now list with difficulty, and storylines built from
  // QuestieDB's chain links. The UI only draws this; nothing here is computed by the page.
  // Difficulty mimics the client's quest colours (the addon asks the client).
  const difficulty = (ql, pl) => { const d = ql - pl; return d >= 5 ? "red" : d >= 3 ? "orange" : d >= -2 ? "yellow" : d >= -5 ? "green" : "grey"; };
  const kindOf = (o) => o.eligibility === "unavailable" ? "unavailable" : o.eligibility === "unknown" ? "unknown"
    : o.completion === C ? "done" : o.eligibility === "locked" ? "locked" : "ready";
  function questsFor(z) {
    if (ui.quests === "building" || ui.quests === "missing") return { status: ui.quests === "building" ? "building" : "unavailable", reason: "QuestieDB not loaded" };
    const sample = QUEST_SAMPLES[z.name];
    if (!sample) return { status: "nosample" };
    const objectives = sample.quests.map(([id, name, questLevel, reqLevel, completion, eligibility, reason, prereqs]) =>
      ui.quests === "horde" ? { id, name, questLevel, reqLevel, completion: I, eligibility: "unavailable", reason: "race or faction" }
        : { id, name, questLevel, reqLevel, completion, eligibility, reason, prereqs });
    objectives.forEach(o => { o.kind = kindOf(o); o.diff = difficulty(o.questLevel, CHAR.level); });
    const n = (f) => objectives.filter(f).length;
    const counted = (o) => o.eligibility === "eligible" || o.eligibility === "locked";
    const completed = n(o => counted(o) && o.completion === C), denominator = n(counted);
    const unknownReasons = {};
    objectives.forEach(o => { if (o.eligibility === "unknown") unknownReasons[o.reason] = (unknownReasons[o.reason] || 0) + 1; });
    const byLevel = (a, b) => (a.questLevel - b.questLevel) || a.name.localeCompare(b.name);

    // Storylines: quests joined by prerequisite / next-quest links; columns by chain depth.
    const byId = Object.fromEntries(objectives.map(o => [o.id, o]));
    const pre = {}, parent = {};
    const root = (x) => { while (parent[x] !== undefined && parent[x] !== x) x = parent[x]; return x; };
    for (const o of objectives) for (const p of (ELWYNN_PREREQS[o.id] || [])) if (byId[p]) {
      (pre[o.id] = pre[o.id] || []).push(p);
      const a = root(p), b = root(o.id); if (a !== b) parent[a] = b;
    }
    const memo = {};
    const depth = (id) => memo[id] !== undefined ? memo[id] : (memo[id] = Math.max(-1, ...(pre[id] || []).map(depth)) + 1);
    const comps = {};
    objectives.forEach(o => { const r = root(o.id); (comps[r] = comps[r] || []).push(o); });
    const stories = [], singles = [];
    for (const list of Object.values(comps)) {
      if (list.length < 2) { singles.push(list[0]); continue; }
      const cols = [];
      list.forEach(o => { const d = depth(o.id); (cols[d] = cols[d] || []).push(o); });
      cols.forEach(c => c.sort(byLevel));
      const cnt = list.filter(counted);
      const done = cnt.filter(o => o.completion === C).length;
      stories.push({ id: cols[0][0].id, name: cols[0][0].name, columns: cols, size: list.length, done, total: cnt.length,
        ready: list.filter(o => o.kind === "ready").length, finished: cnt.length > 0 && done === cnt.length,
        level: Math.min(...list.filter(o => o.kind !== "done").map(o => o.questLevel), 99) });
    }
    const active = stories.filter(s => !s.finished).sort((a, b) => (b.ready > 0) - (a.ready > 0) || a.level - b.level || a.name.localeCompare(b.name));
    const finished = stories.filter(s => s.finished).sort((a, b) => a.name.localeCompare(b.name));
    const order = { ready: 0, locked: 1, unknown: 2, unavailable: 3, done: 4 };
    singles.sort((a, b) => order[a.kind] - order[b.kind] || byLevel(a, b));
    return { status: "ready", objectives, repeatable: sample.repeatable, unknownReasons,
      progress: { completed, denominator, remaining: denominator - completed, locked: n(o => o.eligibility === "locked"),
        unavailable: n(o => o.eligibility === "unavailable"), eligibilityUnknown: n(o => o.eligibility === "unknown"),
        percent: denominator ? completed / denominator : null },
      ready: objectives.filter(o => o.kind === "ready").sort(byLevel), stories: active, finished, singles };
  }
  const fitsLevel = (z) => z.minLevel != null && z.minLevel <= CHAR.level + 3 && z.maxLevel >= CHAR.level;
  const relevant = (z) => z.faction !== (CHAR.faction === "Alliance" ? "Horde" : "Alliance");

  // =====================================================================================
  // UI state
  // =====================================================================================
  const ui = { repBar: "equal", tab: "overview", detail: null, view: "cards", faction: "relevant", status: "all", level: "all", sort: "recommended",
    search: "", zonesScroll: 0, lastZone: null, selected: null, flyout: null, wide: false, newCrit: null, celebrate: null,
    quests: "loaded", showUnavailable: false, openStories: new Set(), detailPage: null, look: "Alliance",
    repFilter: "all", repSort: "group", repSel: null, repOpen: null, watched: null, classSel: null, classPreview: "data" };
  const OPTIONS = {
    faction: { label: "Show", items: [["relevant", "Relevant to me"], ["all", "All zones"]] },
    level: { label: "Level", items: [["all", "All levels"], ["appropriate", "For my level"]] },
    sort: { label: "Sort", items: [["recommended", "Recommended"], ["alphabetical", "A–Z"], ["highest", "Highest %"], ["lowest", "Lowest %"], ["closest", "Closest to done"]] },
    repSort: { label: "Sort", items: [["group", "By group"], ["closest", "Closest to next"], ["az", "A–Z"]] },
  };
  const STATUS = [["all", "All"], ["progress", "In progress"], ["untouched", "Untouched"], ["complete", "Complete"]];
  const optLabel = (key) => OPTIONS[key].items.find(o => o[0] === ui[key])[1];

  // =====================================================================================
  // Helpers and components
  // =====================================================================================
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const content = $("#content");
  const esc = (s) => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const pctText = (p) => p == null ? "—" : `${Math.round(p * 100)}%`;
  const levels = (z) => z.minLevel == null ? "Levels —" : `Levels ${z.minLevel}–${z.maxLevel}`;
  const shortLv = (z) => z.minLevel == null ? "—" : `${z.minLevel}–${z.maxLevel}`;
  const winW = () => ui.wide ? 1640 : 1160;
  const fmtTime = (d) => {
    const days = Math.round((new Date(now).setHours(0, 0, 0, 0) - new Date(d).setHours(0, 0, 0, 0)) / 864e5);
    const hm = d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
    return days === 0 ? `Today, ${hm}` : days === 1 ? `Yesterday, ${hm}` : `${days} days ago`;
  };

  function pips(z, size = "", light = false) {
    if (!z.tracked) return "";
    const ordered = z.criteria.filter(c => c.done).concat(z.criteria.filter(c => !c.done)); // fill left to right
    return `<div class="pips ${size} ${light ? "light" : ""}">${ordered.map(c =>
      `<i class="pip ${c.done ? "on" : ""} ${ui.newCrit === c.id ? "new" : ""}"></i>`).join("")}</div>`;
  }
  const bar = (p, cls = "") => p == null ? `<div class="bar unknown ${cls}"></div>`
    : `<div class="bar ${p >= 1 ? "complete" : ""} ${cls}"><i style="width:${(p * 100).toFixed(1)}%"></i></div>`;
  function levelbar(z) {
    if (z.minLevel == null) return `<div class="levelbar"></div>`;
    const x = (l) => ((l - 1) / 59 * 100).toFixed(1);
    return `<div class="levelbar"><span class="range ${fitsLevel(z) ? "fit" : ""}" style="left:${x(z.minLevel)}%;width:${(x(z.maxLevel) - x(z.minLevel)).toFixed(1)}%"></span><span class="me" style="left:calc(${x(CHAR.level)}% - 1px)"></span></div>`;
  }
  const facBadge = (z) => `<span class="fac ${z.faction}">${z.faction}</span>`;

  // Placeholder zone art (painted-landscape stand-in until real art exists).
  function hash(s) { let h = 0; for (const ch of s) h = (h * 31 + ch.charCodeAt(0)) >>> 0; return h; }
  function art(z) {
    // Real processed art (tools/process-art.ps1) wins; then the fallback image; then a generated placeholder.
    const A = window.AZF_ART;
    if (A && (A.ids.includes(z.mapID) || A.fallback)) {
      return `<img class="zart" src="zone-art/${A.ids.includes(z.mapID) ? z.mapID : "fallback"}.png" alt="">`;
    }
    const h = hash(z.name), n = z.name;
    const kind = /Tanaris|Silithus|Barrens|Desolace|Badlands|Durotar|Thousand|Searing|Burning|Blasted|Un'Goro|Orgrimmar/.test(n) ? "dry"
      : /Winterspring|Dun Morogh|Alterac|Ironforge|Hyjal/.test(n) ? "snow"
      : /Plague|Deadwind|Swamp|Dustwallow|Felwood|Undercity|Duskwood|Shen/.test(n) ? "gloom" : "green";
    const pal = { green: ["#9fd0ef", "#f5e3b5", "#5d8a4a", "#3d6b35", "#24451f"], dry: ["#f2c58a", "#fbe7c2", "#c98a4b", "#a0632f", "#6e3f1b"],
      snow: ["#a9c6e8", "#eef3fb", "#c9d6e6", "#8fa4bd", "#56677e"], gloom: ["#6b7a8f", "#b8b3a0", "#4f5a4a", "#363f35", "#1e241d"] }[kind];
    const r = (i, a, b) => a + ((h >> (i * 3)) % 1000) / 1000 * (b - a);
    const ridge = (y, amp, seed) => {
      let d = `M0 ${y}`;
      for (let x = 0; x <= 320; x += 20) d += ` L${x} ${(y - Math.abs(Math.sin((x + seed * 37 + h % 50) / (30 + seed * 7))) * amp - r(seed + x / 20, 0, amp / 3)).toFixed(1)}`;
      return d + " L320 180 L0 180 Z";
    };
    const trees = kind === "green" || kind === "gloom" ? Array.from({ length: 9 }, (_, i) => {
      const x = 10 + i * 36 + r(i, -8, 8), s = r(i + 2, 14, 26);
      return `<path d="M${x} 174 l${s / 2} -${s * 1.6} l${s / 2} ${s * 1.6} Z" fill="${pal[4]}"/>`; }).join("") : "";
    const id = "g" + h;
    return `<svg viewBox="0 0 320 180" preserveAspectRatio="xMidYMid slice"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal[0]}"/><stop offset="1" stop-color="${pal[1]}"/></linearGradient></defs>
      <rect width="320" height="180" fill="url(#${id})"/><circle cx="${r(1, 40, 280)}" cy="${r(2, 30, 60)}" r="16" fill="#fff6d8" opacity=".75"/>
      <path d="${ridge(110, 45, 1)}" fill="${pal[2]}" opacity=".7"/><path d="${ridge(135, 35, 2)}" fill="${pal[3]}"/><path d="${ridge(160, 22, 3)}" fill="${pal[4]}"/>${trees}</svg>`;
  }

  // Zone mini-map: stylized base terrain + the game's revealed-area pieces cutting through fog.
  function zoneMap(z) {
    const h = hash(z.name);
    const r = (i, a, b) => a + (((h >> (i % 24)) ^ (i * 2654435761)) >>> 0) % 1000 / 1000 * (b - a);
    // Real revealed pieces were captured from Gideon, so only Gideon's scenarios use them.
    const gideon = ui.scenarioName === "today" || ui.scenarioName === "almost";
    let pieces = gideon && z.done > 0 ? (window.AZF_EXPLORED[z.mapID] || []).slice() : [];
    const real = pieces.length > 0;
    // Mockup: zones without real data, or with more discoveries than the snapshot, get approximate pieces.
    const explored = z.total > 0 && z.done === z.total;
    const need = explored ? 99 : z.done - (real ? pieces.length - 1 : 0);
    for (let i = 0; i < need && !explored; i++) pieces.push({ x: r(i * 3 + 1, 40, 760), y: r(i * 3 + 2, 30, 460), w: 230, h: 200 });
    const blobs = Array.from({ length: 14 }, (_, i) => `<ellipse cx="${r(i * 5 + 1, 0, 1002)}" cy="${r(i * 5 + 2, 0, 668)}" rx="${r(i * 5 + 3, 60, 170)}" ry="${r(i * 5 + 4, 40, 110)}" fill="${i % 3 ? "#7c9b55" : "#5f7f43"}" opacity=".55"/>`).join("");
    const holes = pieces.map(p => `<rect x="${p.x + 12}" y="${p.y + 12}" width="${p.w - 24}" height="${p.h - 24}" rx="40" fill="#000"/>`).join("");
    const id = "m" + h;
    const fog = explored ? "" : `<rect width="1002" height="668" fill="#1c140c" opacity=".78" mask="url(#${id})"/>`;
    return `<svg viewBox="0 0 1002 668" preserveAspectRatio="xMidYMid slice">
      <defs><filter id="${id}b"><feGaussianBlur stdDeviation="22"/></filter>
        <mask id="${id}"><rect width="1002" height="668" fill="#fff"/><g filter="url(#${id}b)">${holes}</g></mask></defs>
      <rect width="1002" height="668" fill="#c9b27a"/>${blobs}
      <path d="M0 ${r(90, 200, 450)} C 250 ${r(91, 100, 600)}, 600 ${r(92, 100, 600)}, 1002 ${r(93, 200, 500)}" stroke="#4f7fa8" stroke-width="14" fill="none" opacity=".8"/>
      <path d="M${r(94, 100, 900)} 0 C ${r(95, 0, 1002)} 300, ${r(96, 0, 1002)} 400, ${r(97, 100, 900)} 668" stroke="#8a6a3a" stroke-width="6" stroke-dasharray="14 8" fill="none"/>
      ${fog}</svg>`;
  }

  // =====================================================================================
  // Header
  // =====================================================================================
  function renderHeader() {
    const compact = ui.tab === "zones";
    $("#window").classList.toggle("compact", compact);
    $("#charName").textContent = CHAR.name;
    const line = $("#charLine");
    line.dataset.name = CHAR.name;
    line.innerHTML = `Level ${CHAR.level} ${CHAR.race} <span class="class-paladin">${CHAR.className}</span> · <span class="fac ${CHAR.faction}">${CHAR.faction}</span>`;
    $("#xpFill").style.width = `${(CHAR.xp / CHAR.xpMax * 100).toFixed(1)}%`;
    $("#xpText").textContent = `${CHAR.xp.toLocaleString()} / ${CHAR.xpMax.toLocaleString()} XP`;
    $("#charZone").innerHTML = `<b>${CHAR.subzone}</b>${CHAR.zone}`;
  }

  // =====================================================================================
  // Overview
  // =====================================================================================
  function nextForLevel(exclude) {
    return tracked.filter(z => z !== exclude && relevant(z) && z.state !== "complete" && z.minLevel != null && z.minLevel >= Math.max(1, CHAR.level - 2))
      .sort((a, b) => (b.state === "progress") - (a.state === "progress") || a.minLevel - b.minLevel
        || (b.continent === byName[CHAR.zone].continent) - (a.continent === byName[CHAR.zone].continent) || a.name.localeCompare(b.name))[0];
  }

  function renderOverview() {
    const cur = byName[CHAR.zone];
    const inProgress = tracked.filter(z => z.state === "progress").sort((a, b) => b.pct - a.pct);
    // Your zone whenever it's tracked, even claimed (owner, 2026-11-08).
    const hero = cur && cur.tracked ? cur : inProgress[0] || nextForLevel(cur);
    const heroKicker = hero === cur ? (cur.state === "complete" ? "Your zone · claimed" : cur.state === "untouched" ? "Start · your zone" : "Continue · your zone")
      : "Continue exploring";
    const goal = inProgress.find(z => z !== hero); // never repeat the Continue card
    const next = nextForLevel(hero);
    const p = totals.done / totals.areas;
    const W = (n) => (n / tracked.length * 100).toFixed(2);

    // Suggestions grouped by zone (step 6): each zone's picks mix areas, ready quests and
    // flight paths, the same picks as its Next up (Zones.NextUp).
    const leftText = (z) => z.cats.filter(c => c.done < c.total).map(c => `${c.total - c.done} ${c.unit}`).join(" · ");
    const groups = [];
    const addGroup = (z, why) => { if (!z || groups.some(g => g.z === z)) return; const items = nextItems(z, questsFor(z));
      if (items.length) groups.push({ z, why: `${why} · ${leftText(z)} left`, items }); };
    if (hero && hero.state !== "complete") addGroup(hero, hero === cur ? "Current zone" : "Continue");
    inProgress.filter(z => z !== hero).slice(0, 1).forEach(z => addGroup(z, "Closest to complete"));
    if (next) addGroup(next, "Next for your level");
    const tc = totals.cats;
    const pct1 = (p) => p == null ? "—" : `${(p * 100).toFixed(p > 0 && p < 0.1 ? 1 : 0)}%`;

    const CHIPS = 6;

    content.innerHTML = `<div class="scroll" id="scroll"><div class="overview">
      <div class="col">
        ${hero ? `<button class="hero focusable ${hero.state === "complete" ? "done" : ""}" data-open="${esc(hero.name)}" data-tip="<b>${esc(hero.name)}</b>Open the zone to see what's left.">
          <div class="art">${art(hero)}</div>
          <div class="body"><div class="kicker">${heroKicker}</div><div class="zname">${esc(hero.name)}</div>
            ${catbars(hero)}
            <div class="left">${hero.cats.filter(c => c.done < c.total).map(c => `<b>${c.total - c.done}</b> ${c.unit}`).join(" · ")} to go</div>
            </div>
          <div class="score mini">${progressArt(hero, { mini: true })}<b>${pctText(hero.pct)}</b></div></button>` : ""}
        ${goal ? `<button class="goal framed focusable" data-open="${esc(goal.name)}" data-tip="<b>Next goal</b>The in-progress zone closest to complete.">
          <span class="flag">Next goal</span>
<span>Finish <b>${esc(goal.name)}</b> — ${goal.left} to go</span>${catbars(goal, "sm")}</button>` : ""}
        <div class="plate ovplate" data-group><span>Suggested next</span></div>
        ${groups.length ? groups.map(g => `<div class="zonegroup framed"><header><b>${esc(g.z.name)}</b><span class="why">${g.why}</span></header>
          <div class="sitems">${g.items.slice(0, CHIPS).map(it => `<button class="sitem focusable" data-open="${esc(g.z.name)}" data-next="${esc(it.key)}"
            data-tip="<b>${esc(it.name)}</b>${esc(it.sub)} in ${esc(g.z.name)}. A opens it.">${catIcon(it.cat, "cimg sm")}<span class="sname ${it.diff ? `d-${it.diff}` : ""}">${esc(it.name)}</span>${it.cat === "quests" ? `<span class="slv">${esc(it.sub.replace("Quest · level ", "Lv "))}</span>` : ""}</button>`).join("")}</div></div>`).join("")
          : `<div class="note">Nothing to suggest: every area, quest and flight path you can do in your zones is done.</div>`}
      </div>
      <div class="col">
        <div class="tracked framed" data-tip-none>
          <div class="thead"><span>Tracked completion</span><b>${pct1(tc.pct)}</b></div>
          ${tc.list.map(c => `<button class="trow focusable ${c.pending ? "pending" : ""}" data-go="zones" data-tip="<b>${c.label}</b>${c.pending ? esc(c.pending) : `${c.done} of ${c.total} ${c.unit} the game confirms done, across ${c.zones} zones you can do.`}${c.note ? " " + esc(c.note) + "." : ""}">
            ${catIcon(c.key, "cimg sm")}<span class="tl">${c.label}</span>
            ${c.pending ? `<span class="tpend">${esc(c.pending)}</span>` : `<div class="gbar ${c.pct >= 1 ? "complete" : "progress"}"><i style="width:${(c.pct * 100).toFixed(1)}%"></i></div>
            <span class="tn"><b>${c.done.toLocaleString()}</b> / ${c.total.toLocaleString()}</span><span class="tp">${pct1(c.pct)}</span>`}</button>`).join("")}
          <button class="trow zrowstat focusable" data-go="zones" data-tip="<b>Zones</b>Complete: exploration, quests and flight paths all done. In progress: some done. Untouched: none yet.">
            <span class="cicon zicon">⚑</span><span class="tl">Zones</span>
            <div class="stack">${totals.complete ? `<i class="c" style="flex:${totals.complete}"></i>` : ""}${totals.progress ? `<i class="p" style="flex:${totals.progress}"></i>` : ""}${totals.untouched ? `<i class="u" style="flex:${totals.untouched}"></i>` : ""}</div>
            <span class="tn"><b>${totals.complete}</b> / ${totals.complete + totals.progress + totals.untouched}</span><span class="tp">done</span>
            <span class="zlegend"><i class="p"></i>${totals.progress} in progress · <i class="u"></i>${totals.untouched} untouched</span></button>
          <div class="tfoot">${["Each category counts equally" + (tc.list.some(c => c.pending) ? "; those without data are left out" : ""),
            ...tc.list.filter(c => c.note).map(c => c.key === "quests" ? `${c.unchecked} quests can't be checked yet` : esc(c.note))].join(" · ")}.</div>
        </div>
        <div class="plate ovplate" data-group><span>Atlas</span></div>
        ${miniAtlas()}
      </div>
    </div></div>`;
  }

  // ---- The Atlas (DESIGN.md "Zones: Atlas", Phase 10) ----
  // Each continent drawn from the client's own zone rectangles (atlas-rects.js: real data from
  // C_Map.GetMapRectOnMap). The rectangles are fractions of a 3:2 map, so x is stretched by 1.5.
  // A zone is a tile of its own art at its place (shrunk a little so neighbours don't touch);
  // cities are small plates on top. Zones the client gives no place are listed below.
  const CONT = { EK: "Eastern Kingdoms", KA: "Kalimdor" };
  // Layout (the addon's will be the same pure function): one tile size for zones and a
  // smaller pill for cities, each centred on its zone's true centre; overlapping tiles are then
  // pushed apart along the axis where they overlap least, a little at a time, until none
  // overlap. Directions between neighbours survive; sizes don't (the real rectangles overlap).
  const TILE = { w: 0.135, h: 0.082, cw: 0.12, ch: 0.032, gap: 0.01 };
  function relax(items) {
    for (let it = 0; it < 400; it++) {
      let moved = false;
      for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
        const A = items[i], B = items[j];
        const ox = (A.w + B.w) / 2 + TILE.gap - Math.abs(A.x - B.x), oy = (A.h + B.h) / 2 + TILE.gap - Math.abs(A.y - B.y);
        if (ox <= 0 || oy <= 0) continue;
        moved = true;
        if (ox < oy) { const s = (A.x < B.x || (A.x === B.x && i < j)) ? -1 : 1; A.x += s * ox / 2 * 0.5; B.x -= s * ox / 2 * 0.5; }
        else { const s = (A.y < B.y || (A.y === B.y && i < j)) ? -1 : 1; A.y += s * oy / 2 * 0.5; B.y -= s * oy / 2 * 0.5; }
      }
      if (!moved) break;
    }
  }
  function placesOf(code) {
    const list = tracked.map(z => ({ z, R: (window.AZF_RECTS || {})[z.mapID] })).filter(p => p.R && p.R.c === code);
    if (!list.length) return null;
    list.sort((a, b) => a.z.mapID - b.z.mapID); // a fixed order: the same layout every time
    list.forEach(p => { const [x0, x1, y0, y1] = p.R.r;
      p.x = (x0 + x1) / 2 * 1.5; p.y = (y0 + y1) / 2;
      p.w = TILE.w; p.h = TILE.h; }); // cities are full art cards too (owner, 2026-11-08)
    relax(list);
    const l = Math.min(...list.map(p => p.x - p.w / 2)), r = Math.max(...list.map(p => p.x + p.w / 2));
    const tp = Math.min(...list.map(p => p.y - p.h / 2)), bt = Math.max(...list.map(p => p.y + p.h / 2));
    const w = r - l, h = bt - tp;
    list.forEach(p => { p.box = { left: (p.x - p.w / 2 - l) / w * 100, top: (p.y - p.h / 2 - tp) / h * 100, width: p.w / w * 100, height: p.h / h * 100 }; });
    return { list, ratio: w / h };
  }  function atlasTile(p, visible, mini) {
    const z = p.z, b = p.box, here = z.name === CHAR.zone;
    const cls = `atile ${p.R.city ? "capital" : ""} ${z.state} ${here ? "here" : ""} ${visible && !visible.has(z.name) ? "dim" : ""}`;
    const style = `left:${b.left}%;top:${b.top}%;width:${b.width}%;height:${b.height}%`;
    // The Overview's chart: the zone's art in a small block, its progress as a thin bar.
    if (mini) return `<i class="${cls} withart" style="${style}"><span class="aart">${art(z)}</span>${z.state === "progress"
      ? `<span class="abar"><b style="width:${Math.round((z.pct || 0) * 100)}%"></b></span>` : ""}</i>`;
    const tip = `<b>${esc(z.name)}</b>${pctText(z.pct)} · ${z.cats.map(c => `${c.label} ${c.done}/${c.total}`).join(" · ")}${here ? " · You are here" : ""}`;
    return `<button class="${cls} focusable" style="${style}" data-open="${esc(z.name)}" data-tip="${tip}">
      <span class="aart">${art(z)}</span>
      <span class="aname">${esc(z.name)}</span><span class="apct">${z.state === "complete" ? pennant() : pctText(z.pct)}</span>
      ${z.state === "progress" ? `<span class="abar"><i style="width:${Math.round(z.pct * 100)}%"></i></span>` : ""}
      ${here ? `<span class="apin"></span>` : ""}</button>`;
  }
  function atlasMap(code, visible, mini) {
    const P = placesOf(code);
    if (!P) return "";
    return `<div class="amap ${mini ? "mini" : ""}" style="aspect-ratio:${P.ratio.toFixed(3)}">${P.list.map(p => atlasTile(p, visible, mini)).join("")}</div>`;
  }

  // Overview thumbnail: one focus stop that opens the full Atlas view.
  function miniAtlas() {
    return `<button class="minimap focusable" data-atlas data-tip="<b>Atlas</b>Every tracked zone at its place, coloured by progress. Press A to open.">
      <div class="atlasview mini">
        <div class="aregion ka">${atlasMap("KA", null, true)}</div>
        <div class="aregion sea">${tracked.filter(z => !(window.AZF_RECTS || {})[z.mapID]).map(z =>
          `<i class="atile isle ${z.state} ${z.name === CHAR.zone ? "here" : ""}" style="--p:${Math.round((z.pct || 0) * 100)}%"></i>`).join("")}</div>
        <div class="aregion ek">${atlasMap("EK", null, true)}</div>
        <span class="minicap">Open Atlas ›</span></div></button>`;
  }

  // Full Atlas (a Zones view): one sea chart (the painted backdrop) with Kalimdor's cards over
  // its left landmass and the Eastern Kingdoms' over its right; zones the game gives no place
  // (Zephras Isle: no rectangle on any map, probed 2026-11-08) sit in the open sea between,
  // marked as uncharted. Tiles outside the current filters are dimmed, not hidden.
  function atlasView(visible) {
    const unplaced = tracked.filter(z => !(window.AZF_RECTS || {})[z.mapID]);
    const loose = unplaced.map((z, i) => atlasTile({ z, R: { city: false }, box: { left: 0, top: 0, width: 100, height: 100 } }, visible)
      .replace('class="atile', 'class="atile isle'));
    return `<div class="atlasview">
      <div class="aregion ka"><div class="aname-plate">${CONT.KA}</div>${atlasMap("KA", visible)}</div>
      <div class="aregion sea">${loose.map(h => `<div class="isleslot">${h}<div class="islecap">Uncharted waters</div></div>`).join("")}</div>
      <div class="aregion ek"><div class="aname-plate">${CONT.EK}</div>${atlasMap("EK", visible)}</div></div>
      <div class="atlasfoot"><div class="legend"><span><i class="c"></i>Claimed</span><span><i class="p"></i>In progress</span><span><i class="u"></i>Untouched</span><span>● You are here</span></div></div>`;
  }
  // =====================================================================================
  // Zones catalogue
  // =====================================================================================
  function filteredZones() {
    const q = ui.search.trim().toLowerCase();
    const list = zones.filter(z => {
      if (ui.faction === "relevant" && !relevant(z)) return false;
      if (ui.status !== "all" && z.state !== ui.status) return false;
      if (ui.level === "appropriate" && !fitsLevel(z)) return false;
      if (q && !z.name.toLowerCase().includes(q)) return false;
      return true;
    });
    const name = (a, b) => a.name.localeCompare(b.name);
    const unknownLast = (f) => (a, b) => (a.pct == null) - (b.pct == null) || f(a, b) || name(a, b);
    const sorts = {
      recommended: (a, b) => (a.minLevel ?? 999) - (b.minLevel ?? 999) || (a.tracked ? 0 : 1) - (b.tracked ? 0 : 1) || name(a, b),
      alphabetical: name, highest: unknownLast((a, b) => b.pct - a.pct), lowest: unknownLast((a, b) => a.pct - b.pct),
      closest: unknownLast((a, b) => (a.state === "complete") - (b.state === "complete") || b.pct - a.pct),
    };
    return list.sort(sorts[ui.sort]);
  }
  function groupsOf(list) {
    if (ui.sort !== "recommended") return [{ title: null, items: list }];
    const key = (z) => {
      if (z.minLevel == null) return z.tracked ? "Level unknown" : "Cities and other places";
      if (z.minLevel < 10) return "Levels 1–10";
      const b = Math.floor(z.minLevel / 10) * 10;
      return `Levels ${b}–${b + 10}`;
    };
    const out = [];
    for (const z of list) { const k = key(z); if (!out.length || out[out.length - 1].title !== k) out.push({ title: k, items: [] }); out[out.length - 1].items.push(z); }
    return out;
  }
  // Info text adds what the control doesn't already show; empty if there's nothing to add.
  function zoneTip(z) {
    if (!z.tracked) return `<b>${esc(z.name)}</b>Exploration isn't tracked here: the game has no Explore achievement for this zone.`;
    const last = S.milestones.filter(m => m.zone === z.name).sort((a, b) => b.t - a.t)[0];
    if (last) return `<b>${esc(z.name)}</b>Last discovery: ${last.kind === "zone" ? "zone completed" : esc(last.area)} · ${fmtTime(last.t)}`;
    if (z.state === "progress") return `<b>${esc(z.name)}</b>Discovered before Azerfolio was installed.`;
    return "";
  }
  function card(z, rec) {
    return `<button class="zcard focusable ${z.state}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
      <div class="art">${art(z)}${window.AZF_ART && (window.AZF_ART.ids.includes(z.mapID) || window.AZF_ART.fallback) ? "" : `<span class="artlabel">ART PLACEHOLDER</span>`}${z.state === "complete" ? `<span class="badge claimed">${pennant()}</span>` : ""}</div>
      ${rec ? `<span class="ribbon">Recommended next</span>` : ""}
      <div class="body">
        <div class="top"><span class="name">${esc(z.name)}</span><span class="pct">${z.tracked ? (z.state === "complete" ? "✓ " : "") + pctText(z.pct) : "—"}</span></div>
        ${catbars(z)}
        <div class="meta"><span>Lv ${shortLv(z)}</span>${facBadge(z)}${fitsLevel(z) && z.state !== "complete" ? `<span class="fittag">Your level</span>` : ""}
          ${z.tracked ? "" : `<span class="n">not tracked</span>`}</div></div></button>`;
  }
  function row(z, compact) {
    if (compact) return `<button class="zrow focusable ${z.state} ${ui.selected === z.name ? "selected" : ""}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
      <span class="thumb">${art(z)}</span><span class="areas"><span class="zname">${esc(z.name)}</span>${z.tracked ? catbars(z, "sm") : `<span class="note">not tracked</span>`}</span>
      <span class="lv">Lv ${shortLv(z)}${levelbar(z)}</span><span class="pctcol">${pctText(z.pct)}</span></button>`;
    return `<button class="zrow focusable ${z.state}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
      <span class="thumb">${art(z)}</span><span class="zname">${esc(z.name)} ${facBadge(z)}</span>
      <span class="lv">Lv ${shortLv(z)}${levelbar(z)}</span>
      <span class="areas">${z.tracked ? catbars(z, "sm") : `<span class="note">Nothing tracked here</span>`}</span>
      <span class="pctcol">${pctText(z.pct)}</span></button>`;
  }
  const VIEWS = () => ui.wide ? [["list", "☰", "List"], ["atlas", "◈", "Atlas"]] : [["cards", "▦", "Cards"], ["list", "☰", "List"], ["atlas", "◈", "Atlas"]];
  function toolbar(count) {
    const sel = (key) => `<button class="select focusable" data-cycle="${key}" data-tip="<b>${OPTIONS[key].label}</b>Press A to choose.">${OPTIONS[key].label}: <b>${optLabel(key)}</b><span class="arr">▾</span></button>`;
    return `<div class="toolbar">
      <div class="seg">${STATUS.map(([v, l]) => `<button class="focusable ${ui.status === v ? "on" : ""}" data-status="${v}" data-tip="<b>${l}</b>Show ${l.toLowerCase()} zones.">${l}</button>`).join("")}</div>
      ${sel("faction")}${sel("level")}${sel("sort")}
      <span class="count">${count} zones</span><span class="spacer"></span>
      <label class="search focusable" data-search data-tip="<b>Search</b>Press A to type (on-screen keyboard on controller).">🔍<input id="searchInput" placeholder="Search" value="${esc(ui.search)}" tabindex="-1"></label>
      <div class="viewtoggle">${VIEWS().map(([v, icon, l]) => `<button class="focusable ${ui.view === v ? "on" : ""}" data-view="${v}" title="${l}" data-tip="<b>${l} view</b>Y cycles the views.">${icon}</button>`).join("")}</div>
    </div>`;
  }

  function renderZones() {
    if (!VIEWS().some(v => v[0] === ui.view)) ui.view = ui.wide ? "list" : "cards";
    const list = filteredZones();
    const groups = groupsOf(list);
    const rec = nextForLevel(null);
    const empty = `<div class="empty"><b>No zones match</b>Try a different status or filter, or clear the search.</div>`;
    const body = (compact) => list.length === 0 ? empty : groups.map(g => `${g.title ? `<div class="group-h" data-group>${g.title} <small>${g.items.filter(z => z.state === "complete").length} of ${g.items.filter(z => z.tracked).length} complete</small></div>` : ""}
      ${!compact && ui.view === "cards" ? `<div class="grid">${g.items.map(z => card(z, rec && z.name === rec.name)).join("")}</div>` : `<div class="rows">${g.items.map(z => row(z, compact)).join("")}</div>`}`).join("");
    if (ui.view === "atlas") {
      content.innerHTML = `${toolbar(list.length)}<div class="scroll" id="scroll">${atlasView(new Set(list.map(z => z.name)))}</div>`;
    } else if (ui.wide) {
      if (!ui.selected || !list.some(z => z.name === ui.selected)) ui.selected = (list.find(z => z.name === CHAR.zone) || list[0] || {}).name || null;
      content.innerHTML = `${toolbar(list.length)}<div class="split"><div class="listpane"><div class="scroll" id="scroll">${body(true)}</div></div><div class="detailpane" id="detailpane"></div></div>`;
      renderDetailInto($("#detailpane"), ui.selected ? byName[ui.selected] : null, { back: false });
    } else {
      content.innerHTML = `${toolbar(list.length)}<div class="scroll" id="scroll">${body(false)}</div>`;
    }
    // The toolbar can wrap; start the list right below it.
    const tb = $(".toolbar").offsetHeight;
    ($(".split") || $("#scroll")).style.top = tb + "px";
    wireSearch();
  }
  function wireSearch() {
    const input = $("#searchInput");
    if (!input) return;
    input.addEventListener("input", () => { ui.search = input.value; const pos = input.selectionStart; render(); const i = $("#searchInput"); i.focus(); i.setSelectionRange(pos, pos); });
    input.addEventListener("keydown", (e) => { if (e.key === "Escape" || e.key === "Enter") { e.stopPropagation(); input.blur(); setFocus($("[data-search]")); } });
  }

  // =====================================================================================
  // Zone detail
  // =====================================================================================
  function renderDetailInto(container, z, opts) {
    if (!z) { container.innerHTML = `<div class="empty"><b>Select a zone</b></div>`; return; }
    const page = ui.detailPage && (ui.detailPage !== "explore" || z.total) ? ui.detailPage : null;
    const repId = page && page.startsWith("rep:") ? Number(page.slice(4)) : null; // a faction's page
    const pageTitle = repId ? `${esc(REP_NAMES[repId])}<span class="crumb"> · ${esc(z.name)}</span>` : page ? `${CATS[page].label}<span class="crumb"> · ${esc(z.name)}</span>` : "";
    // Dev bar "Preview claimed": the same zone with every category done (design preview only).
    if (!page && ui.claimPreview && z.tracked) z = { ...z, pct: 1, state: "complete", unchecked: false,
      cats: z.cats.map(c => ({ ...c, done: c.total, pct: 1, unchecked: 0, nodes: c.nodes && c.nodes.map(n => ({ ...n, known: true })) })), criteria: z.criteria.map(c => ({ ...c, done: true })), done: z.total };
    // The dashboard's score, right side of the taller header (design round 2): the zone's %,
    // one line per category, and why it can't be claimed yet if so.
    const zscore = !page && z.tracked ? `<div class="zscore ${z.state}">
        <div class="zpct">${z.state === "complete" ? "Claimed" : pctText(z.pct)}</div>
        <div class="zcats">${z.cats.map(c => `<span class="${catState(c)}">${catIcon(c.key, "cimg sm")}${c.done}/${c.total}</span>`).join("")}</div>
        ${z.unchecked && z.state !== "complete" ? `<div class="znote">${z.cats.filter(c => c.unchecked).map(c => `${c.unchecked} ${c.unit} can't be checked yet`).join(" · ")}</div>` : ""}
      </div>` : "";
    const next = z.tracked ? tracked.filter(x => x !== z && relevant(x) && x.state !== "complete" && x.minLevel != null && z.minLevel != null && x.minLevel > z.minLevel)
      .sort((a, b) => a.minLevel - b.minLevel || (b.continent === z.continent) - (a.continent === z.continent) || a.name.localeCompare(b.name))[0] : null;
    const backLabel = page ? `‹ ${esc(z.name)}` : "‹ Zones";
    const backTip = page ? `Back to the ${esc(z.name)} overview (B)` : "Back to all zones (B)";
    const hero = `<div class="detail-hero ${page ? "slim" : ""}">${art(z)}<div class="shade"></div>
        ${opts.back || page ? `<button class="btn dark back focusable" data-back data-tip="${backTip}">${backLabel}</button>` : ""}
        <div class="info"><div><h1>${page ? pageTitle : esc(z.name)}</h1>
          <div class="sub"><span>${levels(z)}</span>${facBadge(z)}<span>${esc(z.continent)}</span>
          ${next && !page ? `<span class="next">· Next: ${esc(next.name)} (${shortLv(next)})</span>` : ""}</div></div>
          ${repId ? `<div class="pagescore">${((repFor(z) || []).find(x => x.id === repId) || {}).label || ""}</div>` : page ? `<div class="pagescore">${catOf(z, page) ? `${catOf(z, page).done} of ${catOf(z, page).total}<b>${pctText(catOf(z, page).pct)}</b>` : ""}</div>` : zscore}</div></div>`;
    const scrollId = opts.back ? "scroll" : "detailscroll";
    let body;
    if (!page) body = `<div class="detail-body dash"><div class="scroll" id="${scrollId}">${dashboard(z)}</div></div>`;
    else if (page === "explore") body = `<div class="detail-body">
        <div class="scroll" id="${scrollId}">${explorePage(z)}</div>
        <aside class="mapside">
          <div class="zonemap">${zoneMap(z)}</div>
          <div class="mapcap"><span class="legend"><span><i style="background:#c9b27a"></i>Revealed</span><span><i style="background:#3a2e22"></i>Unexplored</span></span>
            <button class="btn focusable" data-map data-tip="<b>World map</b>Open the world map at ${esc(z.name)}.">World map</button></div>
          <div class="focusinfo" id="focusinfo"></div>
        </aside></div>`;
    else body = `<div class="detail-body full"><div class="scroll" id="${scrollId}">${repId ? repPage(z, repId) : page === "quests" ? questSection(z) : flightSection(z)}</div></div>`;
    container.innerHTML = `<div class="detail ${page ? "paged" : ""}">${hero}${body}</div>`;
    if (page === "explore") showFocusInfo(z, z.criteria.find(c => !c.done) || z.criteria[0]);
  }
  function explorePage(z) {
    const remaining = z.criteria.filter(c => !c.done), found = z.criteria.filter(c => c.done);
    const check = (c) => `<button class="check focusable ${c.done ? "done" : "todo"} ${ui.newCrit === c.id ? "new" : ""}" data-crit="${c.id}"><span class="mark">${c.done ? "✓" : ""}</span><span>${esc(c.name)}</span></button>`;
    return `${remaining.length ? `<h2 class="section" data-group>To discover <small>${remaining.length}</small></h2>
      <div class="checklist">${remaining.map(check).join("")}</div>` : `<div class="note">Fully explored: every area the game lists for this zone is discovered. ✦</div>`}
      <h2 class="section" data-group>Discovered <small>${found.length}</small></h2>
      ${found.length ? `<div class="checklist">${found.map(check).join("")}</div>` : `<div class="note">Nothing yet — head out and explore.</div>`}`;
  }

  // ---- Zone dashboard: the zone's standard (progress art) and one tile per category ----
  function dashboard(z) {
    if (!z.tracked) return `<div class="empty"><b>Nothing to track here yet</b>No exploration, quests or flight paths Azerfolio can verify in ${esc(z.name)}.</div>`;
    const tile = (key, inner, opts = {}) => {
      const c = catOf(z, key), d = CATS[key];
      const st = c ? catState(c) : "na";
      return `<button class="ctile ${st} ${opts.open ? "focusable" : "focusable inert"}" ${opts.open ? `data-page="${key}"` : `data-na="${key}"`}
        data-tip="<b>${d.label}</b>${esc(opts.tip || "")}">
        <div class="thead">${catIcon(key)}<span class="tname">${d.label}</span>
          ${c ? `<span class="tcount">${c.done} <small>of ${c.total}</small></span><span class="tpct">${pctText(c.pct)}</span>` : ""}</div>
        ${c && !opts.noBar ? `<div class="tbar ${st}"><i style="width:${(c.pct * 100).toFixed(1)}%"></i></div>` : ""}
        <div class="tbody">${inner}</div>
      </button>`; // no A hint (owner, round 3: obvious)
    };
    const ex = catOf(z, "explore");
    const exTile = ex ? tile("explore", (() => {
      const todo = z.criteria.filter(c => !c.done);
      return `${pips(z)}<div class="tline">${todo.length ? `Next: <b>${esc(todo[0].name)}</b>${todo.length > 1 ? ` and ${todo.length - 1} more` : ""}` : "Every area discovered ✦"}</div>`;
    })(), { open: "Areas", noBar: true, tip: `${ex.done} of ${ex.total} areas discovered. A shows the list and the map.` })
      : tile("explore", `<div class="tline dim">The game has no Explore achievement for ${esc(z.name)}.</div>`, { tip: "Not tracked here." });
    const q = catOf(z, "quests"), r = questsFor(z);
    const qTile = z.questsMissing ? tile("quests", `<div class="tline dim">${ui.quests === "building" ? "Reading QuestieDB…" : "Needs the QuestieDB addon, which isn't loaded."}</div>`, { tip: "Quests unavailable." })
      : !q ? tile("quests", `<div class="tline dim">${ui.quests === "horde" ? "None of the quests here are for this character." : `QuestieDB lists no quests for you in ${esc(z.name)}.`}</div>`, { tip: "Left out of the zone's progress." })
      : tile("quests", r.status === "ready" ? `<div class="tstats"><span><b class="hot">${r.ready.length}</b> ready now</span><span><b>${r.stories.length}</b> storylines going</span><span><b>${r.finished.length}</b> finished</span></div>
          <div class="tline">Next: <b class="d-${r.ready[0] ? r.ready[0].diff : ""}">${r.ready[0] ? esc(r.ready[0].name) : "—"}</b>${q.unchecked ? ` <span class="dim">· ${q.unchecked} unchecked</span>` : ""}</div>`
          : `<div class="tline dim">${q.total - q.done} quests to go${q.unchecked ? ` · ${q.unchecked} unchecked` : ""}. (Mockup: the list is sampled only for Elwynn.)</div>`,
        { open: "Quests", tip: `${q.done} of ${q.total} quests done. A shows Ready now and the storylines.` });
    const f = catOf(z, "flights");
    const fTile = f ? tile("flights", `<div class="tline">${f.nodes.map(n => `<span class="fnode ${n.known ? "on" : ""}">${n.known ? "✓" : "✈"} ${esc(n.name)}</span>`).join("")}</div>`,
        { open: "Flight paths", tip: `${f.done} of ${f.total} flight paths known.` })
      : tile("flights", `<div class="tline dim">No flight master for you in ${esc(z.name)}.</div>`, { tip: "Left out of the zone's progress." });
    // Round 3: the zone comes alive as it fills (the art behind the standard goes from grey and
    // dim to full colour), three square tiles in a row, and "Next up" under them.
    const p = z.pct || 0;
    const alive = `filter: saturate(${(0.12 + 0.88 * p).toFixed(2)}) brightness(${(0.3 + 0.22 * p).toFixed(2)}) blur(1.5px)`;
    return `<div class="dashgrid">
      <div class="standard ${z.state}" data-tip-none><div class="sbg" style="--alive:1"><div class="sbgi" style="${alive}">${art(z)}</div></div>${progressArt(z, { animate: true })}</div>
      <div class="dashright"><div class="tiles row3">${exTile}${qTile}${fTile}</div>${nextUp(z, r)}${repSection(z)}</div></div>`;
  }

  // ---- Zone reputation (Phase 11, spec §7.8) ----
  // What Systems/Reputation will hand the page: the zone's factions this character gets game
  // data for, each with its reaction, progress into it (standing - threshold, out of next -
  // threshold), met and at war. Nil when there are none (or QuestieDB isn't there): no section.
  function repFor(z) {
    if (ui.quests === "missing" || ui.quests === "building") return null;
    const list = (REP_ZONES[z.name] || []).filter(([id]) => S.rep && S.rep[id]).map(([id, quests]) => {
      const [standing, met, atWar] = S.rep[id];
      const reaction = REP_BOUNDS.findIndex(b => b && standing >= b[0] && standing < b[1]);
      const [lo, hi] = REP_BOUNDS[reaction];
      const rival = (REP_RIVALS[z.name] || []).map(p => p[0] === id ? p[1] : p[1] === id ? p[0] : null).find(x => x != null);
      return { id, name: REP_NAMES[id], reaction, label: REACTIONS[reaction], next: REACTIONS[reaction + 1] || null,
        into: standing - lo, span: hi - lo, met, atWar, quests, rival: rival != null && S.rep[rival] ? REP_NAMES[rival] : null };
    });
    // Order: the zone's main faction first (most raising quests here), rivals kept together.
    list.sort((a, b) => b.quests - a.quests);
    const out = [];
    list.forEach(f => { if (out.includes(f)) return; out.push(f); const r = f.rival && list.find(x => x.name === f.rival); if (r && !out.includes(r)) out.push(r); });
    return out.length ? out : null;
  }
  // The reaction ladder: eight equal steps, Hated to Exalted, in the client's reaction colours.
  // Past steps full, the current one filled by progress into it, later ones empty.
  // Round 3 (owner, 2026-11-08: "not liking the pill boxes"): one gilded bar across the whole
  // reaction range, notched where the reaction changes. The fill runs through each reaction's
  // colour up to where you stand; a bright marker sits at your position, and the notch you're
  // heading for is lit. Scale: "equal" (each reaction an eighth, like the ladder) or "true"
  // (by standing, -42,000 to 42,999: Hated takes 42%, Hostile to Neutral 3.5% each).
  function repSegments(scale) {
    if (scale === "true") {
      const lo = REP_BOUNDS[1][0], all = REP_BOUNDS[8][1] - lo;
      return [1, 2, 3, 4, 5, 6, 7, 8].map(r => ({ r, x: (REP_BOUNDS[r][0] - lo) / all * 100, w: (REP_BOUNDS[r][1] - REP_BOUNDS[r][0]) / all * 100 }));
    }
    return [1, 2, 3, 4, 5, 6, 7, 8].map(r => ({ r, x: (r - 1) * 12.5, w: 12.5 }));
  }
  // Position on the bar (0..100) of a standing, on the equal-steps or true scale.
  function repPos(standing, scale) {
    const r = reactionOf(standing), segs = repSegments(scale), s = segs[r - 1], [lo, hi] = REP_BOUNDS[r];
    return s.x + s.w * (r === 8 ? 1 : (standing - lo) / (hi - lo));
  }
  // reach (optional): the standing the quests you haven't done would bring you to, drawn as a
  // hatched ghost past your marker with a dashed end mark (Reputation tab's faction page).
  function repBar(f, scale, reach) {
    const segs = repSegments(scale), cur = segs[f.reaction - 1];
    const into = f.reaction === 8 ? 1 : f.into / f.span;
    const pos = cur.x + cur.w * into;
    const fill = segs.filter(s => s.r <= f.reaction).map(s => {
      const w = s.r < f.reaction ? s.w : s.w * into;
      return `<i class="r${s.r}" style="left:${s.x.toFixed(2)}%;width:${w.toFixed(2)}%"></i>`; }).join("");
    let ghost = "";
    if (reach != null && reach > f.standing) {
      const end = repPos(reach, scale), rr = reactionOf(reach);
      ghost = `<b class="ghost r${rr}" style="left:${pos.toFixed(2)}%;width:${(end - pos).toFixed(2)}%"></b><s class="reachmark" style="left:${end.toFixed(2)}%"></s>`;
    }
    const notches = segs.slice(1).map(s => `<u class="${s.r === f.reaction + 1 ? "next" : s.r <= f.reaction ? "past" : ""}" style="left:${s.x.toFixed(2)}%"></u>`).join("");
    return `<span class="repbar ${scale}"><span class="rtrack">${fill}${ghost}${notches}<em class="r${f.reaction}" style="left:${pos.toFixed(2)}%"></em></span></span>`;
  }
  const reactionOf = (standing) => standing >= 42000 ? 8 : REP_BOUNDS.findIndex(b => b && standing >= b[0] && standing < b[1]);
  function ladder(f) {
    if (ui.repBar !== "ladder") return repBar(f, ui.repBar === "true" ? "true" : "equal");
    return `<span class="ladder">${[1, 2, 3, 4, 5, 6, 7, 8].map(r => {
      const fill = r < f.reaction ? 100 : r > f.reaction ? 0 : f.reaction === 8 ? 100 : f.into / f.span * 100;
      return `<i class="r${r} ${r === f.reaction ? "cur" : ""}"><b style="width:${fill.toFixed(1)}%"></b></i>`; }).join("")}</span>`;
  }
  const repTags = (f) => [f.met ? "" : `<span class="unmet">Not met yet</span>`, f.atWar ? `<span class="war">⚔ At war</span>` : "",
    f.rival ? `<span class="rival">⇄ Rival of ${esc(f.rival)}</span>` : ""].filter(Boolean).join("");
  const num = (n) => n.toLocaleString("en-US");
  // Not a completion category: no %, no gold, no state colours. The bar uses the client's
  // reaction colours (FACTION_BAR_COLORS), like the game's own Reputation window.
  function repSection(z) {
    const list = repFor(z);
    if (!list) return ""; // hidden in zones without a zone faction
    // Ledger (design round 2): one line per faction, a slim gold title instead of a plate.
    const row = (f) => {
      const exalted = f.reaction === 8;
      // Info line (one line): reaction, what's left to the next one, what A shows. The tags
      // already say met, at war and rival.
      const tip = `<b>${esc(f.name)}</b>${f.label}${exalted ? "" : `, ${num(f.span - f.into)} to ${f.next}`}. A shows the ${f.quests} quests here that raise it.`;
      return `<button class="frep focusable r${f.reaction} ${f.met ? "met" : "unmet"}" data-rep="${f.id}" data-page="rep:${f.id}" data-tip="${tip}">
        <span class="fwho"><span class="fname">${esc(f.name)}</span><span class="ftags">${repTags(f)}</span></span>
        <span class="freact">${f.label}</span>${ladder(f)}
        <span class="fnum">${exalted ? "" : `${num(f.into)} / ${num(f.span)}`}</span></button>`;
    };
    return `<div class="repsec"><div class="rephead"><span>Reputation</span><small>Not part of the zone's progress</small></div>
      <div class="flist">${list.map(row).join("")}</div></div>`;
  }
  // A faction's page: the zone's quests that raise it (the addon: Quests' objectives filtered
  // by reputationReward, with their real state). Amounts are QuestieDB's base values.
  function repPage(z, id) {
    const f = (repFor(z) || []).find(x => x.id === id);
    if (!f) return `<div class="qnote">No standing for this faction.</div>`;
    const qs = REP_QUESTS[`${z.name}|${id}`];
    let html = `<div class="repsum frep r${f.reaction} ${f.met ? "met" : "unmet"}"><span class="fwho"><span class="fname">${esc(f.name)}</span><span class="ftags">${repTags(f)}</span></span>
      <span class="freact">${f.label}</span>${ladder(f)}<span class="fnum">${f.reaction === 8 ? "" : `${num(f.into)} / ${num(f.span)} · ${num(f.span - f.into)} to ${f.next}`}</span></div>`;
    if (f.rival) html += `<div class="qnote rivalnote">⇄ Rivals: quests here that raise ${esc(f.name)} lower ${esc(f.rival)}, and the other way round.</div>`;
    if (!qs) return html + `<div class="qnote">(Mockup: the quest list is sampled only for Felwood, Stranglethorn, Desolace and Brood of Nozdormu in Silithus.)</div>`;
    const chip = (q) => { const [qid, name, ql, rl, amt] = q, d = difficulty(ql, CHAR.level), later = rl > CHAR.level;
      return `<button class="qchip repq focusable d-${later ? "grey" : d} ${later ? "later" : ""}" data-rq="${qid}"
        data-tip="<b>${esc(name)}</b>Level ${ql}${later ? `, from level ${rl}` : ""}. About +${num(amt)} ${esc(f.name)} (QuestieDB's base value; the game may give more).">
        <span class="lvl">${ql}</span><span class="qn">${esc(name)}</span><span class="amt">~+${num(amt)}</span></button>`; };
    const now = qs.filter(q => q[3] <= CHAR.level), later = qs.filter(q => q[3] > CHAR.level);
    if (now.length) html += `<h2 class="section" data-group>Up to your level <small>${now.length}</small></h2><div class="readygrid">${now.map(chip).join("")}</div>`;
    if (later.length) html += `<h2 class="section" data-group>Later <small>${later.length} · from level ${Math.min(...later.map(q => q[3]))}</small></h2><div class="readygrid">${later.map(chip).join("")}</div>`;
    return html + `<div class="qfoot"><span class="qnote">From QuestieDB. Amounts are its base values, so approximate; done and locked states come from the Quests page in the addon.</span></div>`;
  }

  // ==== Reputation tab (Phase 12 proposal) ====
  // What a Reputation.All() would hand the tab: every faction with game data, its standing, the
  // quest sources that raise it, and the reach (standing plus the base amounts of the one-time
  // quests you haven't done and can do; repeatables left out, since they have no end). The
  // mockup treats every quest as not done (SAMPLE); the addon uses the Quests page's states.
  function allFactions() {
    if (!S.rep) return [];
    return REP_ALL.filter(f => S.rep[f.id]).map(f => {
      const [standing, met, atWar] = S.rep[f.id];
      const reaction = reactionOf(standing), [lo, hi] = REP_BOUNDS[reaction];
      const usable = f.src.filter(s => s[4] !== false);
      const gain = usable.reduce((n, s) => n + s[3], 0), quests = usable.reduce((n, s) => n + s[2], 0);
      const reach = usable.length && reaction < 8 ? Math.min(standing + gain, 42999) : null;
      const rivalId = REP_RIVAL_OF[f.id];
      return { ...f, standing, met, atWar, reaction, label: REACTIONS[reaction], next: REACTIONS[reaction + 1] || null,
        into: standing - lo, span: hi - lo, left: reaction === 8 ? 0 : hi - standing, quests, gain, reach,
        reachReaction: reach != null ? reactionOf(reach) : null,
        rival: rivalId && S.rep[rivalId] ? REP_NAMES[rivalId] : null, rivalId: rivalId && S.rep[rivalId] ? rivalId : null,
        session: (S.repGains || {})[f.id] || 0, watched: S.watched === f.id || ui.watched === f.id };
    });
  }
  function repShown() {
    const all = allFactions();
    const list = all.filter(f => ui.repFilter === "all" || (ui.repFilter === "met" ? f.met : !f.met));
    // Closest: met factions first (an unmet one only sits at its starting standing), Exalted last.
    if (ui.repSort === "closest") list.sort((a, b) => (a.reaction === 8) - (b.reaction === 8) || b.met - a.met || a.left - b.left || a.name.localeCompare(b.name));
    if (ui.repSort === "az") list.sort((a, b) => a.name.localeCompare(b.name));
    return { all, list };
  }
  const SRC_KIND = { zone: "Zone", dungeon: "Dungeon", raid: "Raid", bg: "Battleground", prof: "Profession", class: "Class quests", event: "Event" };
  const SRC_GLYPH = { dungeon: "⛫", raid: "☠", bg: "⚑", prof: "⚒", class: "✦", event: "✪", none: "?" };
  function repThumb(zoneName, kind) {
    const z = zoneName && byName[zoneName];
    return z ? `<span class="fthumb">${art(z)}</span>` : `<span class="fthumb glyph-k k-${kind || "none"}">${SRC_GLYPH[kind] || "?"}</span>`;
  }
  const tabTags = (f) => repTags(f) + (f.session ? `<span class="gain">+${num(f.session)} today</span>` : "") + (f.watched ? `<span class="watch">Watched</span>` : "");
  function repTabRow(f) {
    const exalted = f.reaction === 8;
    const how = f.group === "none" ? "No quests are known to raise it." : `A shows where to raise it.`;
    const tip = `<b>${esc(f.name)}</b>${f.label}${exalted ? "" : `, ${num(f.left)} to ${f.next}`}${f.met ? "" : " (not met yet)"}. ${how}`;
    const sel = ui.wide && ui.repSel === f.id ? "selected" : "";
    return `<button class="frep tabrow focusable r${f.reaction} ${f.met ? "met" : "unmet"} ${sel}" data-faction="${f.id}" data-tip="${tip}">
      ${repThumb(f.home, (f.src[0] || [])[0])}
      <span class="fwho"><span class="fname">${esc(f.name)}</span><span class="ftags">${tabTags(f)}</span></span>
      <span class="freact">${f.label}</span>${ladder(f)}
      <span class="fnum">${exalted ? "" : ui.repSort === "closest" ? `${num(f.left)} to ${f.next}` : `${num(f.into)} / ${num(f.span)}`}</span></button>`;
  }
  // The standing at a glance: how many factions sit at each reaction, Hated to Exalted. Each
  // cell is a painted plaque (frame-plaque) with the reaction's emblem (rep-<reaction>, metal
  // climbing from iron to gold); stand-in glyphs in the same metals until the art exists.
  const REP_EMBLEM = ["", "✗", "⚔", "⛉", "⚖", "✦", "❦", "✶", "♛"];
  const emblem = (r) => { const key = `rep-${REACTIONS[r].toLowerCase()}`;
    return hasChrome(key) ? `<img class="demb" src="chrome-art/${key}.png" alt="">` : `<span class="demb standin m${r}">${REP_EMBLEM[r]}</span>`; };
  function repDist(all) {
    const n = (r) => all.filter(f => f.reaction === r).length;
    const ex = n(8), met = all.filter(f => f.met).length;
    return `<div class="repdist">${[1, 2, 3, 4, 5, 6, 7, 8].map(r => `<span class="dcell r${r} ${n(r) ? "" : "zero"}">${emblem(r)}<span class="dtxt"><b>${n(r)}</b>${REACTIONS[r]}</span></span>`).join("")}
      <span class="dsum"><span>Met <b>${met}</b> of ${all.length}</span><span>Exalted <b>${ex}</b> of ${all.length}</span></span></div>`;
  }
  const REP_FILTERS = [["all", "All"], ["met", "Met"], ["unmet", "Not met yet"]];
  function renderReputation() {
    const { all, list } = repShown();
    const tools = `<div class="toolbar">
      <div class="seg">${REP_FILTERS.map(([v, l]) => `<button class="focusable ${ui.repFilter === v ? "on" : ""}" data-rfilter="${v}" data-tip="<b>${l}</b>Show ${v === "all" ? "every faction" : v === "met" ? "the factions you've met" : "the factions you haven't met yet"}.">${l}</button>`).join("")}</div>
      <button class="btn focusable" data-cycle="repSort" data-tip="<b>Sort</b>${optLabel("repSort")}. Y cycles it.">Sort: ${optLabel("repSort")}</button>
      <span class="spacer"></span><span class="count">${list.length} factions</span></div>${repDist(all)}`;
    let body;
    if (!list.length) body = `<div class="empty"><b>No factions here</b>Try another filter.</div>`;
    else if (ui.repSort === "group") body = REP_GROUPS.map(([g, title]) => {
      const items = list.filter(f => f.group === g); if (!items.length) return "";
      return `<div class="group-h" data-group>${title} <small>${items.filter(f => f.met).length} of ${items.length} met</small></div><div class="rows">${items.map(repTabRow).join("")}</div>`;
    }).join("");
    else body = `<div class="group-h" data-group>${ui.repSort === "closest" ? "Closest to the next reaction" : "A–Z"} <small>${list.length}</small></div><div class="rows">${list.map(repTabRow).join("")}</div>`;
    if (ui.wide) {
      if (!ui.repSel || !list.some(f => f.id === ui.repSel)) ui.repSel = (list[0] || {}).id || null;
      content.innerHTML = `<div class="rephdr">${tools}</div><div class="split repsplit"><div class="listpane"><div class="scroll" id="scroll">${body}</div></div><div class="detailpane" id="detailpane"></div></div>`;
      renderFactionInto($("#detailpane"), all.find(f => f.id === ui.repSel), { back: false });
    } else {
      content.innerHTML = `<div class="rephdr">${tools}</div><div class="scroll" id="scroll">${body}</div>`;
    }
    ($(".split") || $("#scroll")).style.top = $(".rephdr").offsetHeight + "px";
  }
  // A faction's page: banner (its main zone's art), standing with the reach, the game's
  // description, the rival, and where to raise it. A on a zone opens that zone's faction page.
  function renderFactionInto(container, f, opts) {
    if (!f) { container.innerHTML = `<div class="empty"><b>Select a faction</b></div>`; return; }
    const z = f.home && byName[f.home];
    const groupLabel = REP_GROUPS.find(g => g[0] === f.group)[1];
    const hero = `<div class="detail-hero slim fhero">${z ? art(z) : `<div class="plainart"></div>`}<div class="shade"></div>
      ${opts.back ? `<button class="btn dark back focusable" data-back data-tip="Back to all factions (B)">‹ Reputation</button>` : ""}
      <div class="info"><div><h1>${esc(f.name)}</h1><div class="sub"><span>${groupLabel}</span>${z ? `<span>· Raised most in ${esc(f.home)}</span>` : ""}</div></div>
      <div class="pagescore freact-big r${f.reaction}">${f.label}</div></div></div>`;
    const exalted = f.reaction === 8;
    let html = `<div class="repsum frep r${f.reaction} ${f.met ? "met" : "unmet"}"><span class="fwho"><span class="fname">Your standing</span><span class="ftags">${tabTags(f)}</span></span>
      <span class="freact">${f.label}</span>${repBar(f, ui.repBar === "true" ? "true" : "equal", f.reach)}
      <span class="fnum">${exalted ? "" : `${num(f.into)} / ${num(f.span)} · ${num(f.left)} to ${f.next}`}</span></div>`;
    // The reach in words: what the quests left could do, and whether they get you to the next reaction.
    if (f.reach != null && f.gain > 0) {
      const enough = f.reachReaction > f.reaction;
      html += `<div class="reach"><span class="rk">Quests you haven't done</span> about <b>+${num(f.gain)}</b> from ${f.quests} quests,
        ${f.reachReaction === 8 ? "enough for <b class='r8'>Exalted</b>" : enough ? `enough for about <b class="r${f.reachReaction}">${REACTIONS[f.reachReaction]}</b>` : `not quite enough for ${f.next}`}${f.rpt ? `; ${f.rpt} repeatable turn-ins on top` : ""}.${f.rival ? ` Most of them lower ${esc(f.rival)}.` : ""}</div>`;
    } else if (!exalted && f.group === "none") html += `<div class="reach"><span class="rk">No quests</span> QuestieDB has no quest that raises ${esc(f.name)}, so the addon can't say how to raise it.</div>`;
    else if (!exalted && !f.src.some(s => s[4] !== false)) html += `<div class="reach"><span class="rk">Not for you</span> Only ${esc(f.src.map(s => s[1]).join(", "))} raise it.</div>`;
    html += `<p class="fdesc">${esc(REP_DESC[f.id] || `(The game's description of ${f.name} goes here: C_Reputation's description field.)`)}</p>`;
    if (f.rivalId) {
      const r = allFactions().find(x => x.id === f.rivalId);
      html += `<div class="seesaw"><div class="sstitle">Rivals: raising one lowers the other</div>
        ${[f, r].map(x => `<div class="frep mini r${x.reaction} ${x.met ? "met" : "unmet"}"><span class="fwho"><span class="fname">${esc(x.name)}</span></span><span class="freact">${x.label}</span>${ladder(x)}</div>`).join("")}</div>`;
    }
    if (f.src.length) {
      html += `<h2 class="section" data-group>Where to raise it <small>${f.src.length} ${f.src.length === 1 ? "place" : "places"}</small></h2><div class="srclist">${f.src.map(s => {
        const [kind, place, n, amt, forYou] = s, zoneHere = kind === "zone" && byName[place];
        const hasPage = zoneHere && (REP_ZONES[place] || []).some(p => p[0] === f.id);
        const tip = `<b>${esc(place)}</b>${SRC_KIND[kind]}. ${n} quests, about +${num(amt)} (QuestieDB's base values).${forYou === false ? " Not for your class." : zoneHere ? ` A opens ${hasPage ? `${esc(f.name)} in ${esc(place)}` : esc(place)}.` : " A would open the Dungeons tab (later)."}`;
        return `<button class="srow focusable ${forYou === false ? "notyou" : ""}" data-src="${esc(kind + "|" + place)}" data-tip="${tip}">
          ${repThumb(zoneHere ? place : null, kind)}<span class="sname">${esc(place)}<small>${SRC_KIND[kind]}${forYou === false ? " · not for you" : ""}</small></span>
          <span class="sq">${n} quests</span><span class="samt">~+${num(amt)}</span></button>`; }).join("")}</div>`;
    }
    html += `<div class="qfoot"><span class="qnote">From QuestieDB's quest rewards: amounts are base values, so approximate (bonuses like the Human racial aren't in them). Killing and other ways to gain reputation aren't known to the addon.</span></div>`;
    container.innerHTML = `<div class="detail paged">${hero}<div class="detail-body full"><div class="scroll" id="${opts.back ? "scroll" : "detailscroll"}">${html}</div></div></div>`;
  }
  function toggleWatch(id) {
    const f = allFactions().find(x => x.id === id); if (!f) return;
    if (f.watched) { ui.watched = null; if (S.watched === id) S.watched = null; toast(`Stopped watching <b>${esc(f.name)}</b><small>The XP bar shows experience only.</small>`); }
    else { ui.watched = id; S.watched = null; toast(`Watching <b>${esc(f.name)}</b> on the XP bar<small>C_Reputation.SetWatchedFactionByID</small>`); }
    rerenderKeepFocus();
  }

  // "Next up in <zone>" (round 3): the few most useful things to do here now. The addon's
  // version comes from the systems (next areas in catalogue order, ready quests nearest your
  // level, flight paths not discovered); the page only draws it. Each opens its page on it.
  function nextUp(z, r) {
    const items = nextItems(z, r);
    if (!items.length) return z.state === "complete" ? `<div class="nextup done"><div class="plate"><span>${esc(z.name)} is claimed</span></div>
      <div class="nempty">Every area, quest and flight path you can do here is done.</div></div>` : "";
    return `<div class="nextup"><div class="plate"><span>Next up in ${esc(z.name)}</span></div>
      <div class="nlist">${items.slice(0, 5).map(it => `<button class="nitem focusable" data-next="${esc(it.key)}"
        data-tip="<b>${esc(it.name)}</b>${esc(it.sub)}. A opens it.">${catIcon(it.cat)}
        <span class="nname ${it.diff ? `d-${it.diff}` : ""}">${esc(it.name)}</span><span class="nsub">${esc(it.sub)}</span></button>`).join("")}</div></div>`;
  }
  // The picks behind Next up and the Overview's suggestions (Zones.NextUp in the addon): two
  // areas to discover, three ready quests nearest your level, one flight path to discover.
  function nextItems(z, r) {
    const items = [];
    z.criteria.filter(c => !c.done).slice(0, 2).forEach(c =>
      items.push({ key: `explore:${c.id}`, cat: "explore", name: c.name, sub: "Area to discover" }));
    if (r && r.status === "ready") {
      const rank = { yellow: 0, orange: 1, green: 2, red: 3, grey: 4 };
      r.ready.slice().sort((a, b) => rank[a.diff] - rank[b.diff] || a.questLevel - b.questLevel).slice(0, 3).forEach(q =>
        items.push({ key: `quest:${q.id}`, cat: "quests", name: q.name, sub: `Quest · level ${q.questLevel}`, diff: q.diff }));
    }
    const f = catOf(z, "flights");
    if (f) f.nodes.filter(n => !n.known).slice(0, 1).forEach(n =>
      items.push({ key: `flight:${n.name}`, cat: "flights", name: n.name, sub: "Flight path to discover" }));
    return items;
  }

  // ---- The zone's war banner (approved direction 2026-11-08) ----
  // SVG stand-in for painted art: the banner is hoisted up its pole as the zone fills, one
  // embroidered badge per category, brass rings on the pole at 25/50/75%, gold when claimed.
  // opts.animate: rise from the ground on show; opts.mini: no fringe or rings (small sizes).
  let svgId = 0;
  const FACTION = {
    Alliance: { cloth: "#2452b8", mid: "#1a3d8c", dark: "#0f2557", trim: "#e2bb4f", trimDark: "#8a6a1c", emblem: "#f0cf6a", pole: ["#6b4524", "#3d250f"], metal: "#d9b44a" },
    Horde: { cloth: "#9a2318", mid: "#6e1810", dark: "#3a0a06", trim: "#b59a6a", trimDark: "#4e3b1e", emblem: "#140d0b", pole: ["#5a4128", "#2a1c10"], metal: "#7d7870" },
  };
  // The Horde banner is a battle-worn war banner, not regal: torn edges, holes, a crude patch,
  // rope lashings, a painted sigil; no fringe, tassels or gilding (owner, 2026-11-08).
  function hordeCloth(X0, X1, y0, H, mx) {
    return `M${X0} ${y0} H${X1} L${X1 + 3} ${y0 + 34} L${X1 - 3} ${y0 + 62} L${X1 + 2} ${y0 + H - 34} L${X1 - 7} ${y0 + H - 10}
      L${X1 - 16} ${y0 + H - 2} L${X1 - 25} ${y0 + H - 18} L${X1 - 37} ${y0 + H + 6} L${mx + 9} ${y0 + H - 12} L${mx - 5} ${y0 + H + 3}
      L${mx - 19} ${y0 + H - 15} L${X0 + 35} ${y0 + H + 1} L${X0 + 22} ${y0 + H - 20} L${X0 + 11} ${y0 + H - 5} L${X0} ${y0 + H - 14} Z`;
  }
  function hordeWear(F, X0, X1, y0, H, mx) {
    const stitch = (x, y) => `<path d="M${x - 2} ${y - 2} l4 4 M${x + 2} ${y - 2} l-4 4" stroke="#d8c8a0" stroke-width=".9"/>`;
    return `<ellipse cx="${X0 + 40}" cy="${y0 + H - 40}" rx="40" ry="26" fill="#000" opacity=".22"/>
      <path d="M${X1 - 30} ${y0 + 26} l6 -3 l4 5 l-3 6 l-6 -1 Z" fill="#0b0604" stroke="${F.dark}" stroke-width="1"/>
      <path d="M${X0 + 16} ${y0 + 96} l5 -2 l3 4 l-4 4 Z" fill="#0b0604" stroke="${F.dark}" stroke-width="1"/>
      <g transform="rotate(-6 ${X0 + 22} ${y0 + 30})"><rect x="${X0 + 12}" y="${y0 + 20}" width="22" height="18" fill="#5c3a22" stroke="#2a1a0e" stroke-width="1"/>
        ${stitch(X0 + 14, y0 + 22)}${stitch(X0 + 32, y0 + 22)}${stitch(X0 + 14, y0 + 36)}${stitch(X0 + 32, y0 + 36)}</g>
      <path d="M${X1 - 12} ${y0 + 90} q-6 8 0 16" stroke="${F.dark}" stroke-width="1.2" fill="none" opacity=".7"/>`;
  }
  const RISE = 120; // pole travel in banner units, 0% -> 100%
  function bannerArt(z, opts = {}) {
    const F = FACTION[ui.look], id = "wb" + (++svgId), p = z.pct || 0, done = z.state === "complete";
    const top = 30, y0 = top + (1 - p) * RISE, X0 = 52, X1 = 176, H = 150, mx = (X0 + X1) / 2;
    const horde = ui.look === "Horde";
    const cloth = horde ? hordeCloth(X0, X1, y0, H, mx)
      : `M${X0} ${y0} H${X1} V${y0 + H} L${X1 - 31} ${y0 + H - 24} L${mx} ${y0 + H} L${X0 + 31} ${y0 + H - 24} L${X0} ${y0 + H} Z`;
    const inner = `M${X0 + 7} ${y0 + 12} H${X1 - 7} V${y0 + H - 10} L${X1 - 31} ${y0 + H - 32} L${mx} ${y0 + H - 9} L${X0 + 31} ${y0 + H - 32} L${X0 + 7} ${y0 + H - 10} Z`;
    // Fringe: short gold threads along the swallowtail edges.
    const edge = [[X1, y0 + H, X1 - 31, y0 + H - 24], [X1 - 31, y0 + H - 24, mx, y0 + H], [mx, y0 + H, X0 + 31, y0 + H - 24], [X0 + 31, y0 + H - 24, X0, y0 + H]];
    const fringe = opts.mini || horde ? "" : edge.map(([ax, ay, bx, by]) => Array.from({ length: 9 }, (_, i) => {
      const t = (i + .5) / 9, x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
      return `<line x1="${x.toFixed(1)}" y1="${y.toFixed(1)}" x2="${x.toFixed(1)}" y2="${(y + 6).toFixed(1)}"/>`; }).join("")).join("");
    const tassel = (x, y) => `<g class="tassel"><line x1="${x}" y1="${y}" x2="${x}" y2="${y + 10}" stroke="${F.trim}" stroke-width="1.5"/>
      <path d="M${x - 3.5} ${y + 10} h7 l2 12 h-11 Z" fill="${F.trim}" stroke="${F.trimDark}" stroke-width=".8"/><circle cx="${x}" cy="${y + 10}" r="2.5" fill="${F.trimDark}"/></g>`;
    // Faction emblem (stand-in shapes; the painted art would carry the real heraldry).
    const ey = y0 + 58;
    const emblem = ui.look === "Alliance"
      ? `<path d="M${mx - 25} ${ey - 30} h50 v26 c0 20 -13 30 -25 36 c-12 -6 -25 -16 -25 -36 Z" fill="${F.emblem}" stroke="${F.trimDark}" stroke-width="1.5"/>
         <path d="M${mx - 25} ${ey - 30} h50 v26 c0 20 -13 30 -25 36 c-12 -6 -25 -16 -25 -36 Z" fill="none" stroke="#fff6d0" stroke-width=".8" stroke-dasharray="2 2" transform="translate(0 0)" opacity=".7"/>
         <path d="M${mx - 13} ${ey - 20} l4 7 l4 -7 l5 7 l5 -7 l4 7 l4 -7 v12 h-26 Z" fill="${F.dark}"/>
         <path d="M${mx - 14} ${ey - 2} q14 10 28 0 l-4 14 q-10 6 -20 0 Z" fill="${F.mid}"/>`
      : `<path d="M${mx} ${ey - 34} l9 18 l15 -9 l-7 20 l12 12 l-16 2 l-13 14 l-13 -14 l-16 -2 l12 -12 l-7 -20 l15 9 Z" fill="${F.emblem}" stroke="${F.trim}" stroke-width="1.6"/>
         <path d="M${mx} ${ey - 18} v34 M${mx - 9} ${ey} h18" stroke="${F.trim}" stroke-width="2.5"/>`;
    // Category badges: embroidered roundels; gold thread runs round as the category fills.
    const n = z.cats.length, by = y0 + 112;
    const badges = z.cats.map((c, i) => {
      const cx = X0 + ((X1 - X0) / (n + 1)) * (i + 1), st = catState(c), r = 11, len = 2 * Math.PI * r;
      return `<g class="badge ${st}"><circle cx="${cx}" cy="${by}" r="${r + 2}" fill="${F.dark}" opacity=".6"/>
        <circle cx="${cx}" cy="${by}" r="${r}" fill="${st === "complete" ? `url(#${id}gold)` : F.dark}" stroke="${F.trimDark}" stroke-width="1"/>
        ${st !== "complete" && c.pct > 0 ? `<circle cx="${cx}" cy="${by}" r="${r}" fill="none" stroke="${F.trim}" stroke-width="3" stroke-dasharray="${(c.pct * len).toFixed(1)} ${len.toFixed(1)}" transform="rotate(-90 ${cx} ${by})"/>` : ""}
        <text x="${cx}" y="${by + 4}" text-anchor="middle" font-size="11" fill="${st === "complete" ? F.dark : F.trim}" opacity="${st === "untouched" ? .6 : 1}">${c.icon}</text></g>`;
    }).join("");
    // Pole: wood, brass rings at 25/50/75%, lit once the banner has passed them; a finial on top.
    const rings = opts.mini ? "" : [.25, .5, .75].map(m => {
      const y = top + (1 - m) * RISE, lit = p >= m;
      return `<rect x="41" y="${y - 2}" width="12" height="5" rx="1.5" fill="${lit ? F.metal : "#3a2e22"}" stroke="#1a1208" stroke-width=".8"/>
        ${lit && !opts.mini ? `<circle cx="47" cy="${y}" r="7" fill="${F.metal}" opacity=".35" filter="url(#${id}soft)"/>` : ""}`;
    }).join("");
    const finial = ui.look === "Alliance"
      ? `<path d="M47 4 l7 14 h-14 Z" fill="url(#${id}gold)" stroke="${F.trimDark}" stroke-width=".8"/><circle cx="47" cy="20" r="4" fill="url(#${id}gold)"/>`
      : `<path d="M47 2 l5 16 h-10 Z M40 16 l-8 -8 l6 12 Z M54 16 l8 -8 l-6 12 Z" fill="${F.metal}" stroke="#1a1208" stroke-width=".8"/><circle cx="47" cy="20" r="4" fill="${F.metal}"/>`;
    const sparkles = done && !opts.mini ? [[30, 60], [190, 46], [196, 140], [24, 150], [112, 18]].map(([x, y], i) =>
      `<path class="spark" style="animation-delay:${i * .37}s" d="M${x} ${y - 7} L${x + 2} ${y - 2} L${x + 7} ${y} L${x + 2} ${y + 2} L${x} ${y + 7} L${x - 2} ${y + 2} L${x - 7} ${y} L${x - 2} ${y - 2} Z" fill="#fff3b0"/>`).join("") : "";
    const drop = opts.animate ? (opts.from != null ? (opts.from - p) * RISE : p * RISE) : 0;
    return `<svg class="warbanner ${done ? "claimed" : ""} ${opts.mini ? "mini" : ""}" viewBox="0 0 210 ${opts.mini ? 300 : 310}">
      <defs>
        <linearGradient id="${id}cloth" x1="0" x2="1"><stop offset="0" stop-color="${F.dark}"/><stop offset=".12" stop-color="${F.cloth}"/>
          <stop offset=".3" stop-color="${F.mid}"/><stop offset=".48" stop-color="${F.cloth}"/><stop offset=".66" stop-color="${F.mid}"/>
          <stop offset=".84" stop-color="${F.cloth}"/><stop offset="1" stop-color="${F.dark}"/></linearGradient>
        <linearGradient id="${id}shade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".14"/><stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient>
        <linearGradient id="${id}gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b0"/><stop offset=".5" stop-color="#ffcc33"/><stop offset="1" stop-color="#9c6b10"/></linearGradient>
        <linearGradient id="${id}pole" x1="0" x2="1"><stop offset="0" stop-color="${F.pole[1]}"/><stop offset=".45" stop-color="${F.pole[0]}"/><stop offset="1" stop-color="${F.pole[1]}"/></linearGradient>
        <filter id="${id}soft"><feGaussianBlur stdDeviation="3"/></filter><filter id="${id}glow"><feGaussianBlur stdDeviation="9"/></filter>
      </defs>
      ${done && !opts.mini ? `<g class="rays">${Array.from({ length: 12 }, (_, i) => `<path d="M114 110 L${114 + 160 * Math.cos(i * Math.PI / 6 - .1)} ${110 + 160 * Math.sin(i * Math.PI / 6 - .1)} L${114 + 160 * Math.cos(i * Math.PI / 6 + .1)} ${110 + 160 * Math.sin(i * Math.PI / 6 + .1)} Z" fill="#ffd35a" opacity=".10"/>`).join("")}</g>` : ""}
      <ellipse cx="50" cy="${opts.mini ? 294 : 300}" rx="40" ry="7" fill="#000" opacity=".55"/>
      <rect x="43" y="16" width="8" height="${opts.mini ? 278 : 284}" rx="2" fill="url(#${id}pole)" stroke="#1a1208" stroke-width=".8"/>
      ${rings}${finial}
      <g class="hoist" style="--drop:${drop.toFixed(1)}px">
        <path d="M47 ${y0 - 4} L${X0 + 4} ${y0 - 4}" stroke="${F.trim}" stroke-width="2"/>
        ${done ? `<path d="${cloth}" fill="${F.trim}" filter="url(#${id}glow)" opacity=".75"/>` : ""}
        <g class="flutter">
          <path d="${cloth}" fill="url(#${id}cloth)" stroke="${done ? F.trim : F.dark}" stroke-width="${done ? 2.5 : 1.2}"/>
          <path d="${cloth}" fill="url(#${id}shade)"/>
          ${horde ? (opts.mini ? "" : hordeWear(F, X0, X1, y0, H, mx))
            : `<path d="${inner}" fill="none" stroke="${F.trim}" stroke-width="1.2" stroke-dasharray="3 2.5" opacity=".9"/>`}
          ${emblem}${badges}
          <g stroke="${F.trim}" stroke-width="1.1" opacity=".9">${fringe}</g>
          ${opts.mini || horde ? "" : tassel(X1, y0 + H) + tassel(X0, y0 + H)}
        </g>
        ${horde
          ? `<rect x="${X0 - 6}" y="${y0 - 7}" width="${X1 - X0 + 12}" height="9" rx="2" fill="${F.pole[0]}" stroke="#1a1008" stroke-width="1"/>
             ${[X0 + 4, mx, X1 - 4].map(x => `<path d="M${x - 4} ${y0 - 8} l8 11 M${x + 4} ${y0 - 8} l-8 11" stroke="#a88f62" stroke-width="1.6"/>`).join("")}`
          : `<rect x="${X0 - 3}" y="${y0 - 6}" width="${X1 - X0 + 8}" height="8" rx="3" fill="url(#${id}gold)" stroke="${F.trimDark}" stroke-width=".8"/>
             <circle cx="${X1 + 5}" cy="${y0 - 2}" r="4.5" fill="url(#${id}gold)" stroke="${F.trimDark}" stroke-width=".8"/>`}
      </g>
      ${sparkles}
    </svg>`;
  }
  // Painted art (tools/process-art.ps1 -> banner-art/, chrome-art/, icon-art/), when present.
  const ART = window.AZF_ART || {};
  const hasPiece = (n) => (ART.banner || []).includes(n);
  const hasChrome = (n) => !!(ART.chrome && ART.chrome[n]);
  const hasIcon = (n) => (ART.icons || []).includes(n);
  const ICON_OF = { explore: "explore", quests: "quests", flights: "flights" };
  const catIcon = (key, cls = "cimg") => hasIcon(ICON_OF[key]) ? `<img class="${cls}" src="icon-art/icon-${ICON_OF[key]}.png" alt="">` : `<span class="cicon">${CATS[key].icon}</span>`;
  function progressArt(z, opts) {
    const k = ui.look === "Horde" ? "horde" : "alliance";
    return hasPiece("banner-" + k) && hasPiece("pole-" + k) ? paintedStandard(z, opts || {}) : bannerArt(z, opts);
  }
  // The painted war standard (design round 2): the pole up the middle, the banner's own crossbar
  // hoisted up it, a streamer tied at the crossbar's ends for each finished category. Units:
  // a 220x440 box. The pole is 1:4 (110x440, finial in its top ~12%); the cloth canvas is 1:2
  // with the 2:3 painting centred; streamers 1:8 canvases.
  function paintedStandard(z, opts) {
    const k = ui.look === "Horde" ? "horde" : "alliance", p = z.pct || 0, done = z.state === "complete";
    const W = 220, H = 440, cw = opts.mini ? 170 : 150, ch = cw * 2, pad = ch * 64 / 512, vis = ch * 384 / 512;
    const top = 58, rise = H - 8 - vis - top;
    const y = top + (1 - p) * rise, cx = (W - cw) / 2;
    const finished = z.cats.filter(c => catState(c) === "complete");
    // Hung from the crossbar's ends, measured on the pieces (as ZoneBanner.lua): x from the cloth
    // canvas's left edge; the tie (28 of 208) on the bar's middle (88/512 of the canvas).
    const sw = 26, sh = sw * 8, xs = k === "horde" ? [-19, cw - 7, -35] : [-3, cw - 23, -19];
    const sy = y - pad + ch * 88 / 512 - 28;
    const streamers = hasPiece("streamer-" + k) ? finished.slice(0, 3).map((c, i) =>
      `<image class="streamer" href="banner-art/streamer-${k}.png" x="${cx + xs[i]}" y="${sy}" width="${sw}" height="${sh}"/>`).join("") : "";
    const drop = opts.animate ? (opts.from != null ? (opts.from - p) * rise : p * rise) : 0;
    const id = "ps" + (++svgId), mx = W / 2;
    // Round 3: motes drift up behind the banner, more as the zone fills (in the hoist's group).
    // The pole glow and the 25/50/75% rings were removed (owner, 2026-11-08).
    const motes = opts.mini ? "" : Array.from({ length: Math.round(2 + p * 9) }, (_, i) => {
      const x = cx - 30 + ((i * 53) % (cw + 60)), d = 5 + (i % 4) * 1.3;
      return `<circle class="mote" style="animation-delay:-${(i * 1.7) % d}s;animation-duration:${d}s" cx="${x}" cy="${y + vis * .9}" r="${1.2 + (i % 3) * .5}" fill="#ffe7a0"/>`;
    }).join("");
    const rays = done && !opts.mini && !opts.noRays ? `<g class="prays">${Array.from({ length: 10 }, (_, i) => { const a = i * Math.PI / 5;
      return `<path d="M${mx} ${top + vis * .45} L${mx + 260 * Math.cos(a - .09)} ${top + vis * .45 + 260 * Math.sin(a - .09)} L${mx + 260 * Math.cos(a + .09)} ${top + vis * .45 + 260 * Math.sin(a + .09)} Z" fill="#ffd35a" opacity=".09"/>`; }).join("")}</g>` : "";
    return `<svg class="warbanner painted ${done ? "claimed" : ""}" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet">
      <defs><filter id="pglow"><feGaussianBlur stdDeviation="10"/></filter><filter id="${id}s"><feGaussianBlur stdDeviation="3"/></filter>
        <linearGradient id="${id}l" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#ffd35a" stop-opacity=".05"/><stop offset=".8" stop-color="#ffd35a" stop-opacity=".55"/><stop offset="1" stop-color="#fff3b0" stop-opacity=".85"/></linearGradient></defs>
      ${rays}
      ${done ? `<ellipse cx="${mx}" cy="${top + vis / 2}" rx="${cw * .62}" ry="${vis * .6}" fill="#ffd35a" opacity=".22" filter="url(#pglow)"/>` : ""}
      <image href="banner-art/pole-${k}.png" x="${(W - 110) / 2}" y="0" width="110" height="${H}"/>
      ${done && !opts.mini ? `<path class="glint" d="M${mx} 8 l3 9 l9 3 l-9 3 l-3 9 l-3 -9 l-9 -3 l9 -3 Z" fill="#fffbe0"/>` : ""}
      <g class="hoist" style="--drop:${drop.toFixed(1)}px">
        ${motes}
        <g class="flutter2" style="transform-origin:${mx}px ${y}px"><image href="banner-art/banner-${k}.png" x="${cx}" y="${y - pad}" width="${cw}" height="${ch}"/></g>
        ${streamers}
      </g></svg>`;
  }
  // Small pennant for claimed zones on catalogue cards and Atlas tiles.
  function pennant() {
    const F = FACTION[ui.look];
    return `<svg class="pennant" viewBox="0 0 24 30"><rect x="3" y="1" width="2.5" height="28" rx="1" fill="${F.pole[0]}"/>
      <path d="${ui.look === "Horde" ? "M5.5 3 H22 L21 9 L23 15 L19 19 L16 15 L12 20 L9 15 L5.5 18 Z" : "M5.5 3 H22 V18 L17 15 L13.75 19 L10.5 15 L5.5 18 Z"}" fill="${F.cloth}" stroke="${F.trim}" stroke-width="1.2"/>
      <path d="M10 9.5 l2.4 2.6 l4.6 -5" stroke="${F.trim}" stroke-width="1.8" fill="none"/></svg>`;
  }
  // ---- Celebrations (spec §7.7; design: DESIGN.md "Celebrations") ----
  // Only for a change seen while you play: a category of a zone becoming complete (one
  // streamer earned) or the whole zone becoming claimed. Both at once: only the claim.
  // Window open: a full-window celebration (A or B continues). Window closed: an on-screen
  // alert for a few seconds, and the celebration plays once when you next open Azerfolio.
  const CEL = {
    explore: { title: (z) => `${z.name} Explored`, line: (c) => `All ${c.total} areas discovered.` },
    quests: { title: (z) => `${z.name}: Every Quest Done`, line: (c) => `All ${c.total} quests you can do here are complete.` },
    flights: { title: (z) => `${z.name}: Every Flight Path`, line: (c) => `All ${c.total} flight ${c.total === 1 ? "path" : "paths"} discovered.` },
  };
  const finishCat = (c) => ({ ...c, done: c.total, pct: 1, unchecked: 0 });
  // Round 2 (owner, 2026-11-08): painted pieces made for the moment, no streamer.
  //   cel-laurel         the gold laurel seal frame; the category's seal sits inside it
  //   cel-seal-explore / cel-seal-quests / cel-seal-flights-alliance / cel-seal-flights-horde
  //   cel-ribbon         the title ribbon
  //   cel-claim-alliance / cel-claim-horde   the seal stamped beside the hoisted standard
  // Until a piece exists, a labelled stand-in shows where it goes.
  function celPiece(name, cls, standin) {
    return `<img class="${cls}" src="chrome-art/${name}.png" alt="" onerror="this.nextElementSibling.hidden=false;this.remove()">`
      + `<span class="${cls} standin" hidden>${standin || ""}<small>${name}</small></span>`;
  }
  function celSeal(kind) {
    const k = ui.look === "Horde" ? "horde" : "alliance";
    return kind === "flights" ? `cel-seal-flights-${k}` : `cel-seal-${kind}`;
  }
  function celebrate(z, kind) {
    closeCelebrate(true);
    ui.celebrate = z.name;
    const el = document.createElement("div");
    el.className = `celebrate ${kind === "claim" ? "claim" : "cat"}`; el.id = "celebrate";
    const k = ui.look === "Horde" ? "horde" : "alliance";
    let body;
    if (kind === "claim") {
      const claimed = { ...z, pct: 1, state: "complete", unchecked: false, cats: z.cats.map(finishCat) };
      body = `<div class="claimart">${progressArt(claimed, { animate: true, from: z.pct || 0, noRays: true })}
          <div class="claimseal">${celPiece(`cel-claim-${k}`, "cseal", ui.look === "Horde" ? "⚔" : "🦁")}</div></div>
        <div class="celribbon">${celPiece("cel-ribbon", "ribbonart")}<h1>${esc(z.name)} Claimed</h1></div>
        <p>For the ${ui.look}: every area, quest and flight path you can do here is done.</p>
        <div class="celcats">${claimed.cats.map(c => `<span>${catIcon(c.key, "cimg sm")}<b>${c.total}</b> ${c.total === 1 ? c.unit.replace(/s$/, "").replace("flight paths", "flight path") : c.unit}</span>`).join("")}</div>`;
    } else {
      const c = catOf(z, kind) || { key: kind, total: 1, label: CATS[kind].label };
      const after = { ...z, cats: z.cats.map(x => x.key === kind ? finishCat(x) : x) };
      after.pct = after.cats.reduce((s, x) => s + x.done / x.total, 0) / after.cats.length;
      body = `<div class="celmedal">
          ${celPiece(celSeal(kind), "seal", CATS[kind].icon)}
          ${celPiece("cel-laurel", "laurel")}</div>
        <div class="celribbon">${celPiece("cel-ribbon", "ribbonart")}<h1>${esc(CEL[kind].title(z))}</h1></div>
        <p>${CEL[kind].line(c)} ${esc(z.name)} is now <b>${pctText(after.pct)}</b>.</p>`;
    }
    el.innerHTML = `<div class="motes">${Array.from({ length: 18 }, (_, i) =>
      `<i style="left:${(i * 37) % 100}%;animation-delay:-${(i * 0.7) % 6}s;animation-duration:${5 + (i % 4)}s"></i>`).join("")}</div>
      <div class="card">${body}<button class="btn focusable cel-ok">Continue <span class="glyph A">A</span></button></div>`;
    $("#window").appendChild(el);
    setFocus($(".cel-ok"));
  }  // The on-screen alert while the window is closed (shown on the page, outside the window).
  function gameAlert(z, kind) {
    const a = $("#gamealert");
    const title = kind === "claim" ? `${z.name} claimed` : CEL[kind].title(z);
    a.innerHTML = `<span class="aseal">${celPiece(kind === "claim" ? `cel-claim-${ui.look === "Horde" ? "horde" : "alliance"}` : celSeal(kind), "seal", CATS[kind === "claim" ? "explore" : kind].icon)}</span><span><small>Azerfolio</small>${esc(title)}</span>`;
    a.hidden = false; a.classList.remove("show"); void a.offsetWidth; a.classList.add("show");
    clearTimeout(gameAlert.t); gameAlert.t = setTimeout(() => { a.hidden = true; }, 5000);
  }
  // ---- Zone Detail category sections (Phase 9 step 4, spec §7.3, §7.7) ----
  const cap = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : "";
  // Reason as shown: "level 12" -> "Level 12"; a prerequisite names the quest when known.
  function reasonText(q) {
    if (q.reason === "prerequisite" && q.prereqs && q.prereqs.length)
      return (q.prereqs.length > 1 ? "Needs one of " : "Needs ") + q.prereqs.join(", ");
    return cap(q.reason);
  }
  const QSTATE = {
    ready: { mark: "!", label: "Ready now" }, locked: { mark: "🔒", label: "Locked" }, unknown: { mark: "?", label: "Not counted" },
    done: { mark: "✓", label: "Done" }, unavailable: { mark: "⊘", label: "Not for this character" },
  };
  const DIFF = { red: "far above your level", orange: "above your level", yellow: "about your level", green: "easy for you", grey: "far below your level" };
  function questDetail(q) {
    const lv = `Level ${q.questLevel}${q.reqLevel && q.reqLevel !== q.questLevel ? ` (from ${q.reqLevel})` : ""}`;
    const state = q.kind === "ready" ? `Ready now · ${DIFF[q.diff]}` : q.kind === "done" ? "Done" : `${QSTATE[q.kind].label}: ${reasonText(q)}`;
    return { lv, state };
  }
  const qtip = (q) => { const d = questDetail(q); return `<b>${esc(q.name)}</b>${esc(d.lv)} · ${esc(d.state)}`; };
  // One storyline node: a dot (state) and the name under it.
  const qnode = (q) => `<button class="qnode focusable k-${q.kind} d-${q.diff}" data-quest="${q.id}" data-tip="${qtip(q)}">
    <span class="dot">${q.kind === "ready" ? "" : QSTATE[q.kind].mark}</span><span class="nl">${esc(q.name)}</span></button>`;
  const visible = (q) => ui.showUnavailable || q.kind !== "unavailable";
  function track(story) {
    const cols = story.columns.map(c => c.filter(visible)).filter(c => c.length);
    return `<div class="track">${cols.map(c => `<div class="tcol">${c.map(qnode).join("")}</div>`).join("")}</div>`;
  }
  function storyHead(s) {
    return `<div class="shead"><span class="sname">${esc(s.name)}</span><span class="scount">${s.done} of ${s.total} done${s.ready ? ` · <b>${s.ready} ready</b>` : ""}</span></div>`;
  }
  function questSection(z) {
    const cat = catOf(z, "quests");
    const head = () => ""; // the page's banner already names the category and its count
    const r = questsFor(z);
    if (r.status === "unavailable") return head() + `<div class="qnote">Quests unavailable: needs the QuestieDB addon, which isn't loaded. Exploration and flight paths are unaffected.</div>`;
    if (r.status === "building") return head() + `<div class="qnote">Reading quests from QuestieDB…</div>`;
    if (r.status === "nosample") return cat ? head(`<span class="qscore">${cat.done} of ${cat.total} done<b>${pctText(cat.pct)}</b></span>`)
      + `<div class="qnote">(Mockup: the quest list is sampled only for Elwynn Forest.)</div>` : "";
    const p = r.progress;
    if (!r.objectives.length) return head() + `<div class="qnote">QuestieDB lists no quests in ${esc(z.name)}.</div>`;
    let html = head(p.denominator ? `<span class="qscore">${p.completed} of ${p.denominator} done<b>${pctText(p.percent)}</b></span>` : "");
    if (!p.denominator) html += `<div class="qnote">None of the ${p.unavailable} quests here are for this character, so quests don't count toward ${esc(z.name)}.</div>`;
    if (r.ready.length) html += `<h2 class="section" data-group>Ready now <small>${r.ready.length}</small></h2>
      <div class="readygrid">${r.ready.map(q => `<button class="qchip focusable d-${q.diff}" data-quest="${q.id}" data-tip="${qtip(q)}">
        <span class="lvl">${q.questLevel}</span><span class="qn">${esc(q.name)}</span></button>`).join("")}</div>`;
    const singles = r.singles.filter(q => visible(q) && q.kind !== "done");
    const singlesDone = r.singles.filter(q => q.kind === "done").length;
    if (r.stories.length || singles.length) {
      html += `<h2 class="section" data-group>Storylines <small>${r.stories.length} in progress</small></h2>`;
      html += r.stories.map(s => `<div class="story">${storyHead(s)}${track(s)}</div>`).join("");
      if (singles.length) html += `<div class="story"><div class="shead"><span class="sname">Single quests</span><span class="scount">${singlesDone} done</span></div>
        <div class="track singles">${singles.map(qnode).join("")}</div></div>`;
    }
    if (r.finished.length) {
      html += `<h2 class="section" data-group>Finished <small>${r.finished.length} storylines · ${singlesDone} single quests</small></h2>`;
      html += r.finished.map(s => {
        const open = ui.openStories.has(s.id);
        return `<button class="storyfold focusable ${open ? "open" : ""}" data-story="${s.id}" data-tip="<b>${esc(s.name)}</b>${s.size} quests, every one you can do is done. A ${open ? "folds" : "shows"} the storyline.">
          <span class="mark">✓</span><span class="sname">${esc(s.name)}</span><span class="scount">${s.total} quests</span><span class="arr">${open ? "−" : "+"}</span></button>
          ${open ? `<div class="story inner">${track(s)}</div>` : ""}`;
      }).join("");
    }
    // Footer: what the numbers leave out, and the can't-do toggle.
    const why = Object.entries(r.unknownReasons);
    const left = [];
    if (r.repeatable) left.push(`${r.repeatable} repeatable`);
    if (p.eligibilityUnknown) left.push(`${p.eligibilityUnknown} we can't check yet (${why.map(([w, n]) => why.length > 1 ? `${w} ${n}` : w).join(", ")})`);
    html += `<div class="qfoot"><span class="qnote">From QuestieDB, which may miss quests.${left.length ? " Not counted: " + left.join(", ") + "." : ""}</span>
      ${p.unavailable ? `<button class="btn dark qtoggle focusable" data-qtoggle data-tip="<b>${ui.showUnavailable ? "Hide" : "Show"} quests you can't do</b>Other faction or class, a finished chain or a choice already made. Never counted.">
        ${ui.showUnavailable ? "Hide" : "Show"} ${p.unavailable} you can't do</button>` : ""}</div>`;
    return html;
  }
  // Exploration and flight path headers: the same major heading as Quests.
  function catHead(c, title) {
    return `<div class="majorhead"><span class="cicon">${c.icon}</span><h2>${title}</h2><span class="qscore">${c.done} of ${c.total}<b>${pctText(c.pct)}</b></span></div>`;
  }
  function flightSection(z) {
    const c = catOf(z, "flights");
    if (!c) return "";
    return `<h2 class="section" data-group>Flight masters <small>${c.total}</small></h2><div class="checklist">${c.nodes.map(n => `<button class="check focusable ${n.known ? "done" : "todo"}" data-flight="${esc(n.name)}"
      data-tip="<b>${esc(n.name)}</b>${n.known ? "Known: you can fly here." : "Not discovered yet: talk to the flight master there."}"><span class="mark">${n.known ? "✓" : "✈"}</span><span>${esc(n.name)}</span></button>`).join("")}</div>
      <div class="qnote">Sample flight paths (not yet verified on Forever).</div>`;
  }
  function showQuestInfo(z, el) {
    const box = $("#focusinfo"); if (!box) return;
    const r = questsFor(z);
    const q = r.objectives && r.objectives.find(o => String(o.id) === el.dataset.quest);
    if (!q) return;
    const d = questDetail(q);
    box.innerHTML = `<h3>${esc(q.name)}</h3><div class="facts">${esc(d.lv)}</div><div class="state k-${q.kind}">${esc(d.state)}</div>`;
  }
  function showFocusInfo(z, c) {
    const box = $("#focusinfo"); if (!box) return;
    if (!c) { box.innerHTML = `<h3>${esc(z.name)}</h3><div class="facts">No exploration objectives.</div>`; return; }
    box.innerHTML = `<h3>${esc(c.name)}</h3><div class="state ${c.done ? "done" : "todo"}">${c.done ? "✓ Discovered" : "○ Not yet discovered"}</div>`;
  }

  // =====================================================================================
  // Class tab (Phase 13 mockup, 2026-11-09): the class quest journey. Left: a painted map
  // strip (SVG stand-in), the road running down it with one node per stop (a quest chain) and a
  // bead per quest; optional side paths branch off and end in a dead end. Right: the selected
  // stop. Sample data: Gideon, Human Paladin; quest IDs from `qdb.lua class paladin human`
  // (base rows). In the addon the stops come from the curated Data/ClassJourneys.lua and every
  // done / not done from the game.
  // =====================================================================================
  // step: [questID, name, NPC, place, required level, "sub"?]. A "sub" step is a repeatable-flagged
  // sub-quest inside the chain: shown in place, not counted. `leadins` are optional starts (not
  // counted). `art` is the zone art behind the stop's header (where it starts).
  // Design round 2 (2026-11-09, after the in-game review): a Next line, numbered steps, Travels to,
  // lead-ins above the steps, zone art in the header.
  const CLASS_ROAD = {
    cls: "Paladin", title: "The Paladin's Road",
    // Round 4: the antique strip (mockups/strip-art/paladin-alliance.png, 1:4) sets the size; stops
    // sit in its corridor beside their landmarks (measured on the art, 2026-11-10).
    W: 420, H: 1680, end: { x: 214, y: 1621 }, art: "strip-art/paladin-alliance.png",
    stops: [
      { id: "letter", kind: "road", x: 214, y: 92, lv: 1, name: "Consecrated Letter", landmark: "abbey", art: 1429,
        reward: "Meet Brother Sammuel, your first trainer", start: "Marshal McBride · Northshire Abbey, Elwynn Forest",
        steps: [[3101, "Consecrated Letter", "Marshal McBride", "Northshire Abbey, Elwynn Forest", 1]] },
      { id: "divinity", kind: "road", x: 252, y: 223, lv: 12, name: "The Tome of Divinity", landmark: "cathedral", art: 1453,
        reward: "Redemption (spell)", start: "Duthorian Rall · Cathedral of Light, Stormwind City",
        alt: "Dwarf paladins take this from Tiza Battleforge in Ironforge; Humans get Stormwind's version (the other one is never counted).",
        leadins: [[2998, "Tome of Divinity", "Brother Wilhelm", "Goldshire, Elwynn Forest", 12, "A lead-in: sends you to Duthorian Rall."],
          [1641, "The Tome of Divinity", "Duthorian Rall", "Cathedral of Light, Stormwind City", 12, "The chain's start. QuestieDB flags it repeatable, so it isn't counted."]],
        steps: [[1642, "The Tome of Divinity", "the Tome of Divinity (item)", "Your bags", 12],
          [1643, "The Tome of Divinity", "Duthorian Rall", "Cathedral of Light, Stormwind City", 12],
          [1644, "The Tome of Divinity", "Stephanie Turner", "Old Town, Stormwind City", 13],
          [1780, "The Tome of Divinity", "Stephanie Turner", "Old Town, Stormwind City", 13],
          [1781, "The Tome of Divinity", "Duthorian Rall", "Cathedral of Light, Stormwind City", 13],
          [1786, "The Tome of Divinity", "Gazin Tenorm", "Stormwind City", 13],
          [1787, "The Tome of Divinity", "Henze Faulk", "Elwynn Forest", 13],
          [1788, "The Tome of Divinity", "Gazin Tenorm", "Stormwind City", 13]] },
      { id: "valor", kind: "road", x: 193, y: 664, lv: 20, name: "The Tome of Valor", landmark: "farm", art: 1436,
        reward: "Verigan's Fist (two-handed mace)", start: "Duthorian Rall · Cathedral of Light, Stormwind City",
        leadins: [[1793, "The Tome of Valor", "Duthorian Rall", "Cathedral of Light, Stormwind City", 20, "The chain's start: Duthorian Rall gives you the Tome of Valor."]],
        steps: [[1649, "The Tome of Valor", "the Tome of Valor (item)", "Your bags", 20],
          [1650, "The Tome of Valor", "Duthorian Rall", "Cathedral of Light, Stormwind City", 20],
          [1651, "The Tome of Valor", "Daphne Stilwell", "Westfall", 20],
          [1652, "The Tome of Valor", "Daphne Stilwell", "Westfall", 20],
          [1653, "The Test of Righteousness", "Duthorian Rall", "Cathedral of Light, Stormwind City", 20],
          [1654, "The Test of Righteousness", "Jordan Stilwell", "Ironforge gates, Dun Morogh", 20],
          [1442, "Seeking the Kor Gem", "Thundris Windweaver", "Auberdine, Darkshore", 20, "sub"],
          [1655, "Bailor's Ore Shipment", "Bailor Stonehand", "Thelsamar, Loch Modan", 20, "sub"],
          [1806, "The Test of Righteousness", "Jordan Stilwell", "Ironforge gates, Dun Morogh", 20]] },
      { id: "artifact", kind: "side", from: "valor", x: 118, y: 823, lv: 22, name: "A Strange Artifact", landmark: "grove", art: 1440,
        reward: "Not known yet (read from the quest in game)", start: "A strange artifact (object) · Ashenvale",
        flag: "A newer quest ID: whether it's live in Forever is still an in-game check.",
        steps: [[78088, "A Strange Artifact", "a strange artifact (object)", "Ashenvale", 22],
          [78089, "Advice From Stormwind", "Delgren the Purifier", "Ashenvale", 22],
          [78090, "A Second Opinion", "Katherine the Pure", "Stormwind City", 22],
          [78091, "Earning Your Salt", "Ursula Deline", "Stormwind City", 22],
          [78092, "It Must Be Destroyed", "Ursula Deline", "Stormwind City", 22],
          [78093, "Return to Delgren", "an object", "Ashenvale", 22]] },
      { id: "nobility", kind: "road", x: 260, y: 1008, lv: 40, name: "The Tome of Nobility", landmark: "keep", art: 1453,
        reward: "Summon Warhorse (mount)", start: "Duthorian Rall · Cathedral of Light, Stormwind City",
        steps: [[1661, "The Tome of Nobility", "Duthorian Rall", "Cathedral of Light, Stormwind City", 40]] },
      { id: "mightstone", kind: "side", from: "nobility", x: 269, y: 1210, lv: 50, name: "Forging the Mightstone", landmark: "camp", art: 1422,
        reward: "Shown in game (from the quest)", start: "Lord Grayson Shadowbreaker · Stormwind City",
        leadins: [[8415, "Chillwind Point", "Lord Grayson Shadowbreaker", "Stormwind City", 50, "A lead-in: sends you to Chillwind Camp."]],
        steps: [[8414, "Dispelling Evil", "Commander Ashlam Valorfist", "Chillwind Camp, Western Plaguelands", 50],
          [8416, "Inert Scourgestones", "High Priest Thel'danis", "Chillwind Camp, Western Plaguelands", 50],
          [8418, "Forging the Mightstone", "Commander Ashlam Valorfist", "Chillwind Camp, Western Plaguelands", 50]] },
      { id: "charger", kind: "road", x: 168, y: 1277, lv: 60, name: "The Charger", landmark: "ossuary", art: 1423,
        reward: "Summon Charger (epic mount)", start: "Duthorian Rall, then Lord Grayson Shadowbreaker · Stormwind City",
        flag: "Needs groups for Scholomance and Stratholme.",
        steps: [[7638, "Lord Grayson Shadowbreaker", "Duthorian Rall", "Stormwind City", 60],
          [7637, "Emphasis on Sacrifice", "Lord Grayson Shadowbreaker", "Stormwind City", 60],
          [7639, "To Show Due Judgment", "High Priest Rohan", "Ironforge", 60],
          [7640, "Exorcising Terrordale", "Lord Grayson Shadowbreaker", "Stormwind City", 60],
          [7641, "The Work of Grimand Elmore", "Lord Grayson Shadowbreaker", "Stormwind City", 60],
          [7642, "Collection of Goods", "Grimand Elmore", "Stormwind City", 60],
          [7648, "Grimand's Finest Work", "Grimand Elmore", "Stormwind City", 60],
          [7643, "Ancient Equine Spirit", "Lord Grayson Shadowbreaker", "Stormwind City", 60],
          [7645, "Manna-Enriched Horse Feed", "Merideth Carlson", "Southshore, Hillsbrad Foothills", 60, "sub"],
          [7644, "Blessed Arcanite Barding", "Ancient Equine Spirit", "Scholomance, Western Plaguelands", 60],
          [7646, "The Divination Scryer", "Lord Grayson Shadowbreaker", "Stormwind City", 60],
          [7647, "Judgment and Redemption", "Lord Grayson Shadowbreaker", "Stratholme, Eastern Plaguelands", 60]] },
    ],
  };
  // Quests done per scenario (sample data, invented except "today": Gideon has the letter).
  const CLASS_DONE = { today: [3101], almost: [3101], veteran: [3101, 2998, 1641, 1642, 1643, 1644, 1780, 1781, 1786, 1787, 1788,
    1793, 1649, 1650, 1651, 1652, 1653, 1654, 1442, 1655, 1806, 78088, 78089], fresh: [] };
  const counted = (s) => s.steps.filter(q => q[5] !== "sub");
  const zoneOfPlace = (p) => p === "Your bags" ? null : p.split(", ").pop();
  // "Duthorian Rall · Cathedral of Light, Stormwind City" -> "Duthorian Rall · Stormwind City"
  const shortStart = (s) => s.replace(/ · .*, /, " · ");

  function classModel() {
    const R = CLASS_ROAD, preview = ui.classPreview, unknown = preview === "unknown";
    const done = new Set(preview === "all" ? R.stops.flatMap(s => s.steps.map(q => q[0])) : unknown ? [] : CLASS_DONE[ui.scenarioName] || []);
    const stops = R.stops.map(s => {
      const c = counted(s), n = c.length, d = c.filter(q => done.has(q[0])).length;
      const state = unknown ? "unknown" : d === n ? "done" : d > 0 ? "progress" : CHAR.level >= s.lv ? "ready" : "later";
      const travels = [...new Set(s.steps.map(q => zoneOfPlace(q[3])).filter(Boolean))];
      return { ...s, n, d: unknown ? null : d, state, done, travels };
    });
    const road = stops.filter(s => s.kind === "road"), side = stops.filter(s => s.kind === "side");
    const quests = stops.reduce((a, s) => a + s.n, 0), questsDone = unknown ? null : stops.reduce((a, s) => a + s.d, 0);
    const complete = unknown ? null : stops.every(s => s.state === "done");
    return { stops, road, side, quests, questsDone, complete, unknown,
      roadDone: road.filter(s => s.state === "done").length, sideDone: side.filter(s => s.state === "done").length };
  }
  // Round 3: where your level puts you on the road. Each road stop sits at its level, the road's end
  // at 60; returns { i: the road segment (from road stop i to the next), t: how far along it }.
  function levelPos(m, at) {
    const lv = Math.min(60, at !== undefined ? at : CHAR.level + (CHAR.xpMax ? CHAR.xp / CHAR.xpMax : 0));
    const pts = m.road.map(s => s.lv).concat(60);
    for (let i = 0; i < pts.length - 1; i++) {
      if (lv < pts[i + 1]) return { i, t: pts[i + 1] > pts[i] ? Math.max(0, (lv - pts[i]) / (pts[i + 1] - pts[i])) : 1 };
    }
    return { i: pts.length - 2, t: 1 };
  }
  // Round 3 (owner, 2026-11-10): a finished stop's mark is a gold coin struck with the class emblem
  // (one painted coin per class later; this SVG is the stand-in: the Paladin's hammer in the Light).
  const COIN_EMBLEM = {
    Paladin: `<path d="M0 -15 L4 -4 L15 0 L4 4 L0 15 L-4 4 L-15 0 L-4 -4 Z" class="ce-ray"/><path d="M-3 -9 H3 V-3 H8 V3 H3 V12 H-3 V3 H-8 V-3 H-3 Z" class="ce-ham"/>`,
  };
  const classCoin = (cls = "") => CLASS_ROAD.art
    ? `<span class="ccoin ${cls}" title="Done"><img src="chrome-art/coin-${CLASS_ROAD.cls.toLowerCase()}.png" alt=""></span>`
    : `<span class="ccoin ${cls}" title="Done"><svg viewBox="-24 -24 48 48" aria-hidden="true">
      <defs><radialGradient id="coinface" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#fff4c2"/><stop offset=".45" stop-color="#f2c447"/><stop offset="1" stop-color="#9a6a12"/></radialGradient>
        <linearGradient id="coinrim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff0b0"/><stop offset=".5" stop-color="#b8860b"/><stop offset="1" stop-color="#5a3a06"/></linearGradient></defs>
      <circle r="23" fill="url(#coinrim)"/><circle r="19.5" fill="url(#coinface)"/><circle r="17" class="ce-ring"/>
      <g class="ce">${COIN_EMBLEM[CLASS_ROAD.cls] || ""}</g></svg></span>`;
  // Round 4: a stop not done yet is the coin's emblem as a cartographer's ink sketch (one per class,
  // painted later; this SVG is the stand-in). Finishing the stop turns the sketch into the gold coin.
  // Later: faint pencil; open now: fresh ink with a red cartographer's circle.
  const classSketch = () => CLASS_ROAD.art
    ? `<span class="csketch"><img src="chrome-art/sketch-${CLASS_ROAD.cls.toLowerCase()}.png" alt=""><i class="skred"></i></span>`
    : `<span class="csketch"><svg viewBox="-24 -24 48 48" aria-hidden="true">
      <circle r="20" class="sk-rim"/><circle r="16.5" class="sk-rim thin"/>
      <path d="M0 -12 L3 -4 L11 0 L3 4 L0 12 L-3 4 L-11 0 L-3 -4 Z" class="sk-ray"/>
      <path d="M-3 -9 H3 V-3 H8 V3 H3 V11 H-3 V3 H-8 V-3 H-3 Z" class="sk-ham"/><circle r="22.5" class="sk-red"/></svg></span>`;
  // The one thing to do next (design round 2): your road stop (or a side path once the road is walked).
  function classNext(m) {
    if (m.unknown) return { text: "Next: not known until the game gives Azerfolio your completed quests" };
    const cur = m.road.find(s => s.state !== "done") || m.side.find(s => s.state !== "done");
    if (!cur) return { text: "Every stop walked", done: true };
    if (cur.state === "later") {
      const togo = cur.lv - CHAR.level;
      return { stop: cur, text: `Next: reach level ${cur.lv} (${togo} to go), then ${shortStart(cur.start)}` };
    }
    const q = counted(cur).find(q => !cur.done.has(q[0]));
    return { stop: cur, text: `Next: ${q[1]} · ${q[2]} · ${zoneOfPlace(q[3]) || q[3]}` };
  }
  // Road geometry: one cubic segment per stop, from it to the next road stop (the last to the road's
  // end); the stop's own quests are beads along it. Side paths leave from the middle of their
  // stop's segment and end at their own node.
  // The traced road corridor of a painted strip (strip-art/paths.js, tools/trace-strip.ps1): the road
  // follows the painting's cleared path (it cut across the art, owner 2026-11-10). A segment is a
  // cubic curve [p0..p3] or a stretch { path, s0, s1 } of the traced polyline.
  function newPath(raw) {
    if (!raw || raw.length < 2) return null;
    const pts = raw.map(p => ({ x: p[0], y: p[1] })), acc = [0];
    for (let i = 1; i < pts.length; i++) acc[i] = acc[i - 1] + Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
    return { pts, acc, len: acc[acc.length - 1] };
  }
  function pathPoint(P, s) {
    s = Math.max(0, Math.min(P.len, s));
    let i = 0; while (i < P.pts.length - 2 && P.acc[i + 1] < s) i++;
    const span = P.acc[i + 1] - P.acc[i], f = span > 0 ? (s - P.acc[i]) / span : 0, a = P.pts[i], b = P.pts[i + 1];
    return { x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f };
  }
  function pathProject(P, x, y) {
    let best = 0, bestD = Infinity;
    for (let i = 0; i < P.pts.length - 1; i++) {
      const a = P.pts[i], b = P.pts[i + 1], dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy;
      const f = l2 > 0 ? Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / l2)) : 0;
      const d = (a.x + dx * f - x) ** 2 + (a.y + dy * f - y) ** 2;
      if (d < bestD) { bestD = d; best = P.acc[i] + f * (P.acc[i + 1] - P.acc[i]); }
    }
    return best;
  }
  const bez = (p, t) => { if (p.path) return pathPoint(p.path, p.s0 + (p.s1 - p.s0) * t); const u = 1 - t; return { x: u*u*u*p[0].x + 3*u*u*t*p[1].x + 3*u*t*t*p[2].x + t*t*t*p[3].x, y: u*u*u*p[0].y + 3*u*u*t*p[1].y + 3*u*t*t*p[2].y + t*t*t*p[3].y }; };
  function splitBez(p, t) { // the part of the curve from 0 to t (de Casteljau)
    const L = (a, b) => ({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t });
    const a = L(p[0], p[1]), b = L(p[1], p[2]), c = L(p[2], p[3]), d = L(a, b), e = L(b, c), f = L(d, e);
    return [p[0], a, d, f];
  }
  const bpath = (p) => `M${p[0].x} ${p[0].y} C${p[1].x} ${p[1].y} ${p[2].x} ${p[2].y} ${p[3].x} ${p[3].y}`;
  // Points every `step` units along a curve (by arc length), with the direction in degrees and t.
  function stampsAlong(p, step) {
    const n = 60, acc = [0], pts = [];
    let prev = bez(p, 0);
    for (let i = 1; i <= n; i++) { const q = bez(p, i / n); acc[i] = acc[i - 1] + Math.hypot(q.x - prev.x, q.y - prev.y); prev = q; }
    for (let d = step / 2, i = 0; d < acc[n]; d += step) {
      while (i < n - 1 && acc[i + 1] < d) i++;
      const t = (i + (d - acc[i]) / Math.max(1e-6, acc[i + 1] - acc[i])) / n;
      const a = bez(p, Math.max(0, t - 0.01)), b = bez(p, Math.min(1, t + 0.01)), c = bez(p, t);
      pts.push({ x: c.x, y: c.y, t, deg: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI });
    }
    return pts;
  }
  function roadSegs(m) {
    const R = CLASS_ROAD, segs = {};
    const P = R.art && window.AZF_STRIP_PATHS && newPath(window.AZF_STRIP_PATHS[`${R.cls.toLowerCase()}-alliance`]);
    if (P) {
      // Road stops and the end sit on the traced corridor; each segment is the stretch between.
      const at = (o) => pathProject(P, o.x, o.y);
      const ss = m.road.map(at).concat(at(R.end));
      m.road.forEach((s, i) => { const q = pathPoint(P, ss[i]); s.x = q.x; s.y = q.y; segs[s.id] = { path: P, s0: ss[i], s1: ss[i + 1] }; });
      const e = pathPoint(P, ss[ss.length - 1]); R.end.x = e.x; R.end.y = e.y;
    } else m.road.forEach((s, i) => {
      const nx = m.road[i + 1] || R.end, dy = nx.y - s.y;
      segs[s.id] = [{ x: s.x, y: s.y }, { x: s.x, y: s.y + dy * 0.55 }, { x: nx.x, y: nx.y - dy * 0.55 }, { x: nx.x, y: nx.y }];
    });
    m.side.forEach(s => {
      const b = bez(segs[s.from], 0.5);
      segs[s.id] = [b, { x: b.x + (s.x - b.x) * 0.6, y: b.y + 10 }, { x: s.x, y: s.y - (s.y - b.y) * 0.6 }, { x: s.x, y: s.y }];
    });
    return segs;
  }
  // Landmark silhouettes (stand-ins for the painted strip's own scenery).
  const LANDMARK = {
    abbey: (x, y) => `<g transform="translate(${x} ${y})" class="lm"><path d="M-26 0 V-26 L-13 -40 L0 -26 V0 Z M0 0 V-18 H26 V0 Z"/><path d="M-13 -40 V-56 M-19 -50 H-7" class="lmline"/></g>`,
    cathedral: (x, y) => `<g transform="translate(${x} ${y})" class="lm"><path d="M-34 0 V-30 L-26 -62 L-18 -30 V-22 H18 V-30 L26 -62 L34 -30 V0 Z"/><path d="M-8 0 V-14 A8 8 0 0 1 8 -14 V0 Z" class="lmlit"/></g>`,
    farm: (x, y) => `<g transform="translate(${x} ${y})" class="lm"><path d="M-30 0 V-16 L-16 -30 L-2 -16 V0 Z"/><path d="M14 0 L18 -34 L22 0 Z"/><path d="M18 -34 L36 -44 M18 -34 L0 -24 M18 -34 L28 -16 M18 -34 L8 -52" class="lmline"/></g>`,
    grove: (x, y) => `<g transform="translate(${x} ${y})" class="lm"><path d="M-18 0 C-34 -10 -30 -38 -14 -40 C-12 -56 10 -56 12 -40 C28 -38 30 -10 16 0 Z"/><path d="M-1 0 V-22" class="lmline"/></g>`,
    keep: (x, y) => `<g transform="translate(${x} ${y})" class="lm"><path d="M-34 0 V-34 H-26 V-40 H-20 V-34 H-12 V-40 H-6 V-34 H6 V-40 H12 V-34 H20 V-40 H26 V-34 H34 V0 Z M-8 -34 V-58 H8 V-34"/><path d="M0 -58 V-72 L12 -67 L0 -62" class="lmlit"/></g>`,
    camp: (x, y) => `<g transform="translate(${x} ${y})" class="lm"><path d="M-22 0 L-8 -24 L6 0 Z M4 0 L16 -18 L28 0 Z"/><path d="M-8 -24 V-38 L4 -34 L-8 -30" class="lmlit"/></g>`,
    ossuary: (x, y) => `<g transform="translate(${x} ${y})" class="lm dark"><path d="M-38 0 L-26 -14 H26 L38 0 Z M-24 -14 L-14 -28 H14 L24 -14 Z M-12 -28 L-4 -40 H4 L12 -28 Z"/><circle cx="0" cy="-48" r="5" class="lmsick"/></g>`,
  };
  // The painted map strip (SVG stand-in): dawn light at the top over Northshire, the green
  // Elwynn hills, the road south and east, and the Plaguelands' gloom at the bottom, where the
  // Charger waits; a gilded crest at the road's end.
  function classStrip(m) {
    const R = CLASS_ROAD, segs = roadSegs(m);
    // Round 4 (owner, 2026-11-10): a hand-drawn antique map. Stand-in: parchment, ink hill lines
    // with a thin sage wash, inked tree glyphs; the painted strip replaces it.
    const hills = [[300, 0.10], [520, 0.08], [780, 0.10], [1000, 0.07], [1180, 0.09], [1330, 0.06]].map(([y, o], i) => {
      let d = `M0 ${y}`; for (let x = 0; x <= R.W; x += 30) d += ` L${x} ${(y - 30 - Math.abs(Math.sin((x + i * 70) / 60)) * 46).toFixed(0)}`;
      return `<path d="${d} L${R.W} ${R.H} L0 ${R.H} Z" fill="#7f9a63" opacity="${o}"/><path d="${d}" class="inkline"/>`; }).join("");
    const trees = Array.from({ length: 34 }, (_, i) => { const x = (i * 97) % (R.W - 20) + 10, y = 360 + ((i * 211) % 760);
      return `<path d="M${x} ${y} l-7 13 h4 l-5 9 h16 l-5 -9 h4 Z" class="inktree"/>`; }).join("");
    // Round 3 (owner, 2026-11-10): the road means levels. It fills from the start to your level
    // (XP included); a side path's dotted track fills when it's done.
    const lp = levelPos(m);
    // Round 4: the road is made of painted stamps placed along the curve and turned to follow it:
    // gold-leaf dashes as far as your level, ink dashes after (two variants each, alternated),
    // ink dots along a side path (gold dots once it's done).
    const hasArt = !!R.art;
    const segPaths = Object.entries(segs).map(([id, p]) => {
      const s = m.stops.find(x => x.id === id);
      const ri = m.road.indexOf(s);
      const lit = s.kind === "side" ? (s.d ? s.d / s.n : 0) : ri < lp.i ? 1 : ri === lp.i ? lp.t : 0;
      if (!hasArt) return `<path d="${bpath(p)}" class="road ${s.kind}"/>${lit > 0 ? `<path d="${bpath(splitBez(p, lit))}" class="road lit ${s.kind}"/>` : ""}`;
      const side = s.kind === "side";
      return stampsAlong(p, side ? 9 : 22).map((pt, k) => {
        const on = lit > 0 && pt.t <= lit;
        if (side) return `<image href="chrome-art/road-dot.png" x="${(pt.x - 3).toFixed(1)}" y="${(pt.y - 3).toFixed(1)}" width="6" height="6" class="${on ? "gilt" : ""}"/>`;
        const file = `chrome-art/road-dash-${on ? "gold" : "ink"}-${(k % 2) + 1}.png`;
        return `<image href="${file}" x="-11" y="-5.5" width="22" height="11" transform="translate(${pt.x.toFixed(1)} ${pt.y.toFixed(1)}) rotate(${pt.deg.toFixed(1)})"/>`;
      }).join("");
    }).join("");
    // Quest pips ring each node (completion lives on the node now, not the road).
    const beads = m.stops.map(s => {
      const c = counted(s), r = s.kind === "road" ? 31 : 23;
      return c.map((q, k) => {
        const a = -Math.PI / 2 + (k / c.length) * Math.PI * 2;
        return `<circle cx="${(s.x + r * Math.cos(a)).toFixed(1)}" cy="${(s.y + r * Math.sin(a)).toFixed(1)}" r="${s.kind === "road" ? 3.6 : 3}" class="bead ${s.done.has(q[0]) ? "on" : ""} ${m.unknown ? "unk" : ""}"/>`;
      }).join("");
    }).join("");
    const marks = m.stops.map(s => LANDMARK[s.landmark] ? LANDMARK[s.landmark](s.x + (s.x < R.W / 2 ? 70 : -70), s.y + 22) : "").join("");
    // A side path ends in a dead end: a small hatched ink cairn under its node.
    const deadends = m.side.map(s => `<g class="cairn" transform="translate(${s.x} ${s.y + 30})"><ellipse cx="0" cy="8" rx="11" ry="4.5"/><ellipse cx="1" cy="1" rx="8" ry="3.8"/><ellipse cx="-1" cy="-5" rx="5" ry="3"/></g>`).join("");
    // "You" (round 4): your portrait in a small brass ring, like a token pinned on the map, with an
    // ink tag. The stand-in draws an initial where the game draws your portrait.
    const yp = bez(segs[m.road[lp.i].id], lp.t);
    const you = `<g class="you" transform="translate(${yp.x.toFixed(1)} ${yp.y.toFixed(1)})"><circle r="10.5" class="youface"/>
        <text y="4" class="youinit">${esc(CHAR.name[0])}</text>
        ${hasArt ? `<image href="chrome-art/you-ring.png" x="-15" y="-17" width="30" height="30"/>` : `<circle r="13" class="youring"/><circle cy="-14" r="2.4" class="youpin"/>`}
        <rect x="17" y="-8" width="56" height="16" rx="2" class="youtag"/><text x="45" y="4" class="youtxt">You · ${CHAR.level}</text></g>`;
    // (The uncharted wash past your level was dropped, owner 2026-11-10: it washed the map out.)
    return `<svg viewBox="0 0 ${R.W} ${R.H}" preserveAspectRatio="none" class="cmapart antique" aria-hidden="true">
      <defs><linearGradient id="cparch" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#efe1bd"/><stop offset=".5" stop-color="#e6d3a6"/><stop offset="1" stop-color="#dcc493"/></linearGradient>
        <radialGradient id="cstain" cx=".5" cy=".5" r=".75"><stop offset=".55" stop-color="#7a5a2e" stop-opacity="0"/><stop offset="1" stop-color="#7a5a2e" stop-opacity=".45"/></radialGradient>
        <radialGradient id="ccrest" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#ffe9a0" stop-opacity=".9"/><stop offset="1" stop-color="#ffe9a0" stop-opacity="0"/></radialGradient></defs>
      ${hasArt ? `<image href="${R.art}" width="${R.W}" height="${R.H}" preserveAspectRatio="none"/>` : `<rect width="${R.W}" height="${R.H}" fill="url(#cparch)"/>${hills}${trees}${marks}`}
      ${segPaths}${beads}${deadends}
      <g class="crest ${m.complete ? "lit" : ""}" transform="translate(${R.end.x} ${R.end.y})">${m.complete ? `<circle r="60" fill="url(#ccrest)"/>` : ""}
        ${hasArt ? "" : `<path d="M0 -26 L5 -5 L26 0 L5 5 L0 26 L-5 5 L-26 0 L-5 -5 Z" class="endstar"/><circle r="9" class="endstar-c"/>`}</g>
      ${you}
      ${hasArt ? "" : `<rect width="${R.W}" height="${R.H}" fill="url(#cstain)"/>`}</svg>`;
  }
  const C_STATE = { done: "Done", progress: "In progress", ready: "You can start it", later: "Later", unknown: "Not known yet" };
  const qn = (n) => `${n} quest${n === 1 ? "" : "s"}`;
  // Round 2: a later stop's label shows its reward (the seal already says the level).
  function stopSub(s) {
    if (s.state === "unknown") return `${qn(s.n)} · not known yet`;
    return s.state === "done" ? `All ${qn(s.n)} done` : s.state === "progress" ? `${s.d} of ${qn(s.n)}` : s.state === "ready" ? `Open now · ${qn(s.n)}`
      : `${s.reward.replace(/ \(.*\)$/, "")} · ${qn(s.n)}`;
  }
  function stopTip(s) {
    const when = s.state === "later" ? ` Opens at level ${s.lv} (${s.lv - CHAR.level} to go).` : "";
    const got = s.state === "unknown" ? `${qn(s.n)}; done or not isn't known yet` : s.state === "done" ? "Done" : `${s.d} of ${qn(s.n)} done`;
    return `<b>${esc(s.name)}</b>${s.kind === "side" ? "Side path. " : ""}Level ${s.lv}. ${got}. Reward: ${esc(s.reward)}.${when}`;
  }
  function classNodes(m) {
    const R = CLASS_ROAD;
    return m.stops.map(s => `<button class="cnode focusable ${s.kind} st-${s.state} ${s.x > R.W * 0.58 ? "lab-left" : ""} ${ui.classSel === s.id ? "selected" : ""}"
      data-stop="${s.id}" ${m.stops.some(x => x.from === s.id) || s.from ? "data-sidepath" : ""} style="left:${(s.x / R.W * 100).toFixed(2)}%;top:${(s.y / R.H * 100).toFixed(3)}%" data-tip="${stopTip(s)}">
      ${s.state === "done" ? classCoin() : classSketch()}<span class="clvl">${s.state === "unknown" ? "?" : s.lv}</span>
      <span class="clabel"><span class="cname">${esc(s.name)}</span></span></button>`).join("")
      + `<button class="cnode focusable end ${m.complete ? "st-done" : ""} ${ui.classSel === "end" ? "selected" : ""}" data-stop="end" style="left:${(R.end.x / R.W * 100).toFixed(2)}%;top:${(R.end.y / R.H * 100).toFixed(3)}%"
        data-tip="<b>The road's end</b>${m.complete ? "Every class quest on the road and its side paths is done." : m.unknown ? `${m.quests} class quests; done or not isn't known yet.` : `${m.questsDone} of ${m.quests} class quests done.`}"><span class="cseal"></span>
        <span class="clabel below"><span class="cname">${m.complete ? "The road walked" : "The road's end"}</span></span></button>`;
  }
  function renderClass() {
    const m = classModel(), nx = classNext(m);
    if (!ui.classSel) ui.classSel = (m.road.find(s => s.state !== "done") || { id: "end" }).id;
    const count = m.unknown ? `Road ? of ${m.road.length} · Side paths ? of ${m.side.length}` : `Road ${m.roadDone} of ${m.road.length} · Side paths ${m.sideDone} of ${m.side.length}`;
    content.innerHTML = `<div class="cjourney ${ui.wide ? "wide" : ""}"><div class="cstrip"><div class="scroll" id="scroll">
        <div class="cplaque ${m.complete ? "done" : ""}"><span class="ctitle">${CLASS_ROAD.title}</span>
          <span class="ccount">${count}</span><span class="cnext ${nx.done ? "done" : ""} ${m.unknown ? "unk" : ""}">${esc(nx.text)}</span></div>
        <div class="cmap" style="aspect-ratio:${CLASS_ROAD.W} / ${CLASS_ROAD.H}">${classStrip(m)}${classNodes(m)}</div></div>${classRail(m)}</div>
      <div class="cdetailpane" id="detailpane"></div></div>`;
    renderStopInto($("#detailpane"), m, ui.classSel);
    const sc = $("#scroll"); if (sc) { sc.addEventListener("scroll", updateRail); requestAnimationFrame(updateRail); }
  }
  // Item 13 (owner, 2026-11-09: keep scrolling, add an overview): a thin rail at the strip's right
  // edge with the whole road at a glance. One dot per stop in its state (gold done, orange in
  // progress, a peach ring open now, grey later; side paths smaller, set off the line), your
  // mark, the road's end, and a window showing the part of the road in view. Not a focus stop
  // (LT/RT already go stop to stop); a click scrolls there.
  function classRail(m) {
    const R = CLASS_ROAD, top = (y) => (y / R.H * 100).toFixed(2);
    // Round 3: your mark sits at your level on the road (as on the map); the part of the road in
    // view lights the rail line, with a brass notch at each end (no box).
    // Round 4: the rail is the map's scale bar, an ink ruler marked in levels (1, 10 … 60) at
    // their places on the road, gilded down to your brass dot.
    const segs = roadSegs(m), yAt = (lv) => { const p = levelPos(m, lv); return bez(segs[m.road[p.i].id], p.t).y; };
    const yp = { y: yAt(CHAR.level + (CHAR.xpMax ? CHAR.xp / CHAR.xpMax : 0)) };
    const ticks = [1, 10, 20, 30, 40, 50, 60].map(l => `<i class="rtick" style="top:${top(yAt(l))}%"><em>${l}</em></i>`).join("");
    const dots = m.stops.map(s => `<i class="rdot ${s.kind} st-${s.state}" data-rail="${s.id}" style="top:${top(s.y)}%"></i>`).join("");
    const you = `<b class="ryou" style="top:${top(yp.y)}%"></b>`;
    return `<div class="crail scale" aria-hidden="true"><div class="rtrack"><span class="rline"></span><span class="rfill" style="height:${top(yp.y)}%"></span>${ticks}${dots}
      <i class="rdot end ${m.complete ? "st-done" : ""}" data-rail="end" style="top:${top(R.end.y)}%"></i>${you}<span class="rview" id="railview"></span></div></div>`;
  }
  function updateRail() {
    const sc = $("#scroll"), v = $("#railview"), map = $(".cmap");
    if (!sc || !v || !map) return;
    const mapTop = map.offsetTop, h = map.offsetHeight, plaque = $(".cplaque").offsetHeight;
    const from = Math.max(0, sc.scrollTop + plaque - mapTop) / h, to = Math.min(1, (sc.scrollTop + sc.clientHeight - mapTop) / h);
    v.style.top = (from * 100).toFixed(2) + "%"; v.style.height = (Math.max(0.04, to - from) * 100).toFixed(2) + "%";
  }
  // The header: the stop's zone art behind it (round 2), dimmed and greyed while the stop is later.
  function heroHtml(cls, art, kicker, title, sub, score) {
    return `<div class="chero ${cls}"><img class="cheroart" src="zone-art/${art}.png" alt="" onerror="this.remove()"><div class="chshade"></div>
      <div class="chinfo"><div><div class="ckicker">${kicker}</div><h1>${title}</h1><div class="csubline">${sub}</div></div><div class="cscore">${score}</div></div></div>`;
  }
  // A finished stop (or the road walked) wears the quests medal from the celebration (owner,
  // 2026-11-09): cel-seal-quests inside cel-laurel, small, in place of a check and "Done".
  // Round 3: the class coin replaces the borrowed celebration medal (owner, 2026-11-10).
  const doneMedal = () => classCoin("big");
  function renderStopInto(box, m, id) {
    const nx = classNext(m);
    if (id === "end") {
      const pct = m.quests && !m.unknown ? m.questsDone / m.quests : 0;
      const score = m.complete ? doneMedal() : m.unknown ? `<b class="dim">?</b><small>of ${m.quests} quests, not known</small>` : `<b>${m.questsDone}</b><small>of ${m.quests} quests</small>`;
      box.innerHTML = heroHtml(m.complete ? "done" : "", CLASS_ROAD.stops[0].art, `Paladin · ${esc(CHAR.race)}`,
        m.complete ? "The Paladin's Road, walked" : CLASS_ROAD.title, m.complete ? "Every class quest you can do is done" : "Every class quest you can do, stop by stop", score)
        + `<div class="cbody"><div class="scroll" id="detailscroll">
        <div class="cbar ${m.complete ? "complete" : ""}"><i style="width:${(pct * 100).toFixed(1)}%"></i></div>
        <h2 class="section" data-group>The road <small>${m.unknown ? "?" : m.roadDone} of ${m.road.length} stops</small></h2>${m.road.map(s => stopRow(s, nx)).join("")}
        <h2 class="section" data-group>Side paths <small>${m.unknown ? "?" : m.sideDone} of ${m.side.length} · optional, but they count</small></h2>${m.side.map(s => stopRow(s, nx)).join("")}
        <div class="qfoot"><span class="qnote">Raid and dungeon class quests (gear turn-ins, Quel'Serrar, Dire Maul books) aren't on the road: they belong to the Dungeons tab. Quests that are another race's version of a stop, and repeatable turn-ins, never count.</span></div></div></div>`;
      return;
    }
    const s = m.stops.find(x => x.id === id); if (!s) return;
    const pos = s.kind === "road" ? `Stop ${m.road.indexOf(s) + 1} of ${m.road.length} on the road` : `Side path off ${esc(m.stops.find(x => x.id === s.from).name)}`;
    const togo = s.lv - CHAR.level;
    const score = s.state === "done" ? doneMedal() : s.state === "unknown" ? `<b class="dim">?</b><small>of ${qn(s.n)}, not known</small>`
      : s.state === "later" ? `<b class="dim">${togo}</b><small>level${togo === 1 ? "" : "s"} to go</small>` : `<b>${s.d}</b><small>of ${qn(s.n)}</small>`;
    // Round 2: quests that share a name (The Tome of Divinity x8) lead with who and where, and every
    // step is numbered in its ring; sub-quests sit in place, unnumbered and not counted.
    const same = {}; counted(s).forEach(q => { same[q[1]] = (same[q[1]] || 0) + 1; });
    let num = 0, nextGiven = false;
    const rows = s.steps.map(q => {
      const sub = q[5] === "sub", isDone = s.done.has(q[0]);
      if (!sub) num++;
      let st = s.state === "unknown" ? "unknown" : isDone ? "done" : s.state === "later" ? "later" : nextGiven ? "after" : (nextGiven = true, "next");
      if (sub && st !== "done") st = "sub";
      const icon = st === "done" ? "✓" : st === "unknown" ? "?" : sub ? "·" : num;
      const where = `${q[2]} · ${zoneOfPlace(q[3]) ? q[3] : q[3]}`;
      const cap = (t) => t.charAt(0).toUpperCase() + t.slice(1);
      const lead = same[q[1]] > 1 && !sub ? [cap(where), q[1]] : [q[1], where];
      const lv = sub ? "not counted" : q[4] > s.lv ? `from ${q[4]}` : "";
      const tip = `<b>${esc(q[1])}</b>${st === "done" ? "Done. " : st === "next" ? "Your next step. " : sub ? "Done inside the step before it; not counted (QuestieDB flags it repeatable). " : ""}${esc(q[2])} · ${esc(q[3])}.${q[4] > s.lv ? ` From level ${q[4]}.` : ""}`;
      return `<button class="cstep focusable st-${st}" data-step="${q[0]}" data-tip="${tip}">
        <span class="cicon">${icon}</span><span class="cqname">${esc(lead[0])}<small>${esc(lead[1])}</small></span><span class="cqlv">${lv}</span></button>`;
    }).join("");
    const leadins = (s.leadins || []).map(q => `<button class="cstep focusable st-${s.done.has(q[0]) ? "done" : "after"} opt" data-step="${q[0]}" data-tip="<b>${esc(q[1])}</b>${esc(q[5])} ${esc(q[2])} · ${esc(q[3])}.">
        <span class="cicon">${s.done.has(q[0]) ? "✓" : "›"}</span><span class="cqname">${esc(q[1])}<small>${esc(q[2])} · ${esc(q[3])}</small></span><span class="cqlv">not counted</span></button>`).join("");
    box.innerHTML = heroHtml(`st-${s.state}`, s.art, pos, esc(s.name), `Reward: ${esc(s.reward)}`, score)
      + `<div class="cbody"><div class="scroll" id="detailscroll"><div class="cstopgrid">
      <div class="caside">
        <div class="cfacts"><div><span class="rk">Where it starts</span>${esc(shortStart(s.start))}</div><div><span class="rk">Level</span>${s.lv}</div>
          <div><span class="rk">Travels to</span>${s.travels.map(esc).join(" → ")}</div></div>
        ${s.flag ? `<div class="cflag">${esc(s.flag)}</div>` : ""}
        ${s.alt ? `<p class="fdesc">${esc(s.alt)}</p>` : ""}
      </div>
      <div class="cmain">
        ${leadins ? `<h2 class="section" data-group>Start here <small>optional · not counted</small></h2><div class="csteps">${leadins}</div>` : ""}
        <h2 class="section" data-group>Steps <small>${s.d === null ? "?" : s.d} of ${s.n} done</small></h2><div class="csteps">${rows}</div>
        <div class="qfoot"><span class="qnote">Steps and starters from QuestieDB and the curated journey; done or not is read from the game.</span></div>
      </div></div></div></div>`;
  }
  function stopRow(s, nx) {
    const here = nx && nx.stop === s;
    return `<button class="cstep focusable st-${s.state === "done" ? "done" : s.state === "later" ? "later" : s.state === "progress" ? "next" : s.state === "unknown" ? "unknown" : "after"}" data-goto="${s.id}" data-tip="${stopTip(s)} A goes to it on the road.">
      <span class="cicon">${s.state === "done" ? "✓" : s.state === "unknown" ? "?" : s.state === "later" ? "🔒" : s.state === "progress" ? "◐" : "○"}</span>
      <span class="cqname">${esc(s.name)}${here ? `<em class="youhere">You are here</em>` : ""}<small>Level ${s.lv} · ${esc(s.reward)}</small></span><span class="cqlv">${s.d === null ? "?" : s.d} / ${s.n}</span></button>`;
  }
  function restoreClass() { setFocus($(`.cnode[data-stop="${ui.classSel}"]`) || $(".cnode")); }

  // =====================================================================================
  // Render + hints
  // =====================================================================================
  const HINTS = {
    overview: [["A", "A", "Select"], ["LT", "LT/RT", "Section"], ["LB", "LB/RB", "Tabs"], ["B", "B", "Close"]],
    zones: [["A", "A", "Open"], ["Y", "Y", "View"], ["X", "X", "Search"], ["LT", "LT/RT", "Section"], ["B", "B", "Close"]],
    zonesWide: [["A", "A", "Checklist"], ["Y", "Y", "View"], ["X", "X", "Search"], ["LT", "LT/RT", "Section"], ["B", "B", "Close"]],
    detail: [["A", "A", "Open"], ["X", "X", "World map"], ["B", "B", "Zones"]],
    detailPage: [["A", "A", "Select"], ["X", "X", "World map"], ["LT", "LT/RT", "Section"], ["B", "B", "Overview"]],
    flyout: [["DP", "✥", "Choose"], ["A", "A", "Apply"], ["B", "B", "Cancel"]],
    rep: [["A", "A", "Open"], ["X", "X", "Watch"], ["Y", "Y", "Sort"], ["LT", "LT/RT", "Section"], ["B", "B", "Close"]],
    repWide: [["A", "A", "Details"], ["X", "X", "Watch"], ["Y", "Y", "Sort"], ["LT", "LT/RT", "Section"], ["B", "B", "Close"]],
    repPage: [["A", "A", "Open"], ["X", "X", "Watch"], ["B", "B", "Reputation"]],
    class: [["A", "A", "Steps"], ["LT", "LT/RT", "Stop"], ["LB", "LB/RB", "Tabs"], ["B", "B", "Close"]],
    classSide: [["A", "A", "Steps"], ["DP", "◀▶", "Side path"], ["LT", "LT/RT", "Stop"], ["LB", "LB/RB", "Tabs"], ["B", "B", "Close"]],
    classSteps: [["DP", "✥", "Step"], ["B", "B", "Road"]],
  };
  function screen() {
    if (ui.tab === "class") return "class";
    if (ui.tab === "reputation") return ui.wide ? "repWide" : ui.repOpen ? "repPage" : "rep";
    return ui.tab === "zones" ? (ui.detail && !ui.wide ? "detail" : ui.wide ? "zonesWide" : "zones") : "overview";
  }
  function render() {
    renderHeader();
    $$(".tab").forEach(t => t.classList.toggle("active", t.dataset.tab === ui.tab));
    const sc = screen();
    if (sc === "class") renderClass();
    else if (sc === "rep" || sc === "repWide") renderReputation();
    else if (sc === "repPage") renderFactionInto(content, allFactions().find(f => f.id === ui.repOpen), { back: true });
    else if (sc === "overview") renderOverview();
    else if (sc === "detail") renderDetailInto(content, byName[ui.detail], { back: true });
    else renderZones();
    setHints(ui.flyout ? "flyout" : sc === "detail" && ui.detailPage ? "detailPage" : sc);
    hideTooltip();
  }
  function setHints(key) { $("#hints").innerHTML = HINTS[key].map(([cls, g, t]) => `<span><span class="glyph ${cls}">${g}</span>${t}</span>`).join(""); }

  // Focus restore: remember what was focused by its data attributes, find it again after a re-render.
  function keyOf(el) {
    if (!el) return null;
    const d = el.dataset, parts = [];
    for (const a of ["open", "crit", "quest", "story", "flight", "page", "na", "next", "rep", "rq", "tab", "cycle", "status", "view", "go", "faction", "src", "rfilter", "stop", "step", "goto"]) if (d[a] !== undefined) parts.push(`[data-${a}="${CSS.escape(d[a])}"]`);
    for (const a of ["search", "back", "map", "atlas", "qtoggle"]) if (d[a] !== undefined) parts.push(`[data-${a}]`);
    if (el.id) parts.push("#" + el.id);
    return parts.length ? "." + [...el.classList].filter(c => !["focused", "on", "new", "selected"].includes(c))[0] + parts.join("") : null;
  }
  function rerenderKeepFocus() {
    const k = keyOf(focused);
    render();
    const el = k && $(k);
    setFocus(el || $("#content .focusable"), { noScroll: false });
  }

  // =====================================================================================
  // Navigation and actions
  // =====================================================================================
  function setTab(tab) {
    if (ui.tab === "zones" && !ui.detail) ui.zonesScroll = $("#scroll")?.scrollTop || 0;
    if (ui.tab === "reputation" && !ui.repOpen) ui.repScroll = $("#scroll")?.scrollTop || 0;
    ui.tab = tab; ui.flyout = null;
    render();
    if (tab === "zones" && !ui.detail) restoreCatalog(); else if (tab === "reputation") restoreRep(); else if (tab === "class") restoreClass(); else focusFirst();
  }
  // The Reputation list: back to the faction you were on (or the first one), scroll kept.
  function restoreRep() {
    if (ui.repOpen) return setFocus($("#content .srow") || $("[data-back]"));
    const sc = $("#scroll");
    if (sc) { sc.style.scrollBehavior = "auto"; sc.scrollTop = ui.repScroll || 0; sc.style.scrollBehavior = ""; }
    setFocus($(`#scroll [data-faction="${ui.repSel}"]`) || $("#scroll .focusable") || $(".toolbar .focusable"));
  }
  const TABS = ["overview", "zones", "reputation", "class"];
  const nextTab = (d) => TABS[(TABS.indexOf(ui.tab) + d + TABS.length) % TABS.length];
  function openZone(name, crit) {
    if (ui.tab === "zones" && !ui.detail) ui.zonesScroll = $("#scroll")?.scrollTop || 0;
    ui.tab = "zones"; ui.lastZone = name;
    ui.detailPage = crit ? "explore" : null; // an area chip opens the Exploration page; a zone opens its overview
    if (ui.wide) { ui.selected = name; ui.detail = null; ui.view = "list"; render(); const sel = $(`.zrow[data-open="${CSS.escape(name)}"]`); if (sel) sel.scrollIntoView({ block: "center" });
      const t = crit && $(`#detailpane .check[data-crit="${crit}"]`); setFocus(t || $("#detailpane .ctile[data-page]") || sel); return; }
    ui.detail = name; render();
    const target = crit && $(`.check[data-crit="${crit}"]`);
    setFocus(target || $(".ctile[data-page]") || $("[data-back]"));
  }
  function back() {
    if (ui.celebrate) return closeCelebrate();
    if (ui.flyout) return closeFlyout();
    if (ui.tab === "class" && focused && focused.closest("#detailpane")) { setHints("class"); return restoreClass(); }
    if (ui.tab === "reputation" && ui.repOpen) { ui.repOpen = null; render(); return restoreRep(); }
    if (ui.tab === "reputation" && ui.wide && focused && focused.closest("#detailpane")) return setFocus($(`.frep[data-faction="${ui.repSel}"]`));
    // A category page goes back to the zone's overview, focused on that category's tile.
    if (ui.tab === "zones" && ui.detailPage && (ui.detail || ui.wide)) { const pg = ui.detailPage; ui.detailPage = null; render(); return setFocus($(`[data-page="${pg}"]`) || $(".ctile")); }
    if (ui.tab === "zones" && ui.wide && focused && focused.closest("#detailpane")) return setFocus($(`.zrow[data-open="${CSS.escape(ui.selected)}"]`));
    if (ui.tab === "zones" && ui.detail) { ui.detail = null; render(); return restoreCatalog(); }
    closeWindow();
  }
  function restoreCatalog() {
    const sc = $("#scroll");
    if (sc) { sc.style.scrollBehavior = "auto"; sc.scrollTop = ui.zonesScroll; sc.style.scrollBehavior = ""; }
    const want = ui.lastZone || (ui.wide && ui.selected) || (ui.view === "atlas" && CHAR.zone);
    const last = want && $(`#scroll [data-open="${CSS.escape(want)}"]`);
    if (last && ui.wide) last.scrollIntoView({ block: "center" });
    setFocus(last || $("#scroll .focusable") || $(".toolbar .focusable"));
  }
  function closeWindow() { $("#window").hidden = true; $("#reopen").hidden = false; hideTooltip(); placePointer(); }
  function reopen() { $("#window").hidden = false; $("#reopen").hidden = true; render(); focusFirst(); }
  function toast(html, ms = 2200) { const t = $("#toast"); t.innerHTML = html; t.hidden = false; clearTimeout(toast.timer); toast.timer = setTimeout(() => (t.hidden = true), ms); }

  // Filter flyout (gamepad-friendly dropdown).
  function openFlyout(key, anchor) {
    closeFlyout();
    ui.flyout = key;
    const w = $("#window").getBoundingClientRect(), r = anchor.getBoundingClientRect(), s = currentScale;
    const fly = document.createElement("div");
    fly.className = "flyout"; fly.id = "flyout";
    fly.style.left = (r.left - w.left) / s + "px"; fly.style.top = (r.bottom - w.top) / s + 4 + "px";
    fly.innerHTML = OPTIONS[key].items.map(([v, l]) => `<button class="focusable ${ui[key] === v ? "on" : ""}" data-choose="${v}">${l}</button>`).join("");
    $("#window").appendChild(fly);
    setHints("flyout");
    setFocus($("#flyout .on") || $("#flyout button"));
  }
  function closeFlyout(apply) {
    const key = ui.flyout; const fly = $("#flyout");
    if (fly) fly.remove();
    ui.flyout = null;
    if (key) { if (apply !== undefined) ui[key] = apply; render(); setFocus($(`[data-cycle="${key}"]`)); }
  }

  function activate(el) {
    if (!el) return;
    const d = el.dataset;
    if (d.choose !== undefined) return closeFlyout(d.choose);
    if (el.classList.contains("cel-ok")) return closeCelebrate();
    if (d.tab) return setTab(d.tab);
    if (el.id === "closeBtn") return closeWindow();
    if (d.back !== undefined) return back();
    if (d.stop) { // Class tab: A on a stop moves into its steps
      const first = $("#detailpane .cstep"); if (!first) return;
      setHints("classSteps"); return setFocus(first);
    }
    if (d.goto) { ui.classSel = d.goto; renderStopInto($("#detailpane"), classModel(), d.goto); setHints("class"); return restoreClass(); }
    if (d.step) return; // a quest step: details in the info line
    if (d.rfilter) { ui.repFilter = d.rfilter; render(); return setFocus($(`[data-rfilter="${d.rfilter}"]`)); }
    if (d.faction) { // Reputation tab: open the faction's page (wide: move into it)
      const id = Number(d.faction); ui.repSel = id;
      if (ui.wide) return setFocus($("#detailpane .srow") || el);
      ui.repScroll = $("#scroll")?.scrollTop || 0; ui.repOpen = id; render(); return restoreRep();
    }
    if (d.src) { // a place that raises the faction: a zone opens its page (the faction's own when it has one)
      const [kind, place] = d.src.split(/\|(.*)/), id = ui.repOpen || ui.repSel;
      if (el.classList.contains("notyou")) return;
      if (kind !== "zone" || !byName[place]) return toast(`Would open ${esc(place)} in the Dungeons tab<small>(a later phase)</small>`);
      const page = (REP_ZONES[place] || []).some(p => p[0] === id) ? `rep:${id}` : null;
      ui.tab = "zones"; ui.lastZone = place;
      if (ui.wide) { ui.selected = place; ui.detail = null; ui.view = "list"; ui.detailPage = page; render(); return setFocus($("#detailpane .detail .scroll .focusable") || $("#detailpane .ctile")); }
      ui.detail = place; ui.detailPage = page; render();
      return setFocus($("#content .detail .scroll .focusable") || $("[data-back]"));
    }
    if (d.open && d.next) { // an Overview suggestion: open the zone, then its page on that item
      openZone(d.open);
      return activate({ dataset: { next: d.next }, classList: { contains: () => false } });
    }
    if (d.open && !(ui.wide && el.classList.contains("zrow"))) return openZone(d.open, d.crit);
    if (d.open && ui.wide) { // wide: A on a row moves into its checklist
      return setFocus($("#detailpane .ctile[data-page]") || $("#detailpane .ctile"));
    }
    if (d.atlas !== undefined) { ui.view = "atlas"; ui.detail = null; ui.lastZone = CHAR.zone; return setTab("zones"); }
    if (d.go) return setTab(d.go);
    if (d.status) { ui.status = d.status; render(); return setFocus($(`[data-status="${d.status}"]`)); }
    if (d.view) { ui.view = d.view; render(); return restoreCatalog(); }
    if (d.cycle) return openFlyout(d.cycle, el);
    if (d.search !== undefined) return $("#searchInput").focus();
    if (d.map !== undefined) return toast(`Would open the world map at ${esc(ui.detail || ui.selected)}`);
    if (d.qtoggle !== undefined) { ui.showUnavailable = !ui.showUnavailable; return rerenderKeepFocus(); }
    if (d.page) { ui.detailPage = d.page; render(); return setFocus($("#content .detail .scroll .focusable") || $("#content .detail [data-back]")); }
    if (d.na || d.rq) return; // a quest on a faction's page: details in the info line
    if (d.next) { // Next up: open the category's page focused on that item
      const [kind, id] = d.next.split(/:(.*)/);
      ui.detailPage = { explore: "explore", quest: "quests", flight: "flights" }[kind]; render();
      const sel = kind === "explore" ? `[data-crit="${id}"]` : kind === "quest" ? `[data-quest="${id}"]` : `[data-flight="${CSS.escape(id)}"]`;
      return setFocus($(`#content .detail ${sel}`) || $("#content .detail .scroll .focusable"));
    }
    if (d.story) { const id = Number(d.story); ui.openStories.has(id) ? ui.openStories.delete(id) : ui.openStories.add(id); return rerenderKeepFocus(); }
    if (d.quest || d.flight) return; // A on a quest or flight path: nothing yet (details show in the info line)
    if (d.crit) return setFocus($("[data-map]"));
  }

  // Live discovery simulation: shows how every view updates, plus the completion moment.
  function simulateDiscovery() {
    const z = byName[CHAR.zone];
    const nextC = z.criteria.find(c => !c.done);
    if (!nextC) return toast(`${esc(z.name)} is already fully explored.<small>Switch Data to try again.</small>`);
    (S.done[z.name] = S.done[z.name] || []).push(nextC.name);
    ui.newCrit = nextC.id;
    buildModel();
    const nz = byName[z.name];
    toast(`Discovered: ${esc(nextC.name)}<small>${nz.done} of ${nz.total} in ${esc(z.name)}</small>`);
    rerenderKeepFocus();
    if (nz.done === nz.total) setTimeout(() => celebrate(nz, nz.state === "complete" ? "claim" : "explore"), 900);
    setTimeout(() => { ui.newCrit = null; }, 1500);
  }
  function closeCelebrate(quiet) { $("#celebrate")?.remove(); ui.celebrate = null; if (!quiet) rerenderKeepFocus(); }

  // =====================================================================================
  // Focus engine (spatial stand-in for the addon's explicit focus grid)
  // =====================================================================================
  let focused = null;
  function scope() { return $("#celebrate") || $("#flyout") || $("#window"); }
  function visibleFocusables() { return $$(".focusable", scope()).filter(el => el.offsetParent !== null); }
  // Native focus pointer: the yellow chevron (SmartNavigation's gamepad-largecursor-white) left of the
  // focused control. Hidden when the control is scrolled out of its list.
  function placePointer() {
    const p = $("#pointer");
    if (!focused || !document.contains(focused) || $("#window").hidden) { p.hidden = true; return; }
    const w = $("#window").getBoundingClientRect(), r = focused.getBoundingClientRect(), s = currentScale;
    const sc = focused.closest(".scroll");
    if (sc) { const b = sc.getBoundingClientRect(), cy = r.top + r.height / 2; if (cy < b.top || cy > b.bottom) { p.hidden = true; return; } }
    p.hidden = false;
    p.style.left = ((r.left - w.left) / s - 20) + "px";
    p.style.top = ((r.top - w.top) / s + r.height / s / 2 - 11) + "px";
  }
  function setFocus(el, o = {}) {
    if (focused) focused.classList.remove("focused");
    focused = el || null;
    if (!el) { placePointer(); return hideTooltip(); }
    el.classList.add("focused");
    if (!o.noScroll) el.scrollIntoView({ block: "nearest", inline: "nearest" });
    requestAnimationFrame(placePointer);
    showInfo(el); // gamepad focus describes itself in the footer, never in a floating tooltip
    hideTooltip();    // Focus-driven updates: checklist info, and the wide split's detail pane.
    if (el.dataset.quest || el.dataset.crit || el.dataset.flight) {
      const z = byName[ui.detail || ui.selected];
      if (z && el.dataset.quest) showQuestInfo(z, el);
      else if (z && el.dataset.crit) showFocusInfo(z, z.criteria.find(c => String(c.id) === el.dataset.crit));
      else if (z) { const box = $("#focusinfo"); const n = catOf(z, "flights").nodes.find(x => x.name === el.dataset.flight);
        if (box && n) box.innerHTML = `<h3>${esc(n.name)}</h3><div class="state ${n.known ? "done" : "todo"}">${n.known ? "✓ Known flight path" : "✈ Not discovered yet"}</div>`; }
    }
    if (ui.wide && ui.tab === "zones" && el.classList.contains("zrow") && el.dataset.open !== ui.selected) {
      ui.selected = el.dataset.open; ui.detailPage = null;
      $$(".zrow.selected").forEach(r => r.classList.remove("selected"));
      el.classList.add("selected");
      renderDetailInto($("#detailpane"), byName[ui.selected], { back: false });
    }
    if (ui.tab === "class" && el.dataset.stop) {
      if (el.dataset.stop !== ui.classSel || !$("#detailpane .chero")) {
        ui.classSel = el.dataset.stop;
        $$(".cnode.selected").forEach(r => r.classList.remove("selected"));
        el.classList.add("selected");
        renderStopInto($("#detailpane"), classModel(), ui.classSel);
      }
      setHints(el.hasAttribute("data-sidepath") ? "classSide" : "class");
    }
    if (ui.wide && ui.tab === "reputation" && el.dataset.faction && Number(el.dataset.faction) !== ui.repSel) {
      ui.repSel = Number(el.dataset.faction);
      $$(".frep.selected").forEach(r => r.classList.remove("selected"));
      el.classList.add("selected");
      renderFactionInto($("#detailpane"), allFactions().find(f => f.id === ui.repSel), { back: false });
    }
  }
  function focusFirst() { setFocus($("#content .focusable") || $(".tab.active")); }
  function move(dir) {
    if (!focused || !document.contains(focused)) return focusFirst();
    const a = focused.getBoundingClientRect();
    const ax = a.left + a.width / 2, ay = a.top + a.height / 2;
    const horizontal = dir === "left" || dir === "right";
    const sign = dir === "left" || dir === "up" ? -1 : 1;
    let aligned = null, alignedScore = Infinity, coned = null, conedScore = Infinity;
    for (const el of visibleFocusables()) {
      if (el === focused) continue;
      const b = el.getBoundingClientRect();
      const main = horizontal ? (sign > 0 ? b.left - a.right : a.left - b.right) : (sign > 0 ? b.top - a.bottom : a.top - b.bottom);
      if (main < -2) continue;
      const overlap = horizontal ? Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) : Math.min(a.right, b.right) - Math.max(a.left, b.left);
      if (overlap > 4) { const sc = main + (horizontal ? Math.abs(b.top - a.top) : Math.abs(b.left - a.left)) * 0.1; if (sc < alignedScore) { alignedScore = sc; aligned = el; } continue; }
      const dx = b.left + b.width / 2 - ax, dy = b.top + b.height / 2 - ay;
      const along = horizontal ? sign * dx : sign * dy, across = Math.abs(horizontal ? dy : dx);
      if (along <= 0 || across > along) continue;
      const score = along + across * 2;
      if (score < conedScore) { conedScore = score; coned = el; }
    }
    const best = aligned || coned;
    if (best) setFocus(best);
  }
  // LT/RT: jump to the previous/next section header (in document order) that has focusable content;
  // pages instead when the current scroll area has no sections.
  function jump(dir) {
    if (ui.tab === "class" && !(focused && focused.closest("#detailpane"))) { // LT/RT: previous / next stop on the road
      const order = CLASS_ROAD.stops.filter(s => s.kind === "road").map(s => s.id).concat("end");
      const i = order.indexOf(focused && focused.dataset.stop), from = i < 0 ? order.indexOf((CLASS_ROAD.stops.find(s => s.id === (focused && focused.dataset.stop)) || {}).from) : i;
      const t = order[Math.max(0, Math.min(order.length - 1, from + dir))];
      return setFocus($(`.cnode[data-stop="${t}"]`));
    }
    const sc = (focused && focused.closest(".scroll")) || $("#scroll"); if (!sc) return;
    const firstAfter = (h) => $$(".focusable", sc).find(el => h.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING);
    const heads = $$("[data-group]", sc).filter(h => firstAfter(h));
    if (heads.length) {
      const before = (h) => focused && (h.compareDocumentPosition(focused) & Node.DOCUMENT_POSITION_FOLLOWING);
      let cur = -1; heads.forEach((h, i) => { if (before(h)) cur = i; });
      // Backwards: to the start of the current section, or the previous one if already at its start.
      const atStart = cur >= 0 && focused === firstAfter(heads[cur]);
      const target = dir > 0 ? heads[cur + 1] : heads[atStart ? cur - 1 : cur];
      if (target) { const first = firstAfter(target); target.scrollIntoView({ block: "start" }); setFocus(first, { noScroll: true }); }
      return;
    }
    sc.scrollBy({ top: dir * sc.clientHeight * 0.85 });
    setTimeout(() => { const r = sc.getBoundingClientRect();
      const first = $$(".focusable", sc).find(el => { const b = el.getBoundingClientRect(); return b.top >= r.top && b.bottom <= r.bottom; });
      if (first) setFocus(first, { noScroll: true }); }, 350);
  }

  // =====================================================================================
  // Tooltip
  // =====================================================================================
  function showTooltip(el) {
    const tip = el.dataset.tip, t = $("#tooltip");
    if (!tip || ui.celebrate) return hideTooltip();
    t.innerHTML = tip; t.hidden = false;
    const w = $("#window").getBoundingClientRect(), r = el.getBoundingClientRect(), s = currentScale, W = winW();
    let left = (r.right - w.left) / s + 10, top = (r.top - w.top) / s;
    if (r.width / s > 420) { left = (r.right - w.left) / s - 310; top = (r.bottom - w.top) / s + 6; }
    else if (left + 310 > W) left = (r.left - w.left) / s - 310;
    if (top + 90 > 740) top = (r.top - w.top) / s - 90;
    t.style.left = Math.max(8, left) + "px"; t.style.top = Math.max(8, top) + "px";
  }
  function hideTooltip() { $("#tooltip").hidden = true; }
  // Footer info line: the focused control's description (console-style).
  function showInfo(el) {
    const tip = el && el.dataset.tip;
    $("#info").innerHTML = tip ? tip.replace(/<b>(.*?)<\/b>/, "<b>$1</b>") : "";
  }

  // =====================================================================================
  // Input
  // =====================================================================================
  document.addEventListener("keydown", (e) => {
    if ($("#window").hidden) { if (e.key === "Enter") reopen(); return; }
    if (document.activeElement && document.activeElement.id === "searchInput") return;
    if (e.target.closest && e.target.closest(".devbar")) return;
    const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
    const map = {
      ArrowUp: () => move("up"), ArrowDown: () => move("down"), ArrowLeft: () => move("left"), ArrowRight: () => move("right"),
      Enter: () => activate(focused), " ": () => activate(focused), Escape: back, Backspace: back,
      q: () => !ui.flyout && !ui.celebrate && setTab(nextTab(-1)),
      e: () => !ui.flyout && !ui.celebrate && setTab(nextTab(1)),
      y: () => { if (ui.tab === "reputation" && !ui.repOpen && !ui.flyout) { const v = OPTIONS.repSort.items.map(x => x[0]); ui.repSort = v[(v.indexOf(ui.repSort) + 1) % v.length]; render(); return restoreRep(); }
        if (ui.tab === "zones" && !ui.detail && !ui.flyout) { const v = VIEWS().map(x => x[0]); ui.view = v[(v.indexOf(ui.view) + 1) % v.length]; render(); restoreCatalog(); } },
      x: () => { if (ui.flyout || ui.celebrate) return;
        if (ui.tab === "reputation") { const id = ui.repOpen || (focused && Number(focused.dataset.faction)) || (ui.wide && ui.repSel); if (id) toggleWatch(id); return; }
        if (ui.tab === "zones" && (ui.detail || (ui.wide && focused && focused.closest("#detailpane")))) toast(`Would open the world map at ${esc(ui.detail || ui.selected)}`); else if (ui.tab === "zones") { setFocus($("[data-search]")); $("#searchInput").focus(); } },
      PageDown: () => jump(1), PageUp: () => jump(-1),
    };
    const fn = map[k];
    if (fn) { e.preventDefault(); fn(); }
  });
  document.addEventListener("click", (e) => {
    if (e.target.closest(".devbar")) return;
    if (ui.flyout && !e.target.closest("#flyout")) { closeFlyout(); return; }
    const el = e.target.closest("#window .focusable");
    if (!el) return;
    if (el.dataset.search !== undefined) { setFocus(el); return; }
    setFocus(el, { noScroll: true });
    activate(el);
  });
  document.addEventListener("mouseover", (e) => {
    const el = e.target.closest("#window .focusable");
    if (el) showTooltip(el); else hideTooltip(); // floating tooltips are for the mouse only
  });
  $("#reopen").addEventListener("click", reopen);
  document.addEventListener("scroll", (e) => { if (e.target.classList && e.target.classList.contains("scroll")) { placePointer(); if (!e.target._programmatic) hideTooltip(); } }, true);

  // =====================================================================================
  // Dev controls and scaling
  // =====================================================================================
  function loadScenario(name) {
    ui.scenarioName = name;
    S = SCENARIOS[name]();
    CHAR = S.char;
    ui.detail = null; ui.selected = null; ui.lastZone = null; ui.repOpen = null; ui.repSel = null; ui.watched = null; ui.classSel = null;
    $("#celebrate")?.remove(); ui.celebrate = null; closeFlyout();
    buildModel();
  }
  $("#scenario").addEventListener("change", (e) => { loadScenario(e.target.value); render(); if (ui.tab === "class") restoreClass(); else focusFirst(); e.target.blur(); });
  $("#simulate").addEventListener("click", (e) => { simulateDiscovery(); e.target.blur(); });
  $("#questMode").innerHTML = Object.entries(QUEST_MODES).map(([v, l]) => `<option value="${v}">${l}</option>`).join("");
  $("#questMode").addEventListener("change", (e) => { ui.quests = e.target.value; buildModel(); rerenderKeepFocus(); e.target.blur(); });
  $("#celebrateSel").addEventListener("change", (e) => {
    const kind = e.target.value; e.target.value = ""; e.target.blur();
    const z = byName[ui.detail || ui.selected || CHAR.zone];
    if (!kind || !z || !z.tracked) return;
    if (kind === "alert") return gameAlert(z, "explore");
    celebrate(z, kind);
  });
  $("#lookSel").addEventListener("change", (e) => { ui.look = e.target.value; rerenderKeepFocus(); e.target.blur(); });
  $("#repBarSel").addEventListener("change", (e) => { ui.repBar = e.target.value; rerenderKeepFocus(); e.target.blur(); });
  // Standing-strip plaque background: a tinted painted fill (cloth or enamel) or round 1's top line.
  const setStrip = (v) => { ["cloth", "enamel", "line"].forEach(k => document.body.classList.toggle(`strip-${k}`, k === v)); };
  setStrip("cloth");
  $("#stripSel").addEventListener("change", (e) => { setStrip(e.target.value); e.target.blur(); });
  $("#claimPreview").addEventListener("change", (e) => { ui.claimPreview = e.target.checked; rerenderKeepFocus(); e.target.blur(); });
  $("#wideToggle").addEventListener("change", (e) => {
    ui.wide = e.target.checked; ui.detail = null;
    document.documentElement.style.setProperty("--win-w", winW() + "px");
    ui.repOpen = null;
    fit(); render(); if (ui.tab === "zones") restoreCatalog(); else if (ui.tab === "reputation") restoreRep(); else if (ui.tab === "class") restoreClass(); else focusFirst(); e.target.blur();
  });
  $("#classSel").addEventListener("change", (e) => { ui.classPreview = e.target.value; ui.classSel = null; render(); if (ui.tab === "class") restoreClass(); e.target.blur(); });
  let currentScale = 1;
  function fit() {
    const stage = $("#stage").getBoundingClientRect();
    // Room for the parts outside the frame: side tabs (right), legend box (below), portrait ring and glow.
    currentScale = $("#scaleToggle").checked ? Math.min((stage.width - 2 * 80) / winW(), (stage.height - 2 * 70) / 740, 1.6) : 1;
    $("#window").style.transform = `translateY(-20px) scale(${currentScale})`;
    placePointer();
  }
  window.addEventListener("resize", fit);
  $("#scaleToggle").addEventListener("change", (e) => { fit(); e.target.blur(); });

  // Painted tab icons and chrome, when the art pipeline has produced them.
  for (const t of ["overview", "zones", "reputation"]) {
    const b = $(`.tab[data-tab="${t}"]`);
    if (b && hasIcon(t)) b.innerHTML = `<img src="icon-art/icon-${t}.png" alt="">`;
  }
  document.body.classList.toggle("chrome", hasChrome("frame-card"));
  if (hasChrome("frame-card")) {
    const r = document.documentElement.style, card = ART.chrome["frame-card"], bar = ART.chrome["frame-bar"] || { x: .08, y: .33 };
    r.setProperty("--card-slice", `${Math.round(card.y * 100)}% ${Math.round(card.x * 100)}%`);
    r.setProperty("--bar-slice", `${Math.round(bar.y * 100)}% ${Math.round(bar.x * 100)}%`);
  }
  // Reputation ladder pieces (art/prompts.md): painted step housings and the tinted pale fill
  // once the art exists; the CSS ladder until then. The header rule uses the painted divider.
  document.body.classList.toggle("repstep", hasChrome("frame-step"));
  document.body.classList.toggle("repfill", hasChrome("bar-fill-white"));
  document.body.classList.toggle("repdiv", hasChrome("divider"));
  document.body.classList.toggle("plaque", hasChrome("frame-plaque"));
  document.body.classList.toggle("fill-cloth", hasChrome("plaque-fill-cloth"));
  document.body.classList.toggle("fill-enamel", hasChrome("plaque-fill-enamel"));
  if (hasChrome("frame-plaque")) { const p = ART.chrome["frame-plaque"], s = p === true ? { x: .08, y: .14 } : p;
    document.documentElement.style.setProperty("--plaque-slice", `${Math.round(s.y * 100)}% ${Math.round(s.x * 100)}%`); }
  if (hasChrome("frame-step")) { const st = ART.chrome["frame-step"], s = st === true ? { x: .12, y: .2 } : st;
    document.documentElement.style.setProperty("--step-slice", `${Math.round(s.y * 100)}% ${Math.round(s.x * 100)}%`); }

  loadScenario("today");
  render();
  fit();
  focusFirst();
})();
