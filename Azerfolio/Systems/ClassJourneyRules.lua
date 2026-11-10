-- Class journey rules (Phase 13, the Class tab): one character's class quest road, from the
-- curated Data/ClassJourneys.lua, this character's completed quests and the quest rules. The
-- data says which quests make up each stop; the game says which are done; QuestRules says
-- which this character can do. Nothing here is guessed: a stop with no quest this character
-- can do isn't on the road, and without the completed list nothing is "done" or "not done".
--
-- A step is one entry of a stop's quests: a quest ID, or { a, b } for "any one of". A step:
--   done when any of its quests is completed;
--   otherwise its best state among the quests not ruled out: eligible > locked > unknown;
--   left out when every quest is unavailable (another race's or side's version).
-- A stop's routes are alternatives: done when any route is done; otherwise the route with the
-- most done steps (then the most steps this character can do, then the first) is shown.
-- Race versions of a stop share its key: the one with steps for this character is used (if
-- two are, the one with more done steps).
--
-- Pure: no WoW globals, so tests and tools can load it.
local _, ns = ...
ns = ns or {}

local Rules = {}
ns.ClassJourneyRules = Rules

-- Step state severity for the shown state: the best a step can be (done is best).
local RANK = { done = 4, eligible = 3, locked = 2, unknown = 1 }

local function hasBit(mask, b)
    return type(mask) == "number" and type(b) == "number" and math.floor(mask / b) % 2 == 1
end

-- Pure: the journey for a class file token (PALADIN) and a side (Alliance / Horde), or nil.
function Rules.Journey(data, classFile, side)
    local c = type(data) == "table" and data[classFile]
    local j = type(c) == "table" and c[side]
    return type(j) == "table" and j or nil
end

-- Pure: one step. ev(id) -> state, reason (QuestRules.Evaluate for this character);
-- completed = { [id] = true } or nil (unknown).
-- Returns nil when the step isn't for this character, else
--   { id (the quest to show), ids, state = done|eligible|locked|unknown, reason }
function Rules.Step(entry, ev, completed)
    local ids = type(entry) == "table" and entry or { entry }
    if completed then
        for _, id in ipairs(ids) do
            if completed[id] then return { id = id, ids = ids, state = "done" } end
        end
    end
    local best, bestId, bestWhy
    for _, id in ipairs(ids) do
        local s, why = ev(id)
        if s ~= "unavailable" then
            if not completed then s = s == "eligible" and "unknown" or s end -- can't say it's not done
            if not best or RANK[s] > RANK[best] then best, bestId, bestWhy = s, id, why end
        end
    end
    if not best then return nil end
    if not completed then best, bestWhy = "unknown", bestWhy or "completed quests not known" end
    return { id = bestId, ids = ids, state = best, reason = bestWhy }
end

-- Pure: a quests list -> steps (those for this character), done count.
local function steps(list, ev, completed)
    local out, done = {}, 0
    for _, entry in ipairs(list or {}) do
        local s = Rules.Step(entry, ev, completed)
        if s then
            out[#out + 1] = s
            if s.state == "done" then done = done + 1 end
        end
    end
    return out, done
end

-- Pure: the state of a stop from its steps.
--   done (every step done) | progress (some) | ready (a step can be done now) | later (locked:
--   level or prerequisite) | unknown
function Rules.StopState(list, done, completed)
    if not completed then return "unknown" end
    if #list == 0 then return nil end
    if done == #list then return "done" end
    if done > 0 then return "progress" end
    local any = {}
    for _, s in ipairs(list) do any[s.state] = true end
    if any.eligible then return "ready" end
    if any.locked then return "later" end
    return "unknown"
end

-- Pure: one stop for this character, or nil when it has no step for them.
--   raceBit: the character's QuestieDB race bit (nil = not known: raceMask stops are left out)
function Rules.Stop(stop, ev, completed, raceBit)
    if stop.raceMask and not hasBit(stop.raceMask, raceBit) then return nil end
    local list, done, routeName
    if stop.routes then
        local bestScore
        for _, route in ipairs(stop.routes) do
            local l, d = steps(route, ev, completed)
            if #l > 0 then
                -- Finished routes first, then most done, then most steps this character can do.
                local score = (d == #l and 1e6 or 0) + d * 1000 + #l
                if not bestScore or score > bestScore then
                    bestScore, list, done, routeName = score, l, d, route.name
                end
            end
        end
        if not list then return nil end
    else
        list, done = steps(stop.quests, ev, completed)
        if #list == 0 then return nil end
    end
    local extra = {}
    for _, id in ipairs(stop.extra or {}) do
        local s = Rules.Step(id, ev, completed)
        if s then extra[#extra + 1] = s end
    end
    return { key = stop.key, kind = stop.kind, from = stop.from, name = stop.name, level = stop.level,
        reward = stop.reward, order = stop.order, route = routeName, steps = list, extra = extra,
        count = #list, done = completed and done or nil, state = Rules.StopState(list, done, completed) }
end

-- Pure: the whole road for one character.
--   journey = Rules.Journey(...); ev, completed as for Rules.Step; raceBit as for Rules.Stop.
-- Returns { title, notes, stops = { stop... } in curated order, one per key,
--   road = { count, done }, side = { count, done }, quests = { count, done },
--   complete = true|false|nil (nil: completed quests not known), unknown = stops in "unknown" }
function Rules.Build(journey, ev, completed, raceBit)
    local byKey, order = {}, {}
    for _, stop in ipairs(journey.stops or {}) do
        local s = Rules.Stop(stop, ev, completed, raceBit)
        if s then
            local prev = byKey[s.key]
            if not prev then
                byKey[s.key] = s
                order[#order + 1] = s.key
            elseif (s.done or 0) > (prev.done or 0) then
                byKey[s.key] = s -- two versions for this character: the one further along
            end
        end
    end
    local r = { title = journey.title, notes = journey.notes, stops = {},
        road = { count = 0, done = 0 }, side = { count = 0, done = 0 }, quests = { count = 0, done = 0 }, unknown = 0 }
    for _, key in ipairs(order) do
        local s = byKey[key]
        r.stops[#r.stops + 1] = s
        local group = s.kind == "side" and r.side or r.road
        group.count = group.count + 1
        if s.state == "done" then group.done = group.done + 1 end
        if s.state == "unknown" then r.unknown = r.unknown + 1 end
        r.quests.count = r.quests.count + s.count
        r.quests.done = r.quests.done + (s.done or 0)
    end
    if completed then
        r.complete = #r.stops > 0 and r.road.done == r.road.count and r.side.done == r.side.count
    end
    return r
end

-- Pure: every quest ID the data names (for probes): { [id] = true }.
function Rules.AllIds(data)
    local ids = {}
    local function add(v)
        if type(v) == "number" then ids[v] = true
        elseif type(v) == "table" then for _, x in ipairs(v) do add(x) end end
    end
    for _, c in pairs(type(data) == "table" and data or {}) do
        if type(c) == "table" then
            for side, j in pairs(c) do
                if side ~= "ignore" and type(j) == "table" then
                    for _, s in ipairs(j.stops or {}) do
                        add(s.quests); add(s.extra)
                        for _, route in ipairs(s.routes or {}) do add(route) end
                    end
                end
            end
        end
    end
    return ids
end

return Rules
