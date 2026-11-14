# Professions — research (2026-11-13)

For the Professions tab (spec §10 later: "recipes: known vs. available, where to get them"). Evidence levels as in plan §2.2. Offline numbers: `luajit tools/qdb.lua recipes [areaID]` and `luajit tools/qdb.lua profs [profession]` (QuestieDB base rows, no corrections). In-game probe: `/azfdiag profs`, report `luajit tools/diag-report.lua profs [run]`.

## Summary

- **Skill ranks:** the client has the modern profession APIs on a "Camelot" layer: `GetProfessions` / `GetProfessionInfo` (name, rank, maxRank, skillLine, specialization), `C_TradeSkillUI.GetProfessionInfoBySkillLineID`, `C_SkillInfo.GetSkillLineInfo` (rank, maxRank, category, parent). [verified-ingame: the functions exist (env dump); external: the Forever profession book calls them, `Gethe/wow-ui-source` branch `forever`, `Blizzard_ProfessionsBook/Camelot`]. Values not yet read on our characters.
- **Known recipes with the window shut:** ItemTree's notes say `IsPlayerSpell(recipeSpellID)` and `C_SpellBook.IsSpellKnown` answer a recipe's learnt state at any time on Forever (1.60.1.70124) [external, another addon's in-game note]. Needs our own check. If it holds, known state is cheap and live, but only for recipe spell IDs we already have.
- **The full recipe list (the "m" in n / m) is the open question.** Three candidate sources, all to probe:
  1. The profession window (modern `C_TradeSkillUI.GetAllRecipeIDs` with `SetShowUnlearned(true)`): if Forever lists unlearned recipes with `sourceType` and `GetRecipeSourceText`, the client gives the whole list and where each comes from. Best case. [unverified]
  2. Trainers: `GetTrainerServiceInfo` / `GetTrainerServiceSkillReq` at a profession trainer, recorded per character like `ClassTrainer` does today. Gives trainer recipes only. [unverified for profession trainers]
  3. Recipe items (QuestieDB): 1,971 recipe items with vendor, drop, object and quest sources, but `teachesSpell` is empty on all of them, so item → spell (and so known state) isn't offline. A vendor's or bag item's tooltip may say "Already known"; to probe.
- **No new dependency needed** so far. ItemTree / ItemTree_Data hold full recipe tables extracted from the client's own data, but they're "All Rights Reserved"; read for API usage only, never used as data.

## QuestieDB (offline, base rows)

| What | Numbers | Notes |
|---|---|---|
| Recipe items (class 9) | 1,971: vendors 864, NPC drops 590, object drops 239, quest rewards 71, no source 347 | By subclass: leatherworking 488, blacksmithing 380, tailoring 357, engineering 174, enchanting 173, alchemy 139, book 121, cooking 119, first aid 17, fishing 3. "book" includes warlock grimoires (filter out). Up from 1,788 on 2026-11-08 (QuestieDB update) |
| Vendor recipes by area | Barrens 17: 329, Redridge 44: 319, Orgrimmar 1637: 175, Ironforge 1537: 104, Stormwind 1519: 96, Undercity 1497: 90 | Barrens and Redridge carry Forever's level-60 profession vendors (25xxxx recipes) |
| Trainers (NPC subName) | Leatherworking 30, Alchemy 27, Engineering 25, Tailoring 25, Blacksmithing 23, Enchanting 23, Herbalism 20, Mining 19, Skinning 18, First Aid 15, Cooking 14, Fishing 11 | Ranks from the subName: Journeyman / Expert / Artisan / Master, plus specialisation trainers (Dragonscale, Elemental, Tribal, Gnome, Goblin). Forever adds one **"Junior <Profession> Trainer"** per profession (24xxxx IDs, no spawn area in the base rows) |
| Quests needing a skill (`requiredSkill`) | Blacksmithing 53, Leatherworking 32, Engineering 31, Enchanting 14, Fishing 14, others 11-13 | Includes the classic specialisation and rank quests, and Forever's **"Camping 101: <Profession>"** quests (8 per profession, one per start area, sort -666, after the starting chain; teach a camping item) |
| Forever's crafting writs | 150 **"Craftsman's Writ: <item>"** quests in area 16941 "Crafting" | Started by a writ item, ask for one crafted item, +75 Azeroth Commerce Authority (2586) / Durotar Supply and Logistics (2587) (the profession factions found in the reputation research) |

## Client APIs to check (`/azfdiag profs`)

The probe records whatever is open when it runs (each run is kept, up to 8):

- Always: `GetProfessions` slots and `GetProfessionInfo` per slot, `GetProfessionInfoBySkillLineID`, every `C_SkillInfo` skill line (rank / max, secondary skills), `GetAllProfessionTradeSkillLines`, and `IsPlayerSpell` / `C_SpellBook.IsSpellKnown` on nine classic recipe spells (Linen Bandage 3275, Smelt Copper 2657, Minor Healing Potion 2330...). Recipe items in the bags with tooltip lines.
- Profession window open: base / child profession info, the show learned / unlearned filters, `GetAllRecipeIDs` and `GetFilteredRecipeIDs` before and after showing unlearned (filters restored), each recipe's `GetRecipeInfo` (learned, sourceType, category, difficulty, item), `IsPlayerSpell` against `learned`, `GetRecipeSourceText` for unlearned ones, `GetRecipeRequirements`, categories.
- Profession trainer open: services with name, state, skill requirement, level, cost.
- Vendor open: recipe items with tooltip lines (marked `[red]` for red text: "Already known", "Requires Tailoring (125)").

Questions it answers:

1. Do the skill ranks and max ranks read right on Gideon and Thragor (which professions do they have)?
2. Does `IsPlayerSpell` match the window's `learned` for every recipe?
3. Does the window list **unlearned** recipes, how many, and with which `sourceType` / source text?
4. Does a profession trainer list skill requirements for every recipe, including ones not yet learnable?
5. Does a recipe item's tooltip (vendor and bag) say "Already known" and the skill required?

## Probe results (Gideon, level 10, 2026-11-13, runs 1-5)

Runs: 1 nothing open, 2 First Aid window, 3 Cooking trainer, 4 First Aid trainer, 5 a vendor (12 items, no recipes). No recipe items in the bags.

- **Skills** [verified-ingame]: `GetProfessions` gives 5 slots: Blacksmithing 33/75 (skill line 164), Mining 59/75 (186), First Aid 42/75 (129), Fishing 20/75 (356), Cooking 23/75 (185). `GetProfessionInfo` reads right at any time. `C_TradeSkillUI.GetProfessionInfoBySkillLineID` returns **0/0 until a profession window has been opened** this session (run 1 vs 2), so use `GetProfessionInfo`. `C_SkillInfo.GetSkillLineInfo` agrees and lists each profession twice (base line 164 and a child line 2938 with parent 164); categories 11 = primary, 9 = secondary. Global `GetSkillLineInfo` / `GetNumSkillLines` and the classic `GetTradeSkill*` don't exist.
- **The profession window lists every recipe, learned or not, without touching the filters** [verified-ingame]: First Aid has 32 recipes with `showUnlearned` false (2 learned, 30 not). `GetAllRecipeIDs` and `GetFilteredRecipeIDs` didn't change when unlearned were turned on (32 / 2). Fields per recipe: `recipeID` (the spell), `name`, `learned`, `categoryID`, `skillLineAbilityID`, `relativeDifficulty`, `maxTrivialLevel` (grey at), `numSkillUps`, `hyperlink` (the crafted item), `icon`, `itemLevel`. **No learn-at skill and no source:** `sourceType` is nil on all 32, `GetRecipeSourceText` nil, `GetRecipeRequirements` empty, `GetCategories` empty (named by categoryID next run).
- **Known state with the window shut** [verified-ingame]: `IsPlayerSpell(recipeID)` matched `learned` on all 32 First Aid recipes, and on the 9 test spells with no window open (`C_SpellBook.IsSpellKnown` the same). So once a profession's list is recorded, known state stays live without the window.
- **Trainers** [verified-ingame]: `GetTrainerServiceInfo` + `GetTrainerServiceSkillReq` give each service with its **skill requirement** and cost: Cooking 10 services (Journeyman Cook at 50, Spiced Wolf Meat 10 ... Spider Sausage 200), First Aid 13 (Journeyman at 50, Minor Healing Potion 1 ... Silk Bandage 150). The rank upgrades (Apprentice / Journeyman ...) are services too. Level requirement 0 on all.
- **Forever reworked First Aid** [verified-ingame]: besides bandages it has healing potions (Minor to Major), anti-venoms, poultices, tourniquets, and new recipes (Toxin Study, Plague Doctor's Laboratory; 12xxxxx spell IDs). Cooking's trainer sells a Basic Campfire Kit (the Camping 101 item).
- **Not settled yet:** a recipe item's tooltip ("Already known", "Requires ...") because the vendor sold no recipes; whether a crafting profession's window (Blacksmithing) also lists vendor and drop recipes; category names.

### Runs 6-8 (Blacksmithing and Mining windows, a recipe vendor)

- **Blacksmithing window: 507 recipes** (the probe read 500; cap now 1,200), 16 learned, `IsPlayerSpell` agrees on all 500. **Mining: 18** (14 Smelted Bars, 3 Camping, 1 uncategorised), 1 learned. Categories are named by `GetCategoryInfo(categoryID)` (`GetCategories` stays empty): Blacksmithing has 33 under parent 2425 "Blacksmithing" (Plate Helmets, Daggers, Weapon Stones, Reagents, Camping...) plus **2593 "SEASON OF DISCOVERY" with 58 recipes** (Obsidian, Icebane, Razorspike...). [verified-ingame]
- **The window's list includes recipes that may not be obtainable on Forever:** the Season of Discovery category, a TBC bandage (Crystal Infused Bandage, grey at 360), Smelt Obsidian-Infused Thorium Bar. So the window's count is **not** an honest "m".
- **Recipe item tooltips** (vendor, `C_TooltipInfo.GetMerchantItem`) [verified-ingame]: "Use: Teaches you how to cook Longjaw Mud Snapper.", **"Requires Cooking (50)"** (red when the skill is too low), "Requires Level 5". `C_Item.GetItemSpell` gives only "Learning" (402265), not the recipe spell. "Already known" not seen yet (Gideon knows none of the three).
- **Name match** (`luajit tools/qdb.lua recipes match [all]`, window names against QuestieDB recipe items "Plans: X" etc.): Blacksmithing 370 of 500 match a recipe item, 58 are Season of Discovery, 91 have neither (mostly trainer recipes: Bronze Axe, Silver Rod, the stones; plus Icebane, Rune Edge...). First Aid 16 of 32 match (14 neither: the trainer's bandages and potions). Mining 2 of 18. The match must also check the item's profession subclass (First Aid's "Healing Potion" vs Alchemy's).

Consequences: a profession's full recipe list and learned state come from its window (record once per character, then keep it live with `IsPlayerSpell`); the skill to learn a trainer recipe comes from a trainer visit; where to get the rest has to come from QuestieDB's recipe items (by name: "Plans: X", "Recipe: X"), with no source shown when none matches.

## Owner's answers (2026-11-13)

- Only this character's professions.
- A profession is complete at max skill. Recipe collection is tracked but doesn't count toward completion.
- Gathering professions: skill road and Next up, plus Where to gather from the hand-curated table below. Writs: left to the Reputation tab (default, owner didn't object).

## Ranks on Forever [external]

Warcraft Tavern's Forever professions guide (warcrafttavern.com/forever/guides/professions, read 2026-11-13): "The maximum skill level for professions in Forever is 300." Ranks: Apprentice cap 75 (character level 1 gathering, 5 crafting / secondary); Journeyman cap 150 (train at skill 50, level 10); Expert cap 225 (skill 125, level 20); Artisan cap 300 (skill 200, level 35; "only from special trainers"). Not cross-checked (Icy Veins and Overgear refused the fetch); the skill gates match Gideon's trainers (Journeyman at 50). The trainer reports level 0 for every rank, so levels stay a guide, not shown as game data. Forever adds: Camping objects per profession (three each, e.g. First Aid Kit / Toxin Study / Plague Doctor's Laboratory), titles from the Commerce Authority factions, Legacy points at 150 / 225 / 300 (kami-labs.fr), specialisation quests for Blacksmithing, Engineering and Leatherworking.

## Gathering table (hand-curated, unofficial)

Owner-approved 2026-11-13 as a guide, like `Data/Zones.lua`'s level ranges. No game source; QuestieDB lists the node objects (`qdb.lua objects Vein`, `Deposit`) but with almost no spawn points, so zones come from guides too. Conflicts are noted, not resolved by guessing; an in-game node tooltip ("Requires Mining (65)") settles them (open check G1).

**Mining** (skill to mine): Copper 1 (Forever adds a Poor Copper Vein in starter zones), Tin 65, Incendicite 65, Silver 75, Lesser Bloodstone 75, Iron 125, Indurium 150, Gold 155, Mithril 175, Truesilver 230, Dark Iron 230, Small Thorium 245 (kami-labs.fr Forever list; 250 in Jukaar's Classic guide), Rich Thorium 275 (Classic guides; Warcraft Tavern's Forever page says "once you reach 295", unclear). Forever-only, skill unknown: Heavy Thorium Vein, and the ores behind Azerothium and Heavy Thorium bars, Pyrite, Bauxite, Pitchblende (Warcraft Tavern), Starsilver / Cold Iron / Fool's Gold veins (QuestieDB objects; may be Season of Discovery).

**Herbalism** (gfinityesports.com Forever herb guide, matching Classic): Peacebloom 1, Silverleaf 1, Earthroot 15, Mageroyal 50, Briarthorn 70, Stranglekelp 85, Bruiseweed 85 (100 in rankedboost and Classic lists), Wild Steelbloom 115, Grave Moss 120, Kingsblood 125, Liferoot 150, Fadeleaf 160, Goldthorn 170, Khadgar's Whisker 185, Wintersbite 195, Firebloom 205, Purple Lotus 210, Arthas' Tears 220, Sungrass 230, Blindweed 235, Ghost Mushroom 245, Gromsblood 250, Golden Sansam 260, Dreamfoil 270, Mountain Silversage 280, Plaguebloom 285, Icecap 290, Black Lotus 300. (Firebloom, Purple Lotus, Arthas' Tears, Wintersbite: Classic lists only.) Forever-only, skill unknown: Marefoil, Demonsage, Death Lotus; scarce Frilled Lichen, Rosecap, Stranglevine (Warcraft Tavern). Forever zones: Riverglades (Kingsblood, Liferoot), Mount Hyjal (Mountain Silversage, Black Lotus), Shen'dralas (Khadgar's Whisker) (Gfinity).

**Skinning** (wow-professions.com Classic guide): the highest mob level you can skin is skill / 10 + 10 up to skill 100, then skill / 5; so a mob needs (level − 10) × 10 up to level 20, then level × 5. With `Data/Zones.lua`'s level ranges this gives a zone's skinning range without a new table. Forever bands by zone in Warcraft Tavern's skinning guide (Riverglades in 150-205).

**Fishing:** no source gives a skill per zone for Classic or Forever; only brackets (wow-professions.com: 1-75 starting zones, 75-150 capitals and second zones, 150-225 Dustwallow, Arathi, Stranglethorn..., 225-300 Feralas, Tanaris, Un'Goro, Felwood...). Proposed: show the bracket's zones as "good places to fish", not as a requirement.

Zones per node come from the same guides (Copper: starting zones; Tin: Redridge, Hillsbrad, Ashenvale, The Barrens; Iron and Gold: Arathi, Desolace, Thousand Needles; Mithril and Truesilver: Hinterlands, Tanaris; Thorium: Un'Goro, Felwood, Blasted Lands, Eastern Plaguelands, Winterspring, Burning Steppes). The table itself goes in `Data/Gathering.lua` with its provenance, when the tab is built.

## Proposed recipe model (for the mockup)

A recipe counts in the collection only when it has a known source; the rest is shown apart, as the Reputation tab does with "No known quests":
1. **Trainer:** seen in a trainer's list on this character (skill requirement from `GetTrainerServiceSkillReq`, recorded with the time).
2. **Recipe item** (QuestieDB, matched by name and profession): vendor (with zone), drop, object or quest. Learn-at skill from the item's tooltip when the game has shown it; otherwise unknown.
3. **No known source:** Season of Discovery category and anything matching neither, listed but not in n / m.

## Open design questions (for the owner)

- Gathering professions (Herbalism, Mining, Skinning): proposed skill bar and trainer ranks only (Mining also has its smelting list).
- Craftsman's Writs: proposed to leave them to the Reputation tab.
- Season of Discovery recipes (58 in Blacksmithing): can they be learned on Forever? Proposed: hidden, or under "No known source".
