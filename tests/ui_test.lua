-- Main window, tabs, geometry, gamepad layer and /azf shots, against the mock client.
local wow = require("mocks.wow")

local padUI = true

-- A slice of the real map tree (Phase 0 dump): world, two continents, zones, an orphan.
local MAPS = {
    [947] = { name = "Azeroth", mapType = 1, parentMapID = 0 },
    [1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 },
    [1415] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
    [1411] = { name = "Durotar", mapType = 3, parentMapID = 1414 },
    [1438] = { name = "Teldrassil", mapType = 3, parentMapID = 1414 },
    [1429] = { name = "Elwynn Forest", mapType = 3, parentMapID = 1415 },
    [1426] = { name = "Dun Morogh", mapType = 3, parentMapID = 1415 },
    [1436] = { name = "Westfall", mapType = 3, parentMapID = 1415 },
    [2521] = { name = "Zephras Isle", mapType = 3, parentMapID = 947 },
    [2665] = { name = "Zephras Isle", mapType = 3, parentMapID = 0 },
}

-- Explore achievements (category 14777 = Eastern Kingdoms), shaped like the real API.
local ACH = {
    [14777] = { { id = 776, name = "Explore Elwynn Forest" }, { id = 627, name = "Explore Dun Morogh" } },
    [14778] = { { id = 728, name = "Explore Durotar" } },
}
local CRITERIA = {
    [776] = { { "Northshire Valley", true, 1146 }, { "Goldshire", true, 1147 }, { "Fargodeep Mine", false, 1148 },
        { "Crystal Lake", false, 1149 }, { "Tower of Azora", false, 1150 } },
    [627] = { { "Coldridge Valley", true, 1200 } },
    [728] = { { "Valley of Trials", false, 1300 } },
}
local achievementsReady = true
local here = 1429 -- the player's map

local function boot(savedAccount, savedChar)
    wow.install({
        C_Map = { GetMapInfo = function(id) return MAPS[id] end, GetBestMapForUnit = function() return here end },
        GetCategoryNumAchievements = function(cat) return achievementsReady and #(ACH[cat] or {}) or 0 end,
        GetAchievementInfo = function(cat, i) local a = ACH[cat] and ACH[cat][i]; if a then return a.id, a.name end end,
        GetAchievementNumCriteria = function(id) return achievementsReady and #(CRITERIA[id] or {}) or 0 end,
        GetAchievementCriteriaInfo = function(id, i)
            local c = CRITERIA[id][i]
            return c[1], 43, c[2], c[2] and 1 or 0, 1, "", 0, 0, "", c[3], true
        end,
        UnitName = function() return "Gideon" end,
        UnitFactionGroup = function() return "Alliance", "Alliance" end,
        UnitLevel = function() return 9 end,
        UnitXP = function() return 273 end,
        UnitXPMax = function() return 6500 end,
        GetMaxPlayerLevel = function() return 60 end,
        GetZoneText = function() return "Elwynn Forest" end,
        GetSubZoneText = function() return "Goldshire" end,
        InputUtil = { IsGamepadUIEnabled = function() return padUI end },
        Screenshot = function() _G.screenshotsTaken = (_G.screenshotsTaken or 0) + 1 end,
    })
    _G.AzerfolioDB, _G.AzerfolioCharDB = savedAccount, savedChar
    _G.screenshotsTaken = 0
    local ns = wow.loadToc("Azerfolio", "Azerfolio")
    wow.fire("ADDON_LOADED", "Azerfolio")
    wow.fire("PLAYER_LOGIN")
    -- Quest detection normally runs 5 s after AZF_READY; here, at once (no QuestieDB in these
    -- tests: quests are "unavailable" and left out of zone progress).
    if ns.Quests then ns.Quests.Start() end
    return ns
end

local function slash(input) _G.SlashCmdList.AZERFOLIO(input) end
local function press(ns, button) ns.Gamepad.GetInputFrame().scripts.OnGamePadButtonDown(nil, button) end

return function(t)
    t.test("ClampGeometry keeps an on-screen window as it is", function()
        local ns = boot()
        local x, y, w, h = ns.UI.ClampGeometry(100, -50, 1160, 740, 1835, 768, 1000, 640)
        t.eq(x, 100); t.eq(y, -6, "pulled up just enough: 740 tall in 752 usable"); t.eq(w, 1160); t.eq(h, 740)
    end)

    t.test("ClampGeometry recovers an off-screen window", function()
        local ns = boot()
        local x, y = ns.UI.ClampGeometry(5000, -5000, 1160, 700, 1835, 768, 1000, 640)
        t.ok(x > 0 and x + 1160 / 2 <= 1835 / 2, "right edge on screen: " .. x)
        t.ok(y < 0 and -y + 700 / 2 <= 768 / 2, "bottom edge on screen: " .. y)
    end)

    t.test("ClampGeometry shrinks a window larger than the screen and grows a tiny one", function()
        local ns = boot()
        local x, y, w, h = ns.UI.ClampGeometry(0, 0, 1800, 1100, 1024, 768, 1000, 640)
        t.eq(w, 1024 - 16); t.eq(h, 768 - 16); t.eq(x, 0); t.eq(y, 0)
        local _, _, w2, h2 = ns.UI.ClampGeometry(0, 0, 200, 100, 1835, 768, 1000, 640)
        t.eq(w2, 1000); t.eq(h2, 640)
    end)

    t.test("ClampGeometry keeps the side tabs and legend box on screen", function()
        local ns = boot()
        local out = { left = 8, right = 64, top = 8, bottom = 50 }
        local x, y = ns.UI.ClampGeometry(5000, -5000, 1160, 640, 1835, 768, 1000, 640, out)
        t.ok(x + 1160 / 2 + 64 <= 1835 / 2 - 8, "tabs on screen: " .. x)
        t.ok(y - 640 / 2 - 50 >= -768 / 2 + 8, "legend on screen: " .. y)
        local _, _, w, h = ns.UI.ClampGeometry(0, 0, 1800, 1100, 1835, 768, 1000, 640, out)
        t.eq(w, 1835 - 16 - 72); t.eq(h, 768 - 16 - 58)
    end)

    t.test("the window is the native PortraitFrameTemplate with title and portrait", function()
        local ns = boot()
        slash("")
        local f = ns.UI.GetFrame()
        t.eq(f.template, "PortraitFrameTemplate")
        t.eq(f.title, "Azerfolio")
        t.ok(f.portrait == f.PortraitContainer.portrait, "portrait texture found")
        f.CloseButton.scripts.OnClick(f.CloseButton)
        t.eq(ns.UI.IsShown(), false, "the template's close button closes")
    end)

    t.test("the focus glow shows only while the controller drives the window", function()
        padUI = true
        local ns = boot()
        slash("")
        local f = ns.UI.GetFrame()
        t.eq(f.FrameGlow:IsShown(), true)
        wow.fire("PLAYER_REGEN_DISABLED")
        t.eq(f.FrameGlow:IsShown(), false, "off in combat")
        wow.fire("PLAYER_REGEN_ENABLED")
        t.eq(f.FrameGlow:IsShown(), true)
    end)

    t.test("glyphs use the client's atlas when it exists, a drawn disc otherwise", function()
        local ns = boot()
        _G.C_Texture = { GetAtlasInfo = function(name)
            if name == "Gamepad-Xbox1-Trigger-LB-Normal" or name == "gamepad-xbox1-buttona-normal" then return { width = 34 } end
        end }
        t.eq(ns.Theme.GlyphAtlas("LB"), "Gamepad-Xbox1-Trigger-LB-Normal")
        t.eq(ns.Theme.GlyphAtlas("A"), "gamepad-xbox1-buttona-normal")
        t.eq(ns.Theme.GlyphAtlas("B"), false, "no candidate: drawn")
        local g = ns.Theme.Glyph(_G.UIParent, "B")
        t.eq(g.label:IsShown(), true); t.eq(g.art:IsShown(), false)
        local a = ns.Theme.Glyph(_G.UIParent, "A")
        t.eq(a.art:IsShown(), true); t.eq(a.label:IsShown(), false)
        _G.C_Texture = nil
    end)

    t.test("zones are grouped by continent (EK, Kalimdor, other), sorted, orphans dropped", function()
        local ns = boot()
        local s = ns.Maps.Sections()
        t.eq(#s, 3)
        t.eq(s[1].title, "Eastern Kingdoms"); t.eq(s[2].title, "Kalimdor"); t.eq(s[3].title, "Other places")
        t.eq(s[1].zones[1].name, "Dun Morogh"); t.eq(s[1].zones[3].name, "Westfall")
        t.eq(#s[3].zones, 1, "the parentless Zephras Isle duplicate is dropped")
        t.eq(s[3].zones[1].mapID, 2521)
    end)

    t.test("D-pad moves focus through the zone list; info line follows", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list" } })
        slash("")
        local info = function() return ns.UI.GetFrame().legend.info:GetText() end
        t.eq(ns.Focus.Current().title, "Dun Morogh", "starts on the first zone, not the toolbar")
        t.ok(info():find("Dun Morogh"), info())
        t.eq(ns.Focus.pointer:IsShown(), true, "chevron shown")
        press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Elwynn Forest")
        t.ok(info():find("Eastern Kingdoms") and info():find("Levels 1%-10 %(guide%)")
            and info():find("Exploration 2 of 5"), info())
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "Westfall", "RT: next section (Levels 10-20)")
        press(ns, "PADLTRIGGER")
        t.eq(ns.Focus.Current().title, "Dun Morogh", "LT: previous section")
        press(ns, "PADDUP")
        t.eq(ns.Focus.Current().title, "All", "up from the first zone reaches the toolbar")
        press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().title, "In progress")
        t.eq(#ns.Debug.errors, 0)
    end)

    local function page(ns) return ns.UI.GetFrame().pages.zones end
    local function shown(ns)
        local out = {}
        for _, z in ipairs(page(ns).catalogue.query.zones) do out[#out + 1] = z.name end
        return table.concat(out, ",")
    end

    t.test("catalogue: cards by default, four to a row at the default size, grouped by level", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { faction = "all" } })
        slash("")
        local cat = page(ns).catalogue
        t.eq(cat:View(), "cards")
        t.eq(cat.columns, 4)
        local rows = page(ns):GetFocusRows()
        t.eq(#rows[1].items, 10, "toolbar: 4 segments, Show, Level, Sort, search, Cards, List")
        t.eq(#rows[2].items, 4, "first card row")
        t.eq(rows[2].items[1].title, "Dun Morogh"); t.eq(rows[2].items[4].title, "Teldrassil")
        t.eq(rows[3].items[1].title, "Zephras Isle", "the bracket's fifth zone wraps")
        t.eq(cat.headers[1].text:GetText(), "Levels 1-10")
        t.eq(cat.headers[1].count:GetText(), "1 of 4 complete", "Dun Morogh; Zephras Isle isn't tracked")
        local c = cat.byMap[1429]
        t.eq(c.pct:GetText(), "40%"); t.eq(c.bars.slots[1].count:GetText(), "2/5", "exploration bar")
        t.eq(c.bars.slots[2]:IsShown(), false, "no quests (no QuestieDB): slot left empty, not 0")
        t.eq(c.lv:GetText(), "Lv 1-10")
        t.eq(c.fac:GetText(), "Alliance"); t.eq(cat.byMap[1411].fac:GetText(), "Horde")
        t.eq(cat.byMap[2521].fac:GetText(), "", "Zephras Isle: contested isn't shown on cards")
        t.eq(c.fit:IsShown(), true, "level 9 fits 1-10")
        t.eq(cat.byMap[1426].emblem:IsShown(), true, "complete: emblem")
        t.eq(cat.byMap[1436].pct:GetText(), "?", "Westfall: no data is not 0%")
        t.eq(cat.byMap[2521].n:GetText(), "not tracked"); t.eq(cat.byMap[2521].pct:GetText(), "-")
        t.eq(cat.count:GetText(), "6 zones")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("catalogue: Y switches Cards and List and the choice is saved", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        press(ns, "PAD4")
        t.eq(ns.db.zones.displayMode, "list")
        t.eq(page(ns).catalogue:View(), "list")
        t.eq(ns.Focus.Current().title, "Dun Morogh", "focus kept")
        t.eq(#page(ns):GetFocusRows()[2].items, 1, "one zone per row")
        press(ns, "PAD4")
        t.eq(ns.db.zones.displayMode, "cards")
        local ns2 = boot(_G.AzerfolioDB, _G.AzerfolioCharDB)
        t.eq(ns2.db.zones.displayMode, "cards", "persists")
    end)

    t.test("catalogue: status segments filter and are saved; unknown zones only under All", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list", faction = "all" } })
        slash("")
        local cat = page(ns).catalogue
        cat.status[2].item.onActivate(cat.status[2].item) -- In progress
        t.eq(ns.db.zones.completion, "progress")
        t.eq(shown(ns), "Elwynn Forest")
        t.eq(cat.count:GetText(), "1 of 6 zones")
        t.eq(cat.status[2].on, true); t.eq(cat.status[1].on, false)
        cat.status[3].item.onActivate(cat.status[3].item) -- Untouched
        t.eq(shown(ns), "Durotar", "Westfall (no data) and Teldrassil (no data) aren't untouched")
        cat.status[4].item.onActivate(cat.status[4].item)
        t.eq(shown(ns), "Dun Morogh")
        cat.status[1].item.onActivate(cat.status[1].item)
        t.eq(page(ns).catalogue.query.shown, 6)
    end)

    t.test("catalogue: Sort popup with the controller; B closes it, A picks", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list", faction = "all" } })
        slash("")
        local p, cat = page(ns), page(ns).catalogue
        ns.Focus.FocusKey("tb:sort")
        press(ns, "PAD1")
        t.eq(p.popup:IsShown(), true)
        t.eq(ns.Focus.Current().key, "pop:recommended", "opens on the current choice")
        t.eq(p.hasSections, false)
        press(ns, "PAD2")
        t.eq(p.popup:IsShown(), false, "B closes the popup")
        t.eq(ns.UI.IsShown(), true, "the window stays open")
        t.eq(ns.Focus.Current().key, "tb:sort", "focus back on Sort")
        press(ns, "PAD1"); press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().key, "pop:alphabetical")
        press(ns, "PAD1")
        t.eq(p.popup:IsShown(), false)
        t.eq(ns.db.zones.sort, "alphabetical")
        t.eq(shown(ns), "Dun Morogh,Durotar,Elwynn Forest,Teldrassil,Westfall,Zephras Isle")
        t.eq(cat.headers[1]:IsShown(), false, "no sections outside Recommended")
        t.ok(cat.options.sort.text:GetText():find("A%-Z"), cat.options.sort.text:GetText())
        t.eq(ns.Focus.Current().key, "tb:sort")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("catalogue: toolbar info doesn't repeat the control's name; A says what it does", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        ns.Focus.FocusKey("tb:sort")
        local info = ns.UI.GetFrame().legend.info:GetText()
        t.ok(info:find("Sort|r   Recommended%. Press A to choose%."), info)
        t.eq(ns.Focus.Current().actionLabel, "Choose")
    end)

    t.test("catalogue: a narrow toolbar drops the Show/Level/Sort prefixes to keep search", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones", window = { width = 1000, height = 640 } })
        slash("")
        local cat = page(ns).catalogue
        t.eq(cat.shortLabels, true, "1000 wide: short labels")
        t.ok(not cat.options.sort.text:GetText():find("Sort:"), cat.options.sort.text:GetText())
        t.ok(cat.search:GetWidth() >= ns.Theme.layout.searchMinWidth)
        ns.UI.GetFrame():SetSize(1640, 740); ns.UI.Relayout()
        t.eq(cat.shortLabels, false, "wide: full labels")
        t.ok(cat.options.sort.text:GetText():find("Sort:"))
    end)

    t.test("catalogue: the split view's narrow list drops the level bar, keeps the text", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list" } })
        slash("")
        local cat = page(ns).catalogue
        t.eq(cat.byMap[1429].lvbar:IsShown(), true, "full-width list: bar")
        ns.UI.GetFrame():SetSize(1640, 740); ns.UI.Relayout()
        t.eq(cat.byMap[1429].lvbar:IsShown(), false, "split list: no bar")
        t.eq(cat.byMap[1429].lv:GetText(), "Lv 1-10")
    end)

    t.test("zone detail: the banner shows the zone guide's levels however it was opened", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        page(ns):Open({ mapID = 1436, name = "Westfall", continent = "Eastern Kingdoms" })
        t.eq(page(ns).detail.banner.sub:GetText(), "Eastern Kingdoms  ·  Levels 10-20  ·  Alliance territory")
    end)

    -- Opens a zone's dashboard, then one category's page.
    local function openPage(ns, zone, key)
        page(ns):Open(zone)
        page(ns):OpenPage(key)
        return page(ns).detail
    end
    local ELWYNN = { mapID = 1429, name = "Elwynn Forest", continent = "Eastern Kingdoms" }

    t.test("zone detail: opens on the dashboard: the banner, the % and one tile per category", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        page(ns):Open(ELWYNN)
        local d = page(ns).detail
        t.eq(d.dash:IsShown(), true); t.eq(d.scroll:IsShown(), false)
        t.eq(d.banner.name:GetText(), "Elwynn Forest")
        t.eq(d.banner.zpct:GetText(), "40%", "only exploration applies here (no QuestieDB, no flight paths)")
        t.ok(d.banner.zcats:GetText():find("2/5"), d.banner.zcats:GetText())
        t.eq(d.banner:GetHeight(), 196, "the dashboard's taller header")
        t.eq(d.tiles[1].count:GetText(), "2 of 5"); t.eq(d.tiles[1].pct:GetText(), "40%")
        t.ok(d.tiles[1].line1:GetText():find("Fargodeep Mine"), "next area to discover")
        t.ok(d.tiles[2].line1:GetText():find("QuestieDB"), d.tiles[2].line1:GetText())
        t.eq(ns.Focus.Current().key, "tile:explore")
        local rows = page(ns):GetFocusRows()
        t.eq(#rows, 2, "the three tiles in a row, then Next up")
        t.eq(#rows[1].items, 3); t.eq(rows[1].items[2].onActivate, nil, "nothing to open without QuestieDB")
        t.eq(rows[2].items[1].title, "Fargodeep Mine", "Next up: the next area to discover")
        t.eq(d.nextup.title:GetText(), "Next up in Elwynn Forest")
        press(ns, "PADDDOWN"); press(ns, "PAD1")
        t.eq(page(ns).detailPage, "explore"); t.eq(ns.Focus.Current().title, "Fargodeep Mine", "Next up opens the area")
        press(ns, "PAD2"); press(ns, "PADDUP")
        press(ns, "PAD1")
        t.eq(page(ns).detailPage, "explore"); t.eq(ns.Focus.Current().title, "Fargodeep Mine")
        t.eq(d.banner.name:GetText(), "Exploration")
        press(ns, "PAD2")
        t.eq(page(ns).detailPage, nil, "B: back to the dashboard"); t.eq(ns.Focus.Current().key, "tile:explore")
        press(ns, "PAD2")
        t.eq(page(ns).mode, "list", "B again: the catalogue")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("zone detail: quests page (Ready now, storylines, finished, toggle) and flight paths", function()
        padUI = true
        -- Flight paths: the client's node list, and Stormwind's flight master seen before.
        _G.C_TaxiMap = { GetTaxiNodesForMap = function(id)
            if id ~= 1415 then return {} end
            return { { nodeID = 2, name = "Stormwind, Elwynn", faction = 2 }, { nodeID = 4, name = "Sentinel Hill, Westfall", faction = 2 },
                { nodeID = 84, name = "Plaguewood Tower, Eastern Plaguelands", faction = 0 } }
        end }
        local ns = boot({ schemaVersion = 4, lastTab = "zones" }, { schemaVersion = 1,
            flights = { [1415] = { time = 1794100000, nodes = { ["Stormwind, Elwynn"] = "known", ["Sentinel Hill, Westfall"] = "distant" } } } })
        -- Quests: the real evaluation of a small Elwynn set (QuestieDB stand-in).
        local info = {
            [40] = { name = "A Fishy Peril", level = 10, reqLevel = 7, next = 35 },
            [35] = { name = "Further Concerns", level = 10, reqLevel = 7, preSingle = { 40 } },
            [37] = { name = "Find the Lost Guards", level = 10, reqLevel = 7, preSingle = { 35 } },
            [7] = { name = "Kobold Camp Cleanup", level = 2, next = 15 },
            [15] = { name = "Investigate Echo Ridge", level = 3, preSingle = { 7 } },
            [176] = { name = "WANTED: \"Hogger\"", level = 11, reqLevel = 5 },
            [5261] = { name = "Eagan Peltskinner", level = 2, preSingle = { 7 }, breadcrumbFor = 15 },
        }
        local ctx = ns.QuestRules.Context(function(id) return info[id] end, { [40] = true, [7] = true, [15] = true },
            { raceID = 1, classID = 2, level = 9 })
        local q = ns.Quests.Evaluate(ctx, 1429, { 40, 35, 37, 7, 15, 176, 5261 }, 4)
        local realForZone = ns.Quests.ForZone
        ns.Quests.ForZone = function(z) local id = type(z) == "table" and z.mapID or z; if id == 1429 then return q end
            return { status = "ready", count = 0, objectives = {}, progress = ns.Progression.Aggregate({}) } end
        slash("")
        page(ns):Open(ELWYNN)
        local d = page(ns).detail
        t.eq(d.tiles[2].count:GetText(), "3 of 6")
        t.ok(d.tiles[2].line1:GetText():find("2|r ready"), d.tiles[2].line1:GetText())
        t.ok(d.tiles[3].line1:GetText():find("No flight master"), "Stormwind's node belongs to Stormwind City")
        page(ns):OpenPage("quests")
        t.eq(d.banner.name:GetText(), "Quests"); t.eq(d.banner.count:GetText(), "3 of 6")
        t.eq(d.headers[1].text:GetText(), "Ready now")
        t.eq(ns.Focus.Current().title, "Further Concerns", "focus on the first ready quest")
        t.ok(ns.Focus.Current().detail:find("Ready now"), ns.Focus.Current().detail)
        t.eq(d.headers[2].text:GetText(), "Storylines"); t.eq(d.headers[3].text:GetText(), "Finished")
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "A Fishy Peril", "RT: the storyline track, first node")
        press(ns, "PADDRIGHT"); press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().title, "Find the Lost Guards")
        t.ok(ns.Focus.Current().detail:find("Needs Further Concerns"), ns.Focus.Current().detail)
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().key, "fold:7", "the finished storyline, folded")
        press(ns, "PAD1")
        t.eq(ns.Focus.Current().key, "fold:7", "unfolded, focus kept")
        press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Kobold Camp Cleanup", "its track shows")
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().key, "toggle")
        press(ns, "PAD1")
        t.eq(ns.db.zones.showUnavailable, true)
        t.ok(d.toggle.text:GetText():find("Hide 1 quest"), d.toggle.text:GetText())
        press(ns, "PAD2")
        t.eq(ns.Focus.Current().key, "tile:quests", "B: the dashboard, on the Quests tile")
        -- Westfall: Sentinel Hill not known yet (the flight master's list said DISTANT).
        page(ns):Back()
        page(ns):Open({ mapID = 1436, name = "Westfall", continent = "Eastern Kingdoms" })
        t.eq(d.tiles[3].count:GetText(), "0 of 1")
        page(ns):OpenPage("flights")
        t.eq(ns.Focus.Current().title, "Sentinel Hill")
        t.ok(ns.Focus.Current().detail:find("Not discovered yet"))
        ns.Quests.ForZone, _G.C_TaxiMap = realForZone, nil
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("zone detail: exploration page progress, and a note when the game's list differs", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        local d = openPage(ns, ELWYNN, "explore")
        t.eq(d.banner.pct:GetText(), "40%"); t.eq(d.banner.count:GetText(), "2 of 5")
        t.ok(d.texts[1]:IsShown() and d.texts[1].fs:GetText():find("differs from Azerfolio's catalogue"), "fixture IDs differ")
        t.eq(d.headers[3] == nil or not d.headers[3]:IsShown(), true, "no unknown areas: no third section")
    end)

    t.test("zone detail: areas with unknown state are listed, not counted, and explained", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        local real = _G.GetAchievementCriteriaInfo
        _G.GetAchievementCriteriaInfo = function(achID, i)
            local r = { real(achID, i) }
            if achID == 776 and i == 3 then r[3] = nil end -- Fargodeep Mine: no flag
            return unpack(r, 1, 11)
        end
        ns.Exploration.InvalidateAll()
        local d = openPage(ns, ELWYNN, "explore")
        _G.GetAchievementCriteriaInfo = real
        t.eq(d.headers[3].text:GetText(), "State unknown"); t.eq(d.headers[3].count:GetText(), "1 area")
        t.eq(d.headers[1].count:GetText(), "2 areas", "To discover lists the other two")
        t.ok(d.texts[1].fs:GetText():find("didn't say whether 1 area is discovered"), d.texts[1].fs:GetText())
        t.eq(d.banner.count:GetText(), "2 of 4", "the unknown one isn't counted")
        press(ns, "PADRTRIGGER"); press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "RT reaches the third section")
        t.ok(ns.Focus.Current().detail:find("didn't say"))
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("zone detail: a fully explored zone says so in gold, 100%", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        page(ns):Open({ mapID = 1426, name = "Dun Morogh", continent = "Eastern Kingdoms" })
        local d = page(ns).detail
        t.eq(d.banner.zpct:GetText(), "Claimed", "the dashboard: every category done")
        page(ns):OpenPage("explore")
        t.eq(d.banner.pct:GetText(), "100%")
        t.ok(d.texts[1].fs:GetText():find("Fully explored"), d.texts[1].fs:GetText())
        t.eq(d.headers[1].text:GetText(), "Discovered", "no empty To discover section")
        t.eq(d.headers[1].count:GetText(), "1 area")
        t.eq(d.headers[2] == nil or not d.headers[2]:IsShown(), true)
        local rows = page(ns).detailRows
        t.eq(#rows, 1); t.eq(rows[1].section, 1)
        t.eq(ns.Focus.Current().title, "Coldridge Valley", "focus starts on the first discovered area")
        openPage(ns, { mapID = 1411, name = "Durotar", continent = "Kalimdor" }, "explore")
        t.eq(d.headers[1].text:GetText(), "To discover", "an untouched zone keeps both sections")
        t.eq(d.headers[2].text:GetText(), "Discovered"); t.eq(d.headers[2].count:GetText(), "0 areas")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("zone detail: X opens the world map on the zone; Azerfolio hides and comes back", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list" } })
        local wm = _G.CreateFrame("Frame", "WorldMapFrame", _G.UIParent)
        wm:Hide()
        _G.OpenWorldMap = function(mapID) wm.mapID = mapID; wm:Show() end
        slash("")
        press(ns, "PADDDOWN"); press(ns, "PAD1") -- Elwynn Forest
        t.eq(page(ns).mode, "detail")
        press(ns, "PAD1") -- its Exploration page
        local hints = ns.UI.GetFrame().legend.hints
        t.ok(hints:GetWidth() > 1)
        press(ns, "PAD3")
        t.eq(wm:IsShown(), true); t.eq(wm.mapID, 1429)
        t.eq(ns.UI.IsShown(), false, "Azerfolio steps aside for the map")
        wm:Hide()
        t.eq(ns.UI.IsShown(), true, "back when the map closes")
        t.eq(page(ns).mode, "detail", "still on the zone")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "focus kept")
        ns.UI.Hide(); wm:Show(); wm:Hide()
        t.eq(ns.UI.IsShown(), false, "closing a map Azerfolio didn't open doesn't reopen it")
        _G.OpenWorldMap, _G.WorldMapFrame = nil, nil
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("zone detail: if the map doesn't open, Azerfolio stays and says so", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        page(ns):Open({ mapID = 1429, name = "Elwynn Forest", continent = "Eastern Kingdoms" })
        t.eq(page(ns):OpenMap(), false)
        t.eq(ns.UI.IsShown(), true)
        t.ok(table.concat(wow.chat, "\n"):find("Couldn't open the world map"))
    end)

    t.test("catalogue: For my level uses the zone guide; Show hides the other faction's territory", function()
        _G.UnitFactionGroup = function() return "Alliance", "Alliance" end
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { level = "appropriate", faction = "all" } })
        slash("")
        local cat = page(ns).catalogue
        t.eq(shown(ns), "Dun Morogh,Elwynn Forest,Durotar,Teldrassil,Zephras Isle,Westfall")
        t.eq(cat.options.level:IsShown(), true)
        t.eq(cat.options.faction:IsShown(), true, "faction data from the guide: Show is offered")
        ns.db.zones.faction = "relevant"; cat:Refresh()
        t.eq(shown(ns), "Dun Morogh,Elwynn Forest,Teldrassil,Zephras Isle,Westfall",
            "Durotar (Horde territory) hidden for an Alliance character; Zephras Isle (both) kept")
        t.ok(cat.options.faction.text:GetText():find("Relevant to me"))
    end)

    t.test("catalogue: search filters as you type; B leaves the box; empty state", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        local cat = page(ns).catalogue
        press(ns, "PAD3")
        t.eq(cat.searchBox:HasFocus(), true, "X focuses the search")
        t.eq(ns.Focus.Current().key, "tb:search")
        cat.searchBox:SetText("dun"); cat.searchBox.scripts.OnTextChanged(cat.searchBox)
        wow.runTimers()
        t.eq(shown(ns), "Dun Morogh")
        cat.searchBox:SetText("silithus"); cat.searchBox.scripts.OnTextChanged(cat.searchBox)
        wow.runTimers()
        t.eq(cat.query.shown, 0)
        t.eq(cat.emptyTitle:IsShown(), true); t.eq(cat.emptyTitle:GetText(), "No zones match")
        t.ok(cat.emptyText:GetText():find("clear the search"))
        t.eq(ns.Focus.Current().key, "tb:search", "nothing to focus below: stays on the toolbar")
        press(ns, "PAD2")
        t.eq(cat.searchBox:HasFocus(), false, "B leaves the box")
        t.eq(ns.UI.IsShown(), true)
        t.eq(ns.db.zones.search, nil, "search text isn't saved")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("catalogue: filtering and switching views reuses cards and rows", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        local cat = page(ns).catalogue
        cat:CycleView(); cat:CycleView()
        local before = wow.frameCount()
        for _ = 1, 5 do
            for _, b in ipairs(cat.status) do b.item.onActivate(b.item) end
            cat:CycleView()
        end
        t.eq(wow.frameCount(), before)
    end)

    t.test("catalogue: a discovery redraws the numbers on the cards", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        local cat = page(ns).catalogue
        t.eq(cat.byMap[1429].bars.slots[1].count:GetText(), "2/5")
        CRITERIA[776][3][2] = true
        wow.fire("CRITERIA_UPDATE"); wow.runTimers()
        CRITERIA[776][3][2] = false
        t.eq(cat.byMap[1429].bars.slots[1].count:GetText(), "3/5")
        t.eq(cat.byMap[1429].pct:GetText(), "60%")
    end)

    t.test("focus is remembered per tab", function()
        padUI = true
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        press(ns, "PADDDOWN"); press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Westfall")
        press(ns, "PADLSHOULDER")
        t.eq(ns.UI.CurrentTab(), "overview")
        t.eq(ns.Focus.Current().key, "hero", "the Overview starts on the Continue card")
        press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().key, "completion")
        press(ns, "PADRSHOULDER")
        t.eq(ns.Focus.Current().title, "Westfall", "back where it was")
        press(ns, "PADLSHOULDER")
        t.eq(ns.Focus.Current().key, "completion", "and the Overview's focus too")
    end)

    t.test("no chevron when the controller isn't driving the window", function()
        padUI = false
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        t.eq(ns.Focus.pointer:IsShown(), false)
        t.ok(ns.UI.GetFrame().legend.info:GetText():find("Every zone"), "tab info for mouse users")
        padUI = true
    end)

    t.test("exploration is read from the zone's Explore achievement", function()
        local ns = boot()
        local ex = ns.Exploration.ForZone({ mapID = 1429, name = "Elwynn Forest" })
        t.eq(ex.status, "tracked")
        t.eq(ex.achievementID, 776)
        t.eq(#ex.objectives, 5)
        local o = ex.objectives[1]
        t.eq(o.id, 1146); t.eq(o.name, "Northshire Valley"); t.eq(o.completion, "complete")
        t.eq(o.eligibility, "eligible"); t.eq(o.category, "exploration"); t.eq(o.zone, 1429)
        t.eq(ex.progress.completed, 2); t.eq(ex.progress.remaining, 3); t.eq(ex.progress.total, 5)
        t.eq(ex.progress.coverage, "complete"); t.eq(ns.Progression.PercentText(ex.progress), "40%")
        t.eq(ex.catalogueMatch, false, "the fixture IDs differ from the catalogue: trusted, but flagged")
        t.eq(ns.Exploration.ForZone({ mapID = 2521, name = "Zephras Isle" }).status, "untracked", "not in the catalogue")
        t.eq(ns.Exploration.ForZone({ mapID = 1436, name = "Westfall" }).status, "unavailable", "in the catalogue, no data")
    end)

    t.test("zones catalogue: every listed zone with its live exploration state", function()
        local ns = boot()
        local all = ns.Zones.All()
        t.eq(#all, 6, "the fixture's zone maps, orphan dropped")
        local by = {}
        for _, z in ipairs(all) do by[z.mapID] = z end
        t.eq(by[1429].state, "progress"); t.eq(by[1429].progress.completed, 2)
        t.eq(by[1429].continent, "Eastern Kingdoms"); t.eq(by[1429].rank, 1)
        t.eq(by[1426].state, "complete", "Dun Morogh's only fixture area is done")
        t.eq(by[1411].state, "untouched"); t.eq(by[1411].rank, 2)
        t.eq(by[1436].state, "unknown", "Westfall: tracked, no data")
        t.eq(by[2521].state, "untracked")
        t.eq(all[1].name, "Dun Morogh", "continent order, then name")
        t.eq(by[1436].minLevel, 10); t.eq(by[1436].maxLevel, 20, "Westfall from the curated guide")
        t.eq(by[2521].minLevel, 1); t.eq(by[2521].maxLevel, 12, "Zephras Isle from the owner")
        local q = ns.Zones.Query(all, { level = "appropriate", sort = "recommended" }, { level = 9 })
        t.eq(q.available.levels, true)
        local fit = {}
        for _, z in ipairs(q.zones) do fit[#fit + 1] = z.name end
        t.eq(table.concat(fit, ","), "Dun Morogh,Elwynn Forest,Durotar,Teldrassil,Zephras Isle,Westfall",
            "level 9: the 1-10 zones, Zephras Isle (1-12), then Westfall (10-20, within 3 levels)")
        t.eq(q.groups[1].title, "Levels 1-10"); t.eq(q.groups[2].title, "Levels 10-20")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("a non-boolean done flag is unknown, never done or not done", function()
        local ns = boot()
        local real = _G.GetAchievementCriteriaInfo
        _G.GetAchievementCriteriaInfo = function(achID, i)
            local r = { real(achID, i) }
            if i == 2 then r[3] = nil end
            return unpack(r, 1, 10)
        end
        local p = ns.Exploration.ForZone({ mapID = 1429, name = "Elwynn Forest" }).progress
        _G.GetAchievementCriteriaInfo = real
        t.eq(p.completionUnknown, 1); t.eq(p.denominator, 4); t.eq(p.coverage, "partial")
    end)

    t.test("no achievement data yet: unavailable, and retried later", function()
        achievementsReady = false
        local ns = boot()
        t.eq(ns.Exploration.ForZone({ mapID = 1429, name = "Elwynn Forest" }).status, "unavailable")
        achievementsReady = true
        t.eq(ns.Exploration.ForZone({ mapID = 1429, name = "Elwynn Forest" }).status, "tracked", "not cached empty")
    end)

    t.test("A opens Zone Detail on the first area to discover; B goes back to the same zone", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list" } })
        slash("")
        press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Elwynn Forest")
        press(ns, "PAD1")
        local page = ns.UI.GetFrame().pages.zones
        t.eq(page.mode, "detail")
        t.eq(page.detail.banner.name:GetText(), "Elwynn Forest")
        t.eq(ns.Focus.Current().key, "tile:explore", "the dashboard, on the Exploration tile")
        press(ns, "PAD1")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "first area to discover")
        t.eq(ns.Focus.Current().detail, "Not discovered yet")
        press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().title, "Crystal Lake", "two columns")
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "Northshire Valley", "RT: Discovered section")
        t.eq(ns.Focus.Current().detail, "Discovered")
        press(ns, "PAD2")
        t.eq(page.detailPage, nil, "B: the dashboard first")
        press(ns, "PAD2")
        t.eq(page.mode, "list", "B goes back")
        t.eq(ns.UI.IsShown(), true, "the window stays open")
        t.eq(ns.Focus.Current().title, "Elwynn Forest", "same zone focused")
        press(ns, "PAD2")
        t.eq(ns.UI.IsShown(), false, "B on the list closes")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("an untracked zone says so instead of showing areas", function()
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        local page = ns.UI.GetFrame().pages.zones
        page:Open({ mapID = 2521, name = "Zephras Isle", continent = "Other places" })
        t.ok(page.detail.tiles[1].line1:GetText():find("no Explore achievement for Zephras Isle"))
        t.eq(#page:GetFocusRows(), 0, "nothing to open")
    end)

    t.test("opening zones repeatedly reuses the area rows", function()
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        local page = ns.UI.GetFrame().pages.zones
        page:Open({ mapID = 1429, name = "Elwynn Forest" }); page:Back()
        local before = wow.frameCount()
        for _ = 1, 5 do
            page:Open({ mapID = 1429, name = "Elwynn Forest" }); page:Back()
            page:Open({ mapID = 1426, name = "Dun Morogh" }); page:Back()
        end
        t.eq(wow.frameCount(), before)
    end)

    t.test("banner crop: centred by default, on the landmark where set, kept inside the art", function()
        local ns = boot()
        local T = ns.Theme
        local top, bottom = T.BannerCrop(1429, 1000, 125) -- band = 0.25 of the art's height
        t.eq(top, 0.375); t.eq(bottom, 0.625)
        top, bottom = T.BannerCrop(1436, 1000, 125)
        t.ok(math.abs(top - (T.bannerFocus[1436] - 0.125)) < 1e-9, "Westfall centred on its lighthouse: " .. top)
        t.ok(math.abs(bottom - top - 0.25) < 1e-9)
        T.bannerFocus[1] = 0.02
        top = T.BannerCrop(1, 1000, 125)
        t.eq(top, 0, "never above the art")
        T.bannerFocus[1] = nil
        top, bottom = T.BannerCrop(1436, 400, 400)
        t.eq(top, 0); t.eq(bottom, 1, "a tall banner shows the whole height")
    end)

    t.test("wide window: Zones is a split view whose detail follows focus", function()
        padUI = true
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("")
        local f = ns.UI.GetFrame()
        local page = f.pages.zones
        t.eq(page.wide, false, "1160 is not wide")
        t.eq(page.detail:IsShown(), false)
        f:SetSize(1640, 740); ns.UI.Relayout()
        t.eq(page.wide, true)
        t.eq(page.list:IsShown(), true); t.eq(page.detail:IsShown(), true)
        t.eq(page.list.edge:IsShown(), true, "divider between the panes")
        t.eq(page.detail.back:IsShown(), false, "no Zones button: the list is right there")
        t.eq(ns.Focus.Current().title, "Dun Morogh")
        t.eq(page.detail.banner.name:GetText(), "Dun Morogh", "detail shows the focused zone")
        t.eq(page.catalogue.byMap[1426].selected, true, "its row is marked")
        press(ns, "PADDDOWN")
        t.eq(page.detail.banner.name:GetText(), "Elwynn Forest", "detail follows focus")
        t.eq(page.catalogue.byMap[1426].selected, false); t.eq(page.catalogue.byMap[1429].selected, true)
        t.ok(f.legend.hints:GetWidth() > 1, "hints drawn")
        t.eq(ns.Focus.Current().actionLabel, "Checklist")
        press(ns, "PAD1")
        t.eq(page.mode, "detail")
        t.eq(page.list:IsShown(), true, "the list stays visible")
        t.eq(ns.Focus.Current().key, "tile:explore", "A moves into the zone's dashboard")
        press(ns, "PAD1")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "A again: the areas")
        press(ns, "PADDDOWN")
        t.eq(page.detail.banner.crumb:GetText(), "·  Elwynn Forest", "moving in the areas keeps the zone")
        press(ns, "PAD2")
        t.eq(page.detailPage, nil, "B: the dashboard")
        press(ns, "PAD2")
        t.eq(page.mode, "list")
        t.eq(ns.Focus.Current().title, "Elwynn Forest", "B returns to the zone")
        t.eq(ns.UI.IsShown(), true)
        f:SetSize(1160, 740); ns.UI.Relayout()
        t.eq(page.wide, false)
        t.eq(page.detail:IsShown(), false, "narrow again: list only")
        t.ok(not page.catalogue.byMap[1429].selected, "no selection mark in the narrow cards")
        t.eq(page.catalogue:View(), "cards", "back to the saved view")
        t.eq(ns.Focus.Current().actionLabel, "Open")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("wide window: a click selects, A on an untracked zone stays in the list", function()
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("")
        local f = ns.UI.GetFrame()
        f:SetSize(1640, 740); ns.UI.Relayout()
        local page = f.pages.zones
        local row = page.catalogue.byMap[2521]
        row.scripts.OnClick(row)
        t.eq(page.mode, "list")
        t.eq(page.detail.banner.name:GetText(), "Zephras Isle")
        t.eq(ns.Focus.Current().title, "Zephras Isle", "focus follows the click")
        t.eq(row.item.canActivate(), false, "no A hint: nothing to move into")
        t.eq(page.catalogue.byMap[1429].item.canActivate(), true, "another zone still can")
        page:Open(row.item.zone)
        t.eq(page.mode, "list", "nothing to move into")
        t.ok(page.detail.tiles[1].line1:GetText():find("no Explore achievement"), "the reason shows")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("a window resized past the wide size switches layout on its own", function()
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("")
        local f = ns.UI.GetFrame()
        f:SetSize(1500, 740)
        f.scripts.OnSizeChanged(f, 1500, 740)
        t.eq(f.pages.zones.wide, true)
    end)

    t.test("minimap angle math", function()
        local ns = boot()
        local L = ns.Launcher
        local x, y = L.PositionForAngle(0, 80); t.eq(math.floor(x + 0.5), 80); t.eq(math.floor(y + 0.5), 0)
        x, y = L.PositionForAngle(90, 80); t.eq(math.floor(x + 0.5), 0); t.eq(math.floor(y + 0.5), 80)
        t.eq(L.AngleTo(10, 0, 0, 0), 0)
        t.eq(L.AngleTo(0, 10, 0, 0), 90)
        t.eq(L.AngleTo(-10, 0, 0, 0), 180)
        t.eq(L.AngleTo(0, -10, 0, 0), 270, "never negative")
    end)

    local function withMinimap(ns)
        local mm = _G.CreateFrame("Frame", "Minimap", _G.UIParent)
        mm:SetSize(140, 140)
        function mm:GetCenter() return 1000, 600 end
        ns.Launcher.Refresh()
        return mm
    end

    t.test("minimap button: placed at the saved angle, dragged, hidden and shown", function()
        local ns = boot()
        withMinimap(ns)
        local b = ns.Launcher.button
        t.ok(b and b:IsShown(), "button shown")
        t.eq(ns.db.launcher.minimapAngle, 140, "default angle")
        _G.GetCursorPosition = function() return 1000, 700 end -- straight above the centre
        b.scripts.OnDragStart(b)
        b.scripts.OnUpdate(b)
        b.scripts.OnDragStop(b)
        t.eq(ns.db.launcher.minimapAngle, 90)
        t.eq(b.scripts.OnUpdate, nil, "stops following the cursor")
        b.scripts.OnClick(b)
        t.eq(ns.UI.IsShown(), true, "click opens the window")
        slash("minimap")
        t.eq(b:IsShown(), false); t.eq(ns.db.launcher.minimapHidden, true)
        slash("minimap")
        t.eq(b:IsShown(), true)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("the addon compartment toggles the window", function()
        local ns = boot()
        _G.Azerfolio_OnAddonCompartmentClick("Azerfolio", "LeftButton")
        t.eq(ns.UI.IsShown(), true)
        _G.Azerfolio_OnAddonCompartmentClick("Azerfolio", "LeftButton")
        t.eq(ns.UI.IsShown(), false)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("TOC compartment fields name functions that exist; no key binding", function()
        boot()
        local meta = wow.tocMetadata("Azerfolio", "Azerfolio")
        for _, k in ipairs({ "AddonCompartmentFunc", "AddonCompartmentFuncOnEnter", "AddonCompartmentFuncOnLeave" }) do
            t.eq(type(_G[meta[k]]), "function", k .. " -> " .. tostring(meta[k]))
        end
        t.eq(io.open("Azerfolio/Bindings.xml", "r"), nil, "Bindings.xml removed")
        t.eq(_G.Azerfolio_Toggle, nil)
    end)

    t.test("tabs are registered in order and wrap around", function()
        local ns = boot()
        t.eq(#ns.UI.tabs, 2)
        t.eq(ns.UI.tabs[1].id, "overview")
        t.eq(ns.UI.tabs[2].id, "zones")
        t.eq(ns.UI.TabAfter("overview", 1), "zones")
        t.eq(ns.UI.TabAfter("zones", 1), "overview")
        t.eq(ns.UI.TabAfter("overview", -1), "zones")
    end)

    t.test("/azf opens and closes the window; Escape is registered", function()
        local ns = boot()
        t.eq(ns.UI.IsShown(), false, "not built before first open")
        slash("")
        t.eq(ns.UI.IsShown(), true)
        local found = false
        for _, n in ipairs(_G.UISpecialFrames) do if n == "AzerfolioMainFrame" then found = true end end
        t.ok(found, "in UISpecialFrames")
        slash("")
        t.eq(ns.UI.IsShown(), false)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("repeated open, close and tab switches create no new frames", function()
        local ns = boot()
        slash("")
        ns.UI.SelectTab("zones")
        ns.UI.SelectTab("overview")
        slash("")
        local before = wow.frameCount()
        for _ = 1, 5 do
            slash("")
            ns.UI.SelectTab("zones")
            ns.UI.SelectTab("overview")
            slash("")
        end
        t.eq(wow.frameCount(), before)
    end)

    t.test("the last tab is restored and Zones uses the compact header", function()
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        t.eq(ns.UI.CurrentTab(), "zones")
        local f = ns.UI.GetFrame()
        t.eq(f.header:GetHeight(), ns.Theme.layout.headerCompactHeight)
        ns.UI.SelectTab("overview")
        t.eq(f.header:GetHeight(), ns.Theme.layout.headerHeight)
        t.eq(ns.db.lastTab, "overview", "selection saved")
    end)

    t.test("header shows the character, XP and subzone the client reports", function()
        local ns = boot()
        slash("")
        local h = ns.UI.GetFrame().header
        t.eq(h.name:GetText(), "Gideon")
        t.eq(h.xp.text:GetText(), "273 / 6500 XP")
        t.eq(h.subzone:GetText(), "Goldshire")
        t.eq(h.zone:GetText(), "Elwynn Forest")
    end)

    t.test("dragging saves the position as a centre offset", function()
        local ns = boot()
        slash("")
        local f = ns.UI.GetFrame()
        f:SetPoint("CENTER", _G.UIParent, "CENTER", 120, 4)
        f.header.scripts.OnDragStop(f.header)
        t.eq(ns.db.window.x, 120)
        t.eq(ns.db.window.y, 4)
        t.eq(ns.db.window.point, "CENTER")
    end)

    t.test("an off-screen saved position opens on screen", function()
        local ns = boot({ schemaVersion = 2, window = { x = 3000, y = 0, width = 1160, height = 740 } })
        slash("")
        local f = ns.UI.GetFrame()
        t.ok(f.cx + 1160 / 2 <= 1835 / 2, "right edge on screen: " .. f.cx)
    end)

    t.test("gamepad: LB/RB switch tabs and B closes", function()
        padUI = true
        local ns = boot()
        slash("")
        t.eq(ns.Gamepad.IsActive(), true)
        t.eq(ns.Gamepad.GetInputFrame().gamePadButton, true)
        t.eq(ns.UI.CurrentTab(), "overview")
        press(ns, "PADRSHOULDER")
        t.eq(ns.UI.CurrentTab(), "zones")
        press(ns, "PADLSHOULDER")
        t.eq(ns.UI.CurrentTab(), "overview")
        press(ns, "PAD2")
        t.eq(ns.UI.IsShown(), false)
        t.eq(ns.Gamepad.GetInputFrame().gamePadButton, false, "input released when closed")
    end)

    t.test("gamepad: input is released in combat and back after", function()
        padUI = true
        local ns = boot()
        slash("")
        wow.fire("PLAYER_REGEN_DISABLED")
        t.eq(ns.Gamepad.GetInputFrame().gamePadButton, false)
        t.eq(ns.UI.GetFrame().tabs.lb:IsShown(), false, "hints hidden")
        wow.fire("PLAYER_REGEN_ENABLED")
        t.eq(ns.Gamepad.GetInputFrame().gamePadButton, true)
        t.eq(ns.UI.GetFrame().tabs.lb:IsShown(), true)
    end)

    t.test("gamepad: nothing is taken when the gamepad UI is off", function()
        padUI = false
        local ns = boot()
        slash("")
        t.eq(ns.Gamepad.IsActive(), false)
        t.ok(not ns.Gamepad.GetInputFrame().gamePadButton, "input not enabled")
        t.eq(ns.UI.GetFrame().tabs.lb:IsShown(), false)
        padUI = true
    end)

    t.test("opening during combat works (the window is not protected)", function()
        local ns = boot()
        wow.combat = true
        slash("")
        t.eq(ns.UI.IsShown(), true)
        t.eq(ns.Gamepad.IsActive(), false)
        t.eq(#ns.Debug.errors, 0)
        wow.combat = false
    end)

    t.test("/azf shots screenshots every step and restores the window", function()
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("shots")
        wow.runTimers()
        local pictures = 0
        for _, s in ipairs(ns.UI.ShotSteps()) do if not s.skip then pictures = pictures + 1 end end
        t.eq(_G.screenshotsTaken, pictures)
        t.eq(_G.screenshotsTaken, 15, "12 before, plus the zone's three category pages")
        t.eq(ns.db.zones.displayMode, "cards", "view restored")
        t.eq(ns.UI.GetFrame().pages.zones.popup:IsShown(), false, "popup closed")
        local labels = {}
        for _, s in ipairs(ns.UI.ShotSteps()) do labels[#labels + 1] = s.label end
        local all = table.concat(labels, ", ")
        t.ok(all:find("not tracked") and all:find("zones wide, checklist"), all)
        t.eq(ns.UI.CurrentTab(), "zones", "tab restored")
        t.eq(ns.UI.GetFrame():GetWidth(), 1160, "size restored")
        local page = ns.UI.GetFrame().pages.zones
        t.eq(page.wide, false, "layout restored"); t.eq(page.mode, "list", "back on the list")
        t.eq(ns.UI.shotsRunning, false)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("/azf shots banners shows each zone with a banner offset", function()
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("shots banners")
        wow.runTimers()
        t.eq(_G.screenshotsTaken, 3, "Westfall, Teldrassil and Zephras Isle in the fixture")
        t.eq(ns.UI.GetFrame().pages.zones.mode, "list")
        t.eq(#ns.Debug.errors, 0)
    end)

    -- Exploration tracker -------------------------------------------------------------------

    local function listen(ns)
        local got = {}
        ns.Events.On("AZF_EXPLORATION_UPDATED", function(ids) got[#got + 1] = ids or "all" end)
        return got
    end

    t.test("tracker: catalogue match is flagged, a matching list is not uncertain", function()
        local ns = boot()
        local saved = CRITERIA[776]
        local real = {}
        for i, id in ipairs(ns.ExplorationCatalogue.zones[1429].criteria) do real[i] = { "Area " .. i, i <= 7, id } end
        CRITERIA[776] = real
        local ex = ns.Exploration.ForZone(1429)
        CRITERIA[776] = saved
        t.eq(ex.catalogueMatch, true); t.eq(ex.uncertain, false)
        t.eq(ex.progress.completed, 7); t.eq(ex.progress.denominator, 12)
        t.eq(ns.Progression.PercentText(ex.progress), "58%")
    end)

    t.test("tracker: Compare reports missing and extra IDs", function()
        local ns = boot()
        local match, missing, extra = ns.Exploration.Compare({ 1, 2, 3 }, { 3, 2, 4 })
        t.eq(match, false); t.same(missing, { 1 }); t.same(extra, { 4 })
        t.eq((ns.Exploration.Compare({ 1, 2 }, { 2, 1 })), true, "order doesn't matter")
    end)

    t.test("tracker: results are cached until invalidated", function()
        local ns = boot()
        local a = ns.Exploration.ForZone(1429)
        t.ok(ns.Exploration.ForZone({ mapID = 1429 }) == a, "same result")
        ns.Exploration.Invalidate(1429)
        t.ok(ns.Exploration.ForZone(1429) ~= a, "re-read")
    end)

    t.test("tracker: a micro map finds its zone; other maps have none", function()
        local ns = boot()
        MAPS[9001] = { name = "Lion's Pride Inn", mapType = 5, parentMapID = 1429 }
        t.eq(ns.Exploration.ZoneForMap(9001), 1429)
        t.eq(ns.Exploration.ZoneForMap(1429), 1429)
        t.eq(ns.Exploration.ZoneForMap(1415), nil, "a continent")
        t.eq(ns.Exploration.ZoneForMap(nil), nil)
        MAPS[9001] = nil
    end)

    t.test("tracker: a discovery refreshes the current zone once and the open detail follows", function()
        padUI = true
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("")
        local got = listen(ns)
        local page = ns.UI.GetFrame().pages.zones
        page:Open({ mapID = 1429, name = "Elwynn Forest" })
        page:OpenPage("explore")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine")
        t.eq(page.detail.headers[1].count:GetText(), "3 areas")
        t.eq(page.detail.headers[2].count:GetText(), "2 areas")
        CRITERIA[776][3][2] = true -- Fargodeep Mine discovered
        wow.fire("CRITERIA_UPDATE")
        wow.fire("UI_INFO_MESSAGE", 412, "Discovered: Fargodeep Mine")
        wow.fire("MAP_EXPLORATION_UPDATED")
        wow.runTimers()
        CRITERIA[776][3][2] = false
        t.eq(#got, 1, "one update per discovery")
        t.same(got[1], { 1429 })
        t.eq(page.detail.headers[1].count:GetText(), "2 areas")
        t.eq(page.detail.headers[2].count:GetText(), "3 areas")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "focus stays on the area")
        t.eq(ns.Focus.Current().detail, "Discovered")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("tracker: a discovery outside the current zone's map is found live by a full re-read", function()
        here = 2521 -- standing on a map without an Explore achievement (like Stormwind City)
        local ns = boot()
        ns.Exploration.Overall() -- baseline of every zone
        local got = listen(ns)
        CRITERIA[776][4][2] = true -- an Elwynn Forest area
        wow.fire("CRITERIA_UPDATE")
        wow.fire("MAP_EXPLORATION_UPDATED")
        wow.runTimers()
        CRITERIA[776][4][2] = false
        here = 1429
        t.eq(#got, 1); t.same(got[1], { 1429 })
        local m = ns.charDB.milestones[#ns.charDB.milestones]
        t.eq(m.id, 1149); t.ok(m.time ~= nil, "seen live, so it has a time")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("tracker: the full re-read skips fully explored zones and traces its cost", function()
        here = 2521
        local tick = 0
        _G.debugprofilestop = function() tick = tick + 1.5; return tick end
        local ns = boot({ schemaVersion = 4, debug = true })
        ns.Exploration.Overall() -- caches Elwynn (2/5), Dun Morogh (1/1, fully explored), Durotar (0/1)
        t.ok(ns.Exploration.IsFullyExplored(ns.Exploration.ForZone(1426)), "Dun Morogh is fully explored")
        t.eq(ns.Exploration.IsFullyExplored(ns.Exploration.ForZone(1429)), false)
        t.eq(ns.Exploration.CacheSize(), 3)
        CRITERIA[728][1][2] = true
        wow.fire("MAP_EXPLORATION_UPDATED")
        wow.runTimers()
        CRITERIA[728][1][2] = false
        here = 1429
        local scan
        for _, e in ipairs(ns.db.trace) do if e.scan then scan = e end end
        _G.debugprofilestop = nil
        t.ok(scan, "scan traced")
        t.eq(scan.read, 2); t.eq(scan.skipped, 1); t.eq(scan.changedZones, 1)
        t.ok(type(scan.ms) == "number", "cost in ms")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("perf: debug mode counts events, messages and debounced calls; /azf debug perf reports", function()
        local tick = 0
        _G.debugprofilestop = function() tick = tick + 0.25; return tick end
        local ns = boot()
        wow.fire("CRITERIA_UPDATE")
        t.eq(ns.Events.stats.CRITERIA_UPDATE, nil, "nothing counted while debug is off")
        slash("debug") -- on: counters start
        wow.fire("CRITERIA_UPDATE"); wow.fire("CRITERIA_UPDATE"); wow.fire("CRITERIA_UPDATE")
        wow.runTimers()
        local s = ns.Events.stats
        t.eq(s.CRITERIA_UPDATE.count, 3)
        t.eq(s["debounce:exploration"].count, 1, "one re-read per burst")
        t.ok(s.CRITERIA_UPDATE.ms > 0 and s.CRITERIA_UPDATE.max > 0, "timed")
        local list = ns.Events.StatsList()
        t.ok(#list >= 2 and list[1].ms >= list[#list].ms, "busiest first")
        slash("debug perf")
        local all = table.concat(wow.chat, "\n")
        t.ok(all:find("Performance over"), all)
        t.ok(all:find("CRITERIA_UPDATE: 3 calls"), all)
        t.ok(all:find("memory unknown KB"), "no memory API in the mock: " .. all)
        local e = ns.db.trace[#ns.db.trace]
        t.eq(e.kind, "perf"); t.eq(type(e.sizes), "table"); t.eq(e.sizes.recentZones, 1)
        slash("debug perf reset")
        t.eq(next(ns.Events.stats), nil, "reset")
        slash("debug") -- off
        slash("debug perf")
        t.ok(wow.chat[#wow.chat]:find("only in debug mode"))
        _G.debugprofilestop = nil
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("perf: opening the window, tab switches and relayouts are timed in debug mode", function()
        local tick = 0
        _G.debugprofilestop = function() tick = tick + 1; return tick end
        local ns = boot({ schemaVersion = 4, debug = true })
        slash(""); slash(""); slash("")
        ns.UI.SelectTab("zones"); ns.UI.Relayout()
        local s = ns.Events.stats
        _G.debugprofilestop = nil
        t.eq(s["ui:open (first, builds the window)"].count, 1)
        t.eq(s["ui:open"].count, 1, "the second open; the third /azf closed it")
        t.ok(s["ui:tab overview (first, builds the page)"], "first Overview build")
        t.ok(s["ui:tab zones (first, builds the page)"], "first Zones build")
        t.ok(s["ui:relayout"].count >= 1)
        t.ok(s["ui:open (first, builds the window)"].ms > 0, "timed")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("shots: the wide split view leaves out the 'other view' shot", function()
        local ns = boot()
        slash("")
        local narrow = {}
        for _, s in ipairs(ns.UI.ShotSteps()) do narrow[s.label] = true end
        t.ok(narrow["zones, other view"], "narrow window has it")
        ns.UI.GetFrame():SetSize(1640, 740)
        local wide = {}
        for _, s in ipairs(ns.UI.ShotSteps()) do wide[s.label] = true end
        t.eq(wide["zones, other view"], nil)
        t.ok(wide["zones, sort popup"], "the popup shot stays")
    end)

    t.test("perf: client memory and profiler metrics are read when the client has them", function()
        local ns = boot({ schemaVersion = 4, debug = true })
        _G.UpdateAddOnMemoryUsage = function() end
        _G.GetAddOnMemoryUsage = function(name) return name == "Azerfolio" and 2048.4 or 0 end
        _G.Enum = { AddOnProfilerMetric = { RecentAverageTime = 1, PeakTime = 2, Broken = 3 } }
        _G.C_AddOnProfiler = { IsEnabled = function() return true end,
            GetAddOnMetric = function(_, m) if m == 3 then error("bad metric") end; return m * 0.1 end }
        slash("debug perf")
        local e = ns.db.trace[#ns.db.trace]
        _G.UpdateAddOnMemoryUsage, _G.GetAddOnMemoryUsage, _G.Enum, _G.C_AddOnProfiler = nil, nil, nil, nil
        t.ok(table.concat(wow.chat, "\n"):find("memory 2048 KB"))
        t.eq(e.memoryKB, 2048.4); t.eq(e.profilerEnabled, true)
        t.eq(e.profiler.RecentAverageTime, 0.1); t.eq(e.profiler.PeakTime, 0.2); t.eq(e.profiler.Broken, nil)
        t.eq(#ns.Debug.errors, 1, "the failing metric is recorded, not fatal")
    end)

    t.test("perf: XP gains don't rebuild the Overview; a level-up does", function()
        local level = 9
        local ns = boot()
        _G.UnitLevel = function() return level end
        slash("")
        local page = ns.UI.GetFrame().pages.overview
        local redraws = 0
        local orig = page.Redraw
        page.Redraw = function(self) redraws = redraws + 1; return orig(self) end
        local levels = 0
        ns.Events.On("AZF_LEVEL_CHANGED", function() levels = levels + 1 end)
        wow.fire("PLAYER_XP_UPDATE", "player"); wow.runTimers()
        t.eq(levels, 0); t.eq(redraws, 0, "XP only: header, no Overview rebuild")
        level = 10
        wow.fire("PLAYER_LEVEL_UP", 10); wow.runTimers()
        t.eq(levels, 1); t.eq(redraws, 1)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("quality: a fully corrupted SavedVariables boots, opens every tab and runs every command", function()
        local ns = boot({ schemaVersion = 4, debug = "x", window = { width = -5, height = 1e9, x = 0 / 0,
                point = "NOWHERE" }, lastTab = {}, zones = { displayMode = "atlas", faction = 3,
                completion = "done", level = false, sort = "random" }, launcher = { minimapAngle = 9999,
                minimapHidden = "no" }, notifications = 1, trace = "x" },
            { schemaVersion = 1, baseline = { taken = "yes", exploration = { [1429] = { states = "x" },
                [1411] = 5, junk = { states = {} } } }, milestones = { 1, "a", { kind = "area" } },
                recentZones = { "x", 1429, {} } })
        t.eq(ns.db.window.width, 1000); t.eq(ns.db.window.height, 1100); t.eq(ns.db.window.x, 0)
        t.eq(ns.db.zones.displayMode, "cards"); t.eq(ns.db.zones.sort, "recommended")
        t.eq(ns.db.launcher.minimapAngle, 360)
        t.same(ns.charDB.milestones, {}); t.same(ns.charDB.recentZones, { 1429 })
        wow.runTimers()
        slash("")
        t.ok(ns.UI.IsShown())
        ns.UI.SelectTab("zones"); ns.UI.SelectTab("overview")
        for _, c in ipairs({ "status", "debug zone", "debug exploration", "debug zones", "debug overview",
            "debug", "debug perf", "refresh" }) do slash(c) end
        wow.runTimers()
        CRITERIA[776][4][2] = true
        wow.fire("CRITERIA_UPDATE"); wow.fire("MAP_EXPLORATION_UPDATED")
        wow.runTimers()
        CRITERIA[776][4][2] = false
        t.eq(#ns.charDB.milestones, 1, "a discovery after the rebuilt baseline is a milestone")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("tracker: an unrelated CRITERIA_UPDATE announces nothing", function()
        local ns = boot()
        ns.Exploration.ForZone(1429)
        local got = listen(ns)
        wow.fire("CRITERIA_UPDATE")
        wow.runTimers()
        t.eq(#got, 0)
    end)

    t.test("tracker: outside a tracked zone, discovery events read nothing", function()
        here = 2521
        local ns = boot()
        local got = listen(ns)
        wow.fire("CRITERIA_UPDATE"); wow.runTimers()
        here = 1429
        t.eq(#got, 0)
    end)

    t.test("tracker: login achievement data and /azf refresh re-read every zone", function()
        local ns = boot()
        local a = ns.Exploration.ForZone(1429)
        local got = listen(ns)
        wow.fire("RECEIVED_ACHIEVEMENT_LIST")
        t.eq(got[1], "all")
        t.ok(ns.Exploration.ForZone(1429) ~= a, "cache cleared")
        slash("refresh")
        t.eq(got[2], "all")
    end)

    t.test("tracker: an update for a zone that isn't shown leaves the detail alone", function()
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("")
        local page = ns.UI.GetFrame().pages.zones
        page:Open({ mapID = 1429, name = "Elwynn Forest" })
        local rows = page.detailRows
        ns.Events.Send("AZF_EXPLORATION_UPDATED", { 1426 })
        t.ok(page.detailRows == rows, "not redrawn")
        ns.Events.Send("AZF_EXPLORATION_UPDATED", nil)
        t.ok(page.detailRows ~= rows, "redrawn for all")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("tracker: totals have no percentage while any zone is unreadable", function()
        local ns = boot()
        local all = ns.Exploration.Overall()
        t.eq(all.zones, 43)
        t.eq(all.unavailable, 40, "the fixture has data for 3 zones")
        t.eq(all.progress.percent, nil)
        t.eq(all.progress.coverage, "unavailable")
        t.eq(all.progress.total, 7, "objectives still counted")
    end)

    t.test("tracker: debug trace goes to SavedVariables only in debug mode, capped", function()
        local ns = boot()
        ns.Exploration.RefreshZone(1429)
        t.eq(#ns.db.trace, 0, "off by default")
        ns.db.debug = true
        for _ = 1, ns.Config.LIMITS.trace + 5 do ns.Exploration.RefreshZone(1429) end
        t.eq(#ns.db.trace, ns.Config.LIMITS.trace)
        local e = ns.db.trace[#ns.db.trace]
        t.eq(e.kind, "exploration"); t.eq(e.mapID, 1429); t.eq(e.completed, 2); t.eq(e.denominator, 5)
    end)

    t.test("/azf debug exploration reports the current zone and the total", function()
        local ns = boot()
        slash("debug exploration")
        local all = table.concat(wow.chat, "\n")
        t.ok(all:find("Exploration 1429 %(achievement 776%): 2/5 discovered, 40%%, coverage complete, catalogue differs"), all)
        t.ok(all:find("All zones: no total yet, coverage unavailable %(43 zones, 40 unreadable%)"), all)
        t.eq(#ns.Debug.errors, 0)
    end)

    -- Baseline and milestones (end to end) ------------------------------------------------

    local function discover(achID, index)
        CRITERIA[achID][index][2] = true
        wow.fire("CRITERIA_UPDATE"); wow.fire("MAP_EXPLORATION_UPDATED")
        wow.runTimers()
    end

    t.test("milestones: first login takes the baseline and records nothing", function()
        local ns = boot()
        wow.runTimers() -- the login read of every zone
        local b = ns.charDB.baseline
        t.eq(b.taken, true)
        t.same(b.exploration[1429].states, { [1146] = true, [1147] = true, [1148] = false, [1149] = false, [1150] = false })
        t.eq(b.exploration[1429].complete, false)
        t.ok(b.exploration[1426], "Dun Morogh baselined too, without being opened")
        t.eq(b.exploration[1436], nil, "no data for Westfall: no baseline yet")
        t.eq(#ns.charDB.milestones, 0)
    end)

    t.test("milestones: a live discovery is recorded once with a time, and survives a reload", function()
        local ns = boot()
        wow.runTimers()
        local got = {}
        ns.Events.On("AZF_MILESTONE", function(m) got[#got + 1] = m end)
        discover(776, 3) -- Fargodeep Mine
        local list = ns.charDB.milestones
        t.eq(#list, 1); t.eq(#got, 1)
        t.eq(list[1].kind, "area"); t.eq(list[1].category, "exploration")
        t.eq(list[1].id, 1148); t.eq(list[1].mapID, 1429); t.eq(list[1].name, "Fargodeep Mine")
        t.eq(type(list[1].time), "number", "seen live")
        t.eq(ns.charDB.baseline.exploration[1429].states[1148], true)
        local ns2 = boot(_G.AzerfolioDB, _G.AzerfolioCharDB)
        wow.runTimers()
        slash("refresh"); wow.runTimers()
        CRITERIA[776][3][2] = false
        t.eq(#ns2.charDB.milestones, 1, "no repeat after reload or refresh")
    end)

    t.test("milestones: progress made while Azerfolio wasn't watching has no time", function()
        local ns = boot()
        wow.runTimers()
        local savedAccount, savedChar = _G.AzerfolioDB, _G.AzerfolioCharDB
        CRITERIA[776][4][2] = true -- Crystal Lake, explored with the addon off
        local ns2 = boot(savedAccount, savedChar)
        wow.runTimers()
        CRITERIA[776][4][2] = false
        local list = ns2.charDB.milestones
        t.eq(#list, 1); t.eq(list[1].id, 1149); t.eq(list[1].time, nil, "nobody saw when")
    end)

    t.test("milestones: finishing a zone records the area and the zone", function()
        here = 1411
        local ns = boot()
        wow.runTimers()
        discover(728, 1) -- Valley of Trials, Durotar's only area in the fixture
        CRITERIA[728][1][2] = false
        here = 1429
        local list = ns.charDB.milestones
        t.eq(#list, 2)
        t.eq(list[1].kind, "area"); t.eq(list[2].kind, "zone"); t.eq(list[2].id, 1411)
        t.eq(ns.charDB.baseline.exploration[1411].complete, true)
    end)

    t.test("milestones: a damaged baseline is rebuilt without milestones or errors", function()
        local ns = boot(nil, { schemaVersion = 1, baseline = { taken = true, exploration = { [1429] = "junk" } },
            milestones = { "junk" } })
        wow.runTimers()
        t.eq(type(ns.charDB.baseline.exploration[1429]), "table")
        discover(776, 5)
        CRITERIA[776][5][2] = false
        t.eq(#ns.charDB.milestones, 1, "the junk entry is dropped on load; one real milestone")
        t.eq(ns.charDB.milestones[1].id, 1150)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("milestones: the list is capped at the newest 100", function()
        local old = {}
        for i = 1, 100 do old[i] = { kind = "area", category = "exploration", mapID = 1429, id = 90000 + i } end
        local ns = boot(nil, { schemaVersion = 1, milestones = old })
        wow.runTimers()
        discover(776, 3)
        CRITERIA[776][3][2] = false
        local list = ns.charDB.milestones
        t.eq(#list, 100)
        t.eq(list[100].id, 1148); t.eq(list[1].id, 90002)
    end)

    t.test("/azf debug zones reports the catalogue in chat and in the trace", function()
        _G.UnitFactionGroup = function() return "Alliance", "Alliance" end
        local ns = boot({ schemaVersion = 4, debug = true })
        slash("debug zones")
        local all = table.concat(wow.chat, "\n")
        t.ok(all:find("Zones: 6 listed, 5 shown %(status all, show relevant"), all)
        t.ok(all:find("complete 1, in progress 1, untouched 1, unknown 2, not tracked 1"), all)
        t.ok(all:find("other faction's territory %(Alliance%): Durotar"), all)
        local e = ns.db.trace[#ns.db.trace]
        t.eq(e.kind, "zones"); t.eq(e.shown, 5); t.eq(#e.zones, 6)
        t.ok(table.concat(e.zones, ";"):find("1429 progress 2/5 1%-10 Alliance"), table.concat(e.zones, ";"))
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("/azf shots starts the Zones shots on the catalogue even from Zone Detail", function()
        local ns = boot({ schemaVersion = 4, lastTab = "zones" })
        slash("")
        local p = ns.UI.GetFrame().pages.zones
        p:Open({ mapID = 1429, name = "Elwynn Forest", continent = "Eastern Kingdoms" })
        local modes = {}
        local steps = ns.UI.ShotSteps()
        for i = 1, 2 do steps[i].fn(); modes[i] = ns.UI.CurrentTab() .. ":" .. p.mode end
        t.eq(modes[2], "zones:list")
    end)

    t.test("/azf shots stops if the window is closed", function()
        local ns = boot()
        slash("shots")
        ns.UI.Hide()
        wow.runTimers()
        t.ok(_G.screenshotsTaken <= 1, "stopped early")
        t.eq(ns.UI.shotsRunning, false)
    end)

    ---------------------------------------------------------------------------------------------
    -- Overview
    ---------------------------------------------------------------------------------------------

    local function overview(ns) return ns.UI.GetFrame().pages.overview end
    local function keys(row)
        local out = {}
        for _, it in ipairs(row.items) do out[#out + 1] = tostring(it.key) end
        return table.concat(out, ",")
    end

    t.test("overview: Continue card, suggestions and stats from the live catalogue", function()
        padUI = true
        local ns = boot()
        slash("")
        t.eq(ns.UI.CurrentTab(), "overview")
        local p = overview(ns).parts
        t.eq(p.hero.name:GetText(), "Elwynn Forest")
        t.eq(p.hero.kicker:GetText(), "CONTINUE · YOUR ZONE")
        t.eq(p.hero.pct:GetText(), "40%", "the same number the Zones card shows")
        t.eq(p.hero.count:GetText(), "2 of 5 areas")
        t.ok(p.hero.left:GetText():find("3|r areas to go"), p.hero.left:GetText())
        t.eq(p.goal:IsShown(), false, "no other zone in progress: no next goal")
        local groups = overview(ns).pools.groups
        t.eq(groups[1].name:GetText(), "Elwynn Forest"); t.eq(groups[1].why:GetText(), "Current zone · 3 left")
        t.eq(groups[2], nil, "Durotar is Horde territory; Westfall and Teldrassil have no data")
        t.eq(overview(ns).pools.chips[1].text:GetText(), "Fargodeep Mine")
        -- Most of the 43 catalogue zones have no achievement data in the mock: no percentage.
        t.eq(p.completion.pct:GetText(), "-")
        t.ok(p.completion.line:GetText():find("Waiting for the game's data %(40 of 43 zones unreadable%)"),
            p.completion.line:GetText())
        t.ok(p.zones.count:GetText():find("1|r of 4 complete"), "Durotar left out: " .. p.zones.count:GetText())
        t.ok(p.zones.legend:GetText():find("1 in progress") and p.zones.legend:GetText():find("0 untouched")
            and p.zones.legend:GetText():find("2 no data"), p.zones.legend:GetText())
        t.eq(p.recentEmpty:IsShown(), true, "only the current zone visited so far")
        t.eq(p.activity.empty:IsShown(), true)
        local rows = overview(ns):GetFocusRows()
        t.eq(#rows, 2)
        t.eq(keys(rows[1]), "hero,completion")
        t.eq(keys(rows[2]), "chip:1148,chip:1149,chip:1150,zones")
        t.eq(overview(ns).hasSections, true)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("overview: A on an area opens Zone Detail on it; B comes back to the same chip", function()
        padUI = true
        local ns = boot()
        slash("")
        press(ns, "PADDDOWN"); press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().title, "Crystal Lake")
        press(ns, "PAD1")
        t.eq(ns.UI.CurrentTab(), "zones")
        local z = ns.UI.GetFrame().pages.zones
        t.eq(z.mode, "detail"); t.eq(z.zone.mapID, 1429)
        t.eq(ns.Focus.Current().key, "c1149", "focused on the area")
        press(ns, "PAD2")
        t.eq(ns.UI.CurrentTab(), "overview", "B returns to the Overview")
        t.eq(ns.Focus.Current().key, "chip:1149")
        t.eq(ns.UI.IsShown(), true)
        -- Opened from the catalogue, B stays on Zones.
        press(ns, "PADRSHOULDER")
        t.eq(z.mode, "list")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("overview: RT/LT jump between sections; right moves to the stat panels", function()
        padUI = true
        local ns = boot()
        slash("")
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().key, "chip:1148", "RT: the first suggestion group")
        press(ns, "PADLTRIGGER")
        t.eq(ns.Focus.Current().key, "hero", "LT: back to Continue")
        press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().key, "completion")
        press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().key, "zones", "down stays in the right column")
        press(ns, "PADDLEFT")
        t.eq(ns.Focus.Current().key, "chip:1150", "left: the nearest chip")
        press(ns, "PADDUP")
        t.eq(ns.Focus.Current().key, "hero", "up stays in the left column")
    end)

    t.test("overview: the Zones panel opens the catalogue filtered to complete zones", function()
        padUI = true
        local ns = boot({ schemaVersion = 4, zones = { faction = "all" } })
        slash("")
        ns.Focus.FocusKey("zones")
        t.eq(ns.Focus.Current().actionLabel, "Show complete")
        press(ns, "PAD1")
        t.eq(ns.UI.CurrentTab(), "zones")
        t.eq(ns.db.zones.completion, "complete")
        t.eq(shown(ns), "Dun Morogh")
        t.eq(ns.Focus.Current().title, "Dun Morogh")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("overview: zones you enter are remembered per character and listed, newest first", function()
        padUI = true
        local ns = boot()
        slash("")
        t.same(ns.charDB.recentZones, { 1429 }, "the zone you log in to")
        here = 1426
        wow.fire("ZONE_CHANGED_NEW_AREA")
        here = 2521 -- Zephras Isle isn't tracked: not recorded
        wow.fire("ZONE_CHANGED_NEW_AREA")
        here = 1411
        wow.fire("ZONE_CHANGED_NEW_AREA")
        wow.runTimers()
        here = 1429
        t.same(ns.charDB.recentZones, { 1429, 1426, 1411 })
        local rows = overview(ns).pools.recent
        t.eq(rows[1].name:GetText(), "Dun Morogh"); t.eq(rows[2].name:GetText(), "Elwynn Forest")
        t.eq(rows[1].pct:GetText(), "100%")
        t.eq(overview(ns).parts.hero.name:GetText(), "Durotar", "now the current zone")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("overview: a discovery redraws the card and lists the milestone with its time", function()
        padUI = true
        local ns = boot()
        slash("")
        CRITERIA[776][3][2] = true -- Fargodeep Mine discovered
        wow.fire("CRITERIA_UPDATE")
        wow.runTimers()
        CRITERIA[776][3][2] = false
        local o = overview(ns)
        t.eq(o.parts.hero.pct:GetText(), "60%")
        t.eq(o.pools.chips[1].text:GetText(), "Crystal Lake", "the discovered area is no longer suggested")
        local m = o.pools.milestones[1]
        t.ok(m and m.text:GetText():find("Fargodeep Mine"), m and m.text:GetText())
        t.ok(m.time:GetText():find("^Today, %d%d:%d%d$"), m.time:GetText())
        t.ok(o.parts.activity.today:GetText():find("1|r today"), o.parts.activity.today:GetText())
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("overview: redraws while hidden wait for the next show; frames are reused", function()
        local ns = boot()
        slash("")
        local o = overview(ns)
        ns.UI.SelectTab("zones")
        ns.Events.Send("AZF_MILESTONE", {})
        t.eq(o.dirty, true)
        local before = wow.frameCount()
        ns.UI.SelectTab("overview")
        t.eq(o.dirty, false)
        for _ = 1, 3 do o:Redraw() end
        t.eq(wow.frameCount(), before, "no new frames on redraw")
    end)

    t.test("/azf debug overview reports the picks in chat and in the trace", function()
        local ns = boot({ schemaVersion = 4, debug = true })
        slash("debug overview")
        local text = table.concat(wow.chat, "\n")
        t.ok(text:find("continue: Elwynn Forest %(current%)"), text)
        t.ok(text:find("suggestions: Elwynn Forest %(current, 3 left%)\n"), text)
        t.ok(text:find("zones 1 of 4 complete %(1 in progress, 0 untouched, 2 unknown%)"), text)
        local e = ns.db.trace[#ns.db.trace]
        t.eq(e.kind, "overview"); t.eq(e.hero, 1429)
    end)
end
