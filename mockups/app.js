/* Azerfolio mockup behavior. Design reference only. */
(function () {
  "use strict";

  // ---------- Sample state (Gideon, 2026-11-07, from the in-game diagnostics) ----------
  const CHAR = { name: "Gideon", realm: "Everhope", level: 9, race: "Human", className: "Paladin",
    faction: "Alliance", xp: 273, xpMax: 6500, zone: "Elwynn Forest", subzone: "Goldshire" };
  const DONE = { "Elwynn Forest": ["Jerod's Landing", "Northshire Valley", "Goldshire", "Fargodeep Mine",
    "Crystal Lake", "Forest's Edge", "Brackwell Pumpkin Patch"] };
  const MILESTONES = [
    { icon: "✓", text: "Discovered <b>Brackwell Pumpkin Patch</b>", zone: "Elwynn Forest", time: "Today, 11:30" },
    { icon: "✓", text: "Discovered <b>Forest's Edge</b>", zone: "Elwynn Forest", time: "Today, 11:26" },
  ];

  // Zone metadata: classic level ranges and faction territory. SAMPLE DATA for the mockup only;
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

  // ---------- Model (in the addon this is the Progression service) ----------
  const zones = window.AZF_ZONES.map(z => {
    const m = META[z.name] || [null, null, "Unknown"];
    const doneSet = new Set(DONE[z.name] || []);
    const criteria = z.criteria.map(c => ({ ...c, done: doneSet.has(c.name) }));
    const done = criteria.filter(c => c.done).length;
    return { ...z, tracked: true, minLevel: m[0], maxLevel: m[1], faction: m[2], criteria,
      done, total: criteria.length, pct: done / criteria.length };
  }).concat(UNTRACKED.map(u => ({ ...u, tracked: false, minLevel: null, maxLevel: null, criteria: [], done: 0, total: 0, pct: null })));
  const byName = Object.fromEntries(zones.map(z => [z.name, z]));
  const tracked = zones.filter(z => z.tracked);
  const totalAreas = tracked.reduce((s, z) => s + z.total, 0);
  const doneAreas = tracked.reduce((s, z) => s + z.done, 0);
  const completedZones = tracked.filter(z => z.done === z.total).length;

  // ---------- UI state ----------
  const state = { tab: "overview", detail: null, view: "cards", faction: "relevant", status: "all", level: "all",
    sort: "recommended", search: "", zonesScroll: 0, lastZone: null };
  const OPTIONS = {
    faction: [["relevant", "Relevant to me"], ["all", "All zones"]],
    status: [["all", "All"], ["incomplete", "Incomplete"], ["completed", "Completed"]],
    level: [["all", "All levels"], ["appropriate", "For my level"]],
    sort: [["recommended", "Recommended"], ["alphabetical", "A–Z"], ["highest", "Highest %"], ["lowest", "Lowest %"], ["closest", "Closest to done"]],
  };
  const label = (key) => OPTIONS[key].find(o => o[0] === state[key])[1];

  const $ = (s, r = document) => r.querySelector(s);
  const content = $("#content");
  const pctText = (p) => p == null ? "—" : `${Math.round(p * 100)}%`;
  const esc = (s) => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const levels = (z) => z.minLevel == null ? "Level range unknown" : `Levels ${z.minLevel}–${z.maxLevel}`;
  const bar = (p, cls = "") => p == null ? `<div class="bar unknown ${cls}"></div>`
    : `<div class="bar ${p >= 1 ? "complete" : ""} ${cls}"><i style="width:${(p * 100).toFixed(1)}%"></i></div>`;

  // ---------- Placeholder zone art (painted-landscape stand-in) ----------
  function hash(s) { let h = 0; for (const ch of s) h = (h * 31 + ch.charCodeAt(0)) >>> 0; return h; }
  function art(z) {
    const h = hash(z.name);
    const n = z.name;
    const kind = /Tanaris|Silithus|Barrens|Desolace|Badlands|Durotar|Thousand|Searing|Burning|Blasted|Un'Goro/.test(n) ? "dry"
      : /Winterspring|Dun Morogh|Alterac|Ironforge/.test(n) ? "snow"
      : /Plague|Deadwind|Swamp|Dustwallow|Felwood|Undercity|Duskwood/.test(n) ? "gloom" : "green";
    const pal = {
      green: ["#9fd0ef", "#f5e3b5", "#5d8a4a", "#3d6b35", "#24451f"],
      dry: ["#f2c58a", "#fbe7c2", "#c98a4b", "#a0632f", "#6e3f1b"],
      snow: ["#a9c6e8", "#eef3fb", "#c9d6e6", "#8fa4bd", "#56677e"],
      gloom: ["#6b7a8f", "#b8b3a0", "#4f5a4a", "#363f35", "#1e241d"],
    }[kind];
    const r = (i, a, b) => a + ((h >> (i * 3)) % 1000) / 1000 * (b - a);
    const ridge = (y, amp, seed) => {
      let d = `M0 ${y}`;
      for (let x = 0; x <= 320; x += 20) d += ` L${x} ${(y - Math.abs(Math.sin((x + seed * 37) / (30 + seed * 7))) * amp - r(seed + x / 20, 0, amp / 3)).toFixed(1)}`;
      return d + " L320 180 L0 180 Z";
    };
    const trees = kind === "green" || kind === "gloom"
      ? Array.from({ length: 9 }, (_, i) => { const x = 10 + i * 36 + r(i, -8, 8); const s = r(i + 2, 14, 26);
          return `<path d="M${x} ${180 - 6} l${s / 2} -${s * 1.6} l${s / 2} ${s * 1.6} Z" fill="${pal[4]}"/>`; }).join("") : "";
    const id = "g" + h;
    return `<svg viewBox="0 0 320 180" preserveAspectRatio="xMidYMid slice"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal[0]}"/><stop offset="1" stop-color="${pal[1]}"/></linearGradient></defs>
      <rect width="320" height="180" fill="url(#${id})"/><circle cx="${r(1, 40, 280)}" cy="${r(2, 30, 60)}" r="16" fill="#fff6d8" opacity=".75"/>
      <path d="${ridge(110, 45, 1)}" fill="${pal[2]}" opacity=".7"/><path d="${ridge(135, 35, 2)}" fill="${pal[3]}"/><path d="${ridge(160, 22, 3)}" fill="${pal[4]}"/>${trees}
      <rect width="320" height="180" fill="url(#${id})" opacity=".08"/></svg>`;
  }

  // ---------- Header ----------
  function renderHeader() {
    $("#charName").textContent = CHAR.name;
    $("#charLine").innerHTML = `Level ${CHAR.level} ${CHAR.race} <span class="class-paladin">${CHAR.className}</span> · <span class="fac ${CHAR.faction}">${CHAR.faction}</span>`;
    $("#xpFill").style.width = `${(CHAR.xp / CHAR.xpMax * 100).toFixed(1)}%`;
    $("#xpText").textContent = `XP ${CHAR.xp} / ${CHAR.xpMax}`;
    $("#charZone").innerHTML = `Current zone<b>${CHAR.zone}</b>${CHAR.subzone}`;
  }

  // ---------- Overview ----------
  function renderOverview() {
    const p = doneAreas / totalAreas;
    const C = 2 * Math.PI * 80;
    const cur = byName[CHAR.zone];
    const closest = tracked.filter(z => z.done < z.total && z.done > 0).sort((a, b) => b.pct - a.pct)[0];
    const remaining = cur.criteria.filter(c => !c.done);
    const westfall = byName["Westfall"];
    const suggestions = remaining.slice(0, 4).map(c => ({ name: c.name, zone: cur.name, cat: "Exploration",
      why: `In your current zone — ${remaining.length} left in ${cur.name}`, open: cur.name, crit: c.id }))
      .concat([{ name: "Westfall", zone: "Westfall", cat: "Zone", why: `Next zone for your level — ${westfall.total} areas to discover`, open: "Westfall" }]);
    content.innerHTML = `<div class="scroll" id="scroll"><div class="overview">
      <div>
        <div class="ring-card">
          <h3>Tracked Completion</h3>
          <div class="ring"><svg viewBox="0 0 200 200"><circle cx="100" cy="100" r="80" fill="none" stroke="#3a2b1c" stroke-width="18"/>
            <circle cx="100" cy="100" r="80" fill="none" stroke="#d4a017" stroke-width="18" stroke-linecap="round" stroke-dasharray="${(C * p).toFixed(1)} ${C.toFixed(1)}"/></svg>
            <div class="pct"><b>${(p * 100).toFixed(1)}%</b><span>${doneAreas} of ${totalAreas} objectives</span></div></div>
          <div class="includes">Includes <span class="chip">Exploration</span></div>
          <div class="note" style="margin-top:6px">Counts only what Azerfolio can verify. Quests join in v1.1.</div>
        </div>
        <h2 class="section">Zone highlights</h2>
        <div class="list">
          ${hl("Current zone", cur)}
          ${closest ? hl("Closest to completion", closest) : ""}
          <div class="item" style="cursor:default"><span>Recently completed</span><span class="meta">None yet</span></div>
        </div>
      </div>
      <div>
        <div class="cards">
          <button class="stat focusable" data-go="zones" data-tip="<b>Zones completed</b>Zones where every exploration objective is discovered.<span class='dim'> Tracked zones only (${tracked.length}); capitals have no exploration data.</span>">
            <h4>Zones</h4><div class="big">${completedZones} <small>of ${tracked.length}</small></div><div class="sub">fully explored</div>${bar(completedZones / tracked.length)}</button>
          <button class="stat focusable" data-go="zones" data-tip="<b>Exploration</b>Areas discovered across all ${tracked.length} tracked zones. Source: the game's Explore achievements.">
            <h4>Exploration</h4><div class="big">${doneAreas} <small>of ${totalAreas}</small></div><div class="sub">areas discovered · ${(p * 100).toFixed(1)}%</div>${bar(p)}</button>
          <button class="stat focusable" data-open="${cur.name}" data-tip="<b>${cur.name}</b>${cur.done} of ${cur.total} areas discovered. Press A to open.">
            <h4>Current zone</h4><div class="big">${pctText(cur.pct)}</div><div class="sub">${cur.name} · ${cur.total - cur.done} left</div>${bar(cur.pct)}</button>
        </div>
        <h2 class="section">Suggested next</h2>
        <div class="list">${suggestions.map(s => `<button class="item focusable" data-open="${esc(s.open)}" ${s.crit ? `data-crit="${s.crit}"` : ""}
            data-tip="<b>${esc(s.name)}</b>${esc(s.why)}"><span>${esc(s.name)} <span class="tag">${s.cat}</span></span><span class="meta">${esc(s.zone)}</span><span class="why">${esc(s.why)}</span></button>`).join("")}</div>
        <h2 class="section">Recent milestones</h2>
        <div>${MILESTONES.map(m => `<div class="milestone"><span class="icon">${m.icon}</span><span>${m.text} <span class="note">— ${m.zone}</span></span><time>${m.time}</time></div>`).join("")}
          <div class="note" style="margin-top:6px">Progress made before Azerfolio was installed counts toward your totals but isn't listed here.</div></div>
      </div>
    </div></div>`;
    function hl(title, z) {
      return `<button class="item focusable" data-open="${esc(z.name)}" data-tip="<b>${esc(z.name)}</b>${z.done} of ${z.total} areas · ${pctText(z.pct)}">
        <span><span class="meta">${title}</span><br>${esc(z.name)}</span><span class="meta">${z.done}/${z.total}</span>${bar(z.pct, "small").replace('class="bar', 'style="grid-column:1/-1" class="bar')}</button>`;
    }
  }

  // ---------- Zones catalogue ----------
  function filteredZones() {
    const q = state.search.trim().toLowerCase();
    let list = zones.filter(z => {
      if (state.faction === "relevant" && (z.faction === "Horde")) return false;
      if (state.status === "completed" && !(z.tracked && z.done === z.total)) return false;
      if (state.status === "incomplete" && !(z.tracked && z.done < z.total)) return false;
      if (state.level === "appropriate" && !(z.minLevel != null && z.minLevel <= CHAR.level + 3 && z.maxLevel >= CHAR.level)) return false;
      if (q && !z.name.toLowerCase().includes(q)) return false;
      return true;
    });
    const name = (a, b) => a.name.localeCompare(b.name);
    const unknownLast = (f) => (a, b) => (a.pct == null) - (b.pct == null) || f(a, b) || name(a, b);
    const sorts = {
      recommended: (a, b) => (a.minLevel ?? 999) - (b.minLevel ?? 999) || (a.tracked ? 0 : 1) - (b.tracked ? 0 : 1) || name(a, b),
      alphabetical: name,
      highest: unknownLast((a, b) => b.pct - a.pct),
      lowest: unknownLast((a, b) => a.pct - b.pct),
      closest: unknownLast((a, b) => (a.total - a.done) - (b.total - b.done) || b.pct - a.pct),
    };
    return list.sort(sorts[state.sort]);
  }

  function zoneTip(z) {
    if (!z.tracked) return `<b>${esc(z.name)}</b>Exploration isn't tracked here: the game has no Explore achievement for this zone.`;
    return `<b>${esc(z.name)}</b>${z.done} of ${z.total} areas discovered (${pctText(z.pct)}).<span class='dim'> ${levels(z)} · ${z.faction}</span>`;
  }

  function renderZones() {
    const list = filteredZones();
    const card = (z) => `<button class="zcard focusable ${z.tracked && z.done === z.total ? "complete" : ""} ${z.tracked ? "" : "untracked"}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
        <div class="art">${art(z)}<span class="artlabel">ART PLACEHOLDER</span>${z.tracked && z.done === z.total ? `<span class="badge emblem">✓</span>` : ""}</div>
        <div class="body"><div class="name">${esc(z.name)}</div>
          <div class="meta"><span>${z.minLevel == null ? "Levels —" : `${z.minLevel}–${z.maxLevel}`}</span><span class="fac ${z.faction}">${z.faction}</span></div>
          ${bar(z.pct)}
          <div class="stats">${z.tracked ? `<span>Exploration ${z.done}/${z.total}</span><b>${pctText(z.pct)}</b>` : `<span>Exploration not tracked</span><span>—</span>`}</div></div></button>`;
    const row = (z) => `<button class="zrow focusable ${z.tracked ? "" : "untracked"}" data-open="${esc(z.name)}" data-tip="${zoneTip(z)}">
        <span class="thumb">${art(z)}</span><span class="zname">${esc(z.name)}</span><span>${z.minLevel == null ? "—" : `${z.minLevel}–${z.maxLevel}`}</span>
        <span><span class="fac ${z.faction}">${z.faction}</span></span>${bar(z.pct, "small")}
        <span class="num">${z.tracked ? `${z.done} / ${z.total}` : "not tracked"}</span><span class="pctcol">${pctText(z.pct)}</span></button>`;
    const sel = (key, tip) => `<button class="select focusable" data-cycle="${key}" data-tip="<b>${tip}</b>Press A to change.">${tip}: <b>${label(key)}</b></button>`;
    content.innerHTML = `
      <div class="toolbar">
        <label class="search focusable" data-search data-tip="<b>Search zones</b>Press A to type (on-screen keyboard on controller).">🔍<input id="searchInput" placeholder="Search zones" value="${esc(state.search)}" tabindex="-1"></label>
        ${sel("faction", "Show")}${sel("status", "Status")}${sel("level", "Level")}${sel("sort", "Sort")}
        <span class="count">${list.length} zones</span>
        <div class="viewtoggle"><button class="focusable ${state.view === "cards" ? "on" : ""}" data-view="cards" data-tip="Illustrated cards (Y)">▦ Cards</button><button class="focusable ${state.view === "list" ? "on" : ""}" data-view="list" data-tip="Compact list (Y)">☰ List</button></div>
      </div>
      <div class="scroll zones-scroll" id="scroll">
        ${list.length === 0 ? `<div class="empty"><b>No zones match</b>Try clearing the search or changing the filters.</div>`
          : state.view === "cards" ? `<div class="grid">${list.map(card).join("")}</div>`
          : `<div class="listhead"><span></span><span>Zone</span><span>Levels</span><span>Faction</span><span>Exploration</span><span>Areas</span><span>%</span></div><div class="rows">${list.map(row).join("")}</div>`}
      </div>`;
    const input = $("#searchInput");
    input.addEventListener("input", () => { state.search = input.value; const pos = input.selectionStart; render(); const i = $("#searchInput"); i.focus(); i.setSelectionRange(pos, pos); });
    input.addEventListener("keydown", (e) => { if (e.key === "Escape" || e.key === "Enter") { e.stopPropagation(); input.blur(); setFocus($("[data-search]")); } });
  }

  // ---------- Zone detail ----------
  function renderDetail(focusCrit) {
    const z = byName[state.detail];
    const remaining = z.criteria.filter(c => !c.done);
    const found = z.criteria.filter(c => c.done);
    // No tooltip: the side panel already shows the focused objective's details.
    const check = (c) => `<button class="check focusable ${c.done ? "done" : ""}" data-crit="${c.id}"><span class="mark">${c.done ? "✓" : ""}</span><span>${esc(c.name)}</span></button>`;
    content.innerHTML = `
      <div class="detail-hero">${art(z)}<div class="shade"></div>
        <button class="btn dark back focusable" data-back data-tip="Back to all zones (B)">‹ Zones</button>
        <div class="info"><div><h1>${esc(z.name)}</h1><div class="sub"><span>${levels(z)}</span><span class="fac ${z.faction}">${z.faction}</span><span>${z.continent}</span></div></div>
          <div><div class="bigpct">${z.tracked ? pctText(z.pct) : "—"}<small>${z.tracked ? `${z.done} of ${z.total} areas discovered` : "Exploration not tracked"}</small></div>${bar(z.pct)}</div></div>
      </div>
      <div class="detail-body">
        <div class="scroll" id="scroll">
          ${z.tracked ? `
          <h2 class="section">Exploration · remaining ${remaining.length}</h2>
          ${remaining.length ? `<div class="checklist">${remaining.map(check).join("")}</div>` : `<div class="note">Every area discovered. ✦</div>`}
          <h2 class="section">Discovered ${found.length}</h2>
          <div class="checklist">${found.map(check).join("")}</div>`
          : `<div class="empty"><b>Exploration isn't tracked here</b>The game has no Explore achievement for ${esc(z.name)}, so Azerfolio can't verify progress. Other categories will appear here in later versions.</div>`}
        </div>
        <aside class="side" id="side"></aside>
      </div>`;
    updateSide(z, focusCrit ? z.criteria.find(c => String(c.id) === String(focusCrit)) : remaining[0] || found[0]);
  }

  function updateSide(z, c) {
    const side = $("#side");
    if (!side) return;
    if (!c) { side.innerHTML = `<h3>${esc(z.name)}</h3><div class="facts">Nothing to show.</div>`; return; }
    side.innerHTML = `<h3>${esc(c.name)}</h3>
      <div class="state ${c.done ? "done" : ""}">${c.done ? "✓ Discovered" : "○ Not yet discovered"}</div>
      <div class="facts">Exploration objective in ${esc(z.name)}.<br>Source: the game's “Explore ${esc(z.name)}” achievement (criterion ${c.id}).</div>
      <button class="btn focusable" data-map data-tip="Open the world map at ${esc(z.name)} (X)">Show on world map</button>
      <div class="note">Exact location markers need map data we don't have yet.</div>`;
  }

  // ---------- Render + hints ----------
  const HINTS = {
    overview: [["DP", "✥", "Move"], ["A", "A", "Select"], ["LB", "LB/RB", "Tabs"], ["B", "B", "Close"]],
    zones: [["A", "A", "Open zone"], ["Y", "Y", "Cards / list"], ["X", "X", "Search"], ["LT", "LT/RT", "Page"], ["LB", "LB/RB", "Tabs"], ["B", "B", "Close"]],
    detail: [["A", "A", "Details"], ["X", "X", "World map"], ["LT", "LT/RT", "Page"], ["B", "B", "Back"]],
  };
  function render(opts = {}) {
    document.querySelectorAll(".tab").forEach(t => t.classList.toggle("active", t.dataset.tab === state.tab));
    const screen = state.tab === "zones" && state.detail ? "detail" : state.tab;
    if (screen === "overview") renderOverview();
    else if (screen === "zones") renderZones();
    else renderDetail(opts.focusCrit);
    $("#hints").innerHTML = HINTS[screen].map(([cls, g, t]) => `<span><span class="glyph ${cls}">${g}</span>${t}</span>`).join("");
    hideTooltip();
  }

  // ---------- Navigation actions ----------
  function setTab(tab) {
    if (state.tab === "zones" && !state.detail) state.zonesScroll = $("#scroll")?.scrollTop || 0;
    state.tab = tab;
    render();
    if (tab === "zones" && !state.detail) restoreCatalog();
    else focusFirst();
  }
  function openZone(name, crit) {
    if (state.tab === "zones" && !state.detail) state.zonesScroll = $("#scroll")?.scrollTop || 0;
    state.tab = "zones"; state.detail = name; state.lastZone = name;
    render({ focusCrit: crit });
    const target = crit && $(`.check[data-crit="${crit}"]`);
    setFocus(target || $(".check") || $("[data-back]"));
  }
  function back() {
    if (state.tab === "zones" && state.detail) {
      state.detail = null;
      render();
      restoreCatalog();
    } else {
      closeWindow();
    }
  }
  function restoreCatalog() {
    const sc = $("#scroll");
    if (sc) { sc.style.scrollBehavior = "auto"; sc.scrollTop = state.zonesScroll; sc.style.scrollBehavior = ""; }
    const last = state.lastZone && document.querySelector(`#scroll [data-open="${CSS.escape(state.lastZone)}"]`);
    setFocus(last || $("#scroll .focusable") || $(".toolbar .focusable"), { noScroll: !!last && false });
  }
  function closeWindow() {
    $("#window").hidden = true; $("#reopen").hidden = false; hideTooltip();
  }
  function toast(text) {
    const t = $("#toast"); t.textContent = text; t.hidden = false;
    clearTimeout(toast.timer); toast.timer = setTimeout(() => (t.hidden = true), 1800);
  }

  function activate(el) {
    if (!el) return;
    if (el.dataset.tab) return setTab(el.dataset.tab);
    if (el.id === "closeBtn") return closeWindow();
    if (el.dataset.back !== undefined) return back();
    if (el.dataset.open) return openZone(el.dataset.open, el.dataset.crit);
    if (el.dataset.go) return setTab(el.dataset.go);
    if (el.dataset.view) { state.view = el.dataset.view; render(); return setFocus($(`[data-view="${state.view}"]`)); }
    if (el.dataset.cycle) {
      const key = el.dataset.cycle, opts = OPTIONS[key];
      const i = opts.findIndex(o => o[0] === state[key]);
      state[key] = opts[(i + 1) % opts.length][0];
      render(); return setFocus($(`[data-cycle="${key}"]`));
    }
    if (el.dataset.search !== undefined) { $("#searchInput").focus(); return; }
    if (el.dataset.map !== undefined) return toast("Would open the world map at " + state.detail);
    if (el.dataset.crit) {
      const z = byName[state.detail];
      updateSide(z, z.criteria.find(c => String(c.id) === el.dataset.crit));
      return setFocus($("[data-map]"));
    }
  }

  // ---------- Focus engine (spatial stand-in for the addon's explicit focus grid) ----------
  let focused = null;
  function visibleFocusables() {
    return [...document.querySelectorAll("#window .focusable")].filter(el => el.offsetParent !== null);
  }
  function setFocus(el, o = {}) {
    if (focused) focused.classList.remove("focused");
    focused = el || null;
    if (!el) return hideTooltip();
    el.classList.add("focused");
    if (!o.noScroll) el.scrollIntoView({ block: "nearest", inline: "nearest" });
    showTooltip(el);
    if (el.classList.contains("check") && state.detail) {
      const z = byName[state.detail];
      updateSide(z, z.criteria.find(c => String(c.id) === el.dataset.crit));
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
      // Distance along the move direction, edge to edge (0 if touching).
      const main = horizontal ? (sign > 0 ? b.left - a.right : a.left - b.right) : (sign > 0 ? b.top - a.bottom : a.top - b.bottom);
      if (main < -2) continue;
      // Pass 1: targets that overlap the current control on the cross axis (same row/column).
      const overlap = horizontal ? Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) : Math.min(a.right, b.right) - Math.max(a.left, b.left);
      if (overlap > 4) {
        if (main < alignedScore) { alignedScore = main; aligned = el; }
        continue;
      }
      // Pass 2: strict 45° cone from the control's centre.
      const dx = b.left + b.width / 2 - ax, dy = b.top + b.height / 2 - ay;
      const along = horizontal ? sign * dx : sign * dy, across = Math.abs(horizontal ? dy : dx);
      if (along <= 0 || across > along) continue;
      const score = along + across * 2;
      if (score < conedScore) { conedScore = score; coned = el; }
    }
    const best = aligned || coned;
    if (best) setFocus(best);
  }

  // ---------- Tooltip ----------
  function showTooltip(el) {
    const tip = el.dataset.tip;
    const t = $("#tooltip");
    if (!tip) return hideTooltip();
    t.innerHTML = tip; t.hidden = false;
    const w = $("#window").getBoundingClientRect(), r = el.getBoundingClientRect();
    const s = currentScale;
    let left = (r.right - w.left) / s + 10, top = (r.top - w.top) / s;
    if (r.width / s > 420) { // wide controls (list rows): tooltip below, right-aligned
      left = (r.right - w.left) / s - 310; top = (r.bottom - w.top) / s + 6;
    } else if (left + 310 > 1160) left = (r.left - w.left) / s - 310;
    if (top + 90 > 740) top = 740 - 100;
    t.style.left = Math.max(8, left) + "px"; t.style.top = Math.max(8, top) + "px";
  }
  function hideTooltip() { $("#tooltip").hidden = true; }

  // ---------- Input ----------
  document.addEventListener("keydown", (e) => {
    if ($("#window").hidden) { if (e.key === "Enter") reopen(); return; }
    if (document.activeElement && document.activeElement.id === "searchInput") return;
    const k = e.key;
    const map = { ArrowUp: () => move("up"), ArrowDown: () => move("down"), ArrowLeft: () => move("left"), ArrowRight: () => move("right"),
      Enter: () => activate(focused), " ": () => activate(focused), Escape: back, Backspace: back,
      q: () => setTab(state.tab === "overview" ? "zones" : "overview"), e: () => setTab(state.tab === "overview" ? "zones" : "overview"),
      y: () => { if (state.tab === "zones" && !state.detail) { state.view = state.view === "cards" ? "list" : "cards"; render(); restoreCatalog(); } },
      x: () => { if (state.detail) activate($("[data-map]")); else if (state.tab === "zones") { setFocus($("[data-search]")); $("#searchInput").focus(); } },
      PageDown: () => page(1), PageUp: () => page(-1) };
    const fn = map[k] || map[k.toLowerCase && k.toLowerCase()];
    if (fn) { e.preventDefault(); fn(); }
  });
  function page(dir) {
    const sc = $("#scroll"); if (!sc) return;
    sc.scrollBy({ top: dir * sc.clientHeight * 0.85 });
    setTimeout(() => {
      const r = sc.getBoundingClientRect();
      const first = [...sc.querySelectorAll(".focusable")].find(el => { const b = el.getBoundingClientRect(); return b.top >= r.top && b.bottom <= r.bottom; });
      if (first) setFocus(first, { noScroll: true });
    }, 350);
  }
  document.addEventListener("click", (e) => {
    const el = e.target.closest("#window .focusable");
    if (!el) return;
    if (el.dataset.search !== undefined) { setFocus(el); return; }
    setFocus(el, { noScroll: true });
    activate(el);
  });
  document.addEventListener("mouseover", (e) => {
    const el = e.target.closest("#window .focusable");
    if (el) showTooltip(el); else if (focused) showTooltip(focused);
  });
  function reopen() { $("#window").hidden = false; $("#reopen").hidden = true; render(); focusFirst(); }
  $("#reopen").addEventListener("click", reopen);

  // ---------- Scale to screen ----------
  let currentScale = 1;
  function fit() {
    const stage = $("#stage").getBoundingClientRect();
    currentScale = $("#scaleToggle").checked ? Math.min((stage.width - 24) / 1160, (stage.height - 24) / 740, 1.6) : 1;
    $("#window").style.transform = `scale(${currentScale})`;
  }
  window.addEventListener("resize", fit);
  $("#scaleToggle").addEventListener("change", fit);

  renderHeader();
  render();
  fit();
  focusFirst();
})();
