# Design review, 2026-11-14 (v1.2.0 + Phases 11-14)

A review of the whole addon from four angles: UI design, UX, art direction and a WoW player's view. Evidence: the `/azf shots` run `WoWScrnShot_111426_162321`-`162404` (Gideon, 3440×1440, normal / minimum / wide windows), the professions run `154038`-`154055`, the mockup art in `mockups/*-art/`, `art/review/strips-sheet.jpg` and `coins-sheet.png`. Each finding names the shot it comes from. Nothing here has been changed yet.

## Verdict

The addon is in good shape. The zone art is the best asset: 49 pictures and a fallback that look like one set, and they still look good greyed out. The window chrome is consistent too: the native frame, the gilded frame kit, gold headings and one face throughout. The tabs feel like one product.

The weak spots are mostly at the edges:
- **Small art doesn't read.** Profession coins at 40 px, category icons at 16-18 px and reputation emblems at about 20 px blur into blobs.
- **Two "road" languages.** The Class tab draws a gilded earth band; the Professions tab draws a black stat bar across its painted lane.
- **Pages that run out of content** leave large empty dark areas.
- **A few places break the state language or show text cut short.**

The biggest wins would be finishing what the design already promised: the zone map on the Exploration page, and difficulty colours and icons where a WoW player expects them.

## Top 12, ranked by payoff for the effort

| # | Change | Lens | Effort | Evidence |
|---|---|---|---|---|
| 1 | **Atlas names**: one rule for tile labels. Today the same tiles show "Stormwind City" over two lines in one render and "Stormwin..." in another; "Elwynn F...", "Hillsbrad...", "Western..." are cut; the "you are here" pin sits on top of the name. Wrap to two lines always, shrink to 12 px before cutting, and move the pin to a corner | UI | S | `162330` vs `162333`, `162323` |
| 2 | **Untouched shows orange "0%"** on every Atlas tile. Orange means *in progress* in the state language. Show no % on untouched tiles (or grey it), like the cards, which already use grey | UI | S | `162323`, `162333` |
| 3 | **The legend box lets the game's player frame show through**: "Gideon Everh…" and a portrait sit under the info line in most shots. Make `legendBg` opaque, or keep the legend clear of the player frame | UI | S | `162337`, `162344`-`162355`, `154049` |
| 4 | **Next up suggests red level-60 quests to a level-10 character** (Ironforge: "Rotgath Stonebeard", "The Darkmoon Faire"). Leave out quests that are red for you (5+ levels above), or put them under "Later" | UX / player | S | `162355` |
| 5 | **Profession coins don't read at 40 px**: the code-dulled coin turns all five rail entries and the Overview rows into the same brown disc, which hides the lovely gold emblems. Use the painted `coin-prof-<key>-dull` the design already allows for, or keep the emblem bright at about 60% saturation | Art | S-M | `162327`, `162321`, `154043` |
| 6 | **The Professions tab is the only tab without a painted icon**: it falls back to the stock `Trade_BlackSmithing`, which shows as a grey block beside four painted icons. Paint `icon-professions` (anvil and hammer, same frame as the others) | Art | S | every shot, 5th tab |
| 7 | **One road language**: the skill road draws a black stat-bar track over the painted lane, so the strip reads as a progress bar pasted on a picture. Draw it with the Class tab's `road-band` / `road-band-gold` stamps along the lane, with the gate and stones on top | Art / UI | M | `162327`, `154049` |
| 8 | **The Exploration page's zone map** (Phase 3 design: revealed pieces cutting through the fog) was never built in Lua. Today the page is two columns of ticks over an empty page. `GetExploredMapTextures` is verified in game (display only, not for completion); the base map tiles still need a probe | UX / fun | M-L | `162346` |
| 9 | **Recipe and node difficulty in the game's colours**: show recipes and nodes in orange / yellow / green / grey (the colours every crafter knows) instead of "until 55". For recipes, check whether the trade skill API's skill type is readable in Forever; for gather nodes, colour by the curated table's skills, marked as a guide | Player | M | `154043`, `154046` |
| 10 | **Icons on recipes and reagents**: the item's icon (and its quality colour, an open item) in Recipes, the detail pane and Tracked. Players scan crafting lists by icon. Verify `GetItemIcon` / the item info call in Forever first | Player / UI | M | `154043` |
| 11 | **Selected toolbar buttons are hard to tell apart**: every segment, filter and view toggle is the same red panel button, so in the Zones toolbar (11 red buttons) it's hard to see which status or view is on. Mark the selected button more strongly (gold text plus the lit highlight), or make the status segments plain text tabs with a gold underline | UI | S-M | `162323`, `162332`, `154043` |
| 12 | **Class steps repeat the chain's name** ("The Tome of Divinity" on 7 of 8 rows; step 1 is "Tome of Divinity (item)"). Lead with what the step asks, from QuestieDB's objective text ("Bring 10 Linen Cloth"), and keep the name only where it changes | UX | M | `162326` |

S = under an hour, M = a session, L = a phase step.

## UI design

**Consistent and working:** the frame kit on every panel; gold headings over white names; header plates; the cartouches and milestone stones shared by Class and Professions; the notched reputation bar repeated in the list, ledger and faction page; one focus language (chevron, highlight bar, red-ink ring on the maps).

**Inconsistencies:**
- **Two bar styles on the Overview**: the category rows use the gilded `frame-bar`, but the Zones row right under them is a flat orange-on-grey bar (`162321`). Use the same housing with a stacked fill.
- **Category icons at 16-18 px** (Overview Tracked completion, card bars, Next up rows) are painted square icons scaled down into orange smudges; on the cards the three icons are hard to tell apart (`162332`). Draw simple glyph versions for 20 px and below, or show the painted icons only at 24 px and up.
- **The reputation standing strip** shows reaction names only in the wide window; at normal width it's an emblem at about 20 px and a number, and the emblems for Honored and Revered are near-identical silver wreaths (`162324`). Show the name under the count at every width (there's room), or make the emblems about 28 px.
- **"~+100"**: FRIZQT draws the tilde as a raised squiggle that reads like a glitch (`162352`). Put "about" in the group header and show "+100".
- **Text cut with "..."** in places with room to spare: the minimum-size Continue card ("Elwynn For...", `162338`), storyline node names ("Find the Lost Guar...", `162347`), "Known · where it's taught isn't reco..." in the recipe detail (`154043`), and the Overview's class caption ("Stormwi..."). Each wants a second line or a shorter phrase.
- **Info lines are truncated** in the legend on most pages ("Quests 43 of 69 (2 unch..."). The info line is the gamepad user's tooltip, so key facts should come first. Consider letting it grow to two lines (44 → 56 px) when it overflows.
- **Empty areas**: Professions Journey (about 180 px of nothing between Next up and the road, `162327`), the zone dashboard under Next up (`162344`, about 200 px), the Exploration page (`162346`, half the window), Flight paths with no flight master (`162349`, a full page saying one line). See the UX section for what could fill them.

## UX

- **Next up quality** (#4): it's the addon's main "what should I do" surface, and red quests undermine trust. The same rule should apply to the Overview's suggestions and the faction page's "Up to your level".
- **Pages with nothing to open**: a category tile that doesn't apply shouldn't open a page (the design says "quiet, non-opening tile"). If A can open Flight paths for Elwynn outside `/azf shots`, stop it there.
- **Class "Start here"** lists Brandur Ironhammer · Ironforge for a Human Paladin (`162326`). If that's the Dwarf version, it belongs with "other races' versions"; worth an open check.
- **Professions Journey layout**: the painted road is the most attractive part of the page but gets 130 px, while Next up and Tracked get about 340 px for two lines. Consider a taller road (180-200 px, so the landmarks read), with Next up and Tracked sized to their content.
- **Atlas at low progress** is a wall of grey tiles (`162323`), and the Overview's Atlas thumbnail is grey squares on a sea chart (`162321`). That is honest, but it reads as "nothing here" on the screen meant to show how far you've come. See "Visually compelling" below.
- **Reputation with the Met filter** shows 4 rows and an empty page. Fine as a filter, but the default view should probably be All.

## Art direction

**Style families**, consistent within each and bridged by one warm palette:

| Family | Assets | State |
|---|---|---|
| Painterly key art | 50 zone pictures, faction banners, 12 profession banners | Excellent and uniform. The profession banners (forge, kitchen) match the zone art's light and brushwork |
| Antique map | 18 class strips, 12 skill roads, cartouche, milestones, red-ink ring | Uniform; the strongest "Azerfolio" identity |
| Struck gold | 9 class coins, 12 profession coins, reputation emblems, celebration seals | Beautiful at full size, poor at small size (see #5) |
| Square painted icons | 7 tab and category icons | Good at 50 px; the class icon is a cool blue shield among warm icons; Professions is missing (#6) |

**Is the art good enough?** For zones, banners and coins, yes; that's the quality bar. What to improve:
1. **Class strips, Alliance vs Horde**: at contact-sheet scale, the druid, hunter, rogue, warlock and warrior pairs share composition, palette and most landmarks (`art/review/strips-sheet.jpg`), while the paladin and priest pairs clearly differ. The owner's 2026-11-09 decision was a road per side (Tirisfal and Silverpine for Horde). Worth checking whether the Horde landmarks really are Horde places before calling the set done.
2. **Small-size versions**: dull profession coins (#5) and 20 px glyphs for category icons. These are cheap and fix most of the "blob" problem.
3. **Reputation row thumbnails** reuse zone art (Stormwind shows Elwynn's cottage; Ironforge, Darnassus and Gnomeregan Exiles look nearly alike, `162324`). A set of painted **faction crests** (about 12 for the majors, glyph fallback for the rest) in the struck-gold or banner style would make the Reputation tab as distinctive as the others. Right now it's the plainest tab.
4. **Saturation spikes**: Blasted Lands, Burning Steppes and Searing Gorge are near-pure red, and in the catalogue they're the loudest tiles. A slight desaturation pass on those three would calm the set; optional.

## A WoW player's view

- The things a player reads instantly are missing in places: **difficulty colours** (quest chips have them; recipes and nodes don't, #9), **item icons and quality colours** (#10), and the **class colour** (Paladin pink appears only in the header, which is fine).
- **Gather view**: listing zones per node is useful, but players think "where do I go at 59?". Sort or highlight zones that suit your level, and mark the node you're on (it does: "Gives skill").
- **Faction page "Later" lists 67 quests at 36+** for a level-10 character (`162352`). Accurate, but very long; collapse it to the count and the first few, A to expand.
- **The XP bar** is the game's purple; fine, it's native.
- **Sound**: one `PlaySound` in the whole addon. Celebrations, a claim, a profession rank trained and opening a road stop would all benefit from the game's own sounds (quest complete, level up fanfare, map open). Cheap, and big for "fun".

## Visually compelling and fun

1. **The zone map that clears its fog** (#8). The single most satisfying image for an exploration addon, already designed.
2. **A living Atlas**: untouched tiles as faint ink outlines or sepia washes on the chart instead of grey photos, painting into colour as the zone fills; claimed zones get a small pennant (the cards already earn one). At level 10 the map would look like a map waiting to be explored, not a grid of grey.
3. **The celebrations not built yet**: a class road stop walked (the coin strikes gold), a profession rank trained and Mastered, a reputation rank-up toast. The painted pieces (laurel, ribbon, coins) already exist.
4. **The skill road as a journey**: You walks the painted lane past the village smithy toward the volcanic forge; with the road band (#7) and a taller strip, it becomes the Professions tab's centrepiece, as the strip is on the Class tab.
5. **Faction crests** on the Reputation tab and on the zone ledger.

## Smaller polish

- Overview footer: "Each category counts equally · 123 quests can't be checked yet · Kalimdor: talk to a flight master there." wraps mid-phrase; split it into two lines on purpose.
- The Zones toolbar's "Search" box is the only control in a different style (a native edit box among red buttons).
- The Class pane's header says "2 levels to go" in very large type for a stop you can't start; the Next line already says it. Consider the reward coin or the sketch there instead.
- Recipe detail: "Learn at ?" reads like a typo; write "Learn at: not known yet".

## Not suggested, by earlier decisions

Activity panel and milestones (removed 2026-11-08), rares and treasures (declined), recipes as completion (decided: a collection), pole glow and the 25/50/75 rings (removed), rotation animations (client issue).
