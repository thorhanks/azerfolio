-- What each class wears and wields, for the Dungeons tab's "For you" loot filter (Phase 16,
-- spec §7.12, §8.13). Curated by hand (plan §8 provenance: curated, unofficial), owner-approved
-- in the Phase 16 plan (2026-11-15).
--
-- Source: Classic (1.12) class rules as the Warcraft Wiki's class pages and "Weapon skills" /
-- "Armor" pages describe them (curated 2026-11-15): Warriors and Paladins learn plate at 40,
-- Hunters and Shamans learn mail at 40; Classic Druids have no polearms (those came in TBC).
-- Forever may differ; the UI says "For you" is a guide and "All" shows every item.
--
-- Item subclasses are the client's (Enum.ItemWeaponSubclass / Enum.ItemArmorSubclass), the same
-- numbers QuestieDB stores per item [verified-files]:
--   weapons (item class 2)  0 axe, 1 two-hand axe, 2 bow, 3 gun, 4 mace, 5 two-hand mace,
--                           6 polearm, 7 sword, 8 two-hand sword, 10 staff, 13 fist weapon,
--                           15 dagger, 16 thrown, 18 crossbow, 19 wand (14 misc, 20 fishing pole: never "for you")
--   armour (item class 4)   0 jewellery, cloaks and other misc (every class), 1 cloth, 2 leather,
--                           3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem
--
-- Per class (keyed by the class file token, as UnitClass returns it):
--   armor    the armour type the class wants, by level: { { from = level, sub = subclass }, ... },
--            the last entry whose `from` is at most the level wins (the best type it can wear;
--            lighter types are left out of "For you")
--   shield   true when the class can use shields
--   relic    the relic subclass it uses (7 libram, 8 idol, 9 totem), nil for none
--   weapons  the weapon subclasses it can learn
local _, ns = ...

ns.ClassGearData = {
    source = "Classic class rules (Warcraft Wiki class, weapon skill and armour pages), curated 2026-11-15",
    classes = {
        WARRIOR = { armor = { { from = 1, sub = 3 }, { from = 40, sub = 4 } }, shield = true,
            weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 } },
        PALADIN = { armor = { { from = 1, sub = 3 }, { from = 40, sub = 4 } }, shield = true, relic = 7,
            weapons = { 0, 1, 4, 5, 6, 7, 8 } },
        HUNTER = { armor = { { from = 1, sub = 2 }, { from = 40, sub = 3 } },
            weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 } },
        SHAMAN = { armor = { { from = 1, sub = 2 }, { from = 40, sub = 3 } }, shield = true, relic = 9,
            weapons = { 0, 1, 4, 5, 10, 13, 15 } },
        ROGUE = { armor = { { from = 1, sub = 2 } },
            weapons = { 2, 3, 4, 7, 13, 15, 16, 18 } },
        DRUID = { armor = { { from = 1, sub = 2 } }, relic = 8,
            weapons = { 4, 5, 10, 13, 15 } },
        PRIEST = { armor = { { from = 1, sub = 1 } },
            weapons = { 4, 10, 15, 19 } },
        MAGE = { armor = { { from = 1, sub = 1 } },
            weapons = { 7, 10, 15, 19 } },
        WARLOCK = { armor = { { from = 1, sub = 1 } },
            weapons = { 7, 10, 15, 19 } },
    },
}
