-- Zone factions (Systems/ReputationRules.lua, pure) and zone reputation (Systems/Reputation.lua).
local wow = require("mocks.wow")

local function loadRules()
    return wow.loadAddonFile("Azerfolio/Systems/ReputationRules.lua", "Azerfolio", {}).ReputationRules
end

-- The full stack with stub services; `events` collects On() and Register() handlers.
local function load()
    wow.install()
    local events, sent, traces = {}, {}, {}
    local function add(name, fn)
        events[name] = events[name] or {}
        table.insert(events[name], fn)
    end
    local ns = {
        Events = {
            On = add,
            Send = function(msg)
                sent[#sent + 1] = msg
                for _, fn in ipairs(events[msg] or {}) do fn() end
            end,
            Debounce = function(_, _, fn) fn() end,
            Register = function(e, fn) add(e, fn); return true end,
        },
        Debug = { Trace = function(kind, f) traces[#traces + 1] = { kind = kind, f = f } end,
            Error = function() end, Try = function(_, fn, ...) return fn(...) end },
    }
    for _, f in ipairs({ "Systems/Objectives.lua", "Systems/Progression.lua", "Systems/QuestRules.lua",
        "Systems/Quests.lua", "Systems/ReputationRules.lua", "Systems/Reputation.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    local function fire(name) for _, fn in ipairs(events[name] or {}) do fn() end end
    return ns, fire, sent, traces
end

-- zones = { [mapID] = { questID... } }; rewards = { [questID] = {{factionID, amount}...} }
local function build(R, zones, rewards, opts)
    return R.Build(zones, function(id) return rewards[id] end, opts)
end

local function ids(n, from)
    local t = {}
    for i = 1, n do t[i] = from + i end
    return t
end

local BOOTY, BLOODSAIL, STORMWIND, WSG, GELKIS, MAGRAM = 21, 87, 72, 889, 92, 93

-- A fake C_Reputation: list = index rows ({ factionID, name, isHeader, isCollapsed, children = {...} });
-- byID = { [factionID] = data }. Expand/Collapse change what the index shows, like the client.
local function fakeRep(list, byID, opts)
    opts = opts or {}
    local calls = { expand = 0, collapse = 0, watched = 0 }
    local function rows()
        local out = {}
        local function walk(items)
            for _, r in ipairs(items) do
                out[#out + 1] = r
                if r.isHeader and not r.isCollapsed then walk(r.children or {}) end
            end
        end
        walk(list)
        return out
    end
    local api = {
        GetNumFactions = function() return #rows() end,
        GetFactionDataByIndex = function(i)
            local r = rows()[i]
            return r and { factionID = r.factionID, name = r.name, isHeader = r.isHeader, isCollapsed = r.isCollapsed } or nil
        end,
        GetFactionDataByID = function(id)
            if opts.failOn == id then error("boom") end
            return byID[id]
        end,
        SetWatchedFactionByIndex = function() calls.watched = calls.watched + 1 end,
    }
    if not opts.noExpand then
        api.ExpandFactionHeader = function(i) calls.expand = calls.expand + 1; rows()[i].isCollapsed = false end
        api.CollapseFactionHeader = function(i) calls.collapse = calls.collapse + 1; rows()[i].isCollapsed = true end
    end
    return api, calls
end

local function data(name, reaction, standing, lo, hi, atWar)
    return { name = name, reaction = reaction, currentStanding = standing, currentReactionThreshold = lo,
        nextReactionThreshold = hi, atWarWith = atWar or false }
end

return function(t)
    t.test("rep rule: >= 5 raising quests, or >= 3 with half the faction's quests", function()
        local R = loadRules()
        local rewards = {}
        local zones = { [1] = ids(5, 100), [2] = ids(4, 200), [3] = ids(3, 300), [4] = ids(3, 400) }
        for _, id in ipairs(zones[1]) do rewards[id] = { { 500, 75 } } end           -- 5 here: kept
        for _, id in ipairs(zones[2]) do rewards[id] = { { 600, 50 } } end           -- 4 of 7 (57%): kept
        for _, id in ipairs(zones[3]) do rewards[id] = { { 600, 50 } } end           -- 3 of 7 (43%): dropped
        for _, id in ipairs(zones[4]) do rewards[id] = { { 700, 10 } } end           -- 3 of 3: kept
        local out = build(R, zones, rewards)
        t.eq(out[1].factions[1].factionID, 500)
        t.eq(out[1].factions[1].count, 5)
        t.eq(out[2].factions[1].factionID, 600)
        t.eq(out[3], nil, "3 quests and 43% isn't enough")
        t.eq(out[4].factions[1].count, 3)
        t.eq(out[4].factions[1].share, 1)
        -- The thresholds are options (qdb.lua reps rule min low share).
        t.ok(build(R, zones, rewards, { low = 2, share = 0.4 })[3], "looser rule keeps zone 3")
    end)

    t.test("rep rule: home and battleground factions are left out; losses don't count", function()
        local R = loadRules()
        local zones = { [1434] = ids(6, 0) }
        local rewards = {}
        for i, id in ipairs(zones[1434]) do
            rewards[id] = { { STORMWIND, 250 }, { WSG, 100 }, { BOOTY, 150 }, { BLOODSAIL, i <= 3 and -25 or -10 } }
        end
        local out = build(R, zones, rewards)
        t.eq(#out[1434].factions, 1)
        t.eq(out[1434].factions[1].factionID, BOOTY)
        t.eq(out[1434].factions[1].count, 6)
        t.same(out[1434].rivals, {}, "a lowered faction that isn't a zone faction isn't a rival")
    end)

    t.test("rep rule: malformed rewards are skipped, a faction counts once per quest", function()
        local R = loadRules()
        t.eq(R.Rewards(nil), nil)
        t.eq(R.Rewards({}), nil)
        t.same(R.Rewards({ { 21, 10 }, { 21, 99 }, { "x", 1 }, 5, { 47 } }), { [21] = 10 })
        local zones = { [1] = ids(5, 0) }
        local rewards = {}
        for _, id in ipairs(zones[1]) do rewards[id] = { { 21, 10 }, { 21, 10 } } end
        rewards[3] = "bad"
        local out = build(R, zones, rewards)
        t.eq(out[1].factions[1].count, 4, "the bad row is skipped; duplicates count once")
    end)

    t.test("rep rule: rivals both ways, display order keeps a rival after its rival", function()
        local R = loadRules()
        local zones = { [1434] = ids(12, 0) }
        local rewards = {}
        for i = 1, 6 do rewards[i] = { { BOOTY, 150 }, { BLOODSAIL, -25 } } end
        for i = 7, 9 do rewards[i] = { { BLOODSAIL, 100 }, { BOOTY, -50 } } end
        for i = 10, 12 do rewards[i] = { { 999, 10 } } end   -- 3 of 3, but count above Bloodsail's
        rewards[12] = { { 999, 10 }, { 998, 5 } }
        local out = build(R, zones, rewards)
        local z = out[1434]
        local order = {}
        for _, f in ipairs(z.factions) do order[#order + 1] = f.factionID end
        t.same(order, { BOOTY, BLOODSAIL, 999 }, "Booty Bay (6), its rival, then 999 (3)")
        t.same(z.rivals[BOOTY], { BLOODSAIL })
        t.same(z.rivals[BLOODSAIL], { BOOTY })
        t.eq(z.rivals[999], nil)
        t.same(z.factions[1].quests[1], { id = 1, amount = 150 }, "quests with their base amount, by ID")
        -- Order: rivals placed right after, even when a third faction has more quests.
        local o = R.Order({ { factionID = 1 }, { factionID = 2 }, { factionID = 3 } }, { [1] = { 3 }, [3] = { 1 } })
        t.same({ o[1].factionID, o[2].factionID, o[3].factionID }, { 1, 3, 2 })
    end)

    t.test("rep rule: Gelkis and Magram (Desolace): each side raises one, lowers the other", function()
        local R = loadRules()
        local zones = { [1443] = ids(10, 0) }
        local rewards = {}
        for i = 1, 5 do rewards[i] = { { GELKIS, 250 }, { MAGRAM, -500 } } end
        for i = 6, 10 do rewards[i] = { { MAGRAM, 250 }, { GELKIS, -500 } } end
        local z = build(R, zones, rewards)[1443]
        t.eq(#z.factions, 2)
        t.same(z.rivals[GELKIS], { MAGRAM })
        t.same(z.rivals[MAGRAM], { GELKIS })
    end)

    t.test("reputation: standing, progress into the reaction, at war", function()
        local ns = load()
        local S = ns.Reputation.Standing
        local s = S(data("Stormwind", 5, 6600, 3000, 9000))
        t.eq(s.into, 3600)
        t.eq(s.span, 6000)
        t.eq(s.maxed, false)
        t.eq(s.atWar, false)
        local h = S(data("Timbermaw Hold", 2, -3500, -6000, -3000, true))
        t.eq(h.into, 2500, "standing is absolute: -3500 is 2,500 into Hostile")
        t.eq(h.span, 3000)
        t.eq(h.atWar, true)
        local e = S(data("Exalted one", 8, 42999, 42000, 42000))
        t.eq(e.maxed, true)
        t.eq(e.into, nil, "no span: shown without numbers")
        t.eq(ns.Reputation.ReadFaction(nil, 21), nil)
        t.eq(ns.Reputation.ReadFaction({ GetFactionDataByID = function() error("x") end }, 21), nil, "pcall")
        t.eq(ns.Reputation.ReadFaction({ GetFactionDataByID = function() return {} end }, 21), nil, "no reaction")
    end)

    t.test("reputation: met list opens collapsed headers and closes them again", function()
        local ns = load()
        local list = {
            { factionID = 469, name = "Alliance", isHeader = true, isCollapsed = false, children = {
                { factionID = 72, name = "Stormwind" } } },
            { factionID = 1118, name = "Classic", isHeader = true, isCollapsed = true, children = {
                { factionID = 1, name = "Steamwheedle", isHeader = true, isCollapsed = true, children = {
                    { factionID = BOOTY, name = "Booty Bay" } } },
                { factionID = 576, name = "Timbermaw Hold" } } },
            { factionID = 59, name = "Thorium Brotherhood" },
        }
        local api, calls = fakeRep(list, {})
        local met, complete, expanded = ns.Reputation.ReadMet(api)
        t.ok(met[72] and met[BOOTY] and met[576] and met[59], "children of collapsed headers are seen")
        t.eq(complete, true)
        t.eq(expanded, 2)
        t.eq(calls.collapse, 2)
        t.eq(list[2].isCollapsed, true, "outer header collapsed again")
        t.eq(list[2].children[1].isCollapsed, true, "inner header collapsed again")
        t.eq(list[1].isCollapsed, false, "an open header stays open")
        t.eq(calls.watched, 0, "the watched faction is never touched")
        -- Without Expand: what's hidden is unknown, not unmet.
        list[2].isCollapsed = true
        local api2 = fakeRep(list, {}, { noExpand = true })
        local met2, complete2 = ns.Reputation.ReadMet(api2)
        t.eq(met2[BOOTY], nil)
        t.eq(complete2, false)
    end)

    t.test("reputation: a zone's factions, dropping ones without data; met, rivals, quests", function()
        local ns = load()
        local zone = { factions = {
            { factionID = BOOTY, count = 2, quests = { { id = 1, amount = 150 }, { id = 2, amount = 75 } } },
            { factionID = BLOODSAIL, count = 1, quests = { { id = 3, amount = 100 } } },
            { factionID = 471, count = 1, quests = { { id = 4, amount = 10 } } },
        }, rivals = { [BOOTY] = { BLOODSAIL }, [BLOODSAIL] = { BOOTY } } }
        local byID = { [BOOTY] = data("Booty Bay", 4, 500, 0, 3000), [BLOODSAIL] = data("Bloodsail Buccaneers", 1, -6500, -42000, -6000, true) }
        local read = function(id) return byID[id] end
        local state = function(id) return id == 1 and { name = "Q1", completion = "complete" } or nil end
        local list = ns.Reputation.Zone(zone, read, { [BOOTY] = true }, true, state)
        t.eq(#list, 2, "471: the game returns nothing, so it's left out")
        t.eq(list[1].name, "Booty Bay")
        t.eq(list[1].met, true)
        t.eq(list[1].into, 500)
        t.eq(list[1].span, 3000)
        t.same(list[1].rivals, { { factionID = BLOODSAIL, name = "Bloodsail Buccaneers" } })
        t.eq(list[1].quests[1].completion, "complete")
        t.eq(list[1].quests[1].amount, 150)
        t.eq(list[2].met, false, "met list complete: not in it = not met yet")
        t.eq(list[2].atWar, true)
        t.eq(ns.Reputation.Zone(zone, read, {}, false, nil)[2].met, nil, "met list incomplete: unknown")
        t.eq(ns.Reputation.Zone(zone, function() return nil end, {}, true), nil, "nothing left: nil")
        byID[BLOODSAIL] = nil
        t.same(ns.Reputation.Zone(zone, read, {}, true)[1].rivals, {}, "a rival without data isn't named")
    end)

    t.test("reputation: live, from Quests' zone data; refresh on UPDATE_FACTION", function()
        local ns, fire, sent = load()
        -- Stranglethorn (area 33 -> 1434): 6 Booty Bay quests (one repeatable), 3 Bloodsail.
        local quests = {}
        for id = 1, 6 do quests[id] = { 33, id == 6 and 1 or 0, name = "B" .. id, questLevel = 40,
            reputationReward = { { BOOTY, 150 }, { BLOODSAIL, -25 } } } end
        for id = 7, 9 do quests[id] = { 33, 0, name = "S" .. id, questLevel = 40,
            reputationReward = { { BLOODSAIL, 100 }, { BOOTY, -50 } } } end
        quests[10] = { 33, 0, name = "Other", reputationReward = { { 471, 10 } } }
        local qids = {}
        for id in pairs(quests) do qids[#qids + 1] = id end
        table.sort(qids)
        local Q = { GetAllIds = function() return qids end, Exists = function(id) return quests[id] ~= nil end,
            zoneOrSort = function(id) return quests[id][1] end, specialFlags = function(id) return quests[id][2] end }
        for _, f in ipairs({ "name", "questLevel", "reputationReward" }) do
            Q[f] = function(id) return quests[id] and quests[id][f] end
        end
        _G.LibQuestieDB = { contractVersion = 4, RequireContract = function() return true end, Quest = Q }
        ns.QuestAreaData = { zone = { [33] = 1434 } }
        _G.C_QuestLog = { GetAllCompletedQuestIDs = function() return { 1 } end }
        ns.character = { raceID = 1, classID = 2, level = 45 }
        local byID = { [BOOTY] = data("Booty Bay", 4, 500, 0, 3000), [BLOODSAIL] = data("Bloodsail Buccaneers", 1, -6500, -42000, -6000, true) }
        local list = { { factionID = 469, name = "Alliance", isHeader = true, children = { { factionID = 72, name = "Stormwind" } } } }
        local api = fakeRep(list, byID)
        _G.C_Reputation = api
        t.eq(ns.Reputation.ForZone(1434), nil, "nothing before Quests is ready")
        fire("AZF_READY")
        wow.runTimers()
        t.eq(ns.Reputation.State().status, "ready")
        local z = ns.Reputation.ForZone({ mapID = 1434 })
        t.eq(#z, 2, "471 dropped (no data)")
        t.eq(z[1].factionID, BOOTY)
        t.eq(z[1].count, 6, "the repeatable counts")
        t.eq(z[1].met, false, "not in the index list")
        t.eq(z[1].rivals[1].factionID, BLOODSAIL)
        t.eq(z[1].quests[1].completion, "complete", "Quests' state")
        t.eq(z[1].quests[6].repeatable, true)
        t.eq(z[1].quests[6].name, "B6")
        t.eq(z[2].factionID, BLOODSAIL)
        t.eq(ns.Reputation.Faction(1434, BLOODSAIL).count, 3)
        t.eq(ns.Reputation.ForZone(1429), nil, "a zone without a zone faction")
        -- Meeting Booty Bay and gaining standing: UPDATE_FACTION re-reads.
        list[2] = { factionID = BOOTY, name = "Booty Bay" }
        byID[BOOTY] = data("Booty Bay", 5, 3600, 3000, 9000)
        local before = #sent
        fire("UPDATE_FACTION")
        t.eq(sent[before + 1], "AZF_REPUTATION_UPDATED")
        z = ns.Reputation.ForZone(1434)
        t.eq(z[1].met, true)
        t.eq(z[1].reaction, 5)
        t.eq(z[1].into, 600)
        _G.LibQuestieDB, _G.C_QuestLog, _G.C_Reputation = nil, nil, nil
    end)

    t.test("reputation: nothing when QuestieDB isn't loaded", function()
        local ns, fire, sent = load()
        _G.LibQuestieDB = nil
        _G.C_Reputation = fakeRep({}, { [BOOTY] = data("Booty Bay", 4, 0, 0, 3000) })
        fire("AZF_READY")
        wow.runTimers()
        t.eq(ns.Reputation.State().status, "unavailable")
        t.eq(ns.Reputation.ForZone(1434), nil)
        t.eq(sent[#sent], "AZF_REPUTATION_UPDATED")
        _G.C_Reputation = nil
    end)
end
