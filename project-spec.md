# Azerfolio — Product Specification

**Version:** 0.3
**Target:** World of Warcraft: Forever (client flavor `wowf`, addon interface `16001`)
**Audience:** Personal use. Not published to CurseForge or other distribution sites.
**Development:** Built entirely by AI coding agents; a human runs the game client for in-game validation.
**Tagline:** Every adventure. Every achievement. Every step.

## 1. Vision

Azerfolio is a completionist dashboard and progression journal for WoW Forever. It answers three questions:

1. What have I completed?
2. What remains?
3. What should I do next?

It presents progress as attractive dashboards and actionable checklists, in a visual style that looks like Blizzard's own UI (Encounter Journal / Adventure Guide, parchment and gold).

## 2. Principles

These are hard rules. When a requirement elsewhere conflicts with one of these, the principle wins.

| # | Principle | Rule |
|---|---|---|
| P1 | Honest data | Never show a completion state, count, total, percentage, or timestamp that the game did not confirm. Unknown is displayed as unknown, never as 0% or 100%. |
| P2 | Completion first | Every screen leads with progress. Every statistic is clickable through to the objectives behind it, where a detail view exists. |
| P3 | Native look | Looks like an official WoW interface. No generic web-dashboard aesthetics. |
| P4 | Minimal dependencies | No required addons. Any dependency, including embedded libraries, needs explicit approval from the project owner before it is added. |
| P5 | Character-aware | Objectives a character can never complete (faction, class, exclusive choices) are excluded from that character's totals, so 100% is reachable. |
| P6 | One source of truth | Progress is calculated in one place. UI code only displays results; it never calculates progress. |
| P7 | Cheap at runtime | Event-driven updates and cached results. No polling loops, no per-frame scans, no full rescans when one zone changed. |
| P8 | Expandable | Adding a new category (class, professions, dungeons, collections, Legacy) means adding a provider, not redesigning. |

## 3. Release scope

### v1 — Overview + Zones (exploration)

- Main window with bottom tabs: **Overview** and **Zones**. Zone Detail is a subview of Zones.
- Character header.
- Overview dashboard: tracked completion, stat cards, zone highlights, suggestions, recent milestones (removed in v1.1, §5.6).
- Zone catalogue: illustrated card view (default) and compact list view, filters, sorting, search.
- Zone Detail with an exploration checklist.
- Exploration tracking implemented by Azerfolio itself.
- Saved UI preferences.
- English only.

### v1.1 — Quests

- Quest tracking per zone, using QuestieDB as the quest catalogue (see §8.4).
- Quest stat card, quest section on Zone Detail, quest suggestions.
- **Zone completion across categories** (§7.7): exploration, quests and flight paths together, not exploration alone (owner, 2026-11-08).
- **Flight paths** discovered per zone (§8.5), if the client can confirm them.

### v1.3 — Zone reputation

- The zone's own factions on Zone Detail, with the character's standing (§7.8, §8.9). Owner's choice, 2026-11-08.

### v1.4 — Reputation tab

- A third tab with every faction the game returns data for, and a page per faction on how to raise it (§7.9, §8.10). Owner's choice, 2026-11-09.

### v1.5 — Class tab

- A fourth tab: the character's class quests as a road on a painted map, stop by stop, with the class trainer's abilities along it (§7.10, §8.11). Owner's choice, 2026-11-09.

### Later (architecture must allow, do not build)

Professions (recipes: known vs. available, where to get them), collections, dungeons and raids (incl. a dungeon tile on Zone Detail: art and quest progress, opens the Dungeons tab), Legacy progression, reputation rewards per standing and kill reputation, account-wide and cross-character views, custom goals, smarter recommendations, waypoint integration, localization.

### Out of scope

Rares, treasures, fishing, quest storylines as goals, and bounties as zone categories (owner, 2026-11-08: data gaps, no history, little reward). Public release and packaging, network or cloud features, sharing between players, route optimization, gear/talent advice, required third-party addons.

## 4. Main window

### 4.1 Look

- Ornate Warcraft-style outer frame with gold trim.
- Parchment, leather, and stone surfaces.
- Blizzard-style buttons, tooltips, progress bars, scrollbars.
- Readable, high-contrast text over every background.
- Clear visual difference between completed and unfinished content.
- Restrained decoration; content comes first.

**Art policy:** Azerfolio uses its own artwork, created in the style of native Blizzard art and bundled with the addon. Native client textures (frames, buttons, icons, fonts) may be used where they exist and fit. Zone illustrations are custom. Every zone without finished art shows one consistent fallback.

### 4.2 Behavior

- `/azerfolio` and `/azf` toggle the window.
- Launcher: a minimap button and/or the addon compartment. Left-click toggles; tooltip names the addon.
- Draggable; resizable between a minimum and maximum size.
- Remembers position, size, and last tab. First launch opens Overview.
- Escape closes it.
- Never performs protected actions; safe to open in combat.
- Recovers if saved position is off-screen after a resolution or UI-scale change.

### 4.3 Gamepad

Azerfolio is **gamepad first**: the owner plays with a controller. Everything must be usable without a mouse, and the mouse must keep working too.

- **Open/close:** `/azf`, the minimap button or the addon compartment. No key binding (removed 2026-11-08: the owner doesn't need one).
- **Focus:** the D-pad moves a clearly visible gold focus highlight between controls in a predictable order (rows and columns, not guesswork). Focus starts on a sensible element on each screen and is restored when returning to a screen.
- **Buttons:**

  | Input | Action |
  |---|---|
  | D-pad / left stick | Move focus |
  | A (bottom face) | Activate the focused control |
  | B (right face) | Back (Zone Detail → catalogue), otherwise close the window |
  | LB / RB | Previous / next main tab |
  | LT / RT | Scroll the current list (page up/down). The right stick stays with the camera in this client (owner, 2026-11-08) |
  | Y / X | Context actions (e.g. toggle card/list view, open filters), shown in a hint bar |

- **Hint bar:** the bottom of the window shows which buttons do what on the current screen.
- **No hover-only information:** anything a mouse user sees on hover (tooltips, percentage explanations) also appears when the control has gamepad focus.
- **Size:** focusable controls are large enough to read and to show a focus border clearly.
- **Text entry:** zone search must be usable from a controller (the client's on-screen keyboard if available), and every filter must be reachable without typing.
- **Combat:** custom gamepad input is released in combat so it never blocks gameplay.

### 4.4 Navigation

- Bottom tabs: Overview, Zones. No tabs for features that don't exist yet.
- Zone Detail has a back button to the catalogue.
- Returning to the catalogue restores search, filters, sort, display mode, and scroll position.

## 5. Overview tab

### 5.1 Character header

Name, race, class, faction, level, XP progress toward next level (when not max level), and portrait or class icon.

### 5.2 Tracked Completion

A prominent percentage of *supported, eligible* objectives completed. It is labeled as tracked completion, not "completion of WoW", and lists which categories it includes (v1: exploration only).

From v1.1 the headline is the **equal-weight average of the included categories' percentages** (§7.7), so a large category (quests) doesn't drown a small one (exploration); each category's own percentage follows the calculation below.

Calculation (per category):
- Numerator: objectives the game confirms complete.
- Denominator: eligible objectives plus locked-but-achievable ones.
- Excluded: permanently unavailable objectives, unknown objectives, categories without a complete catalogue.
- Each objective counted once, even if it appears in several zones or categories.

If no meaningful percentage can be produced, show a labeled unavailable state.

### 5.3 Stat cards

| Card | Shows | Click opens |
|---|---|---|
| Zones | Fully completed zones / applicable tracked zones, % | Zones tab filtered to completed |
| Exploration | Discovered / total exploration objectives, % | Zones tab |
| Current Zone | Name, tracked %, remaining objectives | That Zone Detail |
| Quests (v1.1) | Confirmed completed / known eligible, coverage note | Zones tab |

A card without a meaningful value shows an explanatory empty state, never a bare `0%`.

From v1.1 the Exploration, Quests and Flight paths cards are rows of the Tracked completion panel (one row per category: done / counted, %, a gilded bar; a category without data says why), and Zones is its last row (mockups/DESIGN.md, Overview step 6).

### 5.4 Zone highlights

Current zone, recently visited zones, zones closest to completion, recently completed zones. Each entry shows name and a compact progress indicator, and opens Zone Detail.

### 5.5 Suggested next objectives

A few unfinished objectives chosen by fixed rules, in this order:
1. Unfinished objectives in the current zone.
2. Objectives in zones close to completion.
3. Other eligible unfinished exploration objectives.
4. (v1.1) Eligible unfinished quests.

From v1.1 each suggested zone lists its Next up picks (§7.1: areas to discover, ready quests nearest your level, a flight path to discover), and the reason names what's left per category ("Current zone · 5 areas · 26 quests left").

Each suggestion shows objective name, zone, category, a short reason ("2 left in Westfall"), and opens its detail. Never suggest objectives that are unavailable or of unknown eligibility. Show an empty state if nothing qualifies.

### 5.6 Recent milestones (removed in v1.1)

Removed on 2026-11-08 (owner: not interesting enough), with the Overview's Activity panel and the milestone history and baseline behind it; existing saved history is deleted on load (character schema 2). The original requirement, for reference:

Recently detected accomplishments: a new area discovered, a zone's exploration completed, (v1.1) a quest completed, a zone fully completed.

- Stored in SavedVariables, history size capped.
- Progress that existed before the addon first saw the character is a baseline, not a milestone. No invented timestamps.
- Deduplicated across reloads.

## 6. Zones tab

### 6.1 Display modes

| Illustrated cards (default) | Compact list |
|---|---|
| Large zone art, consistent aspect ratio | Small art or icon |
| Name, level range, faction applicability | Name, % |
| Tracked %, progress bar, exploration progress | Compact progress bar, key metrics |
| Completion emblem when justified | Dense; easy to compare many zones |

Both modes use the same data, filters, and sort. The chosen mode is saved. The card grid adapts to window width without cards becoming unreadably small.

### 6.2 Filters

- **Faction relevance:** Relevant to my character (default) / All zones. Never hides contested or neutral zones from either faction.
- **Completion:** All / Incomplete / Completed. Zones with unknown status are not counted as "Incomplete".
- **Level:** All / Appropriate for my level.
- **Search:** case-insensitive name match.

### 6.3 Sorting

Recommended progression order (default, by level range then stable tie-break), alphabetical, highest completion, lowest completion, closest to completion. Zones without completion data sort separately from zones with a confirmed 0%.

### 6.4 Behavior

Scrollable; tooltips explain each percentage; helpful empty state when filters match nothing; state preserved across navigation.

Zone relevance (should this zone be listed for my character?) and objective eligibility (can I complete this objective?) are calculated separately.

## 7. Zone Detail

### 7.1 Header

Large zone illustration, name, level range, faction applicability, tracked %, progress bar, back button.

From v1.1 Zone Detail opens on a **zone dashboard**: the zone's completion (§7.7) as the player's faction **war banner**, hoisted up its pole as the zone fills, one badge per category, claimed at the top (owner's choice 2026-11-08; `mockups/DESIGN.md`), and one tile per category; each tile opens that category's full page (checklists, storylines, map). B steps back page by page.

### 7.2 Exploration section

Total, completed, remaining, %, and a checklist. Each row: location name, completed/incomplete indicator, and extra info or map guidance where available. All completion comes from game data, never from tracking the player's movement.

### 7.3 Quest section (v1.1)

Total known eligible, completed, remaining, % when valid, checklist (name, level, status, eligibility, prerequisites and chain where known), and a coverage indicator. Repeatable quests never count toward totals. Mutually exclusive quests are handled. If quest data is incomplete, say so.

Layout (design review 2026-11-08): **Ready now** first (quests the character can take now, with the client's quest difficulty colours relative to their level), then **storylines** (chains built from QuestieDB's prerequisite and next-quest links, one track per chain, done / ready / locked nodes; single quests share one row). Finished storylines fold into one row. Quests the character can't do are hidden behind one toggle. The coverage note (catalogue, repeatables and unknowns left out, with counts) is a quiet footer. Chains, groups and difficulty come from the quest system; the UI only draws them.

### 7.4 Objective states

Each objective has two independent properties:

| Completion | Meaning |
|---|---|
| Complete | Game confirms it is done |
| Incomplete | Game confirms it is not done |
| Unknown | Cannot be determined |

| Eligibility | Meaning |
|---|---|
| Eligible | Can be done now |
| Locked | Not yet, but will become possible (level, prerequisite) |
| Unavailable | Never possible for this character (faction, class, exclusive choice) |
| Unknown | Cannot be determined |

The UI derives what it shows from these two. Unknown never silently counts as complete or incomplete.

### 7.5 Completion claims

- **Tracked Objectives Complete:** every included, eligible, tracked objective in the zone is verified complete.
- **Zone Complete:** the above, *and* every category the zone should have has a complete catalogue.

Never show or celebrate Zone Complete when any category has unknown or partial coverage.

### 7.7 Zone completion (v1.1)

Decided 2026-11-08 (owner): a zone's completion is holistic, not exploration alone.

- **Categories:** exploration, quests, flight paths (§8.5); more later (§3 Later). Each has its own completed / counted / % from the progression service.
- **Applies or not:** a category applies to a zone only when the zone has at least one counted objective in it for this character. A category that doesn't apply (no quests in Deadwind Pass, every Durotar quest Horde-only for an Alliance character, no Explore achievement in a capital) is **left out**, never shown as 0%. Capitals with quests become tracked zones through their quests.
- **Combined %:** the equal-weight average of the applying categories' percentages, computed by `ns.Progression`. A category with partial coverage still shows its own % and ring; its line says what's unchecked ("2 unchecked"), and "Zone Complete" is withheld.
- **Zone Complete (gold medallion):** every applying category at 100% with complete coverage (§7.5).
- **Display:** Zone Detail shows the zone standard (§7.1); catalogue cards and list rows show one thin bar per category instead of the exploration pips (the pips stay inside the exploration section); the Overview uses the same combined % and progress art. Catalogue states (complete, in progress, untouched), filters and sorts use the combined state.
- **Celebrations:** one per category ("Elwynn Forest Explored", "... Quests Complete", "... Flight Paths") and a larger one for Zone Complete.

### 7.8 Zone reputation (v1.3)

Decided 2026-11-08 (owner):

- Zone Detail shows the **zone's own factions** (§8.9) with the character's standing: reaction (Hated … Exalted, the client's labels), a bar with progress into the current reaction (standing − its threshold, out of the next threshold − the current one), and "Not met yet" for factions not in the character's reputation list. At war is shown.
- **Not a completion category:** it never counts toward the combined % (§7.7), the war banner, claims or celebrations.
- **Hidden** when the zone has no zone faction for this character (most leveling zones and the capitals).
- Quest reputation amounts are QuestieDB's base values; if shown, they are labeled as approximate, never as exact gains.
- Layout comes from the mockup step.
- Exalted is gold, here and on the Reputation tab (owner, 2026-11-09): gold isn't reserved for completion, and completion keeps its own cues (✓, %, the claimed pennant, celebrations).

### 7.9 Reputation tab (v1.4)

Approved 2026-11-09 (owner); layout and gamepad map in `mockups/DESIGN.md` "Reputation tab". Like §7.8, it's progress beside completion, never part of it: no %, no claims, no celebrations.

- **Factions:** every faction the game returns data for (§8.10), on this character's side.
- **Groups** with sticky headers ("n of m met"), from where most of a faction's raising quests are: Home, Zones, Dungeons & raids, Battlegrounds, Professions, Class and events, No known quests.
- **Toolbar:** All / Met / Not met yet; sort By group, Closest to next (met factions first, "n to <next>" in place of n / m), A–Z.
- **Standing strip:** how many factions sit at each reaction, and "Met n of m · Exalted n of m".
- **Row:** the main zone's art (or a glyph), name, tags (Not met yet, At war, Rival of, "+n today" for a gain seen this session, Watched), reaction, the reputation bar, n / m (none at Exalted).
- **Faction page:** the main zone's art in the banner; the bar with the **reach** (where the one-time quests you haven't done and can do would take you, at QuestieDB's base amounts, capped at Exalted, always "about"; repeatables mentioned, not counted); the game's description; for rivals both factions side by side; **Where to raise it**, one row per place with its kind, quest count and ~amount; class quests for another class dimmed as "not for you". A on a zone opens that zone's faction page (§7.8), or its dashboard when the faction isn't one of its zone factions; dungeons and raids wait for the Dungeons tab. A faction with no known quests says so.
- **Watch:** X sets or clears the faction shown on the experience bar, when the client allows it; otherwise the action isn't offered.
- Not built: rank-up toasts, rewards per standing, kill reputation (no data source).

### 7.10 Class tab (v1.5)

Approved 2026-11-09 to 11-13 (owner, five design rounds); layout, art and gamepad map in mockups/DESIGN.md "Class tab". Progress beside zone completion, never part of it.

- **The road:** the character's class quests for their class and side, as stops on a painted map strip (one per class and side, 18 in all), top to bottom in the order they're walked. Road stops and optional **side paths** (they count, but the road doesn't wait for them). A stop is a quest chain; a step is a quest. Another race's version of a stop, repeatable turn-ins and raid or dungeon class quests (gear turn-ins, Dire Maul books) aren't on the road.
- **The map:** the road runs along the painting's own lane, gilded as far as the character's level (XP included); each road stop sits at its level, the road's end at 60. A finished stop wears the class's gold coin, an unfinished one the same coin dulled (a red dotted ring when it's open now). Names on a parchment cartouche, the stop's quest pips in a row under it. **You** is the character's portrait in a brass ring on the road at their level.
- **Abilities:** a milestone stone at the road's edge at each level where the class trainer has new abilities: a gilded rune when all are learned, a red rune when something can be trained now, blank while later. Stones close together merge ("Levels 8–10"). The list comes from the trainer (§8.11); until the character opens it once, the tab says so and shows no stones.
- **The plaque:** the road's title, "Road n of m · Side paths n of m", "n to train", and the one next thing to do.
- **The pane:** the selected stop: its zone art, reward, where it starts, level, the places it travels to, lead-ins (not counted), numbered steps (sub-quests in place, not counted), done or not from the game; the road's end lists every stop; a milestone lists its levels' abilities (learned / train now / later, cost).
- **Gamepad:** up and down walk the road (stops and stones in road order), left and right reach a stop's side paths, LT/RT jump stop to stop, A opens the steps, B goes back.

### 7.11 Professions tab (v1.6)

Approved 2026-11-13 to 11-14 (owner, two design rounds); layout and gamepad map in mockups/DESIGN.md "Professions tab". This character's professions only. A profession is **Mastered at skill 300**; recipes are a **collection that never counts** toward it, and nothing here is part of zone completion.

- **The rail:** Primary, then Secondary; per profession its coin, name, "skill / cap" and a dot for the most urgent state. The status, most urgent first: Mastered (gold) > At cap · train <rank> (red: skill-ups are lost) > Train <rank> now (orange) > n recipes to learn (orange) > Open your <profession> window once (grey).
- **Views** (Y cycles; only those a profession has): **Journey**, **Recipes**, **Gather** (Mining, Herbalism, Skinning, Fishing).
- **Journey** (one screen, no scroll): the banner with rank title and skill, and the **skill road** in its foot: 1 to 300, gilded to the skill, hatched past the current cap behind a closed gate, a stone at each rank's training skill (Journeyman 50, Expert 125, Artisan 200: trained, train now, later), You at the skill, the profession coin at 300 (dull until mastered). Below, **Next up** (up to 5: the next rank and its trainers, recipes waiting at a trainer, known recipes that still give skill, the node you're on and the next, "Open your window once") and **Tracked** (the game's tracked recipes with ingredients).
- **Recipes:** filters with counts, **For you now** by default (learn now, known and still giving skill, opening in the next 25 points), then All, Known, Learn now, Later, No known source; in levelling order. A list and the focused recipe beside it: state, learn at / gives skill until, every known source, ingredients with have / need and where to get each, Track / Untrack in the game's objective tracker (X).
- **Counts:** only recipes with a known source (seen at a trainer, or a recipe item in QuestieDB) are counted; the rest, Season of Discovery included, are listed under No known source and not counted. No % for recipes.
- **Gather:** the hand-curated node table, labelled as a guide, not game data.
- **Overview:** a Professions panel ("n of m mastered", one row per profession with its skill bar and status; A opens the tab on it).
- **Gamepad:** the rail, A into the page, Y view, LT/RT sections, X Track, B back.

### 7.6 Map actions

Where supported: open the world map to this zone, show where an exploration objective is, tooltips on objectives.

## 8. Data architecture

### 8.1 Layers

1. **Game-state readers** — wrap client APIs; the only code that calls them.
2. **Static catalogues** — bundled Lua data (zones, exploration, later quests).
3. **Eligibility** — decides eligibility state per objective for this character.
4. **Completion** — decides completion state per objective.
5. **Aggregation** — one progression service computes all counts, percentages, coverage.
6. **Presentation** — UI pages and components; read-only consumers of aggregation results.

### 8.2 Objective model

Each objective has: stable ID, category, zone, display name, optional description, eligibility requirements, completion state, data source, coverage classification, optional map location, optional grouping/prerequisites. Providers fill only the fields relevant to them.

### 8.3 Exploration

Implemented by Azerfolio; no dependency on other addons. Prefer native completion signals (achievement/Legacy criteria) over inferring from revealed map textures. The approach is decided by the Phase 1 findings (see the implementation plan). If an objective can't be verified, its completion is unknown.

The bundled exploration catalogue uses game IDs (not names) as keys, is versioned, and is generated reproducibly where practical.

### 8.4 Quests (v1.1)

- Completion: client quest-completion APIs.
- Catalogue: QuestieDB (installed on this machine). Azerfolio reads it **at runtime as an optional dependency** through its public API (decided 2026-11-08; `docs/research/quest-data.md`). Without QuestieDB, quests are shown as unavailable with the reason; nothing else changes. Note that QuestieDB is GPL-3.0 licensed; either approach is fine for personal use.
- Must handle faction, class, profession, prerequisites, exclusive choices, repeatables, breadcrumbs.
- A partial catalogue is never presented as exhaustive.

### 8.5 Flight paths (v1.1)

Requested by the owner 2026-11-08. One objective per flight path node in a zone that the character's faction can use; complete when the client confirms the character knows it. Flight paths count toward the zone's % like any category (owner, 2026-11-08). **Catalogue:** the client's own node list (`C_TaxiMap.GetTaxiNodesForMap`: every node on the continent, both factions, with `name` "Place, Zone" and `faction`); the node's zone comes from the name's zone suffix and its position, with a small curated override table (e.g. "Stormwind, Elwynn" belongs to Stormwind City); `zzOLD…` leftovers are ignored. **Knowledge:** the flight master's list, below. Probe results (`/azfdiag taxi`, 2026-11-08) [verified-ingame]: `C_TaxiMap.GetTaxiNodesForMap(zone)` returns the whole continent's nodes for any zone (36 Eastern Kingdoms, 38 Kalimdor), each with `nodeID`, `name` ("Sentinel Hill, Westfall"), `faction`, `atlasName` and `isUndiscovered`, which was false for every node, Horde ones included, on a level-10 Alliance character: it does **not** say what the character knows. So knowledge must come from the flight master's list (`TaxiNodeGetType`, only while the flight map is open; Forever opens it through `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` type 5, not `TAXIMAP_OPENED`), remembered per character. With the map open (Stormwind): 18 Alliance and neutral Eastern Kingdoms nodes, `CURRENT` / `REACHABLE` = known (Stormwind, Sentinel Hill), `DISTANT` = not known. Details: `docs/research/client-capabilities.md` § Flight paths. A continent whose flight master list hasn't been seen yet has **unknown** flight paths (category shown as "Visit a flight master to check"), never "not discovered". If the client can't confirm knowledge, the category is unavailable, never guessed.

### 8.9 Reputation (v1.3)

Research and probe: `docs/research/reputation.md`.

- **Zone factions** are derived at runtime from the `reputationReward` of the zone's quests (QuestieDB composed view, same zone mapping as quests). No hand-curated table. Rule: count the quests that raise each faction; leave out home factions (capitals, races, Alliance/Horde) and battleground factions; keep a faction with ≥ 5 such quests in the zone, or ≥ 3 when the zone holds ≥ 50% of the faction's quests in all zones. Offline, this gives 21 zones.
- **Standing** from `C_Reputation.GetFactionDataByID` (Forever has no classic faction globals). "Met" = the faction is in `C_Reputation`'s index list. Factions the game returns no data for (the other side's) are left out.
- Without QuestieDB there are no zone factions, so the section is hidden, the same as quests being unavailable.
- Refresh on `UPDATE_FACTION`, debounced. Standing is read from the game, never stored. Azerfolio never changes the player's reputation UI state (collapsed headers, watched faction) by itself; the one exception is the Reputation tab's Watch, which the player asks for (§7.9).

### 8.10 Reputation tab data (v1.4)

- **All factions:** every ID `C_Reputation.GetFactionDataByID` returns data for, met or not (38 IDs for Gideon in the probe). Left out by side: the other side's battleground factions (510, 729, 2798; the game returns them at Hated) and the Alliance / Horde headers. "Met" as in §8.9.
- **Sources** from each quest's QuestieDB `reputationReward`, sorted by where the quest is: zone, dungeon, raid, battleground, profession, class or event. A faction's group is where most of its raising quests are. Rivals as in §8.9 (negative rewards).
- **Reach:** standing plus the base amounts of the one-time quests that raise it and are neither done nor ruled out for this character (the quest eligibility of §8.4), capped at Exalted. Repeatables are counted separately. Shown as approximate.
- **Gains this session:** standing changes between `UPDATE_FACTION` reads while the addon runs; kept in memory only, never saved, nothing at login.
- **Watched:** `isWatched` from the faction data; set with `C_Reputation.SetWatchedFactionByID`, guarded (existence check and `pcall`) until verified in game.
- Pure rules (groups, reach, sorts) live in `Systems/ReputationRules`; the UI only shows their results.

### 8.11 Class tab data (v1.5)

- **The roads:** Data/ClassJourneys.lua, curated from QuestieDB (qdb.lua class) and checked against it (qdb.lua class check): per class and side, the stops in order, their quests (any-one-of versions, alternative routes), lead-ins and sub-quests shown but not counted, race masks where QuestieDB is too broad. Quest names, levels, starters and eligibility come from QuestieDB and the quest rules (§8.4); done or not from the game's completed-quest list. Unknown stays unknown.
- **The rules** (Systems/ClassJourneyRules, pure): a step is done by any of its quests and left out when none is for the character; a stop's state (done, in progress, open now, later, not known); the road's counts and the next thing to do; where a level sits on the road.
- **Abilities:** the class trainer lists every service with its level and learned / available / later state, but only while its window is open; Azerfolio reads it on TRAINER_SHOW / TRAINER_UPDATE (all filters on, restored after) and keeps it per character (AzerfolioCharDB.trainer). The spellbook lists no future spells in this client (docs/research/class-spells.md). Systems/ClassTrainerRules (pure) sorts new abilities from new ranks and gives each level's state.
- **The art:** each strip's lane is traced into Data/StripPaths.lua (	ools/trace-strip.ps1); stop positions per road are Theme.classStrip.

### 8.12 Professions data (v1.6)

- **Skills:** GetProfessions / GetProfessionInfo (skill, cap, skill line) at any time; GetProfessionInfoBySkillLineID reads 0/0 until a window opens and isn't used. Ranks: Apprentice cap 75, Journeyman 150 (train at 50), Expert 225 (125), Artisan 300 (200) (Warcraft Tavern's Forever guide; training skills match the trainers seen). Character-level requirements aren't shown: the trainer reports 0.
- **Recipes:** each profession window's whole list (recipe, name, learned, grey-at skill, category), read when it opens and kept per character; learned state kept live with IsPlayerSpell. Until a profession's window has been opened once, its recipes are unknown.
- **Learn-at skill and trainer recipes:** a profession trainer's list (GetTrainerServiceSkillReq), recorded per character when its window opens.
- **Sources** (Systems/ProfessionRules decides, Systems/Professions reads): seen at a trainer; or a QuestieDB recipe item matched by name and profession subclass (vendors with zone, drops, containers, quests); otherwise No known source. Without QuestieDB only trainer sources are known.
- **Ingredients:** GetRecipeSchematic (window shut, any recipe), have from C_Item.GetItemCount; where to get each: another recipe of the profession, a gathering node, QuestieDB vendors or drops, or unknown.
- **Tracking:** the game's own (GetRecipesTracked, SetRecipeTracked). Azerfolio changes it only on the player's X.
- **Gathering:** Data/Gathering.lua, hand-curated and unofficial, with provenance per row (like Data/Zones.lua); conflicting or unknown skills stay marked as such (open check G1).

### 8.6 Aggregation output

For any scope (objective set, zone, category, overall): completed, eligible, locked, unavailable, unknown counts; percentage if valid; coverage (`complete` / `partial` / `unavailable`); categories included.

### 8.7 Events

Listen for zone changes, exploration changes, quest changes, and login. Invalidate only affected cached results. Provide `/azf refresh` for cases where events are missing.

### 8.8 Persistence (SavedVariables)

Window position/size, last tab, Zones display mode, filters and sort, recently visited zones, flight masters' lists, preferences. Versioned schema with migrations. Completion state is read from the game, not stored.

## 9. Technical requirements

- Target the actual Forever client. Do not assume Retail or Classic APIs exist; check, and degrade gracefully when an API is missing or returns unexpected data.
- Modular Lua files; the plan defines the layout.
- Reuse frames; efficient scrolling; cache expensive calculations.
- Errors in one section must not stop the window from opening.
- Debug mode (off by default) reports map and zone IDs, exploration criteria, eligibility decisions, aggregate counts, missing data, API failures.
- English only. Strings shown to the player that the client provides (zone and area names) come from the client.

## 10. UX requirements

- Clear progress indicators, high-contrast text, consistent spacing, tooltips for non-obvious numbers.
- On completing a tracked objective: refresh affected indicators and summaries, optionally show a subtle notification (configurable).
- Satisfying completion visuals (gold accent, emblem, full bar) when justified; no celebration when coverage is incomplete.
- Distinct visible states for: no matching zones, no tracked objectives, loading, data unavailable, partial coverage, fully complete.

## 11. Privacy

Runs entirely in the game client. No accounts, network, cloud, companion apps, or uploads.

## 12. Acceptance criteria (v1)

All v1 criteria met 2026-11-08 (evidence: `docs/testing.md` § Phase 8).

### Window
- [x] `/azerfolio` and `/azf` toggle the window; launcher button works.
- [x] Every screen and action is usable with the gamepad alone (spec §4.3), with a visible focus highlight and hint bar.
- [x] Draggable, resizable; position and size persist.
- [x] Overview and Zones tabs work; Escape closes.
- [x] Cohesive native Warcraft style.

### Overview
- [x] Accurate character info.
- [x] Tracked completion with listed categories; unavailable data clearly marked.
- [x] Current-zone progress with link to Zone Detail.
- [x] Suggestions only from eligible, known objectives.
- [x] Milestones recorded only for progress observed after baseline. (v1; removed in v1.1, §5.6.)

### Zones
- [x] Applicable zones listed; illustrated cards by default; compact mode; mode persists.
- [x] Faction and completion filters, search, sorting.
- [x] Zone Detail opens; back restores catalogue state.

### Exploration
- [x] Azerfolio's own tracking; no other addon required.
- [x] Verified per-objective states; discovered vs. undiscovered correct.
- [x] Refreshes when a new area is discovered.
- [x] Missing data never produces a false completion claim.

### Quality
- [x] No Lua errors in normal use.
- [x] No noticeable performance impact during gameplay.
- [x] SavedVariables survive reloads and restarts; invalid settings recover to defaults.
- [x] Usable across supported window sizes and UI scales.
- [x] Automated tests pass for pure-logic modules.

### v1.1 Quests
- [x] Reads quest completion; shows known quests per zone.
- [x] Eligibility rules applied; repeatables and unavailable quests excluded from totals.
- [x] Incomplete coverage clearly labeled; no unverifiable total presented as complete.
- [x] Zone completion combines the applying categories (§7.7); a category that doesn't apply is left out, not 0%.
- [x] Flight paths per zone, confirmed by the client, or shown as unavailable with the reason.

### v1.4 Reputation tab
- [ ] Lists every faction the game returns data for on this side; met factions match the game's Reputation window.
- [ ] Filters, sorts and the standing strip's counts agree with the list.
- [ ] Reach and amounts come from QuestieDB and are marked approximate; without QuestieDB the tab still shows standing, with sources unavailable.
- [ ] Watch sets the experience bar's faction in game, or isn't offered.
- [ ] Exalted is gold on the tab and in the zone ledger; nothing touches combined zone completion.

## 13. Definition of v1 success

A player opens Azerfolio and immediately understands their progress through Azeroth. They browse illustrated zones, switch to the compact list, open a zone, see verified exploration progress, and find what's left. When they discover a new area, the numbers update correctly. It looks good, it's standalone, and its numbers can be trusted.
