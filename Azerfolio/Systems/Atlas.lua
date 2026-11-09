-- The Atlas's places (mockups/DESIGN.md "Zones: Atlas", Phase 10). Where each zone sits comes
-- from the client: its rectangle on its continent (C_Map.GetMapRectOnMap) [verified-ingame,
-- /azfdiag zones]. Pure: Atlas.Layout turns rectangles into tiles of one size centred on each
-- zone's true centre, pushed apart until none overlap (the real rectangles overlap a lot), so
-- neighbours keep their direction and no name is covered. Live: Atlas.Places reads the
-- rectangles once per session. Zones without one (Zephras Isle) are "unplaced".
local _, ns = ...

local Atlas = {}
ns.Atlas = Atlas

-- Kalimdor on the left, the Eastern Kingdoms on the right (owner, 2026-11-08).
Atlas.CONTINENTS = { 1414, 1415 }
-- Tile size and gap in map units (x stretched 1.5: the rectangles are fractions of a 3:2 map).
Atlas.TILE = { w = 0.135, h = 0.082, gap = 0.01 }
Atlas.STRETCH = 1.5
Atlas.PASSES = 400

---------------------------------------------------------------------------------------------
-- Pure
---------------------------------------------------------------------------------------------

-- items: { { mapID, rect = { left, right, top, bottom } } } (one continent). Returns
--   { tiles = { { mapID, left, top, width, height } (fractions of the map, 0..1) }, ratio = w / h }
-- or nil for an empty list. The same input always gives the same layout (ordered by mapID).
function Atlas.Layout(items, tile)
    tile = tile or Atlas.TILE
    local list = {}
    for _, it in ipairs(items or {}) do
        local r = it.rect
        if type(r) == "table" and type(r[1]) == "number" and r[2] > r[1] and r[4] > r[3] then
            list[#list + 1] = { mapID = it.mapID, x = (r[1] + r[2]) / 2 * Atlas.STRETCH, y = (r[3] + r[4]) / 2,
                w = tile.w, h = tile.h }
        end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b) return a.mapID < b.mapID end)
    for _ = 1, Atlas.PASSES do
        local moved = false
        for i = 1, #list do
            for j = i + 1, #list do
                local A, B = list[i], list[j]
                local ox = (A.w + B.w) / 2 + tile.gap - math.abs(A.x - B.x)
                local oy = (A.h + B.h) / 2 + tile.gap - math.abs(A.y - B.y)
                if ox > 0 and oy > 0 then
                    moved = true
                    -- Apart along the axis that overlaps least, a quarter of the overlap each.
                    if ox < oy then
                        local s = A.x <= B.x and -1 or 1
                        A.x = A.x + s * ox / 4; B.x = B.x - s * ox / 4
                    else
                        local s = A.y <= B.y and -1 or 1
                        A.y = A.y + s * oy / 4; B.y = B.y - s * oy / 4
                    end
                end
            end
        end
        if not moved then break end
    end
    local l, r, t, b = math.huge, -math.huge, math.huge, -math.huge
    for _, p in ipairs(list) do
        l = math.min(l, p.x - p.w / 2); r = math.max(r, p.x + p.w / 2)
        t = math.min(t, p.y - p.h / 2); b = math.max(b, p.y + p.h / 2)
    end
    local w, h = r - l, b - t
    local tiles = {}
    for i, p in ipairs(list) do
        tiles[i] = { mapID = p.mapID, left = (p.x - p.w / 2 - l) / w, top = (p.y - p.h / 2 - t) / h,
            width = p.w / w, height = p.h / h }
    end
    return { tiles = tiles, ratio = w / h }
end

-- Pure: do any two tiles of a layout overlap? (For tests and the debug report.)
function Atlas.Overlaps(layout)
    local n = 0
    local ts = layout and layout.tiles or {}
    for i = 1, #ts do
        for j = i + 1, #ts do
            local a, b = ts[i], ts[j]
            if a.left < b.left + b.width - 1e-6 and b.left < a.left + a.width - 1e-6
                and a.top < b.top + b.height - 1e-6 and b.top < a.top + a.height - 1e-6 then n = n + 1 end
        end
    end
    return n
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

local rects -- [mapID] = { continent, rect } or false (no place), read once per session

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

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

local function readRect(mapID)
    if rects == nil then rects = {} end
    if rects[mapID] ~= nil then return rects[mapID] end
    local found = false
    local cont = continentOf(mapID)
    if cont and C_Map and type(C_Map.GetMapRectOnMap) == "function" then
        local l, r, t, b = try("GetMapRectOnMap", C_Map.GetMapRectOnMap, mapID, cont)
        if type(l) == "number" and type(r) == "number" and type(t) == "number" and type(b) == "number"
            and r > l and b > t then
            found = { continent = cont, rect = { l, r, t, b } }
        end
    end
    rects[mapID] = found
    return found
end

-- Where the given zone entries go: { layouts = { [continentID] = Layout result }, unplaced =
-- { entry, ... } }. Layouts are cached per set of zones (they only change when the set does).
local cache = {}
function Atlas.Places(entries)
    local by, keyParts, unplaced = {}, {}, {}
    for _, z in ipairs(entries or {}) do
        local p = readRect(z.mapID)
        if p then
            by[p.continent] = by[p.continent] or {}
            table.insert(by[p.continent], { mapID = z.mapID, rect = p.rect })
            keyParts[#keyParts + 1] = z.mapID
        else
            unplaced[#unplaced + 1] = z
        end
    end
    table.sort(keyParts)
    local key = table.concat(keyParts, ",")
    if not cache[key] then
        local layouts = {}
        for cont, items in pairs(by) do layouts[cont] = Atlas.Layout(items) end
        cache = { [key] = layouts } -- one set at a time is enough
    end
    return { layouts = cache[key], unplaced = unplaced }
end

-- For tests.
function Atlas.Reset() rects, cache = nil, {} end
