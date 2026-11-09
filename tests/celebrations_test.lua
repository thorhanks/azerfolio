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
end
