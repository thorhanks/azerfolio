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

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

local last          -- the last snapshot (nil until the first one)
local queue = {}    -- celebrations waiting for the window: { mapID, kind, zone = entry }

function Celebrations.Queue() return queue end -- for tests

-- The next waiting celebration (removed from the queue), or nil.
function Celebrations.Next() return table.remove(queue, 1) end

local function byMap(entries)
    local m = {}
    for _, z in ipairs(entries) do m[z.mapID] = z end
    return m
end

-- Hands one celebration on: played now with the window open, else an alert and queued.
function Celebrations.Announce(ev)
    queue[#queue + 1] = ev
    ns.Debug.Trace("celebrate", { mapID = ev.mapID, kind = ev.kind, shown = ns.UI and ns.UI.IsShown() or false })
    ns.Events.Send("AZF_CELEBRATE", ev)
end

function Celebrations.Check(reason)
    local entries = ns.Zones.All()
    local snap = Celebrations.Snapshot(entries)
    if last then
        local zones = byMap(entries)
        for _, ev in ipairs(Celebrations.Diff(last, snap)) do
            ev.zone = zones[ev.mapID]
            if ev.zone then Celebrations.Announce(ev) end
        end
    end
    last = snap
    ns.Debug.Trace("celebrations", { reason = reason, waiting = #queue })
end

-- Debug: plays a sample celebration for a zone (/azf debug celebrate <kind> [mapID]).
function Celebrations.Preview(kind, mapID)
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
    local function changed(reason)
        if not last then return end
        ns.Events.Debounce("celebrations", Celebrations.DEBOUNCE, function() Celebrations.Check(reason) end)
    end
    ns.Events.On("AZF_READY", function()
        C_Timer.After(Celebrations.SETTLE, function() Celebrations.Check("first") end)
    end)
    ns.Events.On("AZF_EXPLORATION_UPDATED", function() changed("exploration") end)
    ns.Events.On("AZF_QUESTS_UPDATED", function() changed("quests") end)
    ns.Events.On("AZF_FLIGHTS_UPDATED", function() changed("flights") end)
end
