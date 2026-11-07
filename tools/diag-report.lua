-- Summarizes the AzerfolioDiag SavedVariables dump.
-- Usage: luajit tools/diag-report.lua [section] [param]
-- Sections: summary (default), env, ach, explore, maps, quests, zone, events, art, errors,
--           criteria <achID>, ns <filter>, log [n], skin [tree [filter]]
-- Set AZF_DIAG_FILE to read a different dump.
local DEFAULT = "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account/COMPUTERWISPERER/SavedVariables/AzerfolioDiag.lua"

local section, arg2 = arg[1] or "summary", arg[2]
local path = os.getenv("AZF_DIAG_FILE") or DEFAULT

-- Load the file in an empty environment: it only assigns a table.
local chunk = assert(loadfile(path))
local env = {}
setfenv(chunk, env)
chunk()
local DB = assert(env.AzerfolioDiagDB, "AzerfolioDiagDB missing")

local function p(...) print(string.format(...)) end
local function keys(t) local k = {} for x in pairs(t or {}) do k[#k + 1] = x end table.sort(k, function(a, b) return tostring(a) < tostring(b) end) return k end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function s(v) if type(v) == "table" then local o = {} for i, x in ipairs(v) do o[i] = tostring(x) end return "{" .. table.concat(o, ",") .. "}" end return tostring(v) end

local R = {}

function R.errors()
    p("errors: %d", #(DB.errors or {}))
    for _, e in ipairs(DB.errors or {}) do p("  [%s] %s", e.label, e.err) end
end

function R.env()
    local e = DB.env or {}
    p("build: %s", s(e.build)); p("lua: %s  locale: %s  projectID: %s", tostring(e.lua), tostring(e.locale), tostring(e.projectID))
    for _, k in ipairs(keys(e.projectConstants)) do p("  %s = %s", k, tostring(e.projectConstants[k])) end
    local pl = e.player or {}
    p("player: %s-%s lvl %s race %s class %s faction %s xp %s/%s max %s", tostring(pl.name), tostring(pl.realm), tostring(pl.level),
        s(pl.race), s(pl.class), s(pl.faction), tostring(pl.xp), tostring(pl.xpMax), tostring(pl.maxLevel))
    p("C_ namespaces: %d", count(e.namespaces))
    p("globals:"); for _, k in ipairs(keys(e.globals)) do p("  %-34s %s", k, e.globals[k]) end
    p("templates:"); for _, k in ipairs(keys(e.templates)) do p("  %-34s %s", k, tostring(e.templates[k])) end
    p("matching globals (legacy/forever/explor): %d", count(e.matchingGlobals))
    for _, k in ipairs(keys(e.matchingGlobals)) do p("  %s (%s)", k, e.matchingGlobals[k]) end
    p("uiMapType: "); for _, k in ipairs(keys(e.uiMapType)) do p("  %s=%s", k, tostring(e.uiMapType[k])) end
end

function R.ns(filter)
    local e = DB.env or {}
    for _, k in ipairs(keys(e.namespaces)) do
        if not filter or k:lower():find(filter:lower(), 1, true) then
            p("%s: %s", k, table.concat(e.namespaces[k], ", "))
        end
    end
end

function R.ach()
    local a = DB.achievements or {}
    p("categories: %d, achievements: %d", #(a.categories or {}), #(a.all or {}))
    for _, c in ipairs(a.categories or {}) do
        p("  cat %-6s %-32s parent %-6s %-24s %s/%s", tostring(c.id), tostring(c.name), tostring(c.parent), tostring(c.parentName), tostring(c.completed), tostring(c.total))
    end
end

function R.explore()
    local a = DB.achievements or {}
    local list = {}
    for id, x in pairs(a.explore or {}) do list[#list + 1] = x end
    table.sort(list, function(x, y) return tostring(x.name) < tostring(y.name) end)
    p("explore achievements: %d", #list)
    for _, x in ipairs(list) do
        local done, assetAreas, withCID = 0, 0, 0
        local types = {}
        for _, c in ipairs(x.criteria or {}) do
            if c.done then done = done + 1 end
            if c.assetAreaName then assetAreas = assetAreas + 1 end
            if c.criteriaID and c.criteriaID ~= 0 then withCID = withCID + 1 end
            types[tostring(c.type)] = true
        end
        p("  %-6s %-40s cat %-6s %2d/%-2d done=%-5s areaAssets=%d critIDs=%d types=%s maps=%s",
            tostring(x.id), tostring(x.name), tostring(x.category), done, #(x.criteria or {}), tostring(x.done), assetAreas, withCID,
            table.concat(keys(types), "/"), s(x.matchedMapIDs))
    end
end

function R.criteria(id)
    local x = DB.achievements and DB.achievements.explore and DB.achievements.explore[tonumber(id)]
    if not x then p("no explore achievement %s", tostring(id)) return end
    p("%s %s desc=%s flags=%s", tostring(x.id), tostring(x.name), tostring(x.desc), tostring(x.flags))
    for _, c in ipairs(x.criteria or {}) do
        p("  %2d %-30s type=%s done=%s asset=%s (%s) critID=%s flags=%s qty=%s/%s elig=%s",
            c.index, tostring(c.name), tostring(c.type), tostring(c.done), tostring(c.assetID), tostring(c.assetAreaName),
            tostring(c.criteriaID), tostring(c.flags), tostring(c.qty), tostring(c.reqQty), tostring(c.eligible))
    end
end

function R.maps()
    local m = DB.maps or {}
    p("maps: %s", tostring(m.count))
    local byType = {}
    for _, x in pairs(m.byID or {}) do byType[x.mapType or -1] = (byType[x.mapType or -1] or 0) + 1 end
    for _, k in ipairs(keys(byType)) do p("  mapType %s: %d", tostring(k), byType[k]) end
    local zones = {}
    for id, x in pairs(m.byID or {}) do if x.mapType == 3 then zones[#zones + 1] = x end end
    table.sort(zones, function(a, b) return a.id < b.id end)
    p("zone maps (type 3): %d", #zones)
    for _, z in ipairs(zones) do
        local parent = m.byID[z.parent]
        p("  %-5d %-34s parent %-5s %-20s explored textures %s", z.id, tostring(z.name), tostring(z.parent), parent and tostring(parent.name) or "?", tostring(z.exploredTextureCount))
    end
end

function R.quests()
    local q = DB.quests or {}
    for _, k in ipairs(keys(q.has)) do p("  %-40s %s", k, tostring(q.has[k])) end
    p("allCompletedCount %s legacyCompletedCount %s logEntries %s", tostring(q.allCompletedCount), tostring(q.legacyCompletedCount), tostring(q.logEntries))
    for _, x in ipairs(q.samples or {}) do p("  quest %s done=%s title=%s", tostring(x.id), tostring(x.done), tostring(x.title)) end
end

function R.zone()
    for i, z in ipairs(DB.zoneSnapshots or {}) do
        local w = z.where or {}
        p("snapshot %d: map %s zone %s sub %s pos %s,%s", i, tostring(w.map), tostring(w.zone), tostring(w.subzone), tostring(w.x), tostring(w.y))
        for _, a in ipairs(w.areas or {}) do p("  area here: %s %s", tostring(a.id), tostring(a.name)) end
        for _, c in ipairs(z.mapChain or {}) do p("  chain: %s %s type %s", tostring(c.id), tostring(c.name), tostring(c.mapType)) end
        p("  explored textures: %d", #(z.exploredTextures or {}))
        local t1 = z.exploredTextures and z.exploredTextures[1]
        if t1 then for _, k in ipairs(keys(t1)) do p("    tex[1].%s = %s", k, s(t1[k])) end end
        if z.exploreAchievement then p("  achievement %s %s", tostring(z.exploreAchievement.id), tostring(z.exploreAchievement.name)) end
    end
end

function R.events()
    p("registration:"); for _, k in ipairs(keys(DB.eventRegistration)) do p("  %-30s %s", k, tostring(DB.eventRegistration[k])) end
    p("counts:"); for _, k in ipairs(keys(DB.eventCounts)) do p("  %-30s %s", k, tostring(DB.eventCounts[k])) end
    p("log entries: %d, diffs: %d", #(DB.log or {}), #(DB.diffs or {}))
    for _, d in ipairs(DB.diffs or {}) do
        p("  diff t=%s map=%s textures %s->%s triggers=%d", tostring(d.t), tostring(d.textures and d.textures.map), tostring(d.textures and d.textures.before), tostring(d.textures and d.textures.after), #(d.triggers or {}))
        for _, c in ipairs(d.changes or {}) do p("    %s #%s %s asset=%s crit=%s %s->%s", tostring(c.achName), tostring(c.index), tostring(c.name), tostring(c.assetID), tostring(c.criteriaID), tostring(c.from), tostring(c.to)) end
        for _, tr in ipairs(d.triggers or {}) do p("    trigger %s @%s", tostring(tr.e), tostring(tr.gt)) end
    end
    if DB.sniff then
        p("sniff (on=%s): %d distinct events", tostring(DB.sniffOn), count(DB.sniff.counts))
        local list = {}
        for k, v in pairs(DB.sniff.counts) do list[#list + 1] = { k, v } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i = 1, #list do p("  %-44s %d", list[i][1], list[i][2]) end
    end
end

function R.log(n)
    local log = DB.log or {}
    n = tonumber(n) or 60
    for i = math.max(1, #log - n + 1), #log do
        local l = log[i]
        local args = {}
        for j = 1, (l.args and l.args.n or 0) do args[#args + 1] = tostring(l.args[j]) end
        p("%s %-28s map=%s sub=%s args=%s", tostring(l.gt), l.e, tostring(l.where and l.where.map), tostring(l.where and l.where.subzone), table.concat(args, " | "))
    end
end

function R.art()
    for _, r in ipairs((DB.art or {}).results or {}) do
        p("  %-24s ok=%s ret=%s tex=%s fileID=%s", r.label, tostring(r.pcallOk), tostring(r.setTextureReturn), tostring(r.getTexture), tostring(r.getTextureFileID))
    end
end

function R.pad()
    local pad = DB.pad
    if not pad then p("no gamepad probe recorded") return end
    local e = pad.env or {}
    for _, k in ipairs(keys(e)) do
        if type(e[k]) ~= "table" then p("  %-22s %s", k, tostring(e[k])) end
    end
    p("  frame methods:"); for _, k in ipairs(keys(e.frameMethods)) do p("    %-26s %s", k, tostring(e.frameMethods[k])) end
    p("  C_GamePad: %s", table.concat(e.C_GamePadFunctions or {}, ", "))
    p("  constants:"); for _, k in ipairs(keys(e.constants)) do p("    %-36s %s", k, tostring(e.constants[k])) end
    p("  enableButton=%s enableStick=%s focusGamepad=%s stoppedBy=%s", tostring(pad.enableButton), tostring(pad.enableStick), tostring(pad.focusGamepad), tostring(pad.stoppedBy))
    p("  presses: %d", #(pad.presses or {}))
    for _, x in ipairs(pad.presses or {}) do if x.down then p("    %-16s @%.2f", x.key, (x.gt or 0) - (pad.startedAt or 0)) end end
    p("  sticks: %d", #(pad.sticks or {}))
    for i, s in ipairs(pad.sticks or {}) do if i <= 10 then p("    %s x=%.2f y=%.2f", s.stick, s.x or 0, s.y or 0) end end
end

-- skin: unique atlases, files and fonts per probed frame. "skin tree [root|overlays|templates]"
-- prints the indented frame tree instead.
local function eachNode(node, depth, fn)
    if type(node) ~= "table" then return end
    fn(node, depth)
    for _, r in ipairs(node.regions or {}) do fn(r, depth + 1) end
    for _, c in ipairs(node.children or {}) do eachNode(c, depth + 1, fn) end
end

local function nodeLine(n)
    local size = n.size and string.format("%sx%s", tostring(math.floor((tonumber(n.size[1]) or 0) + 0.5)), tostring(math.floor((tonumber(n.size[2]) or 0) + 0.5))) or "?"
    local label = (n.key and n.key ~= "nil" and n.key) or n.name or ""
    local bits = { tostring(n.type), label, size, n.shown == false and "hidden" or "" }
    if n.atlas and n.atlas ~= "nil" then bits[#bits + 1] = "atlas=" .. tostring(n.atlas) end
    if (not n.atlas or n.atlas == "nil") and n.texture and n.texture ~= "nil" then bits[#bits + 1] = "tex=" .. tostring(n.texture) end
    if n.fileID and n.fileID ~= "nil" then bits[#bits + 1] = "id=" .. tostring(n.fileID) end
    if n.layer then bits[#bits + 1] = "layer=" .. s(n.layer) end
    if n.color then bits[#bits + 1] = "rgba=" .. s(n.color) end
    if n.font then bits[#bits + 1] = "font=" .. s(n.font) end
    if n.text and n.text ~= "nil" then bits[#bits + 1] = "text=" .. tostring(n.text) end
    return table.concat(bits, " ")
end

local function skinRoots(sk)
    local list = {}
    for _, k in ipairs(keys(sk.roots)) do list[#list + 1] = { k, sk.roots[k] } end
    for i, o in ipairs(sk.overlays or {}) do list[#list + 1] = { "overlay" .. i .. " " .. tostring(o.name), o } end
    for _, t in ipairs(sk.templates or {}) do list[#list + 1] = { "template " .. t.template, t.tree } end
    return list
end

function R.skin(mode, which)
    local sk = DB.skin
    if not sk then p("no skin probe recorded") return end
    if mode == "tree" then
        for _, pair in ipairs(skinRoots(sk)) do
            if not which or pair[1]:lower():find(which:lower(), 1, true) then
                p("== %s", pair[1])
                eachNode(pair[2], 0, function(n, d)
                    if n.type == "Texture" or n.type == "FontString" or n.type == "MaskTexture" then
                        if n.shown == false then return end
                    end
                    p("%s%s", string.rep("  ", d), nodeLine(n))
                end)
            end
        end
        return
    end
    for _, pair in ipairs(skinRoots(sk)) do
        local atlases, files, fonts, nodes = {}, {}, {}, 0
        eachNode(pair[2], 0, function(n)
            nodes = nodes + 1
            if n.atlas and n.atlas ~= "nil" then atlases[n.atlas] = (atlases[n.atlas] or 0) + 1
            elseif n.texture and n.texture ~= "nil" then files[tostring(n.texture)] = (files[tostring(n.texture)] or 0) + 1 end
            if n.font then local f = s(n.font); fonts[f] = (fonts[f] or 0) + 1 end
        end)
        p("== %s (%d nodes%s)", pair[1], nodes, type(pair[2]) == "table" and pair[2].shown == false and ", hidden" or "")
        for _, k in ipairs(keys(atlases)) do p("  atlas %-50s x%d", k, atlases[k]) end
        for _, k in ipairs(keys(files)) do p("  file  %-50s x%d", k, files[k]) end
        for _, k in ipairs(keys(fonts)) do p("  font  %-50s x%d", k, fonts[k]) end
    end
    p("atlas checks:")
    for _, k in ipairs(keys(sk.atlases)) do
        local a = sk.atlases[k]
        p("  %-45s %s", k, a and string.format("file=%s %sx%s", tostring(a.file or a.filename), tostring(a.width), tostring(a.height)) or "MISSING")
    end
    p("templates:")
    for _, t in ipairs(sk.templates or {}) do p("  %-28s %s", t.template, t.ok and "ok" or ("FAILED " .. tostring(t.err))) end
end

function R.summary()
    R.errors(); print(); R.env(); print(); R.explore(); print(); R.quests(); print(); R.art()
end

local fn = R[section]
if not fn then print("unknown section " .. section) os.exit(1) end
fn(arg2, arg[3])
