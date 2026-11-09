-- Addon-owned gamepad input for the main window (spec §4.3, plan Phase 4 task 6).
-- One input frame on the window takes controller buttons only while the window is shown, the
-- client's gamepad UI is on, and the player is out of combat. Never touches Blizzard's
-- SmartNavigation (secure-only registration; taint risk; see client-capabilities § Gamepad).
-- LB/RB switch tabs, B closes, D-pad moves focus (UI/Focus.lua), A activates, LT/RT jump
-- between sections, X and Y go to the page (page:OnButton).
local _, ns = ...

local Gamepad = {}
ns.Gamepad = Gamepad

local input   -- the input frame (child of the window)
local owner   -- the window frame
local active = false

-- Button names [verified-ingame]; the client's GAMEPAD_* constants are preferred when present.
local function name(constant, fallback)
    local v = _G[constant]
    return type(v) == "string" and v or fallback
end

-- Maps a button name to a window action. Pure; built on first use so constants are read late.
local actionMap
local function actions()
    if actionMap then return actionMap end
    actionMap = {
        [name("GAMEPAD_SHOULDER_LEFT", "PADLSHOULDER")] = "prevTab",
        [name("GAMEPAD_SHOULDER_RIGHT", "PADRSHOULDER")] = "nextTab",
        [name("GAMEPAD_FACE_RIGHT", "PAD2")] = "back",
        [name("GAMEPAD_FACE_BOTTOM", "PAD1")] = "activate",
        [name("GAMEPAD_FACE_LEFT", "PAD3")] = "x", -- [verified-ingame: /azfdiag pad]
        [name("GAMEPAD_FACE_TOP", "PAD4")] = "y",
        [name("GAMEPAD_DPAD_TOP", "PADDUP")] = "up",
        [name("GAMEPAD_DPAD_BOTTOM", "PADDDOWN")] = "down",
        [name("GAMEPAD_DPAD_LEFT", "PADDLEFT")] = "left",
        [name("GAMEPAD_DPAD_RIGHT", "PADDRIGHT")] = "right",
        [name("GAMEPAD_TRIGGER_LEFT", "PADLTRIGGER")] = "prevSection",
        [name("GAMEPAD_TRIGGER_RIGHT", "PADRTRIGGER")] = "nextSection",
    }
    return actionMap
end

function Gamepad.ActionFor(button)
    return actions()[button]
end

-- Is the client's gamepad UI on? [verified-ingame: InputUtil.IsGamepadUIEnabled]
function Gamepad.IsUIEnabled()
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        return ns.Debug.Try("IsGamepadUIEnabled", InputUtil.IsGamepadUIEnabled) == true
    end
    if C_GamePad and type(C_GamePad.IsEnabled) == "function" then
        return ns.Debug.Try("C_GamePad.IsEnabled", C_GamePad.IsEnabled) == true
    end
    return false
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

-- True while the controller drives the window.
function Gamepad.IsActive() return active end

-- Pure rule, for tests: should the input frame take buttons?
function Gamepad.ShouldBeActive(windowShown, uiEnabled, combat)
    return windowShown and uiEnabled and not combat
end

local function handle(action)
    -- A modal on the window (a celebration) takes every button first.
    local modal = ns.UI.modal
    if modal and modal.OnAction and modal.OnAction(action) then return end
    if action == "prevTab" then
        ns.UI.NextTab(-1)
    elseif action == "nextTab" then
        ns.UI.NextTab(1)
    elseif action == "back" then
        ns.UI.Back()
    elseif action == "activate" then
        ns.Focus.Activate()
    elseif action == "x" or action == "y" then
        ns.UI.PageButton(action) -- the page decides (Zones: X search, Y next view)
    elseif action == "prevSection" or action == "nextSection" then
        ns.Focus.Jump(action == "nextSection" and 1 or -1)
        ns.UI.RefreshHints()
    else
        ns.Focus.Move(action)
        ns.UI.RefreshHints()
    end
end

-- Re-evaluates whether the layer takes input. Call on show, hide, and combat changes.
-- `combat` overrides the lockdown check (PLAYER_REGEN_DISABLED fires just before lockdown).
function Gamepad.Update(combat)
    if not input then return end
    if combat == nil then combat = inCombat() end
    local want = Gamepad.ShouldBeActive(owner:IsShown(), Gamepad.IsUIEnabled(), combat)
    if want ~= active then
        local ok, err = pcall(input.EnableGamePadButton, input, want)
        if not ok then
            ns.Debug.Error("EnableGamePadButton", err)
            want = false
        end
        active = want
        if owner:IsShown() then ns.UI.RefreshHints() end
        ns.Debug.Print("gamepad input %s", active and "on" or "off")
    end
end

function Gamepad.GetInputFrame() return input end -- for tests

function Gamepad.Attach(window)
    if input then return end
    owner = window
    input = CreateFrame("Frame", nil, window)
    input:SetAllPoints(window)
    input:SetScript("OnGamePadButtonDown", function(_, button)
        local action = Gamepad.ActionFor(button)
        if action then
            local ok, err = pcall(handle, action)
            if not ok then ns.Debug.Error("gamepad " .. action, err) end
        end
    end)
    ns.Events.Register("PLAYER_REGEN_DISABLED", function() Gamepad.Update(true) end)
    ns.Events.Register("PLAYER_REGEN_ENABLED", function() Gamepad.Update(false) end)
end
