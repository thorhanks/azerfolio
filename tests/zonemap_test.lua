-- The Exploration page's zone map (pure tile layout), on Elwynn's real returns
-- (/azfdiag mapart, Gideon, 2026-11-14).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/Systems/ZoneMap.lua", "Azerfolio", ns)
    return ns.ZoneMap
end

local LAYER = { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256, minScale = 1, maxScale = 2.14 }
local IDS = { 8061958, 8061962, 8061963, 8061964, 8061965, 8061966, 8061967, 8061968, 8061969, 8061959, 8061960, 8061961 }
local EXPLORED = {
    { offsetX = 577, offsetY = 419, textureWidth = 256, textureHeight = 249, fileDataIDs = { 8061955 } },
    { offsetX = 124, offsetY = 327, textureWidth = 256, textureHeight = 341, fileDataIDs = { 8061971, 8061972 } },
    { offsetX = 696, offsetY = 435, textureWidth = 306, textureHeight = 233, fileDataIDs = { 8061976, 8061977 } },
    { offsetX = 0, offsetY = 0, textureWidth = 512, textureHeight = 512, fileDataIDs = { 8061980, 8061981, 8061982, 8061983 } },
    { offsetX = 10, offsetY = 10, textureWidth = 256, textureHeight = 256, fileDataIDs = { 1 }, isShownByMouseOver = true },
}

return function(t)
    t.test("zonemap: the base layer is 4x3 tiles, the last column and row cropped to 1002x668", function()
        local tiles = load().BaseTiles(LAYER, IDS)
        t.eq(#tiles, 12)
        t.eq(tiles[1].fid, 8061958)
        local last = tiles[12]
        t.eq(last.x, 768); t.eq(last.y, 512); t.eq(last.w, 234); t.eq(last.h, 156)
        t.ok(math.abs(last.r - 234 / 256) < 1e-9 and math.abs(last.b - 156 / 256) < 1e-9, "texture coordinates crop the edge")
        t.eq(tiles[5].x, 0); t.eq(tiles[5].y, 256)
        t.eq(#load().BaseTiles(nil, IDS), 0)
        t.eq(#load().BaseTiles(LAYER, nil), 0)
    end)

    t.test("zonemap: explored pieces are cut into 256-unit files, cropped from power-of-two files", function()
        local p = load().Pieces(EXPLORED)
        t.eq(#p, 1 + 2 + 2 + 4, "the mouse-over piece is left out")
        t.eq(p[1].x, 577); t.eq(p[1].h, 249); t.ok(math.abs(p[1].b - 249 / 256) < 1e-9, "249 of a 256 file")
        t.eq(p[3].y, 327 + 256); t.eq(p[3].h, 85); t.ok(math.abs(p[3].b - 85 / 128) < 1e-9, "85 of a 128 file")
        t.eq(p[5].x, 696 + 256); t.eq(p[5].w, 50); t.ok(math.abs(p[5].r - 50 / 64) < 1e-9, "50 of a 64 file")
        t.eq(p[9].fid, 8061983); t.eq(p[9].x, 256); t.eq(p[9].y, 256)
        t.eq(#load().Pieces(nil), 0)
    end)

    t.test("zonemap: ForMap reads the client, and gives nil without base art", function()
        local Z = load()
        local saved, savedE = _G.C_Map, _G.C_MapExplorationInfo
        _G.C_Map = { GetMapArtLayers = function() return { LAYER } end, GetMapArtLayerTextures = function() return IDS end }
        _G.C_MapExplorationInfo = { GetExploredMapTextures = function() return EXPLORED end }
        local m = Z.ForMap(1429)
        t.eq(m.width, 1002); t.eq(m.height, 668); t.eq(#m.base, 12); t.eq(#m.pieces, 9)
        _G.C_Map = { GetMapArtLayers = function() error("boom") end }
        t.eq(Z.ForMap(1429), nil, "an error is no map")
        _G.C_Map = {}
        t.eq(Z.ForMap(1429), nil)
        _G.C_Map, _G.C_MapExplorationInfo = saved, savedE
    end)
end
