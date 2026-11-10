-- Zone reputation (Phase 11, spec §7.8, §8.9): each zone's own factions with this
-- character's standing. Not a completion category: nothing here counts toward a zone's %.
--
-- Zone factions: ns.ReputationRules over the reputationReward of every quest Quests puts in a
-- zone (counted and repeatable; QuestieDB's composed view, so in-game corrections apply).
-- Without QuestieDB there are none, and ForZone returns nothing (the section is hidden).
-- Standing: C_Reputation.GetFactionDataByID [verified-ingame], read under pcall; a faction the
-- game returns nothing for (the other side's, faction 471) is dropped. Standing is absolute
-- (-42000..42000); progress into the reaction = standing - currentReactionThreshold, out of
-- nextReactionThreshold - currentReactionThreshold [verified-ingame, Stormwind].
-- Met: the faction is in C_Reputation's index list, which holds only met factions
-- [verified-ingame]. Collapsed headers hide their children, so they are expanded for the read
-- and collapsed again (bottom-up, so indexes don't shift); the watched faction is never touched
-- by a read.
-- If a header can't be expanded, a faction not seen is "unknown" (nil), never "not met".
-- Refreshed on UPDATE_FACTION, debounced. Nothing is saved.
-- Reputation tab (Phase 12, spec §7.9, §8.10): AllFactions / List / Get give every faction the
-- game returns data for on this side (seed IDs, every faction a quest reward names, met ones),
-- with sources and the reach from ns.ReputationRules over every quest with a reward; session
-- gains against the first read this session (memory only); Watch through
-- C_Reputation.SetWatchedFactionByID, only when the player asks (X).
-- Everything above "Live" is pure, so tests can load it without the client.
local _, ns = ...

local Reputation = {}
ns.Reputation = Reputation

Reputation.REFRESH_DELAY = 1 -- seconds after the last UPDATE_FACTION
Reputation.EXPAND_QUIET = 2  -- seconds after a read that expanded headers: its own UPDATE_FACTION
                             -- events refresh standing without expanding again (no loop)
Reputation.MAX_REACTION = 8  -- Exalted (FACTION_STANDING_LABEL1..8) [verified-ingame]

---------------------------------------------------------------------------------------------
-- Pure
---------------------------------------------------------------------------------------------

-- Pure: one faction's data from C_Reputation (api), or nil (no function, an error, no data).
function Reputation.ReadFaction(api, factionID)
    if type(api) ~= "table" or type(api.GetFactionDataByID) ~= "function" then return nil end
    local ok, d = pcall(api.GetFactionDataByID, factionID)
    if not ok or type(d) ~= "table" or type(d.reaction) ~= "number" then return nil end
    return d
end

-- Pure: standing from a faction data table:
--   { reaction, standing, into, span, maxed, atWar }   into/span nil when the thresholds
--   don't give a span (shown without numbers).
function Reputation.Standing(d)
    local reaction, standing = d.reaction, d.currentStanding
    local lo, hi = d.currentReactionThreshold, d.nextReactionThreshold
    local s = { reaction = reaction, standing = type(standing) == "number" and standing or nil,
        maxed = reaction >= Reputation.MAX_REACTION, atWar = d.atWarWith == true }
    if s.standing and type(lo) == "number" and type(hi) == "number" and hi > lo then
        s.into = math.max(0, math.min(hi - lo, s.standing - lo))
        s.span = hi - lo
    end
    return s
end

-- Pure: the factions in C_Reputation's index list (api), restoring collapsed headers.
-- Returns met = { [factionID] = true }, complete (false when a collapsed header couldn't be
-- expanded, so some met factions weren't seen), expanded (headers opened and closed again).
function Reputation.ReadMet(api)
    local met = {}
    if type(api) ~= "table" or type(api.GetNumFactions) ~= "function"
        or type(api.GetFactionDataByIndex) ~= "function" then
        return met, false, 0
    end
    local function count()
        local ok, n = pcall(api.GetNumFactions)
        return ok and type(n) == "number" and n or 0
    end
    local function data(i)
        local ok, d = pcall(api.GetFactionDataByIndex, i)
        return ok and type(d) == "table" and d or nil
    end
    local canExpand = type(api.ExpandFactionHeader) == "function" and type(api.CollapseFactionHeader) == "function"
    local reopened, complete, expanded = {}, true, 0
    local i, guard = 1, 0
    while i <= count() and guard < 1000 do
        guard = guard + 1
        local d = data(i)
        if d then
            if type(d.factionID) == "number" and d.factionID > 0 then met[d.factionID] = true end
            if d.isHeader and d.isCollapsed then
                local ok = canExpand and pcall(api.ExpandFactionHeader, i)
                local after = ok and data(i)
                if after and not after.isCollapsed then
                    expanded = expanded + 1
                    reopened[#reopened + 1] = { id = d.factionID, name = d.name }
                else
                    complete = false
                end
            end
        end
        i = i + 1
    end
    -- Collapse what we opened, from the bottom up (closing a header only moves rows below it).
    if #reopened > 0 then
        local want = {}
        for _, h in ipairs(reopened) do want[tostring(h.id) .. "|" .. tostring(h.name)] = true end
        for j = count(), 1, -1 do
            local d = data(j)
            local key = d and (tostring(d.factionID) .. "|" .. tostring(d.name))
            if key and want[key] and d.isHeader and not d.isCollapsed then
                pcall(api.CollapseFactionHeader, j)
                want[key] = nil
            end
        end
    end
    return met, complete, expanded
end

-- Pure: what the faction page shows for a repeatable quest (no completion: it can be done
-- again): ready when you can take it, else locked, unknown or unavailable as the rules say.
function Reputation.RepeatableKind(eligibility)
    if eligibility == "eligible" then return "ready" end
    if eligibility == "locked" or eligibility == "unavailable" then return eligibility end
    return "unknown"
end

-- Pure: a zone's factions for this character.
--   zone = ReputationRules.Build entry ({ factions, rivals }); read(factionID) -> data or nil;
--   met, metComplete from ReadMet (a faction not seen counts as unknown unless complete);
--   questState(questID) -> { name, questLevel, reqLevel, completion, eligibility, reason,
--   difficulty, repeatable } or nil.
-- Returns a list in display order (rule order, rivals together), factions without data left
-- out, or nil when none are left:
--   { factionID, name, reaction, standing, into, span, maxed, atWar, met = true|false|nil,
--     count = raising quests here, rivals = { { factionID, name } }, quests = { { id, amount,
--     name, questLevel, reqLevel, completion, eligibility, reason, difficulty, kind (the
--     Quests page's: ready, locked, unknown, done, unavailable, open), repeatable } } }
function Reputation.Zone(zone, read, met, metComplete, questState)
    if not zone then return nil end
    local data, list = {}, {}
    for _, p in ipairs(zone.factions) do data[p.factionID] = read(p.factionID) end
    for _, p in ipairs(zone.factions) do
        local d = data[p.factionID]
        if d then
            local f = Reputation.Standing(d)
            f.factionID, f.name, f.count = p.factionID, d.name, p.count
            if met and met[p.factionID] then f.met = true elseif metComplete then f.met = false end
            f.rivals = {}
            for _, r in ipairs(zone.rivals and zone.rivals[p.factionID] or {}) do
                if data[r] then f.rivals[#f.rivals + 1] = { factionID = r, name = data[r].name } end
            end
            f.quests = {}
            for _, q in ipairs(p.quests) do
                local e = { id = q.id, amount = q.amount }
                local s = questState and questState(q.id)
                if s then for k, v in pairs(s) do e[k] = v end end
                f.quests[#f.quests + 1] = e
            end
            list[#list + 1] = f
        end
    end
    return #list > 0 and list or nil
end

-- Pure: a session gain: the change since the first read this session, or nil (no baseline,
-- no standing, or no change).
function Reputation.Gain(base, now)
    if type(base) ~= "number" or type(now) ~= "number" or now == base then return nil end
    return now - base
end

-- Pure: the Reputation tab's factions (spec §7.9, §8.10), in no particular order (sort with
-- ReputationRules.Sort). o = {
--   ids = { factionID... } to try (duplicates fine), read(factionID) -> data or nil,
--   met, metComplete (ReadMet), side ("Alliance"/"Horde"/nil),
--   catalogue = ReputationRules.Catalogue result, or nil while sources aren't known,
--   sources = "ready" | "building" | "unavailable" (with reason),
--   stateOf(questID) -> { completion, eligibility }, classFile,
--   rivals = { [factionID] = { rivalID... } }, baseline = { [factionID] = standing },
--   placeName(kind, key, classFile) -> name or nil, isZoneFaction(mapID, factionID) -> bool }
-- Each: { factionID, name, description, reaction, standing, into, span, left, maxed, atWar,
--   met, watched, gain, group, raising, unplaced, sources (ReputationRules.Evaluate, each with
--   name and, for zones, zoneFaction), main (the source it's raised most in), artMap (main's
--   mapID when it's a zone), reach, rivals = { { factionID, name } }, sourcesStatus }.
-- Left out: headers (by ID or the data's isHeader), the other side's battleground factions,
-- and factions the game returns nothing for.
function Reputation.All(o)
    local R = ns.ReputationRules
    local data, order, seen = {}, {}, {}
    for _, id in ipairs(o.ids or {}) do
        if not seen[id] then
            seen[id] = true
            if R.Shown(id, o.side) then
                local d = o.read(id)
                if d and not d.isHeader then data[id] = d; order[#order + 1] = id end
            end
        end
    end
    local out = {}
    for _, id in ipairs(order) do
        local d = data[id]
        local f = Reputation.Standing(d)
        f.factionID, f.name = id, d.name
        f.description = type(d.description) == "string" and d.description ~= "" and d.description or nil
        f.watched = d.isWatched == true
        if f.into and f.span and not f.maxed then f.left = f.span - f.into end
        if o.met and o.met[id] then f.met = true elseif o.metComplete then f.met = false end
        f.gain = Reputation.Gain(o.baseline and o.baseline[id], f.standing)
        f.rivals = {}
        local rivalIDs = {}
        for _, r in ipairs(o.rivals and o.rivals[id] or {}) do
            if data[r] then
                f.rivals[#f.rivals + 1] = { factionID = r, name = data[r].name }
                rivalIDs[#rivalIDs + 1] = r
            end
        end
        f.sourcesStatus = o.sources or "unavailable"
        local fc = o.catalogue and o.catalogue[id]
        if o.catalogue then
            f.group = R.GroupOf(id, fc)
            f.raising, f.unplaced = fc and fc.raising or 0, fc and fc.unplaced or 0
            f.sources, f.reach = R.Evaluate(fc, o.stateOf, { classFile = o.classFile,
                standing = not f.maxed and f.standing or nil, rivals = rivalIDs })
            for _, s in ipairs(f.sources) do
                s.name = o.placeName and o.placeName(s.kind, s.key, s.classFile) or nil
                if s.kind == "zone" and o.isZoneFaction then s.zoneFaction = o.isZoneFaction(s.key, id) and true or false end
            end
            f.main = R.Main(f.sources, f.group)
            f.artMap = f.main and f.main.kind == "zone" and f.main.key or nil
        else
            -- Sources unknown: only the home and battleground factions can be placed.
            local ex = R.EXCLUDED[id]
            f.group = ex == "home" and "home" or ex == "battleground" and "bgs" or "unknown"
            f.sources = {}
        end
        out[#out + 1] = f
    end
    return out
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

-- state.status: "idle" (waiting for Quests), "ready", "unavailable" (with reason)
local state = { status = "idle" }
local zones          -- ReputationRules.Build result: [mapID] = { factions, rivals }
local factionIDs     -- every zone faction, once
local standings = {} -- [factionID] = data from GetFactionDataByID (false = no data)
local met, metComplete = {}, false
local lastExpand     -- GetTime() of the last read that expanded headers
local reading = false -- true while ReadMet runs (its own UPDATE_FACTION, if it fires at once)
local results = {}   -- [mapID] = Zone result (cleared on every refresh and quest update)
-- Reputation tab (Phase 12):
local catalogue      -- ReputationRules.Catalogue over every quest with a reward (nil without QuestieDB)
local rivalsAll = {} -- [factionID] = { rivalID... }: the zones' rival pairs together
local readIDs = {}   -- every faction read by ID: zone factions, seeds, the catalogue's, met ones
local baseline = {}  -- [factionID] = the first standing read this session (session gains)
local allCache       -- Reputation.All result (cleared on every refresh and quest update)

local function api() return rawget(_G, "C_Reputation") end
local function now() return type(GetTime) == "function" and GetTime() or 0 end

function Reputation.State() return state end

-- The rule's input from Quests' index: every zone's counted and repeatable quests.
local function ruleInput()
    local index = ns.Quests.Index()
    if not index then return nil end
    local input = {}
    for mapID, z in pairs(index.zones) do
        local ids = {}
        for _, id in ipairs(z.ids) do ids[#ids + 1] = id end
        for _, id in ipairs(z.repeats or {}) do ids[#ids + 1] = id end
        input[mapID] = ids
    end
    return input
end
local function rewardsOf(id)
    local r = ns.Quests.Info(id)
    return r and r.rep
end

-- The tab's catalogue input: every zone quest (counted and repeatable) plus every quest
-- outside a zone that has a reward (Quests' others pass).
local function catalogueInput(index)
    local entries = {}
    for mapID, z in pairs(index.zones) do
        for _, id in ipairs(z.ids) do entries[#entries + 1] = { id = id, kind = "zone", key = mapID } end
        for _, id in ipairs(z.repeats or {}) do entries[#entries + 1] = { id = id, kind = "zone", key = mapID, repeatable = true } end
    end
    for _, o in ipairs(index.repOthers or {}) do entries[#entries + 1] = o end
    return entries
end

-- The IDs read by ID on every refresh: seeds, zone factions, the catalogue's.
local function setReadIDs()
    local seen, list = {}, {}
    local function add(id) if not seen[id] then seen[id] = true; list[#list + 1] = id end end
    for _, id in ipairs(ns.ReputationRules.SEED_IDS) do add(id) end
    for _, id in ipairs(factionIDs or {}) do add(id) end
    local extra = {}
    for id in pairs(catalogue or {}) do if not seen[id] then extra[#extra + 1] = id end end
    table.sort(extra)
    for _, id in ipairs(extra) do add(id) end
    readIDs = list
end

local function build()
    local input = ruleInput()
    if not input then return false end
    zones = ns.ReputationRules.Build(input, rewardsOf)
    factionIDs = {}
    rivalsAll = {}
    local seen, n = {}, 0
    for _, z in pairs(zones) do
        n = n + 1
        for _, p in ipairs(z.factions) do
            if not seen[p.factionID] then seen[p.factionID] = true; factionIDs[#factionIDs + 1] = p.factionID end
        end
        for f, list in pairs(z.rivals or {}) do
            rivalsAll[f] = rivalsAll[f] or {}
            for _, g in ipairs(list) do
                local dup = false
                for _, x in ipairs(rivalsAll[f]) do if x == g then dup = true end end
                if not dup then table.insert(rivalsAll[f], g) end
            end
        end
    end
    for _, list in pairs(rivalsAll) do table.sort(list) end
    table.sort(factionIDs)
    catalogue = ns.ReputationRules.Catalogue(catalogueInput(ns.Quests.Index()), rewardsOf)
    local nc = 0
    for _ in pairs(catalogue) do nc = nc + 1 end
    setReadIDs()
    state = { status = "ready", zones = n, factions = #factionIDs, catalogued = nc }
    return true
end

-- Re-reads the met list and the standing of every faction read by ID (zone factions, the
-- tab's). allowExpand = false: don't open collapsed headers (right after our own expansion);
-- factions met earlier stay met.
local function refresh(reason, allowExpand)
    if state.status ~= "ready" and state.status ~= "unavailable" then return end
    local C = api()
    local expanded = 0
    if allowExpand ~= false then
        local seen, complete
        reading = true
        seen, complete, expanded = Reputation.ReadMet(C)
        reading = false
        for id in pairs(seen) do met[id] = true end
        metComplete = complete
        if expanded > 0 then lastExpand = now() end
    else
        -- Without expanding, only rows outside collapsed headers are seen: add those.
        local fake = C and { GetNumFactions = C.GetNumFactions, GetFactionDataByIndex = C.GetFactionDataByIndex }
        local seen = Reputation.ReadMet(fake)
        for id in pairs(seen) do met[id] = true end
    end
    -- Standing by ID: every ID to read plus every met faction.
    local ids, isRead = {}, {}
    for _, id in ipairs(readIDs) do ids[#ids + 1] = id; isRead[id] = true end
    local extra = {}
    for id in pairs(met) do if not isRead[id] then extra[#extra + 1] = id end end
    table.sort(extra)
    for _, id in ipairs(extra) do ids[#ids + 1] = id end
    local readCount, missing = 0, 0
    for _, id in ipairs(ids) do
        local d = Reputation.ReadFaction(C, id)
        standings[id] = d or false
        if d then
            readCount = readCount + 1
            if baseline[id] == nil and type(d.currentStanding) == "number" then baseline[id] = d.currentStanding end
        else
            missing = missing + 1
        end
    end
    results, allCache = {}, nil
    -- Per faction "reaction standing into/span met|unmet|? [war] [watched] [+gain]", or "none".
    local each = {}
    for _, id in ipairs(ids) do
        local d = standings[id]
        if d then
            local s = Reputation.Standing(d)
            local g = Reputation.Gain(baseline[id], s.standing)
            each[tostring(id)] = string.format("%d %s %s/%s %s%s%s%s", s.reaction, tostring(s.standing), tostring(s.into),
                tostring(s.span), met[id] and "met" or (metComplete and "unmet" or "?"), s.atWar and " war" or "",
                d.isWatched and " watched" or "", g and string.format(" %+d", g) or "")
        else
            each[tostring(id)] = "none"
        end
    end
    ns.Debug.Trace("reputation", { refresh = reason, factions = #(factionIDs or {}), ids = #ids, read = readCount, missing = missing,
        metComplete = metComplete, expanded = expanded, standing = each })
    ns.Events.Send("AZF_REPUTATION_UPDATED")
end

-- Quest state for the faction page: the Quests page's own objective (counted quests), or the
-- rules' eligibility for a repeatable (no completion: it can be done again).
local function questStateFor(mapID)
    local byID = {}
    local zr = ns.Quests.ForZone(mapID)
    for _, o in ipairs(zr and zr.objectives or {}) do byID[o.id] = o end
    local ctx = ns.Quests.Context()
    return function(id)
        local o = byID[id]
        if o then
            return { name = o.name, questLevel = o.questLevel, reqLevel = o.reqLevel, completion = o.completion,
                eligibility = o.eligibility, reason = o.reason, difficulty = o.difficulty, kind = o.kind,
                prereqs = o.prereqs, prereqAny = o.prereqAny }
        end
        local r = ns.Quests.Info(id)
        if not r then return nil end
        local s = { name = r.name, questLevel = r.level, reqLevel = r.reqLevel, repeatable = true }
        if ctx then
            s.eligibility, s.reason = ns.QuestRules.Evaluate(ctx, id)
            s.difficulty = ns.Quests.Difficulty(r.level, ctx.char and ctx.char.level, ctx.greenRange)
        end
        s.kind = Reputation.RepeatableKind(s.eligibility)
        return s
    end
end

-- A zone's factions (a mapID or { mapID }) for this character, in display order (see
-- Reputation.Zone), or nil: QuestieDB isn't loaded or still reading, or the zone has no
-- zone faction the game gives this character data for. Not part of the zone's progress.
function Reputation.ForZone(zone)
    local mapID = type(zone) == "table" and zone.mapID or zone
    if state.status ~= "ready" or not zones or not zones[mapID] then return nil end
    local r = results[mapID]
    if r == nil then
        local function read(id) return standings[id] or nil end
        r = Reputation.Zone(zones[mapID], read, met, metComplete, questStateFor(mapID)) or false
        results[mapID] = r
    end
    return r or nil
end

-- One faction of a zone (the faction page), or nil.
function Reputation.Faction(zone, factionID)
    for _, f in ipairs(Reputation.ForZone(zone) or {}) do
        if f.factionID == factionID then return f end
    end
    return nil
end

-- The zone-faction table itself (debug and tests): [mapID] = { factions, rivals }, or nil.
function Reputation.Zones() return zones end

---------------------------------------------------------------------------------------------
-- Reputation tab (Phase 12, spec §7.9, §8.10)
---------------------------------------------------------------------------------------------

-- A place's name: zones and areas from the client (C_Map), classes from the client's class
-- names, sorts from ReputationRules.SORT_NAMES. nil when the client has none.
local function placeName(kind, key, classFile)
    local C = rawget(_G, "C_Map")
    if kind == "zone" then
        if not (C and type(C.GetMapInfo) == "function") then return nil end
        local ok, info = pcall(C.GetMapInfo, key)
        return ok and type(info) == "table" and info.name or nil
    end
    if kind == "class" then
        local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
        return type(names) == "table" and names[classFile] or nil
    end
    if type(key) == "number" and key < 0 then return ns.ReputationRules.SORT_NAMES[key] end
    if type(key) == "number" and C and type(C.GetAreaInfo) == "function" then
        local ok, name = pcall(C.GetAreaInfo, key)
        return ok and type(name) == "string" and name ~= "" and name or nil
    end
    return nil
end

local function isZoneFaction(mapID, factionID)
    for _, p in ipairs(zones and zones[mapID] and zones[mapID].factions or {}) do
        if p.factionID == factionID then return true end
    end
    return false
end

-- Quest states for the reach: the client's completion and the rules' eligibility, memoised
-- for one All() build.
local function stateOfAll()
    local ctx = ns.Quests.Context()
    if not ctx then return function() return nil end end
    local memo = {}
    return function(id)
        local s = memo[id]
        if s == nil then
            s = { completion = ns.QuestRules.Completion(ctx.completed, id), eligibility = (ns.QuestRules.Evaluate(ctx, id)) }
            memo[id] = s
        end
        return s
    end
end

-- Every faction for the tab (see Reputation.All), or nil before the first read (Quests still
-- building). Sources are "ready" with QuestieDB, else "unavailable" (state.reason says why).
function Reputation.AllFactions()
    if state.status ~= "ready" and state.status ~= "unavailable" then return nil end
    if not allCache then
        local ids = {}
        for _, id in ipairs(readIDs) do ids[#ids + 1] = id end
        for id in pairs(met) do ids[#ids + 1] = id end
        local c = ns.character or {}
        allCache = Reputation.All({ ids = ids, read = function(id) return standings[id] or nil end,
            met = met, metComplete = metComplete, side = c.faction,
            catalogue = state.status == "ready" and catalogue or nil, sources = state.status,
            stateOf = state.status == "ready" and stateOfAll() or nil, classFile = c.classFile,
            rivals = rivalsAll, baseline = baseline, placeName = placeName, isZoneFaction = isZoneFaction })
    end
    return allCache
end

-- What the tab shows for a filter ("all"/"met"/"unmet") and a sort ("group"/"closest"/"name"):
--   { factions = filtered and sorted, groups = ReputationRules.Grouped (sort "group" only),
--     summary = ReputationRules.Summary of every faction (the standing strip), total,
--     sources = "ready"|"unavailable", reason }  or nil before the first read.
function Reputation.List(filter, sort)
    local all = Reputation.AllFactions()
    if not all then return nil end
    local R = ns.ReputationRules
    local list = R.Sort(R.Filter(all, filter), sort)
    return { factions = list, groups = sort == "group" and R.Grouped(list) or nil, summary = R.Summary(all),
        total = #all, sources = state.status, reason = state.reason }
end

-- One faction of the tab (its page), or nil.
function Reputation.Get(factionID)
    for _, f in ipairs(Reputation.AllFactions() or {}) do
        if f.factionID == factionID then return f end
    end
    return nil
end

-- Watching (X): sets the faction shown on the experience bar. C_Reputation.SetWatchedFactionByID
-- exists in the client [verified-ingame, probe] but hasn't been called yet [unverified]; 0
-- clears it [unverified, retail convention]. Offered only for met factions (an unmet one isn't
-- in the game's list) [inferred]. Open check: docs/open-checks.md.
function Reputation.CanWatch(f)
    local C = api()
    return type(C) == "table" and type(C.SetWatchedFactionByID) == "function" and type(f) == "table" and f.met == true
end

-- Watch (on = true) or stop watching a faction. Returns true when the call went through (the
-- tab shows the game's isWatched after the next read), or false and a reason.
function Reputation.SetWatched(factionID, on)
    local C = api()
    if type(C) ~= "table" or type(C.SetWatchedFactionByID) ~= "function" then return false, "unsupported" end
    local ok, err = pcall(C.SetWatchedFactionByID, on and factionID or 0)
    ns.Debug.Trace("reputation", { watch = factionID, on = on and true or false, ok = ok, err = not ok and tostring(err) or nil })
    if not ok then return false, "error" end
    -- The client may or may not fire UPDATE_FACTION for this; read again either way.
    ns.Events.Debounce("reputation", Reputation.REFRESH_DELAY, function() refresh("watch", false) end)
    return true
end

-- /azf debug reputation [mapID|questID ...]: the zone factions with their quest IDs, every
-- faction the rule saw in the watched zones (kept or not, with the share), and where the
-- watched quests stand in QuestieDB's composed view, so in-game corrections can be told apart
-- from the offline base rows. Read with `luajit tools/trace-report.lua reputation`.
-- Watched by default: Feralas 1444 and The Barrens 1413 (they differ from the base rows), the
-- Steamwheedle Cartel quests Feralas has in the base rows, and every quest that raises
-- Powderfuse 2827 anywhere.
Reputation.DEBUG_ZONES = { 1444, 1413 }
Reputation.DEBUG_QUESTS = { 7003, 7721, 7725, 7726 }
Reputation.DEBUG_FACTIONS = { 2827 }

local function ids(list)
    local o = {}
    for _, q in ipairs(list) do o[#o + 1] = q.id .. (q.amount and (":" .. q.amount) or "") end
    return table.concat(o, " ")
end

function Reputation.DebugReport(args)
    if state.status ~= "ready" then
        ns.Printf("Reputation: %s%s", state.status, state.reason and (" (" .. state.reason .. ")") or "")
        ns.Debug.Trace("reputation", { report = true, status = state.status, reason = state.reason })
        return
    end
    local watchZones, watchQuests = {}, {}
    for _, z in ipairs(Reputation.DEBUG_ZONES) do watchZones[#watchZones + 1] = z end
    for _, q in ipairs(Reputation.DEBUG_QUESTS) do watchQuests[#watchQuests + 1] = q end
    for _, a in ipairs(args or {}) do
        local n = tonumber(a)
        -- Map IDs are 4 digits here; quest IDs are any other number.
        if n and n >= 1400 and n < 3000 and ns.Quests.Index() and ns.Quests.Index().zones[n] then
            watchZones[#watchZones + 1] = n
        elseif n then
            watchQuests[#watchQuests + 1] = n
        end
    end
    local input = ruleInput() or {}
    local tally = ns.ReputationRules.Tally(input, rewardsOf)
    -- Every quest raising a watched faction, wherever the index put it.
    local seenQ = {}
    for _, q in ipairs(watchQuests) do seenQ[q] = true end
    for _, f in ipairs(Reputation.DEBUG_FACTIONS) do
        for _, zt in pairs(tally.zones) do
            for _, q in ipairs(zt[f] and zt[f].quests or {}) do
                if not seenQ[q.id] then seenQ[q.id] = true; watchQuests[#watchQuests + 1] = q.id end
            end
        end
    end
    -- Picks per zone: "factionID:count [questID:amount ...]".
    local picks, nz = {}, 0
    for mapID, z in pairs(zones or {}) do
        nz = nz + 1
        local parts = {}
        for _, p in ipairs(z.factions) do parts[#parts + 1] = string.format("%d:%d [%s]", p.factionID, p.count, ids(p.quests)) end
        picks[tostring(mapID)] = table.concat(parts, "  ")
    end
    -- The watched zones' whole tally: every faction with raising quests, kept or not.
    local seen = {}
    for _, mapID in ipairs(watchZones) do
        local zt = tally.zones[mapID]
        local rows = {}
        for f, e in pairs(zt or {}) do
            local total = tally.totals[f] or 0
            rows[#rows + 1] = string.format("%d %s %d/%d [%s]", f,
                ns.ReputationRules.Keeps(f, e.count, total) and "kept" or (ns.ReputationRules.EXCLUDED[f] or "dropped"),
                e.count, total, ids(e.quests))
        end
        table.sort(rows)
        seen[tostring(mapID)] = zt and (#input[mapID] .. " quests; " .. table.concat(rows, "  |  ")) or "not in the index"
    end
    -- The watched quests in QuestieDB's composed view.
    local probes = {}
    for _, id in ipairs(watchQuests) do
        local p = ns.Quests.Probe(id)
        if p then
            local rep = {}
            for _, r in ipairs(type(p.rep) == "table" and p.rep or {}) do
                if type(r) == "table" then rep[#rep + 1] = tostring(r[1]) .. ":" .. tostring(r[2]) end
            end
            probes[tostring(id)] = string.format("%s lv%s exists=%s zoneOrSort=%s -> %s%s%s, index %s, rep [%s]",
                tostring(p.name), tostring(p.level), tostring(p.exists), tostring(p.zoneOrSort), p.place,
                p.repeatable and " repeatable" or "", p.excluded and " excluded" or "", tostring(p.indexed or "none"),
                table.concat(rep, " "))
        else
            probes[tostring(id)] = "QuestieDB not detected"
        end
    end
    ns.Printf("Reputation: %d zones with factions; watched zones %s; %d quests probed.", nz,
        table.concat(watchZones, ", "), #watchQuests)
    for _, mapID in ipairs(watchZones) do ns.Printf("  %d: %s", mapID, seen[tostring(mapID)]) end
    ns.Print(ns.Debug.IsEnabled() and "  Full list in the trace: /reload, then luajit tools/trace-report.lua reputation"
        or "  Debug mode is off, so nothing was saved: type /azf debug, then run this again.")
    ns.Debug.Trace("reputation", { report = true, zones = nz, picks = picks, watched = seen, probes = probes })
end

ns.Events.On("AZF_QUESTS_UPDATED", function()
    local qs = ns.Quests.State()
    if qs.status == "unavailable" then
        -- No zone factions and no sources; the tab still lists standing (seeds and met ones).
        state = { status = "unavailable", reason = qs.reason }
        zones, catalogue, factionIDs, rivalsAll = nil, nil, nil, {}
        setReadIDs()
        ns.Debug.Trace("reputation", { status = "unavailable", reason = qs.reason })
        return refresh("unavailable")
    end
    if state.status ~= "ready" then
        if not build() then return end
        -- Per zone "factionID:count ..." in display order, rivals as "<>a/b".
        local each = {}
        for mapID, z in pairs(zones) do
            local parts = {}
            for _, p in ipairs(z.factions) do parts[#parts + 1] = p.factionID .. ":" .. p.count end
            for f, list in pairs(z.rivals) do
                for _, g in ipairs(list) do if f < g then parts[#parts + 1] = "<>" .. f .. "/" .. g end end
            end
            each[tostring(mapID)] = table.concat(parts, " ")
        end
        ns.Debug.Trace("reputation", { status = "ready", zones = state.zones, factions = state.factions, list = each })
        return refresh("build")
    end
    -- Quest states changed (turn-in, level): the faction pages' quest lists and the reach.
    results, allCache = {}, nil
end)

ns.Events.Register("UPDATE_FACTION", function()
    if state.status ~= "ready" and state.status ~= "unavailable" then return end
    local quiet = reading or (lastExpand and now() - lastExpand < Reputation.EXPAND_QUIET)
    ns.Events.Debounce("reputation", Reputation.REFRESH_DELAY, function()
        refresh("UPDATE_FACTION", not quiet)
    end)
end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() refresh("refresh") end)
