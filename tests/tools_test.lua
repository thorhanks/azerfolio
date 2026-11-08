-- tools/trace-report.lua against a small fake SavedVariables file.
local function run(file, section, param)
    local cmd = string.format('set "AZF_SV_FILE=%s" && luajit tools/trace-report.lua %s %s', file, section, param or "")
    local f = assert(io.popen(cmd))
    local out = f:read("*a")
    f:close()
    return out
end

local FAKE = [[
AzerfolioDB = { debug = true, trace = {
  { t = 10, kind = "quests", status = "ready", total = 5, counted = 3, steps = 4, workMs = 1.5, maxStepMs = 0.5,
    completedKnown = true, left = { sort = 1, repeatable = 1, error = 0 } },
  { t = 11, kind = "quests", report = true, status = "ready", character = { name = "Gideon", raceID = 1, classID = 2, level = 10 },
    all = { completed = 1, denominator = 3, eligible = 2, locked = 1, unavailable = 0, unknown = 0, coverage = "complete", percent = 33.3 },
    reasons = { ["level 12"] = 1, ["level 14"] = 2, completed = 1 }, zones = { "1429 Elwynn Forest 3 quests: 1/3 done" },
    empty = {}, notListed = {}, unmapped = {}, here = 1429, hereList = { "7 Kobold Camp Cleanup L2/1 complete eligible completed" } },
  { t = 12, kind = "quests", report = true, status = "ready", character = { name = "Gideon" },
    all = { completed = 2, denominator = 3, eligible = 2, locked = 1, unavailable = 0, unknown = 0, coverage = "complete" },
    reasons = {}, zones = { "1429 Elwynn Forest 3 quests: 2/3 done" }, empty = {}, notListed = {}, unmapped = {},
    here = 1429, hereList = { "7 Kobold Camp Cleanup L2/1 complete eligible completed" } },
  { t = 13, kind = "perf", memoryKB = 6270.2, gc = true, seconds = 20, profiler = { PeakTime = 3.5 }, sizes = { trace = 4 },
    top = { { name = "AZF_READY", count = 1, ms = 0.1, max = 0.1 } } },
} }
]]

return function(t)
    local file = os.tmpname()
    if file:sub(1, 1) == "\\" then file = (os.getenv("TEMP") or ".") .. file end
    local h = assert(io.open(file, "w"))
    h:write(FAKE)
    h:close()

    t.test("trace-report quests: build, report, grouped reasons and the change since the report before", function()
        local out = run(file, "quests")
        t.ok(out:find("5 quests, 3 in zones, 4 frames"), out)
        t.ok(out:find("all zones 2/3 done"), out)
        t.ok(out:find("since the report before: completed 1%->2"), out)
        local r = run(file, "kind", "quests 1")
        t.ok(r:find("report=true"), r)
    end)

    t.test("trace-report zone and perf", function()
        local z = run(file, "zone", "1429")
        t.ok(z:find("1429 Elwynn Forest 3 quests: 2/3 done"), z)
        t.ok(z:find("Kobold Camp Cleanup"), z)
        local p = run(file, "perf")
        t.ok(p:find("memory 6270.20 KB %(after a full GC%)"), p)
        t.ok(p:find("AZF_READY"), p)
    end)

    t.test("trace-report groups level reasons", function()
        -- a copy whose latest report has level reasons
        local f2 = file .. ".2"
        local h2 = assert(io.open(f2, "w"))
        h2:write((FAKE:gsub("reasons = {}, zones", "reasons = { [\"level 12\"] = 1, [\"level 14\"] = 2 }, zones")))
        h2:close()
        local out = run(f2, "quests")
        os.remove(f2)
        t.ok(out:find("reasons: level 3"), out)
    end)
end
