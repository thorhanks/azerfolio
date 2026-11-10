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

    t.test("rep tab rules: sides, headers and where a quest's place puts it", function()
        local R = loadRules()
        t.eq(R.Shown(469, "Alliance"), false, "the Alliance header isn't a row")
        t.eq(R.Shown(67, "Horde"), false)
        t.eq(R.Shown(510, "Alliance"), false, "The Defilers: Horde's battleground faction")
        t.eq(R.Shown(509, "Alliance"), true)
        t.eq(R.Shown(2798, "Alliance"), false)
        t.eq(R.Shown(2799, "Horde"), false)
        t.eq(R.Shown(510, nil), true, "side unknown: keep it")
        t.eq(R.Shown(BOOTY, "Horde"), true)
        t.same({ R.SourceOf("zone", 1434) }, { "zone", 1434 })
        t.same({ R.SourceOf("dungeon", 2557) }, { "dungeon", 2557 })
        t.same({ R.SourceOf("sort", -162) }, { "class", -162, "ROGUE" })
        t.same({ R.SourceOf("sort", -121) }, { "profession", -121 })
        t.same({ R.SourceOf("sort", -364) }, { "event", -364 })
        t.same({ R.SourceOf("sort", -25) }, { "battleground", -25 })
        t.same({ R.SourceOf("sort", -284) }, { "other", -284 })
        t.same({ R.SourceOf("unmapped", 16941) }, { "profession", 16941 }, "Forever's Crafting area")
        t.same({ R.SourceOf("unmapped", 25) }, { "unplaced", 25 })
        t.same({ R.SourceOf("nozone", nil) }, { "unplaced" })
    end)

    t.test("rep tab rules: catalogue, sources, group and the main place", function()
        local R = loadRules()
        local THORIUM, RAVEN, SHEN = 59, 349, 809
        local entries, rewards = {}, {}
        local function add(id, kind, key, rw, rep)
            entries[#entries + 1] = { id = id, kind = kind, key = key, repeatable = rep }
            rewards[id] = rw
        end
        for i = 1, 4 do add(i, "zone", 1427, { { THORIUM, 100 } }) end            -- Searing Gorge
        add(5, "zone", 1427, { { THORIUM, 25 } }, true)                            -- a repeatable
        for i = 6, 7 do add(i, "raid", 2717, { { THORIUM, 200 } }) end             -- Molten Core
        for i = 8, 10 do add(i, "sort", -121, { { THORIUM, 150 } }) end            -- Blacksmithing
        add(11, "nozone", nil, { { THORIUM, 50 } })                                -- no place
        for i = 12, 13 do add(i, "sort", -162, { { RAVEN, 110 } }) end             -- Rogue quests
        for i = 14, 16 do add(i, "dungeon", 2557, { { SHEN, 200 } }) end           -- Dire Maul
        add(17, "zone", 1429, { { STORMWIND, 75 }, { BLOODSAIL, -10 } })
        add(18, "zone", 1429, nil)
        local cat = R.Catalogue(entries, function(id) return rewards[id] end)
        t.eq(cat[THORIUM].raising, 10, "placed raising quests, the repeatable included")
        t.eq(cat[THORIUM].unplaced, 1)
        t.eq(cat[BLOODSAIL], nil, "a faction only lowered isn't catalogued")
        t.same(cat[STORMWIND].sources["zone:1429"].quests[1].lowers, { BLOODSAIL })
        local list = R.SourceList(cat[THORIUM])
        t.same({ list[1].kind, list[2].kind, list[3].kind }, { "zone", "profession", "raid" }, "most quests first")
        t.eq(#list[1].quests, 5)
        t.eq(R.GroupOf(THORIUM, cat[THORIUM]), "zones", "5 zone quests beat 3 and 2")
        t.eq(R.GroupOf(RAVEN, cat[RAVEN]), "other", "class quests")
        t.eq(R.GroupOf(SHEN, cat[SHEN]), "instances")
        t.eq(R.GroupOf(STORMWIND, cat[STORMWIND]), "home", "home factions are Home whatever their quests")
        t.eq(R.GroupOf(509, nil), "bgs")
        t.eq(R.GroupOf(2747, nil), "none", "no known quests")
        t.eq(R.Main(list, "zones").key, 1427)
        t.eq(R.Main(R.SourceList(cat[SHEN]), "instances").key, 2557)
        t.eq(R.Main({}, "none"), nil)
    end)

    t.test("rep tab rules: the reach counts one-time quests you can still do, capped", function()
        local R = loadRules()
        t.eq(R.ReactionAt(-42000), 1)
        t.eq(R.ReactionAt(-3500), 2)
        t.eq(R.ReactionAt(500), 4)
        t.eq(R.ReactionAt(3000), 5)
        t.eq(R.ReactionAt(42999), 8)
        local fc = { sources = {
            ["zone:1434"] = { kind = "zone", key = 1434, quests = {
                { id = 1, amount = 150, lowers = { BLOODSAIL } }, -- done
                { id = 2, amount = 250, lowers = { BLOODSAIL } }, -- eligible, not done
                { id = 3, amount = 100 },                         -- locked (level): counts
                { id = 4, amount = 500 },                         -- the other side's: left out
                { id = 5, amount = 75 },                          -- eligibility unknown
                { id = 6, amount = 50, repeatable = true },       -- repeatable: counted, not added
                { id = 9, amount = 40 },                          -- no completed list: unknown
            } },
            ["class:-162"] = { kind = "class", key = -162, classFile = "ROGUE", quests = {
                { id = 7, amount = 1000 } } },
        } }
        local st = { [1] = { completion = "complete", eligibility = "eligible" },
            [2] = { completion = "incomplete", eligibility = "eligible" },
            [3] = { completion = "incomplete", eligibility = "locked" },
            [4] = { completion = "incomplete", eligibility = "unavailable" },
            [5] = { completion = "incomplete", eligibility = "unknown" },
            [6] = { completion = "incomplete", eligibility = "eligible" },
            [7] = { completion = "incomplete", eligibility = "unavailable" },
            [9] = { completion = "unknown", eligibility = "eligible" } }
        local sources, reach = R.Evaluate(fc, function(id) return st[id] end,
            { classFile = "PALADIN", standing = 500, rivals = { BLOODSAIL } })
        t.eq(#sources, 2)
        local z, c = sources[1], sources[2]
        t.eq(z.kind, "zone")
        t.eq(z.count, 6, "the other side's quest is left out")
        t.eq(z.oneTime, 5)
        t.eq(z.repeats, 1)
        t.eq(z.done, 1)
        t.eq(z.left, 2)
        t.eq(z.unknown, 2)
        t.eq(z.amount, 150 + 250 + 100 + 75 + 40)
        t.eq(z.amountLeft, 350)
        t.eq(c.forYou, false, "Rogue quests for a Paladin")
        t.eq(c.count, 1, "listed, dimmed")
        t.eq(reach.gain, 350, "eligible + locked, not done; the class quest adds nothing")
        t.eq(reach.count, 2)
        t.eq(reach.repeats, 1)
        t.eq(reach.unknown, 2)
        t.eq(reach.done, 1)
        t.eq(reach.lowersRival, 1)
        t.eq(reach.target, 850)
        t.eq(reach.reaction, 4, "not quite enough for Friendly")
        t.eq(reach.into, 850, "the reach mark: 850 into Neutral")
        t.eq(reach.span, 3000)
        t.eq(reach.capped, false)
        local _, r2 = R.Evaluate(fc, function(id) return st[id] end, { standing = 42900 })
        t.eq(r2.target, 42999, "capped at Exalted")
        t.eq(r2.capped, true)
        t.eq(r2.reaction, 8)
        local s3 = R.Evaluate(fc, function(id) return st[id] end, { classFile = "ROGUE" })
        t.eq(#s3, 1, "for you, the rules' state applies: quest 7 unavailable, so no Rogue row")
        local _, r4 = R.Evaluate(nil, nil, { standing = 0 })
        t.eq(r4.gain, 0)
        t.eq(r4.target, 0)
    end)

    t.test("rep tab rules: sorts, filters, the strip's counts and groups", function()
        local R = loadRules()
        local list = {
            { factionID = 1, name = "Stormwind", group = "home", met = true, reaction = 8, maxed = true, raising = 200 },
            { factionID = 2, name = "Booty Bay", group = "zones", met = false, reaction = 4, left = 2500, raising = 40 },
            { factionID = 3, name = "Argent Dawn", group = "zones", met = true, reaction = 5, left = 4000, raising = 107 },
            { factionID = 4, name = "Ironforge", group = "home", met = true, reaction = 5, left = 900, raising = 150 },
            { factionID = 5, name = "Odd", group = "none", met = nil, reaction = 4, left = 100, raising = 0 },
        }
        local function names(l) local o = {} for i, f in ipairs(l) do o[i] = f.name end return o end
        t.same(names(R.Sort(list, "group")), { "Stormwind", "Ironforge", "Argent Dawn", "Booty Bay", "Odd" })
        t.same(names(R.Sort(list, "closest")), { "Ironforge", "Argent Dawn", "Odd", "Booty Bay", "Stormwind" },
            "met first, least left; Exalted last")
        t.same(names(R.Sort(list, "name")), { "Argent Dawn", "Booty Bay", "Ironforge", "Odd", "Stormwind" })
        t.eq(list[1].name, "Stormwind", "Sort returns a copy")
        t.same(names(R.Filter(list, "met")), { "Stormwind", "Argent Dawn", "Ironforge" })
        t.same(names(R.Filter(list, "unmet")), { "Booty Bay" }, "met unknown: only under All")
        t.eq(#R.Filter(list, "all"), 5)
        local s = R.Summary(list)
        t.same(s.byReaction, { 0, 0, 0, 2, 2, 0, 0, 1 })
        t.eq(s.met, 3)
        t.eq(s.exalted, 1)
        t.eq(s.total, 5)
        local g = R.Grouped(R.Sort(list, "group"))
        t.eq(#g, 3)
        t.eq(g[1].key, "home")
        t.eq(g[1].met, 2)
        t.eq(g[2].total, 2)
        t.eq(g[2].met, 1)
        t.eq(R.NextSort("group"), "closest")
        t.eq(R.NextSort("name"), "group")
        t.eq(R.NextSort("x"), "group")
    end)

    t.test("reputation tab: every faction with data, by side, met, gains, watched, rivals", function()
        local ns = load()
        local R = ns.ReputationRules
        local byID = {
            [469] = data("Alliance", 5, 3312, 3000, 9000),
            [72] = data("Stormwind", 5, 6600, 3000, 9000),
            [BOOTY] = data("Booty Bay", 4, 500, 0, 3000),
            [BLOODSAIL] = data("Bloodsail Buccaneers", 1, -6500, -42000, -6000, true),
            [510] = data("The Defilers", 1, -42000, -42000, -6000, true),
            [1118] = data("Classic", 4, 0, 0, 3000),
            [2747] = data("Barkskin Burrow", 2, -3400, -6000, -3000, true),
        }
        byID[1118].isHeader = true
        byID[BOOTY].isWatched = true
        byID[BOOTY].description = "The goblin port."
        local cat = R.Catalogue({ { id = 1, kind = "zone", key = 1434 }, { id = 2, kind = "zone", key = 1434 },
            { id = 3, kind = "zone", key = 1429 } },
            function(id) return id == 3 and { { 72, 75 } } or { { BOOTY, 150 }, { BLOODSAIL, -25 } } end)
        local o = { ids = { 469, 72, BOOTY, BLOODSAIL, 510, 1118, 2747, 471, BOOTY },
            read = function(id) return byID[id] end, met = { [72] = true, [469] = true }, metComplete = true,
            side = "Alliance", catalogue = cat, sources = "ready",
            stateOf = function(id) return { completion = id == 1 and "complete" or "incomplete", eligibility = "eligible" } end,
            classFile = "PALADIN", rivals = { [BOOTY] = { BLOODSAIL }, [BLOODSAIL] = { BOOTY } },
            baseline = { [72] = 6250, [BOOTY] = 500 },
            placeName = function(kind, key) return kind == "zone" and ("Z" .. key) or nil end,
            isZoneFaction = function(mapID, f) return mapID == 1434 and f == BOOTY end }
        local all = ns.Reputation.All(o)
        local by = {}
        for _, f in ipairs(all) do by[f.factionID] = f end
        t.eq(#all, 4, "header, the other side's battleground faction, a header by data and no-data left out")
        t.eq(by[469], nil)
        t.eq(by[510], nil)
        t.eq(by[1118], nil)
        t.eq(by[72].met, true)
        t.eq(by[72].gain, 350, "+350 this session")
        t.eq(by[72].group, "home")
        t.eq(by[72].left, 2400)
        t.eq(by[BOOTY].met, false)
        t.eq(by[BOOTY].gain, nil, "no change")
        t.eq(by[BOOTY].watched, true)
        t.eq(by[BOOTY].description, "The goblin port.")
        t.eq(by[BOOTY].group, "zones")
        t.eq(by[BOOTY].artMap, 1434)
        t.eq(by[BOOTY].sources[1].name, "Z1434")
        t.eq(by[BOOTY].sources[1].zoneFaction, true)
        t.eq(by[BOOTY].reach.gain, 150, "quest 1 is done")
        t.eq(by[BOOTY].reach.lowersRival, 1)
        t.eq(by[BOOTY].rivals[1].name, "Bloodsail Buccaneers")
        t.eq(by[2747].group, "none")
        t.same(by[2747].sources, {})
        t.eq(by[BLOODSAIL].watched, false)
        -- Without sources: Home still placed, the rest unknown.
        o.catalogue, o.sources = nil, "unavailable"
        local by2 = {}
        for _, f in ipairs(ns.Reputation.All(o)) do by2[f.factionID] = f end
        t.eq(by2[72].group, "home")
        t.eq(by2[BOOTY].group, "unknown")
        t.eq(by2[BOOTY].reach, nil)
        t.eq(by2[BOOTY].sourcesStatus, "unavailable")
        t.eq(ns.Reputation.Gain(nil, 5), nil)
        t.eq(ns.Reputation.Gain(100, 50), -50)
    end)

    t.test("reputation tab: live, with sources outside zones, session gains and watching", function()
        local ns, fire, sent, traces = load()
        -- Stranglethorn quests 1-3 (Booty Bay), a Dire Maul quest 4 (Shen'dralar), Rogue quests
        -- 5-6 (Ravenholdt), a quest 7 outside zones without a reward.
        local quests = {
            [1] = { 33, 0, name = "B1", questLevel = 40, reputationReward = { { BOOTY, 150 } } },
            [2] = { 33, 0, name = "B2", questLevel = 40, reputationReward = { { BOOTY, 150 } } },
            [3] = { 33, 0, name = "B3", questLevel = 40, reputationReward = { { BOOTY, 150 } } },
            [4] = { 2557, 0, name = "D1", questLevel = 58, reputationReward = { { 809, 200 } } },
            [5] = { -162, 0, name = "R1", questLevel = 50, reputationReward = { { 349, 110 } } },
            [6] = { -162, 1, name = "R2", questLevel = 50, reputationReward = { { 349, 110 } } },
            [7] = { 2557, 0, name = "D2", questLevel = 58 },
        }
        local qids = { 1, 2, 3, 4, 5, 6, 7 }
        local reads = {}
        local Q = { GetAllIds = function() return qids end, Exists = function(id) return quests[id] ~= nil end,
            zoneOrSort = function(id) return quests[id][1] end, specialFlags = function(id) return quests[id][2] end }
        for _, f in ipairs({ "name", "questLevel", "reputationReward" }) do
            Q[f] = function(id) reads[f .. id] = (reads[f .. id] or 0) + 1; return quests[id] and quests[id][f] end
        end
        _G.LibQuestieDB = { contractVersion = 4, RequireContract = function() return true end, Quest = Q }
        ns.QuestAreaData = { zone = { [33] = 1434 }, dungeon = { [2557] = true } }
        _G.C_QuestLog = { GetAllCompletedQuestIDs = function() return { 1 } end }
        _G.C_Map = { GetMapInfo = function(id) return { name = "Map" .. id } end,
            GetAreaInfo = function(id) return id == 2557 and "Dire Maul" or nil end }
        _G.LOCALIZED_CLASS_NAMES_MALE = { ROGUE = "Rogue" }
        ns.character = { raceID = 1, classID = 2, classFile = "PALADIN", faction = "Alliance", level = 45 }
        local byID = { [BOOTY] = data("Booty Bay", 4, 500, 0, 3000), [72] = data("Stormwind", 5, 6600, 3000, 9000),
            [809] = data("Shen'dralar", 4, 0, 0, 3000), [349] = data("Ravenholdt", 4, 0, 0, 3000),
            [510] = data("The Defilers", 1, -42000, -42000, -6000) }
        local list = { { factionID = 469, name = "Alliance", isHeader = true, children = { { factionID = 72, name = "Stormwind" } } },
            { factionID = 5555, name = "Odd met faction" } }
        byID[5555] = data("Odd met faction", 4, 10, 0, 3000)
        local api = fakeRep(list, byID)
        local watchedWith = {}
        api.SetWatchedFactionByID = function(id) watchedWith[#watchedWith + 1] = id end
        _G.C_Reputation = api
        t.eq(ns.Reputation.List("all", "group"), nil, "nothing before Quests is ready")
        fire("AZF_READY")
        wow.runTimers()
        local index = ns.Quests.Index()
        t.eq(#index.others, 4, "quests 4-7 are outside zones")
        t.eq(#index.repOthers, 3, "three of them have a reward")
        t.eq(reads.name7, nil, "no record read for the one without a reward")
        local l = ns.Reputation.List("all", "group")
        local by = {}
        for _, f in ipairs(l.factions) do by[f.factionID] = f end
        t.ok(by[BOOTY] and by[72] and by[809] and by[349] and by[5555], "seeds, catalogue and met factions")
        t.eq(by[510], nil, "the Horde's battleground faction for an Alliance character")
        t.eq(by[809].group, "instances")
        t.eq(by[809].sources[1].name, "Dire Maul")
        t.eq(by[349].group, "other")
        t.eq(by[349].sources[1].forYou, false, "Rogue quests for a Paladin")
        t.eq(by[349].sources[1].name, "Rogue")
        t.eq(by[349].reach.gain, 0)
        t.eq(by[BOOTY].sources[1].name, "Map1434")
        t.eq(by[BOOTY].reach.gain, 300, "quest 1 done, 2 and 3 left")
        t.eq(by[BOOTY].reach.count, 2)
        t.eq(by[5555].group, "none")
        t.eq(by[72].met, true)
        t.eq(by[BOOTY].met, false)
        t.eq(l.summary.total, #l.factions)
        t.eq(l.summary.met, 2, "Stormwind and the odd one")
        t.eq(l.groups[1].key, "home")
        t.eq(ns.Reputation.Get(809).name, "Shen'dralar")
        t.eq(#ns.Reputation.List("met", "name").factions, 2)
        -- A gain this session, seen on UPDATE_FACTION.
        byID[72] = data("Stormwind", 5, 6950, 3000, 9000)
        fire("UPDATE_FACTION")
        t.eq(ns.Reputation.Get(72).gain, 350)
        -- Watching: only a met faction, through SetWatchedFactionByID; 0 stops.
        t.eq(ns.Reputation.CanWatch(ns.Reputation.Get(BOOTY)), false, "not met yet")
        t.eq(ns.Reputation.CanWatch(ns.Reputation.Get(72)), true)
        t.eq(ns.Reputation.SetWatched(72, true), true)
        byID[72].isWatched = true
        t.eq(ns.Reputation.SetWatched(72, false), true)
        t.same(watchedWith, { 72, 0 })
        t.eq(ns.Reputation.Get(72).watched, true, "re-read after the call")
        api.SetWatchedFactionByID = function() error("blocked") end
        t.same({ ns.Reputation.SetWatched(72, true) }, { false, "error" })
        api.SetWatchedFactionByID = nil
        t.same({ ns.Reputation.SetWatched(72, true) }, { false, "unsupported" })
        t.eq(ns.Reputation.CanWatch(ns.Reputation.Get(72)), false)
        _G.LibQuestieDB, _G.C_QuestLog, _G.C_Reputation, _G.C_Map, _G.LOCALIZED_CLASS_NAMES_MALE = nil, nil, nil, nil, nil
    end)

    t.test("reputation tab: without QuestieDB, standing still listed, sources unavailable", function()
        local ns, fire = load()
        _G.LibQuestieDB = nil
        ns.character = { faction = "Alliance" }
        _G.C_Reputation = fakeRep({}, { [BOOTY] = data("Booty Bay", 4, 0, 0, 3000), [72] = data("Stormwind", 5, 6600, 3000, 9000) })
        fire("AZF_READY")
        wow.runTimers()
        local l = ns.Reputation.List("all", "group")
        t.eq(l.total, 2)
        t.eq(l.sources, "unavailable")
        t.eq(l.groups[1].key, "home")
        t.eq(l.groups[2].key, "unknown")
        t.eq(ns.Reputation.ForZone(1434), nil, "no zone factions")
        _G.C_Reputation = nil
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
