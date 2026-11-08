-- Exploration baseline and milestones (plan Phase 5 task 6).
-- The baseline remembers, per character and per zone, each area's last confirmed state
-- (true = discovered, false = not yet; unknown areas are not stored). A milestone is recorded
-- only for a confirmed transition, false -> true, so progress that existed before Azerfolio
-- first saw the zone never becomes a milestone. A zone milestone is recorded when a zone whose
-- baseline was confirmed not complete becomes tracked-complete.
-- Times: only a change seen live (by a discovery event) gets a time; a change found on a later
-- read (e.g. explored while the addon was off) has none, since nobody saw when it happened.
local _, ns = ...

local Milestones = {}
ns.Milestones = Milestones

-- Pure. zoneBase: { states = { [id] = bool }, complete = bool } or nil (zone never seen).
-- result: a tracked Exploration result. Returns the new zone baseline and the transitions:
-- { { kind = "area", id, name }, { kind = "zone" } }.
function Milestones.Compare(zoneBase, result)
    local first = zoneBase == nil
    local old = (zoneBase and zoneBase.states) or {}
    local states, found = {}, {}
    for id, v in pairs(old) do states[id] = v end
    for _, o in ipairs(result.objectives or {}) do
        local now
        if o.completion == "complete" then now = true elseif o.completion == "incomplete" then now = false end
        if now ~= nil then
            if not first and old[o.id] == false and now == true then
                found[#found + 1] = { kind = "area", id = o.id, name = o.name }
            end
            -- Discovery can't be undone; a later "not done" for a discovered area is ignored.
            if not (old[o.id] == true and now == false) then states[o.id] = now end
        end
    end
    local complete = result.progress and result.progress.trackedComplete == true
    local wasComplete = zoneBase and zoneBase.complete
    if not first and wasComplete == false and complete then found[#found + 1] = { kind = "zone" } end
    return { states = states, complete = complete or wasComplete == true }, found
end

local function key(m) return m.kind .. ":" .. m.category .. ":" .. tostring(m.id) end

-- Pure: appends milestones to `list` unless one with the same key is already there.
-- Returns the ones added.
function Milestones.Append(list, entries)
    local seen, added = {}, {}
    for _, m in ipairs(list) do
        if type(m) == "table" and m.kind and m.category then seen[key(m)] = true end
    end
    for _, m in ipairs(entries) do
        local k = key(m)
        if not seen[k] then
            seen[k] = true
            list[#list + 1] = m
            added[#added + 1] = m
        end
    end
    return added
end

-- Called by the tracker with every tracked read. `live` = the read was caused by a discovery
-- event, so the change happened just now.
function Milestones.Observe(result, live)
    local char = ns.charDB
    if not char or not result or result.status ~= "tracked" then return end
    local base = char.baseline
    local mapID = result.mapID
    local prev = base.exploration[mapID]
    -- A damaged entry is treated as never seen: no milestones from it.
    if type(prev) ~= "table" or type(prev.states) ~= "table" then prev = nil end
    local zoneBase, found = Milestones.Compare(prev, result)
    base.exploration[mapID] = zoneBase
    base.taken = true
    if #found == 0 then return end

    local now = live and type(time) == "function" and time() or nil
    local entries = {}
    for _, f in ipairs(found) do
        entries[#entries + 1] = {
            kind = f.kind, category = "exploration", mapID = mapID,
            id = f.kind == "area" and f.id or mapID, name = f.name,
            time = now, -- nil: the change wasn't seen when it happened
        }
    end
    local added = Milestones.Append(char.milestones, entries)
    ns.SavedVariables.TrimList(char.milestones, ns.Config.LIMITS.milestones)
    for _, m in ipairs(added) do
        ns.Debug.Trace("milestone", { what = m.kind, mapID = m.mapID, id = m.id, live = live == true,
            timed = m.time ~= nil })
        ns.Events.Send("AZF_MILESTONE", m)
    end
end

-- For the debug report: zones in the baseline, milestone count, newest milestones.
function Milestones.Summary(n)
    local char = ns.charDB
    if not char then return nil end
    local zones = 0
    for _ in pairs(char.baseline.exploration) do zones = zones + 1 end
    local list, recent = char.milestones, {}
    for i = #list, math.max(1, #list - (n or 3) + 1), -1 do recent[#recent + 1] = list[i] end
    return { zones = zones, count = #list, recent = recent }
end
