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
      questScale: "veteran", flightsRead: ["Eastern Kingdoms", "Kalimdor"],
      milestones: [
        { t: ago(12, 20, 10), kind: "zone", zone: "Elwynn Forest" }, { t: ago(9, 21, 40), kind: "zone", zone: "Westfall" },
        { t: ago(6, 19, 5), kind: "zone", zone: "Loch Modan" }, { t: ago(4, 22, 15), kind: "area", area: "Lakeridge Highway", zone: "Redridge Mountains" },
        { t: ago(3, 18, 30), kind: "area", area: "Three Corners", zone: "Redridge Mountains" }, { t: ago(1, 20, 0), kind: "area", area: "Raven Hill", zone: "Duskwood" },
        { t: ago(0, 21, 12), kind: "area", area: "Darkshire", zone: "Duskwood" }, { t: ago(0, 21, 30), kind: "area", area: "Manor Mistmantle", zone: "Duskwood" },
      ],
    }),
    fresh: () => ({
      char: { name: "Elowen", level: 1, race: "Human", className: "Paladin", faction: "Alliance", xp: 0, xpMax: 400, zone: "Elwynn Forest", subzone: "Northshire Abbey" },
      done: {}, milestones: [], flights: [], questScale: 0, flightsRead: [],
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
  const ui = { tab: "overview", detail: null, view: "cards", faction: "relevant", status: "all", level: "all", sort: "recommended",
    search: "", zonesScroll: 0, lastZone: null, selected: null, flyout: null, wide: false, newCrit: null, celebrate: null,
    quests: "loaded", showUnavailable: false, openStories: new Set(), detailPage: null, look: "Alliance" };
  const OPTIONS = {
    faction: { label: "Show", items: [["relevant", "Relevant to me"], ["all", "All zones"]] },
    level: { label: "Level", items: [["all", "All levels"], ["appropriate", "For my level"]] },
    sort: { label: "Sort", items: [["recommended", "Recommended"], ["alphabetical", "A–Z"], ["highest", "Highest %"], ["lowest", "Lowest %"], ["closest", "Closest to done"]] },
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
        <div class="info"><div><h1>${page ? `${CATS[page].label}<span class="crumb"> · ${esc(z.name)}</span>` : esc(z.name)}</h1>
          <div class="sub"><span>${levels(z)}</span>${facBadge(z)}<span>${esc(z.continent)}</span>
          ${next && !page ? `<span class="next">· Next: ${esc(next.name)} (${shortLv(next)})</span>` : ""}</div></div>
          ${page ? `<div class="pagescore">${catOf(z, page) ? `${catOf(z, page).done} of ${catOf(z, page).total}<b>${pctText(catOf(z, page).pct)}</b>` : ""}</div>` : zscore}</div></div>`;
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
    else body = `<div class="detail-body full"><div class="scroll" id="${scrollId}">${page === "quests" ? questSection(z) : flightSection(z)}</div></div>`;
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
      <div class="dashright"><div class="tiles row3">${exTile}${qTile}${fTile}</div>${nextUp(z, r)}</div></div>`;
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
    const rays = done && !opts.mini ? `<g class="prays">${Array.from({ length: 10 }, (_, i) => { const a = i * Math.PI / 5;
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
  function celebrate(z, kind) {
    closeCelebrate(true);
    ui.celebrate = z.name;
    const el = document.createElement("div");
    el.className = `celebrate ${kind === "claim" ? "claim" : "cat"}`; el.id = "celebrate";
    let body;
    if (kind === "claim") {
      const claimed = { ...z, pct: 1, state: "complete", unchecked: false, cats: z.cats.map(finishCat) };
      body = `<div class="claimart">${progressArt(claimed, { animate: true, from: z.pct || 0 })}</div>
        <div class="kicker">Zone claimed</div><h1>${esc(z.name)}</h1>
        <p>Claimed for the ${ui.look}.</p>
        <div class="celcats">${claimed.cats.map(c => `<span>${catIcon(c.key, "cimg sm")}<b>${c.total}</b> ${c.total === 1 ? c.unit.replace(/s$/, "").replace("flight paths", "flight path") : c.unit}</span>`).join("")}</div>`;
    } else {
      const c = catOf(z, kind) || { key: kind, total: 1, label: CATS[kind].label };
      const k = ui.look === "Horde" ? "horde" : "alliance";
      const after = { ...z, cats: z.cats.map(x => x.key === kind ? finishCat(x) : x) };
      after.pct = after.cats.reduce((s, x) => s + x.done / x.total, 0) / after.cats.length;
      body = `<div class="celmedal">${hasPiece("streamer-" + k) ? `<img class="celstreamer" src="banner-art/streamer-${k}.png" alt="">` : ""}
          <div class="ring">${catIcon(kind, "cimg big")}</div></div>
        <div class="kicker">Streamer earned</div><h1>${esc(CEL[kind].title(z))}</h1>
        <p>${CEL[kind].line(c)} ${esc(z.name)} is now <b>${pctText(after.pct)}</b>.</p>`;
    }
    el.innerHTML = `<div class="rays"></div><div class="motes">${Array.from({ length: 18 }, (_, i) =>
      `<i style="left:${(i * 37) % 100}%;animation-delay:-${(i * 0.7) % 6}s;animation-duration:${5 + (i % 4)}s"></i>`).join("")}</div>
      <div class="card">${body}<button class="btn focusable cel-ok">Continue <span class="glyph A">A</span></button></div>`;
    $("#window").appendChild(el);
    setFocus($(".cel-ok"));
  }
  // The on-screen alert while the window is closed (shown on the page, outside the window).
  function gameAlert(z, kind) {
    const a = $("#gamealert");
    const title = kind === "claim" ? `${z.name} claimed` : CEL[kind].title(z);
    a.innerHTML = `${catIcon(kind === "claim" ? "explore" : kind, "cimg")}<span><small>Azerfolio</small>${esc(title)}</span>`;
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
  // Render + hints
  // =====================================================================================
  const HINTS = {
    overview: [["A", "A", "Select"], ["LT", "LT/RT", "Section"], ["LB", "LB/RB", "Tabs"], ["B", "B", "Close"]],
    zones: [["A", "A", "Open"], ["Y", "Y", "View"], ["X", "X", "Search"], ["LT", "LT/RT", "Section"], ["B", "B", "Close"]],
    zonesWide: [["A", "A", "Checklist"], ["Y", "Y", "View"], ["X", "X", "Search"], ["LT", "LT/RT", "Section"], ["B", "B", "Close"]],
    detail: [["A", "A", "Open"], ["X", "X", "World map"], ["B", "B", "Zones"]],
    detailPage: [["A", "A", "Select"], ["X", "X", "World map"], ["LT", "LT/RT", "Section"], ["B", "B", "Overview"]],
    flyout: [["DP", "✥", "Choose"], ["A", "A", "Apply"], ["B", "B", "Cancel"]],
  };
  function screen() { return ui.tab === "zones" ? (ui.detail && !ui.wide ? "detail" : ui.wide ? "zonesWide" : "zones") : "overview"; }
  function render() {
    renderHeader();
    $$(".tab").forEach(t => t.classList.toggle("active", t.dataset.tab === ui.tab));
    const sc = screen();
    if (sc === "overview") renderOverview();
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
    for (const a of ["open", "crit", "quest", "story", "flight", "page", "na", "next", "tab", "cycle", "status", "view", "go"]) if (d[a] !== undefined) parts.push(`[data-${a}="${CSS.escape(d[a])}"]`);
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
    ui.tab = tab; ui.flyout = null;
    render();
    if (tab === "zones" && !ui.detail) restoreCatalog(); else focusFirst();
  }
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
    // A category page goes back to the zone's overview, focused on that category's tile.
    if (ui.tab === "zones" && ui.detailPage && (ui.detail || ui.wide)) { const pg = ui.detailPage; ui.detailPage = null; render(); return setFocus($(`.ctile[data-page="${pg}"]`) || $(".ctile")); }
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
    if (d.na) return;
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
    hideTooltip();
    // Focus-driven updates: checklist info, and the wide split's detail pane.
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
      q: () => !ui.flyout && !ui.celebrate && setTab(ui.tab === "overview" ? "zones" : "overview"),
      e: () => !ui.flyout && !ui.celebrate && setTab(ui.tab === "overview" ? "zones" : "overview"),
      y: () => { if (ui.tab === "zones" && !ui.detail && !ui.flyout) { const v = VIEWS().map(x => x[0]); ui.view = v[(v.indexOf(ui.view) + 1) % v.length]; render(); restoreCatalog(); } },
      x: () => { if (ui.flyout || ui.celebrate) return; if (ui.tab === "zones" && (ui.detail || (ui.wide && focused && focused.closest("#detailpane")))) toast(`Would open the world map at ${esc(ui.detail || ui.selected)}`); else if (ui.tab === "zones") { setFocus($("[data-search]")); $("#searchInput").focus(); } },
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
    ui.detail = null; ui.selected = null; ui.lastZone = null;
    $("#celebrate")?.remove(); ui.celebrate = null; closeFlyout();
    buildModel();
  }
  $("#scenario").addEventListener("change", (e) => { loadScenario(e.target.value); render(); focusFirst(); e.target.blur(); });
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
  $("#claimPreview").addEventListener("change", (e) => { ui.claimPreview = e.target.checked; rerenderKeepFocus(); e.target.blur(); });
  $("#wideToggle").addEventListener("change", (e) => {
    ui.wide = e.target.checked; ui.detail = null;
    document.documentElement.style.setProperty("--win-w", winW() + "px");
    fit(); render(); if (ui.tab === "zones") restoreCatalog(); else focusFirst(); e.target.blur();
  });
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
  for (const t of ["overview", "zones"]) {
    const b = $(`.tab[data-tab="${t}"]`);
    if (b && hasIcon(t)) b.innerHTML = `<img src="icon-art/icon-${t}.png" alt="">`;
  }
  document.body.classList.toggle("chrome", hasChrome("frame-card"));
  if (hasChrome("frame-card")) {
    const r = document.documentElement.style, card = ART.chrome["frame-card"], bar = ART.chrome["frame-bar"] || { x: .08, y: .33 };
    r.setProperty("--card-slice", `${Math.round(card.y * 100)}% ${Math.round(card.x * 100)}%`);
    r.setProperty("--bar-slice", `${Math.round(bar.y * 100)}% ${Math.round(bar.x * 100)}%`);
  }

  loadScenario("today");
  render();
  fit();
  focusFirst();
})();
