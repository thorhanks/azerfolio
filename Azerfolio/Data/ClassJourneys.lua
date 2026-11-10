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
--   routes  instead of quests: alternative ways through the stop, each a quests list; the stop is
--           done when any one route is (e.g. a home city's weapon chain, the two Succubus routes)
--   extra   quests shown in the stop but not counted: lead-ins (breadcrumbs) and repeatable
--           sub-quests the game may never flag as done
--   order   "inferred" when QuestieDB doesn't link the quests and the order is by quest level
--   raceMask  only for characters whose race bit is in it (QuestieDB's race bits). Used where
--           QuestieDB leaves a quest open to every race but it can only be reached by one race
--           (the Skyborne class intros on Zephras Isle, behind 92461)
-- }
-- ClassJourneyData[CLASS].ignore[questID] = reason: class-sort quests left off on purpose.
-- A stop whose quests are all ruled out for the character (another race's version) isn't shown.
local _, ns = ...

-- Skyborne race bits (Alliance 2^32, Horde 2^33) [inferred from QuestieDB's side masks].
local SKYBORNE = 2 ^ 32 + 2 ^ 33

ns.ClassJourneyData = {
    source = "Curated from QuestieDB (qdb.lua class) and Warcraft Tavern's Forever guides, 2026-11-09",

    WARRIOR = {
        Alliance = {
            title = "The Warrior's Road",
            stops = {
                { key = "intro", kind = "road", name = "Simple Letter", level = 1, quests = { 3100 } },
                { key = "intro", kind = "road", name = "Simple Rune", level = 1, quests = { 3106 } },
                { key = "intro", kind = "road", name = "Simple Memorandum", level = 1, quests = { 3112 } },
                { key = "intro", kind = "road", name = "Simple Sigil", level = 1, quests = { 3116 } },
                { key = "intro", kind = "road", name = "The Warrior's Path", level = 2, quests = { 92532 }, raceMask = SKYBORNE },
                -- Level 10: Defensive Stance. One home city's chain is enough.
                { key = "stance", kind = "road", name = "Defensive Stance", level = 10, reward = "Defensive Stance",
                  routes = { { 1639, 1640, 1665, 1666, 1667, name = "Stormwind" }, { 1678, 1680, 1681, 1682, name = "Ironforge" },
                      { 1683, 1686, 1692, 1693, name = "Darnassus" }, { 94003, name = "Zephras Isle" } },
                  extra = { 1638, 1679, 1684 } },
                -- Level 20: the Shieldsmith, then three armour chains in three cities.
                { key = "shieldsmith", kind = "road", name = "The Shieldsmith", level = 20,
                  quests = { 1699, 1702, 1701, 1782 }, extra = { 1698 } },
                { key = "grimand", kind = "side", from = "shieldsmith", name = "Grimand's Armor", level = 20,
                  quests = { 1705, 1706 }, extra = { 1700 } },
                { key = "klockmort", kind = "side", from = "shieldsmith", name = "Klockmort's Creation", level = 20,
                  quests = { 1708, 1709 }, extra = { 1704 } },
                { key = "mathiel", kind = "side", from = "shieldsmith", name = "Mathiel's Armor", level = 20,
                  quests = { 1710, 1711 }, extra = { 1703 } },
                -- Level 30: Berserker Stance, then the Whirlwind weapon.
                { key = "berserker", kind = "road", name = "The Affray", level = 30, reward = "Berserker Stance",
                  quests = { 1718, 1719 } },
                { key = "whirlwind", kind = "road", name = "Whirlwind Weapon", level = 30,
                  quests = { 1791, 1712, 1713, 1792 }, extra = { 1714 } },
                -- Level 50: the Fallen Hero in the Swamp of Sorrows.
                { key = "kinship", kind = "road", name = "Voodoo Feathers", level = 50,
                  quests = { 8417, 8423, 8424, 8425 } },
            },
        },
        Horde = {
            title = "The Warrior's Road",
            stops = {
                { key = "intro", kind = "road", name = "Simple Parchment", level = 1, quests = { 2383 } },
                { key = "intro", kind = "road", name = "Simple Tablet", level = 1, quests = { 3065 } },
                { key = "intro", kind = "road", name = "Simple Note", level = 1, quests = { 3091 } },
                { key = "intro", kind = "road", name = "Simple Scroll", level = 1, quests = { 3095 } },
                { key = "intro", kind = "road", name = "The Warrior's Path", level = 2, quests = { 92532 }, raceMask = SKYBORNE },
                { key = "stance", kind = "road", name = "Defensive Stance", level = 10, reward = "Defensive Stance",
                  routes = { { 1498, 1502, 1503, name = "The Barrens" }, { 1819, 1820, 1821, 1822, name = "Tirisfal Glades" },
                      { 94003, name = "Zephras Isle" } }, extra = { 1505, 1818 } },
                -- Level 20: the Field of Giants, then three Brutal pieces from three trainers.
                { key = "giants", kind = "road", name = "Trial at the Field of Giants", level = 20,
                  quests = { 1824, 1838, 1848 }, extra = { 1823, 1825 } },
                { key = "gauntlets", kind = "side", from = "giants", name = "Brutal Gauntlets", level = 20,
                  quests = { 1842, 1843 }, extra = { 1839 } },
                { key = "helm", kind = "side", from = "giants", name = "Brutal Helm", level = 20,
                  quests = { 1844, 1845 }, extra = { 1840 } },
                { key = "legguards", kind = "side", from = "giants", name = "Brutal Legguards", level = 20,
                  quests = { 1846, 1847 }, extra = { 1841 } },
                { key = "berserker", kind = "road", name = "The Affray", level = 30, reward = "Berserker Stance",
                  quests = { 1718, 1719 } },
                { key = "whirlwind", kind = "road", name = "Whirlwind Weapon", level = 30,
                  quests = { 1791, 1712, 1713, 1792 }, extra = { 1714 } },
                { key = "kinship", kind = "road", name = "Voodoo Feathers", level = 50,
                  quests = { 8417, 8423, 8424, 8425 } },
            },
        },
    },

    PRIEST = {
        ignore = { [5691] = "not implemented (<NYI>)", [5692] = "not implemented (<NYI>)", [5693] = "not implemented (<NYI>)",
            [5704] = "not implemented (<NYI>)", [5705] = "not implemented (<NYI>)", [5706] = "not implemented (<NYI>)" },
        Alliance = {
            title = "The Priest's Road",
            stops = {
                { key = "intro", kind = "road", name = "Hallowed Letter", level = 1, quests = { 3103 } },
                { key = "intro", kind = "road", name = "Hallowed Rune", level = 1, quests = { 3110 } },
                { key = "intro", kind = "road", name = "Hallowed Sigil", level = 1, quests = { 3119 } },
                { key = "intro", kind = "road", name = "Hallowed Memorandum", level = 1, quests = { 98574 } },
                -- Level 5: the first robe, per race.
                { key = "garments", kind = "road", name = "Garments of the Light", level = 5, quests = { 5624 }, extra = { 5623 } },
                { key = "garments", kind = "road", name = "Garments of the Light", level = 5, quests = { 5625 }, extra = { 5626 } },
                { key = "garments", kind = "road", name = "Garments of the Moon", level = 5, quests = { 5621 }, extra = { 5622 } },
                -- Level 10: the racial spell (from any trainer), and Forever's Divine Grace for Humans.
                { key = "spell10", kind = "road", name = "Desperate Prayer", level = 10, reward = "Desperate Prayer",
                  quests = { { 5634, 5635, 5636, 5637, 5638, 5639, 5640 } } },
                { key = "spell10", kind = "road", name = "Stars of Elune", level = 10, reward = "Starshards",
                  quests = { 5627 }, extra = { 5628, 5629, 5630, 5631, 5632, 5633 } },
                { key = "spell10", kind = "road", name = "Confounding Flash", level = 10,
                  quests = { { 94817, 94821, 94822, 94823, 94824, 94825, 94826 } } },
                { key = "grace", kind = "road", name = "Divine Grace", level = 10,
                  quests = { { 94773, 94774, 94775, 94776, 94777, 94778, 94779 } } },
                -- Level 20: the second racial spell.
                { key = "spell20", kind = "road", name = "A Lack of Fear", level = 20, reward = "Fear Ward",
                  quests = { { 5641, 5645, 5647 } } },
                { key = "spell20", kind = "road", name = "Elune's Grace", level = 20, reward = "Elune's Grace",
                  quests = { { 5672, 5673, 5674, 5675 } } },
                { key = "spell20", kind = "road", name = "Arcane Feedback", level = 20, reward = "Feedback",
                  quests = { { 5676, 5677, 5678 } } },
                { key = "spell20", kind = "road", name = "Contingency Plan", level = 20,
                  quests = { { 94818, 94819, 94820 } } },
                { key = "morphaz", kind = "road", name = "Blood of Morphaz", level = 50, quests = { 8254, 8255, 8256, 8257 } },
                -- Level 60: Eris Havenfire (Eastern Plaguelands); A Warning is the lead-in.
                { key = "eris", kind = "road", name = "The Balance of Light and Shadow", level = 60,
                  quests = { 7622 }, extra = { 7621 } },
            },
        },
        Horde = {
            title = "The Priest's Road",
            stops = {
                { key = "intro", kind = "road", name = "Hallowed Tablet", level = 1, quests = { 3085 } },
                { key = "intro", kind = "road", name = "Hallowed Scroll", level = 1, quests = { 3097 } },
                { key = "garments", kind = "road", name = "Garments of Spirituality", level = 5, quests = { 5648 }, extra = { 5649 } },
                { key = "garments", kind = "road", name = "Garments of Darkness", level = 5, quests = { 5650 }, extra = { 5651 } },
                { key = "spell10", kind = "road", name = "Hex of Weakness", level = 10, reward = "Hex of Weakness",
                  quests = { { 5652, 5654, 5655, 5656, 5657 } } },
                { key = "spell10", kind = "road", name = "Touch of Weakness", level = 10, reward = "Touch of Weakness",
                  quests = { { 5658, 5660, 5661, 5662, 5663 } } },
                { key = "spell20", kind = "road", name = "Shadowguard", level = 20, reward = "Shadowguard",
                  quests = { { 5642, 5643, 5680 } } },
                { key = "spell20", kind = "road", name = "Dark Sacrifice", level = 20, reward = "Devouring Plague",
                  quests = { { 5644, 5646, 5679 } } },
                { key = "morphaz", kind = "road", name = "Blood of Morphaz", level = 50, quests = { 8254, 8255, 8256, 8257 } },
                { key = "eris", kind = "road", name = "The Balance of Light and Shadow", level = 60,
                  quests = { 7622 }, extra = { 7621 } },
            },
        },
    },

    MAGE = {
        ignore = { [97286] = "needs 40 Season of Discovery quests (78124 and up) first",
            [7463] = "starts in Dire Maul (Lorekeeper Lydros): for the Dungeons tab" },
        Alliance = {
            title = "The Mage's Road",
            stops = {
                { key = "intro", kind = "road", name = "Glyphic Letter", level = 1, quests = { 3104 } },
                { key = "intro", kind = "road", name = "Glyphic Memorandum", level = 1, quests = { 3114 } },
                { key = "intro", kind = "road", name = "A Student of the Arcane", level = 2, quests = { 92481 }, raceMask = SKYBORNE },
                { key = "ten", kind = "road", name = "First Errand", level = 10,
                  routes = { { 1861, name = "Mirror Lake" }, { 1880, name = "Mage-tastic Gizmonitor" }, { 93791, name = "Speak with Belann" } },
                  extra = { 1860, 1879 } },
                { key = "robe15", kind = "road", name = "Manaweave Robe", level = 15, quests = { 1920, 1921, 1941 }, extra = { 1919 } },
                { key = "robe26", kind = "road", name = "Astral Knot Garment", level = 26, quests = { 1938, 1940, 1942 }, extra = { 1939 } },
                { key = "wand", kind = "road", name = "Mage's Wand", level = 30, quests = { 1947, 1949, 1950, 1951, 1948, 1952 } },
                { key = "orb", kind = "road", name = "Celestial Power", level = 35, quests = { 1954, 1955, 1956, 1957, 1958 }, extra = { 1953 } },
                { key = "morphaz", kind = "road", name = "Destroy Morphaz", level = 50, quests = { 8251, 8252, 8253 }, extra = { 8250 } },
                { key = "krellian", kind = "road", name = "Fragmented Magic", level = 60, quests = { 9362, 9364 } },
            },
        },
        Horde = {
            title = "The Mage's Road",
            stops = {
                { key = "intro", kind = "road", name = "Glyphic Tablet", level = 1, quests = { 3086 } },
                { key = "intro", kind = "road", name = "Glyphic Scroll", level = 1, quests = { 3098 } },
                { key = "intro", kind = "road", name = "Glyphic Parchment", level = 1, quests = { 98576 } },
                { key = "ten", kind = "road", name = "First Errand", level = 10,
                  routes = { { 1882, name = "The Balnir Farmstead" }, { 1884, name = "Ju-Ju Heaps" } }, extra = { 1881, 1883 } },
                { key = "robe15", kind = "road", name = "Spellfire Robes", level = 15, quests = { 1960, 1961, 1962 }, extra = { 1959 } },
                { key = "robe26", kind = "road", name = "Nether-lace Garment", level = 26, quests = { 1944, 1945, 1946 }, extra = { 1943 } },
                { key = "wand", kind = "road", name = "Mage's Wand", level = 30, quests = { 1947, 1949, 1950, 1951, 1948, 1952 } },
                { key = "orb", kind = "road", name = "Celestial Power", level = 35, quests = { 1954, 1955, 1956, 1957, 1958 }, extra = { 1953 } },
                { key = "morphaz", kind = "road", name = "Destroy Morphaz", level = 50, quests = { 8251, 8252, 8253 }, extra = { 8250 } },
                { key = "krellian", kind = "road", name = "Fragmented Magic", level = 60, quests = { 9362, 9364 } },
            },
        },
    },

    WARLOCK = {
        Alliance = {
            title = "The Warlock's Road",
            stops = {
                { key = "intro", kind = "road", name = "Tainted Letter", level = 1, quests = { 3105 } },
                { key = "intro", kind = "road", name = "Tainted Memorandum", level = 1, quests = { 3115 } },
                { key = "imp", kind = "road", name = "First Lessons", level = 1,
                  routes = { { 1598, name = "The Stolen Tome" }, { 1599, name = "Beginnings" } } },
                { key = "void", kind = "road", name = "Summon Voidwalker", level = 10, reward = "Summon Voidwalker",
                  quests = { { 1688, 1715 }, 1689 }, extra = { 1685 } },
                -- Level 20: two routes to the Succubus (the 1.12 chain, or Classic Era's 65602).
                { key = "succubus", kind = "road", name = "Summon Succubus", level = 20, reward = "Summon Succubus",
                  routes = { { { 1716, 1717 }, 1738, 1739 }, { { 1716, 1717 }, 65602, 65603 } } },
                { key = "soranruk", kind = "side", from = "succubus", name = "The Orb of Soran'ruk", level = 20, quests = { 1740 } },
                { key = "felhunter", kind = "road", name = "Summon Felhunter", level = 30, reward = "Summon Felhunter",
                  quests = { 1758, 1802, 1804, 1795 }, extra = { 1798 } },
                { key = "robe", kind = "side", from = "felhunter", name = "The Completed Robe", level = 31,
                  quests = { 1796, 4781, 4782, 4783, 4784, 4786 }, extra = { 4736, 4738, 4785 } },
                { key = "orahil", kind = "side", from = "felhunter", name = "The Orb of Orahil", level = 35,
                  quests = { 1799, { 4962, 4963 }, 4961, 4976, { 4964, 4975 } }, extra = { 4965, 4968 } },
                { key = "felsteed", kind = "road", name = "Summon Felsteed", level = 40, reward = "Summon Felsteed",
                  quests = { { 4487, 4488 }, 4490 } },
                { key = "imps", kind = "road", name = "Trolls of a Feather", level = 50, quests = { { 8419, 8420 }, 8421, 8422 } },
                { key = "kroshius", kind = "side", from = "imps", name = "Kroshius' Infernal Core", level = 50, quests = { 7601, 7602, 7603 } },
                { key = "dreadsteed", kind = "road", name = "Dreadsteed of Xoroth", level = 60, reward = "Summon Dreadsteed",
                  quests = { 7563, 7564, 7626, 7627, 7628, 7623, 7624, 7625, 7629, 7630, 7631 }, extra = { 7562 } },
                { key = "suppression", kind = "side", from = "dreadsteed", name = "Suppression", level = 60, quests = { 7581, 7582, 7583 } },
            },
        },
        Horde = {
            title = "The Warlock's Road",
            stops = {
                { key = "intro", kind = "road", name = "Tainted Parchment", level = 1, quests = { 3090 } },
                { key = "intro", kind = "road", name = "Tainted Scroll", level = 1, quests = { 3099 } },
                { key = "intro", kind = "road", name = "Tainted Tablet", level = 1, quests = { 98575 } },
                { key = "imp", kind = "road", name = "First Lessons", level = 1,
                  routes = { { 1470, name = "Piercing the Veil" }, { 1485, 1499, name = "Vile Familiars" } } },
                { key = "void", kind = "road", name = "Summon Voidwalker", level = 10, reward = "Summon Voidwalker",
                  quests = { 1473, 1471 }, extra = { 1478 } },
                { key = "void", kind = "road", name = "Summon Voidwalker", level = 10, reward = "Summon Voidwalker",
                  quests = { 1501, 1504 }, extra = { 1506 } },
                { key = "succubus", kind = "road", name = "Summon Succubus", level = 20, reward = "Summon Succubus",
                  routes = { { 1472, 1476, 1474, name = "Hearts of the Pure" }, { 1472, 65593, 65597, name = "Hearts of the Lovers" },
                      { 1507, 1508, 1509, 1510, 1511, 1515, 1512, 1513, name = "Love's Gift" },
                      { 1507, 65601, 65610, 65604, name = "Love Hurts" } } },
                { key = "soranruk", kind = "side", from = "succubus", name = "The Orb of Soran'ruk", level = 20, quests = { 1740 } },
                { key = "felhunter", kind = "road", name = "Summon Felhunter", level = 30, reward = "Summon Felhunter",
                  quests = { 1801, 1803, 1805, 1795 }, extra = { 2996, 3001 } },
                { key = "robe", kind = "side", from = "felhunter", name = "The Completed Robe", level = 31,
                  quests = { 1796, 4781, 4782, 4783, 4784, 4786 }, extra = { 4737, 4739, 4785 } },
                { key = "orahil", kind = "side", from = "felhunter", name = "The Orb of Orahil", level = 35,
                  quests = { 1799, { 4962, 4963 }, 4961, 4976, { 4964, 4975 } }, extra = { 4967, 4969 } },
                { key = "felsteed", kind = "road", name = "Summon Felsteed", level = 40, reward = "Summon Felsteed",
                  quests = { { 3631, 4489 }, 4490 } },
                { key = "imps", kind = "road", name = "Trolls of a Feather", level = 50, quests = { { 8419, 8420 }, 8421, 8422 } },
                { key = "kroshius", kind = "side", from = "imps", name = "Kroshius' Infernal Core", level = 50, quests = { 7601, 7602, 7603 } },
                { key = "dreadsteed", kind = "road", name = "Dreadsteed of Xoroth", level = 60, reward = "Summon Dreadsteed",
                  quests = { 7563, 7564, 7626, 7627, 7628, 7623, 7624, 7625, 7629, 7630, 7631 }, extra = { 7562 } },
                { key = "suppression", kind = "side", from = "dreadsteed", name = "Suppression", level = 60, quests = { 7581, 7582, 7583 } },
            },
        },
    },

    HUNTER = {
        ignore = { [7632] = "Rhok'delar starts from a Molten Core drop: for the Dungeons tab",
            [7633] = "Rhok'delar (Molten Core): for the Dungeons tab", [7634] = "Rhok'delar (Molten Core): for the Dungeons tab",
            [7635] = "Rhok'delar (Molten Core): for the Dungeons tab", [7636] = "Rhok'delar (Molten Core): for the Dungeons tab" },
        Alliance = {
            title = "The Hunter's Road",
            stops = {
                { key = "intro", kind = "road", name = "Etched Rune", level = 1, quests = { 3108 } },
                { key = "intro", kind = "road", name = "Etched Sigil", level = 1, quests = { 3117 } },
                -- 92479 is filed under the Warrior sort in QuestieDB, but it's the Human hunter's letter.
                { key = "intro", kind = "road", name = "A Scribbled Letter", level = 1, quests = { 92479 } },
                { key = "intro", kind = "road", name = "The Way of the Hunter", level = 2, quests = { 92482 }, raceMask = SKYBORNE },
                -- Level 10: taming a pet, per starting area.
                { key = "pet", kind = "road", name = "Taming the Beast", level = 10, reward = "Tame Beast",
                  routes = { { 6063, 6101, 6102, 6103, name = "Teldrassil" }, { 6064, 6084, 6085, 6086, name = "Dun Morogh" },
                      { 94792, 94863, 94864, 94793, name = "Elwynn Forest" }, { 94978, 94979, 94013, 94050, name = "Zephras Isle" } },
                  extra = { 6071, 6072, 6073, 6074, 6075, 6076, 94007 } },
                { key = "charm", kind = "road", name = "The Green Drake", level = 50, quests = { 8151, 8153, 8231, 8232 } },
            },
        },
        Horde = {
            title = "The Hunter's Road",
            stops = {
                { key = "intro", kind = "road", name = "Etched Tablet", level = 1, quests = { 3082 } },
                { key = "intro", kind = "road", name = "Etched Parchment", level = 1, quests = { 3087 } },
                { key = "intro", kind = "road", name = "Etched Note", level = 1, quests = { 3092 } },
                { key = "intro", kind = "road", name = "The Way of the Hunter", level = 2, quests = { 92482 }, raceMask = SKYBORNE },
                { key = "pet", kind = "road", name = "Taming the Beast", level = 10, reward = "Tame Beast",
                  quests = { 6061, 6087, 6088, 6089 }, extra = { 6065, 6066, 6067 } },
                { key = "pet", kind = "road", name = "Taming the Beast", level = 10, reward = "Tame Beast",
                  quests = { 6062, 6083, 6082, 6081 }, extra = { 6068, 6069, 6070 } },
                { key = "pet", kind = "road", name = "Taming the Beast", level = 10, reward = "Tame Beast",
                  quests = { 94978, 94979, 94013, 94050 }, extra = { 94007 } },
                { key = "charm", kind = "road", name = "The Green Drake", level = 50, quests = { 8151, 8153, 8231, 8232 } },
            },
        },
    },

    ROGUE = {
        Alliance = {
            title = "The Rogue's Road",
            stops = {
                { key = "intro", kind = "road", name = "Encrypted Letter", level = 1, quests = { 3102 } },
                { key = "intro", kind = "road", name = "Encrypted Rune", level = 1, quests = { 3109 } },
                { key = "intro", kind = "road", name = "Encrypted Memorandum", level = 1, quests = { 3113 } },
                { key = "intro", kind = "road", name = "Encrypted Sigil", level = 1, quests = { 3118 } },
                { key = "intro", kind = "road", name = "At Home in the Shadows", level = 2, quests = { 92483 }, raceMask = SKYBORNE },
                { key = "ten", kind = "road", name = "Thieves' Errand", level = 10,
                  routes = { { 2206, name = "Snatch and Grab" }, { 2218, 2238, 2239, name = "Onin's Report" }, { 2241, 2242, name = "Destiny Calls" } },
                  extra = { 2205 } },
                { key = "sixteen", kind = "road", name = "Lockpicking Trial", level = 16,
                  routes = { { 2281, 2282, name = "Alther's Mill" }, { 2298, name = "Kingly Shakedown" }, { 2260, 2358, name = "Horns of Nez'ra" } },
                  extra = { 2300, 2299, 2259 } },
                { key = "zanzil", kind = "road", name = "The Touch of Zanzil", level = 20, quests = { 2360, 2359, 2607, 2608, 2609 } },
                { key = "ravenholdt", kind = "road", name = "The Manor, Ravenholdt", level = 24, quests = { 6681 }, extra = { 6701 } },
                -- Forever's Syndicate chain (Myrokos Silentform, Alterac Mountains): not linked, ordered by level.
                { key = "syndicate", kind = "road", name = "The Syndicate Sting", level = 24,
                  quests = { 96779, 96783, 96785, 96786, 96781, 96782 }, order = "inferred" },
                { key = "bhossca", kind = "side", from = "syndicate", name = "The Eye of Bhossca", level = 25,
                  quests = { 78676, 78699 }, order = "inferred" },
                { key = "azure", kind = "road", name = "The Azure Key", level = 50, quests = { 8234, 8235, 8236 }, extra = { 8233 } },
            },
        },
        Horde = {
            title = "The Rogue's Road",
            stops = {
                { key = "intro", kind = "road", name = "Encrypted Tablet", level = 1, quests = { 3083 } },
                { key = "intro", kind = "road", name = "Encrypted Parchment", level = 1, quests = { 3088 } },
                { key = "intro", kind = "road", name = "Encrypted Scroll", level = 1, quests = { 3096 } },
                { key = "intro", kind = "road", name = "At Home in the Shadows", level = 2, quests = { 92483 }, raceMask = SKYBORNE },
                { key = "ten", kind = "road", name = "The Shattered Hand", level = 10, quests = { 1963, 1858 }, extra = { 1859 } },
                { key = "ten", kind = "road", name = "The Deathstalkers", level = 10, quests = { 1886, 1898, 1899, 1978 }, extra = { 1885 } },
                { key = "sixteen", kind = "road", name = "Lockpicking Trial", level = 16,
                  routes = { { 1999, name = "Tools of the Trade" }, { 2379, 2382, 2381, name = "Plundering the Plunderers" } },
                  extra = { 1998, 2378, 2380 } },
                { key = "zanzil", kind = "road", name = "Hinott's Assistance", level = 20, quests = { 2460, 2458, 2478, 2479, 2480 } },
                { key = "ravenholdt", kind = "road", name = "The Manor, Ravenholdt", level = 24, quests = { 6681 }, extra = { 6701 } },
                { key = "syndicate", kind = "road", name = "The Syndicate Sting", level = 24,
                  quests = { 96779, 96783, 96784, 96785, 96786, 96781, 96782 }, order = "inferred" },
                { key = "bhossca", kind = "side", from = "syndicate", name = "The Eye of Bhossca", level = 25,
                  quests = { 78676, 78699 }, order = "inferred" },
                { key = "azure", kind = "road", name = "The Azure Key", level = 50, quests = { 8234, 8235, 8236 }, extra = { 8233 } },
            },
        },
    },

    DRUID = {
        Alliance = {
            title = "The Druid's Road",
            stops = {
                { key = "intro", kind = "road", name = "Verdant Sigil", level = 1, quests = { 3120 } },
                { key = "intro", kind = "road", name = "A Student of Nature", level = 2, quests = { 92485 }, raceMask = SKYBORNE },
                { key = "bear", kind = "road", name = "Body and Heart", level = 10, reward = "Bear Form",
                  quests = { 5921, 5929, 5931, 6001 }, extra = { 5923, 5924, 5925 } },
                { key = "bear", kind = "road", name = "Strength and Mercy", level = 10, reward = "Bear Form",
                  quests = { 94006, 94638 } },
                { key = "nature", kind = "side", from = "bear", name = "Child of Nature", level = 10,
                  quests = { 94912, 94914 }, order = "inferred" },
                { key = "poison", kind = "road", name = "Power over Poison", level = 14, reward = "Cure Poison",
                  quests = { 6121, 6122, 6123, 6124, 6125 } },
                { key = "aquatic", kind = "road", name = "Aquatic Form", level = 16, reward = "Aquatic Form",
                  quests = { 26, 29, 272, 5061 } },
                { key = "cat", kind = "road", name = "The Great Cat Spirit", level = 20, reward = "Cat Form",
                  routes = { { 98393, 98394, 98396, 98731, 98397, name = "Darnassus" },
                      { 98341, 98404, 98738, name = "The Great Windborne Cat Spirit" } }, order = "inferred" },
                { key = "torwa", kind = "road", name = "A Better Ingredient", level = 50, quests = { 9052, 9051, 9053 }, extra = { 9063 } },
            },
        },
        Horde = {
            title = "The Druid's Road",
            stops = {
                { key = "intro", kind = "road", name = "Verdant Note", level = 1, quests = { 3094 } },
                { key = "intro", kind = "road", name = "A Student of Nature", level = 2, quests = { 92485 }, raceMask = SKYBORNE },
                { key = "bear", kind = "road", name = "Body and Heart", level = 10, reward = "Bear Form",
                  quests = { 5922, 5930, 5932, 6002 }, extra = { 5926, 5927, 5928 } },
                { key = "bear", kind = "road", name = "Strength and Mercy", level = 10, reward = "Bear Form",
                  quests = { 94006, 94638 } },
                { key = "nature", kind = "side", from = "bear", name = "Child of Nature", level = 10,
                  quests = { 94911, 94913 }, order = "inferred" },
                { key = "poison", kind = "road", name = "Power over Poison", level = 14, reward = "Cure Poison",
                  quests = { 6126, 6127, 6128, 6129, 6130 } },
                { key = "aquatic", kind = "road", name = "Aquatic Form", level = 16, reward = "Aquatic Form",
                  quests = { 27, 28, 30, 31 } },
                { key = "cat", kind = "road", name = "The Great Cat Spirit", level = 20, reward = "Cat Form",
                  routes = { { 98340, 98405, 98342, 98739, 98362, name = "Thunder Bluff" },
                      { 98341, 98404, 98738, name = "The Great Windborne Cat Spirit" } }, order = "inferred" },
                { key = "torwa", kind = "road", name = "A Better Ingredient", level = 50, quests = { 9052, 9051, 9053 }, extra = { 9063 } },
            },
        },
    },

    SHAMAN = {
        Alliance = {
            title = "The Shaman's Road",
            stops = {
                { key = "intro", kind = "road", name = "Archaic Rune", level = 1, quests = { 98581 } },
                { key = "earth", kind = "road", name = "Call of Earth", level = 4, reward = "Earth Totem",
                  quests = { 94373, 94374, 94375 }, extra = { 94472, 96243 } },
                { key = "fire", kind = "road", name = "Call of Fire", level = 10, reward = "Fire Totem",
                  quests = { 94465, 94466, 94467, 94468 }, extra = { 94449, 94473 } },
                { key = "water", kind = "road", name = "Call of Water", level = 20, reward = "Water Totem",
                  quests = { 94495, 94497, 94499, 94500, 94501, 94502, 94503, 94505 }, extra = { 94494, 94616 }, order = "inferred" },
                { key = "air", kind = "road", name = "Call of Air", level = 30, reward = "Air Totem", quests = { 94789 } },
                { key = "tempest", kind = "road", name = "The Tempest's Weapons", level = 30,
                  quests = { 96264, 79358, 96135, 96016 }, order = "inferred" },
            },
        },
        Horde = {
            title = "The Shaman's Road",
            stops = {
                { key = "intro", kind = "road", name = "Rune-Inscribed Tablet", level = 1, quests = { 3084 } },
                { key = "intro", kind = "road", name = "Rune-Inscribed Parchment", level = 1, quests = { 3089 } },
                { key = "intro", kind = "road", name = "Rune-Inscribed Note", level = 1, quests = { 3093 } },
                { key = "intro", kind = "road", name = "Embracing the Elements", level = 2, quests = { 92484 }, raceMask = SKYBORNE },
                -- Each step: the Durotar, Mulgore or Zephras Isle version.
                { key = "earth", kind = "road", name = "Call of Earth", level = 4, reward = "Earth Totem",
                  quests = { { 1516, 1519, 92466 }, { 1517, 1520, 92467 }, { 1518, 1521, 92468 } }, extra = { 1462, 1463 } },
                { key = "fire", kind = "road", name = "Call of Fire", level = 10, reward = "Fire Totem",
                  quests = { { 1524, 97243 }, { 1525, 97244 }, { 1526, 97245 }, { 1527, 97257 } },
                  extra = { 1522, 1523, 2983, 2984, 1464 } },
                { key = "water", kind = "road", name = "Call of Water", level = 20, reward = "Water Totem",
                  quests = { 1530, 1535, 1536, 1534, 220, 63, 100, 96 }, extra = { 1528, 1529, 2985, 2986, 972, 1103 } },
                { key = "air", kind = "road", name = "Call of Air", level = 30, reward = "Air Totem", quests = { { 1531, 1532, 96136 } } },
                { key = "tempest", kind = "road", name = "The Tempest's Weapons", level = 30,
                  quests = { 79360, 79364, { 79358, 79361 }, 79366, 79442 }, order = "inferred" },
                { key = "mastery", kind = "road", name = "Da Voodoo", level = 50, quests = { { 8410, 8411 }, 8412, 8413 } },
                { key = "darkreaver", kind = "road", name = "The Darkreaver Menace", level = 58,
                  quests = { 7667, { 7668, 8258 } }, extra = { 7669 } },
            },
        },
    },

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
