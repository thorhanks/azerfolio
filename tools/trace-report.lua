-- Summarizes Azerfolio's debug trace (AzerfolioDB.trace, written in debug mode on /reload).
-- Usage: luajit tools/trace-report.lua [section] [param]
-- Sections:
--   summary (default)   file time, session starts, entry counts by kind, the latest of each kind
--   last [n]            the latest n entries (default 15), one line each
--   quests              the latest quest build and report, compactly; changes since the report before
--   zone <mapID>        one zone's quest line and checklist from the latest quest report
--   perf                the latest /azf debug perf: memory, profiler peaks, busiest callbacks
--   reputation          zone factions built (per zone, rivals) and the latest standing read
--   kind <name> [n]     the latest n entries of one kind, one line each
-- Set AZF_SV_FILE to read a different file.
local DEFAULT = "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account/COMPUTERWISPERER/SavedVariables/Azerfolio.lua"

local section, arg2, arg3 = arg[1] or "summary", arg[2], arg[3]
local path = os.getenv("AZF_SV_FILE") or DEFAULT

-- Load the file in an empty environment: it only assigns tables.
local chunk = assert(loadfile(path))
local env = {}
setfenv(chunk, env)
chunk()
local DB = assert(env.AzerfolioDB, "AzerfolioDB missing")
local trace = DB.trace or {}

local function p(...) print(string.format(...)) end
local function keys(t)
    local k = {}
    for x in pairs(t or {}) do k[#k + 1] = x end
    table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
    return k
end
local function num(v) return type(v) == "number" and (v == math.floor(v) and tostring(v) or string.format("%.2f", v)) or tostring(v) end

-- A flat, short rendering: scalars inline, lists as counts, tables as k=v (one level).
local function short(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return num(v) end
    if #v > 0 then return "[" .. #v .. "]" end
    if depth > 0 then return "{..}" end
    local o = {}
    for _, k in ipairs(keys(v)) do o[#o + 1] = tostring(k) .. "=" .. short(v[k], depth + 1) end
    return "{" .. table.concat(o, " ") .. "}"
end

local SKIP = { t = true, kind = true }
local function line(i, e)
    local o = {}
    for _, k in ipairs(keys(e)) do
        if not SKIP[k] then o[#o + 1] = k .. "=" .. short(e[k], 1) end
    end
    local s = table.concat(o, " ")
    if #s > 160 then s = s:sub(1, 157) .. "..." end
    return string.format("%3d %9.1f %-12s %s", i, e.t or 0, tostring(e.kind), s)
end

local function latest(pred, skip)
    skip = skip or 0
    for i = #trace, 1, -1 do
        if pred(trace[i]) then
            if skip == 0 then return trace[i], i end
            skip = skip - 1
        end
    end
end

-- "level 12"... reasons as one "level" bucket.
local function groupReasons(r)
    local out = {}
    for why, n in pairs(r or {}) do
        local k = why:match("^level %d+$") and "level" or why
        out[k] = (out[k] or 0) + n
    end
    return out
end

local function byCount(t)
    local list = {}
    for k, v in pairs(t or {}) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return tostring(a.k) < tostring(b.k) end)
    local o = {}
    for i, x in ipairs(list) do o[i] = tostring(x.k) .. " " .. num(x.v) end
    return table.concat(o, ", ")
end

local R = {}

function R.summary()
    local f = io.popen('powershell -NoProfile -Command "(Get-Item \'' .. path .. '\').LastWriteTime.ToString(\'yyyy-MM-dd HH:mm:ss\')"')
    local when = f and f:read("*l") or "?"
    if f then f:close() end
    p("file written %s; debug %s; %d trace entries", tostring(when), tostring(DB.debug), #trace)
    local counts, last, sessions = {}, {}, 0
    local prev
    for i, e in ipairs(trace) do
        counts[e.kind] = (counts[e.kind] or 0) + 1
        last[e.kind] = i
        if prev and e.t and prev > e.t then sessions = sessions + 1 end -- GetTime restarts with the client
        prev = e.t
    end
    p("kinds: %s", byCount(counts))
    if sessions > 0 then p("client restarts inside the trace: %d", sessions) end
    for _, k in ipairs(keys(last)) do print(line(last[k], trace[last[k]])) end
end

function R.last(n)
    n = tonumber(n) or 15
    for i = math.max(1, #trace - n + 1), #trace do print(line(i, trace[i])) end
end

function R.kind(name, n)
    n = tonumber(n) or 10
    local hits = {}
    for i, e in ipairs(trace) do if e.kind == name then hits[#hits + 1] = i end end
    for j = math.max(1, #hits - n + 1), #hits do print(line(hits[j], trace[hits[j]])) end
end

local function isReport(e) return e.kind == "quests" and e.report and e.status == "ready" end

function R.quests()
    local b, bi = latest(function(e) return e.kind == "quests" and e.status == "ready" and not e.report end)
    if b then
        p("build #%d at %.1f: %d quests, %d in zones, %s frames, %s ms work, %s ms max frame, completed list %s",
            bi, b.t, b.total or 0, b.counted or 0, num(b.steps), num(b.workMs), num(b.maxStepMs),
            b.completedKnown == nil and "?" or (b.completedKnown and "read" or "missing"))
        p("  left out: %s", byCount(b.left))
    end
    local u = latest(function(e) return e.kind == "quests" and e.status == "unavailable" end)
    if u then p("unavailable at %.1f: %s", u.t, tostring(u.reason)) end
    for _, e in ipairs(trace) do
        if e.kind == "quests" and e.refresh then p("refresh %s at %.1f: completed %s (+%s)", e.refresh, e.t, num(e.completed), num(e.added)) end
    end
    local r, ri = latest(isReport)
    if not r then p("no quest report in the trace (run /azf debug quests with debug on)"); return end
    local c, a = r.character or {}, r.all or {}
    p("report #%d at %.1f: %s race %s class %s level %s; eval %s ms", ri, r.t, tostring(c.name), num(c.raceID),
        num(c.classID), num(c.level), num(r.evalMs))
    p("  all zones %s/%s done (%s%%), eligible %s, locked %s, unavailable %s, unknown %s, coverage %s",
        num(a.completed), num(a.denominator), a.percent and string.format("%.1f", a.percent) or "-",
        num(a.eligible), num(a.locked), num(a.unavailable), num(a.unknown), tostring(a.coverage))
    p("  reasons: %s", byCount(groupReasons(r.reasons)))
    if r.completedByPlace then p("  completed quests by place: %s", byCount(r.completedByPlace)) end
    if r.here then p("  current zone %s: %s quests", num(r.here), num(r.hereCount or (r.hereList and #r.hereList))) end
    p("  zones listed %s; without quests: %s; not listed: %s", r.zones and #r.zones or "?",
        table.concat(r.empty or {}, ", "), #(r.notListed or {}) > 0 and table.concat(r.notListed, ", ") or "none")
    p("  unmapped: %s", table.concat(r.unmapped or {}, ", "))
    local prev = latest(isReport, 1)
    if prev and prev.all then
        local d = {}
        for _, k in ipairs({ "completed", "denominator", "eligible", "locked", "unavailable", "unknown" }) do
            local x, y = prev.all[k], a[k]
            if type(x) == "number" and type(y) == "number" and x ~= y then d[#d + 1] = string.format("%s %s->%s", k, num(x), num(y)) end
        end
        p("  since the report before: %s", #d > 0 and table.concat(d, ", ") or "no change")
    end
end

function R.zone(mapID)
    local r = latest(isReport)
    if not r then p("no quest report in the trace"); return end
    local want = tostring(mapID or r.here)
    for _, z in ipairs(r.zones or {}) do
        if z:match("^(%d+) ") == want then print(z) end
    end
    if tostring(r.here) == want then
        for _, q in ipairs(r.hereList or {}) do print("  " .. q) end
    elseif r.zones then
        p("(checklist is only saved for the current zone, %s, or with /azf debug quests full)", tostring(r.here))
    end
    for _, z in ipairs(r.full or {}) do
        if tostring(z.mapID) == want then for _, q in ipairs(z.quests or {}) do print("  " .. q) end end
    end
end

function R.perf()
    local e, i = latest(function(x) return x.kind == "perf" end)
    if not e then p("no perf entry (run /azf debug perf with debug on)"); return end
    local pr = e.profiler or {}
    p("perf #%d at %.1f over %s s: memory %s KB%s", i, e.t, num(e.seconds), num(e.memoryKB), e.gc and " (after a full GC)" or " (garbage included)")
    p("  profiler: peak %s ms, session avg %s ms, frames >1 ms %s, >5 ms %s, >10 ms %s, >50 ms %s",
        num(pr.PeakTime), pr.SessionAverageTime and string.format("%.4f", pr.SessionAverageTime) or "?",
        num(pr.CountTimeOver1Ms), num(pr.CountTimeOver5Ms), num(pr.CountTimeOver10Ms), num(pr.CountTimeOver50Ms))
    p("  sizes: %s", short(e.sizes))
    for j, c in ipairs(e.top or {}) do
        if j > 8 then break end
        p("  %-28s %4s calls %7s ms total %6s ms max", tostring(c.name), num(c.count), num(c.ms), num(c.max))
    end
end

-- Zone reputation (Systems/Reputation): the zone factions built, and the latest standing read.
function R.reputation()
    local u = latest(function(e) return e.kind == "reputation" and e.status == "unavailable" end)
    if u then p("unavailable at %.1f: %s", u.t, tostring(u.reason)) end
    local b, bi = latest(function(e) return e.kind == "reputation" and e.status == "ready" end)
    if not b then p("no reputation build in the trace (debug on, then /reload)"); return end
    p("build #%d at %.1f: %s zones, %s factions", bi, b.t, num(b.zones), num(b.factions))
    for _, k in ipairs(keys(b.list)) do p("  %-5s %s", k, tostring(b.list[k])) end
    for _, e in ipairs(trace) do
        if e.kind == "reputation" and e.refresh then
            p("refresh %s at %.1f: read %s, no data %s, met list %s, headers opened %s", tostring(e.refresh), e.t,
                num(e.read), num(e.missing), e.metComplete and "complete" or "incomplete", num(e.expanded))
        end
    end
    local r = latest(function(e) return e.kind == "reputation" and e.refresh end)
    if r then
        p("latest standing (factionID: reaction standing into/span met):")
        for _, k in ipairs(keys(r.standing)) do p("  %-5s %s", k, tostring(r.standing[k])) end
    end
    -- /azf debug reputation: picks with quest IDs, the watched zones' whole tally, the probes.
    local d, di = latest(function(e) return e.kind == "reputation" and e.report end)
    if not d then p("no /azf debug reputation report in the trace"); return end
    if d.status then p("report #%d at %.1f: %s %s", di, d.t, tostring(d.status), tostring(d.reason or "")); return end
    p("report #%d at %.1f: %s zones with factions (factionID:count [questID:amount ...])", di, d.t, num(d.zones))
    for _, k in ipairs(keys(d.picks)) do p("  %-5s %s", k, tostring(d.picks[k])) end
    p("watched zones, every faction the rule saw (factionID kept|dropped|home count/all zones [quests]):")
    for _, k in ipairs(keys(d.watched)) do
        p("  %s", k)
        for part in tostring(d.watched[k]):gmatch("[^|]+") do p("      %s", (part:gsub("^%s+", ""):gsub("%s+$", ""))) end
    end
    p("watched quests in QuestieDB (corrections applied):")
    for _, k in ipairs(keys(d.probes)) do p("  %-6s %s", k, tostring(d.probes[k])) end
end

local fn = R[section]
if not fn then
    p("unknown section %q; sections: summary, last [n], quests, zone <mapID>, perf, reputation, kind <name> [n]", section)
    os.exit(1)
end
fn(arg2, arg3)
