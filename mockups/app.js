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
  // Schematic atlas: rough geographic grid positions [col, row]. Zones without a known
  // position are listed as "not placed" rather than guessed.
  const ATLAS = {
    "Eastern Kingdoms": {
      "Tirisfal Glades": [1, 0], "Western Plaguelands": [2, 0], "Eastern Plaguelands": [3, 0],
      "Silverpine Forest": [0, 1], "Alterac Mountains": [1, 1], "The Hinterlands": [3, 1],
      "Hillsbrad Foothills": [1, 2], "Arathi Highlands": [2, 2], "Wetlands": [2, 3],
      "Dun Morogh": [1, 4], "Loch Modan": [2, 4], "Searing Gorge": [1, 5], "Badlands": [2, 5],
      "Burning Steppes": [1, 6], "Elwynn Forest": [1, 7], "Redridge Mountains": [2, 7],
      "Westfall": [0, 8], "Duskwood": [1, 8], "Deadwind Pass": [2, 8], "Swamp of Sorrows": [3, 8],
      "Stranglethorn Vale": [1, 9], "Blasted Lands": [3, 9],
    },
    "Kalimdor": {
      "Teldrassil": [0, 0], "Moonglade": [2, 0], "Winterspring": [3, 0],
      "Darkshore": [1, 1], "Felwood": [2, 1], "Mount Hyjal": [3, 1],
      "Ashenvale": [2, 2], "Azshara": [3, 2], "Stonetalon Mountains": [1, 3], "The Barrens": [2, 3], "Durotar": [3, 3],
      "Desolace": [0, 4], "Mulgore": [1, 4], "Dustwallow Marsh": [3, 4],
      "Feralas": [0, 5], "Thousand Needles": [2, 5], "Silithus": [0, 6], "Un'Goro Crater": [1, 6], "Tanaris": [2, 6],
    },
  };

  const now = new Date();
  const ago = (days, h, m) => { const d = new Date(now); d.setDate(d.getDate() - days); d.setHours(h, m, 0, 0); return d; };
  const firstN = (zoneName, n) => window.AZF_ZONES.find(z => z.name === zoneName).criteria.slice(0, n).map(c => c.name);
  const all = (zoneName) => firstN(zoneName, 999);
  const GIDEON_ELWYNN = ["Jerod's Landing", "Northshire Valley", "Goldshire", "Fargodeep Mine", "Crystal Lake", "Forest's Edge", "Brackwell Pumpkin Patch"];

  const SCENARIOS = {
    today: () => ({
      char: { name: "Gideon", level: 9, race: "Human", className: "Paladin", faction: "Alliance", xp: 273, xpMax: 6500, zone: "Elwynn Forest", subzone: "Goldshire" },
      done: { "Elwynn Forest": GIDEON_ELWYNN.slice() },
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
      milestones: [
        { t: ago(12, 20, 10), kind: "zone", zone: "Elwynn Forest" }, { t: ago(9, 21, 40), kind: "zone", zone: "Westfall" },
        { t: ago(6, 19, 5), kind: "zone", zone: "Loch Modan" }, { t: ago(4, 22, 15), kind: "area", area: "Lakeridge Highway", zone: "Redridge Mountains" },
        { t: ago(3, 18, 30), kind: "area", area: "Three Corners", zone: "Redridge Mountains" }, { t: ago(1, 20, 0), kind: "area", area: "Raven Hill", zone: "Duskwood" },
        { t: ago(0, 21, 12), kind: "area", area: "Darkshire", zone: "Duskwood" }, { t: ago(0, 21, 30), kind: "area", area: "Manor Mistmantle", zone: "Duskwood" },
      ],
    }),
    fresh: () => ({
      char: { name: "Elowen", level: 1, race: "Human", className: "Paladin", faction: "Alliance", xp: 0, xpMax: 400, zone: "Elwynn Forest", subzone: "Northshire Abbey" },
      done: {}, milestones: [],
    }),
  };
  // Veteran activity: pad extra area discoveries so the activity strip has a realistic shape.
  const VETERAN_DAILY = [3, 0, 5, 2, 0, 0, 4, 6, 1, 0, 2, 3, 1, 2];

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
      return { ...z, tracked: true, minLevel: m[0], maxLevel: m[1], faction: m[2], criteria, done, total, pct: done / total,
        state: done === total ? "complete" : done > 0 ? "progress" : "untouched" };
    }).concat(UNTRACKED.map(u => ({ ...u, tracked: false, minLevel: null, maxLevel: null, criteria: [], done: 0, total: 0, pct: null, state: "untracked" })));
    byName = Object.fromEntries(zones.map(z => [z.name, z]));
    tracked = zones.filter(z => z.tracked);
    totals = {
      areas: tracked.reduce((s, z) => s + z.total, 0), done: tracked.reduce((s, z) => s + z.done, 0),
      complete: tracked.filter(z => z.state === "complete").length, progress: tracked.filter(z => z.state === "progress").length,
      untouched: tracked.filter(z => z.state === "untouched").length,
    };
  }
  const fitsLevel = (z) => z.minLevel != null && z.minLevel <= CHAR.level + 3 && z.maxLevel >= CHAR.level;
  const relevant = (z) => z.faction !== (CHAR.faction === "Alliance" ? "Horde" : "Alliance");

  // =====================================================================================
  // UI state
  // =====================================================================================
  const ui = { tab: "overview", detail: null, view: "cards", faction: "relevant", status: "all", level: "all", sort: "recommended",
    search: "", zonesScroll: 0, lastZone: null, selected: null, flyout: null, wide: false, newCrit: null, celebrate: null };
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
    const need = z.state === "complete" ? 99 : z.done - (real ? pieces.length - 1 : 0);
    for (let i = 0; i < need && z.state !== "complete"; i++) pieces.push({ x: r(i * 3 + 1, 40, 760), y: r(i * 3 + 2, 30, 460), w: 230, h: 200 });
    const blobs = Array.from({ length: 14 }, (_, i) => `<ellipse cx="${r(i * 5 + 1, 0, 1002)}" cy="${r(i * 5 + 2, 0, 668)}" rx="${r(i * 5 + 3, 60, 170)}" ry="${r(i * 5 + 4, 40, 110)}" fill="${i % 3 ? "#7c9b55" : "#5f7f43"}" opacity=".55"/>`).join("");
    const holes = pieces.map(p => `<rect x="${p.x + 12}" y="${p.y + 12}" width="${p.w - 24}" height="${p.h - 24}" rx="40" fill="#000"/>`).join("");
    const id = "m" + h;
    const fog = z.state === "complete" ? "" : `<rect width="1002" height="668" fill="#1c140c" opacity=".78" mask="url(#${id})"/>`;
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
    const inProgress = tracked.filter(z => z.state === "progress").sort((a, b) => (a.total - a.done) - (b.total - b.done));
    const hero = cur.state !== "complete" ? cur : inProgress[0] || nextForLevel(cur);
    const heroKicker = hero === cur ? (cur.done ? "Continue exploring · current zone" : "Start exploring · current zone")
      : cur.state === "complete" ? `${cur.name} complete · next up` : "Continue exploring";
    const goal = inProgress.find(z => z !== hero); // never repeat the Continue card
    const next = nextForLevel(hero);
    const p = totals.done / totals.areas;
    const W = (n) => (n / tracked.length * 100).toFixed(2);

    // Suggestions grouped by zone.
    const groups = [];
    if (hero && hero.state !== "complete") groups.push({ z: hero, why: hero === cur ? `Current zone · ${hero.total - hero.done} left` : `${hero.total - hero.done} left` });
    inProgress.filter(z => z !== hero).slice(0, 1).forEach(z => groups.push({ z, why: `Closest to complete · ${z.total - z.done} left` }));
    if (next && !groups.some(g => g.z === next)) groups.push({ z: next, why: `Next for your level · ${next.total - next.done} areas` });

    // Activity: last 14 days.
    const days = Array.from({ length: 14 }, (_, i) => { const d = new Date(now); d.setDate(d.getDate() - (13 - i)); d.setHours(0, 0, 0, 0); return d; });
    const counts = days.map((d, i) => S.milestones.filter(m => m.kind === "area" && new Date(m.t).setHours(0, 0, 0, 0) === d.getTime()).length
      + (ui.scenarioName === "veteran" ? VETERAN_DAILY[i] : 0));
    const max = Math.max(1, ...counts);
    const recent = S.milestones.slice().sort((a, b) => b.t - a.t).slice(0, 3);
    const CHIPS = 6;

    content.innerHTML = `<div class="scroll" id="scroll"><div class="overview">
      <div class="col">
        ${hero ? `<button class="hero focusable ${hero.state === "complete" ? "done" : ""}" data-open="${esc(hero.name)}" data-tip="<b>${esc(hero.name)}</b>Open the zone to see what's left.">
          <div class="art">${art(hero)}</div>
          <div class="body"><div class="kicker">${heroKicker}</div><div class="zname">${esc(hero.name)}</div>
            ${pips(hero, "lg")}
            <div class="left">${hero.done ? `<b>${hero.total - hero.done}</b> areas to go` : `${hero.total} areas to discover`}</div>
            <div class="go"><span class="glyph A">A</span>${hero.done ? "Continue" : "Start"}</div></div>
          <div class="score"><b>${pctText(hero.pct)}</b><span>${hero.done} of ${hero.total}</span></div></button>` : ""}
        ${goal ? `<button class="goal focusable" data-open="${esc(goal.name)}" data-tip="<b>Next goal</b>The in-progress zone with the fewest areas left.">
          <span class="flag">Next goal</span><span>Finish <b>${esc(goal.name)}</b> — ${goal.total - goal.done} to go</span>${pips(goal)}</button>` : ""}
        <h2 class="section" data-group>Suggested next</h2>
        ${groups.length ? groups.map(g => `<div class="zonegroup"><header><b>${esc(g.z.name)}</b><span class="why">${g.why}</span></header>
          <div class="chips">${g.z.criteria.filter(c => !c.done).slice(0, CHIPS).map(c => `<button class="areachip focusable" data-open="${esc(g.z.name)}" data-crit="${c.id}" data-tip="<b>${esc(c.name)}</b>Undiscovered area in ${esc(g.z.name)}.">${esc(c.name)}</button>`).join("")}
          ${g.z.total - g.z.done > CHIPS ? `<span class="note">+${g.z.total - g.z.done - CHIPS} more</span>` : ""}</div></div>`).join("")
          : `<div class="note">Nothing to suggest: every relevant zone is explored.</div>`}
      </div>
      <div class="col">
        <button class="counter focusable" data-go="zones" data-tip="<b>Areas discovered</b>Every exploration objective across ${tracked.length} tracked zones, from the game's Explore achievements.">
          <h4>Areas discovered <b>${totals.done} <small>/ ${totals.areas} · ${(p * 100).toFixed(1)}%</small></b></h4>${bar(p)}</button>
        <button class="counter focusable" data-go="zones" data-tip="<b>Zones</b>Complete: every area found. In progress: some found. Untouched: none yet. Capitals and Zephras Isle aren't tracked.">
          <h4>Zones <b>${totals.complete} <small>complete</small></b></h4>
          <div class="stack">${totals.complete ? `<i class="c" style="flex:${totals.complete}"></i>` : ""}${totals.progress ? `<i class="p" style="flex:${totals.progress}"></i>` : ""}${totals.untouched ? `<i class="u" style="flex:${totals.untouched}"></i>` : ""}</div>
          <div class="legend"><span><i class="c"></i>${totals.complete} complete</span><span><i class="p"></i>${totals.progress} in progress</span><span><i class="u"></i>${totals.untouched} untouched</span></div></button>
        <h2 class="section" data-group>Atlas</h2>
        ${miniAtlas()}
        <h2 class="section" data-group>Activity</h2>
        <div class="activity">
          <div class="sparklabels"><span>Areas discovered per day</span><span><b>${counts[13]}</b> today</span></div>
          <div class="spark">${counts.map(c => `<i class="${c ? "" : "zero"}" style="height:${c ? Math.max(8, c / max * 100) : 4}%"></i>`).join("")}</div>
          <div class="sparklabels"><span>2 weeks ago</span><span>Today</span></div>
          ${recent.length ? recent.map(m => m.kind === "zone"
            ? `<div class="milestone big"><span class="icon">★</span><span class="txt"><b>${esc(m.zone)}</b> fully explored</span><time>${fmtTime(m.t)}</time></div>`
            : `<div class="milestone"><span class="icon">✓</span><span class="txt">Discovered <b>${esc(m.area)}</b> <span class="note">· ${esc(m.zone)}</span></span><time>${fmtTime(m.t)}</time></div>`).join("")
            : `<div class="note" style="margin-top:8px">Your discoveries will appear here.</div>`}
        </div>
      </div>
    </div></div>`;
  }

  // Overview thumbnail: one focus stop that opens the full Atlas view.
  function miniAtlas() {
    const grid = (name) => {
      const cells = ATLAS[name];
      return `<div class="mg">${Object.entries(cells).map(([zn, [c, r]]) => {
        const z = byName[zn]; if (!z) return "";
        return `<i class="${z.state} ${zn === CHAR.zone ? "here" : ""}" style="grid-column:${c + 1};grid-row:${r + 1};--p:${z.state === "progress" ? Math.round(z.pct * 100) : 0}%"></i>`;
      }).join("")}</div>`;
    };
    return `<button class="minimap focusable" data-atlas data-tip="<b>Atlas</b>Every tracked zone, coloured by progress. Press A to open.">
      <div class="grids">${grid("Eastern Kingdoms")}${grid("Kalimdor")}</div>
      <div class="cap"><span>Eastern Kingdoms · Kalimdor</span><span><b>Open Atlas ›</b></span></div></button>`;
  }

  // Full Atlas (a Zones view). Tiles outside the current filters are dimmed, not hidden.
  function atlasView(visible) {
    const cont = (name) => {
      const cells = ATLAS[name];
      const rows = Math.max(...Object.values(cells).map(c => c[1])) + 1;
      return `<div class="continent"><h3>${name}</h3><div class="cgrid" style="grid-template-rows:repeat(${rows},34px)">
        ${Object.entries(cells).map(([zn, [c, r]]) => tile(byName[zn], `grid-column:${c + 1};grid-row:${r + 1}`)).join("")}</div></div>`;
    };
    const tile = (z, style) => !z ? "" : `<button class="tile focusable ${z.state} ${z.name === CHAR.zone ? "here" : ""} ${visible.has(z.name) ? "" : "dim"}" style="${style}" data-open="${esc(z.name)}"
        data-tip="<b>${esc(z.name)}</b>${z.done} of ${z.total} areas · ${pctText(z.pct)}${z.name === CHAR.zone ? " · You are here" : ""}">${z.state === "progress" ? `<i style="width:${Math.round(z.pct * 100)}%"></i>` : ""}<span>${esc(z.name)}</span></button>`;
    const placed = new Set(Object.values(ATLAS).flatMap(Object.keys));
    const unplaced = tracked.filter(z => !placed.has(z.name));
    return `<div class="atlasview">${cont("Eastern Kingdoms")}${cont("Kalimdor")}</div>
      ${unplaced.length ? `<div class="unplaced">Position not mapped yet:${unplaced.map(z => tile(z, "")).join("")}</div>` : ""}
      <div class="atlasfoot"><div class="legend"><span><i class="c"></i>Complete</span><span><i class="p"></i>In progress</span><span><i class="u"></i>Untouched</span><span>● You are here</span></div></div>`;
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
      closest: unknownLast((a, b) => (a.state === "complete") - (b.state === "complete") || (a.total - a.done) - (b.total - b.done)),
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
      <div class="art">${art(z)}${window.AZF_ART && (window.AZF_ART.ids.includes(z.mapID) || window.AZF_ART.fallback) ? "" : `<span class="artlabel">ART PLACEHOLDER</span>`}${z.state === "complete" ? `<span class="badge emblem">✓</span>` : ""}</div>
      ${rec ? `<span class="ribbon">Recommended next</span>` : ""}
      <div class="body">
        <div class="top"><span class="name">${esc(z.name)}</span><span class="pct">${z.tracked ? (z.state === "complete" ? "✓ " : "") + pctText(z.pct) : "—"}</span></div>
        ${z.tracked ? pips(z) : `<div class="bar unknown small"></div>`}
        <div class="meta"><span>Lv ${shortLv(z)}</span>${facBadge(z)}${fitsLevel(z) && z.state !== "complete" ? `<span class="fittag">Your level</span>` : ""}
          <span class="n">${z.tracked ? `${z.done}/${z.total}` : "not tracked"}</span></div></div></button>`;
  }
  function row(z, compact) {
    if (compact) return `<button class="zrow focusable ${z.state} ${ui.selected === z.name ? "selected" : ""}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
      <span class="thumb">${art(z)}</span><span class="areas"><span class="zname">${esc(z.name)}</span>${z.tracked ? pips(z, "sm") : `<span class="note">not tracked</span>`}</span>
      <span class="lv">Lv ${shortLv(z)}${levelbar(z)}</span><span class="pctcol">${pctText(z.pct)}</span></button>`;
    return `<button class="zrow focusable ${z.state}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
      <span class="thumb">${art(z)}</span><span class="zname">${esc(z.name)} ${facBadge(z)}</span>
      <span class="lv">Lv ${shortLv(z)}${levelbar(z)}</span>
      <span class="areas">${z.tracked ? `${pips(z, "sm")}<span class="note">${z.done} / ${z.total} areas</span>` : `<span class="note">Exploration not tracked</span>`}</span>
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
    const remaining = z.criteria.filter(c => !c.done), found = z.criteria.filter(c => c.done);
    const check = (c) => `<button class="check focusable ${c.done ? "done" : "todo"} ${ui.newCrit === c.id ? "new" : ""}" data-crit="${c.id}"><span class="mark">${c.done ? "✓" : ""}</span><span>${esc(c.name)}</span></button>`;
    const next = z.tracked ? tracked.filter(x => x !== z && relevant(x) && x.state !== "complete" && x.minLevel != null && z.minLevel != null && x.minLevel > z.minLevel)
      .sort((a, b) => a.minLevel - b.minLevel || (b.continent === z.continent) - (a.continent === z.continent) || a.name.localeCompare(b.name))[0] : null;
    container.innerHTML = `<div class="detail">
      <div class="detail-hero ${opts.back ? "has-back" : ""}">${art(z)}<div class="shade"></div>
        ${opts.back ? `<button class="btn dark back focusable" data-back data-tip="Back to all zones (B)">‹ Zones</button>` : ""}
        <div class="info">
          <div><h1>${esc(z.name)}</h1><div class="sub"><span>${levels(z)}</span>${facBadge(z)}<span>${esc(z.continent)}</span>
            ${next ? `<span class="next">· Next: ${esc(next.name)} (${shortLv(next)})</span>` : ""}</div></div>
          <div class="scorebox">${z.tracked ? `<div class="bigpct">${pctText(z.pct)}<small>${z.done} of ${z.total}</small></div>${pips(z, "lg", true)}` : `<div class="bigpct">—<small>not tracked</small></div>`}</div>
        </div></div>
      <div class="detail-body">
        <div class="scroll" id="${opts.back ? "scroll" : "detailscroll"}">
          ${z.tracked ? `
            <h2 class="section" data-group>To discover <small>${remaining.length}</small></h2>
            ${remaining.length ? `<div class="checklist">${remaining.map(check).join("")}</div>` : `<div class="note">Every area discovered. ✦</div>`}
            <h2 class="section" data-group>Discovered <small>${found.length}</small></h2>
            ${found.length ? `<div class="checklist">${found.map(check).join("")}</div>` : `<div class="note">Nothing yet — head out and explore.</div>`}`
          : `<div class="empty"><b>Exploration isn't tracked here</b>The game has no Explore achievement for ${esc(z.name)}, so Azerfolio can't verify progress.</div>`}
        </div>
        <aside class="mapside">
          <div class="zonemap">${zoneMap(z)}</div>
          <div class="mapcap"><span class="legend"><span><i style="background:#c9b27a"></i>Revealed</span><span><i style="background:#3a2e22"></i>Unexplored</span></span>
            <button class="btn focusable" data-map data-tip="<b>World map</b>Open the world map at ${esc(z.name)}.">World map</button></div>
          <div class="focusinfo" id="focusinfo"></div>
        </aside>
      </div></div>`;
    showFocusInfo(z, remaining[0] || found[0]);
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
    detail: [["A", "A", "Select"], ["X", "X", "World map"], ["LT", "LT/RT", "Section"], ["B", "B", "Back"]],
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
    setHints(ui.flyout ? "flyout" : sc);
    hideTooltip();
  }
  function setHints(key) { $("#hints").innerHTML = HINTS[key].map(([cls, g, t]) => `<span><span class="glyph ${cls}">${g}</span>${t}</span>`).join(""); }

  // Focus restore: remember what was focused by its data attributes, find it again after a re-render.
  function keyOf(el) {
    if (!el) return null;
    const d = el.dataset, parts = [];
    for (const a of ["open", "crit", "tab", "cycle", "status", "view", "go"]) if (d[a] !== undefined) parts.push(`[data-${a}="${CSS.escape(d[a])}"]`);
    for (const a of ["search", "back", "map", "atlas"]) if (d[a] !== undefined) parts.push(`[data-${a}]`);
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
    if (ui.wide) { ui.selected = name; ui.detail = null; ui.view = "list"; render(); const sel = $(`.zrow[data-open="${CSS.escape(name)}"]`); if (sel) sel.scrollIntoView({ block: "center" });
      const t = crit && $(`#detailpane .check[data-crit="${crit}"]`); setFocus(t || $("#detailpane .check") || sel); return; }
    ui.detail = name; render();
    const target = crit && $(`.check[data-crit="${crit}"]`);
    setFocus(target || $(".check") || $("[data-back]"));
  }
  function back() {
    if (ui.celebrate) return closeCelebrate();
    if (ui.flyout) return closeFlyout();
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
    if (d.open && !(ui.wide && el.classList.contains("zrow"))) return openZone(d.open, d.crit);
    if (d.open && ui.wide) { // wide: A on a row moves into its checklist
      return setFocus($("#detailpane .check.todo") || $("#detailpane .check") || $("#detailpane [data-map]"));
    }
    if (d.atlas !== undefined) { ui.view = "atlas"; ui.detail = null; ui.lastZone = CHAR.zone; return setTab("zones"); }
    if (d.go) return setTab(d.go);
    if (d.status) { ui.status = d.status; render(); return setFocus($(`[data-status="${d.status}"]`)); }
    if (d.view) { ui.view = d.view; render(); return restoreCatalog(); }
    if (d.cycle) return openFlyout(d.cycle, el);
    if (d.search !== undefined) return $("#searchInput").focus();
    if (d.map !== undefined) return toast(`Would open the world map at ${esc(ui.detail || ui.selected)}`);
    if (d.crit) return setFocus($("[data-map]"));
  }

  // Live discovery simulation: shows how every view updates, plus the completion moment.
  function simulateDiscovery() {
    const z = byName[CHAR.zone];
    const nextC = z.criteria.find(c => !c.done);
    if (!nextC) return toast(`${esc(z.name)} is already fully explored.<small>Switch Data to try again.</small>`);
    (S.done[z.name] = S.done[z.name] || []).push(nextC.name);
    S.milestones.push({ t: new Date(), kind: "area", area: nextC.name, zone: z.name });
    ui.newCrit = nextC.id;
    buildModel();
    const nz = byName[z.name];
    toast(`Discovered: ${esc(nextC.name)}<small>${nz.done} of ${nz.total} in ${esc(z.name)} · milestone recorded</small>`);
    rerenderKeepFocus();
    if (nz.state === "complete") {
      S.milestones.push({ t: new Date(), kind: "zone", zone: z.name });
      setTimeout(() => showCelebrate(nz), 900);
    }
    setTimeout(() => { ui.newCrit = null; }, 1500);
  }
  function showCelebrate(z) {
    ui.celebrate = z.name;
    const el = document.createElement("div");
    el.className = "celebrate"; el.id = "celebrate";
    el.innerHTML = `<div class="rays"></div><div class="card"><div class="emblem">✓</div><h1>${esc(z.name)} Explored</h1>
      <p>All ${z.total} areas discovered. Added to your milestones.</p><button class="btn focusable cel-ok">Continue <span class="glyph A">A</span></button></div>`;
    $("#window").appendChild(el);
    setFocus($(".cel-ok"));
  }
  function closeCelebrate() { $("#celebrate")?.remove(); ui.celebrate = null; rerenderKeepFocus(); }

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
    if (el.classList.contains("check")) {
      const z = byName[ui.detail || ui.selected];
      if (z) showFocusInfo(z, z.criteria.find(c => String(c.id) === el.dataset.crit));
    }
    if (ui.wide && ui.tab === "zones" && el.classList.contains("zrow") && el.dataset.open !== ui.selected) {
      ui.selected = el.dataset.open;
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
      x: () => { if (ui.flyout || ui.celebrate) return; if (ui.tab === "zones" && (ui.detail || (ui.wide && focused && focused.closest("#detailpane")))) activate($("[data-map]")); else if (ui.tab === "zones") { setFocus($("[data-search]")); $("#searchInput").focus(); } },
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

  loadScenario("today");
  render();
  fit();
  focusFirst();
})();
