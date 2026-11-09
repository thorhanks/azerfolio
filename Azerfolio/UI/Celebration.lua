-- The celebration overlay and the on-screen alert (mockups/DESIGN.md "Celebrations").
-- ns.Celebrations decides what to celebrate; this file only shows it.
--   Window open: a dark overlay over the window with rising motes,
--   a card in the painted frame (round 2, owner 2026-11-08): the category's seal in the gold
--   laurel, or the zone's war standard hoisted with the faction's claim seal; the title on the
--   crimson ribbon. A or B (or the button) continues; the next waiting celebration follows.
--   Window closed: an alert in the painted frame at the top centre of the screen for a few
--   seconds (the seal, "Azerfolio", the title); the waiting
--   celebrations play when the window opens.
-- Without the art, simple shapes stand in (the category icon in a gold ring).
local _, ns = ...

local Celebration = {}
ns.Celebration = Celebration

Celebration.ALERT_SECONDS = 5
local CARD_W = 470
local MEDAL = 176        -- the laurel and its seal
local RIBBON_W = 460     -- the title ribbon (4:1)

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

-- A painted celebration piece (Media\Chrome\cel-*.blp, listed in Data/Art.lua), or nil.
local function piece(name) return ns.Theme.Chrome(name) end

-- The category's seal (flight paths: the faction's gryphon or wyvern).
local function sealFor(kind)
    if kind == "flights" then return piece("cel-seal-flights-" .. faction():lower()) end
    return piece("cel-seal-" .. kind)
end

local function circleMask(tex, owner)
    local mk = owner:CreateMaskTexture()
    if mk then
        mk:SetAllPoints(tex)
        mk:SetTexture(ns.Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(tex.AddMaskTexture, tex, mk)
    end
end

-- Fades a region in after `delay` seconds (frame and texture Alpha animations work here).
local function fadeIn(region, delay, duration)
    if not region.CreateAnimationGroup then return end
    local ag = region:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(duration or 0.4)
    if a.SetStartDelay then a:SetStartDelay(delay or 0) end
    if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
    region.fade = ag
end

local function build(window)
    local T, S = ns.Theme, ns.Theme.space
    local o = CreateFrame("Frame", nil, window)
    o:SetAllPoints(window)
    o:SetFrameLevel((window:GetFrameLevel() or 1) + 100)
    if o.EnableMouse then o:EnableMouse(true) end -- clicks don't reach the page underneath
    o.dark = o:CreateTexture(nil, "BACKGROUND")
    o.dark:SetAllPoints(); o.dark:SetColorTexture(0.02, 0.012, 0, 0.94)
    -- (A masked warm disc here showed as a hard yellow circle in game, WoWScrnShot_110826_201141;
    -- the overlay stays plain dark.)

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
    o.card = card
    -- No burst behind the card: in game it looked odd (owner, 2026-11-08); the dark overlay and
    -- the rising motes are enough.
    card.bg = T.Solid(card, "cardBg", "BACKGROUND", 0.97)
    card.bg:SetAllPoints()
    card.frame = T.CardFrame(card, 22, 5)

    -- Category: the seal inside the gold laurel (the category's icon in a ring without art).
    card.medal = CreateFrame("Frame", nil, card)
    card.medal:SetSize(MEDAL, MEDAL)
    card.medal:SetPoint("TOP", 0, -18)
    card.seal = card.medal:CreateTexture(nil, "ARTWORK", nil, 1)
    card.seal:SetSize(MEDAL * 0.74, MEDAL * 0.74); card.seal:SetPoint("CENTER")
    card.laurel = card.medal:CreateTexture(nil, "ARTWORK", nil, 3)
    card.laurel:SetAllPoints()
    card.ring = card.medal:CreateTexture(nil, "ARTWORK", nil, 0) -- fallback ring
    card.ring:SetSize(MEDAL * 0.66, MEDAL * 0.66); card.ring:SetPoint("CENTER")
    card.ring:SetColorTexture(0.72, 0.54, 0.18, 1)
    circleMask(card.ring, card.medal)
    fadeIn(card.medal, 0.15, 0.5)

    -- Claim: the zone's standard (without its own claimed rays) and the faction's claim seal.
    card.banner = ns.ZoneBanner.New(card)
    card.banner:SetPoint("TOP", card, "TOP", 0, -14)
    card.banner.noRays = true
    card.claimSeal = card:CreateTexture(nil, "OVERLAY", nil, 2)
    card.claimSeal:SetSize(100, 100)
    fadeIn(card.claimSeal, 1.2, 0.35)

    -- The title on the crimson ribbon (kept 4:1: its centre crest mustn't stretch).
    card.ribbon = card:CreateTexture(nil, "ARTWORK", nil, 1)
    card.ribbon:SetSize(RIBBON_W, RIBBON_W / 4)
    card.title = T.Text(card, "lg", "gold")
    card.title:SetWordWrap(false)
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

-- The title on the ribbon: the largest size that fits between its folded ends.
local function setTitle(card, text)
    local T = ns.Theme
    local room = RIBBON_W - 150
    for _, size in ipairs({ "lg", "md", "sm" }) do
        T.SetFont(card.title, size)
        card.title:SetText(text)
        if (card.title:GetStringWidth() or 0) <= room then break end
    end
    -- Pale gold on the crimson ribbon; the plain gold without it.
    if piece("cel-ribbon") then card.title:SetTextColor(1, 0.91, 0.66) else card.title:SetTextColor(T.RGB("gold")) end
end

local function place(o, top)
    local card, S = o.card, ns.Theme.space
    local ribbonH = RIBBON_W / 4
    card.ribbon:ClearAllPoints(); card.ribbon:SetPoint("TOP", card, "TOP", 0, -top)
    -- Centred on the red band (rows 39-79 of the 128-tall art, about the image's middle). At +6
    -- the capitals touched the band's top trim in game (WoWScrnShot_110826_201212: about 3 units
    -- high), so +2.
    card.title:ClearAllPoints(); card.title:SetPoint("CENTER", card.ribbon, "CENTER", 0, 2)
    card.line:ClearAllPoints(); card.line:SetPoint("TOP", card.ribbon, "BOTTOM", 0, 2)
    local below = card.line
    if card.cats:IsShown() then
        card.cats:ClearAllPoints(); card.cats:SetPoint("TOP", card.line, "BOTTOM", 0, -S.s2)
        below = card.cats
    end
    card.button:ClearAllPoints(); card.button:SetPoint("TOP", below, "BOTTOM", 0, -S.s4)
    local h = top + ribbonH - 2 + (card.line:GetStringHeight() or 16)
        + (card.cats:IsShown() and (S.s2 + 16) or 0) + S.s4 + 26 + 24
    card:SetHeight(math.max(260, math.floor(h + 0.5)))
end

local function fill(o, ev)
    local T, card, z = ns.Theme, o.card, ev.zone
    local claim = ev.kind == "claim"
    card.medal:SetShown(not claim)
    card.banner:SetShown(claim)
    card.cats:SetShown(claim)
    local ribbonFile = piece("cel-ribbon")
    card.ribbon:SetShown(ribbonFile ~= nil)
    if ribbonFile then card.ribbon:SetTexture(ribbonFile) end
    if claim then
        local scale = 0.66
        card.banner:SetScale(scale)
        card.banner:Set(z, faction(), true, true)
        local sealFile = piece("cel-claim-" .. faction():lower())
        card.claimSeal:SetShown(sealFile ~= nil)
        if sealFile then
            card.claimSeal:SetTexture(sealFile)
            card.claimSeal:ClearAllPoints()
            card.claimSeal:SetPoint("BOTTOMLEFT", card.banner, "BOTTOM", 18 / scale, 60 / scale)
            if card.claimSeal.fade then card.claimSeal:SetAlpha(0); card.claimSeal.fade:Stop(); card.claimSeal.fade:Play() end
        end
        setTitle(card, TITLE.claim(z))
        card.line:SetText("For the " .. faction() .. ": every area, quest and flight path you can do here is done.")
        local parts = {}
        for _, c in ipairs(z.cats or {}) do
            if not c.pending then
                parts[#parts + 1] = "|T" .. tostring(T.category[c.key].icon) .. ":14:14|t |cffffd35a"
                    .. c.denominator .. "|r " .. (c.denominator == 1 and UNIT_ONE[c.key] or T.category[c.key].unit)
            end
        end
        card.cats:SetText(table.concat(parts, "     "))
        place(o, math.floor(14 + (card.banner:GetHeight() or 440) * scale + 2))
    else
        card.claimSeal:Hide()
        local seal, laurel = sealFor(ev.kind), piece("cel-laurel")
        card.seal:SetTexture(seal or T.category[ev.kind].icon)
        card.laurel:SetShown(laurel ~= nil)
        if laurel then card.laurel:SetTexture(laurel) end
        card.ring:SetShown(laurel == nil)
        card.seal:SetSize(MEDAL * (seal and 0.74 or 0.4), MEDAL * (seal and 0.74 or 0.4))
        if card.medal.fade then card.medal:SetAlpha(0); card.medal.fade:Stop(); card.medal.fade:Play() end
        setTitle(card, TITLE[ev.kind](z))
        card.line:SetText(catLine(z, ev.kind))
        place(o, 18 + MEDAL - 6)
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
    -- In the painted card frame, everything inside it (owner: the header plate's thin band left
    -- the text outside the border, WoWScrnShot_110826_201720).
    local a = CreateFrame("Frame", nil, UIParent)
    a:SetSize(400, 66)
    a:SetPoint("TOP", UIParent, "TOP", 0, -150)
    a:SetFrameStrata("HIGH")
    a.bg = T.Solid(a, "cardBg", "BACKGROUND", 0.95)
    a.bg:SetAllPoints()
    a.frame = T.CardFrame(a, 18, 4)
    a.icon = a:CreateTexture(nil, "ARTWORK")
    a.icon:SetSize(46, 46)
    a.icon:SetPoint("LEFT", 14, 0)
    a.small = T.Text(a, "xs", "dim")
    a.small:SetPoint("TOPLEFT", a.icon, "TOPRIGHT", S.s3, -3)
    a.small:SetText("AZERFOLIO")
    a.title = T.Text(a, "md", "gold")
    a.title:SetPoint("BOTTOMLEFT", a.icon, "BOTTOMRIGHT", S.s3, 4)
    a.title:SetPoint("RIGHT", a, "RIGHT", -16, 0)
    a.title:SetJustifyH("LEFT"); a.title:SetWordWrap(false)
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
    -- The category's seal, or the claim seal (round 2); the category icon without the art.
    local seal = ev.kind == "claim" and piece("cel-claim-" .. faction():lower()) or (ev.kind ~= "claim" and sealFor(ev.kind))
    alert.icon:SetTexture(seal or T.category[ev.kind == "claim" and "explore" or ev.kind].icon)
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
