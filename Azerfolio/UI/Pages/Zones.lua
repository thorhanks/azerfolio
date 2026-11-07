-- Zones tab. Uses the compact header (mockups/DESIGN.md). The catalogue and Zone Detail
-- arrive in the next steps; until then this page says so.
local _, ns = ...

local function build(parent)
    local T, S = ns.Theme, ns.Theme.space
    local page = CreateFrame("Frame", nil, parent)
    local title = T.Text(page, "title", "xl", "ink")
    title:SetShadowOffset(0, 0)
    title:SetPoint("TOPLEFT", S.s6, -S.s6)
    title:SetText("Zones")
    local note = T.Text(page, "body", "md", "inkSoft")
    note:SetShadowOffset(0, 0)
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S.s2)
    note:SetText("The zone catalogue will appear here.")
    return page
end

ns.UI.RegisterTab({
    id = "zones",
    label = "Zones",
    order = 2,
    compactHeader = true,
    info = "Every zone, its art and its exploration.",
    build = build,
})
