-- Celebrations: what counts as a change worth celebrating (pure).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/Systems/Celebrations.lua", "Azerfolio", ns)
    return ns.Celebrations
end

-- A Zones entry with categories { key = state } ("complete", "progress", "untouched", "pending").
local function entry(mapID, state, cats)
    local list = {}
    for _, key in ipairs({ "explore", "quests", "flights" }) do
        local s = cats[key]
        if s == "pending" then list[#list + 1] = { key = key, pending = "building", state = "unknown" }
        elseif s then list[#list + 1] = { key = key, state = s } end
    end
    return { mapID = mapID, tracked = true, state = state, cats = list }
end

local function kinds(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.mapID .. ":" .. e.kind end
    return table.concat(out, ",")
end

return function(t)
    t.test("celebrations: a category known open and now complete earns its streamer", function()
        local C = load()
        local before = C.Snapshot({ entry(1429, "progress", { explore = "progress", quests = "progress" }) })
        local after = C.Snapshot({ entry(1429, "progress", { explore = "complete", quests = "progress" }) })
        t.eq(kinds(C.Diff(before, after)), "1429:explore")
        t.eq(kinds(C.Diff(after, after)), "", "nothing new")
    end)

    t.test("celebrations: the last category completing claims the zone, once", function()
        local C = load()
        local before = C.Snapshot({ entry(1429, "progress", { explore = "complete", quests = "progress" }) })
        local after = C.Snapshot({ entry(1429, "complete", { explore = "complete", quests = "complete" }) })
        t.eq(kinds(C.Diff(before, after)), "1429:claim", "the claim replaces the category's own")
    end)

    t.test("celebrations: data arriving late celebrates nothing", function()
        local C = load()
        -- Quests were still being read; a flight master's list wasn't known yet.
        local before = C.Snapshot({ entry(1429, "unknown", { explore = "complete", quests = "pending" }),
            entry(1436, "progress", { explore = "progress", flights = "pending" }) })
        local after = C.Snapshot({ entry(1429, "complete", { explore = "complete", quests = "complete" }),
            entry(1436, "progress", { explore = "progress", flights = "complete" }) })
        t.eq(kinds(C.Diff(before, after)), "")
        t.eq(kinds(C.Diff(nil, after)), "", "no earlier snapshot: the first one only")
        local new = C.Snapshot({ entry(1426, "complete", { explore = "complete" }) })
        t.eq(kinds(C.Diff(before, new)), "", "a zone not in the earlier snapshot")
    end)

    t.test("celebrations: claims first, then categories in order, zones by map ID", function()
        local C = load()
        local before = C.Snapshot({
            entry(1436, "progress", { explore = "progress", quests = "progress", flights = "progress" }),
            entry(1429, "progress", { explore = "complete", quests = "progress" }) })
        local after = C.Snapshot({
            entry(1436, "progress", { explore = "complete", quests = "progress", flights = "complete" }),
            entry(1429, "complete", { explore = "complete", quests = "complete" }) })
        t.eq(kinds(C.Diff(before, after)), "1429:claim,1436:explore,1436:flights")
    end)

    -- Phase 15 step 9 ---------------------------------------------------------------------------
    local function road(complete, states)
        local stops = {}
        for _, s in ipairs(states) do stops[#stops + 1] = { key = s[1], state = s[2] } end
        return { status = "ready", journey = { complete = complete, stops = stops } }
    end
    local function list(evs, field)
        local out = {}
        for _, e in ipairs(evs) do out[#out + 1] = e.kind .. (field and (":" .. tostring(e[field])) or "") end
        return table.concat(out, ",")
    end

    t.test("celebrations: a class road stop known open and now done; the road walked replaces it", function()
        local C = load()
        local b = C.ClassSnapshot(road(false, { { "letter", "done" }, { "divinity", "eligible" }, { "valor", "later" } }))
        local a = C.ClassSnapshot(road(false, { { "letter", "done" }, { "divinity", "done" }, { "valor", "later" } }))
        t.eq(list(C.ClassDiff(b, a), "key"), "stop:divinity")
        t.eq(list(C.ClassDiff(a, a)), "", "nothing new")
        local all = C.ClassSnapshot(road(true, { { "letter", "done" }, { "divinity", "done" }, { "valor", "done" } }))
        t.eq(list(C.ClassDiff(a, all)), "road", "the last stop walks the road: one celebration")
        t.eq(C.ClassSnapshot({ status = "building" }), nil, "not ready: no snapshot")
        local unknown = C.ClassSnapshot(road(nil, { { "letter", "unknown" }, { "divinity", "unknown" } }))
        t.eq(list(C.ClassDiff(unknown, a)), "", "completed quests arriving late celebrate nothing")
        t.eq(list(C.ClassDiff(nil, a)), "", "no earlier snapshot")
    end)

    t.test("celebrations: a profession rank trained, Mastered, and a profession learned (nothing)", function()
        local C = load()
        local function skills(rows)
            local o = {}
            for _, r in ipairs(rows) do o[#o + 1] = { skillLine = r[1], skill = r[2], cap = r[3] } end
            return o
        end
        local b = C.ProfSnapshot(skills({ { 164, 50, 75 }, { 186, 299, 300 }, { 129, 42, 0 } }))
        local a = C.ProfSnapshot(skills({ { 164, 50, 150 }, { 186, 300, 300 }, { 129, 42, 150 }, { 185, 1, 75 } }))
        t.eq(list(C.ProfDiff(b, a, 300), "skillLine"), "rank:164,mastered:186",
            "First Aid's cap read 0 before (unknown): no rank; Cooking learned now: nothing")
        t.eq(list(C.ProfDiff(a, a, 300)), "")
        t.eq(list(C.ProfDiff(nil, a, 300)), "")
    end)

    t.test("celebrations: a reputation reaction rising, read before and now", function()
        local C = load()
        t.eq(list(C.RepDiff({ [72] = 5, [47] = 4, [69] = 6 }, { [72] = 6, [47] = 4, [69] = 5, [54] = 6 }), "factionID"), "rep:72",
            "a fall and a faction read only now celebrate nothing")
        local ev = C.RepDiff({ [72] = 7 }, { [72] = 8 })[1]
        t.eq(ev.reaction, 8, "Exalted")
        t.eq(list(C.RepDiff(nil, { [72] = 8 })), "")
    end)
end
