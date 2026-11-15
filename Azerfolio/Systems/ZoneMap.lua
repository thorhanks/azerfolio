-- The zone map on the Exploration page (Phase 15 step 6, R8; mockups/DESIGN.md "Zone Detail"):
-- the client's own base map tiles (C_Map.GetMapArtLayers / GetMapArtLayerTextures) and the
-- explored overlays (C_MapExplorationInfo.GetExploredMapTextures), laid out in map units
-- (1002x668 on Forever). Probed 2026-11-14 (`/azfdiag mapart`, WoWScrnShot_111426_204830): both
-- draw in an addon frame by file ID [verified-ingame].
--
-- Display only. The explored overlays don't match the achievement's criteria (more pieces than
-- areas; a piece in zones never visited; docs/research/client-capabilities.md), so nothing
-- here counts toward progress: the page's counts come from ns.Exploration.
--
-- BaseTiles and Pieces are pure (tests load them); ForMap reads the client, guarded.
local _, ns = ...
ns = ns or {}

local ZoneMap = {}
ns.ZoneMap = ZoneMap

ZoneMap.W, ZoneMap.H = 1002, 668 -- the classic zone map's size, when the client gives none
local PIECE_TILE = 256           -- explored overlays are cut into 256-unit files

local function pow2(n) local p = 1 while p < n do p = p * 2 end return p end

local function num(v, default) return type(v) == "number" and v > 0 and v or default end

-- The base layer's tiles, row by row: { fid, x, y, w, h, r, b } in map units (r, b: the
-- texture coordinates that crop the last column and row to the layer's edge).
function ZoneMap.BaseTiles(layer, ids)
    local out = {}
    if type(layer) ~= "table" or type(ids) ~= "table" then return out end
    local tw, th = num(layer.tileWidth, 256), num(layer.tileHeight, 256)
    local lw, lh = num(layer.layerWidth, ZoneMap.W), num(layer.layerHeight, ZoneMap.H)
    local cols = math.ceil(lw / tw)
    for i, fid in ipairs(ids) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local w, h = math.min(tw, lw - col * tw), math.min(th, lh - row * th)
        if w > 0 and h > 0 then
            out[#out + 1] = { fid = fid, x = col * tw, y = row * th, w = w, h = h, r = w / tw, b = h / th }
        end
    end
    return out
end

-- The explored overlays as tiles: each piece is cut into 256-unit files, row by row; the last
-- column and row are cropped from a power-of-two file. Pieces shown only on mouse-over are left
-- out (none on Forever's Elwynn or Alterac, probed 2026-11-14).
function ZoneMap.Pieces(explored)
    local out = {}
    for _, e in ipairs(type(explored) == "table" and explored or {}) do
        local tw, th = num(e.textureWidth, 0), num(e.textureHeight, 0)
        local fids = type(e.fileDataIDs) == "table" and e.fileDataIDs or {}
        if not e.isShownByMouseOver and tw > 0 and th > 0 then
            local wide, high = math.ceil(tw / PIECE_TILE), math.ceil(th / PIECE_TILE)
            for j = 1, high do
                local ph = (j < high) and PIECE_TILE or (th - PIECE_TILE * (j - 1))
                for k = 1, wide do
                    local pw = (k < wide) and PIECE_TILE or (tw - PIECE_TILE * (k - 1))
                    local fid = fids[(j - 1) * wide + k]
                    if fid then
                        out[#out + 1] = { fid = fid, x = (e.offsetX or 0) + PIECE_TILE * (k - 1),
                            y = (e.offsetY or 0) + PIECE_TILE * (j - 1), w = pw, h = ph,
                            r = pw / pow2(pw), b = ph / pow2(ph) }
                    end
                end
            end
        end
    end
    return out
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

-- The map of `mapID`: { width, height, base = tiles, pieces = tiles }, or nil when the client
-- gives no base art (then the page shows the checklist alone).
function ZoneMap.ForMap(mapID)
    local C = C_Map
    if not (mapID and type(C) == "table") then return nil end
    local layers = call(C.GetMapArtLayers, mapID)
    local layer = type(layers) == "table" and layers[1]
    if type(layer) ~= "table" then return nil end
    local base = ZoneMap.BaseTiles(layer, call(C.GetMapArtLayerTextures, mapID, 1))
    if #base == 0 then return nil end
    local E = C_MapExplorationInfo
    local explored = type(E) == "table" and call(E.GetExploredMapTextures, mapID) or nil
    return { width = num(layer.layerWidth, ZoneMap.W), height = num(layer.layerHeight, ZoneMap.H),
        base = base, pieces = ZoneMap.Pieces(explored) }
end

return ZoneMap
