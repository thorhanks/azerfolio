-- Profession facts the client doesn't give in one place (plan §8 provenance per field).
-- Keyed by skill line ID: GetProfessionInfo's 7th return. Lines 164, 185, 186, 129, 356 were
-- read on Gideon [verified-ingame, /azfdiag profs run 1]; the rest are the Classic-era IDs
-- [external: warcraft.wiki.gg SkillLine IDs], to confirm when a character has them.
-- kind: primary / secondary (C_SkillInfo category 11 / 9 [verified-ingame]); role: crafting,
-- gathering or both. noun: the rank title's second word ("Journeyman Blacksmith").
-- recipeSubclass: the recipe item subclass (item class 9) in QuestieDB [verified-files:
-- qdb.lua recipes]. A recipe item is "<Word>: <recipe name>" (Plans, Pattern, Recipe, Formula,
-- Schematic, Manual, Forever's Blueprint; Fishing's have none) [verified-files: qdb.lua gather check],
-- so the match is by the name after the colon and this subclass, not by a fixed prefix.
-- gather: the Data/Gathering.lua table that applies.
local _, ns = ...

ns.ProfessionData = {
    -- Every profession tops out at 300 on Forever (Warcraft Tavern's Forever professions guide,
    -- 2026-11-13; owner decision 2026-11-13): "Mastered" at this skill.
    maxSkill = 300,

    -- Ranks: the cap each gives and the skill its training needs. The gates (50, 125, 200)
    -- match Gideon's trainers (Journeyman at 50) [verified-ingame]; the caps are Warcraft
    -- Tavern's [external]. Level requirements aren't kept: the trainer reports 0.
    ranks = {
        { name = "Apprentice", cap = 75, at = 1 },
        { name = "Journeyman", cap = 150, at = 50 },
        { name = "Expert", cap = 225, at = 125 },
        { name = "Artisan", cap = 300, at = 200 },
    },

    -- The profession window's category for Season of Discovery recipes (58 in Blacksmithing):
    -- listed by the client, not known to be obtainable on Forever, so never counted
    -- [verified-ingame, run 6: GetCategoryInfo(2593) = "SEASON OF DISCOVERY"].
    seasonCategories = { [2593] = true },

    skills = {
        [171] = { key = "alchemy", name = "Alchemy", kind = "primary", role = "crafting", noun = "Alchemist",
                  recipeSubclass = 6 },
        [164] = { key = "blacksmithing", name = "Blacksmithing", kind = "primary", role = "crafting", noun = "Blacksmith",
                  recipeSubclass = 4 },
        [333] = { key = "enchanting", name = "Enchanting", kind = "primary", role = "crafting", noun = "Enchanter",
                  recipeSubclass = 8 },
        [202] = { key = "engineering", name = "Engineering", kind = "primary", role = "crafting", noun = "Engineer",
                  recipeSubclass = 3 },
        [182] = { key = "herbalism", name = "Herbalism", kind = "primary", role = "gathering", noun = "Herbalist",
                  gather = "herbalism" },
        [165] = { key = "leatherworking", name = "Leatherworking", kind = "primary", role = "crafting", noun = "Leatherworker",
                  recipeSubclass = 1 },
        [186] = { key = "mining", name = "Mining", kind = "primary", role = "both", noun = "Miner",
                  gather = "mining" },
        [393] = { key = "skinning", name = "Skinning", kind = "primary", role = "gathering", noun = "Skinner",
                  gather = "skinning" },
        [197] = { key = "tailoring", name = "Tailoring", kind = "primary", role = "crafting", noun = "Tailor",
                  recipeSubclass = 2 },
        [185] = { key = "cooking", name = "Cooking", kind = "secondary", role = "crafting", noun = "Cook",
                  recipeSubclass = 5 },
        [129] = { key = "firstaid", name = "First Aid", kind = "secondary", role = "crafting", noun = "First Aid",
                  recipeSubclass = 7 },
        [356] = { key = "fishing", name = "Fishing", kind = "secondary", role = "gathering", noun = "Fisherman",
                  recipeSubclass = 9, gather = "fishing" },
    },

    -- Rail order: primary first, then secondary, each alphabetical (mockups/DESIGN.md).
}
