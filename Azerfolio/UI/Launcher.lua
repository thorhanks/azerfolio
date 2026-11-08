-- Ways to open the window besides /azf (plan Phase 4 task 4), all without libraries:
--   * the client's addon compartment (TOC AddonCompartmentFunc*, globals below);
--   * an in-house minimap button, dragged around the minimap edge, angle saved;
--   * a key binding (Bindings.xml -> Azerfolio_Toggle), assignable to a controller combo.
local _, ns = ...

local Launcher = {}
ns.Launcher = Launcher

local BUTTON_NAME = "AzerfolioMinimapButton"
local SIZE = 31
local ICON = "Interface\\Icons\\INV_Misc_Book_11"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"     -- [unverified on this client]
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background" -- [unverified on this client]
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local EDGE_OFFSET = 10 -- the button's centre sits this far outside the minimap's radius

local button

---------------------------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------------------------

-- Offset from the minimap centre for an angle in degrees (0 = right, counter-clockwise).
function Launcher.PositionForAngle(angle, radius)
    local a = math.rad(angle)
    return math.cos(a) * radius, math.sin(a) * radius
end

-- Angle in degrees, 0..360, of point (x, y) seen from centre (cx, cy).
function Launcher.AngleTo(x, y, cx, cy)
    local deg = math.deg(math.atan2(y - cy, x - cx))
    if deg < 0 then deg = deg + 360 end
    return math.floor(deg * 10 + 0.5) / 10
end

---------------------------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------------------------

local function place()
    local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
    local x, y = Launcher.PositionForAngle(ns.db.launcher.minimapAngle, radius)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function followCursor()
    local scale = Minimap:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local cx, cy = Minimap:GetCenter()
    ns.db.launcher.minimapAngle = Launcher.AngleTo(x / scale, y / scale, cx, cy)
    place()
end

local function showTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Azerfolio", 1, 0.82, 0)
    GameTooltip:AddLine("Click to open or close.", 1, 1, 1)
    if owner == button then GameTooltip:AddLine("Drag to move around the minimap.", 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

local function buildButton()
    if button or not Minimap then return end
    local b = CreateFrame("Button", BUTTON_NAME, Minimap)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    bg:SetTexture(BACKGROUND)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    local mask = b:CreateMaskTexture()
    if mask then
        mask:SetAllPoints(icon)
        mask:SetTexture(ns.Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(icon.AddMaskTexture, icon, mask)
    end
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture(BORDER)
    b:SetHighlightTexture(HIGHLIGHT)

    b:SetScript("OnClick", function() ns.UI.Toggle() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", followCursor)
        hideTooltip()
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", showTooltip)
    b:SetScript("OnLeave", hideTooltip)
    button = b
    Launcher.button = b
end

-- Shows or hides the minimap button per the saved setting.
function Launcher.Refresh()
    if ns.db.launcher.minimapHidden then
        if button then button:Hide() end
        return
    end
    buildButton()
    if button then place(); button:Show() end
end

function Launcher.ToggleMinimapButton()
    ns.db.launcher.minimapHidden = not ns.db.launcher.minimapHidden
    Launcher.Refresh()
    return not ns.db.launcher.minimapHidden
end

---------------------------------------------------------------------------------------------
-- Globals the client calls (TOC compartment fields, Bindings.xml)
---------------------------------------------------------------------------------------------

local function safely(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Debug.Error(label, err) end
end

function Azerfolio_Toggle()
    if not ns.ready then return end
    safely("key binding", ns.UI.Toggle)
end

function Azerfolio_OnAddonCompartmentClick()
    if not ns.ready then return end
    safely("addon compartment", ns.UI.Toggle)
end

function Azerfolio_OnAddonCompartmentEnter(_, frame)
    safely("addon compartment", showTooltip, frame)
end

function Azerfolio_OnAddonCompartmentLeave()
    hideTooltip()
end

BINDING_HEADER_AZERFOLIO = "Azerfolio"
BINDING_NAME_AZERFOLIO_TOGGLE = "Open or close Azerfolio"

ns.Events.On("AZF_READY", function() Launcher.Refresh() end)
