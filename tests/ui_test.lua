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

local function boot(savedAccount)
    wow.install({
        C_Map = { GetMapInfo = function(id) return MAPS[id] end },
        GetCategoryNumAchievements = function(cat) return achievementsReady and #(ACH[cat] or {}) or 0 end,
        GetAchievementInfo = function(cat, i) local a = ACH[cat] and ACH[cat][i]; if a then return a.id, a.name end end,
        GetAchievementNumCriteria = function(id) return #(CRITERIA[id] or {}) end,
        GetAchievementCriteriaInfo = function(id, i)
            local c = CRITERIA[id][i]
            return c[1], 43, c[2], c[2] and 1 or 0, 1, "", 0, 0, "", c[3], true
        end,
        UnitName = function() return "Gideon" end,
        UnitLevel = function() return 9 end,
        UnitXP = function() return 273 end,
        UnitXPMax = function() return 6500 end,
        GetMaxPlayerLevel = function() return 60 end,
        GetZoneText = function() return "Elwynn Forest" end,
        GetSubZoneText = function() return "Goldshire" end,
        InputUtil = { IsGamepadUIEnabled = function() return padUI end },
        Screenshot = function() _G.screenshotsTaken = (_G.screenshotsTaken or 0) + 1 end,
    })
    _G.AzerfolioDB, _G.AzerfolioCharDB = savedAccount, nil
    _G.screenshotsTaken = 0
    local ns = wow.loadToc("Azerfolio", "Azerfolio")
    wow.fire("ADDON_LOADED", "Azerfolio")
    wow.fire("PLAYER_LOGIN")
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
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        local info = function() return ns.UI.GetFrame().legend.info:GetText() end
        t.eq(ns.Focus.Current().title, "Dun Morogh", "starts on the first zone")
        t.ok(info():find("Dun Morogh"), info())
        t.eq(ns.Focus.pointer:IsShown(), true, "chevron shown")
        press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Elwynn Forest")
        t.ok(info():find("Elwynn Forest") and info():find("Eastern Kingdoms"), info())
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "Durotar", "RT: next continent")
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "Zephras Isle")
        press(ns, "PADLTRIGGER")
        t.eq(ns.Focus.Current().title, "Durotar", "LT: previous continent")
        press(ns, "PADDUP")
        t.eq(ns.Focus.Current().title, "Westfall", "up crosses into the previous continent")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("focus is remembered per tab", function()
        padUI = true
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        press(ns, "PADDDOWN"); press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Westfall")
        press(ns, "PADLSHOULDER")
        t.eq(ns.UI.CurrentTab(), "overview")
        t.eq(ns.Focus.Current(), nil, "the placeholder Overview has nothing to focus")
        t.eq(ns.Focus.pointer:IsShown(), false)
        press(ns, "PADRSHOULDER")
        t.eq(ns.Focus.Current().title, "Westfall", "back where it was")
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
        t.eq(#ex.criteria, 5)
        t.eq(ex.criteria[1].id, 1146); t.eq(ex.criteria[1].name, "Northshire Valley"); t.eq(ex.criteria[1].completed, true)
        t.eq(ex.summary.done, 2); t.eq(ex.summary.todo, 3); t.eq(ex.summary.total, 5)
        t.eq(ns.Exploration.ForZone({ mapID = 1436, name = "Westfall" }).status, "untracked")
    end)

    t.test("unknown completion is counted as unknown, never done or not done", function()
        local ns = boot()
        local s = ns.Exploration.Summarize({ { completed = true }, { completed = false }, { completed = nil } })
        t.eq(s.done, 1); t.eq(s.todo, 1); t.eq(s.unknown, 1); t.eq(s.total, 3)
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
        local ns = boot({ schemaVersion = 2, lastTab = "zones" })
        slash("")
        press(ns, "PADDDOWN")
        t.eq(ns.Focus.Current().title, "Elwynn Forest")
        press(ns, "PAD1")
        local page = ns.UI.GetFrame().pages.zones
        t.eq(page.mode, "detail")
        t.eq(page.detail.banner.name:GetText(), "Elwynn Forest")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "first area to discover")
        t.eq(ns.Focus.Current().detail, "Not discovered yet")
        press(ns, "PADDRIGHT")
        t.eq(ns.Focus.Current().title, "Crystal Lake", "two columns")
        press(ns, "PADRTRIGGER")
        t.eq(ns.Focus.Current().title, "Northshire Valley", "RT: Discovered section")
        t.eq(ns.Focus.Current().detail, "Discovered")
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
        page:Open({ mapID = 1436, name = "Westfall", continent = "Eastern Kingdoms" })
        t.ok(page.detail.message:IsShown())
        t.ok(page.detail.message:GetText():find("no Explore achievement for Westfall"))
        t.eq(#page:GetFocusRows(), 0)
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
        t.eq(page.list.byMap[1426].selected, true, "its row is marked")
        press(ns, "PADDDOWN")
        t.eq(page.detail.banner.name:GetText(), "Elwynn Forest", "detail follows focus")
        t.eq(page.list.byMap[1426].selected, false); t.eq(page.list.byMap[1429].selected, true)
        t.ok(f.legend.hints:GetWidth() > 1, "hints drawn")
        t.eq(ns.Focus.Current().actionLabel, "Checklist")
        press(ns, "PAD1")
        t.eq(page.mode, "detail")
        t.eq(page.list:IsShown(), true, "the list stays visible")
        t.eq(ns.Focus.Current().title, "Fargodeep Mine", "A moves into the areas")
        press(ns, "PADDDOWN")
        t.eq(page.detail.banner.name:GetText(), "Elwynn Forest", "moving in the areas keeps the zone")
        press(ns, "PAD2")
        t.eq(page.mode, "list")
        t.eq(ns.Focus.Current().title, "Elwynn Forest", "B returns to the zone")
        t.eq(ns.UI.IsShown(), true)
        f:SetSize(1160, 740); ns.UI.Relayout()
        t.eq(page.wide, false)
        t.eq(page.detail:IsShown(), false, "narrow again: list only")
        t.eq(page.list.byMap[1429].selected, false, "no selection mark in the narrow list")
        t.eq(ns.Focus.Current().actionLabel, "Open")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("wide window: a click selects, A on an untracked zone stays in the list", function()
        local ns = boot({ schemaVersion = 3, lastTab = "zones" })
        slash("")
        local f = ns.UI.GetFrame()
        f:SetSize(1640, 740); ns.UI.Relayout()
        local page = f.pages.zones
        local row = page.list.byMap[1436]
        row.scripts.OnClick(row)
        t.eq(page.mode, "list")
        t.eq(page.detail.banner.name:GetText(), "Westfall")
        t.eq(ns.Focus.Current().title, "Westfall", "focus follows the click")
        t.eq(row.item.canActivate(), false, "no A hint: nothing to move into")
        t.eq(page.list.byMap[1429].item.canActivate(), true, "another zone still can")
        page:Open(row.item.zone)
        t.eq(page.mode, "list", "no areas to move into")
        t.ok(page.detail.message:GetText():find("no Explore achievement"), "the reason shows")
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

    t.test("the addon compartment and the key binding toggle the window", function()
        local ns = boot()
        t.eq(_G.BINDING_NAME_AZERFOLIO_TOGGLE, "Open or close Azerfolio")
        _G.Azerfolio_OnAddonCompartmentClick("Azerfolio", "LeftButton")
        t.eq(ns.UI.IsShown(), true)
        _G.Azerfolio_Toggle()
        t.eq(ns.UI.IsShown(), false)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("TOC compartment fields and Bindings.xml name functions that exist", function()
        boot()
        local meta = wow.tocMetadata("Azerfolio", "Azerfolio")
        for _, k in ipairs({ "AddonCompartmentFunc", "AddonCompartmentFuncOnEnter", "AddonCompartmentFuncOnLeave" }) do
            t.eq(type(_G[meta[k]]), "function", k .. " -> " .. tostring(meta[k]))
        end
        local f = assert(io.open("Azerfolio/Bindings.xml", "r"))
        local xml = f:read("*a"); f:close()
        local name = xml:match('<Binding name="([%w_]+)"')
        t.eq(name, "AZERFOLIO_TOGGLE")
        t.ok(_G["BINDING_NAME_" .. name], "binding label defined")
        local call = xml:match("([%w_]+)%(%)")
        t.eq(type(_G[call]), "function", "binding calls " .. tostring(call))
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
        t.eq(_G.screenshotsTaken, #ns.UI.ShotSteps())
        t.eq(_G.screenshotsTaken, 9)
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

    t.test("/azf shots stops if the window is closed", function()
        local ns = boot()
        slash("shots")
        ns.UI.Hide()
        wow.runTimers()
        t.ok(_G.screenshotsTaken <= 1, "stopped early")
        t.eq(ns.UI.shotsRunning, false)
    end)
end
