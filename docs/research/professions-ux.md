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

## 5a. Pinned recipes and a shopping list (owner's idea, 2026-11-14)

The owner wants to **pin a recipe and always see on screen what's still needed for it** (a shopping list). Questions the probe answers first (`/azfdiag profs`, 2026-11-14 additions):
- Does `C_TradeSkillUI.GetRecipeSchematic(recipeID, false)` return the reagents (item, quantity) on Forever, and **with the profession window shut**? If only while open, ingredients are recorded with the recipe list (the "open your window once" step).
- `C_Item.GetItemCount(item, includeBank)` for "have / need" (bags; bags + bank).
- **The game's own recipe tracking:** the Forever profession window has a Track checkbox (`Blizzard_Professions/Camelot`), and `GetRecipesTracked` / `SetRecipeTracked` exist. If the client already shows tracked recipes with reagent counts in its objective tracker, pinning can use it (native look, no frame of our own; Azerfolio's pin = `SetRecipeTracked`). Otherwise Azerfolio needs a small on-screen tracker of its own (outside the main window, movable, gamepad-safe, out of combat updates only).

**Probe answers (Gideon, runs 7-8, 2026-11-14; `WoWScrnShot_111426_091411`)** [verified-ingame]:
- `GetRecipeSchematic` returns reagents (item, quantity, type) and the crafted item **with the window shut, for any profession's recipe**, learned or not (Linen Cloak and Charred Wolf Meat, professions Gideon doesn't have): 8 of 9 test spells (2330 is no longer a recipe on Forever: First Aid's Minor Healing Potion is 1244431). With the window open: 32 of 32 First Aid recipes. Fields: `recipeID`, `name`, `outputItemID`, `quantityMin` / `quantityMax`, `reagentSlotSchematics` (`reagents[].itemID`, `quantityRequired`, `reagentType`), `recipeType`, `isRecraft`.
- Reagent names come back nil until the item is cached (run 7), then fill in (run 8): ask for them, then refresh on `GET_ITEM_INFO_RECEIVED`.
- `C_Item.GetItemCount` works (Linen Cloth 4, Rough Stone 8, Copper Ore 12; bags and bank the same here).
- **The game tracks recipes itself:** ticking Track in the profession window put "Recipes · Linen Bandage · Linen Cloth: 4/1" in the objective tracker (with Questie's lines); `GetRecipesTracked(false)` returned `{3275}` with the window shut, and `SetRecipeTracked` and `ProfessionsRecipeTracker` exist. The native line shows one craft's need, nothing about where to get a reagent.

**Owner's decision (2026-11-14):** no tracker of Azerfolio's own; the game's pinning is used as it is, unless an idea makes it clearly better. Azerfolio's additions are proposed below, all inside the tab:
1. **Ingredients on a recipe's details** (info line and the recipe page): each reagent with "have n" and **where to get it** (a vendor that sells it, from QuestieDB item vendors; a gathering node from the Where to gather table; another recipe when it's crafted). This is what the native tracker lacks.
2. **X: Track / Untrack** on a recipe row calls the game's own `SetRecipeTracked`, so a recipe can be pinned from the dashboard (also one you haven't learned yet, if the game allows it: open check G3). The row shows a "Tracked" tag.
3. A **Tracked** section at the top of the profession page listing the game's tracked recipes with their reagents and sources.

Superseded sketch (an Azerfolio tracker), kept for reference: a **Pin** action (X) on a recipe row and in Next up; a **Shopping list** section on the Professions tab and a line on the Overview panel ("Pinned: Heavy Linen Bandage ×5 · Wool Cloth 3 / 10"); quantities per pinned recipe (craft n times, or "until it greys"), reagents summed across pins, each with have / need and where it comes from (vendor-sold reagents: QuestieDB item vendors; gathered: the Where to gather table; crafted reagents: their own recipe).

## 5b. Layout review of mockup round 1 (2026-11-14)

Measured in the preview at the standard window (1160×740, no scaling): list 360 px, page 784 px; the page's scroll view is 529 px under a 124 px banner.

| Profession (Gideon today) | Page height | Screens | Focus stops | D-pad presses to the first recipe | Where "Recipes" starts |
|---|---|---|---|---|---|
| Blacksmithing | 16,965 px | 32 | 397 | 11 | 351 px (bottom third of the first screen) |
| First Aid (1 tracked) | 2,079 px | 3.9 | 41 | 13 | 546 px (below the fold) |
| Mining | 1,183 px | 2.2 | 23 | 22 (past 10 gather rows) | 910 px |
| Cooking (window not read) | 529 px | 1 | 6 | — | — |
| Veteran First Aid (2 tracked) | 2,169 px | 4.1 | 41 | 13 | 619 px; the skill road starts at 284 px |

**What works:** the list-plus-page pattern (same as Class and the wide Reputation), the road as the profession's signature, the status tags, honest counts.

**Problems:**
1. **One scroll does three jobs**: progress (banner, road), what to do now (Tracked, Next up) and a reference (recipes, where to gather). The reference dwarfs the rest: Blacksmithing's recipes are 97% of the page, and with a gamepad the page is a 397-stop walk.
2. **The page moves under you:** Tracked sits on top, so tracking a recipe pushes the road down 150 px per card (veteran First Aid: 284 px).
3. **The same fact in four places:** the next rank is in the list tag, the banner's subline, the road's stone and Next up; the skill is in the list row, the banner score and the road. 267 px of banner + road come before the first actionable line.
4. **The recipe list opens on "All 386"** in levelling order, so the first rows are greys you already know (Copper Rod, Sharpening Wheel) and 370 "Later" recipes with no learn skill yet. The questions a player has at the forge (what can I learn, what still gives skill) are filters away.
5. **Mining's Where to gather (10 rows, mostly grey or far off) sits between Next up and the recipes**; only the node you're on and the next one matter day to day.
6. **The list spends 360 px on 5 professions** whose rows repeat what the page says; the Overview panel already gives the same summary.
7. Ingredients expand inline, so rows jump as you open them.

**Recommendation: split the page into views, and let the road lead.**

```
┌ rail ┬──────────────────────────────── Blacksmithing ─────────────────────────────────┐
│ ⚒ 33 │ [ Journey ]  Recipes  Gather                                  Y switches view │
│ ⛏ 59•│ ┌ banner art, full width ──────────────────────────────────────────────────┐ │
│ ✚ 42•│ │ Blacksmithing  Apprentice Blacksmith                               33/75 │ │
│ 🍲 23 │ │ 1 ●━━━━━G══╪╱╱╱╱╱ Journeyman ╱╱╱╱ Expert ╱╱╱╱ Artisan ╱╱╱╱╱╱╱╱╱╱ (coin) 300 │ │
│ ⚓ 20 │ └──────────────────────────────────────────────────────────────────────────┘ │
│      │ NEXT UP                              │ TRACKED                              │
│      │ • Journeyman at 50 · 17 to go …      │ Linen Bandage   Ready                │
│      │ • Still gives skill: Copper Battle … │   4 / 1 Linen Cloth                  │
│      │ • 2 recipes waiting at your trainer  │ First Aid Kit   Missing Linen Band.  │
└──────┴──────────────────────────────────────┴──────────────────────────────────────┘
```

- **A slim rail instead of the list** (about 110 px: coin, name, "33 / 75", a red or orange dot for "at cap" / "train now"); the Overview panel and the info line carry the full status. The page gets about 1,040 px.
- **Journey** (default, fits one screen, no scroll): a full-width banner with the **road set into it** (the road gets about 1,000 px: stones and labels finally have room; the painted banners are wide scenes anyway), then **Next up** and **Tracked** side by side. Tracked no longer pushes anything.
- **Recipes**: a toolbar (filters, count), then the **recipe list on the left and the focused recipe on the right**, like the Class tab's road and stop: ingredients with have / need and sources, learn and grey skills, where to get it, Track (X). Nothing jumps; D-pad walks the list, the detail follows. Default filter **"For you now"**: learn now, known and still giving skill, and the next 25 skill points, still in levelling order; All / Known / Later / No known source one press away.
- **Gather** (Mining, Herbalism, Skinning, Fishing): the full node table. Journey's Next up keeps only the node you're on and the next.
- **Y cycles the views** (the Zones tab's precedent), with a visible switch at the top for the mouse; LT/RT jump sections inside a view; B goes back to the rail.

Expected: Journey 1 screen instead of 1-32; the first recipe one press away (Y) instead of 11-22; the next rank in two places (rail dot, road / Next up) instead of four; nothing moves when you track.

Smaller alternative (keeps one scroll): drop the banner's subline, put Next up beside the road, move Tracked under Next up, default the recipes to "For you now", collapse Where to gather to two rows. Fixes 2-5, not 1 or 6.

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
