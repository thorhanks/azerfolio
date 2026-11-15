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
local STRIKE = 1.0       -- seconds before the coin strikes gold (mockup: 1 s)
local SEAL_FLASH = 0.55  -- a category seal's flash, as it settles (mockup)
local CLAIM_FLASH = 1.4  -- the claim seal's flash, right after it stamps (fades in at 1.2 s)
local PROF_BANNER_W = 400 -- Mastered: the profession's banner (2:1) above the medal
local PROF_OVERLAP = 96  -- the medal over the banner's lower edge (mockup)
local TOAST_CREST = 42   -- the reputation toast's crest, its reaction emblem, and its place
local TOAST_EMBLEM = 34  -- under the window's top (below the header, mockup 104 px)
local TOAST_TOP = 104

local TITLE = {
    explore = function(z) return z.name .. " Explored" end,
    quests = function(z) return z.name .. ": Every Quest Done" end,
    flights = function(z) return z.name .. ": Every Flight Path" end,
    claim = function(z) return z.name .. " Claimed" end,
}
local UNIT_ONE = { explore = "area", quests = "quest", flights = "flight path" }

-- Phase 15 step 9: the class road and professions (ev.stop / ev.journey, ev.prof).
local MORE_TITLE = {
    stop = function(ev) return ev.stop.name end,
    road = function(ev) return (ev.journey.title or "Your Class Road") .. " Walked" end,
    rank = function(ev) return ev.prof.title or ev.prof.name end,
    mastered = function(ev) return ev.prof.name .. " Mastered" end,
}
local ALERT_TITLE = {
    stop = function(ev) return ev.stop.name .. " walked" end,
    road = function(ev) return (ev.journey.title or "Your class road") .. " walked" end,
}
local function lowerThe(s) return (tostring(s or ""):gsub("^The ", "the ")) end

-- The line under the ribbon for the new kinds.
local function moreLine(ev)
    local j = ev.journey
    if ev.kind == "stop" then
        local s, n, i = ev.stop, 0, nil
        for _, x in ipairs(j.stops) do
            if x.kind ~= "side" then n = n + 1; if x == s then i = n end end
        end
        local q = "|cffffffff" .. (s.count or 0) .. "|r " .. ((s.count or 0) == 1 and "quest" or "quests") .. " done."
        local text = i and string.format("Stop %d of %d on %s is walked:\n%s", i, n, lowerThe(j.title), q)
            or string.format("A side path of %s is walked:\n%s", lowerThe(j.title), q)
        if s.reward then text = text .. "\nReward: " .. s.reward .. "." end
        return text
    elseif ev.kind == "road" then
        return string.format("Every stop on your class road is done:\n|cffffffff%d|r stops, |cffffffff%d|r quests.",
            j.road.count + j.side.count, j.quests.count)
    elseif ev.kind == "rank" then
        local m = ev.prof
        local text = m.cap and (m.name .. " can now reach |cffffffff" .. m.cap .. "|r.") or (m.title or m.name) .. "."
        if m.next then text = text .. "\nNext: " .. m.next.name .. " from skill " .. m.next.at .. "."
        elseif not m.mastered then text = text .. "\nThe last rank: " .. (ns.ProfessionData and ns.ProfessionData.maxSkill or 300) .. " masters it." end
        return text
    elseif ev.kind == "mastered" then
        local m = ev.prof
        return string.format("Skill |cffffffff%s|r of %s%s", tostring(m.skill), tostring(m.cap or m.skill), m.title and (": " .. m.title .. ".") or ".")
    end
end

-- The coin for the new kinds: gold file, bronze file (nil: no strike), whether the bronze one is
-- the gold art greyed by code (the class coins have no bronze painting).
local function coinsFor(ev)
    local T = ns.Theme
    if ev.kind == "stop" or ev.kind == "road" then
        local gold = ev.classFile and T.Chrome("coin-" .. ev.classFile:lower())
        return gold, gold, true
    end
    local key = ev.prof and ev.prof.key
    local gold = key and T.Chrome("coin-prof-" .. key)
    local dull = key and T.Chrome("coin-prof-" .. key .. "-dull")
    if ev.kind == "rank" then return dull or gold, nil, false end
    return gold, dull, false
end

-- The game's own sound for a moment (Theme.sound), under pcall; nothing when PlaySound is missing.
local function playSound(key)
    local id = ns.Theme.sound and ns.Theme.sound[key]
    if id and type(PlaySound) == "function" then
        local ok, err = pcall(PlaySound, id, "SFX")
        if not ok then ns.Debug.Error("PlaySound", err) end
    end
end
local SOUND_OF = { explore = "cat", quests = "cat", flights = "cat" }
Celebration.SoundOf = function(ev)
    if ev.kind == "rep" then return ev.reaction == 8 and "exalted" or "rep" end
    return SOUND_OF[ev.kind] or ev.kind
end

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
    -- Phase 15 step 9: a coin that strikes gold (owner's pick): the bronze coin under the gold
    -- one, which fades in with a flash after STRIKE seconds while the bronze one fades out.
    card.dull = card.medal:CreateTexture(nil, "ARTWORK", nil, 1)
    card.dull:SetSize(MEDAL * 0.74, MEDAL * 0.74); card.dull:SetPoint("CENTER")
    card.flash = card.medal:CreateTexture(nil, "ARTWORK", nil, 4)
    card.flash:SetSize(MEDAL * 0.9, MEDAL * 0.9); card.flash:SetPoint("CENTER")
    if card.flash.SetBlendMode then card.flash:SetBlendMode("ADD") end
    if card.seal.CreateAnimationGroup then
        local function group(region, steps)
            local ag = region:CreateAnimationGroup()
            for i, s in ipairs(steps) do
                local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(s[1]); a:SetToAlpha(s[2]); a:SetDuration(s[3]); a:SetOrder(i)
                if s[4] and a.SetStartDelay then a:SetStartDelay(s[4]) end
            end
            if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
            return ag
        end
        card.strike = {
            group(card.seal, { { 0, 0, STRIKE }, { 0, 1, 0.3 } }),
            group(card.dull, { { 1, 1, STRIKE }, { 1, 0, 0.25 } }),
            group(card.flash, { { 0, 0, STRIKE - 0.05 }, { 0, 1, 0.15 }, { 1, 0, 0.6 } }),
        }
        -- The zone seals match (owner, 2026-11-14): the same flash as a category's seal settles.
        card.sealFlash = group(card.flash, { { 0, 0, SEAL_FLASH }, { 0, 1, 0.15 }, { 1, 0, 0.6 } })
        card.flashGroup = group
    end
    -- Mastered: the profession's painted banner above the medal.
    card.profBanner = card:CreateTexture(nil, "ARTWORK", nil, 0)
    card.profBanner:SetSize(PROF_BANNER_W, PROF_BANNER_W / 2)
    card.profBanner:SetPoint("TOP", card, "TOP", 0, -16)

    -- Claim: the zone's standard (without its own claimed rays) and the faction's claim seal.
    card.banner = ns.ZoneBanner.New(card)
    card.banner:SetPoint("TOP", card, "TOP", 0, -14)
    card.banner.noRays = true
    card.claimSeal = card:CreateTexture(nil, "OVERLAY", nil, 2)
    card.claimSeal:SetSize(100, 100)
    fadeIn(card.claimSeal, 1.2, 0.35)
    card.claimFlash = card:CreateTexture(nil, "OVERLAY", nil, 3)
    card.claimFlash:SetSize(124, 124)
    card.claimFlash:SetPoint("CENTER", card.claimSeal, "CENTER")
    if card.claimFlash.SetBlendMode then card.claimFlash:SetBlendMode("ADD") end
    card.claimFlash:SetAlpha(0)
    if card.flashGroup then
        card.claimFlashAnim = card.flashGroup(card.claimFlash, { { 0, 0, CLAIM_FLASH }, { 0, 1, 0.15 }, { 1, 0, 0.6 } })
    end

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

-- The class road and professions: the coin in the laurel (striking gold for a stop, the road
-- and Mastered), Mastered with the profession's banner above.
local function fillMore(o, ev)
    local T, card = ns.Theme, o.card
    card.claimSeal:Hide()
    local gold, dull, greyed = coinsFor(ev)
    local laurel = piece("cel-laurel")
    card.laurel:SetShown(laurel ~= nil)
    if laurel then card.laurel:SetTexture(laurel) end
    card.ring:SetShown(laurel == nil)
    card.seal:SetTexture(gold or T.category.quests.icon)
    card.seal:SetSize(MEDAL * (gold and 0.74 or 0.4), MEDAL * (gold and 0.74 or 0.4))
    local strike = dull ~= nil and card.strike ~= nil
    card.dull:SetShown(strike)
    card.flash:SetShown(strike)
    if strike then
        card.dull:SetTexture(dull)
        card.dull:SetDesaturated(greyed)
        if greyed then card.dull:SetVertexColor(0.86, 0.66, 0.44) else card.dull:SetVertexColor(1, 1, 1) end
        for _, ag in ipairs(card.strike) do ag:Stop(); ag:Play() end
    else
        card.seal:SetAlpha(1)
    end
    local key = ev.kind == "mastered" and ev.prof and ev.prof.key
    local bannerArt = key and ns.Art and ns.Art.professions and ns.Art.professions[key]
    card.profBanner:SetShown(bannerArt and true or false)
    card.medal:ClearAllPoints()
    local top = 18
    if bannerArt then
        card.profBanner:SetTexture(T.mediaDir .. "Professions\\" .. key .. ".blp")
        top = 16 + PROF_BANNER_W / 2 - PROF_OVERLAP
    end
    card.medal:SetPoint("TOP", 0, -top)
    if card.medal.fade then card.medal:SetAlpha(0); card.medal.fade:Stop(); card.medal.fade:Play() end
    setTitle(card, MORE_TITLE[ev.kind](ev))
    card.line:SetText(moreLine(ev))
    place(o, top + MEDAL - 6)
end

local function fill(o, ev)
    local T, card, z = ns.Theme, o.card, ev.zone
    local claim = ev.kind == "claim"
    local more = MORE_TITLE[ev.kind] ~= nil
    card.medal:SetShown(not claim)
    card.banner:SetShown(claim)
    card.cats:SetShown(claim)
    card.dull:Hide(); card.flash:Hide(); card.profBanner:Hide(); card.claimFlash:Hide()
    for _, ag in ipairs(card.strike or {}) do ag:Stop() end
    if card.sealFlash then card.sealFlash:Stop() end
    if card.claimFlashAnim then card.claimFlashAnim:Stop() end
    -- The flash (glow-soft, added), shared by the coins and the zone seals.
    local glow = piece("glow-soft")
    for _, f in ipairs({ card.flash, card.claimFlash }) do
        if glow then f:SetTexture(glow) else f:SetColorTexture(1, 0.93, 0.7, 0.8) end
    end
    card.seal:SetAlpha(1)
    card.medal:ClearAllPoints(); card.medal:SetPoint("TOP", 0, -18)
    local ribbonFile = piece("cel-ribbon")
    card.ribbon:SetShown(ribbonFile ~= nil)
    if ribbonFile then card.ribbon:SetTexture(ribbonFile) end
    if more then
        fillMore(o, ev)
    elseif claim then
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
            if card.claimFlashAnim then card.claimFlash:Show(); card.claimFlashAnim:Play() end
        end
        setTitle(card, TITLE.claim(z))
        card.line:SetText("For the " .. faction() .. ": every area, quest and flight path you can do here is done.")
        local parts = {}
        for _, c in ipairs(z.cats or {}) do
            if not c.pending then
                parts[#parts + 1] = T.CategoryInline(c.key, 14) .. " |cffffd35a"
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
        if card.sealFlash then card.flash:SetAlpha(0); card.flash:Show(); card.sealFlash:Play() end
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
    if MORE_TITLE[ev.kind] then
        -- The class road and professions: the coin (gold, or bronze for a rank).
        local gold = coinsFor(ev)
        alert.icon:SetTexture(gold or T.category.quests.icon)
        alert.title:SetText((ALERT_TITLE[ev.kind] or MORE_TITLE[ev.kind])(ev))
    else
        -- The category's seal, or the claim seal (round 2); the category icon without the art.
        local seal = ev.kind == "claim" and piece("cel-claim-" .. faction():lower()) or (ev.kind ~= "claim" and sealFor(ev.kind))
        alert.icon:SetTexture(seal or T.category[ev.kind == "claim" and "explore" or ev.kind].icon)
        alert.title:SetText(TITLE[ev.kind](ev.zone))
    end
    alert:Show()
    if alert.anim then
        alert.anim:Stop(); alert.anim:Play()
    elseif C_Timer then
        C_Timer.After(Celebration.ALERT_SECONDS, function() alert:Hide() end)
    end
end

function Celebration.GetAlert() return alert end -- for tests

---------------------------------------------------------------------------------------------
-- Reputation toast (Phase 15 step 9): the faction's crest, "Honored with Stormwind" and the
-- reaction's emblem, for a few seconds; Exalted in gold. Not modal and never queued for the
-- window: under the window's header while it's open, at the alert's place while it's closed.
-- Several at once follow one another.
---------------------------------------------------------------------------------------------

local toast
local toasts = {} -- waiting while one shows

local function buildToast()
    local T, S, W = ns.Theme, ns.Theme.space, ns.Widgets
    local t = CreateFrame("Frame", nil, UIParent)
    t:SetSize(360, 64)
    t:SetFrameStrata("DIALOG")
    t.bg = T.Solid(t, "cardBg", "BACKGROUND", 0.96)
    t.bg:SetAllPoints()
    t.frame = T.CardFrame(t, 18, 4)
    t.crest = W.Crest(t)
    t.crest:SetPoint("LEFT", t, "LEFT", 14, 0)
    t.emblem = t:CreateTexture(nil, "ARTWORK")
    t.emblem:SetSize(TOAST_EMBLEM, TOAST_EMBLEM)
    t.emblem:SetPoint("RIGHT", t, "RIGHT", -14, 0)
    t.small = T.Text(t, "xs", "dim")
    t.small:SetPoint("TOPLEFT", t, "TOPLEFT", 14 + TOAST_CREST + S.s3, -14)
    t.small:SetText("AZERFOLIO · REPUTATION")
    t.title = T.Text(t, "md", "gold")
    t.title:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 14 + TOAST_CREST + S.s3, 14)
    t.title:SetJustifyH("LEFT"); t.title:SetWordWrap(false)
    if t.CreateAnimationGroup then
        local ag = t:CreateAnimationGroup()
        local fin = ag:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.4); fin:SetOrder(1)
        local hold = ag:CreateAnimation("Alpha"); hold:SetFromAlpha(1); hold:SetToAlpha(1)
        hold:SetDuration(Celebration.ALERT_SECONDS - 1.2); hold:SetOrder(2)
        local fout = ag:CreateAnimation("Alpha"); fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.8); fout:SetOrder(3)
        ag:SetScript("OnFinished", function() t:Hide(); Celebration.NextToast() end)
        t.anim = ag
    end
    t:Hide()
    return t
end

local function showToast(ev)
    toast = toast or buildToast()
    local T, S = ns.Theme, ns.Theme.space
    local f = ev.faction or { factionID = ev.factionID, reaction = ev.reaction }
    toast.crest:Set({ factionID = f.factionID, name = f.name, met = true }, TOAST_CREST)
    local emblem = T.reaction.emblem and T.reaction.emblem[ev.reaction]
    local file = emblem and T.Chrome(emblem)
    toast.emblem:SetShown(file ~= nil)
    if file then toast.emblem:SetTexture(file) end
    local name = (tostring(f.name or "?"):gsub("^The ", "the "))
    toast.title:SetText(T.ReactionLabel(ev.reaction) .. " with " .. name)
    -- Exalted is gold (DESIGN.md "Gold beyond completion"); every other rank the plain gold text.
    if ev.reaction == 8 then toast.title:SetTextColor(1, 0.824, 0.302) else toast.title:SetTextColor(T.RGB("gold")) end
    local w = 14 + TOAST_CREST + S.s3 + math.max(toast.title:GetStringWidth() or 0, toast.small:GetStringWidth() or 0)
        + S.s3 + (file and TOAST_EMBLEM or 0) + 18
    toast:SetWidth(math.max(320, math.floor(w + 0.5)))
    toast:ClearAllPoints()
    if ns.UI.IsShown() then
        toast:SetPoint("TOP", ns.UI.GetFrame(), "TOP", 0, -TOAST_TOP)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
    toast.ev = ev
    toast:Show()
    if toast.anim then
        toast.anim:Stop(); toast.anim:Play()
    elseif C_Timer then
        C_Timer.After(Celebration.ALERT_SECONDS, function() toast:Hide(); Celebration.NextToast() end)
    end
    playSound(Celebration.SoundOf(ev))
end

function Celebration.Toast(ev)
    if toast and toast:IsShown() then toasts[#toasts + 1] = ev; return end
    showToast(ev)
end
function Celebration.NextToast()
    local ev = table.remove(toasts, 1)
    if ev then showToast(ev) end
end
function Celebration.GetToast() return toast end -- for tests

ns.Events.On("AZF_TOAST", function(ev) Celebration.Toast(ev) end)
ns.Events.On("AZF_CELEBRATE", function(ev)
    -- The game's sound once, as it happens (not again when a waiting celebration plays).
    playSound(Celebration.SoundOf(ev))
    if ns.UI.IsShown() then Celebration.PlayNext() else Celebration.Alert(ev) end
end)
ns.Events.On("AZF_WINDOW_SHOWN", function() Celebration.PlayNext() end)
ns.Events.On("AZF_WINDOW_HIDDEN", function()
    if ns.UI.modal == modal then ns.UI.modal = nil end
    if overlay then overlay:Hide() end
end)
