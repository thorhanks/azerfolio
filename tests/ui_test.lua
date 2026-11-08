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
        page:Open({ mapID = 2521, name = "Zephras Isle", continent = "Other places" })
        t.ok(page.detail.message:IsShown())
        t.ok(page.detail.message:GetText():find("no Explore achievement for Zephras Isle"))
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
        local row = page.list.byMap[2521]
        row.scripts.OnClick(row)
        t.eq(page.mode, "list")
        t.eq(page.detail.banner.name:GetText(), "Zephras Isle")
        t.eq(ns.Focus.Current().title, "Zephras Isle", "focus follows the click")
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
        t.eq(#ns.charDB.milestones, 2, "the junk entry plus one real milestone")
        t.eq(ns.charDB.milestones[2].id, 1150)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("milestones: the list is capped at the newest 100", function()
        local old = {}
        for i = 1, 100 do old[i] = { kind = "area", category = "exploration", id = 90000 + i } end
        local ns = boot(nil, { schemaVersion = 1, milestones = old })
        wow.runTimers()
        discover(776, 3)
        CRITERIA[776][3][2] = false
        local list = ns.charDB.milestones
        t.eq(#list, 100)
        t.eq(list[100].id, 1148); t.eq(list[1].id, 90002)
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
