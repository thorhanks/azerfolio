-- /azf shots: opens the window and screenshots each tab and state, so the agent can review the
-- real UI from <game>\Screenshots (plan §4.3). Development aid; changes nothing it doesn't restore.
local _, ns = ...

local UI = ns.UI

local SETTLE = 0.5 -- seconds after a change before the screenshot
local GAP = 1.0    -- seconds after a screenshot before the next change

local function zonesPage() return UI.GetFrame().pages.zones end

-- Every listed zone as { mapID, name, continent }.
local function allZones()
    local out = {}
    for _, s in ipairs(ns.Maps.Sections()) do
        for _, z in ipairs(s.zones) do out[#out + 1] = { mapID = z.mapID, name = z.name, continent = s.title } end
    end
    return out
end

-- Opens a zone's detail in the normal-size window (restored when the shots end).
local function openDetail(zone)
    UI.ApplyGeometry(); UI.Relayout(); UI.SelectTab("zones")
    local page = zonesPage()
    if zone and page and page.Open then page:Open(zone); UI.shotsOpenedDetail = true end
end

-- The wide split view's size: the design's 1640, within the allowed range.
local function wideSize()
    local r = ns.Config.RANGES
    local w = math.max(ns.Theme.layout.wideMinWidth, math.min(1640, r["window.width"][2]))
    return w, ns.db.window.height
end

-- /azf shots banners: the Zone Detail of every zone with a banner offset.
local function bannerSteps()
    local list = {}
    for _, z in ipairs(allZones()) do
        if ns.Theme.bannerFocus[z.mapID] then
            list[#list + 1] = { label = "banner " .. z.name, fn = function() openDetail(z) end }
        end
    end
    return list
end

-- The zone to show reputation on: the player's zone if it has factions, else the zone with
-- the most (rivals first: their tags wrap), or nil when no zone has any.
local function repZone(zones, here)
    local best, bestScore
    for _, z in ipairs(zones) do
        local ok, list = pcall(ns.Reputation.ForZone, z)
        if ok and list then
            local score = #list * 10
            for _, f in ipairs(list) do if #(f.rivals or {}) > 0 then score = score + 5 end end
            if z.mapID == here then score = score + 1000 end
            if not bestScore or score > bestScore then best, bestScore = z, score end
        end
    end
    return best
end

-- Zone Detail's Reputation ledger (focus on its first faction) and that faction's page; with
-- `wide`, the same in the wide split view.
local function repSteps(zones, here, wide)
    local z = repZone(zones, here)
    if not z then return {} end
    local function focusFirst()
        local list = ns.Reputation.ForZone(z)
        if list then ns.Focus.FocusKey(ns.ZoneDetail.RepKey(list[1].factionID)); UI.RefreshHints() end
    end
    local function openPage()
        local page, list = zonesPage(), ns.Reputation.ForZone(z)
        if page and list then page:OpenRep(list[1].factionID) end
    end
    if wide then
        return {
            { label = "zones wide, reputation", fn = function()
                local page = zonesPage()
                if page then page:Open(z); UI.shotsOpenedDetail = true end
                focusFirst()
            end },
            { label = "zones wide, faction page", fn = openPage },
        }
    end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    return {
        { label = "zone detail, reputation", fn = function() openDetail(z); focusFirst() end },
        { label = "zone detail, faction page", fn = openPage },
        -- The smallest window: the dashboard's right column scrolls to the last faction.
        { label = "zone detail, reputation at minimum size", fn = function()
            openDetail(z); UI.FitSize(minW, minH)
            -- Focus once the layout has settled (the column's scroll range is only known after
            -- the resize's size events), as when a player resizes and then moves.
            C_Timer.After(0.2, function()
                local list = ns.Reputation.ForZone(z)
                if list then ns.Focus.FocusKey(ns.ZoneDetail.RepKey(list[#list].factionID)); UI.RefreshHints() end
            end)
        end },
    }
end

local function repPage() return UI.GetFrame().pages.reputation end

-- The Reputation tab (Phase 12): the list, the Closest sort, the next section, a faction page
-- (a rival faction with sources if there is one: seesaw and reach), the minimum size; with
-- `wide`, the split view with focus in the list, then in the page. The sort is restored at
-- the end.
local function repTabSteps(wide)
    local function pick()
        local best
        for _, f in ipairs(ns.Reputation.AllFactions() or {}) do
            local score = #(f.sources or {}) + (#(f.rivals or {}) > 0 and 100 or 0) + ((f.reach and f.reach.count or 0) > 0 and 50 or 0)
            if not best or score > best.score then best = { id = f.factionID, score = score } end
        end
        return best and best.id
    end
    local function list()
        UI.SelectTab("reputation")
        local p = repPage()
        if p and p.mode == "detail" then p:Back() end
        if UI.shotsRepSort == nil then UI.shotsRepSort = ns.db.reputation.sort end
        if ns.db.reputation.sort ~= "group" then ns.db.reputation.sort = "group"; p:Redraw() end
        return p
    end
    local function openPick()
        local p, id = repPage(), pick()
        if p and id then p:OpenFaction(id) end
    end
    if wide then
        return {
            { label = "reputation wide", fn = function()
                local p = list()
                local id = pick()
                if p and id then p:ClickFaction(id) end
            end },
            { label = "reputation wide, in the page", fn = openPick },
        }
    end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    return {
        { label = "reputation", fn = function() UI.ApplyGeometry(); UI.Relayout(); list() end },
        { label = "reputation, next section", fn = function() ns.Focus.Jump(1); UI.RefreshHints() end },
        { label = "reputation, closest sort", fn = function() local p = repPage(); if p then p:CycleSort() end end },
        { label = "reputation, faction page", fn = function() list(); openPick() end },
        { label = "reputation at minimum size", fn = function() list(); UI.FitSize(minW, minH) end },
        { label = "reputation page at minimum size", fn = openPick },
        { label = "normal size", fn = function() UI.ApplyGeometry(); UI.Relayout() end, skip = true },
    }
end

-- /azf shots reputation: the Reputation tab, then the zone ledger and the faction page,
-- normal size then wide.
local function reputationSteps(zones, here)
    local list = repTabSteps(false)
    for _, s in ipairs(repSteps(zones, here, false)) do list[#list + 1] = s end
    list[#list + 1] = { label = "reputation tab wide", fn = function() UI.FitSize(wideSize()) end, skip = true }
    for _, s in ipairs(repTabSteps(true)) do list[#list + 1] = s end
    if #repSteps(zones, here, false) == 0 then return list end
    list[#list + 1] = { label = "zones wide", fn = function()
        local page = zonesPage()
        if page and page.mode == "detail" then page:Back() end
        if page and page.mode == "detail" then page:Back() end
        UI.shotsOpenedDetail = nil
        UI.SelectTab("zones"); UI.FitSize(wideSize())
    end, skip = true }
    for _, s in ipairs(repSteps(zones, here, true)) do list[#list + 1] = s end
    return list
end

-- /azf shots class: the Class tab (Phase 13) on your current stop, that stop's steps, the
-- next stop (RT), the road's end, the minimum size, then wide.
local function classPage() return UI.GetFrame().pages.class end
local function classSteps()
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function road()
        UI.SelectTab("class")
        local p = classPage()
        if p and p.mode == "steps" then p:Back() end
        return p
    end
    local function current() local p = road(); if p and p.journey then p:FocusStop(p:CurrentStopKey()) end end
    return {
        { label = "class", fn = function() UI.ApplyGeometry(); UI.Relayout(); current() end },
        { label = "class, steps", fn = function() local p = classPage(); if p then p:EnterSteps() end end },
        { label = "class, next stop", fn = function() current(); ns.Focus.Jump(1); UI.RefreshHints() end },
        { label = "class, road's end", fn = function() local p = road(); if p and p.journey then p:FocusStop("end") end end },
        { label = "class, road's end list", fn = function() local p = classPage(); if p then p:EnterSteps() end end },
        -- Round 4: the first level with an ability you could train now (else the first mark).
        { label = "class, abilities", fn = function()
            local p = road()
            local tr = p and p.trainer
            local pick
            for _, mk in ipairs(tr and tr.abilities and tr.abilities.marks or {}) do
                if not pick or (mk.state == "available" and pick.state ~= "available") then pick = mk end
            end
            -- Round 5: stones can merge; focus the stone (its first level) that holds this level.
            local key
            for first, g in pairs(p and p.abilityGroups or {}) do
                for _, lv in ipairs(g.levels) do if pick and lv == pick.level then key = "a:" .. first end end
            end
            if key then p:FocusStop(key) end
        end },
        { label = "class at minimum size", fn = function() current(); UI.FitSize(minW, minH) end },
        { label = "class wide", fn = function() UI.FitSize(wideSize()); current() end },
        { label = "class wide, steps", fn = function() local p = classPage(); if p then p:EnterSteps() end end },
    }
end

-- /azf shots professions: the Professions tab (Phase 14) on each of your professions (Journey),
-- the road and Next up of the first, then the minimum size and wide.
local function profPage() return UI.GetFrame().pages.professions end
local function professionSteps()
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function open(line)
        UI.SelectTab("professions")
        local p = profPage()
        if not p then return nil end
        -- Back to the rail (a recipe's detail needs two B: detail -> list -> rail).
        local guard = 0
        while p.mode == "page" and guard < 3 do p:Back(); guard = guard + 1 end
        if p.view ~= "journey" then p:SetView("journey") end
        if line then ns.Focus.FocusKey("p:" .. line); UI.RefreshHints() end
        return p
    end
    local list = ns.Professions.Get().professions
    local first = list[1] and list[1].skillLine
    if not first then
        -- No professions (Thragor, WoWScrnShot_111426_130431): the empty page at each size only.
        return {
            { label = "professions, none yet", fn = function() UI.ApplyGeometry(); UI.Relayout(); open() end },
            { label = "professions, none yet at minimum size", fn = function() open(); UI.FitSize(minW, minH) end },
            { label = "professions, none yet wide", fn = function() UI.FitSize(wideSize()); open() end },
        }
    end
    local out = {
        { label = "professions", fn = function() UI.ApplyGeometry(); UI.Relayout(); open(first) end },
        { label = "professions, the road", fn = function() local p = open(first); if p then p:EnterPage() end end },
        { label = "professions, next up", fn = function() ns.Focus.Jump(1); UI.RefreshHints() end },
    }
    -- Recipes and the focused recipe's detail on the first profession that has a read window,
    -- then Gather on the first gathering profession.
    local withRecipes, gatherer
    for _, m in ipairs(list) do
        if not withRecipes and m.recipes then withRecipes = m end
        if not gatherer and m.gather then gatherer = m end
    end
    if withRecipes then
        out[#out + 1] = { label = "professions, recipes", fn = function()
            local p = open(withRecipes.skillLine); if p then p:SetView("recipes"); p:EnterPage() end end }
        out[#out + 1] = { label = "professions, recipe detail", fn = function() local p = profPage(); if p then p:EnterDetail() end end }
    end
    if gatherer then
        out[#out + 1] = { label = "professions, gather", fn = function()
            local p = open(gatherer.skillLine); if p then p:SetView("gather"); p:EnterPage() end end }
    end
    for i = 2, #list do
        local m = list[i]
        out[#out + 1] = { label = "professions, " .. m.name, fn = function() open(m.skillLine) end }
    end
    out[#out + 1] = { label = "professions at minimum size", fn = function() open(first); UI.FitSize(minW, minH) end }
    out[#out + 1] = { label = "professions wide", fn = function() UI.FitSize(wideSize()); open(first) end }
    return out
end

-- /azf shots dungeons (Phase 16 tasks 4-6): the Dungeons tab's Cards, List and Road, the next
-- section, instances' pages, at the minimum size and wide (Cards and Road full width, List split). The view and
-- filter are restored at the end.
local function dunPage() return UI.GetFrame().pages.dungeons end
local function dungeonSteps()
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function open(view)
        UI.SelectTab("dungeons")
        local p = dunPage()
        if not p then return nil end
        if p.mode == "page" then p:Back() end
        if UI.shotsDunView == nil then UI.shotsDunView, UI.shotsDunFilter = ns.db.dungeons.view, ns.db.dungeons.filter end
        if ns.db.dungeons.filter ~= "all" then ns.db.dungeons.filter = "all" end
        p:SetView(view)
        ns.Focus.Jump(1); UI.RefreshHints() -- the first instance
        return p
    end
    local function openPage()
        local p = dunPage()
        local item = ns.Focus.Current()
        if not (p and item and item.entry) then return end
        if UI.shotsDunPv == nil then UI.shotsDunPv = p.pv or false end
        p.pv = "overview"
        p:OpenInstance(item.entry.inst.key)
    end
    -- An instance's page (Cards, full size) in a view (task 5).
    local function inst(key, view)
        return function()
            local p = open("cards")
            if not p then return false end
            if UI.shotsDunPv == nil then UI.shotsDunPv = p.pv or false end
            p.pv = view
            p:OpenInstance(key)
            UI.RefreshHints()
        end
    end
    local function view(v) return function() local p = dunPage(); if p then p:SetPageView(v); UI.RefreshHints() end end end
    -- Down the boss list, n steps (the loot follows).
    local function down(n) return function() for _ = 1, n do ns.Focus.Move("down") end; UI.RefreshHints() end end
    -- Along the road, n steps right (the strip scrolls, the preview follows).
    local function right(n) return function() for _ = 1, n do ns.Focus.Move("right") end; UI.RefreshHints() end end
    return {
        { label = "dungeons, cards", fn = function() UI.ApplyGeometry(); UI.Relayout(); open("cards") end },
        { label = "dungeons, next section", fn = function() ns.Focus.Jump(1); UI.RefreshHints() end },
        { label = "dungeons, instance page", fn = openPage },
        { label = "dungeons, the Deadmines, overview", fn = inst("deadmines", "overview") },
        { label = "dungeons, the Deadmines, bosses and loot", fn = view("bosses") },
        { label = "dungeons, the Deadmines, a loot tile (the game's tooltip)", fn = function()
            local p = dunPage()
            if p and p.selBoss then p:EnterLoot(p.selBoss) end
            UI.RefreshHints()
        end },
        { label = "dungeons, the Deadmines, a later boss", fn = function()
            local p = dunPage()
            if p then ns.Focus.FocusKey("b:" .. (p.selBoss or 1)) end
            down(3)()
        end },
        { label = "dungeons, the Deadmines, quests", fn = view("quests") },
        { label = "dungeons, Blackrock Depths, overview", fn = inst("blackrockDepths", "overview") },
        { label = "dungeons, Blackrock Depths, bosses and loot", fn = view("bosses") },
        { label = "dungeons, Blackrock Depths, bosses scrolled", fn = down(20) },
        { label = "dungeons, Blackrock Depths, quests", fn = view("quests") },
        { label = "dungeons, Scarlet Monastery wings", fn = inst("smLibrary", "overview") },
        { label = "dungeons, Molten Core, bosses and loot", fn = inst("moltenCore", "bosses") },
        { label = "dungeons, list", fn = function() open("list") end },
        { label = "dungeons, list scrolled", fn = function() ns.Focus.Jump(1); ns.Focus.Jump(1); UI.RefreshHints() end },
        -- The Road (task 6): it opens on the your-level instance nearest You (LT lands there).
        { label = "dungeons, road", fn = function() open("road") end },
        { label = "dungeons, road walked right", fn = right(7) },
        { label = "dungeons, road, the raids", fn = function() ns.Focus.FocusKey("d:naxxramas"); UI.RefreshHints() end },
        { label = "dungeons at minimum size", fn = function() open("cards"); UI.FitSize(minW, minH) end },
        { label = "dungeons, road at minimum size", fn = function() open("road") end },
        { label = "dungeons, road at minimum size, walked", fn = right(12) },
        { label = "dungeons, list at minimum size", fn = function() open("list") end },
        { label = "dungeons, page at minimum size", fn = inst("deadmines", "overview") },
        { label = "dungeons, Blackrock Depths at minimum size", fn = inst("blackrockDepths", "overview") },
        { label = "dungeons, Blackrock Depths bosses at minimum size", fn = view("bosses") },
        { label = "dungeons wide, cards", fn = function() UI.FitSize(wideSize()); open("cards") end },
        { label = "dungeons wide, instance page", fn = openPage },
        { label = "dungeons wide, Blackrock Depths", fn = inst("blackrockDepths", "overview") },
        { label = "dungeons wide, Blackrock Depths, bosses and loot", fn = view("bosses") },
        { label = "dungeons wide, Dire Maul wings, quests", fn = inst("dmWest", "quests") },
        { label = "dungeons wide, road", fn = function() open("road") end },
        { label = "dungeons wide, road walked right", fn = right(16) },
        { label = "dungeons wide, list", fn = function() open("list") end },
        { label = "dungeons wide, list next section", fn = function() ns.Focus.Jump(1); UI.RefreshHints() end },
        { label = "dungeons wide, list split, into the page", fn = function()
            local item = ns.Focus.Current()
            if item and item.onActivate then item.onActivate(item) end
            UI.RefreshHints()
        end },
    }
end

-- /azf shots links (Phase 16 task 7): the Zones tab's big art cards (normal and minimum size),
-- Zone Detail's "Dungeon here" tiles (a zone with one dungeon, the zone with the most, both
-- capitals; normal, minimum and wide), A on a tile (the instance's page, "B Zone") and B back,
-- then a Reputation faction's dungeon source, A to the instance and B back. The Zones view is
-- restored at the end.
local function linkSteps()
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local Rules = ns.DungeonRules
    local byMap, one, dense, denseN = {}, nil, nil, 0
    for _, z in ipairs(allZones()) do
        byMap[z.mapID] = z
        local n = #Rules.InZone(ns.DungeonData.instances, z.mapID)
        if n > denseN then dense, denseN = z, n end
    end
    one = byMap[1436] or dense -- Westfall: The Deadmines
    local horde = ns.character and ns.character.faction == "Horde"
    local ownCap, otherCap = byMap[horde and 1454 or 1453], byMap[horde and 1453 or 1454]
    -- Focus a zone's first tile once the dashboard has settled (its column scrolls to it).
    local function focusTile(z)
        local first = z and Rules.InZone(ns.DungeonData.instances, z.mapID)[1]
        if not first then return end
        C_Timer.After(0.2, function() ns.Focus.FocusKey("dun:" .. first.key); UI.RefreshHints() end)
    end
    local function zone(z, w, h)
        return function()
            if not z then return false end
            UI.SelectTab("zones")
            local page = zonesPage()
            if w then
                if page and page.mode == "detail" then page:Back() end
                UI.SelectTab("zones"); UI.FitSize(w, h)
                if page then page:Open(z); UI.shotsOpenedDetail = true end
            else
                openDetail(z)
            end
            focusTile(z)
            return true
        end
    end
    local function cards(fn)
        return function()
            UI.SelectTab("zones") -- builds the page the first time
            local page = zonesPage()
            if page.mode == "detail" then page:Back() end
            if UI.shotsView == nil then UI.shotsView = ns.db.zones.displayMode end
            if ns.db.zones.displayMode ~= "cards" then ns.db.zones.displayMode = "cards"; page.catalogue:Refresh() end
            fn()
            UI.RefreshHints()
        end
    end
    local function activate() local item = ns.Focus.Current(); if item and item.onActivate then item.onActivate(item) end; UI.RefreshHints() end
    local function back() local p = dunPage(); if p then p:Back() end; UI.RefreshHints() end
    -- A faction this character can raise in a dungeon or raid (the Reputation tab's sources).
    local function dunSource()
        local ok, all = pcall(ns.Reputation.AllFactions)
        for _, f in ipairs(ok and all or {}) do
            for _, s in ipairs(f.sources or {}) do
                if (s.kind == "dungeon" or s.kind == "raid") and s.forYou ~= false and Rules.ForQuestArea(s.key) then
                    return f.factionID, "s:" .. s.kind .. ":" .. tostring(s.key)
                end
            end
        end
    end
    local list = {
        { label = "zones, cards", fn = cards(function() UI.ApplyGeometry(); UI.Relayout(); ns.Focus.Jump(1) end) },
        { label = "zones, cards, next section", fn = cards(function() ns.Focus.Jump(1) end) },
        { label = "zones, cards, a section on", fn = cards(function() ns.Focus.Jump(1); ns.Focus.Jump(1) end) },
        { label = "zones, cards at minimum size", fn = cards(function() UI.FitSize(minW, minH); ns.Focus.Jump(-3) end) },
        { label = "zone detail, dungeon here", fn = zone(one) },
        { label = "dungeon opened from the zone", fn = activate },
        { label = "back to the zone (B)", fn = back },
        { label = "zone detail, " .. denseN .. " dungeons here", fn = zone(dense) },
        { label = "zone detail, capital", fn = zone(ownCap) },
        { label = "zone detail, the other capital", fn = zone(otherCap) },
        { label = "zone detail, dungeon here at minimum size", fn = zone(one, minW, minH) },
        { label = "zone detail, " .. denseN .. " dungeons here at minimum size", fn = zone(dense, minW, minH) },
        { label = "zones wide, dungeon here", fn = zone(one, wideSize()) },
        { label = "zones wide, " .. denseN .. " dungeons here", fn = zone(dense, wideSize()) },
        { label = "zones wide, dungeon opened", fn = activate },
        { label = "zones wide, back (B)", fn = back },
    }
    local fid, key = dunSource()
    if fid then
        list[#list + 1] = { label = "reputation, a dungeon source", fn = function()
            UI.ApplyGeometry(); UI.Relayout(); UI.SelectTab("reputation")
            local rp = repPage()
            if not rp then return false end
            rp:OpenFaction(fid)
            -- Focus once the page has its layout, so the row scrolls into view (it didn't at once).
            C_Timer.After(0.2, function() ns.Focus.FocusKey(key); UI.RefreshHints() end)
        end }
        list[#list + 1] = { label = "dungeon opened from reputation", fn = activate }
        list[#list + 1] = { label = "back to reputation (B)", fn = back }
    else
        ns.Debug.Print("shots: no faction with a dungeon or raid source for this character")
    end
    return list
end

-- /azf shots explore: the Exploration page and its zone map (Phase 15 step 6) for the player's
-- zone at the normal, minimum and wide sizes, then a fully explored zone and one with no area
-- found yet, where the character has them.
local function exploreSteps()
    local zones = allZones()
    local here = C_Map and C_Map.GetBestMapForUnit
        and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local pick, full, none
    for _, z in ipairs(zones) do
        local ok, ex = pcall(ns.Exploration.ForZone, z)
        if ok and ex and ex.status == "tracked" then
            if z.mapID == here or not pick then pick = z end
            local p = ex.progress
            if p.trackedComplete and not full and z.mapID ~= here then full = z end
            if p.complete == 0 and not none then none = z end
        end
    end
    local function open(z, w, h)
        return function()
            local page = zonesPage()
            if not (page and z) then return false end
            if w then
                if page.mode == "detail" then page:Back() end
                UI.SelectTab("zones"); UI.FitSize(w, h)
                page:Open(z); UI.shotsOpenedDetail = true
            else
                openDetail(z)
            end
            page:OpenPage("explore")
            return true
        end
    end
    local r = ns.Config.RANGES
    local list = { { label = "explore", fn = open(pick) },
        { label = "explore at minimum size", fn = open(pick, r["window.width"][1], r["window.height"][1]) },
        { label = "explore wide", fn = open(pick, wideSize()) } }
    if full then list[#list + 1] = { label = "explore, fully explored", fn = open(full) } end
    if none and none ~= pick then list[#list + 1] = { label = "explore, nothing found yet", fn = open(none) } end
    return list
end

-- /azf shots celebrations (Phase 15 step 9): the class road, profession and reputation
-- celebrations as previews (sounds included), each after the coin has struck gold. The previews
-- use this character's own road, first profession and home city.
local function celebrationSteps()
    local function play(kind)
        return function()
            if ns.Celebration.IsShown() then ns.Celebration.Close() end
            ns.Celebrations.Preview(kind)
        end
    end
    -- First a pause with no picture: the stop's shot came out without its celebration when it
    -- ran as the window opened (WoWScrnShot_111426_223149).
    local list = { { label = "celebrations: the window settles", fn = function() end, skip = true, wait = 1.5 } }
    -- The zone seals' flash (owner, 2026-11-14), caught near its peak: a category seal's at
    -- about 0.7 s, the claim seal's at about 1.55 s (the zone you stand in).
    list[#list + 1] = { label = "celebrate explore (flash)", fn = play("explore"), wait = 0.7 }
    list[#list + 1] = { label = "celebrate claim (flash)", fn = play("claim"), wait = 1.55 }
    for _, k in ipairs({ "stop", "road", "rank", "mastered" }) do
        list[#list + 1] = { label = "celebrate " .. k, fn = play(k), wait = 2 }
    end
    list[#list + 1] = { label = "celebrate rep (toast)", fn = play("rep"), wait = 1 }
    list[#list + 1] = { label = "celebrate exalted (toast)", fn = function()
        ns.Celebration.Close(); play("exalted")()
    end, wait = 6 } -- after the first toast has gone
    list[#list + 1] = { label = "celebrations closed", fn = function()
        if ns.Celebration.IsShown() then ns.Celebration.Close() end
    end, skip = true }
    return list
end

-- Each step changes the window, then one screenshot is taken.
local function steps(which)
    if which == "celebrations" or which == "celebrate" then return celebrationSteps() end
    if which == "banners" then return bannerSteps() end
    -- /azf shots zone <mapID> [...]: those zones' Zone Detail (the art in full colour, e.g. after
    -- a tone pass in process-art.ps1, Phase 15 step 10).
    if which and which:match("^zone%s") then
        local want, list = {}, {}
        for id in which:gmatch("%d+") do want[tonumber(id)] = true end
        for _, z in ipairs(allZones()) do
            if want[z.mapID] then list[#list + 1] = { label = "zone " .. z.name, fn = function() openDetail(z) end } end
        end
        return list
    end
    if which == "explore" then return exploreSteps() end
    if which == "class" then return classSteps() end
    if which == "professions" or which == "profs" then return professionSteps() end
    if which == "dungeons" or which == "dungeon" then return dungeonSteps() end
    if which == "links" then return linkSteps() end
    if which == "reputation" or which == "rep" then
        local here = C_Map and C_Map.GetBestMapForUnit
            and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
        return reputationSteps(allZones(), here)
    end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function size(w, h) return function() UI.FitSize(w, h) end end
    local list = {}
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id, fn = function()
            UI.ApplyGeometry(); UI.SelectTab(def.id)
            -- Start the Zones shots on the catalogue, even if Zone Detail was left open.
            local page = def.id == "zones" and zonesPage()
            if page and page.mode == "detail" then page:Back() end
        end }
    end
    -- Overview with focus on the class road window (round 3: its edge and the chevron).
    list[#list + 1] = { label = "overview, class road", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("overview")
        local item = ns.Focus.Current()
        UI.shotsOverviewKey = item and item.key
        ns.Focus.FocusKey("classroad"); UI.RefreshHints()
    end }
    -- Focus after an RT jump: chevron, row highlight and scroll-into-view in one picture.
    list[#list + 1] = { label = "zones, next section", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("zones")
        local item = ns.Focus.Current()
        UI.shotsFocusKey = item and item.key
        ns.Focus.Jump(1); UI.RefreshHints()
    end }
    -- The catalogue's other view and the Sort popup (the view is restored at the end). The wide
    -- split view always shows the list, so there the other view would repeat the last shot.
    if not UI.IsWide() then list[#list + 1] = { label = "zones, other view", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("zones")
        local page = zonesPage()
        if UI.shotsView == nil then UI.shotsView = ns.db.zones.displayMode end
        page.catalogue:CycleView()
    end } end
    -- The Atlas view (Phase 10).
    if not UI.IsWide() then list[#list + 1] = { label = "zones, atlas", fn = function()
        local page = zonesPage()
        if UI.shotsView == nil then UI.shotsView = ns.db.zones.displayMode end
        ns.db.zones.displayMode = "atlas"; page.catalogue:Refresh()
    end } end
    list[#list + 1] = { label = "zones, sort popup", fn = function()
        local page = zonesPage()
        local cat = page.catalogue
        for _, o in ipairs(ns.ZonesCatalogue.OPTIONS) do
            if o.key == "sort" then page:OpenPopup(o, cat.options.sort) end
        end
    end }
    list[#list + 1] = { label = "zones, popup closed", fn = function()
        local page = zonesPage()
        if page.popup:IsShown() then page:ClosePopup() end
        if UI.shotsView and ns.db.zones.displayMode ~= UI.shotsView then
            ns.db.zones.displayMode = UI.shotsView; page.catalogue:Refresh()
        end
    end, skip = true }
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id .. " at minimum size", fn = function()
            UI.SelectTab(def.id); size(minW, minH)()
        end }
    end
    -- Zone Detail for the zone the player stands in (or the first listed zone).
    local zones = allZones()
    local here = C_Map and C_Map.GetBestMapForUnit
        and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local pick = zones[1]
    for _, z in ipairs(zones) do if z.mapID == here then pick = z end end
    list[#list + 1] = { label = "zone detail", fn = function() openDetail(pick) end }
    -- Its category pages (the dashboard's tiles), only where the tile opens one: a tile that
    -- doesn't apply (no flight master) is quiet in play, so the shots don't force its page
    -- open either (review 2026-11-14).
    for _, key in ipairs({ "explore", "quests", "flights" }) do
        list[#list + 1] = { label = "zone detail, " .. key, fn = function()
            local page = zonesPage()
            openDetail(pick)
            local tiles = page and page.detail and page.detail.tiles or {}
            for _, tile in ipairs(tiles) do
                local it = tile.item
                if it and it.key == "tile:" .. key then
                    if it.onActivate then it.onActivate(it); return true end
                end
            end
            ns.Debug.Print("shot skipped: the %s tile doesn't open a page here", key)
            return false
        end }
    end
    -- The Reputation ledger and a faction page (Phase 11), where some zone has factions.
    for _, s in ipairs(repSteps(zones, here, false)) do list[#list + 1] = s end
    -- A zone the game has no Explore achievement for (the "can't track" message).
    for _, z in ipairs(zones) do
        local ok, ex = pcall(ns.Exploration.ForZone, z)
        if ok and ex and ex.status == "untracked" then
            list[#list + 1] = { label = "zone detail, not tracked", fn = function() openDetail(z) end }
            break
        end
    end
    -- Wide window: the split view with focus in the list, then in the selected zone's areas.
    list[#list + 1] = { label = "zones wide", fn = function()
        local page = zonesPage()
        if page and page.mode == "detail" then page:Back() end
        UI.shotsOpenedDetail = nil
        UI.SelectTab("zones"); size(wideSize())()
        if page and pick then page:Click(pick) end -- start on the player's zone, which has areas
    end }
    list[#list + 1] = { label = "zones wide, checklist", fn = function()
        local page = zonesPage()
        local item = ns.Focus.Current()
        if page and item and item.zone then page:Open(item.zone); UI.shotsOpenedDetail = true end
    end }
    for _, s in ipairs(repSteps(zones, here, true)) do list[#list + 1] = s end
    for _, s in ipairs(repTabSteps(true)) do list[#list + 1] = s end
    return list
end
UI.ShotSteps = steps

function UI.RunShots(which)
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

    local list, startTab, i = steps(which), UI.CurrentTab(), 0
    if #list == 0 then return ns.Print("Nothing to screenshot.") end
    local pictures = 0
    for _, s in ipairs(list) do if not s.skip then pictures = pictures + 1 end end
    UI.shotsRunning = true
    local function finish(msg)
        UI.shotsRunning = false
        UI.ApplyGeometry(); UI.Relayout()
        local page = zonesPage()
        if page and page.popup:IsShown() then page:ClosePopup() end
        if page and UI.shotsView and ns.db.zones.displayMode ~= UI.shotsView then
            ns.db.zones.displayMode = UI.shotsView; page.catalogue:Refresh()
        end
        UI.shotsView = nil
        local rp = UI.GetFrame().pages.reputation
        if rp then
            if rp.mode == "detail" then rp:Back() end
            if UI.shotsRepSort and ns.db.reputation.sort ~= UI.shotsRepSort then
                ns.db.reputation.sort = UI.shotsRepSort; rp:Redraw()
            end
        end
        UI.shotsRepSort = nil
        local cp = UI.GetFrame().pages.class
        if cp and cp.mode == "steps" then cp:Back() end
        local pp = UI.GetFrame().pages.professions
        if pp and pp.mode == "page" then pp:Back() end
        if pp and pp.mode == "page" then pp:Back() end
        local dp = UI.GetFrame().pages.dungeons
        if dp and dp.mode == "page" then dp:Back() end
        if dp and UI.shotsDunView ~= nil then
            ns.db.dungeons.filter = UI.shotsDunFilter or ns.db.dungeons.filter
            dp:SetView(UI.shotsDunView)
        end
        UI.shotsDunView, UI.shotsDunFilter = nil, nil
        if dp and UI.shotsDunPv ~= nil then dp.pv = UI.shotsDunPv or nil end
        UI.shotsDunPv = nil
        if UI.shotsOpenedDetail then
            UI.SelectTab("zones")
            local zp = UI.GetFrame().pages.zones
            zp:Back() -- a category or faction page needs a second B to reach the catalogue
            if zp.mode == "detail" then zp:Back() end
            UI.shotsOpenedDetail = nil
        end
        if UI.shotsFocusKey ~= nil then
            UI.SelectTab("zones"); ns.Focus.FocusKey(UI.shotsFocusKey); UI.shotsFocusKey = nil
        end
        if UI.shotsOverviewKey ~= nil then
            UI.SelectTab("overview"); ns.Focus.FocusKey(UI.shotsOverviewKey); UI.shotsOverviewKey = nil
        end
        UI.SelectTab(startTab)
        ns.Print(msg)
    end
    local function nextStep()
        if not UI.IsShown() then return finish("Screenshots stopped: the window was closed.") end
        i = i + 1
        local s = list[i]
        if not s then return finish(string.format("Took %d screenshots.", pictures)) end
        local t = ns.Events.StartTiming()
        local ok, err = pcall(s.fn)
        ns.Events.StopTiming("shots: " .. s.label, t)
        if not ok then
            ns.Debug.Error("shots " .. s.label, err)
            return finish("Screenshots stopped: " .. tostring(err))
        end
        -- A tidy-up step, or a step with nothing to show here (fn returned false): no picture.
        if s.skip or err == false then return C_Timer.After(s.wait or SETTLE, nextStep) end
        C_Timer.After(s.wait or SETTLE, function()
            local sok, serr = pcall(Screenshot)
            if not sok then ns.Debug.Error("Screenshot", serr) end
            ns.Debug.Print("shot %d: %s", i, s.label)
            C_Timer.After(GAP, nextStep)
        end)
    end
    ns.Printf("Taking %d screenshots; keep the window open.", pictures)
    nextStep()
end
