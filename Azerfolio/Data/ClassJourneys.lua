-- Class journeys: the class quest road for each class and side, curated by hand (owner-approved
-- 2026-11-09; research in docs/research/class-quests.md). Only the structure lives here: which
-- quests make up each stop, in what order, and which stops are side paths. Quest names, levels,
-- starters and eligibility come from QuestieDB and the quest rules; done or not comes from the
-- game. Check against QuestieDB with `luajit tools/qdb.lua class check`.
--
-- ClassJourneyData[CLASS][side] = { title, stops = { stop, ... }, notes = { ... } }
--   CLASS is the client's class file token (PALADIN); side is "Alliance" or "Horde".
-- stop = {
--   key     slot on the class's painted strip (node position); race versions of one stop share it
--   kind    "road" or "side" (a side path: optional, ends in a dead end, still counts)
--   from    side paths only: the road stop it branches off
--   name    the stop's name (usually the chain's)
--   level   the level it opens at (the first quest's requiredLevel)
--   reward  what the chain gives, when a source confirms it; nil = not known (the UI says so)
--   quests  counted quests in order; a table entry { a, b } is "any one of" (exclusive versions)
--   extra   quests shown in the stop but not counted: lead-ins (breadcrumbs) and repeatable
--           sub-quests the game may never flag as done
--   order   "inferred" when QuestieDB doesn't link the quests and the order is by quest level
-- }
-- A stop whose quests are all ruled out for the character (another race's version) isn't shown.
local _, ns = ...

ns.ClassJourneyData = {
    source = "Curated from QuestieDB (qdb.lua class) and Warcraft Tavern's Forever guides, 2026-11-09",

    PALADIN = {
        Alliance = {
            title = "The Paladin's Road",
            stops = {
                -- Level 1: the trainer letter (Human) or rune (Dwarf).
                { key = "intro", kind = "road", name = "Consecrated Letter", level = 1,
                  reward = "Meet your first trainer", quests = { 3101 } },
                { key = "intro", kind = "road", name = "Consecrated Rune", level = 1,
                  reward = "Meet your first trainer", quests = { 3107 } },
                -- Level 12: Redemption. Human chain from Stormwind, Dwarf chain from Ironforge.
                { key = "divinity", kind = "road", name = "The Tome of Divinity", level = 12, reward = "Redemption",
                  quests = { 1642, 1643, 1644, 1780, 1781, 1786, 1787, 1788 },
                  extra = { 2998, 3681, 1641, 1790 } },
                { key = "divinity", kind = "road", name = "The Tome of Divinity", level = 12, reward = "Redemption",
                  quests = { 1646, 1647, 1648, 1778, 1779, 1783, 1784, 1785 },
                  extra = { 2997, 2999, 3000, 1645, 1789 } },
                -- Level 20: Verigan's Fist. 1442 and 1655 are 1654's sub-quests, flagged repeatable.
                { key = "valor", kind = "road", name = "The Tome of Valor", level = 20, reward = "Verigan's Fist",
                  quests = { 1649, 1650, 1651, 1652, 1653, 1654, 1806 },
                  extra = { 1793, 1794, 1442, 1655 } },
                -- Level 22: a newer chain (IDs 78088-78093); live in Forever is still an in-game check.
                { key = "artifact", kind = "side", from = "valor", name = "A Strange Artifact", level = 22,
                  quests = { 78088, 78089, 78090, 78091, 78092, 78093 }, order = "inferred" },
                -- Level 40: the warhorse, from any of three trainers.
                { key = "nobility", kind = "road", name = "The Tome of Nobility", level = 40, reward = "Summon Warhorse",
                  quests = { { 1661, 4485, 4486 } } },
                -- Level 50: Chillwind Point (8415) is the lead-in.
                { key = "mightstone", kind = "side", from = "nobility", name = "Forging the Mightstone", level = 50,
                  quests = { 8414, 8416, 8418 }, extra = { 8415 } },
                -- Level 60: the Charger. 7670 is the Ironforge start (exclusive with 7638); 7645 is
                -- 7643's sub-quest; 7666 is a repeatable second run.
                { key = "charger", kind = "road", name = "The Charger", level = 60, reward = "Summon Charger",
                  quests = { { 7638, 7670 }, 7637, 7639, 7640, 7641, 7642, 7648, 7643, 7644, 7646, 7647 },
                  extra = { 7645, 7666 } },
            },
        },

        Horde = {
            title = "The Forsaken Paladin's Road",
            notes = { "QuestieDB has no Horde Paladin class quests at levels 40 or 60 yet (Warcraft Tavern: the Horde mount is a long chain); the road ends at the Moonsilver Blade until it does." },
            stops = {
                -- Level 1: Deathknell, Tirisfal Glades.
                { key = "intro", kind = "road", name = "A Difficult Path", level = 1, quests = { 98601 } },
                -- Levels 2-4: Aramis Hammerhand, Deathknell. 91209 isn't linked; by level it follows 91208.
                { key = "light", kind = "road", name = "Rediscovering the Light", level = 2,
                  quests = { 90902, 91208, 91209 } },
                -- Levels 7-9: Bandarion Keep, Whispering Wood (Tirisfal).
                { key = "keep", kind = "road", name = "Bandarion Keep", level = 7,
                  quests = { 91285, 91294, 91316, 91317, 95803 } },
                { key = "home", kind = "side", from = "keep", name = "A Second Home", level = 8, quests = { 91282 } },
                -- Level 12: Redemption's Forsaken counterpart (reward not confirmed by a source).
                { key = "divinity", kind = "road", name = "A Lesson in Divinity", level = 12,
                  quests = { 94427, 94434, 94435, 94436, 94438, 94440, 94441 } },
                -- Level 18: Silverpine, Lumina Windsinger. Not linked in QuestieDB: order by level.
                { key = "incident", kind = "road", name = "Diplomatic Incident", level = 18,
                  quests = { 91858, 91859, 91860, 91861, 91862, 96204 }, order = "inferred" },
                -- Level 20: the Moonsilver Blade (the Horde Verigan's Fist?). Not linked: order by level.
                { key = "moonsilver", kind = "road", name = "The Moonsilver Blade", level = 20,
                  quests = { 95034, 95036, 95042, 95111, 95125, 95126, 95140 }, order = "inferred" },
            },
        },
    },
}
