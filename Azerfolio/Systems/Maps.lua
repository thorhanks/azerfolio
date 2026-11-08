-- Zone list from the client's map tree. Names and parents come from C_Map.GetMapInfo
-- [verified-ingame: 51 zone maps under Eastern Kingdoms 1415, Kalimdor 1414 and Azeroth 947].
-- No progress here; that is the progression service's job (Phase 5).
local _, ns = ...

local Maps = {}
ns.Maps = Maps

local ZONE, CONTINENT, WORLD = 3, 2, 1 -- Enum.UIMapType values [verified-ingame]
local SCAN_MAX = 3000                  -- the Phase 0 scan found every map below this
local CONTINENT_ORDER = { [1415] = 1, [1414] = 2 } -- Eastern Kingdoms, Kalimdor, then others
-- Maps of another type listed as zones anyway. Darkspear Islands (2524) is map type 6
-- [verified-ingame, /azfdiag questdb] but has 18 quests, so it's a quest-only zone (no
-- exploration achievement). Owner-approved 2026-11-08.
Maps.EXTRA_ZONES = { [2524] = true }

local cache

-- Pure: groups zones { mapID, name, parentMapID, parentName, parentType } into sections:
-- continents in a fixed order, then "Other places" for zones directly under the world map.
-- Zones without a continent or world parent (orphan maps) are dropped.
function Maps.Group(zones)
    local byParent, sections = {}, {}
    for _, z in ipairs(zones) do
        local key
        if z.parentType == CONTINENT then key = z.parentMapID
        elseif z.parentType == WORLD then key = "other" end
        if key then
            local s = byParent[key]
            if not s then
                s = { key = key, title = key == "other" and "Other places" or z.parentName, zones = {} }
                byParent[key] = s
                sections[#sections + 1] = s
            end
            s.zones[#s.zones + 1] = z
        end
    end
    local function rank(s)
        if s.key == "other" then return 1000 end
        return CONTINENT_ORDER[s.key] or 100
    end
    table.sort(sections, function(a, b)
        if rank(a) ~= rank(b) then return rank(a) < rank(b) end
        return tostring(a.title) < tostring(b.title)
    end)
    for _, s in ipairs(sections) do
        table.sort(s.zones, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            return a.mapID < b.mapID
        end)
    end
    return sections
end

-- Scans the client once (lazily) and returns the grouped sections.
function Maps.Sections()
    if cache then return cache end
    local started = type(debugprofilestop) == "function" and debugprofilestop() or nil
    local zones = {}
    if C_Map and type(C_Map.GetMapInfo) == "function" then
        local infos = {}
        local function info(id)
            if infos[id] == nil then
                local ok, v = pcall(C_Map.GetMapInfo, id)
                infos[id] = ok and v or false
            end
            return infos[id] or nil
        end
        for id = 1, SCAN_MAX do
            local m = info(id)
            if m and (m.mapType == ZONE or Maps.EXTRA_ZONES[id]) then
                local parent = m.parentMapID and m.parentMapID > 0 and info(m.parentMapID)
                zones[#zones + 1] = {
                    mapID = id, name = m.name,
                    parentMapID = m.parentMapID,
                    parentName = parent and parent.name,
                    parentType = parent and parent.mapType,
                }
            end
        end
    end
    cache = Maps.Group(zones)
    -- Once per session (first open): its cost goes to the debug trace (Phase 8 performance review).
    if ns.Debug then
        local ms = started and type(debugprofilestop) == "function" and (debugprofilestop() - started) or nil
        ns.Debug.Trace("maps", { zones = #zones, scanned = SCAN_MAX, ms = ms and math.floor(ms * 100 + 0.5) / 100 })
    end
    return cache
end
