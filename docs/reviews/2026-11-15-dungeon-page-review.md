# Dungeon page review (2026-11-15)

The owner likes the banner and asked for everything below it to be reviewed as a UI designer, a UX designer, a WoW player and an artist, before the dungeon art is generated. Mockup round 4 (`mockups/DESIGN.md` "Dungeons tab"), window 1160×740, measured in the browser (CSS px).

## What's there now

Below the 216 px banner the page scrolls in a 437 px window. One column of sections, in this order: keys strip (when the instance has keys), **Bosses** (left) with the focused boss's **loot** beside it (sticky), **Quests** (chips: Ready now / Ready but red / Later / Done), **Factions raised here**, the source note.

| Instance | Bosses | Boss list height | Quests start at | Page height | Screens | Focus stops |
|---|---|---|---|---|---|---|
| Scarlet Monastery: Cathedral | 2 | 110 | 234 | 510 | 1.2 | 11 |
| Krol'dok Stronghold | 6 | 343 | 453 | 605 | 1.4 | 9 |
| The Deadmines | 8 | 459 | 569 | 955 | 2.2 | 20 |
| Molten Core | 10 | 575 | 492 | 999 | 2.3 | 21 |
| Zul'Gurub | 13 | 749 | 860 | 1,231 | 2.8 | 42 |
| Blackrock Depths | 27 | 1,563 | 1,736 | 2,282 | 5.2 | 61 |

## Findings

### UX (what the page is for, and how fast you get there)

1. **The page leads with what doesn't count and buries what does.** The banner's score is quests ("0 / 6 quests done"), the tab's only honest progress, but quests start below the whole boss list: 569 px down in the Deadmines, 1,736 px (four screens) in Blackrock Depths. A player opening a dungeon page asks "what should I pick up before I go?" first, and that answer is at the bottom.
2. **The questions a player has come in an order the page doesn't follow.** Before the run: am I the right level, do I need a key, which quests do I take and *where do I pick them up*. During: which bosses, what do they drop, is it for me. After: turn-ins, reputation. The page mixes these (keys at the top, factions at the bottom, quests between).
3. **Quests lack the one fact that matters for dungeons: where they start.** Dungeon quests are picked up far away (the Deadmines' six: three at Sentinel Hill in Westfall, two in Stormwind City, one at Alba Fairmoon in Westfall) and two of them need an earlier quest first. QuestieDB has the giver, their spawn zone and the prerequisite (`startedBy`, NPC `spawns`, `preQuestSingle`), so this is honest data the addon can show. The chips only show name and level.
4. **The loot pane can't keep up with long lists.** It's sticky and 264-516 px tall, so on Blackrock Depths the right column is empty for 1,300 px under it. In raids it's mostly "No loot known" (QuestieDB has gear for only Ragnaros in Molten Core).
5. **Long pages cost presses.** 61 focus stops on Blackrock Depths; LT/RT jumps sections (Bosses, Quests, Factions), but inside Bosses you walk 27 rows.

### UI (layout, hierarchy, density)

6. **Boss rows are tall for one line of text**: 52 px each (the 40 px milestone stone plus padding), about 8 visible. The stone and the dotted path repeat 27 times on Blackrock Depths; the information is just a number, a name and a tag.
7. **Every section looks the same** (a gold group header over brown boxes), so nothing tells you where to look first. The keys strip is the one thing styled differently, and it's the least important for most instances (11 of 41 have keys).
8. **Half the width is unused below the loot pane**, and the quest chips are a flat grid with no grouping a player would recognise.
9. **Sources and honesty notes are good but take 3 lines in three places** (kills not counted, quest rule, sources); one footer would do.

### WoW player

10. **"Is this loot for me?"** The loot list shows type ("Leather", "Two-Hand Axe") but doesn't say what this character can use or would want: a Paladin wants plate (mail before 40), a two-hander or a one-hander and shield, a libram. A "For you" filter (armour your class wears, weapons it can use, level within reach) is what players look for first; the game's item tooltip (`GameTooltip:SetItemByID`, in the addon) answers "is it an upgrade".
11. **Bosses want a little more than a name**: rares and optional bosses are tagged, but summoned bosses (Kirtonos, Gahz'rilla, Lord Valthalak) need an item or event; wings with separate entrances (Stratholme's two gates, Naxxramas's quarters) want their own grouping. Kill state is honestly unknown, which is right.
12. **Dungeons are run in groups**: "Ready now" is about me, not the group; that's fine. Turn-ins are often in a different place from the pickup (Destruction in Deadmines: from Alba Fairmoon, to a different NPC); worth one line.

### Artist

13. **Below the banner the page loses the painting.** The banner is rich; then a flat dark-brown slab of identical panels. The cards and the road made the instance feel like a place; the page body doesn't.
14. **The milestone stone means "a level you reach" on the Class and Profession roads**; reused for bosses it reads as tombstones. Bosses deserve their own mark (a numbered seal or a small crest-like shield), and fewer of them visible at a larger size beats many small repeated ones.
15. **Gold text everywhere** (headers, names, plates) flattens emphasis; the banner already owns the gold.

## Proposals

### A. Views, like the Professions tab (recommended)

The banner stays; under it a view switch (the toolbar's view-toggle buttons, Y cycles): **Overview · Bosses & loot · Quests**. Each view fits the page (no or little scroll), and Y reaches any of them in at most two presses.

- **Overview** (fits one screen; the page opens here): three framed panels in the art-card style.
  - *Before you go*: level fit ("Your level: 10 · this is for 15-23, 5 to go"), keys and attunements, and **where to pick up the quests**, grouped by place: "Sentinel Hill, Westfall · 3 quests (Gryan Stoutmantle, Scout Riell, Alba Fairmoon)", "Stormwind City · 2 quests"; "needs an earlier quest" where it does. A on a place opens the Quests view filtered to it.
  - *The run*: the bosses as a short horizontal path of numbered seals (the road's language, small), rares and optional bosses hollow; total loot "34 items, 6 for you"; A opens Bosses & loot on that boss.
  - *Rewards*: factions raised (crests in a row with ~+amount) and the quest score.
- **Bosses & loot**: master-detail like Recipes. A compact boss list on the left (32 px rows: seal number, name, tags, items; wing headers), the focused boss's loot on the right as a grid of item tiles (icon, name in quality colour, type, level) with **For you / All** at the top (For you: armour and weapons your class uses; the info line explains). Each column scrolls on its own, so the loot never sits beside empty space.
- **Quests**: grouped **by where you pick them up** (place headers with the giver), in chain order, each row: level chip, name, "from Gryan Stoutmantle", "needs: The Defias Brotherhood (1 of 5)", turn-in when it differs, done ✓. Filters: Ready now / All / Done.
- Cost: data for givers and prerequisites from QuestieDB (already read for zone storylines); "For you" needs the class's armour and weapon rules (curated table, small). Fits Phase 9's quest model.

### B. One scroll, reordered

Keep one page but put **Before you go** (level, keys, quest pickups by place) first, then the quest checklist, then compact bosses (32 px rows) with loot, then factions in one footer with the sources. Cheaper (no view switch), still long on big instances (Blackrock Depths about 3 screens), and the loot pane still competes with a long list.

### C. Boss path under the banner

A horizontal path of boss seals right under the banner (like the road), the focused boss's loot below it, quests and factions in a column on the right. The most "place-like", but the right column gets narrow for quest names at 1160 px, and 27 seals don't fit one row (two rows, or scroll).

**Recommendation: A**, with C's boss path as the Overview's "The run" panel. It answers the player's questions in order, keeps progress (quests) one press away, gives loot its own room with a "For you" filter, and matches a pattern the owner already approved (Professions: Journey · Recipes · Gather).

## Art notes for any option

- Carry the painting below the banner: the page background a dark, blurred, low-opacity crop of the instance's painting fading to the page colour, so each dungeon's page feels different (no new art needed).
- Bosses get a **numbered seal** (a small round bronze seal with the number; rares hollow, optional dashed), not the road's milestone stone. New piece: `boss-seal` (chrome, 64 px), one prompt.
- Panels in the art-card frame A (thin bronze line) instead of brown boxes; gold kept for the banner, names white, headers in the plate style.
- Item tiles use the game's icons in the addon with the quality colour on a thin border.

## Decision

Owner (2026-11-15): **option A**, views. Built in the mockup as round 5 (`mockups/DESIGN.md` "Dungeons tab"): Overview with Before you go (quest pickups by place, from QuestieDB givers), The run (numbered seals) and Rewards; Bosses & loot with For you / All; Quests grouped by where you pick them up. Measured: every Overview fits the page (10 instances, including Blackrock Depths' 27 bosses and 9 pickup places), no panel scrolls. The `boss-seal` art and the class gear table for "For you" are still to make.
