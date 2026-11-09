-- Flight paths per zone (spec §8.5, Phase 9 step 4).
--   Catalogue: the client's own node list, C_TaxiMap.GetTaxiNodesForMap(continent): every node
--   on the continent, both factions, { nodeID, name = "Place, Zone", faction = 0|1|2 }
--   [verified-ingame]. Data/FlightPaths.lua (curated) turns the zone part into a mapID.
--   Knowledge: only the flight master says what this character knows. While the flight map is
--   open (PLAYER_INTERACTION_MANAGER_FRAME_SHOW type 5 on Forever, not TAXIMAP_OPENED
--   [verified-ingame]) TaxiNodeGetType(i) is CURRENT / REACHABLE (known) or DISTANT (not
--   known) for this faction's nodes on this continent. That list is saved per character
--   (AzerfolioCharDB.flights[continentMapID]); a continent never seen at a flight master has
--   unknown flight paths, never "not discovered" (honest data).
-- Everything above "Live" is pure.
local _, ns = ...

local FlightPaths = {}
ns.FlightPaths = FlightPaths

FlightPaths.CATEGORY = "flights"
FlightPaths.CONTINENTS = { 1415, 1414 } -- Eastern Kingdoms, Kalimdor [verified-ingame]
FlightPaths.TAXI_INTERACTION = 5        -- Enum.PlayerInteractionType.TaxiNode [verified-ingame, sniffer]
FlightPaths.FACTION_ID = { Horde = 1, Alliance = 2 }
FlightPaths.READ_DELAY = 0.2            -- after the map opens, before reading its list [unverified]

-- Pure: "Sentinel Hill, Westfall" -> "Sentinel Hill", "Westfall". A name without a comma is
-- both the place and the zone ("Moonglade").
function FlightPaths.Split(name)
    if type(name) ~= "string" then return nil, nil end
    local place, zone = name:match("^(.-),%s*([^,]+)$")
    if not place then return name, name end
    return place, zone
end

-- Pure: the mapID a node belongs to, or nil (unknown zone part, excluded or obsolete node).
function FlightPaths.ZoneOf(node, data)
    if type(node) ~= "table" or type(node.name) ~= "string" then return nil end
    data = data or {}
    local id = node.nodeID
    if data.excluded and data.excluded[id] then return nil end
    if data.obsoletePrefix and node.name:sub(1, #data.obsoletePrefix) == data.obsoletePrefix then return nil end
    if data.overrides and data.overrides[id] then return data.overrides[id] end
    local _, zone = FlightPaths.Split(node.name)
    return data.zones and data.zones[zone] or nil
end

-- Pure: nodes (merged across continents) grouped by zone, each list sorted by name.
--   nodes: { { nodeID, name, faction, continent } }; returns { [mapID] = { node... } }, unmapped
--   (names of real nodes whose zone the data doesn't know).
function FlightPaths.Catalogue(nodes, data)
    local byZone, unmapped, seen = {}, {}, {}
    for _, n in ipairs(nodes or {}) do
        if type(n) == "table" and type(n.nodeID) == "number" and not seen[n.nodeID] then
            seen[n.nodeID] = true
            local mapID = FlightPaths.ZoneOf(n, data)
            if mapID then
                local place = FlightPaths.Split(n.name)
                local list = byZone[mapID] or {}
                byZone[mapID] = list
                list[#list + 1] = { nodeID = n.nodeID, name = n.name, place = place, faction = n.faction,
                    continent = n.continent }
            elseif type(n.name) == "string" and not (data and data.excluded and data.excluded[n.nodeID])
                and not (data and data.obsoletePrefix and n.name:sub(1, #data.obsoletePrefix) == data.obsoletePrefix) then
                unmapped[#unmapped + 1] = n.name
            end
        end
    end
    for _, list in pairs(byZone) do
        table.sort(list, function(a, b) if a.place ~= b.place then return a.place < b.place end return a.nodeID < b.nodeID end)
    end
    table.sort(unmapped)
    return byZone, unmapped
end

-- Pure: the flight master's list -> a saved record. entries: { { name, type } }.
--   { time, nodes = { [name] = "known" | "distant" } }; types other than CURRENT, REACHABLE and
--   DISTANT are left out.
local KNOWN = { CURRENT = "known", REACHABLE = "known", DISTANT = "distant" }
function FlightPaths.Record(entries, time)
    local r = { time = time, nodes = {} }
    for _, e in ipairs(entries or {}) do
        local s = type(e) == "table" and type(e.name) == "string" and KNOWN[e.type]
        if s then r.nodes[e.name] = s end
    end
    return r
end

-- Pure: one zone's flight paths for this character.
--   nodes: the zone's catalogue list; record: the saved list for their continent (or nil);
--   factionID: 1 Horde, 2 Alliance (nil = unknown).
-- Returns { status, mapID, objectives, progress, count }:
--   "ready"   the flight master's list is known: objectives = this faction's nodes it listed
--   "pending" never seen at a flight master: objectives with completion unknown (no counts)
--   "none"    no flight path here for this character
function FlightPaths.Evaluate(mapID, nodes, record, factionID)
    local O = ns.Objectives
    local objectives = {}
    for _, n in ipairs(nodes or {}) do
        local mine = n.faction == 0 or (factionID ~= nil and n.faction == factionID)
        if mine then
            local completion
            if record then
                local s = record.nodes and record.nodes[n.name]
                completion = s == "known" and O.COMPLETE or (s == "distant" and O.INCOMPLETE or nil)
            else
                completion = O.UNKNOWN
            end
            -- With a record, a node it doesn't list isn't available to this character: left out.
            if completion then
                objectives[#objectives + 1] = O.New({ id = n.nodeID, category = FlightPaths.CATEGORY, zone = mapID,
                    name = n.place, completion = completion, eligibility = O.ELIGIBLE, source = "flightmaster" })
            end
        end
    end
    if #objectives == 0 then return { status = "none", mapID = mapID, objectives = objectives, count = 0 } end
    local progress = ns.Progression.Aggregate({ { category = FlightPaths.CATEGORY, coverage = record and "complete" or "unavailable",
        objectives = objectives } })
    return { status = record and "ready" or "pending", mapID = mapID, objectives = objectives, progress = progress,
        count = #objectives, seen = record and record.time or nil }
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

local catalogue, unmapped   -- built once per session from the client
local results = {}          -- [mapID] = Evaluate result

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

local function readCatalogue()
    if catalogue then return catalogue end
    local nodes = {}
    local T = C_TaxiMap
    if T and type(T.GetTaxiNodesForMap) == "function" then
        for _, continent in ipairs(FlightPaths.CONTINENTS) do
            local list = try("GetTaxiNodesForMap", T.GetTaxiNodesForMap, continent)
            for _, n in ipairs(type(list) == "table" and list or {}) do
                if type(n) == "table" then
                    nodes[#nodes + 1] = { nodeID = n.nodeID, name = n.name, faction = n.faction, continent = continent }
                end
            end
        end
    end
    catalogue, unmapped = FlightPaths.Catalogue(nodes, ns.FlightPathData)
    ns.Debug.Trace("flights", { catalogue = #nodes, unmapped = unmapped })
    return catalogue
end

local function saved()
    local c = ns.charDB
    if not c then return {} end
    if type(c.flights) ~= "table" then c.flights = {} end
    return c.flights
end

-- The continent a map lies on (walks the parents), or nil.
local function continentOf(mapID)
    local guard = 0
    while type(mapID) == "number" and mapID > 0 and guard < 10 do
        local info = C_Map and type(C_Map.GetMapInfo) == "function" and try("GetMapInfo", C_Map.GetMapInfo, mapID)
        if not info then return nil end
        if info.mapType == 2 then return mapID end
        mapID, guard = info.parentMapID, guard + 1
    end
    return nil
end

-- A zone's flight paths (see Evaluate). Without the client's node API: { status = "unavailable" }.
function FlightPaths.ForZone(zone)
    local mapID = type(zone) == "table" and zone.mapID or zone
    if results[mapID] then return results[mapID] end
    if not (C_TaxiMap and type(C_TaxiMap.GetTaxiNodesForMap) == "function") then
        return { status = "unavailable", mapID = mapID, count = 0 }
    end
    local nodes = readCatalogue()[mapID]
    local continent = nodes and nodes[1] and nodes[1].continent
    local record = continent and saved()[continent] or nil
    local c = ns.character or {}
    local r = FlightPaths.Evaluate(mapID, nodes, record, FlightPaths.FACTION_ID[c.faction])
    results[mapID] = r
    return r
end

function FlightPaths.Invalidate() results = {} end

-- Every zone together (the Overview's tracked completion). Only zones whose continent's flight
-- master list is known count; the others are listed by continent so the UI can say why.
--   { status = "ready"|"pending"|"none"|"unavailable", progress (ready zones' Aggregate or nil),
--     zones = zones counted, unread = { continent mapID, ... } (sorted) }
function FlightPaths.Overall()
    if not (C_TaxiMap and type(C_TaxiMap.GetTaxiNodesForMap) == "function") then
        return { status = "unavailable", zones = 0, unread = {} }
    end
    local sets, zones, unread, seen = {}, 0, {}, {}
    for mapID, nodes in pairs(readCatalogue()) do
        local r = FlightPaths.ForZone(mapID)
        if r.status == "ready" then
            zones = zones + 1
            sets[#sets + 1] = { category = FlightPaths.CATEGORY, coverage = "complete", objectives = r.objectives }
        elseif r.status == "pending" then
            local c = nodes[1] and nodes[1].continent
            if c and not seen[c] then seen[c] = true; unread[#unread + 1] = c end
        end
    end
    table.sort(unread)
    local status = zones > 0 and "ready" or (#unread > 0 and "pending" or "none")
    return { status = status, progress = zones > 0 and ns.Progression.Aggregate(sets) or nil, zones = zones, unread = unread }
end

-- Reads the open flight map's list and saves it for the player's continent.
function FlightPaths.ReadMaster(reason)
    local n = try("NumTaxiNodes", NumTaxiNodes)
    if type(n) ~= "number" or n <= 0 then return end
    local entries = {}
    for i = 1, n do
        entries[i] = { name = try("TaxiNodeName", TaxiNodeName, i), type = try("TaxiNodeGetType", TaxiNodeGetType, i) }
    end
    local here = C_Map and type(C_Map.GetBestMapForUnit) == "function" and try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local continent = continentOf(here)
    if not continent then
        ns.Debug.Trace("flights", { master = n, reason = reason, err = "continent unknown", map = here })
        return
    end
    local record = FlightPaths.Record(entries, type(time) == "function" and time() or nil)
    local known, listed = 0, 0
    for _, s in pairs(record.nodes) do listed = listed + 1; if s == "known" then known = known + 1 end end
    saved()[continent] = record
    FlightPaths.Invalidate()
    ns.Debug.Trace("flights", { master = n, reason = reason, continent = continent, listed = listed, known = known })
    ns.Events.Send("AZF_FLIGHTS_UPDATED", continent)
end

local function onOpen(reason)
    if C_Timer and C_Timer.After then
        C_Timer.After(FlightPaths.READ_DELAY, function() FlightPaths.ReadMaster(reason) end)
    else
        FlightPaths.ReadMaster(reason)
    end
end

ns.Events.Register("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if kind == FlightPaths.TAXI_INTERACTION then onOpen("interaction") end
end)
ns.Events.Register("TAXIMAP_OPENED", function() onOpen("TAXIMAP_OPENED") end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() FlightPaths.Invalidate() end)

-- /azf debug flights: the catalogue per zone and what this character is known to know.
function FlightPaths.DebugReport()
    readCatalogue()
    local lines, zones = {}, 0
    for mapID in pairs(catalogue) do
        local r = FlightPaths.ForZone(mapID)
        if r.count and r.count > 0 then
            zones = zones + 1
            local p = r.progress
            local names = {}
            for _, o in ipairs(r.objectives) do names[#names + 1] = o.name .. (o.completion == "complete" and "+" or (o.completion == "unknown" and "?" or "-")) end
            lines[#lines + 1] = string.format("%d %s %s/%s %s", mapID, r.status, p and p.completed or "-", p and p.denominator or "-",
                table.concat(names, ", "))
        end
    end
    table.sort(lines)
    local seen = {}
    for continent, rec in pairs(saved()) do seen[#seen + 1] = string.format("%s at %s", tostring(continent), tostring(rec.time)) end
    ns.Printf("Flight paths: %d zones with flight paths for you; flight masters seen: %s; unmapped nodes: %d",
        zones, #seen > 0 and table.concat(seen, ", ") or "none", #unmapped)
    ns.Debug.Trace("flights", { report = true, zones = lines, seen = seen, unmapped = unmapped })
end
