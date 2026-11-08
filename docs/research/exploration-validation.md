# Exploration validation (Phase 1)

Status: **validated** (2026-11-07). Approach A accepted.
Test zone: Elwynn Forest (map 1429, achievement 776). Characters: Gideon (level 9 Human Paladin, Alliance) and Thragor (Horde, Durotar).
Reproduce with `luajit tools/diag-report.lua events` / `zone` / `criteria 776`.

## Result

Exploration objectives and their completion come from the zone's **"Explore <zone>" achievement criteria**:

- **Objective list (denominator):** `GetAchievementNumCriteria(achID)` and `GetAchievementCriteriaInfo(achID, i)`. Elwynn has 12.
- **Stable objective ID:** `criteriaID` (10th return of `GetAchievementCriteriaInfo`). Unique per area.
- **Completion:** the `completed` return (3rd).
- **Name:** the criteria string (1st), already localized by the client.

Explored map textures are not used. They don't correspond to criteria (6 textures for 5 done areas; textures in zones never visited).

## Discovery test

Two new areas were discovered on Gideon. Both were detected, and each flipped exactly one criterion: [verified-ingame]

| Area | criteriaID | Events (GetTime) | Criteria done | Textures |
|---|---|---|---|---|
| Forest's Edge | 1150 | `CRITERIA_UPDATE` + `UI_INFO_MESSAGE` @12257.807 (same frame), then `PLAYER_XP_UPDATE` + `MAP_EXPLORATION_UPDATED` @12258.161 | 5 → 6 | 6 → 7 |
| Brackwell Pumpkin Patch | 1153 | `CRITERIA_UPDATE` + `UI_INFO_MESSAGE` @12510.228, then `PLAYER_XP_UPDATE` + `MAP_EXPLORATION_UPDATED` @12510.704 | 6 → 7 | 7 → 8 |

- `UI_INFO_MESSAGE` args: `412, "Discovered: <area name>"`.
- The criterion was already complete when the diagnostic re-read it 1 s after the first event. Exactly when, within that second, it flipped isn't measured.
- After `/reload`, the baseline read back the new state correctly; no repeated diff. [verified-ingame]
- The game's own discovery message matched the criterion that flipped, both times. That is the cross-check, since the Achievements window doesn't open on Forever. [verified-ingame]

## Refresh strategy

- Trigger a refresh on `CRITERIA_UPDATE` and `MAP_EXPLORATION_UPDATED`, debounced (about 0.5 s) so one discovery causes one refresh.
- `CRITERIA_UPDATE` carries no arguments and fires for unrelated criteria too (8 times in one short session). The debounce makes that cheap.
- On refresh, re-read criteria only for the current zone's achievement. A discovery always happens in the zone the player is standing in. Recompute only that zone's summary and the totals.
- `UI_INFO_MESSAGE` with "Discovered:" isn't needed as a trigger, but it's a handy debug signal.
- `RECEIVED_ACHIEVEMENT_LIST` does **not** fire on `/reload` (Phase 5 trace, 2026-11-07) [verified-ingame]. Azerfolio reads every zone 3 s after `AZF_READY` as well; after a reload that read found all 43 zones readable [verified-ingame].
- Initial read: after `PLAYER_ENTERING_WORLD`; achievement data was readable 3 s after it. `RECEIVED_ACHIEVEMENT_LIST` fires about 2 s after it on login. Read on that event when it arrives, with `PLAYER_ENTERING_WORLD` + delay as a fallback.

## Zone coverage

| Group | Zones | Exploration status |
|---|---|---|
| Questing zones with an achievement | 43 (40 classic + Mount Hyjal, Riverglades, Shen'dralas) | Tracked, complete catalogue |
| Capitals | Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity | No achievement. Show "not tracked". Note: Elwynn's list includes a "Stormwind City" criterion |
| Zephras Isle | maps 2521 / 2665 | No achievement. Show "not tracked" |
| Rollups | Explore Eastern Kingdoms / Kalimdor / Azeroth | Criteria type 8 point at child achievements. Usable for continent summaries, but count from zone criteria to avoid double counting |

## Proposed catalogue

Generated from the dump by a `tools/` script, committed as `Azerfolio/Data/Exploration.lua`:

```lua
-- Generated from client 1.60.1.70862. Do not edit.
Exploration = {
  dataVersion = 1,
  clientBuild = 70862,
  zones = {
    [1429] = { achievementID = 776, criteria = { 1146, 1147, 1148, ... } }, -- Elwynn Forest
  },
}
```

- The catalogue stores IDs only. Names and completion are read live from the client.
- Storing `criteriaID`s lets us detect when a patch changes a zone's criteria. If live criteria don't match the catalogue, mark the zone "uncertain" in debug and trust the game (plan §8).
- Should the catalogue store `criteriaID` → index? `GetAchievementCriteriaInfoByID(achID, criteriaID)` exists; a quick in-game probe in Phase 5 decides whether to use it.

## Per-character test

Achievement data read on each character, same account: [verified-ingame]

| Achievement | Gideon (Alliance) | Thragor (Horde) |
|---|---|---|
| Explore Elwynn Forest (776) | 7/12 | 0/12 |
| Explore Durotar (728) | 0/11 | 1/11 (Valley of Trials) |

**Criteria completion is per character.** Azerfolio can present it as the character's own progress.

## Edge cases

- **Faction restrictions:** the game marks no criterion ineligible. Elwynn's 12 criteria, including "Stormwind City", are `eligible = true` on a Horde character, and Durotar's include "Orgrimmar". [verified-ingame] Following the honest-data rule, Azerfolio counts every criterion as eligible and doesn't invent faction exclusions. Whether a zone is *relevant* to a faction is a separate, zone-level setting (spec §6.4).
- **Capitals inside zone lists:** each starting region's achievement includes its capital as a criterion (Elwynn → Stormwind City, Durotar → Orgrimmar). Enemy capitals are hard but not impossible to explore. Shown as normal objectives.
- **Criteria flags/type changes in patches:** handled by the catalogue check above.
- **Indoors / micro maps:** discovery happened outdoors. `GetBestMapForUnit` inside the Lion's Pride Inn still returned Elwynn (1429).

## Recommendation

Proceed with approach A (achievement criteria). All Phase 1 done-when items pass:

- [x] Discovering a new area is detected in game.
- [x] Elwynn's total (12) is confirmed. The game's "Discovered" messages matched the criteria that flipped; the Achievements window isn't available.
- [x] Computed completed count matches the game (5 → 6 → 7).
- [x] `/reload` keeps results correct.
- [x] Strategy for other zones documented (coverage table above).
