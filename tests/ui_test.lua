-- Main window, tabs, geometry, gamepad layer and /azf shots, against the mock client.
local wow = require("mocks.wow")

local padUI = true

local function boot(savedAccount)
    wow.install({
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
        t.eq(ns.UI.GetFrame().footer.lb:IsShown(), false, "hints hidden")
        wow.fire("PLAYER_REGEN_ENABLED")
        t.eq(ns.Gamepad.GetInputFrame().gamePadButton, true)
        t.eq(ns.UI.GetFrame().footer.lb:IsShown(), true)
    end)

    t.test("gamepad: nothing is taken when the gamepad UI is off", function()
        padUI = false
        local ns = boot()
        slash("")
        t.eq(ns.Gamepad.IsActive(), false)
        t.ok(not ns.Gamepad.GetInputFrame().gamePadButton, "input not enabled")
        t.eq(ns.UI.GetFrame().footer.lb:IsShown(), false)
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
        t.eq(_G.screenshotsTaken, 4)
        t.eq(ns.UI.CurrentTab(), "zones", "tab restored")
        t.eq(ns.UI.GetFrame():GetWidth(), 1160, "size restored")
        t.eq(ns.UI.shotsRunning, false)
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
