-- The celebration overlay and the on-screen alert (mockups/DESIGN.md "Celebrations").
-- ns.Celebrations decides what to celebrate; this file only shows it.
--   Window open: a dark overlay over the window with still rays and rising motes, a card in
--   the painted frame: a category's icon in a gold ring with the faction's streamer beside
--   it, or the zone's war standard hoisted for a claim. A or B (or the button) continues;
--   the next waiting celebration follows.
--   Window closed: an alert at the top centre of the screen for a few seconds; the waiting
--   celebrations play when the window opens.
-- Rays are still textures: Rotation animations misbehave in this client (ZoneBanner.lua).
local _, ns = ...

local Celebration = {}
ns.Celebration = Celebration

Celebration.ALERT_SECONDS = 5
local CARD_W = 470

local TITLE = {
    explore = function(z) return z.name .. " Explored" end,
    quests = function(z) return z.name .. ": Every Quest Done" end,
    flights = function(z) return z.name .. ": Every Flight Path" end,
    claim = function(z) return z.name .. " Claimed" end,
}
local UNIT_ONE = { explore = "area", quests = "quest", flights = "flight path" }

local function faction()
    return (ns.character and ns.character.faction == "Horde") and "Horde" or "Alliance"
end

local function catOf(z, key)
    for _, c in ipairs(z.cats or {}) do if c.key == key then return c end end
end

local function countText(c, key)
    local n = c and c.denominator or 0
    return n .. " " .. (n == 1 and UNIT_ONE[key] or ns.Theme.category[key].unit)
end

-- The line under a category's title: "All 12 areas discovered. Elwynn Forest is now 80%."
local function catLine(z, key)
    local c = catOf(z, key)
    local n = c and c.denominator or 0
    local what = key == "explore" and ("All " .. countText(c, key) .. " discovered.")
        or key == "quests" and ("All " .. countText(c, key) .. " you can do here are complete.")
        or ("All " .. countText(c, key) .. " discovered.")
    if key == "quests" and n == 1 then what = "The only quest you can do here is complete." end
    local pct = z.combined and ns.Progression.PercentText(z.combined)
    return what .. (pct and ("  " .. z.name .. " is now |cffffffff" .. pct .. "|r.") or "")
end

---------------------------------------------------------------------------------------------
-- Overlay
---------------------------------------------------------------------------------------------

local overlay

local function build(window)
    local T, S = ns.Theme, ns.Theme.space
    local o = CreateFrame("Frame", nil, window)
    o:SetAllPoints(window)
    o:SetFrameLevel((window:GetFrameLevel() or 1) + 100)
    if o.EnableMouse then o:EnableMouse(true) end -- clicks don't reach the page underneath
    o.dark = o:CreateTexture(nil, "BACKGROUND")
    o.dark:SetAllPoints(); o.dark:SetColorTexture(0.02, 0.012, 0, 0.94)
    o.warm = o:CreateTexture(nil, "BACKGROUND", nil, 1)
    o.warm:SetPoint("CENTER", 0, 30); o.warm:SetSize(900, 700)
    o.warm:SetColorTexture(0.35, 0.22, 0.04, 0.22)
    local m = o:CreateMaskTexture()
    if m then
        m:SetAllPoints(o.warm)
        m:SetTexture(T.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(o.warm.AddMaskTexture, o.warm, m)
    end
    o.rays = {}
    for i = 1, 12 do
        local r = o:CreateTexture(nil, "BACKGROUND", nil, 2)
        r:SetSize(34, 1100)
        r:SetPoint("CENTER", 0, 30)
        r:SetColorTexture(1, 0.83, 0.35, 0.05)
        if r.SetRotation then r:SetRotation((i - 1) * math.pi / 12) end
        o.rays[i] = r
    end
    -- Rising motes: small frames (a Translation on a texture only faded in place in game).
    o.motes = {}
    for i = 1, 16 do
        local mf = CreateFrame("Frame", nil, o)
        mf:SetSize(4, 4)
        mf:SetPoint("BOTTOM", o, "BOTTOMLEFT", 40 + ((i * 97) % 1000), 0)
        local dot = mf:CreateTexture(nil, "ARTWORK")
        dot:SetAllPoints(); dot:SetColorTexture(1, 0.91, 0.63, 1)
        mf:SetAlpha(0)
        if mf.CreateAnimationGroup then
            local ag = mf:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local d = 5 + (i % 4)
            local wait = (i * 0.9) % d
            local up = ag:CreateAnimation("Translation"); up:SetOffset(0, 520); up:SetDuration(d)
            local fin = ag:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(0.9); fin:SetDuration(d * 0.15)
            local fout = ag:CreateAnimation("Alpha"); fout:SetFromAlpha(0.9); fout:SetToAlpha(0); fout:SetDuration(d * 0.85)
            if up.SetStartDelay then
                up:SetStartDelay(wait); fin:SetStartDelay(wait); fout:SetStartDelay(wait + d * 0.15)
            end
            mf.anim = ag
        end
        o.motes[i] = mf
    end

    -- The card.
    local card = CreateFrame("Frame", nil, o)
    card:SetWidth(CARD_W)
    card:SetPoint("CENTER", 0, 10)
    card.bg = T.Solid(card, "cardBg", "BACKGROUND", 0.97)
    card.bg:SetAllPoints()
    card.frame = T.CardFrame(card, 22, 5)
    o.card = card
    -- Category: a gold ring with the category's icon, the faction's streamer beside it.
    card.medal = CreateFrame("Frame", nil, card)
    card.medal:SetSize(150, 150)
    card.medal:SetPoint("TOP", 0, -26)
    local function circle(size, r, g, b, a, sub)
        local t = card.medal:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetSize(size, size); t:SetPoint("CENTER", -10, 6)
        t:SetColorTexture(r, g, b, a)
        local mk = card.medal:CreateMaskTexture()
        if mk then
            mk:SetAllPoints(t)
            mk:SetTexture(T.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            pcall(t.AddMaskTexture, t, mk)
        end
        return t
    end
    card.glow = circle(132, 1, 0.78, 0.31, 0.18, 0)
    card.ringOuter = circle(108, 0.72, 0.54, 0.18, 1, 1)
    card.ringInner = circle(98, 0.07, 0.04, 0.01, 1, 2)
    card.icon = card.medal:CreateTexture(nil, "ARTWORK", nil, 3)
    card.icon:SetSize(64, 64); card.icon:SetPoint("CENTER", -10, 6)
    card.streamer = card.medal:CreateTexture(nil, "ARTWORK", nil, 0)
    card.streamer:SetSize(26, 156)
    card.streamer:SetPoint("TOPRIGHT", card.medal, "TOPRIGHT", -2, 8)
    card.streamer:SetTexCoord(0, 1, 0.125, 0.875) -- the 1:6 painting inside its 1:8 canvas
    -- Claim: the zone's standard.
    card.banner = ns.ZoneBanner.New(card)
    card.banner:SetPoint("TOP", card, "TOP", 0, -14)
    card.kicker = T.Text(card, "xs", "gold")
    card.title = T.Text(card, "xxl", "gold")
    card.title:SetWidth(CARD_W - 40); card.title:SetWordWrap(true)
    card.line = T.Text(card, "md", "text")
    card.line:SetWidth(CARD_W - 60); card.line:SetWordWrap(true)
    card.cats = T.Text(card, "sm", "dim")
    card.button = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.button:SetSize(150, 26)
    card.button:SetText("Continue")
    card.button:SetScript("OnClick", function() Celebration.Close() end)
    o:Hide()
    return o
end

local function place(o, top)
    local card, S = o.card, ns.Theme.space
    card.kicker:ClearAllPoints(); card.kicker:SetPoint("TOP", card, "TOP", 0, -top)
    card.title:ClearAllPoints(); card.title:SetPoint("TOP", card.kicker, "BOTTOM", 0, -S.s1)
    card.line:ClearAllPoints(); card.line:SetPoint("TOP", card.title, "BOTTOM", 0, -S.s2)
    local below = card.line
    if card.cats:IsShown() then
        card.cats:ClearAllPoints(); card.cats:SetPoint("TOP", card.line, "BOTTOM", 0, -S.s2)
        below = card.cats
    end
    card.button:ClearAllPoints(); card.button:SetPoint("TOP", below, "BOTTOM", 0, -S.s4)
    local h = top + 14 + S.s1 + (card.title:GetStringHeight() or 30) + S.s2 + (card.line:GetStringHeight() or 16)
        + (card.cats:IsShown() and (S.s2 + 16) or 0) + S.s4 + 26 + 26
    card:SetHeight(math.max(240, math.floor(h + 0.5)))
end

local function fill(o, ev)
    local T, card, z = ns.Theme, o.card, ev.zone
    local claim = ev.kind == "claim"
    card.medal:SetShown(not claim)
    card.banner:SetShown(claim)
    card.cats:SetShown(claim)
    if claim then
        local scale = 0.66
        card.banner:SetScale(scale)
        card.banner:Set(z, faction(), true, true)
        card.kicker:SetText("ZONE CLAIMED")
        card.title:SetText(z.name)
        card.line:SetText("Claimed for the " .. faction() .. ".")
        local parts = {}
        for _, c in ipairs(z.cats or {}) do
            if not c.pending then
                parts[#parts + 1] = "|T" .. tostring(T.category[c.key].icon) .. ":14:14|t |cffffd35a"
                    .. c.denominator .. "|r " .. (c.denominator == 1 and UNIT_ONE[c.key] or T.category[c.key].unit)
            end
        end
        card.cats:SetText(table.concat(parts, "     "))
        place(o, math.floor(14 + (card.banner:GetHeight() or 440) * scale + 6))
    else
        card.icon:SetTexture(T.category[ev.kind].icon)
        local key = faction() == "Horde" and "horde" or "alliance"
        local art = ns.Art and ns.Art.banner and ns.Art.banner["streamer-" .. key]
        card.streamer:SetShown(art ~= nil)
        if art then card.streamer:SetTexture(ns.ZoneBanner.MEDIA .. "streamer-" .. key .. ".blp") end
        card.kicker:SetText("STREAMER EARNED")
        card.title:SetText(TITLE[ev.kind](z))
        card.line:SetText(catLine(z, ev.kind))
        place(o, 26 + 150 + 4)
    end
end

-- What the gamepad does while a celebration shows: A or B continues; nothing else.
local modal = {
    hints = { { "A", "Continue" } },
    OnAction = function(action)
        if action == "activate" or action == "back" then Celebration.Close() end
        return true
    end,
}

-- Shows the next waiting celebration over the window (if open and none is showing).
function Celebration.PlayNext()
    if not (ns.UI.IsShown() and ns.Celebrations) then return end
    if overlay and overlay:IsShown() then return end
    local ev = ns.Celebrations.Next()
    if not ev then return end
    overlay = overlay or build(ns.UI.GetFrame())
    fill(overlay, ev)
    overlay:Show()
    for _, m in ipairs(overlay.motes) do if m.anim then m.anim:Play() end end
    ns.UI.modal = modal
    ns.UI.RefreshHints()
    ns.Debug.Trace("celebration", { mapID = ev.mapID, kind = ev.kind })
end

function Celebration.IsShown() return overlay ~= nil and overlay:IsShown() end
function Celebration.GetOverlay() return overlay end -- for tests

function Celebration.Close()
    if overlay then
        for _, m in ipairs(overlay.motes) do if m.anim then m.anim:Stop() end end
        overlay:Hide()
    end
    if ns.UI.modal == modal then ns.UI.modal = nil end
    ns.UI.RefreshHints()
    Celebration.PlayNext()
end

---------------------------------------------------------------------------------------------
-- On-screen alert (window closed)
---------------------------------------------------------------------------------------------

local alert

local function buildAlert()
    local T, S = ns.Theme, ns.Theme.space
    local a = T.Plate(UIParent, 52)
    a:SetSize(440, 52)
    a:SetPoint("TOP", UIParent, "TOP", 0, -150)
    a:SetFrameStrata("HIGH")
    a.title:ClearAllPoints()
    a.icon = a:CreateTexture(nil, "ARTWORK")
    a.icon:SetSize(26, 26)
    a.icon:SetPoint("LEFT", 74, 0)
    a.small = T.Text(a, "xs", "dim")
    a.small:SetPoint("TOPLEFT", a.icon, "TOPRIGHT", S.s2, 1)
    a.small:SetText("AZERFOLIO")
    a.title:SetPoint("BOTTOMLEFT", a.icon, "BOTTOMRIGHT", S.s2, -1)
    if a.CreateAnimationGroup then
        local ag = a:CreateAnimationGroup()
        local fin = ag:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.4); fin:SetOrder(1)
        local hold = ag:CreateAnimation("Alpha"); hold:SetFromAlpha(1); hold:SetToAlpha(1)
        hold:SetDuration(Celebration.ALERT_SECONDS - 1.2); hold:SetOrder(2)
        local fout = ag:CreateAnimation("Alpha"); fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.8); fout:SetOrder(3)
        ag:SetScript("OnFinished", function() a:Hide() end)
        a.anim = ag
    end
    a:Hide()
    return a
end

function Celebration.Alert(ev)
    alert = alert or buildAlert()
    local T = ns.Theme
    alert.icon:SetTexture(T.category[ev.kind == "claim" and "explore" or ev.kind].icon)
    alert.title:SetText(TITLE[ev.kind](ev.zone))
    alert:Show()
    if alert.anim then
        alert.anim:Stop(); alert.anim:Play()
    elseif C_Timer then
        C_Timer.After(Celebration.ALERT_SECONDS, function() alert:Hide() end)
    end
end

function Celebration.GetAlert() return alert end -- for tests

ns.Events.On("AZF_CELEBRATE", function(ev)
    if ns.UI.IsShown() then Celebration.PlayNext() else Celebration.Alert(ev) end
end)
ns.Events.On("AZF_WINDOW_SHOWN", function() Celebration.PlayNext() end)
ns.Events.On("AZF_WINDOW_HIDDEN", function()
    if ns.UI.modal == modal then ns.UI.modal = nil end
    if overlay then overlay:Hide() end
end)
