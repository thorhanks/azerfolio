-- /azf shots: opens the window and screenshots each tab and state, so the agent can review the
-- real UI from <game>\Screenshots (plan §4.3). Development aid; changes nothing it doesn't restore.
local _, ns = ...

local UI = ns.UI

local SETTLE = 0.5 -- seconds after a change before the screenshot
local GAP = 1.0    -- seconds after a screenshot before the next change

-- Each step changes the window, then one screenshot is taken.
local function steps()
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function size(w, h) return function() UI.GetFrame():SetSize(w, h) end end
    local list = {}
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id, fn = function() UI.ApplyGeometry(); UI.SelectTab(def.id) end }
    end
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id .. " at minimum size", fn = function()
            UI.SelectTab(def.id); size(minW, minH)()
        end }
    end
    return list
end
UI.ShotSteps = steps

function UI.RunShots()
    if type(Screenshot) ~= "function" then
        ns.Print("Screenshot() is not available on this client.")
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        ns.Print("Not during combat.")
        return
    end
    if UI.shotsRunning then return end
    UI.Show()
    if not UI.IsShown() then return end

    local list, startTab, i = steps(), UI.CurrentTab(), 0
    UI.shotsRunning = true
    local function finish(msg)
        UI.shotsRunning = false
        UI.ApplyGeometry()
        UI.SelectTab(startTab)
        ns.Print(msg)
    end
    local function nextStep()
        if not UI.IsShown() then return finish("Screenshots stopped: the window was closed.") end
        i = i + 1
        local s = list[i]
        if not s then return finish(string.format("Took %d screenshots.", #list)) end
        local ok, err = pcall(s.fn)
        if not ok then
            ns.Debug.Error("shots " .. s.label, err)
            return finish("Screenshots stopped: " .. tostring(err))
        end
        C_Timer.After(SETTLE, function()
            local sok, serr = pcall(Screenshot)
            if not sok then ns.Debug.Error("Screenshot", serr) end
            ns.Debug.Print("shot %d: %s", i, s.label)
            C_Timer.After(GAP, nextStep)
        end)
    end
    ns.Printf("Taking %d screenshots; keep the window open.", #list)
    nextStep()
end
