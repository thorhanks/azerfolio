# Professions tab: UX analysis (2026-11-13)

What a player would want from a Professions tab, what we can honestly show, and how to show it in Azerfolio's language. Data facts and evidence: [professions.md](professions.md). Owner decisions so far: this character's professions only; a profession is complete at max skill; recipes are a collection that doesn't count toward completion.

## 1. What a player actually asks

From playing Classic-era professions, roughly in the order they come up:

| # | The player's question | When it matters | Today's answer in game |
|---|---|---|---|
| Q1 | **Am I at my cap?** "Mining 75/75: every node from here is a wasted skill-up until I train." | Constantly while levelling. The most common profession mistake | The skill bar in the profession book; nothing warns you |
| Q2 | **Where and when do I train the next rank?** Journeyman at skill 50, Expert at 125, Artisan at 200, and Artisan trainers are few and far between | Every 75 points | Ask a guard, or look it up |
| Q3 | **What can I learn right now?** New trainer recipes unlocked by my skill | After every few skill-ups | Visit the trainer and look |
| Q4 | **What should I craft to keep skilling?** Which known recipes still give points (orange / yellow / green, not grey) | Every session at the forge | The profession window's colours, only while it's open |
| Q5 | **Where do I gather for my skill?** "Tin at 65, Silver at 75, Iron at 125": which zones | Gathering levelling | Look it up |
| Q6 | **Where do I get the recipe I'm missing?** Vendor (which one, which zone), drop, quest | Collecting, and for the good items | Look it up |
| Q7 | **What's rare or worth having?** Epic and rare patterns, world drops, the showpieces (Lionheart Helm, Arcanite Reaper) | Bragging rights, completionist | Look it up |
| Q8 | **How far along is my collection?** "312 of 442 Blacksmithing recipes" | Completionist | Nowhere honest: the window lists recipes Forever may not offer |
| Q9 | Specialisation (Armorsmith / Weaponsmith, Dragonscale / Elemental / Tribal, Gnomish / Goblin) and its quests | Mid-levels | Quest givers |
| Q10 | Cooldowns at 60 (transmutes, Mooncloth, Salt Shaker) | Endgame | The window |

Q1-Q4 are the daily questions, Q5-Q8 the collector's and planner's, Q9-Q10 the later ones. Azerfolio's strength is answering the questions the game doesn't answer **while you're not standing at the forge**.

## 2. What we can honestly show

| Data | Source | Evidence | Answers |
|---|---|---|---|
| Professions, skill, current cap, rank name | `GetProfessions` / `GetProfessionInfo` | verified in game, any time | Q1 |
| Next rank: its skill requirement and cost | A profession trainer's list (`GetTrainerServiceSkillReq`), recorded per character | verified (First Aid: Journeyman at 50) | Q2 |
| Next rank: **where** the trainers are | QuestieDB NPC subNames ("Expert Blacksmith", "Artisan Tailor") with spawn areas | offline, base rows | Q2 |
| Level requirement for a rank | Trainer reported 0 on every service | **unknown**; don't show | — |
| Every recipe the client knows, learned or not, by category | The profession window, recorded once per profession per character | verified (Blacksmithing 507, First Aid 32, Mining 18) | Q8 (with care) |
| Learned state, live | `IsPlayerSpell(recipeID)` | verified, 550 of 550 agree | Q3, Q8 |
| Grey-at skill per recipe | `maxTrivialLevel` | verified | Q4 (still skills up: yes / no) |
| Orange / yellow / green | `relativeDifficulty`, only as of the last time the window was open | verified, but goes stale | Q4 (with "as of" care) |
| Learn-at skill, trainer recipes | Trainer list | verified | Q3 |
| Learn-at skill, item recipes | Recipe tooltip "Requires Blacksmithing (125)" | verified at a vendor; by item ID unverified | Q3, Q6 |
| Where to get a recipe item | QuestieDB recipe item (vendor NPC + area, drop, object, quest), matched by name | offline, 370 of 500 Blacksmithing | Q6 |
| Crafted item and its quality | The recipe's `hyperlink` (quality in the link) | verified in the sample; not yet recorded for all | Q7 |
| Reagents | `GetRecipeSchematic` with the window open | not probed | (later: shopping) |
| Cooldowns | `GetRecipeCooldown` with the window open | not probed | Q10 |
| Specialisation | `GetProfessionInfo` specialisation index (-1 now) | partly verified | Q9 |
| Profession quests | QuestieDB `requiredSkill` (Camping 101, specialisation, rank quests) | offline | Q9 |
| Gathering node → skill needed | **No source.** Would need a small hand-curated table (Copper 1, Tin 65, Silver 75...) like `Data/Zones.lua` | needs owner approval | Q5 |
| Gathering nodes per zone | QuestieDB objects with spawn areas (`qdb.lua objects`) | offline | Q5 |
| Fishing skill per zone | No source; hand-curated | needs owner approval | Q5 |

**The honest collection total (Q8):** count only recipes with a known way to get them (seen at a trainer, or a QuestieDB recipe item). The rest, Season of Discovery's 58 included, sits under "No known source", listed, not counted, as the Reputation tab does with "No known quests". Before a profession's window has been opened once, the tab says "Open your Blacksmithing window once to read its recipes", the way flight paths ask you to talk to a flight master.

## 3. Design principles for this tab

1. **Lead with what's actionable now.** The cap warning, the trainer visit, the recipes waiting: the class tab's "3 abilities waiting at your trainer" proved this kind of line is the one you read.
2. **Skill is the progress; recipes are the collection.** Completion language (gold, ✓, %, the celebration) belongs to the skill only. Recipes use counts and states, never a %.
3. **Reuse the app's road.** The class road already teaches "a gold fill up to where you are, stones at milestones". A profession's skill is the same idea on one axis: 1 → 300 with rank gates. The player reads it instantly.
4. **Every count must survive "is that true?"** No "of 507". No stale difficulty colours presented as current. No level requirement the game reported as 0.
5. **Gamepad first.** One focus stop per profession, per action, per recipe row; info line carries the details; LT/RT jump sections.

## 4. Proposed structure

```
┌ Professions ───────────────────────────────────────────────────────────────┐
│ PROFESSIONS (list, 360)          │ BLACKSMITHING (selected)                 │
│ ┌──────────────────────────────┐ │ [banner: forge art]  Apprentice          │
│ │⚒ Blacksmithing  Apprentice   │ │                      Blacksmith  33/75   │
│ │  ▓▓▓▓▓░░░ 33/75   16 recipes │ │ 1 ●━━━━━━━◆──────◆──────◆──────◆ 300    │
│ │⛏ Mining   ▓▓▓▓▓▓▓░ 59/75     │ │   You 33  Jrny 75  Exp 150 Art 225 (cap)│
│ │  Train Journeyman now        │ │                                          │
│ ├ Secondary ───────────────────┤ │ NEXT UP                                  │
│ │✚ First Aid  42/75 · 3 to learn│ │ • Train Journeyman (skill 50) · Ironforge│
│ │🍳 Cooking   23/75             │ │ • 2 recipes waiting at your trainer      │
│ │🎣 Fishing   20/75             │ │ • Still skills up: Copper Chain Belt (85)│
│ └──────────────────────────────┘ │ RECIPES  16 known · 21 to learn · 405 more│
│                                  │ [Plate] [Mail] [Weapons] [Stones] ...    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 The profession list (left)

- **Primary** professions first, then **Secondary** (Cooking, First Aid, Fishing) under a group header. Only this character's.
- One row per profession: painted profession icon, name, rank title ("Journeyman Miner"), the skill bar (gilded, the existing stat-bar style) with "33 / 75", and **one status tag**, the most urgent:
  - **"At cap · train Journeyman"** (orange-red, the loudest): skill = cap and a higher rank exists.
  - **"Train Journeyman now"**: skill ≥ the next rank's requirement (from the trainer).
  - **"3 recipes to learn"**: trainer recipes you meet the skill for and don't know.
  - **"Mastered"** in gold with ✓ at max skill.
- Row is a focus stop; the right pane follows focus (as the wide Zones split does).

### 4.2 The profession page (right)

**Banner:** profession art (one painted scene per profession, zone-art style: a forge, a mine mouth, a herb garden; 12 pieces), rank title and skill large on the right, gold "Mastered" when complete.

**The skill road** (signature element): a horizontal track 1 → 300 (or the profession's top cap) in the class road's language:
- gold fill up to your skill; **You** marker;
- a **milestone stone** at each rank gate (75, 150, 225), lit when passed; the next gate shows its requirement ("Journeyman · skill 50"); the cap you're under is a closed gate when you're at it;
- smaller marks for profession quests (Camping 101, the specialisation quest) at their skill;
- the end: the profession's **coin** (a gold coin with its emblem, like the class coin), dull until mastered.
Each stone is a focus stop: the info line says what it needs and where ("Expert Blacksmith: trainers in Ironforge and Stormwind City. Needs skill 125.").

**Next up** (up to 5, the same pattern as the zone dashboard): train the next rank (where), recipes waiting at your trainer, a nearby vendor recipe you can learn now, and two known recipes that still give skill. Each opens its detail.

**Recipes** (the collection): summary "16 known · 21 you can learn now · 405 later" (+ "58 with no known source"). Filters: Known / Learn now / Later / All; grouped by the window's categories (Plate Helmets, Daggers...) or by skill bracket (sort Y). A row:
- icon of the crafted item, name in its **quality colour** (white, green, blue, purple: the rarity reads at a glance);
- learn-at skill ("125");
- source glyph + short text: "Trainer", "Vendor · Booty Bay", "Drop · Stratholme", "Quest · The Undermarket", "No known source";
- state: ✓ known (with "grey at 65" when it no longer skills up), **learn now** (orange), later (dim).
- A opens a recipe page: the item, every source with NPC and zone (A on a zone opens its dashboard), learn-at and grey-at, the quests that need it.

**Rare finds** (the collector's corner, optional): the profession's rare and epic recipes as a small trophy shelf, known ones gilded.

### 4.3 Gathering and secondary professions

- **Herbalism, Skinning:** no recipes. Skill road plus Next up only. With an owner-approved node table, Next up and a **"Where to gather"** section list zones for your skill: "Tin Vein from 65: Westfall, Redridge, Darkshore" (nodes per zone from QuestieDB objects). Skinning can use the zone level ranges already curated (mob level → skill) with the same table approval.
- **Mining:** the skill road, smelting recipes as its (small) collection, and Where to gather.
- **Fishing:** skill road; "where to fish" needs a curated table too.
- **Cooking, First Aid:** like crafting professions (Forever's First Aid has 32 recipes, potions included).

### 4.4 The Overview panel (the space kept free on the left)

"Professions": one line per profession with its skill bar and the status tag (cap warnings first). A opens the tab on that profession. It answers Q1 without opening anything, which is the single most useful thing the tab can do.

### 4.5 Celebrations

- **Mastered** (max skill reached, seen this session): a category-style celebration with the profession's seal, "Blacksmithing Mastered".
- Rank-ups (Journeyman, Expert): a small toast at most, or nothing; to decide.

## 5. Phasing suggestion

| Round | Contents | Data needed |
|---|---|---|
| 1 | List with skill and status tags; profession page with banner, skill road, Next up; Overview panel; "open your window once" state | Have it all (record trainer lists and windows) |
| 2 | Recipe collection with sources, filters, the recipe page, quality colours | Name match + subclass check; tooltip learn-at by item ID (probe) |
| 3 | Where to gather (Mining, Herbalism, Skinning), Fishing spots | Owner-approved curated node and fishing tables |
| Later | Rare finds shelf, reagents / shopping list, cooldowns, specialisation, zone dashboard "for your professions here" | Schematic and cooldown probes |

## 6. Owner's decisions (2026-11-13)

1. Skill road: the Class-tab-style track.
2. Art: a painted banner and a coin per profession.
3. Where to gather: a hand-curated table is fine (web research allowed): [professions.md § Gathering table](professions.md#gathering-table-hand-curated-unofficial).
4. Max skill 300 (confirmed for Forever by Warcraft Tavern; not stated per secondary profession).
5. Overview panel in round 1.
6. Recipes in levelling order by default.

## 6a. The questions as asked

1. **Skill road on the profession page:** a horizontal track in the class road's style (recommended), or a simple bar with rank labels?
2. **Profession art:** a painted banner scene per profession (12 pieces) plus a coin per profession, or icons only for now?
3. **Where to gather:** allow a small hand-curated, unofficial node → skill table (like the zone level ranges)? It's the most useful gathering feature and has no game source.
4. **Top cap:** treat 300 (Artisan) as max skill for "Mastered", unless Forever shows a higher rank? (Some recipes grey out above 300; we haven't seen a trainer rank past Artisan.)
5. **Overview:** add the Professions panel in round 1?
6. **Recipe sort default:** by category (the game's own grouping) or by skill bracket (levelling order)?
