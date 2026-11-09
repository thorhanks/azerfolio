-- The Atlas layout (pure): tiles at each zone's true centre, pushed apart until none overlap.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/Systems/Atlas.lua", "Azerfolio", ns)
    return ns.Atlas
end

-- The Eastern Kingdoms' zones and cities, as the client gave them (/azfdiag zones, 2026-11-08).
local EK = {
    { 1416, 0.4323, 0.5118, 0.2543, 0.3338 }, { 1417, 0.4792, 0.5814, 0.3239, 0.4261 }, { 1418, 0.5136, 0.5843, 0.5692, 0.6398 },
    { 1419, 0.4898, 0.5850, 0.7685, 0.8636 }, { 1420, 0.3684, 0.4967, 0.1546, 0.2830 }, { 1421, 0.3565, 0.4759, 0.2472, 0.3665 },
    { 1422, 0.4427, 0.5649, 0.1747, 0.2969 }, { 1423, 0.5186, 0.6409, 0.1609, 0.2830 }, { 1424, 0.4242, 0.5152, 0.3011, 0.3920 },
    { 1425, 0.4993, 0.6087, 0.2557, 0.3651 }, { 1426, 0.4034, 0.5433, 0.4834, 0.6233 }, { 1427, 0.4637, 0.5271, 0.5781, 0.6415 },
    { 1428, 0.4621, 0.5453, 0.6178, 0.7010 }, { 1429, 0.4109, 0.5095, 0.6565, 0.7551 }, { 1430, 0.4782, 0.5492, 0.7386, 0.8097 },
    { 1431, 0.4309, 0.5076, 0.7322, 0.8089 }, { 1432, 0.5112, 0.5895, 0.5094, 0.5878 }, { 1433, 0.5023, 0.5640, 0.6836, 0.7453 },
    { 1434, 0.3915, 0.5727, 0.7941, 0.9754 }, { 1435, 0.5177, 0.5829, 0.7282, 0.7933 }, { 1436, 0.3688, 0.4683, 0.7187, 0.8182 },
    { 1437, 0.4656, 0.5831, 0.4097, 0.5272 }, { 1453, 0.4056, 0.4550, 0.6589, 0.7083 }, { 1455, 0.4748, 0.4973, 0.5129, 0.5354 },
    { 1458, 0.4297, 0.4570, 0.2382, 0.2654 }, { 2548, 0.5083, 0.6461, 0.5937, 0.7315 },
}
local function items(list)
    local out = {}
    for i, r in ipairs(list) do out[i] = { mapID = r[1], rect = { r[2], r[3], r[4], r[5] } } end
    return out
end
local function find(layout, mapID)
    for _, t in ipairs(layout.tiles) do if t.mapID == mapID then return t end end
end

return function(t)
    t.test("atlas: the client's real rectangles end with no two tiles overlapping", function()
        local A = load()
        local raw = 0
        for i = 1, #EK do for j = i + 1, #EK do
            local a, b = EK[i], EK[j]
            if a[2] < b[3] and b[2] < a[3] and a[4] < b[5] and b[4] < a[5] then raw = raw + 1 end
        end end
        t.ok(raw > 10, "the real rectangles overlap a lot (" .. raw .. " pairs)")
        local L = A.Layout(items(EK))
        t.eq(#L.tiles, #EK)
        t.eq(A.Overlaps(L), 0)
        for _, tl in ipairs(L.tiles) do
            t.ok(tl.left >= -1e-9 and tl.top >= -1e-9 and tl.left + tl.width <= 1 + 1e-9 and tl.top + tl.height <= 1 + 1e-9,
                "inside the map: " .. tl.mapID)
        end
        t.ok(L.ratio > 0.3 and L.ratio < 1, "a tall continent")
    end)

    t.test("atlas: neighbours keep their direction", function()
        local L = load().Layout(items(EK))
        local elwynn, westfall, duskwood = find(L, 1429), find(L, 1436), find(L, 1431)
        local dunMorogh, tirisfal = find(L, 1426), find(L, 1420)
        t.ok(westfall.left < elwynn.left, "Westfall west of Elwynn")
        t.ok(duskwood.top > elwynn.top, "Duskwood south of Elwynn")
        t.ok(dunMorogh.top < elwynn.top, "Dun Morogh north of Elwynn")
        t.ok(tirisfal.top < dunMorogh.top, "Tirisfal far north")
    end)

    t.test("atlas: the same zones always give the same layout, in any order; nothing gives nil", function()
        local A = load()
        local a = A.Layout(items(EK))
        local rev = items(EK)
        for i = 1, math.floor(#rev / 2) do rev[i], rev[#rev + 1 - i] = rev[#rev + 1 - i], rev[i] end
        local b = A.Layout(rev)
        for _, tl in ipairs(a.tiles) do
            local o = find(b, tl.mapID)
            t.ok(math.abs(o.left - tl.left) < 1e-9 and math.abs(o.top - tl.top) < 1e-9, "same place: " .. tl.mapID)
        end
        t.eq(A.Layout({}), nil)
        t.eq(A.Layout({ { mapID = 1, rect = { 0, 0, 0, 0 } } }), nil, "an empty rectangle has no place")
    end)
end
