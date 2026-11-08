-- The zone's war banner (spec §7.1, mockups/DESIGN.md "The war banner"): the player's faction
-- banner hoisted up its pole as the zone fills, one badge per category, claimed at the top.
-- Uses the painted pieces (art/prompts.md § War banner pieces, Media\Banner) as a war standard:
-- the pole up the middle, the banner's crossbar hoisted up it. Without them, a stand-in drawn
-- from plain textures. Draws what it's given; never computes progress.
local _, ns = ...

local Banner = {}
ns.ZoneBanner = Banner

Banner.SIZE = { 170, 270 }   -- the whole piece
Banner.CLOTH = { 118, 150 }
Banner.RISE = 96              -- pole travel from 0% to 100%
Banner.TOP = 28               -- cloth top at 100%, from the piece's top
Banner.HOIST_TIME = 1.4       -- seconds, rising from the ground when shown
Banner.MEDIA = "Interface\\AddOns\\Azerfolio\\Media\\Banner\\"
-- With the painted pieces: a war standard, the pole up the middle behind the banner and the
-- banner's own crossbar hoisted up it. The cloth canvas is 1:2 with the 2:3 painting centred
-- (a quarter of the canvas height padding top and bottom, half each side: 64/512).
-- Design round 2 (approved 2026-11-08, mockups/DESIGN.md): a 220x440 box, the pole (1:4) as
-- tall as the box, a smaller cloth so the hoist has real travel, no badges on the cloth.
Banner.ART = { size = { 220, 440 }, pole = { 110, 440 }, cloth = { 150, 300 } }
Banner.ART.pad = Banner.ART.cloth[2] * 64 / 512          -- canvas above the crossbar
Banner.ART.visible = Banner.ART.cloth[2] * 384 / 512     -- the painting's height
Banner.ART.top = 58                                      -- crossbar at 100%: just under the finial
Banner.ART.rise = Banner.ART.size[2] - 8 - Banner.ART.visible - Banner.ART.top
-- Battle streamers: one per finished category, tied at the crossbar's ends (left, right,
-- outer left). Canvas 1:8 with the 1:6 painting centred.
Banner.ART.streamer = { 26, 208 }
Banner.ART.streamerX = { -6, Banner.ART.cloth[1] - 26 + 6, -22 }

Banner.LOOK = {
    Alliance = { cloth = { 0.14, 0.32, 0.72 }, dark = { 0.06, 0.15, 0.34 }, trim = { 0.89, 0.73, 0.31 },
        pole = { 0.42, 0.27, 0.14 }, finial = { 0.89, 0.73, 0.31 }, bar = { 0.89, 0.73, 0.31 }, edge = 3,
        emblem = "Interface\\TargetingFrame\\UI-PVP-Alliance" },
    Horde = { cloth = { 0.60, 0.14, 0.09 }, dark = { 0.23, 0.04, 0.02 }, trim = { 0.71, 0.60, 0.42 },
        pole = { 0.35, 0.25, 0.16 }, finial = { 0.49, 0.47, 0.44 }, bar = { 0.35, 0.25, 0.16 }, edge = 1,
        emblem = "Interface\\TargetingFrame\\UI-PVP-Horde" },
}

local function circle(parent, layer, size, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetSize(size, size)
    local m = parent:CreateMaskTexture()
    if m then
        m:SetAllPoints(t)
        m:SetTexture(ns.Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(t.AddMaskTexture, t, m)
    end
    return t
end

function Banner.New(parent)
    local T, W = ns.Theme, ns.Widgets
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(Banner.SIZE[1], Banner.SIZE[2])

    f.shadow = f:CreateTexture(nil, "BACKGROUND")
    f.shadow:SetColorTexture(0, 0, 0, 0.5)
    f.shadow:SetSize(70, 8)
    f.shadow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 0)
    f.pole = f:CreateTexture(nil, "BORDER")
    f.pole:SetSize(7, Banner.SIZE[2] - 14)
    f.pole:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 4)
    f.finial = circle(f, "ARTWORK", 13)
    f.finial:SetPoint("BOTTOM", f.pole, "TOP", 0, -4)
    f.rings = {}
    for i, m in ipairs({ 0.25, 0.5, 0.75 }) do
        local r = f:CreateTexture(nil, "ARTWORK")
        r:SetSize(12, 5)
        r:SetPoint("CENTER", f.pole, "TOP", 0, -(Banner.TOP - 4 + (1 - m) * Banner.RISE))
        f.rings[i] = { tex = r, at = m }
    end

    -- The cloth and everything on it move together (the hoist).
    local c = CreateFrame("Frame", nil, f)
    c:SetSize(Banner.CLOTH[1], Banner.CLOTH[2])
    f.cloth = c
    c.glow = c:CreateTexture(nil, "BACKGROUND")
    c.glow:SetPoint("TOPLEFT", -10, 10); c.glow:SetPoint("BOTTOMRIGHT", 10, -10)
    c.bg = c:CreateTexture(nil, "BORDER")
    c.bg:SetAllPoints()
    c.shade = c:CreateTexture(nil, "BORDER", nil, 1)
    c.shade:SetAllPoints()
    c.shade:SetColorTexture(1, 1, 1, 1)
    local ok = type(CreateColor) == "function" and pcall(c.shade.SetGradient, c.shade, "VERTICAL",
        CreateColor(0, 0, 0, 0.45), CreateColor(1, 1, 1, 0.08))
    if not ok then c.shade:SetColorTexture(0, 0, 0, 0.15) end
    c.edge = W.Edge(c, "ARTWORK")
    c.bar = c:CreateTexture(nil, "OVERLAY")
    c.bar:SetHeight(8)
    c.bar:SetPoint("BOTTOMLEFT", c, "TOPLEFT", -4, -4); c.bar:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", 6, -4)
    c.art = c:CreateTexture(nil, "BORDER", nil, 2) -- the painted cloth, when it exists
    c.art:SetAllPoints()
    c.art:Hide()
    c.emblem = c:CreateTexture(nil, "ARTWORK", nil, 2)
    c.emblem:SetSize(58, 58)
    c.emblem:SetPoint("TOP", c, "TOP", 0, -16)
    c.badges = {}
    for i = 1, #T.categoryOrder do
        local b = CreateFrame("Frame", nil, c)
        b:SetSize(26, 26)
        b.ring = circle(b, "ARTWORK", 26); b.ring:SetPoint("CENTER")
        b.inner = circle(b, "ARTWORK", 20, 1); b.inner:SetPoint("CENTER")
        b.icon = b:CreateTexture(nil, "OVERLAY")
        b.icon:SetSize(14, 14); b.icon:SetPoint("CENTER")
        c.badges[i] = b
    end
    c.streamers = {}
    for i = 1, 3 do
        local s = c:CreateTexture(nil, "ARTWORK", nil, 3)
        s:SetSize(Banner.ART.streamer[1], Banner.ART.streamer[2])
        s:Hide()
        c.streamers[i] = s
    end
    -- Hoist: rise from the ground to the banner's height.
    if c.CreateAnimationGroup then
        local ag = c:CreateAnimationGroup()
        local jump = ag:CreateAnimation("Translation")
        jump:SetDuration(0); jump:SetOrder(1)
        local rise = ag:CreateAnimation("Translation")
        rise:SetDuration(Banner.HOIST_TIME); rise:SetOrder(2)
        if rise.SetSmoothing then rise:SetSmoothing("OUT") end
        f.hoist, f.jump, f.rise = ag, jump, rise
    end
    f.claimText = T.Text(f, "sm", "gold")
    f.claimText:SetPoint("TOP", f, "BOTTOM", 0, -4)

    -- Painted pieces (tools/process-art.ps1 -> Media\Banner, listed in Data/Art.lua) replace
    -- the stand-in shapes when present. Sizes follow the pieces' canvases (1:2, 1:4, 1:1).
    local function piece(name)
        local art = ns.Art and ns.Art.banner
        return art and art[name] and (Banner.MEDIA .. name .. ".blp") or nil
    end
    local function applyArt(faction)
        local key = faction == "Horde" and "horde" or "alliance"
        local cloth, pole, badge = piece("banner-" .. key), piece("pole-" .. key), piece("badge-" .. key)
        -- The standard layout needs both the cloth and the pole; otherwise the stand-in.
        if not (cloth and pole) then cloth, pole = nil, nil end
        local A, c = Banner.ART, f.cloth
        f:SetSize(cloth and A.size[1] or Banner.SIZE[1], cloth and A.size[2] or Banner.SIZE[2])
        c.art:SetShown(cloth ~= nil)
        if cloth then c.art:SetTexture(cloth) end
        c:SetSize(cloth and A.cloth[1] or Banner.CLOTH[1], cloth and A.cloth[2] or Banner.CLOTH[2])
        for _, t in ipairs({ c.bg, c.shade, c.bar, c.emblem }) do t:SetShown(cloth == nil) end
        for i = 1, 4 do c.edge[i]:SetShown(cloth == nil) end
        f.pole:ClearAllPoints()
        f.shadow:ClearAllPoints()
        if pole then
            f.pole:SetTexture(pole); f.pole:SetVertexColor(1, 1, 1)
            f.pole:SetSize(A.pole[1], A.pole[2])
            f.pole:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
            f.shadow:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
            f.shadow:Hide() -- a flat bar under painted art looked wrong in game
        else
            f.pole:SetSize(7, Banner.SIZE[2] - 14)
            f.pole:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 4)
            f.shadow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 0)
            f.shadow:Show()
        end
        f.finial:SetShown(pole == nil)
        for _, r in ipairs(f.rings) do r.tex:SetShown(pole == nil) end
        local streamer = cloth and piece("streamer-" .. key) or nil
        for _, s in ipairs(c.streamers) do if streamer then s:SetTexture(streamer) end; s:Hide() end
        return cloth ~= nil, pole ~= nil, streamer
    end

    -- entry: a ns.Zones entry (state, percent, cats); faction: "Alliance" | "Horde".
    -- animate: rise from the ground now.
    function f:Set(entry, faction, animate)
        local look = Banner.LOOK[faction] or Banner.LOOK.Alliance
        local hasCloth, hasPole, streamer = applyArt(faction)
        local pct = math.max(0, math.min(100, entry.percent or 0)) / 100
        local claimed = entry.state == "complete"
        if not hasPole then self.pole:SetColorTexture(look.pole[1], look.pole[2], look.pole[3], 1) end
        self.finial:SetColorTexture(look.finial[1], look.finial[2], look.finial[3], 1)
        for _, r in ipairs(self.rings) do
            local lit = pct >= r.at
            if lit then r.tex:SetColorTexture(look.trim[1], look.trim[2], look.trim[3], 1)
            else r.tex:SetColorTexture(0.23, 0.18, 0.13, 1) end
        end
        local c, A = self.cloth, Banner.ART
        local rise = hasCloth and A.rise or Banner.RISE
        c:ClearAllPoints()
        if hasCloth then
            c:SetPoint("TOP", self, "TOP", 0, -(A.top + (1 - pct) * A.rise - A.pad))
        else
            c:SetPoint("TOPLEFT", self, "TOPLEFT", 37, -(Banner.TOP + (1 - pct) * Banner.RISE))
        end
        c.bg:SetColorTexture(look.cloth[1], look.cloth[2], look.cloth[3], 1)
        c.bar:SetColorTexture(look.bar[1], look.bar[2], look.bar[3], 1)
        local er, eg, eb = unpack(claimed and { 1, 0.8, 0.2 } or (look.edge > 1 and look.trim or look.dark))
        for i = 1, 4 do c.edge[i]:SetColorTexture(er, eg, eb, 1) end
        c.edge:SetThickness(claimed and 4 or look.edge)
        c.glow:SetColorTexture(1, 0.8, 0.2, (claimed and not hasCloth) and 0.35 or 0)
        c.emblem:SetTexture(look.emblem)
        c.emblem:SetTexCoord(0, 0.62, 0, 0.62) -- the crest sits top-left in these files [unverified]
        local cats = entry.cats or {}
        for _, b in ipairs(c.badges) do b:Hide() end
        if hasCloth then
            -- Painted: a streamer at the crossbar's ends for each finished category.
            local k = 0
            for _, cat in ipairs(cats) do
                if not cat.pending and cat.state == "complete" and streamer and k < #c.streamers then
                    k = k + 1
                    local s = c.streamers[k]
                    s:ClearAllPoints()
                    s:SetPoint("TOPLEFT", c, "TOPLEFT", A.streamerX[k],
                        -(A.pad - (A.streamer[2] - A.streamer[1] * 6) / 2 - 4))
                    s:Show()
                end
            end
        else
            -- Stand-in: one badge per category, gold when done, orange while in progress.
            local n, i = 0, 0
            for _, cat in ipairs(cats) do if not cat.pending then n = n + 1 end end
            for _, cat in ipairs(cats) do
                if not cat.pending then
                    i = i + 1
                    local b = c.badges[i]
                    b:ClearAllPoints()
                    b:SetPoint("CENTER", c, "BOTTOMLEFT", Banner.CLOTH[1] * i / (n + 1), 30)
                    local ring = cat.state == "complete" and T.color.complete or (cat.state == "progress" and T.color.todo or { 0.36, 0.32, 0.27 })
                    b.ring:SetColorTexture(ring[1], ring[2], ring[3], 1)
                    local inner = cat.state == "complete" and T.color.complete or look.dark
                    b.inner:SetColorTexture(inner[1], inner[2], inner[3], 1)
                    b.icon:SetTexture(T.category[cat.key] and T.category[cat.key].icon)
                    b:Show()
                end
            end
        end
        -- Painted: no text under the banner (round 2); the header says "Claimed".
        self.claimText:SetText((claimed and not hasCloth) and ("Claimed for the " .. (faction or "Alliance")) or "")
        if self.hoist then
            self.hoist:Stop()
            if animate and pct > 0 then
                local drop = pct * rise
                self.jump:SetOffset(0, -drop)
                self.rise:SetOffset(0, drop)
                self.hoist:Play()
            end
        end
    end
    return f
end
