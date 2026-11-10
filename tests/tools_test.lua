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
  { t = 14, kind = "reputation", status = "ready", zones = 1, factions = 1, list = { ["1434"] = "21:40 87:12 <>21/87" } },
  { t = 15, kind = "reputation", refresh = "build", read = 2, missing = 0, metComplete = true, expanded = 1,
    standing = { ["21"] = "4 0 0/3000 unmet" } },
  { t = 16, kind = "reputation", report = true, zones = 1, picks = { ["1434"] = "21:40 [1:100 2:75]" },
    watched = { ["1444"] = "12 quests; 169 dropped 2/40 [7003:75 7721:50]  |  609 kept 6/30 [1:25]" },
    probes = { ["7003"] = "Zapped Giants lv48 exists=true zoneOrSort=440 -> zone 1446, index 1446, rep [169:75]" } },
  { t = 17, kind = "class", report = true, status = "ready", character = "PALADIN Alliance raceID=1 raceFile=Human raceBit=1 level=10",
    totals = "road 1/5, side paths 0/2, quests 1/42, unknown stops 0, complete false", completedKnown = true,
    ids = "500 curated IDs, 2 not in QuestieDB, 120 newer IDs present", missing = "78090 78091",
    stops = { ["01 intro"] = "road done Consecrated Letter 1/1  [3101:done]" }, extras = { divinity = "2998:locked 1641:locked" },
    inferred = { artifact = "78088 pre=- next=78089" }, probes = { ["1641"] = "The Tome of Divinity exists=true completed=false" } },
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

    t.test("trace-report reputation: build, standing, and the debug report's picks, tally and probes", function()
        local out = run(file, "reputation")
        t.ok(out:find("1 zones, 1 factions"), out)
        t.ok(out:find("21:40 %[1:100 2:75%]"), out)
        t.ok(out:find("169 dropped 2/40 %[7003:75 7721:50%]"), out)
        t.ok(out:find("609 kept 6/30"), out)
        t.ok(out:find("7003%s+Zapped Giants lv48 .- index 1446"), out)
    end)

    t.test("trace-report class: totals, stops, extras, inferred links and probes", function()
        local out = run(file, "class")
        t.ok(out:find("PALADIN Alliance raceID=1"), out)
        t.ok(out:find("road 1/5, side paths 0/2"), out)
        t.ok(out:find("not in QuestieDB: 78090 78091"), out)
        t.ok(out:find("Consecrated Letter 1/1"), out)
        t.ok(out:find("2998:locked 1641:locked"), out)
        t.ok(out:find("78088 pre=%- next=78089"), out)
        t.ok(out:find("1641%s+The Tome of Divinity exists=true"), out)
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
