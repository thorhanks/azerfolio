-- Quest catalogue and tracker (Phase 9 steps 2-3): which quests belong to which zone, read at
-- runtime from QuestieDB, an optional dependency (decision 2026-11-08,
-- docs/research/quest-data.md), with this character's completion and eligibility.
--
-- Build, once per session, in batches across frames:
--   1. index: each quest's zoneOrSort, specialFlags and questFlags, sorted into zones with
--      Data/QuestAreas.lua (curated, unofficial). Left out of zone counts, each counted by
--      reason for the coverage note: repeatable, quest sorts (class, profession, holiday...),
--      no zone, battleground, unmapped areas, read errors. Dungeon and raid quests aren't in
--      zone counts either; they're kept per instance for a Dungeons tab later.
--   2. details: the fields eligibility needs, for every quest in a zone (Quests.ReadDetails).
-- Completion comes from the client's completed-quest list (C_QuestLog.GetAllCompletedQuestIDs
-- [verified-ingame]), re-read after QUEST_TURNED_IN [verified-ingame, sniffer]. Eligibility is
-- ns.QuestRules; counts come from ns.Progression. The UI shows what this returns.
-- Without QuestieDB, or with a contract it doesn't support, quests are "unavailable" with the
-- reason, never zero. Exploration never depends on this.
-- Everything above "Live" is pure, so tests can load it without the client.
local _, ns = ...

local Quests = {}
ns.Quests = Quests

Quests.CATEGORY = "quests"
Quests.CONTRACT = 4      -- QuestieDB contract this was written against [verified-ingame]
Quests.BATCH = 500       -- index pass: quests per frame (3 reads each; 8.6 ms for 5,233 in game)
Quests.DETAIL_BATCH = 50 -- details pass: quests per frame (20 reads each; 100 gave one 15.7 ms frame)
Quests.DETAIL_READS = 20 -- reads in one full record (the others pass budgets by reads)
Quests.START_DELAY = 5   -- seconds after AZF_READY: after the exploration baseline (3 s)
Quests.REFRESH_DELAY = 1 -- after QUEST_TURNED_IN, so the completed list has the quest [unverified]

-- Reasons a quest isn't in a zone count. "dungeon" and "raid" are kept per instance.
-- "notcounted" quests (Data/QuestAreas.lua notCountedQuests) stay on their zone's page, uncounted.
Quests.REASONS = { "repeatable", "sort", "nozone", "dungeon", "raid", "battleground", "unmapped", "excluded",
    "notcounted", "error" }

-- Why a notCountedQuests quest isn't counted: reason key -> { label (the list's header, plural),
-- detail (its tooltip) }.
Quests.NOT_COUNTED = {
    riding = { label = "riding quests", detail = "Learning to ride, at level 40: a step for your character, not the zone. Never counted." },
}

local function rules() return ns.QuestRules end

---------------------------------------------------------------------------------------------
-- Pure
---------------------------------------------------------------------------------------------

-- Pure: is QuestieDB usable? lib = the LibQuestieDB global (or nil).
-- Returns true, or false and a reason for the coverage note.
function Quests.Detect(lib)
    if type(lib) ~= "table" then return false, "QuestieDB is not loaded" end
    if type(lib.RequireContract) ~= "function" then return false, "QuestieDB has no contract check" end
    local ok, fine, message = pcall(lib.RequireContract, Quests.CONTRACT)
    if not ok then return false, "QuestieDB contract check failed: " .. tostring(fine) end
    if not fine then
        return false, "QuestieDB contract " .. tostring(lib.contractVersion) .. " doesn't support "
            .. Quests.CONTRACT .. (message and (": " .. tostring(message)) or "")
    end
    local Q = lib.Quest
    if type(Q) ~= "table" or type(Q.GetAllIds) ~= "function" or type(Q.zoneOrSort) ~= "function"
        or type(Q.specialFlags) ~= "function" then
        return false, "QuestieDB has no quest readers"
    end
    return true
end

-- Pure: specialFlags bit 1, or a daily/weekly/monthly questFlags bit [verified-files].
function Quests.IsRepeatable(flags, questFlags) return rules().IsRepeatable(flags, questFlags) end

-- Pure: where a quest's zoneOrSort puts it. Returns kind, key:
--   "zone", mapID | "dungeon", areaID | "raid", areaID | "battleground", areaID
--   "sort", sortID (negative) | "nozone", nil | "unmapped", areaID
function Quests.Place(zoneOrSort, areas)
    local v = zoneOrSort
    if type(v) ~= "number" or v == 0 then return "nozone", nil end
    if v < 0 then return "sort", v end
    areas = areas or {}
    local map = areas.zone and areas.zone[v]
    if map then return "zone", map end
    if areas.dungeon and areas.dungeon[v] then return "dungeon", v end
    if areas.raid and areas.raid[v] then return "raid", v end
    if areas.battleground and areas.battleground[v] then return "battleground", v end
    return "unmapped", v
end

-- Pure: an empty index.
--   zones[mapID] = { ids = {questID...}, repeatable = n, repeats = {questID...},
--                    extras = { { id, why } } }
--                  counted quests, the zone's repeatables left out (count for its note,
--                  IDs for Reputation: repeatables raise factions too), and its not-counted
--                  quests (Data/QuestAreas.lua notCountedQuests), shown but never counted
--   instances[areaID] = { kind = "dungeon"|"raid", ids }  kept for a Dungeons tab later
--   left[reason] = n          quests left out of zone counts, by reason (Quests.REASONS)
--   unmapped[areaID] = n      quests per unmapped area; sorts[sortID] = n
--   others = { { id, kind, key, repeatable } }  every quest outside a zone (Quests.Place kind
--                  and key), for the Reputation tab's sources; repOthers = the ones with a
--                  reputation reward (filled by the builder's last pass)
--   total = quests seen, counted = quests in a zone
function Quests.NewIndex()
    local left = {}
    for _, r in ipairs(Quests.REASONS) do left[r] = 0 end
    return { zones = {}, instances = {}, left = left, unmapped = {}, sorts = {}, others = {}, repOthers = {},
        total = 0, counted = 0 }
end

local function zoneOf(index, mapID)
    local z = index.zones[mapID]
    if not z then z = { ids = {}, repeatable = 0, repeats = {}, extras = {} }; index.zones[mapID] = z end
    return z
end

-- Pure: adds one quest. ok = false when its fields couldn't be read (counted as "error").
function Quests.Add(index, id, zoneOrSort, specialFlags, areas, ok, questFlags)
    index.total = index.total + 1
    local left = index.left
    if ok == false then
        left.error = left.error + 1
        return "error"
    end
    -- Quests the curated data rules out (can't be obtained in this client): left out.
    if areas and areas.excludedQuests and areas.excludedQuests[id] then
        left.excluded = left.excluded + 1
        return "excluded"
    end
    local kind, key = Quests.Place(zoneOrSort, areas)
    -- Quests the curated data keeps out of zone counts but on the zone's page (riding).
    local why = areas and areas.notCountedQuests and areas.notCountedQuests[id]
    if why then
        left.notcounted = left.notcounted + 1
        if kind == "zone" then
            local z = zoneOf(index, key)
            z.extras[#z.extras + 1] = { id = id, why = why }
        else
            index.others[#index.others + 1] = { id = id, kind = kind, key = key }
        end
        return "notcounted"
    end
    if Quests.IsRepeatable(specialFlags, questFlags) then
        left.repeatable = left.repeatable + 1
        if kind == "zone" then
            local z = zoneOf(index, key)
            z.repeatable = z.repeatable + 1
            z.repeats[#z.repeats + 1] = id
        else
            index.others[#index.others + 1] = { id = id, kind = kind, key = key, repeatable = true }
        end
        return "repeatable"
    end
    if kind ~= "zone" then index.others[#index.others + 1] = { id = id, kind = kind, key = key } end
    if kind == "zone" then
        local z = zoneOf(index, key)
        z.ids[#z.ids + 1] = id
        index.counted = index.counted + 1
        return kind
    end
    left[kind] = left[kind] + 1
    if kind == "dungeon" or kind == "raid" then
        local inst = index.instances[key]
        if not inst then inst = { kind = kind, ids = {} }; index.instances[key] = inst end
        inst.ids[#inst.ids + 1] = id
    elseif kind == "unmapped" then
        index.unmapped[key] = (index.unmapped[key] or 0) + 1
    elseif kind == "sort" then
        index.sorts[key] = (index.sorts[key] or 0) + 1
    end
    return kind
end

-- Fields read for eligibility and the checklist: record key -> QuestieDB reader.
Quests.DETAIL_FIELDS = {
    name = "name", level = "questLevel", reqLevel = "requiredLevel", maxLevel = "requiredMaxLevel",
    races = "requiredRaces", classes = "requiredClasses", preGroup = "preQuestGroup",
    preSingle = "preQuestSingle", exclusive = "exclusiveTo", next = "nextQuestInChain",
    parent = "parentQuest", breadcrumbFor = "breadcrumbForQuestId",
    untilCompleted = "availableUntilCompleted", startingWith = "availableStartingWith",
    rep = "reputationReward", -- {{factionID, amount}...}, base values (Systems/Reputation) [verified-files, Types/Quest.t.lua]
}
-- Requirements not checked yet: any of these makes the quest's eligibility unknown.
Quests.NEEDS_FIELDS = {
    { "requiredSkill", "profession" }, { "requiredRanks", "profession" },
    { "requiredSpecialization", "profession" }, { "requiredMinRep", "reputation" },
    { "requiredMaxRep", "reputation" }, { "requiredSpell", "spell" },
}

local function present(v)
    if v == nil or v == false or v == 0 then return false end
    if type(v) == "table" then return next(v) ~= nil end
    return true
end

-- Pure: one quest's record from the reader table Q. Readers the API doesn't have are skipped.
-- Only fields with a value are kept (memory). err = true when a read failed.
--   { name, level, reqLevel, maxLevel, races, classes, preGroup, preSingle, exclusive, next,
--     parent, breadcrumbFor, untilCompleted, startingWith, needs = "profession"|... , err }
function Quests.ReadDetails(Q, id)
    local r = {}
    for key, field in pairs(Quests.DETAIL_FIELDS) do
        local reader = Q[field]
        if type(reader) == "function" then
            local ok, v = pcall(reader, id)
            if not ok then r.err = true
            elseif present(v) then r[key] = v end
        end
    end
    for _, n in ipairs(Quests.NEEDS_FIELDS) do
        local reader = Q[n[1]]
        if type(reader) == "function" and not r.needs then
            local ok, v = pcall(reader, id)
            if not ok then r.err = true
            elseif present(v) then r.needs = n[2] end
        end
    end
    return r
end

-- Pure: a builder that reads `ids` through the reader table Q (QuestieDB's Quest API) in
-- steps: the index first, then details for every quest in a zone (repeatables too, for their
-- reputation rewards), then the reputation reward of every quest outside a zone (details for
-- those that have one: the Reputation tab's sources). builder.Step(n, d) reads up
-- to n quests in the index pass or d in the details pass (defaults BATCH, DETAIL_BATCH) and
-- returns true when both passes are done. Every read is pcall'd; a quest whose index read fails counts as "error".
function Quests.Builder(Q, ids, areas)
    local index, pos = Quests.NewIndex(), 0
    local details, todo, dpos, opos = {}, nil, 0, 0
    local b = { index = index, details = details, steps = 0, phase = "index" }
    local qf = type(Q.questFlags) == "function" and Q.questFlags or nil
    function b.Step(n, d)
        b.steps = b.steps + 1
        if b.phase == "index" then
            local last = math.min(#ids, pos + (n or Quests.BATCH))
            for i = pos + 1, last do
                local id = ids[i]
                local ok1, zs = pcall(Q.zoneOrSort, id)
                local ok2, flags = pcall(Q.specialFlags, id)
                local ok3, qflags = true, nil
                if qf then ok3, qflags = pcall(qf, id) end
                Quests.Add(index, id, ok1 and zs or nil, ok2 and flags or nil, areas, ok1 and ok2 and ok3,
                    ok3 and qflags or nil)
            end
            pos = last
            if pos >= #ids then
                todo = {}
                for _, z in pairs(index.zones) do
                    for _, id in ipairs(z.ids) do todo[#todo + 1] = id end
                    for _, id in ipairs(z.repeats) do todo[#todo + 1] = id end
                    for _, e in ipairs(z.extras) do todo[#todo + 1] = e.id end
                end
                table.sort(todo)
                b.phase = "details"
            end
            return false
        end
        if b.phase == "details" then
            local last = math.min(#todo, dpos + math.max(1, d or Quests.DETAIL_BATCH))
            for i = dpos + 1, last do
                details[todo[i]] = Quests.ReadDetails(Q, todo[i])
            end
            dpos = last
            if dpos < #todo then return false end
            b.phase = "others" -- and start it in this step
        end
        -- Quests outside zones: one read for the reputation reward; the full record only for
        -- the few that have one. Budget in reads per step (a full record is about 20).
        local others, rr = index.others, Q.reputationReward
        if type(rr) ~= "function" then b.phase = "done"; return true end
        local budget = math.max(1, d or Quests.DETAIL_BATCH) * Quests.DETAIL_READS
        while opos < #others and budget > 0 do
            opos = opos + 1
            local o = others[opos]
            local ok, rep = pcall(rr, o.id)
            budget = budget - 1
            if ok and type(rep) == "table" and next(rep) ~= nil then
                details[o.id] = details[o.id] or Quests.ReadDetails(Q, o.id)
                index.repOthers[#index.repOthers + 1] = o
                budget = budget - Quests.DETAIL_READS
            end
        end
        if opos >= #others then b.phase = "done"; return true end
        return false
    end
    function b.Progress()
        if b.phase == "index" then return pos, #ids, "index" end
        if b.phase == "others" or b.phase == "done" then return opos, #index.others, b.phase end
        return dpos, todo and #todo or 0, b.phase
    end
    return b
end

-- Pure: the quest difficulty colour name for a quest level and the player's level, the
-- client's rule (QuestDifficultyColors): red 5+ above, orange 3-4 above, yellow within 2,
-- green down to greenRange below, grey under that. greenRange comes from the client's
-- GetQuestGreenRange() when it has one; the fallback is the classic table [unverified].
function Quests.GreenRange(level)
    if type(level) ~= "number" then return 5 end
    if level <= 5 then return 5 end
    if level <= 39 then return math.floor(level / 10) + 5 end
    if level <= 59 then return math.floor(level / 5) + 1 end
    return 12
end
function Quests.Difficulty(questLevel, level, greenRange)
    if type(questLevel) ~= "number" or type(level) ~= "number" then return nil end
    local d = questLevel - level
    if d >= 5 then return "red" end
    if d >= 3 then return "orange" end
    if d >= -2 then return "yellow" end
    if -d <= (greenRange or Quests.GreenRange(level)) then return "green" end
    return "grey"
end

local function idList(v)
    if type(v) == "table" then return v end
    if type(v) == "number" and v > 0 then return { v } end
    return {}
end

-- Pure: what the checklist shows for one quest (spec §7.3): ready (can take now), locked,
-- unknown (eligibility not known), done, unavailable, or open (eligible, completion unknown).
function Quests.KindOf(o)
    if o.eligibility == "unavailable" then return "unavailable" end
    if o.eligibility == "unknown" then return "unknown" end
    if o.completion == "complete" then return "done" end
    if o.eligibility == "locked" then return "locked" end
    if o.completion == "incomplete" then return "ready" end
    return "open"
end

-- Pure: Ready now, storylines and single quests from a zone's objectives (Evaluate fills
-- o.kind). Storylines are quests joined by prerequisite or next-quest links (QuestieDB
-- preQuestGroup / preQuestSingle / availableStartingWith / nextQuestInChain) within the zone;
-- columns follow chain depth, so branches stack. info(id) -> the quest's detail record.
--   { ready, stories (unfinished: those with a ready quest first, then by level), finished,
--     singles (ready, locked, unknown, open, unavailable, done; then by level) }
function Quests.Shape(objectives, info)
    local byId, pre, parent = {}, {}, {}
    for _, o in ipairs(objectives) do byId[o.id] = o end
    local function root(x)
        while parent[x] ~= nil and parent[x] ~= x do x = parent[x] end
        return x
    end
    local function link(a, b) -- a must come before b
        if not (byId[a] and byId[b]) or a == b then return end
        pre[b] = pre[b] or {}
        for _, x in ipairs(pre[b]) do if x == a then return end end
        table.insert(pre[b], a)
        local ra, rb = root(a), root(b)
        if ra ~= rb then parent[ra] = rb end
    end
    for _, o in ipairs(objectives) do
        local r = info(o.id)
        if r then
            for _, p in ipairs(idList(r.preGroup)) do link(p, o.id) end
            for _, p in ipairs(idList(r.preSingle)) do link(p, o.id) end
            for _, p in ipairs(idList(r.startingWith)) do link(p, o.id) end
            for _, n in ipairs(idList(r.next)) do link(o.id, n) end
        end
    end
    local memo, visiting = {}, {}
    local function depth(id)
        if memo[id] then return memo[id] end
        if visiting[id] then return 0 end -- a loop in the data: break it
        visiting[id] = true
        local d = 0
        for _, p in ipairs(pre[id] or {}) do d = math.max(d, depth(p) + 1) end
        visiting[id] = nil
        memo[id] = d
        return d
    end
    local function byLevel(a, b)
        local la, lb = a.questLevel or 0, b.questLevel or 0
        if la ~= lb then return la < lb end
        local na, nb = tostring(a.name), tostring(b.name)
        if na ~= nb then return na < nb end
        return a.id < b.id
    end
    local comps, order = {}, {}
    for _, o in ipairs(objectives) do
        local r = root(o.id)
        if not comps[r] then comps[r] = {}; order[#order + 1] = r end
        table.insert(comps[r], o)
    end
    local stories, singles = {}, {}
    for _, key in ipairs(order) do
        local list = comps[key]
        if #list < 2 then
            singles[#singles + 1] = list[1]
        else
            local cols = {}
            for _, o in ipairs(list) do
                local d = depth(o.id) + 1
                cols[d] = cols[d] or {}
                table.insert(cols[d], o)
            end
            local columns = {}
            for d = 1, table.maxn(cols) do if cols[d] then table.sort(cols[d], byLevel); columns[#columns + 1] = cols[d] end end
            local done, total, ready, level = 0, 0, 0, nil
            for _, o in ipairs(list) do
                if o.eligibility == "eligible" or o.eligibility == "locked" then
                    total = total + 1
                    if o.completion == "complete" then done = done + 1 end
                end
                if o.kind == "ready" then ready = ready + 1 end
                if o.kind ~= "done" and o.questLevel and (not level or o.questLevel < level) then level = o.questLevel end
            end
            local first = columns[1][1]
            stories[#stories + 1] = { id = first.id, name = first.name, columns = columns, size = #list, done = done,
                total = total, ready = ready, finished = total > 0 and done == total, level = level or 99 }
        end
    end
    local active, finished = {}, {}
    for _, s in ipairs(stories) do table.insert(s.finished and finished or active, s) end
    table.sort(active, function(a, b)
        if (a.ready > 0) ~= (b.ready > 0) then return a.ready > 0 end
        if a.level ~= b.level then return a.level < b.level end
        if tostring(a.name) ~= tostring(b.name) then return tostring(a.name) < tostring(b.name) end
        return a.id < b.id
    end)
    table.sort(finished, function(a, b)
        if tostring(a.name) ~= tostring(b.name) then return tostring(a.name) < tostring(b.name) end
        return a.id < b.id
    end)
    local rank = { ready = 1, locked = 2, unknown = 3, open = 4, unavailable = 5, done = 6 }
    table.sort(singles, function(a, b)
        if rank[a.kind] ~= rank[b.kind] then return rank[a.kind] < rank[b.kind] end
        return byLevel(a, b)
    end)
    -- Ready now leaves out quests red for you (Phase 15 step 5, Next up's rule since step 1):
    -- Stormwind's library books (level 20-45, no level requirement) filled it for a level-10
    -- character. They are readyRed, shown after it.
    local ready, readyRed = {}, {}
    for _, o in ipairs(objectives) do
        if o.kind == "ready" then
            if o.difficulty == "red" then readyRed[#readyRed + 1] = o else ready[#ready + 1] = o end
        end
    end
    table.sort(ready, byLevel); table.sort(readyRed, byLevel)
    return { ready = ready, readyRed = readyRed, stories = active, finished = finished, singles = singles }
end

-- Pure: a zone's quest objectives and progress for one character.
--   ctx: QuestRules.Context; ids: the zone's quest IDs; mapID; repeatable: left out count.
--   { status = "ready", mapID, objectives, progress, count, repeatable, reasons = { [reason] = n } }
-- objectives: ns.Objectives (category "quests", id = questID) plus questLevel, reqLevel, reason.
-- The set's coverage is "complete" when every quest was read without error; QuestieDB is the
-- catalogue (the coverage note says so and lists what's left out).
-- One quest as an objective, with its state for the page (kind, difficulty, what it needs).
local function questObjective(ctx, mapID, id)
    local O, R = ns.Objectives, rules()
    local info = ctx.info(id)
    local elig, why = R.Evaluate(ctx, id)
    local o = O.New({ id = id, category = Quests.CATEGORY, zone = mapID, name = info and info.name,
        completion = R.Completion(ctx.completed, id), eligibility = elig, source = "questiedb" })
    o.questLevel, o.reqLevel, o.reason = info and info.level, info and info.reqLevel, why
    o.kind = Quests.KindOf(o)
    o.difficulty = Quests.Difficulty(o.questLevel, ctx.char and ctx.char.level, ctx.greenRange)
    -- A quest locked behind others names the ones still to do (any zone), when known.
    if why == "prerequisite" and info then
        local names = {}
        local function add(p)
            if not (ctx.completed and ctx.completed[p]) then
                local r = ctx.info(p)
                if r and r.name then names[#names + 1] = r.name end
            end
        end
        for _, p in ipairs(idList(info.preGroup)) do add(p) end
        for _, p in ipairs(idList(info.preSingle)) do add(p) end
        for _, p in ipairs(idList(info.startingWith)) do add(p) end
        if #names > 0 then o.prereqs = names; o.prereqAny = info.preSingle ~= nil and info.preGroup == nil end
    end
    return o, info, why
end

-- extras = the zone's not-counted quests ({ { id, why } }, Quests.Add): returned as
-- notCounted objectives (o.notCounted = why), by level, never in progress or the shape.
function Quests.Evaluate(ctx, mapID, ids, repeatable, extras)
    local objectives, reasons, coverage = {}, {}, "complete"
    for _, id in ipairs(ids or {}) do
        local o, info, why = questObjective(ctx, mapID, id)
        if not info or info.err then coverage = "partial" end
        objectives[#objectives + 1] = o
        if why then reasons[why] = (reasons[why] or 0) + 1 end
    end
    local notCounted = {}
    for _, e in ipairs(extras or {}) do
        local o = questObjective(ctx, mapID, e.id)
        o.notCounted = e.why
        notCounted[#notCounted + 1] = o
    end
    table.sort(notCounted, function(a, b)
        local la, lb = a.questLevel or 0, b.questLevel or 0
        if la ~= lb then return la < lb end
        return (a.name or "") < (b.name or "")
    end)
    local progress = ns.Progression.Aggregate({ { category = Quests.CATEGORY, coverage = coverage, objectives = objectives } })
    local unknownReasons = {}
    for _, o in ipairs(objectives) do
        if o.eligibility == "unknown" and o.reason then unknownReasons[o.reason] = (unknownReasons[o.reason] or 0) + 1 end
    end
    local shape = Quests.Shape(objectives, ctx.info)
    return { status = "ready", mapID = mapID, objectives = objectives, progress = progress,
        count = #objectives, repeatable = repeatable or 0, reasons = reasons, unknownReasons = unknownReasons,
        coverage = coverage, ready = shape.ready, readyRed = shape.readyRed, stories = shape.stories, finished = shape.finished,
        singles = shape.singles, notCounted = notCounted }
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

-- state.status: "idle" (not started), "building", "ready", "unavailable" (with reason)
local state = { status = "idle" }
local completed      -- { [questID] = true }, or nil when the client gives no list
local ctx            -- QuestRules context for the current character and completed list
local results = {}   -- [mapID] = Evaluate result (cleared on turn-in, level change, refresh)
local lib            -- LibQuestieDB, once detected

local function clock() return type(debugprofilestop) == "function" and debugprofilestop() or nil end
local function round(ms) return ms and math.floor(ms * 100 + 0.5) / 100 or nil end
local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

function Quests.State() return state end

-- The client's completed quests as a set, or nil when it can't say.
function Quests.ReadCompleted()
    if C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs) == "function" then
        local list = try("GetAllCompletedQuestIDs", C_QuestLog.GetAllCompletedQuestIDs)
        if type(list) == "table" then
            local s = {}
            for _, id in ipairs(list) do s[id] = true end
            return s, #list
        end
    end
    return nil
end

local function character()
    local c = ns.character or {}
    return { raceID = c.raceID, classID = c.classID, level = c.level }
end

-- Record for a quest: from the details pass, or read now (prerequisites outside any zone).
local function info(id)
    local d = state.details
    if not d then return nil end
    local r = d[id]
    if r == nil then
        local Q = lib and lib.Quest
        local exists = Q and type(Q.Exists) == "function" and try("QuestDB.Exists", Q.Exists, id)
        r = exists and Quests.ReadDetails(Q, id) or false
        d[id] = r
    end
    return r or nil
end

local function context()
    if not ctx then
        ctx = ns.QuestRules.Context(info, completed, character())
        -- The client's green range for quest colours, when it has the function [unverified].
        if type(GetQuestGreenRange) == "function" then
            local ok, g = pcall(GetQuestGreenRange)
            if ok and type(g) == "number" then ctx.greenRange = g end
        end
    end
    return ctx
end

-- Forget per-character results (completion, level or character changed).
function Quests.Invalidate()
    ctx, results = nil, {}
end

local function finish(b, started, maxStep)
    local ms = started and clock() and (clock() - started) or nil
    completed = Quests.ReadCompleted()
    Quests.Invalidate()
    state = { status = "ready", index = b.index, details = b.details, steps = b.steps,
        maxStepMs = round(maxStep), workMs = round(b.workMs), elapsedMs = round(ms) }
    local i = b.index
    ns.Debug.Trace("quests", { status = "ready", total = i.total, counted = i.counted, left = i.left,
        others = #i.others, repOthers = #i.repOthers,
        steps = b.steps, workMs = state.workMs, maxStepMs = state.maxStepMs, completedKnown = completed ~= nil })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

local function unavailable(reason)
    state = { status = "unavailable", reason = reason }
    ns.Debug.Trace("quests", { status = "unavailable", reason = reason })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

-- Starts the one-time build (no-op once started). The index and details are the same for
-- every character; eligibility is evaluated per character on demand.
function Quests.Start()
    if state.status ~= "idle" then return end
    local L = rawget(_G, "LibQuestieDB")
    local ok, reason = Quests.Detect(L)
    if not ok then return unavailable(reason) end
    lib = L
    local got, ids = pcall(lib.Quest.GetAllIds)
    if not got or type(ids) ~= "table" then
        return unavailable("QuestieDB's quest list couldn't be read")
    end
    local b = Quests.Builder(lib.Quest, ids, ns.QuestAreaData)
    b.workMs = 0
    state = { status = "building", builder = b }
    local started, maxStep = clock(), 0
    local function step()
        local t0 = clock()
        local ran, done = pcall(b.Step, Quests.BATCH, Quests.DETAIL_BATCH)
        if t0 and clock() then
            local d = clock() - t0
            b.workMs = b.workMs + d
            if d > maxStep then maxStep = d end
        end
        if not ran then
            ns.Debug.Error("quests build", done)
            return unavailable("reading QuestieDB failed")
        end
        if done then return finish(b, started, maxStep) end
        C_Timer.After(0, step)
    end
    C_Timer.After(0, step)
end

-- A zone's quests (a mapID or { mapID }) for this character:
--   { status = "ready", mapID, objectives, progress, count, repeatable, reasons }  (see Evaluate;
--     count 0 = QuestieDB has none there)
--   { status = "building"|"unavailable"|"idle", reason }   no counts
function Quests.ForZone(zone)
    local mapID = type(zone) == "table" and zone.mapID or zone
    if state.status ~= "ready" then return { status = state.status, reason = state.reason } end
    local r = results[mapID]
    if r then return r end
    local z = state.index.zones[mapID]
    r = Quests.Evaluate(context(), mapID, z and z.ids or {}, z and z.repeatable or 0, z and z.extras)
    results[mapID] = r
    return r
end

-- For other systems (Reputation): the built index (nil until ready), a quest's record (from
-- the details pass, or read now), and the eligibility context for this character.
function Quests.Index() return state.status == "ready" and state.index or nil end

-- Debug (/azf debug reputation): where one quest stands in QuestieDB's composed view (in-game
-- corrections applied) and in the index. Every read pcall'd; nil before QuestieDB is detected.
--   { exists, zoneOrSort, specialFlags, questFlags, place = "zone 1444"|..., repeatable,
--     indexed = mapID (counted) | "repeat mapID", rep = { {factionID, amount}... }, name, level }
function Quests.Probe(id)
    local Q = lib and lib.Quest
    if type(Q) ~= "table" then return nil end
    local function read(field)
        local f = Q[field]
        if type(f) ~= "function" then return nil end
        local ok, v = pcall(f, id)
        return ok and v or nil
    end
    local p = { zoneOrSort = read("zoneOrSort"), specialFlags = read("specialFlags"), questFlags = read("questFlags"),
        rep = read("reputationReward"), name = read("name"), level = read("questLevel") }
    if type(Q.Exists) == "function" then
        local ok, v = pcall(Q.Exists, id)
        p.exists = ok and v and true or false
    end
    local kind, key = Quests.Place(p.zoneOrSort, ns.QuestAreaData)
    p.place = kind .. (key and (" " .. tostring(key)) or "")
    p.repeatable = Quests.IsRepeatable(p.specialFlags, p.questFlags) and true or false
    local areas = ns.QuestAreaData
    p.excluded = areas and areas.excludedQuests and areas.excludedQuests[id] and true or nil
    local index = state.index
    for mapID, z in pairs(index and index.zones or {}) do
        for _, q in ipairs(z.ids) do if q == id then p.indexed = mapID end end
        for _, q in ipairs(z.repeats or {}) do if q == id then p.indexed = "repeat " .. mapID end end
        for _, e in ipairs(z.extras or {}) do if e.id == id then p.indexed = "not counted " .. mapID end end
    end
    return p
end
function Quests.Info(id) return info(id) end

-- Where a quest starts (the Class tab's "Where it starts"), from QuestieDB's startedBy
-- ({ npcIDs?, objectIDs?, itemIDs? }, contract 4 [verified-files, src/meta/questMeta.lua]) and the
-- starter's name and zone (Npc / Object / Item entities, zoneID an AreaTable ID).
--   { kind = "npc"|"object"|"item", name, place, mapID }   nil fields when not known (mapID: the
--   zone map of the starter's area per Data/QuestAreas)
-- nil when QuestieDB has no starter for it (or isn't loaded). Cached per quest.
-- Each race's home zone maps (its capital and its starting zone), by the client's race file
-- token: the Class tab names a giver there first (Phase 15 step 5). Races not listed (Forever's
-- newer ones) have no home preference.
Quests.RACE_HOME = {
    Human = { 1453, 1429 }, Dwarf = { 1455, 1426 }, Gnome = { 1455, 1426 }, NightElf = { 1457, 1438 },
    Orc = { 1454, 1411 }, Troll = { 1454, 1411 }, Scourge = { 1458, 1420 }, Tauren = { 1456, 1412 },
}

-- Pure (Phase 15 step 5): which of a quest's starting NPCs to name. QuestieDB lists every NPC
-- that gives the quest, from both sides (Torwa Pathfinder: Darnassus and Thunder Bluff); the
-- first was named before. Order: friendly to your side ("A", "H", "AH"; unknown counts as
-- friendly), in your home (home = { [mapID] = true }), then QuestieDB's order.
--   ids = NPC IDs; side = "A" | "H" | nil; friendOf(id) -> "A"|"H"|"AH"|nil; zoneOf(id) -> mapID|nil
function Quests.PickStarter(ids, side, home, friendOf, zoneOf)
    local best, bestScore
    for i, id in ipairs(ids or {}) do
        local f = friendOf and friendOf(id)
        local friendly = not side or type(f) ~= "string" or f:find(side, 1, true) ~= nil
        local z = zoneOf and zoneOf(id)
        local score = (friendly and 2 or 0) + ((friendly and home and z and home[z]) and 1 or 0)
        if not bestScore or score > bestScore then best, bestScore = id, score end
        if i > 12 then break end -- long lists (a class quest from every trainer): enough
    end
    return best
end

-- Pure (Phase 15 step 5, R12): what a quest asks, from QuestieDB's objectivesText (a list of
-- strings; contract per Types/Quest.t.lua [verified-files]): the first sentence of the first
-- entry with text, without its closing full stop. nil when there's none.
function Quests.ObjectiveText(v)
    local s = v
    if type(v) == "table" then
        s = nil
        for _, x in ipairs(v) do
            if type(x) == "string" and x:find("%S") then s = x; break end
        end
    end
    if type(s) ~= "string" then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local cut = s:find("[%.!%?]%s")
    if cut then s = s:sub(1, cut) end
    s = s:gsub("%.$", "")
    return s ~= "" and s or nil
end

-- What a quest asks (Quests.ObjectiveText of QuestieDB's composed view), cached; nil when it has
-- none or QuestieDB isn't loaded.
local objectives = {}
function Quests.Objective(id)
    if objectives[id] ~= nil then return objectives[id] or nil end
    local Q = lib and lib.Quest
    if type(Q) ~= "table" or type(Q.objectivesText) ~= "function" then return nil end
    local ok, v = pcall(Q.objectivesText, id)
    objectives[id] = ok and Quests.ObjectiveText(v) or false
    return objectives[id] or nil
end

local starters = {}
function Quests.Starter(id)
    if starters[id] ~= nil then return starters[id] or nil end
    local Q = lib and lib.Quest
    if type(Q) ~= "table" or type(Q.startedBy) ~= "function" then return nil end
    local function read(entity, field, key)
        local E = lib[entity]
        local f = type(E) == "table" and E[field]
        if type(f) ~= "function" then return nil end
        local ok, v = pcall(f, key)
        return ok and v or nil
    end
    local zones = ns.QuestAreaData and ns.QuestAreaData.zone
    local function zoneOf(entity, key)
        local area = read(entity, "zoneID", key)
        return type(area) == "number" and zones and zones[area] or nil
    end
    local function areaName(areaID)
        if type(areaID) ~= "number" or not (C_Map and type(C_Map.GetAreaInfo) == "function") then return nil end
        local ok, name = pcall(C_Map.GetAreaInfo, areaID)
        return ok and type(name) == "string" and name ~= "" and name or nil
    end
    local ok, sb = pcall(Q.startedBy, id)
    local r = false
    if ok and type(sb) == "table" then
        for i, kind in ipairs({ "npc", "object", "item" }) do
            local list = sb[i]
            local first = type(list) == "table" and list[1]
            if kind == "npc" and type(first) == "number" and #list > 1 then
                local c = ns.character or {}
                local side = c.faction == "Alliance" and "A" or c.faction == "Horde" and "H" or nil
                local home
                for _, m in ipairs(Quests.RACE_HOME[c.raceFile] or {}) do home = home or {}; home[m] = true end
                first = Quests.PickStarter(list, side, home,
                    function(n) return read("Npc", "friendlyToFaction", n) end,
                    function(n) return zoneOf("Npc", n) end) or first
            end
            if type(first) == "number" then
                local entity = ({ npc = "Npc", object = "Object", item = "Item" })[kind]
                local name = read(entity, "name", first)
                r = { kind = kind, name = type(name) == "string" and name or nil }
                if kind ~= "item" then
                    local area = read(entity, "zoneID", first)
                    r.place = areaName(area)
                    -- The zone it's in (Data/QuestAreas: the area's zone map), for the zone's art.
                    local zones = ns.QuestAreaData and ns.QuestAreaData.zone
                    r.mapID = type(area) == "number" and zones and zones[area] or nil
                end
                break
            end
        end
    end
    starters[id] = r
    return r or nil
end
function Quests.Context() return state.status == "ready" and context() or nil end

-- Every zone together: { status, progress, zones = zones with quests, left = index.left }.
function Quests.Overall()
    if state.status ~= "ready" then return { status = state.status, reason = state.reason } end
    local sets, zones = {}, 0
    for mapID in pairs(state.index.zones) do
        local r = Quests.ForZone(mapID)
        if r.count > 0 then
            zones = zones + 1
            sets[#sets + 1] = { category = Quests.CATEGORY, coverage = r.coverage, objectives = r.objectives }
        end
    end
    return { status = "ready", progress = ns.Progression.Aggregate(sets), zones = zones, left = state.index.left }
end

-- Re-read the completed list (after a turn-in or /azf refresh). Announces a change.
local function refreshCompleted(reason)
    if state.status ~= "ready" then return end
    local before = completed
    local n
    completed, n = Quests.ReadCompleted()
    local added = 0
    if completed and before then
        for id in pairs(completed) do if not before[id] then added = added + 1 end end
    end
    Quests.Invalidate()
    ns.Debug.Trace("quests", { refresh = reason, completed = n, added = added })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

ns.Events.On("AZF_READY", function()
    ns.Events.Debounce("quests-build", Quests.START_DELAY, Quests.Start)
end)
ns.Events.Register("QUEST_TURNED_IN", function()
    ns.Events.Debounce("quests-completed", Quests.REFRESH_DELAY, function() refreshCompleted("QUEST_TURNED_IN") end)
end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() refreshCompleted("refresh") end)
ns.Events.On("AZF_LEVEL_CHANGED", function()
    if state.status ~= "ready" then return end
    Quests.Invalidate()
    ns.Events.Send("AZF_QUESTS_UPDATED")
end)

local function top(t, n)
    local list = {}
    for k, v in pairs(t) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return tostring(a.k) < tostring(b.k) end)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = string.format("%s %d", tostring(list[i].k), list[i].v) end
    return out
end

-- Pure: "level 12", "level 30"... as one "level" bucket (the report stays short).
function Quests.GroupReasons(reasons)
    local out = {}
    for why, n in pairs(reasons or {}) do
        local k = tostring(why):match("^level %d+$") and "level" or why
        out[k] = (out[k] or 0) + n
    end
    return out
end

local function checklist(r)
    local out = {}
    for _, o in ipairs(r.objectives or {}) do
        out[#out + 1] = string.format("%d %s L%s/%s %s %s %s", o.id, tostring(o.name),
            tostring(o.questLevel), tostring(o.reqLevel), o.completion, o.eligibility, tostring(o.reason or ""))
    end
    return out
end

-- /azf debug quests [full]: the catalogue's state and counts, in chat and the trace (read it
-- with `luajit tools/trace-report.lua quests`). The trace keeps one line per zone and the
-- current zone's checklist; "full" adds every zone's checklist (large).
function Quests.DebugReport(option)
    if state.status == "idle" then Quests.Start() end
    if state.status ~= "ready" then
        local pos, n, phase
        if state.builder then pos, n, phase = state.builder.Progress() end
        ns.Printf("Quests: %s%s%s", state.status, state.reason and (" (" .. state.reason .. ")") or "",
            pos and string.format(", %s %d/%d", phase, pos, n) or "")
        ns.Debug.Trace("quests", { report = true, status = state.status, reason = state.reason })
        return
    end
    local i = state.index
    local L = i.left
    local t0 = clock()
    ns.Printf("Quests: %d in QuestieDB, %d in zone counts (built in %d frames, %s ms work, %s ms max frame)",
        i.total, i.counted, state.steps, tostring(state.workMs), tostring(state.maxStepMs))
    ns.Printf("  left out: repeatable %d, quest sorts %d, no zone %d, dungeon %d, raid %d, battleground %d, unmapped %d, excluded %d, not counted %d, errors %d",
        L.repeatable, L.sort, L.nozone, L.dungeon, L.raid, L.battleground, L.unmapped, L.excluded, L.notcounted, L.error)

    -- Our zone list against the index: zones with no quests, and indexed maps we don't list.
    local listed, zones, empty, notListed = {}, {}, {}, {}
    local reasons = {}
    for _, s in ipairs(ns.Maps.Sections()) do
        for _, z in ipairs(s.zones) do
            listed[z.mapID] = true
            local q = Quests.ForZone(z.mapID)
            local p = q.progress
            zones[#zones + 1] = string.format("%d %s %d quests: %d/%d done, eligible %d, locked %d, unavailable %d, unknown %d, %s, coverage %s (+%d repeatable)",
                z.mapID, tostring(z.name), q.count, p.completed, p.denominator, p.eligible, p.locked, p.unavailable,
                p.eligibilityUnknown, ns.Progression.PercentText(p) or "no %", p.coverage, q.repeatable)
            if q.count == 0 then empty[#empty + 1] = tostring(z.name) end
            for why, n in pairs(q.reasons) do reasons[why] = (reasons[why] or 0) + n end
        end
    end
    for mapID, z in pairs(i.zones) do
        if not listed[mapID] then notListed[#notListed + 1] = string.format("%d (%d)", mapID, #z.ids) end
    end
    table.sort(notListed)
    local unmapped = {}
    for areaID, n in pairs(i.unmapped) do
        local name = C_Map and type(C_Map.GetAreaInfo) == "function" and try("GetAreaInfo", C_Map.GetAreaInfo, areaID)
        unmapped[#unmapped + 1] = string.format("%d %s (%d)", areaID, tostring(name or "?"), n)
    end
    table.sort(unmapped)

    local all = Quests.Overall()
    local ap = all.progress
    local evalMs = t0 and clock() and round(clock() - t0)
    local c = ns.character or {}
    ns.Printf("  %s (race %s, class %s, level %s); completed list: %s", tostring(c.name), tostring(c.raceID),
        tostring(c.classID), tostring(c.level), completed and "read" or "not available")
    ns.Printf("  all zones: %d/%d done (%s), eligible %d, locked %d, unavailable %d, unknown %d, coverage %s",
        ap.completed, ap.denominator, ns.Progression.PercentText(ap) or "no %", ap.eligible, ap.locked,
        ap.unavailable, ap.eligibilityUnknown, ap.coverage)
    reasons = Quests.GroupReasons(reasons)
    ns.Printf("  reasons: %s", table.concat(top(reasons, 8), ", "))

    -- Where the character's completed quests fall: in a zone count, or left out and why.
    local done = {}
    if completed and lib then
        local Q = lib.Quest
        for id in pairs(completed) do
            local kind
            if type(Q.Exists) == "function" and not try("QuestDB.Exists", Q.Exists, id) then
                kind = "not in QuestieDB"
            else
                local zs = try("QuestDB.zoneOrSort", Q.zoneOrSort, id)
                local sf = try("QuestDB.specialFlags", Q.specialFlags, id)
                local qf = type(Q.questFlags) == "function" and try("QuestDB.questFlags", Q.questFlags, id) or nil
                kind = Quests.IsRepeatable(sf, qf) and "repeatable" or Quests.Place(zs, ns.QuestAreaData)
            end
            done[kind] = (done[kind] or 0) + 1
        end
        ns.Printf("  your completed quests by place: %s", table.concat(top(done, 10), ", "))
    end

    local here = ns.Exploration and ns.Exploration.CurrentZone and ns.Exploration.CurrentZone()
    local hq = here and Quests.ForZone(here)
    local hereList = {}
    if hq then
        local hp = hq.progress
        ns.Printf("  this zone (%d): %d quests, %d/%d done, eligible %d, locked %d, unavailable %d, unknown %d, %d repeatable left out",
            here, hq.count, hp.completed, hp.denominator, hp.eligible, hp.locked, hp.unavailable,
            hp.eligibilityUnknown, hq.repeatable)
        hereList = checklist(hq)
    end
    local full
    if option == "full" then
        full = {}
        for mapID in pairs(i.zones) do
            full[#full + 1] = { mapID = mapID, quests = checklist(Quests.ForZone(mapID)) }
        end
        table.sort(full, function(a, b) return a.mapID < b.mapID end)
    end
    ns.Printf("  listed zones without quests: %s", #empty > 0 and table.concat(empty, ", ") or "none")
    ns.Printf("  indexed maps not in the zone list: %s", #notListed > 0 and table.concat(notListed, ", ") or "none")
    ns.Printf("  unmapped areas: %s", #unmapped > 0 and table.concat(unmapped, ", ") or "none")
    local instances = 0
    for _ in pairs(i.instances) do instances = instances + 1 end
    ns.Debug.Trace("quests", { report = true, status = "ready", total = i.total, counted = i.counted, left = L,
        instances = instances, zones = zones, empty = empty, notListed = notListed, unmapped = unmapped,
        full = full, hereCount = hq and hq.count, steps = state.steps, workMs = state.workMs, maxStepMs = state.maxStepMs,
        elapsedMs = state.elapsedMs, evalMs = evalMs, completedKnown = completed ~= nil,
        character = { name = c.name, raceID = c.raceID, classID = c.classID, level = c.level },
        all = { completed = ap.completed, denominator = ap.denominator, eligible = ap.eligible, locked = ap.locked,
            unavailable = ap.unavailable, unknown = ap.eligibilityUnknown, completionUnknown = ap.completionUnknown,
            coverage = ap.coverage, percent = ap.percent },
        reasons = reasons, here = here, hereList = hereList, completedByPlace = done })
end
