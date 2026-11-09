-- The Atlas chart (mockups/DESIGN.md "Zones: Atlas", Phase 10): the painted sea chart
-- (Media\Chrome\atlas-backdrop) in the painted frame, Kalimdor's zones over its left landmass,
-- the Eastern Kingdoms' over its right, zones with no place in the open sea between ("Uncharted
-- waters"). Places come from ns.Atlas (the client's own rectangles); states and % from
-- ns.Zones. Two sizes:
--   full  (the Zones tab's Atlas view): focusable art cards with name, %, a progress bar, a gold
--         edge when claimed, a pulsing pin where you are; zones outside the filters dimmed.
--   mini  (the Overview's panel): small art blocks with a progress bar, the same edges.
-- Frames are pooled and reused on every draw.
local _, ns = ...

local Chart = {}
ns.AtlasChart = Chart

-- Regions as fractions of the chart, matching the painting (the mockup's .aregion).
local REGION = {
    [1414] = { left = 0.01, width = 0.38 },   -- Kalimdor: the left landmass
    [1415] = { left = 0.63, width = 0.36 },   -- Eastern Kingdoms: the right landmass
    sea = { left = 0.40, width = 0.22 },
}
local NAMES = { [1414] = "Kalimdor", [1415] = "Eastern Kingdoms" }
local LABEL_H = 24
Chart.SOURCE_ASPECT = 4 / 3 -- the backdrop was painted 4:3 (stored stretched to 1024x1024)

local function cropArt(tex, mapID, w, h)
    if not (w and h and w > 0 and h > 0) then return end
    if w / h >= 2 then
        local top, bottom = ns.Theme.BannerCrop(mapID, w, h)
        tex:SetTexCoord(0, 1, top, bottom)
    else
        local f = (w / h) / 2
        tex:SetTexCoord((1 - f) / 2, (1 + f) / 2, 0, 1)
    end
end

local function setArt(tex, z, w, h)
    local art = ns.Theme.ZoneArt(z.mapID)
    if art then tex:SetTexture(art) else tex:SetColorTexture(0.1, 0.07, 0.04, 1) end
    cropArt(tex, z.mapID, w, h)
    local grey = z.state == "untouched" or z.state == "untracked"
    if tex.SetDesaturated then tex:SetDesaturated(grey) end
    if grey then tex:SetVertexColor(0.55, 0.55, 0.55) else tex:SetVertexColor(1, 1, 1) end
end

---------------------------------------------------------------------------------------------
-- Tiles
---------------------------------------------------------------------------------------------

local function newTile(parent, mini)
    local T, W = ns.Theme, ns.Widgets
    local t = mini and CreateFrame("Frame", nil, parent) or W.FocusRow(parent, 40)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints(); t.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
    t.art = t:CreateTexture(nil, "BORDER")
    t.art:SetPoint("TOPLEFT", 1, -1); t.art:SetPoint("BOTTOMRIGHT", -1, 1)
    t.well = t:CreateTexture(nil, "ARTWORK", nil, 2)
    t.well:SetPoint("BOTTOMLEFT", 1, 1); t.well:SetPoint("BOTTOMRIGHT", -1, 1)
    t.well:SetHeight(mini and 2 or 3); t.well:SetColorTexture(0, 0, 0, 0.65)
    t.fill = t:CreateTexture(nil, "ARTWORK", nil, 3)
    t.fill:SetPoint("TOPLEFT", t.well, "TOPLEFT"); t.fill:SetPoint("BOTTOMLEFT", t.well, "BOTTOMLEFT")
    local r, g, b = T.RGB("todo")
    t.fill:SetColorTexture(r, g, b, 1)
    t.edge = W.Edge(t, "OVERLAY")
    if not mini then
        t.shade = t:CreateTexture(nil, "ARTWORK", nil, 1)
        t.shade:SetAllPoints(t.art)
        t.shade:SetColorTexture(1, 1, 1, 1)
        local ok = type(CreateColor) == "function" and pcall(t.shade.SetGradient, t.shade, "VERTICAL",
            CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0))
        if not ok then t.shade:SetColorTexture(0, 0, 0, 0.35) end
        t.name = T.Text(t, "xs", "white")
        t.name:SetPoint("BOTTOMLEFT", 5, 5); t.name:SetPoint("RIGHT", -4, 0)
        t.name:SetJustifyH("LEFT"); t.name:SetWordWrap(true)
        t.pct = T.Text(t, "xs", "todo")
        t.pct:SetPoint("TOPRIGHT", -4, -3)
        t.pin = t:CreateTexture(nil, "OVERLAY", nil, 2)
        t.pin:SetSize(10, 10); t.pin:SetPoint("CENTER", 0, 4)
        t.pin:SetColorTexture(1, 1, 1, 1)
        local m = t:CreateMaskTexture()
        if m then
            m:SetAllPoints(t.pin)
            m:SetTexture(T.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            pcall(t.pin.AddMaskTexture, t.pin, m)
        end
        if t.pin.CreateAnimationGroup then
            local ag = t.pin:CreateAnimationGroup()
            ag:SetLooping("BOUNCE")
            local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.8)
            t.pin.anim = ag
        end
    end
    return t
end

local function fillTile(t, z, w, h, here, dim, mini)
    local T = ns.Theme
    t:SetSize(w, h)
    setArt(t.art, z, w - 2, h - 2)
    local claimed = z.state == "complete"
    if claimed then
        t.edge:SetColor("complete"); t.edge:SetThickness(mini and 1 or 2)
    elseif here then
        t.edge:SetColor("white"); t.edge:SetThickness(2)
    else
        t.edge:SetColor("black", 0.85); t.edge:SetThickness(1)
    end
    local pct = z.percent and z.percent / 100 or 0
    local progress = z.state == "progress"
    t.well:SetShown(progress); t.fill:SetShown(progress and pct > 0)
    if progress and pct > 0 then t.fill:SetWidth(math.max(1, (w - 2) * math.min(1, pct))) end
    t:SetAlpha(dim and 0.3 or 1)
    if not mini then
        t.name:SetText(z.name)
        t.name:SetTextColor(T.RGB(claimed and "gold" or (z.state == "untouched" and "dim" or "white")))
        t.pct:SetText(claimed and "Claimed" or (z.combined and ns.Progression.PercentText(z.combined) or ""))
        t.pct:SetTextColor(T.RGB(claimed and "complete" or "todo"))
        t.pin:SetShown(here)
        if t.pin.anim then if here then t.pin.anim:Play() else t.pin.anim:Stop() end end
    end
end

---------------------------------------------------------------------------------------------
-- The chart
---------------------------------------------------------------------------------------------

function Chart.New(parent, mini)
    local T = ns.Theme
    local f = CreateFrame(mini and "Button" or "Frame", nil, parent)
    f.mini = mini
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local file = T.Chrome("atlas-backdrop")
    if file then f.bg:SetTexture(file) else f.bg:SetColorTexture(0.05, 0.12, 0.13, 1) end
    f.hasArt = file ~= nil
    f.frame = T.CardFrame(f, mini and 18 or 26, 0)
    f.tiles, f.labels = {}, {}
    if not mini then
        for _, id in ipairs(ns.Atlas.CONTINENTS) do
            local l = T.Text(f, "md", "gold")
            l:SetText(NAMES[id])
            f.labels[id] = l
        end
        f.isleCap = T.Text(f, "xs", "dim")
        f.isleCap:SetText("Uncharted waters")
    else
        f.open = T.Text(f, "sm", "gold", "OVERLAY")
        f.open:SetText("Open Atlas ›")
        -- In the open sea at the bottom: the Eastern Kingdoms' tiles covered it bottom right
        -- (WoWScrnShot_110826_194100).
        f.open:SetPoint("BOTTOM", 0, 18)
    end
    return f
end

-- Draws the chart w x h with the given zone entries (tracked zones).
--   opts.shown    set of mapIDs inside the current filters (nil = every zone shown)
--   opts.current  the player's mapID
--   opts.item(tile, z) -> a focus item for the tile (full chart only)
-- Returns the full chart's focus rows (tiles grouped into bands top to bottom, left to right)
-- and byMap ([mapID] = tile).
function Chart.Draw(f, entries, w, h, opts)
    opts = opts or {}
    local mini = f.mini
    f:SetSize(w, h)
    -- The painting is 4:3; a wider box shows its middle band (cropped top and bottom).
    if f.hasArt then
        local a = w / math.max(1, h)
        if a > Chart.SOURCE_ASPECT then
            local v = Chart.SOURCE_ASPECT / a
            f.bg:SetTexCoord(0, 1, (1 - v) / 2, (1 + v) / 2)
        else
            f.bg:SetTexCoord(0, 1, 0, 1)
        end
    end
    for _, t in ipairs(f.tiles) do t:Hide() end
    local places = ns.Atlas.Places(entries)
    local by = {}
    for _, z in ipairs(entries) do by[z.mapID] = z end
    local used, placed = 0, {}
    local function take()
        used = used + 1
        local t = f.tiles[used]
        if not t then t = newTile(f, mini); f.tiles[used] = t end
        t:ClearAllPoints()
        t:Show()
        return t
    end
    local padY = (mini and 0.09 or 0.04) * h
    local labelH = mini and 0 or LABEL_H
    local tileW, tileH
    for _, cont in ipairs(ns.Atlas.CONTINENTS) do
        local R, layout = REGION[cont], places.layouts[cont]
        local rx, rw = R.left * w, R.width * w
        local rh = h - 2 * padY - labelH
        if f.labels[cont] then
            f.labels[cont]:ClearAllPoints()
            f.labels[cont]:SetPoint("TOP", f, "TOPLEFT", rx + rw / 2, -padY)
            f.labels[cont]:SetShown(layout ~= nil)
        end
        if layout then
            local mh = math.min(rh, rw / layout.ratio)
            local mw = mh * layout.ratio
            local mx, my = rx + (rw - mw) / 2, padY + labelH
            for _, tl in ipairs(layout.tiles) do
                local z = by[tl.mapID]
                if z then
                    local t = take()
                    local tw, th = math.floor(tl.width * mw + 0.5), math.floor(tl.height * mh + 0.5)
                    tileW, tileH = tileW or tw, tileH or th
                    t:SetPoint("TOPLEFT", f, "TOPLEFT", math.floor(mx + tl.left * mw + 0.5), -math.floor(my + tl.top * mh + 0.5))
                    fillTile(t, z, tw, th, z.mapID == opts.current, opts.shown and not opts.shown[z.mapID], mini)
                    placed[#placed + 1] = { t = t, z = z, x = mx + tl.left * mw, y = my + tl.top * mh, h = th }
                end
            end
        end
    end
    -- Zones with no place: cards in the open sea, one under the other, around the middle.
    local sea = REGION.sea
    tileW, tileH = tileW or math.floor(w * 0.08), tileH or math.floor(h * 0.06)
    local n = #places.unplaced
    local sy = (h - n * (tileH + 30)) / 2
    for i, z in ipairs(places.unplaced) do
        local t = take()
        local x = sea.left * w + (sea.width * w - tileW) / 2
        local y = sy + (i - 1) * (tileH + 30)
        t:SetPoint("TOPLEFT", f, "TOPLEFT", math.floor(x + 0.5), -math.floor(y + 0.5))
        fillTile(t, z, tileW, tileH, z.mapID == opts.current, opts.shown and not opts.shown[z.mapID], mini)
        placed[#placed + 1] = { t = t, z = z, x = x, y = y, h = tileH }
        if i == 1 and f.isleCap then
            f.isleCap:ClearAllPoints()
            f.isleCap:SetPoint("TOP", t, "BOTTOM", 0, -6)
        end
    end
    if f.isleCap then f.isleCap:SetShown(n > 0) end

    -- Focus rows: tiles in bands by their top edge (a new band when a tile starts lower than
    -- the band's first by more than half a tile), left to right in each band.
    local rows, byMap = {}, {}
    for _, p in ipairs(placed) do byMap[p.z.mapID] = p.t end
    if not mini and opts.item then
        table.sort(placed, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
        local band
        for _, p in ipairs(placed) do
            if not band or p.y > band.y + (tileH or 40) * 0.5 then
                band = { y = p.y, list = {} }
                rows[#rows + 1] = band
            end
            band.list[#band.list + 1] = p
        end
        for i, b in ipairs(rows) do
            table.sort(b.list, function(a, c) return a.x < c.x end)
            local items = {}
            for _, p in ipairs(b.list) do items[#items + 1] = opts.item(p.t, p.z) end
            rows[i] = { items = items }
        end
    end
    return rows, byMap
end
