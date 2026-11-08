-- Overview tab. The dashboard itself arrives in Phase 7; until progress is tracked (Phase 5)
-- this page says so instead of showing numbers the game hasn't confirmed.
local _, ns = ...

local function build(parent)
    local T, S = ns.Theme, ns.Theme.space
    local page = CreateFrame("Frame", nil, parent)
    local title = T.Text(page, "xl", "gold")
    title:SetPoint("TOPLEFT", S.s6, -S.s4)
    title:SetText("Overview")
    local note = T.Text(page, "md", "dim")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S.s2)
    note:SetText("Your exploration progress will appear here once tracking is in place.")
    return page
end

ns.UI.RegisterTab({
    id = "overview",
    label = "Overview",
    icon = "Interface\\Icons\\INV_Misc_Book_11",
    order = 1,
    info = "Your character's progress at a glance.",
    build = build,
})
