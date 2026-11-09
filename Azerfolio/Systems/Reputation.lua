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
-- and collapsed again (bottom-up, so indexes don't shift); the watched faction is never touched.
-- If a header can't be expanded, a faction not seen is "unknown" (nil), never "not met".
-- Refreshed on UPDATE_FACTION, debounced. Nothing is saved.
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

-- Pure: a zone's factions for this character.
--   zone = ReputationRules.Build entry ({ factions, rivals }); read(factionID) -> data or nil;
--   met, metComplete from ReadMet (a faction not seen counts as unknown unless complete);
--   questState(questID) -> { name, questLevel, reqLevel, completion, eligibility, reason,
--   difficulty, repeatable } or nil.
-- Returns a list in display order (rule order, rivals together), factions without data left
-- out, or nil when none are left:
--   { factionID, name, reaction, standing, into, span, maxed, atWar, met = true|false|nil,
--     count = raising quests here, rivals = { { factionID, name } }, quests = { { id, amount,
--     name, questLevel, reqLevel, completion, eligibility, reason, difficulty, repeatable } } }
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

local function api() return rawget(_G, "C_Reputation") end
local function now() return type(GetTime) == "function" and GetTime() or 0 end

function Reputation.State() return state end

-- The rule's input from Quests' index: every zone's counted and repeatable quests.
local function build()
    local index = ns.Quests.Index()
    if not index then return false end
    local input = {}
    for mapID, z in pairs(index.zones) do
        local ids = {}
        for _, id in ipairs(z.ids) do ids[#ids + 1] = id end
        for _, id in ipairs(z.repeats or {}) do ids[#ids + 1] = id end
        input[mapID] = ids
    end
    local function rewardsOf(id)
        local r = ns.Quests.Info(id)
        return r and r.rep
    end
    zones = ns.ReputationRules.Build(input, rewardsOf)
    factionIDs = {}
    local seen, n = {}, 0
    for _, z in pairs(zones) do
        n = n + 1
        for _, p in ipairs(z.factions) do
            if not seen[p.factionID] then seen[p.factionID] = true; factionIDs[#factionIDs + 1] = p.factionID end
        end
    end
    table.sort(factionIDs)
    state = { status = "ready", zones = n, factions = #factionIDs }
    return true
end

-- Re-reads standing for every zone faction and the met list. allowExpand = false: don't open
-- collapsed headers (right after our own expansion); factions met earlier stay met.
local function refresh(reason, allowExpand)
    if state.status ~= "ready" then return end
    local C = api()
    local readCount, missing = 0, 0
    for _, id in ipairs(factionIDs) do
        local d = Reputation.ReadFaction(C, id)
        standings[id] = d or false
        if d then readCount = readCount + 1 else missing = missing + 1 end
    end
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
    results = {}
    -- Per faction "reaction standing into/span met|unmet|? [war]", or "none" without data.
    local each = {}
    for _, id in ipairs(factionIDs) do
        local d = standings[id]
        if d then
            local s = Reputation.Standing(d)
            each[tostring(id)] = string.format("%d %s %s/%s %s%s", s.reaction, tostring(s.standing), tostring(s.into),
                tostring(s.span), met[id] and "met" or (metComplete and "unmet" or "?"), s.atWar and " war" or "")
        else
            each[tostring(id)] = "none"
        end
    end
    ns.Debug.Trace("reputation", { refresh = reason, factions = #factionIDs, read = readCount, missing = missing,
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
                eligibility = o.eligibility, reason = o.reason, difficulty = o.difficulty }
        end
        local r = ns.Quests.Info(id)
        if not r then return nil end
        local s = { name = r.name, questLevel = r.level, reqLevel = r.reqLevel, repeatable = true }
        if ctx then
            s.eligibility, s.reason = ns.QuestRules.Evaluate(ctx, id)
            s.difficulty = ns.Quests.Difficulty(r.level, ctx.char and ctx.char.level, ctx.greenRange)
        end
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

ns.Events.On("AZF_QUESTS_UPDATED", function()
    local qs = ns.Quests.State()
    if qs.status == "unavailable" then
        state = { status = "unavailable", reason = qs.reason }
        ns.Debug.Trace("reputation", { status = "unavailable", reason = qs.reason })
        ns.Events.Send("AZF_REPUTATION_UPDATED")
        return
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
    -- Quest states changed (turn-in, level): the faction pages' quest lists.
    results = {}
end)

ns.Events.Register("UPDATE_FACTION", function()
    if state.status ~= "ready" then return end
    local quiet = reading or (lastExpand and now() - lastExpand < Reputation.EXPAND_QUIET)
    ns.Events.Debounce("reputation", Reputation.REFRESH_DELAY, function()
        refresh("UPDATE_FACTION", not quiet)
    end)
end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() refresh("refresh") end)
