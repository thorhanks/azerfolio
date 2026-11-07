# Client capabilities — WoW Forever

Evidence levels: **[verified-ingame]**, **[verified-files]**, **[external]**, **[unverified]** (see plan §2.2).

Sources: installed files (2026-11-07), and the first `AzerfolioDiag` dump (2026-11-07, character Gideon, level 9 Human Paladin, Alliance, realm "CAMWOW US1 Realm 10 RP"). Reproduce the numbers with `luajit tools/diag-report.lua <section>`.

## Summary

- The client runs the **modern retail addon API** on Lua 5.1, with classic-era content plus some Forever-only zones.
- **Exploration is solved at the data level:** every questing zone has an "Explore <zone>" achievement. Its criteria are the zone's named areas, each with a stable `criteriaID` and a done flag. That gives us both the list of areas and completion from native data (Phase 1 approach A).
- **Explored map textures can't be used for exploration:** they don't match criteria counts and appear in zones the character never visited.
- Quest completion: `C_QuestLog.IsQuestFlaggedCompleted` and `C_QuestLog.GetAllCompletedQuestIDs` work. The legacy `GetQuestsCompleted` does not exist.
- The client loads both **PNG and TGA** from addon folders. Native parchment, gold borders, Encounter Journal art and class icons are available.
- No Forever- or Legacy-specific `C_*` API is exposed to addons. The Legacy UI exists, but only through Blizzard frames.

## Client

| Fact | Value | Evidence |
|---|---|---|
| Product flavor | `wowf` | [verified-files] `.flavor.info` |
| Version / build | 1.60.1 / 70862 (built Nov 6 2026) | [verified-ingame] `GetBuildInfo()` |
| Addon interface | `16001` | [verified-ingame] `GetBuildInfo()` 4th return |
| Lua | Lua 5.1 | [verified-ingame] `_VERSION` |
| Project ID | `WOW_PROJECT_ID = 18` = `WOW_PROJECT_CAMELOT` (`MAINLINE` = 1, `CLASSIC` = 2) | [verified-ingame] |
| Locale | enUS | [verified-ingame] |
| Max level | 60 (`GetMaxPlayerLevel()`; global `MAX_PLAYER_LEVEL` is nil) | [verified-ingame] |
| API surface | 272 `C_*` namespaces: the full modern retail set, including `C_Secrets`, housing and `C_EncounterJournal` | [verified-ingame] |

## Exploration

### Achievements

- 46 exploration achievements: 43 zones and 3 rollups (Explore Eastern Kingdoms 62353, Explore Kalimdor 62355, Explore Azeroth 62053). [verified-ingame]
- Zone achievements are in category 14777 (Eastern Kingdoms) and 14778 (Kalimdor). Rollups are in 15607. [verified-ingame]
- Each zone achievement's name is "Explore <map name>". Each matches exactly one map by name. [verified-ingame]
- Forever-only zones with achievements: Mount Hyjal (62356, map 2482), Riverglades (62354, map 2548), Shen'dralas (63684, map 2652). [verified-ingame]

### Criteria

`GetAchievementCriteriaInfo(achID, i)` returns, for zone achievements: [verified-ingame]

| Field | Value |
|---|---|
| name | Area name (e.g. "Goldshire") |
| type | `43` (explore area) for every zone criterion. Rollups use `8` (achievement), with assetID = child achievement ID |
| completed | boolean |
| quantity / reqQuantity | 1/1 when done, 0/1 when not |
| assetID | **Not an area ID.** Names don't match `C_Map.GetAreaInfo(assetID)`; e.g. Goldshire → "Zuuldaia Ruins". Probably a world-map overlay ID [unverified]. Don't use it for names |
| criteriaID | Unique and nonzero for every criterion; e.g. Elwynn 1146–1157, Riverglades 116887–116898. **This is the stable objective ID** |
| eligible | `true` for all criteria seen |
| flags | 0 |

Criteria counts per zone range from 1 (Moonglade) to 27 (Stranglethorn Vale). The full list is in the dump (`tools/diag-report.lua explore`).

Elwynn Forest (776) has 12 criteria, 5 done on Gideon: Jerod's Landing, Northshire Valley, Goldshire, Fargodeep Mine, Crystal Lake. One criterion is "Stormwind City", so the city counts toward Elwynn's exploration. [verified-ingame]

### Maps

- Maps 1–3000 scanned: 60 maps. 1 world, 4 continents, 51 zones, 4 orphans. **No dungeon or micro maps** in that range. [verified-ingame]
- Zone maps with no explore achievement: the six capitals (1453–1458) and Zephras Isle (2521, plus orphan 2665). [verified-ingame]
- `C_MapExplorationInfo.GetExploredMapTextures(mapID)`: Elwynn returns 6 textures while 5 criteria are done. Alterac Mountains and Moonglade return 1 texture each with 0 criteria done, on a character who has never been there. **Not usable for completion.** [verified-ingame]
- Texture entries have `fileDataIDs`, `offsetX/Y`, `textureWidth/Height`, `hitRect`, `isShownByMouseOver`, `isDrawOnTopLayer`. They could help draw a map highlight later. [verified-ingame]
- `GetExploredAreaIDsAtPosition` returned area 87 "Goldshire" at the player's position. [verified-ingame]
- `GetMapOverlayInfo` and `GetNumMapOverlays` (classic) don't exist. [verified-ingame]

### Events

All candidate events registered without error, including `MAP_EXPLORATION_UPDATED`, `CRITERIA_UPDATE`, `CRITERIA_EARNED`, `CRITERIA_COMPLETE`, `ACHIEVEMENT_EARNED`, `RECEIVED_ACHIEVEMENT_LIST` and `UI_INFO_MESSAGE`. [verified-ingame]

Which of them fire on discovery, and in what order, is **not yet observed** (no discovery happened during the dump). Phase 1.

### Open exploration questions

1. Which events fire on discovery, and does the criterion flip immediately?
2. **Per-character or account-wide?** The rollup says "on a single character", but it's unknown whether criteria `completed` reflects the current character or the account. Test on the second character (Thragor).
3. Does the in-game Achievements window show Elwynn 5/12 for Gideon (cross-check)?
4. Are any criteria faction-restricted (`eligible` false) on a Horde character?

## Quests

| API | Status | Evidence |
|---|---|---|
| `C_QuestLog.IsQuestFlaggedCompleted(id)` | Works. Gideon: 783, 7, 33, 15, 18, 3903 done; 5261 not done | [verified-ingame] |
| `C_QuestLog.GetAllCompletedQuestIDs()` | Works, returned 64 IDs | [verified-ingame] |
| `GetQuestsCompleted`, global `IsQuestFlaggedCompleted` | Do not exist | [verified-ingame] |
| `C_QuestLog.GetTitleForQuestID(id)` | Returned nil for completed quests (likely not cached). Use the QuestieDB catalogue for names | [verified-ingame] |
| `C_QuestLine`, `C_QuestHub`, `C_QuestInfoSystem` | Namespaces exist; not yet probed | [verified-ingame] |

## UI framework

- Available: `CreateScrollBoxListLinearView`, `CreateScrollBoxListGridView`, `CreateDataProvider`, `ScrollUtil`, `Mixin`, `CreateFromMixins`, `UISpecialFrames`, `AddonCompartmentFrame`, `Settings`, `OpenWorldMap`, `ToggleWorldMap`, `WorldMapFrame`, `SetPortraitTexture`. [verified-ingame]
- `SetPortraitToTexture` doesn't exist. [verified-ingame]
- `LibStub` exists globally because other addons embed it. Azerfolio must not rely on that. [verified-ingame]
- Templates that exist: `BackdropTemplate`, `ButtonFrameTemplate`, `PortraitFrameTemplate`, `DefaultPanelTemplate`, `BasicFrameTemplate(WithInset)`, `InsetFrameTemplate`, `PanelTabButtonTemplate`, `WowScrollBox`, `WowScrollBoxList`, `MinimalScrollBar`, `SearchBoxTemplate`, `InputBoxTemplate`, `UICheckButtonTemplate`, `WowStyle1DropdownTemplate`, `WowStyle1FilterDropdownTemplate`, `UIPanelButtonTemplate`, `UIPanelCloseButton`, tooltip templates. [verified-ingame]
- `CharacterFrameTabButtonTemplate` doesn't exist. Use `PanelTabButtonTemplate` for bottom tabs. [verified-ingame]
- `EncounterJournal` is not loaded and `EncounterJournal_LoadUI` doesn't exist. `AchievementFrame_LoadUI` exists. [verified-ingame]

## Art

Test frame screenshot and `SetTexture` results: [verified-ingame]

| Texture | Result |
|---|---|
| Addon `.tga` | Displays (fileID -24) |
| Addon `.png` | Displays (fileID -23) |
| Path with no extension | Loads the `.tga` |
| `Interface\EncounterJournal\UI-EJ-BACKGROUND-Default` | Displays (521743), dungeon painting |
| `Interface\QuestFrame\QuestBG` | Displays (530420), parchment |
| `Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal` | Displays (130661), parchment |
| `Interface\DialogFrame\UI-DialogBox-Gold-Border` | Displays (131076), gold border pieces |
| `Interface\TargetingFrame\UI-Classes-Circles` | Displays (237669), class icon sheet |

Consequence: the art pipeline can ship **PNG** directly, with no TGA conversion needed. Always include the file extension in paths.

## Gamepad

The owner uses the client's gamepad UI (button prompts, "Focus/Unfocus Interface", "Previous/Next Frame"). [verified-ingame, screenshot 2026-11-07]

**Blizzard SmartNavigation** (source: `Gethe/wow-ui-source`, branch `forever`, `Interface/AddOns/Blizzard_GamepadSmartNavigation/SmartNavigation.lua` and `Utility.lua`): [external, read 2026-11-07]
- Panels become navigable only through `SmartNavigation:HandlePanelOpen(panel)`. Calling `:Show()` on a frame does nothing. That method and most setters (`SetTargetButtonForFrame`, `SetScrollFrameForFrame`, `RefreshButtonGroups`, `SetUseGridNavigation`) return early unless `issecure()`. **Addon code can't register a panel.**
- Focus candidates: `Button`/`EditBox`, or frames with `OnMouseUp`/`OnMouseDown`, or frames marked through `SmartNavigation_MarkFrameFocusable`. Directions are chosen by angle and distance (45° cone), or by a grid mode.
- Bindings: D-pad navigates, bottom face clicks, right face closes (`SmartNavigationCloseHandler`, then `frame.CloseButton`), right stick scrolls. **There are no LB/RB bindings.**
- It hooks `CreateFrame` and rescans registered panels when children are created under them. ItemTree's comments say this tainted protected calls.

**How installed addons do it** [verified-files]:
- GatherLite builds an addon-owned input layer. It has a child frame with `EnableGamePadButton(true)`/`EnableGamePadStick(true)` and `OnGamePadButtonDown`/`Up` scripts, its own focus list and highlight border, and calls `owner:FocusGamepad()` / `UnfocusGamepad()`. It is active only when `InputUtil.IsGamepadUIEnabled()` is true and the player is out of combat. Its comment: never register with Blizzard's frame manager or binding stack, because their listeners call protected action-bar APIs.
- ItemTree avoids creating frames under Blizzard panels while they're open, because of the `CreateFrame` hook.

**Probe results** (`/azfdiag pad`, Gideon, out of combat, 2026-11-07): [verified-ingame]
- `C_GamePad.IsEnabled()` = true, `GamePadEnable` CVar = 1, `InputUtil.IsGamepadUIEnabled()` = true. The globals `SmartNavigation`, `GamepadMode` and `InputUtil` exist.
- An addon frame with `EnableGamePadButton(true)` received **every** button through `OnGamePadButtonDown`/`Up`. 66 presses, 0 errors.
- Button names (equal to the `GAMEPAD_*` constants, so code should use the constants):

  | Constant | Name | Xbox |
  |---|---|---|
  | `GAMEPAD_DPAD_TOP/BOTTOM/LEFT/RIGHT` | `PADDUP`, `PADDDOWN`, `PADDLEFT`, `PADDRIGHT` | D-pad |
  | `GAMEPAD_FACE_BOTTOM/RIGHT/LEFT/TOP` | `PAD1`, `PAD2`, `PAD3`, `PAD4` | A, B, X, Y |
  | `GAMEPAD_SHOULDER_LEFT/RIGHT` | `PADLSHOULDER`, `PADRSHOULDER` | LB, RB |
  | `GAMEPAD_TRIGGER_LEFT/RIGHT` | `PADLTRIGGER`, `PADRTRIGGER` | LT, RT |
  | `GAMEPAD_STICK_LEFT/RIGHT_PRESS` | `PADLSTICK`, `PADRSTICK` | stick clicks |
  | `GAMEPAD_MENU_LEFT/RIGHT` | `PADBACK`, `PADFORWARD` | View, Menu |

- `EnableGamePadStick(true)` delivered `OnGamePadStick` for the **left** stick (`"Left"`, x/y in −1…1). No right-stick samples were recorded. Either the owner didn't move it during the probe, or the camera keeps it. **Open:** confirm in Phase 4. Fallback: scroll with LT/RT (page) and the D-pad (move focus, auto-scroll).
- `FocusGamepad`/`UnfocusGamepad` don't exist as frame methods (GatherLite's are its own). `SetPropagateKeyboardInput` exists; `SetPropagateGamepadInput` doesn't.
- `GAMEPAD_SMARTNAV_CURSOR_COLOR_CODE` = `|cffffe600` (Blizzard's focus cursor yellow). Worth matching for a native feel.
- The modifiers `GAMEPAD_MOD_LEFT` = SHIFT and `GAMEPAD_MOD_RIGHT` = CTRL mean the owner's bindings can be combos (for the open/close key binding).

## Native frame style (Forever) — research for the restyle (2026-11-07)

The owner wants Azerfolio to match the native Forever UI (reference: Reputation frame: gold frame with outer glow, round portrait, dark brown panes, right-side LB/RB icon tabs, yellow chevron on the focused row, floating round A/B hint box).

From `Gethe/wow-ui-source`, branch `forever` [external, read 2026-11-07]:
- `PortraitFrameMixin:SetBorder(layoutName)` applies a NineSlice layout (`Blizzard_SharedXML/PortraitFrame.lua`). The published `PortraitFrameTemplate` layout uses **Metal** atlases (`UI-Frame-PortraitMetal-CornerTopLeft`, `UI-Frame-Metal-*`), not gold. So the gold frame seen in game is either a client-side atlas override or an unpublished layout. **Unknown until probed in game.**
- Inset panes: `InsetFrameTemplate` layout, atlases `UI-Frame-Inner*`.
- Right-side tabs: `RightSideTabTemplate` (`Shared/Tabs/RightSideTab.xml`), spellbook-tab textures. The LB/RB Character tabs were not found in the source.
- Focus pointer: `SmartNavigationPointerTemplate` uses atlas `gamepad-largecursor-white` tinted `GAMEPAD_SMARTNAV_CURSOR_COLOR`, bobbing ±4 px. Probably the yellow chevron [unverified].
- Hint box: `Blizzard_GamepadSharedUtility/InputPrompts/InputPrompts.xml` (`InputPromptOneIconWithTextTemplate` etc., mixin `InputPromptMixin`); the legend box is likely `InputLegendPromptGroup.lua` / `FrameControlsManager.lua` (not read). Round glyph atlases not found yet.
- CharacterFrame / ReputationFrame XML is not in the published branch.

**In-game probe** (`/azfdiag skin`, Gideon, screenshot `WoWScrnShot_110726_165420.jpg`) [verified-ingame]:
- `PortraitFrameTemplate` renders the native Forever chrome on this client: bronze-gold edges, round portrait ring top-left (`PortraitContainer.portrait` + `SetPortraitTexture` works), title bar with gold title (`SetTitle`), red-gold close button. Identical to the Reputation window. So the published "Metal" atlas names draw gold here.
- `ButtonFrameTemplate`: the same chrome plus a dark inset and a bottom strip. `DefaultPanelTemplate`: the same without the portrait. `InsetFrameTemplate`: a near-black inset with a thin edge.
- `gamepad-largecursor-white` tinted yellow is the focus chevron seen beside the focused row. `gamepad-mapquestlog-cursor-diamond-gold` is a gold diamond.
- The Reputation panes are a darker, warmer brown than the template background; the yellow outer glow seen in the owner's first screenshot was absent here, so it likely marks the controller-focused frame [unverified].
- Recorded texture data (`luajit tools/diag-report.lua skin` / `skin tree`), live CharacterFrame on the Reputation tab:

  | Part | Native source | Notes |
  |---|---|---|
  | Frame | NineSlice `UI-Frame-PortraitMetal-CornerTopLeft`, `UI-Frame-Metal-*` (= `PortraitFrameTemplate`) | Draws gold on this client |
  | Controller-focus glow | `gamepad-uiframemetal-largeportrait-focus`, texture `NineSlice.GlowTexture` (1330×1044 for a 631×484 frame, BACKGROUND) | The yellow glow in the owner's first screenshot |
  | Pane backgrounds | `UI-Character-Info-General-BG` (left), `UI-Character-Info-Stat-BG` (right) | The warm dark-brown panes |
  | Pane divider | `common-framedivider` (11 px wide, OVERLAY) | |
  | Inner pane border | `common-insideframe` | |
  | Side tabs (right, 55×60) | `common-sidetab`, `-hover`, `-selected`, `-mask` | LB above, RB below |
  | List group header | `common-button-list-collapseExpand` (row), `common-button-list-minus` (icon); gold text (1, 0.82, 0) | "Alliance" row |
  | Row highlight | `charactercreate-customize-dropdown-linemouseover-side` / `-middle` | Selected/hovered row |
  | Progress bar (160×29) | `common-stat-bar-BG`, fill `common-stat-bar-white` tinted, `common-stat-bar-Mask`; also `common-stat-bar-green` | Reputation and XP bars |
  | Dropdown | `common-dropdown-textholder`, `common-dropdown-a-button` | |
  | Buttons | `common-button-square-gray-up/down`, `common-button-tertiary-normal`, `RedButton-Exit` (close) | |
  | Shoulder/trigger glyphs | `Gamepad-Xbox1-Trigger-LB/RB/LT/RT-Normal` (also `-Over`, `-Down`, `-Focus`, `-Disabled`), `Gamepad-Xbox1-View-Normal` | Face-button (A/B/X/Y) atlas names not captured yet |
  | Button legend box | `GamepadPersistentInputLegend`: NineSlice `UI-Frame-DiamondMetal-*`, `UI-World-Quest-golden-line`; footer slots `gamepad-footer-slot-bg`, `-frameneutral` | Bottom-left "A Select / B Close" box |
  | Focus pointer | `SmartNavigation.Pointer.Icon`: `gamepad-largecursor-white` | Yellow chevron |
  | Font | `Fonts\FRIZQT__.TTF` 14 everywhere | Names white, headers gold (1, 0.82, 0) |

- The CharacterFrame walk hit the 1,500-node cap (paperdoll), so some Character tabs are incomplete; the Reputation subtree (183 nodes) is complete.

Consequence: build the window on `PortraitFrameTemplate` (native chrome for free, no custom frame art) and use the native chevron for focus.

## Events seen in session

`RECEIVED_ACHIEVEMENT_LIST` fires once after login. Achievement data should be read after it, or after `PLAYER_ENTERING_WORLD` plus a delay. [verified-ingame] The event sniffer is now on and will capture discovery events in Phase 1.
