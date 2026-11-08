-- Zones catalogue: states, filters, sorting and sections (pure).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Systems/Objectives.lua", "Systems/Progression.lua", "Systems/Zones.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

-- A tracked ForZone-shaped result: `done` discovered, `todo` not, `unknown` unknown.
local function tracked(ns, done, todo, unknown, coverage)
    local O, objectives, id = ns.Objectives, {}, 0
    local function add(completion, n)
        for _ = 1, n or 0 do
            id = id + 1
            objectives[#objectives + 1] = O.New({ id = id, category = "exploration", completion = completion,
                eligibility = "eligible" })
        end
    end
    add("complete", done); add("incomplete", todo); add("unknown", unknown)
    return { status = "tracked", objectives = objectives, progress = ns.Progression.Aggregate({
        { category = "exploration", coverage = coverage or "complete", objectives = objectives } }) }
end

-- zone(ns, mapID, name, ex[, extra fields])
local function zone(ns, mapID, name, ex, extra)
    local z = { mapID = mapID, name = name, continent = "Eastern Kingdoms", rank = 1 }
    for k, v in pairs(extra or {}) do z[k] = v end
    return ns.Zones.Entry(z, ex)
end

local function names(list)
    local out = {}
    for i, z in ipairs(list) do out[i] = z.name end
    return table.concat(out, ",")
end

-- A small catalogue covering every state.
local function catalogue(ns)
    return {
        zone(ns, 1429, "Elwynn Forest", tracked(ns, 10, 2)),                  -- progress 83%
        zone(ns, 1426, "Dun Morogh", tracked(ns, 0, 12)),                     -- untouched 0%
        zone(ns, 1436, "Westfall", tracked(ns, 11, 0)),                       -- complete 100%
        zone(ns, 1433, "Redridge Mountains", tracked(ns, 1, 9)),              -- progress 10%
        zone(ns, 1453, "Stormwind City", { status = "untracked" }),           -- untracked
        zone(ns, 1437, "Wetlands", { status = "unavailable" }),               -- unknown
        zone(ns, 1411, "Durotar", tracked(ns, 0, 11), { continent = "Kalimdor", rank = 2 }),
    }
end

return function(t)
    t.test("state: complete, progress, untouched, unknown and untracked from the tracker", function()
        local ns = load()
        local Z = ns.Zones
        t.eq(Z.StateOf(tracked(ns, 12, 0)), "complete")
        t.eq(Z.StateOf(tracked(ns, 3, 9)), "progress")
        t.eq(Z.StateOf(tracked(ns, 0, 12)), "untouched")
        t.eq(Z.StateOf({ status = "untracked" }), "untracked")
        t.eq(Z.StateOf({ status = "unavailable" }), "unknown", "unreadable is unknown, not 0%")
        t.eq(Z.StateOf(nil), "untracked")
    end)

    t.test("state: unknown areas never make a zone complete or untouched", function()
        local ns = load()
        local Z = ns.Zones
        t.eq(Z.StateOf(tracked(ns, 11, 0, 1)), "progress", "11 confirmed, 1 unknown: not complete")
        t.eq(Z.StateOf(tracked(ns, 0, 11, 1)), "unknown", "none confirmed done, one unknown: not untouched")
        t.eq(Z.StateOf(tracked(ns, 0, 0, 3)), "unknown")
        t.eq(Z.StateOf(tracked(ns, 12, 0, 0, "partial")), "unknown",
            "partial coverage: Progression counts nothing, so never complete")
    end)

    t.test("entry: percent only where Progression gives one; levels and faction unknown", function()
        local ns = load()
        local e = zone(ns, 1429, "Elwynn Forest", tracked(ns, 10, 2))
        t.ok(math.abs(e.percent - 1000 / 12) < 1e-9)
        t.eq(e.tracked, true); t.eq(e.progress.completed, 10)
        t.eq(e.minLevel, nil); t.eq(e.maxLevel, nil); t.eq(e.faction, nil)
        local u = zone(ns, 1453, "Stormwind City", { status = "untracked" })
        t.eq(u.tracked, false); t.eq(u.percent, nil); t.eq(u.progress, nil)
        local w = zone(ns, 1437, "Wetlands", { status = "unavailable" })
        t.eq(w.tracked, true, "in the catalogue"); t.eq(w.percent, nil)
    end)

    t.test("filter: status segments show only zones confirmed in that state", function()
        local ns = load()
        local list = catalogue(ns)
        local F = function(c) return names(ns.Zones.Filter(list, { completion = c })) end
        t.eq(F("all"), "Elwynn Forest,Dun Morogh,Westfall,Redridge Mountains,Stormwind City,Wetlands,Durotar")
        t.eq(F("progress"), "Elwynn Forest,Redridge Mountains")
        t.eq(F("untouched"), "Dun Morogh,Durotar", "unknown Wetlands isn't counted as untouched")
        t.eq(F("complete"), "Westfall")
    end)

    t.test("filter: search is case-insensitive, trimmed and plain text", function()
        local ns = load()
        local list = catalogue(ns)
        t.eq(names(ns.Zones.Filter(list, { search = "  FOREST " })), "Elwynn Forest")
        t.eq(names(ns.Zones.Filter(list, { search = "w" })), "Elwynn Forest,Westfall,Stormwind City,Wetlands")
        t.eq(#ns.Zones.Filter(list, { search = "%a" }), 0, "a pattern character is literal")
        t.eq(#ns.Zones.Filter(list, { search = "" }), #list)
    end)

    t.test("filter: faction hides only the other faction's known territory", function()
        local ns = load()
        local list = {
            zone(ns, 1, "Ally", tracked(ns, 0, 1), { faction = "Alliance" }),
            zone(ns, 2, "Horde", tracked(ns, 0, 1), { faction = "Horde" }),
            zone(ns, 3, "Contested", tracked(ns, 0, 1), { faction = "Contested" }),
            zone(ns, 4, "Unknown", tracked(ns, 0, 1)),
        }
        local F = function(f, cf) return names(ns.Zones.Filter(list, { faction = f }, { faction = cf })) end
        t.eq(F("relevant", "Alliance"), "Ally,Contested,Unknown")
        t.eq(F("relevant", "Horde"), "Horde,Contested,Unknown")
        t.eq(F("relevant", nil), "Ally,Horde,Contested,Unknown", "unknown character faction hides nothing")
        t.eq(F("all", "Alliance"), "Ally,Horde,Contested,Unknown")
    end)

    t.test("filter: for my level needs a known range; unknown ranges never fit", function()
        local ns = load()
        local list = {
            zone(ns, 1, "Low", tracked(ns, 0, 1), { minLevel = 1, maxLevel = 10 }),
            zone(ns, 2, "Mid", tracked(ns, 0, 1), { minLevel = 10, maxLevel = 20 }),
            zone(ns, 3, "High", tracked(ns, 0, 1), { minLevel = 30, maxLevel = 40 }),
            zone(ns, 4, "Unknown", tracked(ns, 0, 1)),
        }
        local F = function(level) return names(ns.Zones.Filter(list, { level = "appropriate" }, { level = level })) end
        t.eq(F(9), "Low,Mid", "Mid starts within 3 levels")
        t.eq(F(6), "Low")
        t.eq(F(20), "Mid")
        t.eq(F(nil), "", "no character level: nothing confirmed to fit")
        t.eq(#ns.Zones.Filter(list, { level = "all" }, { level = 9 }), 4)
    end)

    t.test("available: a filter is offered only when its data exists", function()
        local ns = load()
        local a = ns.Zones.Available(catalogue(ns))
        t.eq(a.levels, false); t.eq(a.faction, false)
        local b = ns.Zones.Available({ zone(ns, 1, "X", nil, { minLevel = 1, maxLevel = 10, faction = "Horde" }) })
        t.eq(b.levels, true); t.eq(b.faction, true)
        local c = ns.Zones.Available({ zone(ns, 1, "X", nil, { minLevel = 1, faction = "Contested" }) })
        t.eq(c.levels, false, "half a range isn't a range"); t.eq(c.faction, false, "contested hides nothing")
    end)

    t.test("sort: alphabetical, case-insensitive, ties broken by mapID", function()
        local ns = load()
        local list = catalogue(ns)
        list[#list + 1] = zone(ns, 2521, "Zephras Isle", { status = "untracked" })
        list[#list + 1] = zone(ns, 1400, "zephras isle", { status = "untracked" })
        local s = ns.Zones.Sort(list, "alphabetical")
        t.eq(names(s), "Dun Morogh,Durotar,Elwynn Forest,Redridge Mountains,Stormwind City,Westfall,Wetlands,zephras isle,Zephras Isle")
        t.eq(s[8].mapID, 1400)
        t.eq(#list, 9, "the input is not reordered in place")
        t.eq(list[1].name, "Elwynn Forest")
    end)

    t.test("sort: highest and lowest keep zones without data apart from a confirmed 0%", function()
        local ns = load()
        local list = catalogue(ns)
        t.eq(names(ns.Zones.Sort(list, "highest")),
            "Westfall,Elwynn Forest,Redridge Mountains,Dun Morogh,Durotar,Stormwind City,Wetlands")
        t.eq(names(ns.Zones.Sort(list, "lowest")),
            "Dun Morogh,Durotar,Redridge Mountains,Elwynn Forest,Westfall,Stormwind City,Wetlands")
    end)

    t.test("sort: closest puts the fewest areas left first and complete zones after", function()
        local ns = load()
        local list = catalogue(ns)
        list[#list + 1] = zone(ns, 1440, "Ashenvale", tracked(ns, 6, 2)) -- 2 left, 75%
        t.eq(names(ns.Zones.Sort(list, "closest")),
            "Elwynn Forest,Ashenvale,Redridge Mountains,Durotar,Dun Morogh,Westfall,Stormwind City,Wetlands")
    end)

    t.test("sort: recommended goes by level range, unknown levels after by continent", function()
        local ns = load()
        local list = {
            zone(ns, 5, "Kal unknown", nil, { continent = "Kalimdor", rank = 2 }),
            zone(ns, 4, "EK unknown", nil),
            zone(ns, 3, "Thirties", nil, { minLevel = 30, maxLevel = 40 }),
            zone(ns, 2, "Low wide", nil, { minLevel = 1, maxLevel = 12 }),
            zone(ns, 1, "Low", nil, { minLevel = 1, maxLevel = 10 }),
        }
        t.eq(names(ns.Zones.Sort(list, "recommended")), "Low,Low wide,Thirties,EK unknown,Kal unknown")
        t.eq(names(ns.Zones.Sort(list, "nonsense")), "Low,Low wide,Thirties,EK unknown,Kal unknown", "fallback")
    end)

    t.test("sections: level brackets or continents under recommended, one untitled list otherwise", function()
        local ns = load()
        local Z = ns.Zones
        t.eq(Z.SectionOf({ minLevel = 1, maxLevel = 10 }), "Levels 1-10")
        t.eq(Z.SectionOf({ minLevel = 15, maxLevel = 25 }), "Levels 10-20")
        t.eq(Z.SectionOf({ minLevel = 60, maxLevel = 60 }), "Level 60", "no bracket past the cap")
        t.eq(Z.SectionOf({ minLevel = 55, maxLevel = 60 }), "Levels 50-60")
        t.eq(Z.SectionOf({ continent = "Kalimdor" }), "Kalimdor")
        local list = Z.Sort(catalogue(ns), "recommended")
        local g = Z.Groups(list, "recommended")
        t.eq(#g, 2)
        t.eq(g[1].title, "Eastern Kingdoms"); t.eq(#g[1].zones, 6)
        t.eq(g[1].complete, 1, "Westfall"); t.eq(g[1].tracked, 5, "Stormwind City isn't tracked")
        t.eq(g[2].title, "Kalimdor"); t.eq(g[2].complete, 0); t.eq(g[2].tracked, 1)
        local one = Z.Groups(Z.Sort(list, "highest"), "highest")
        t.eq(#one, 1); t.eq(one[1].title, nil); t.eq(#one[1].zones, 7)
        t.eq(#Z.Groups({}, "recommended"), 0)
    end)

    t.test("levels: only sane curated ranges are used", function()
        local ns = load()
        local L = ns.Zones.LevelsFor
        local data = { levels = { [1] = { 1, 10 }, [2] = { 10, 5 }, [3] = { 0, 10 }, [4] = { 50, 61 },
            [5] = { 1.5, 10 }, [6] = "1-10", [7] = { 12 } } }
        local lo, hi = L(data, 1); t.eq(lo, 1); t.eq(hi, 10)
        for id = 2, 8 do t.eq((L(data, id)), nil, "entry " .. id .. " is unknown") end
        t.eq((L(nil, 1)), nil); t.eq((L({}, 1)), nil)
    end)

    t.test("levels: the curated data covers exactly the catalogue's classic zones, all sane", function()
        local ns = load()
        wow.loadAddonFile("Azerfolio/Data/Exploration.lua", "Azerfolio", ns)
        wow.loadAddonFile("Azerfolio/Data/Zones.lua", "Azerfolio", ns)
        local n = 0
        for mapID in pairs(ns.ZoneData.levels) do
            n = n + 1
            t.ok(ns.ExplorationCatalogue.zones[mapID] or mapID == 2521,
                "map " .. mapID .. " is a tracked zone (or Zephras Isle)")
            t.ok(ns.Zones.LevelsFor(ns.ZoneData, mapID), "map " .. mapID .. " has a sane range")
        end
        t.eq(n, 44, "40 classic zones from the wiki + 4 Forever zones from the owner")
        local function range(id) return table.concat(ns.ZoneData.levels[id], "-") end
        t.eq(range(2521), "1-12"); t.eq(range(2548), "35-45"); t.eq(range(2652), "35-45"); t.eq(range(2482), "60-60")
        for _, id in ipairs({ 1453, 1454, 1455, 1456, 1457, 1458 }) do t.eq(ns.ZoneData.levels[id], nil, "capital") end
        t.ok(ns.ZoneData.source:find("Warcraft Wiki"), "provenance recorded")
    end)

    t.test("faction: only Alliance, Horde or Contested; the curated data is sane", function()
        local ns = load()
        local F = ns.Zones.FactionFor
        local d = { faction = { [1] = "Alliance", [2] = "Horde", [3] = "Contested", [4] = "alliance", [5] = true } }
        t.eq(F(d, 1), "Alliance"); t.eq(F(d, 2), "Horde"); t.eq(F(d, 3), "Contested")
        t.eq(F(d, 4), nil, "case matters"); t.eq(F(d, 5), nil); t.eq(F(d, 6), nil); t.eq(F(nil, 1), nil)
        wow.loadAddonFile("Azerfolio/Data/Zones.lua", "Azerfolio", ns)
        local n, counts = 0, { Alliance = 0, Horde = 0, Contested = 0 }
        for mapID, f in pairs(ns.ZoneData.faction) do
            n = n + 1
            t.ok(F(ns.ZoneData, mapID), "map " .. mapID .. " has a valid territory")
            counts[f] = counts[f] + 1
        end
        t.eq(n, 46, "40 classic zones and 6 capitals")
        t.eq(counts.Alliance, 12); t.eq(counts.Horde, 7); t.eq(counts.Contested, 27)
        for _, id in ipairs({ 1440, 1425, 1445, 1435 }) do
            t.eq(ns.ZoneData.faction[id], "Contested", "judgement call kept contested: " .. id)
        end
        for _, id in ipairs({ 2521, 2548, 2652, 2482 }) do t.eq(ns.ZoneData.faction[id], nil) end
    end)

    t.test("query: filter, sort and group together; counts come with it", function()
        local ns = load()
        local q = ns.Zones.Query(catalogue(ns), { completion = "untouched", sort = "recommended" })
        t.eq(q.total, 7); t.eq(q.shown, 2)
        t.eq(names(q.zones), "Dun Morogh,Durotar")
        t.eq(#q.groups, 2)
        t.eq(q.available.levels, false)
        local none = ns.Zones.Query(catalogue(ns), { search = "Silithus" })
        t.eq(none.shown, 0); t.eq(#none.groups, 0)
    end)
end
