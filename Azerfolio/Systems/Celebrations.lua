-- Celebrations (spec §7.7, mockups/DESIGN.md "Celebrations"): a zone's category becoming
-- complete (the streamer it earns) or the zone becoming claimed, seen while you play.
-- Pure: Snapshot and Diff over ns.Zones entries. Live: a snapshot is taken once the data has
-- settled after login (that one celebrates nothing); every later update is compared with the
-- last snapshot. A category only celebrates when it was known and not complete before and is
-- complete now (data arriving late, such as a first flight master visit or QuestieDB finishing
-- its read, is not a change you made). A claim needs such a category change in the same zone.
-- Window open: the celebration plays (ns.Celebration, UI). Window closed: an on-screen alert,
-- and the celebration plays when you next open Azerfolio. Nothing is saved.
local _, ns = ...

local Celebrations = {}
ns.Celebrations = Celebrations

Celebrations.DEBOUNCE = 1     -- seconds after an update before comparing
Celebrations.SETTLE = 8       -- seconds after AZF_READY before the first snapshot

---------------------------------------------------------------------------------------------
-- Pure
---------------------------------------------------------------------------------------------

-- A category's state for celebrations: "complete", "open" (known, not complete), "pending".
local function catState(c)
    if c.pending then return "pending" end
    if c.state == "complete" then return "complete" end
    if c.state == "progress" or c.state == "untouched" then return "open" end
    return "pending"
end

-- Pure: { [mapID] = { state, cats = { [key] = "complete"|"open"|"pending" } } } for tracked zones.
function Celebrations.Snapshot(entries)
    local s = {}
    for _, z in ipairs(entries or {}) do
        if z.tracked then
            local cats = {}
            for _, c in ipairs(z.cats or {}) do cats[c.key] = catState(c) end
            s[z.mapID] = { state = z.state, cats = cats }
        end
    end
    return s
end

-- Pure: what to celebrate between two snapshots, claims first, then categories in the
-- display order (explore, quests, flights), zones by mapID.
--   { { mapID, kind = "claim" | "explore" | "quests" | "flights" } }
local ORDER = { "explore", "quests", "flights" }
function Celebrations.Diff(before, after)
    local claims, cats = {}, {}
    local ids = {}
    for mapID in pairs(after or {}) do ids[#ids + 1] = mapID end
    table.sort(ids)
    for _, mapID in ipairs(ids) do
        local b, a = before and before[mapID], after[mapID]
        if b then
            local done = {}
            for _, key in ipairs(ORDER) do
                if b.cats[key] == "open" and a.cats[key] == "complete" then done[#done + 1] = key end
            end
            if #done > 0 then
                if a.state == "complete" and b.state ~= "complete" then
                    claims[#claims + 1] = { mapID = mapID, kind = "claim" }
                else
                    for _, key in ipairs(done) do cats[#cats + 1] = { mapID = mapID, kind = key } end
                end
            end
        end
    end
    for _, c in ipairs(cats) do claims[#claims + 1] = c end
    return claims
end

-- Phase 15 step 9 (mockups/DESIGN.md "Celebrations", round 3): the class road, professions and
-- reputation, by the same rule: the state before and after both read in this session.

-- Pure: the class road from ClassJourney.Get(), or nil unless it's ready:
--   { complete = true|false|nil, order = { key... }, stops = { [key] = state } }
function Celebrations.ClassSnapshot(g)
    if type(g) ~= "table" or g.status ~= "ready" or type(g.journey) ~= "table" then return nil end
    local s = { complete = g.journey.complete, order = {}, stops = {} }
    for _, st in ipairs(g.journey.stops or {}) do
        s.order[#s.order + 1] = st.key
        s.stops[st.key] = st.state
    end
    return s
end

-- Pure: { { kind = "road" } } when the road became walked (it replaces its last stop's own), else
-- { { kind = "stop", key } ... } for each stop known not done before ("unknown" isn't known) and
-- done now, in road order.
function Celebrations.ClassDiff(before, after)
    if not before or not after then return {} end
    if after.complete == true and before.complete == false then return { { kind = "road" } } end
    local out = {}
    for _, key in ipairs(after.order) do
        local b = before.stops[key]
        if b and b ~= "done" and b ~= "unknown" and after.stops[key] == "done" then
            out[#out + 1] = { kind = "stop", key = key }
        end
    end
    return out
end

-- Pure: professions from Professions.Skills(): { [skillLine] = { skill, cap } } (nil fields when
-- the game gave none; a cap of 0 is unknown).
function Celebrations.ProfSnapshot(skills)
    local s = {}
    for _, p in ipairs(skills or {}) do
        s[p.skillLine] = { skill = type(p.skill) == "number" and p.skill or nil,
            cap = type(p.cap) == "number" and p.cap > 0 and p.cap or nil }
    end
    return s
end

-- Pure: { { kind = "mastered" | "rank", skillLine } } by skill line: Mastered when the skill
-- reached maxSkill (known below it before), else a rank when the cap rose. A profession learned
-- in this session (not in the earlier snapshot) celebrates nothing.
function Celebrations.ProfDiff(before, after, maxSkill)
    if not before or not after then return {} end
    local lines = {}
    for line in pairs(after) do if before[line] then lines[#lines + 1] = line end end
    table.sort(lines)
    local out = {}
    for _, line in ipairs(lines) do
        local b, a = before[line], after[line]
        if b.skill and a.skill and maxSkill and b.skill < maxSkill and a.skill >= maxSkill then
            out[#out + 1] = { kind = "mastered", skillLine = line }
        elseif b.cap and a.cap and a.cap > b.cap then
            out[#out + 1] = { kind = "rank", skillLine = line }
        end
    end
    return out
end

-- Pure: { { kind = "rep", factionID, reaction } } for each faction read before and now whose
-- reaction rose (by faction ID). reactions = { [factionID] = reaction }.
function Celebrations.RepDiff(before, after)
    if not before or not after then return {} end
    local ids = {}
    for id, r in pairs(after) do
        if type(before[id]) == "number" and type(r) == "number" and r > before[id] then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local out = {}
    for _, id in ipairs(ids) do out[#out + 1] = { kind = "rep", factionID = id, reaction = after[id] } end
    return out
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

local last          -- the last zones snapshot (nil until the first one)
local lastClass, lastProf, lastRep -- the others' last snapshots (nil until their data is ready)
local started = false -- the first, settled check has run
local dirty = {}    -- groups to compare on the next check: zones, class, prof, rep
local queue = {}    -- celebrations waiting for the window: { mapID, kind, zone = entry } and the others

function Celebrations.Queue() return queue end -- for tests

-- The next waiting celebration (removed from the queue), or nil.
function Celebrations.Next() return table.remove(queue, 1) end

local function byMap(entries)
    local m = {}
    for _, z in ipairs(entries) do m[z.mapID] = z end
    return m
end

-- Hands one celebration on: played now with the window open, else an alert and queued. A
-- reputation rank-up is a toast instead (AZF_TOAST): never queued, never modal.
function Celebrations.Announce(ev)
    ns.Debug.Trace("celebrate", { mapID = ev.mapID, kind = ev.kind, key = ev.key, skillLine = ev.skillLine,
        factionID = ev.factionID, reaction = ev.reaction, shown = ns.UI and ns.UI.IsShown() or false })
    if ev.kind == "rep" then return ns.Events.Send("AZF_TOAST", ev) end
    queue[#queue + 1] = ev
    ns.Events.Send("AZF_CELEBRATE", ev)
end

-- The live data each group reads (nil while it isn't ready).
local function classNow() return ns.ClassJourney and ns.ClassJourney.Get() end
local function stopOf(g, key)
    for _, s in ipairs(g and g.journey and g.journey.stops or {}) do if s.key == key then return s end end
end
local function profModel(line)
    for _, p in ipairs(ns.Professions and ns.Professions.Skills() or {}) do
        if p.skillLine == line then return ns.ProfessionRules.Profession(p) end
    end
end
-- { [factionID] = reaction } for every faction read this session, or nil before the first read.
local function reactions() return ns.Reputation and ns.Reputation.Reactions and ns.Reputation.Reactions() end
local function factionOf(id, reaction)
    local name = ns.Reputation.Name and ns.Reputation.Name(id)
    return { factionID = id, name = name or ("Faction " .. id), reaction = reaction }
end

-- The class road's events with what the UI shows: the stop, the road's counts, the class.
local function classEvent(ev, g)
    ev.journey = g.journey
    ev.classFile = g.char and g.char.classFile
    if ev.kind == "stop" then ev.stop = stopOf(g, ev.key) end
    return ev.kind == "road" or ev.stop ~= nil
end

function Celebrations.Check(reason)
    local all = reason == "first"
    local found = {}
    if all or dirty.zones then
        local entries = ns.Zones.All()
        local snap = Celebrations.Snapshot(entries)
        if last then
            local zones = byMap(entries)
            for _, ev in ipairs(Celebrations.Diff(last, snap)) do
                ev.zone = zones[ev.mapID]
                if ev.zone then found[#found + 1] = ev end
            end
        end
        last = snap
    end
    if all or dirty.class then
        local g = classNow()
        local snap = Celebrations.ClassSnapshot(g)
        if snap then
            for _, ev in ipairs(Celebrations.ClassDiff(lastClass, snap)) do
                if classEvent(ev, g) then found[#found + 1] = ev end
            end
            lastClass = snap
        end
    end
    if all or dirty.prof then
        local snap = ns.Professions and Celebrations.ProfSnapshot(ns.Professions.Skills())
        if snap then
            for _, ev in ipairs(Celebrations.ProfDiff(lastProf, snap, ns.ProfessionData and ns.ProfessionData.maxSkill)) do
                ev.prof = profModel(ev.skillLine)
                if ev.prof then found[#found + 1] = ev end
            end
            lastProf = snap
        end
    end
    if all or dirty.rep then
        local snap = reactions()
        if snap then
            for _, ev in ipairs(Celebrations.RepDiff(lastRep, snap)) do
                ev.faction = factionOf(ev.factionID, ev.reaction)
                found[#found + 1] = ev
            end
            lastRep = snap
        end
    end
    dirty = {}
    started = true
    for _, ev in ipairs(found) do Celebrations.Announce(ev) end
    ns.Debug.Trace("celebrations", { reason = reason, found = #found, waiting = #queue,
        class = lastClass ~= nil, prof = lastProf ~= nil, rep = lastRep ~= nil })
end

-- Debug: plays a sample of the class road, professions and reputation celebrations
-- (/azf debug celebrate stop|road|rank|mastered|rep|exalted): this character's first stop (the
-- first walked one when there is one), first profession, Stormwind or Orgrimmar (else the first
-- faction read). Returns false (with a message) when there's nothing to show.
local MORE = { stop = true, road = true, rank = true, mastered = true, rep = true, exalted = true }
Celebrations.PREVIEW_KINDS = MORE
function Celebrations.PreviewMore(kind)
    if kind == "stop" or kind == "road" then
        local g = classNow()
        if not (g and g.status == "ready") then return ns.Print("No class road to celebrate yet (" .. tostring(g and g.reason or g and g.status) .. ").") end
        local pick
        for _, s in ipairs(g.journey.stops) do if s.state == "done" and not pick then pick = s end end
        pick = pick or g.journey.stops[1]
        local ev = { kind = kind, key = pick and pick.key, preview = true }
        if classEvent(ev, g) then Celebrations.Announce(ev) end
    elseif kind == "rank" or kind == "mastered" then
        local first = ns.Professions.Skills()[1]
        if not first then return ns.Print("No profession to celebrate: learn one first.") end
        local p = first
        if kind == "mastered" then -- as it would read at the top (this character's skill isn't)
            local max = ns.ProfessionData.maxSkill
            p = { skillLine = first.skillLine, name = first.name, icon = first.icon, skill = max, cap = max }
        end
        Celebrations.Announce({ kind = kind, skillLine = first.skillLine, prof = ns.ProfessionRules.Profession(p), preview = true })
    else
        local r = reactions() or {}
        local home = (ns.character and ns.character.faction == "Horde") and 76 or 72
        local id = r[home] and home
        if not id then for fid in pairs(r) do if not id or fid < id then id = fid end end end
        if not id then return ns.Print("No faction read yet: open the Reputation tab once, then try again.") end
        local reaction = kind == "exalted" and 8 or math.max(5, math.min(7, (r[id] or 4) + 1))
        Celebrations.Announce({ kind = "rep", factionID = id, reaction = reaction, faction = factionOf(id, reaction), preview = true })
    end
end

-- Debug: plays a sample celebration for a zone (/azf debug celebrate <kind> [mapID]).
function Celebrations.Preview(kind, mapID)
    if MORE[kind] then return Celebrations.PreviewMore(kind) end
    local entries = ns.Zones.All()
    local z
    for _, e in ipairs(entries) do if e.mapID == mapID then z = e end end
    if not z then
        local here = ns.Exploration.CurrentZone()
        for _, e in ipairs(entries) do if e.mapID == here then z = e end end
    end
    if not z then return ns.Print("No zone to celebrate: stand in a tracked zone or give a map ID.") end
    Celebrations.Announce({ mapID = z.mapID, kind = kind, zone = z, preview = true })
end

if ns.Events then -- absent when tests load the pure part alone
    local function changed(reason, group)
        if not started then return end
        dirty[group] = true
        ns.Events.Debounce("celebrations", Celebrations.DEBOUNCE, function() Celebrations.Check(reason) end)
    end
    ns.Events.On("AZF_READY", function()
        C_Timer.After(Celebrations.SETTLE, function() Celebrations.Check("first") end)
    end)
    ns.Events.On("AZF_EXPLORATION_UPDATED", function() changed("exploration", "zones") end)
    ns.Events.On("AZF_QUESTS_UPDATED", function() changed("quests", "zones") end)
    ns.Events.On("AZF_FLIGHTS_UPDATED", function() changed("flights", "zones") end)
    ns.Events.On("AZF_CLASS_UPDATED", function() changed("class", "class") end)
    ns.Events.On("AZF_PROFESSIONS_UPDATED", function() changed("professions", "prof") end)
    ns.Events.On("AZF_REPUTATION_UPDATED", function() changed("reputation", "rep") end)
end
