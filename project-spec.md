\# Azerfolio — Product Specification



\*\*Version:\*\* 0.2 — Revised Draft  

\*\*Target:\*\* World of Warcraft: Forever  

\*\*Initial release:\*\* v1 — Overview + Zones  

\*\*Project type:\*\* Standalone World of Warcraft addon  

\*\*Primary purpose:\*\* A visually polished completionist dashboard and progression journal.



\## 1. Product Vision



\*\*Azerfolio\*\* is a comprehensive progression and completionist dashboard for World of Warcraft: Forever.



It gives players one central place to understand their progress through Azeroth, discover what remains unfinished, and work systematically toward completing everything available to their character.



The core experience answers three questions:



1\. What have I completed?

2\. What remains to be completed?

3\. What should I work on next?



Rather than presenting an overwhelming database of game content, Azerfolio organizes progression into attractive, understandable dashboards and actionable checklists.



The interface should feel like a natural extension of Blizzard's own UI, drawing inspiration from the Encounter Journal, Adventure Guide, and traditional Warcraft art direction.



\*\*Product tagline:\*\* Every adventure. Every achievement. Every step.



\## 2. Core Design Principles



\### 2.1 Completion First



Progress is the central focus of every screen. Players should quickly understand what they've completed and what remains.



\### 2.2 Beautiful Native Presentation



Azerfolio should look and feel like an official WoW interface.



Use native Blizzard-style frames, textures, typography, icons, gold accents, parchment backgrounds, and illustrated content wherever possible.



Avoid generic web-dashboard aesthetics.



\### 2.3 Actionable Information



Progress statistics must lead to the objectives they summarize.



Clicking a completion category, zone, or suggested milestone should reveal the underlying objectives whenever supported.



\### 2.4 Standalone Architecture



Azerfolio must function without other addons.



Third-party integrations may be added later but must remain optional.



\### 2.5 Accurate Progress



Never claim an objective is complete without game confirmation or an explicitly supported user-controlled completion state.



Unknown and unsupported data must be visibly distinguished from verified data.



\### 2.6 Character-Aware Completion



Objective eligibility should consider relevant restrictions, including:



\- Faction

\- Race

\- Class

\- Level

\- Profession

\- Quest prerequisites

\- Mutually exclusive quest choices

\- Other applicable restrictions



Objectives unavailable to a character must not prevent that character from reaching 100% completion.



\### 2.7 Modular and Expandable



The architecture must support future Class, Professions, Collections, Dungeons, Legacy, and other progression categories without major redesign.



\### 2.8 Performance



Progress updates should be event-driven where possible, with cached data and selective refreshes.



Avoid unnecessary repeated scans of large databases.



\---



\## 3. Initial Release Scope



The initial release contains two main navigation tabs:



\- \*\*Overview\*\*

\- \*\*Zones\*\*



The Zones tab includes a separate Zone Detail view.



\### 3.1 Primary v1 Features



\- Main Azerfolio window

\- Native-style UI and bottom tab navigation

\- Character information header

\- Overview progression dashboard

\- Zone catalogue

\- Illustrated zone cards

\- Compact zone list mode

\- Faction-aware zone filtering

\- Zone detail pages

\- Native exploration tracking

\- Exploration objective checklists

\- Quest completion tracking where reliable data is available

\- Progress percentages and statistics

\- Suggested next objectives

\- Recently recorded milestones

\- Saved UI preferences



\### 3.2 Implementation Priority



Exploration tracking is the first progression category that must work completely.



Quest tracking follows once exploration and the core UI are functioning reliably.



Azerfolio should not display fabricated progress values to compensate for missing data.



\### 3.3 Future Features



The architecture must accommodate, but v1 will not implement:



\- Class progression

\- Class quests and spell unlocks

\- Profession progression and recipes

\- Collections

\- Dungeon and raid progression

\- Rare enemies and world bosses

\- Legacy progression

\- Reputations

\- Account-wide completion

\- Cross-character comparisons

\- Manual custom goals

\- Advanced recommendation systems



\---



\## 4. Main Window



\### 4.1 Visual Design



The window should resemble a polished Blizzard interface.



Visual characteristics:



\- Ornate Warcraft-style outer frame

\- Gold trim and native-looking decorations

\- Parchment, leather, and stone-inspired surfaces

\- Clear typography and readable text contrast

\- Illustrated headers and zone artwork

\- Blizzard-style buttons, tooltips, progress bars, and scrollbars

\- Consistent visual hierarchy and spacing

\- Minimal unnecessary decoration

\- Strong visual distinction between completed and unfinished content



Prefer native UI assets before introducing custom artwork.



Custom artwork may be used where existing game assets are inadequate, but it must be bundled with the addon and meet applicable usage requirements.



\### 4.2 Window Behavior



The main window must:



\- Open and close using `/azerfolio`.

\- Support `/azf` as a shorter alias.

\- Open through a minimap button.

\- Be draggable.

\- Be resizable within reasonable minimum and maximum dimensions.

\- Remember its position and dimensions.

\- Remember the last selected main tab.

\- Open on the Overview tab for first-time users.

\- Close when Escape is pressed, where supported by the client.

\- Avoid protected gameplay actions.

\- Remain responsive and usable at supported UI scales.



\### 4.3 Navigation



Navigation tabs appear along the bottom edge of the window.



The initial tabs are:



1\. Overview

2\. Zones



Selecting a tab changes the main content area without reopening the window.



Zone Detail is a subview of Zones, not a separate main tab.



A back button returns from a Zone Detail page to the zone catalogue.



The catalogue should preserve its search query, filters, sorting, display mode, and scroll position when navigating back.



\---



\## 5. Overview Tab



The Overview tab is the default entry point for Azerfolio.



Its purpose is to summarize progress and help the player identify their next objective.



\### 5.1 Character Header



Display:



\- Character name

\- Race

\- Class

\- Faction

\- Current level

\- Current experience progress toward the next level, when applicable

\- Character portrait or class icon, subject to client support



The header should integrate naturally with the native Warcraft appearance.



\### 5.2 Overall Progress Summary



Display a prominent \*\*Tracked Completion\*\* summary.



This represents the portion of supported and eligible objectives completed by the character, not a claim that the player has completed every activity in WoW Forever.



Initially, the overall progress model should use only categories for which a sufficiently complete and validated objective catalogue exists.



The calculation must:



\- Count confirmed completed objectives.

\- Include eligible unfinished objectives.

\- Include locked objectives that remain achievable later.

\- Exclude objectives definitively unavailable to the character.

\- Avoid treating unknown completion states as incomplete.

\- Avoid mixing unsupported categories into the denominator.

\- Avoid double-counting objectives shared by multiple zones or categories.



Display which categories contribute to the total.



If the available data cannot produce a meaningful percentage, show a clearly labeled incomplete or unavailable state instead.



\### 5.3 Progress Statistics



The Overview should display a set of summary cards.



Initial cards:



\*\*Zones\*\*

\- Fully completed zones

\- Total applicable tracked zones

\- Percentage of applicable tracked zones completed



\*\*Exploration\*\*

\- Discovered exploration objectives

\- Total supported exploration objectives

\- Exploration completion percentage



\*\*Quests\*\*

\- Confirmed completed quests

\- Total known eligible quests, when reliable

\- Completion percentage when meaningful

\- Coverage status when incomplete



\*\*Current Zone\*\*

\- Current zone name

\- Tracked completion percentage

\- Remaining known objectives

\- Quick navigation to Zone Detail



Each card should be clickable when it has a corresponding detail view.



Cards without a meaningful value must have a helpful empty state instead of displaying `0%` misleadingly.



\### 5.4 Zone Progress Highlights



Provide a section highlighting relevant zones.



Potential entries:



\- Current zone

\- Recently visited zones

\- Zones closest to completion

\- Recently completed zones



Each entry should show the zone name and a concise progress indicator.



Clicking an entry opens the corresponding Zone Detail page.



\### 5.5 Suggested Next Objectives



Display a small number of meaningful unfinished objectives.



For v1, use deterministic rules rather than complex recommendation logic.



Prioritization:



1\. Known unfinished objectives in the current zone.

2\. Objectives in zones near completion.

3\. Eligible unfinished exploration objectives.

4\. Known unfinished quests when quest data is reliable.



Avoid recommending objectives that are unavailable or whose eligibility cannot be established.



Suggestions should include:



\- Objective name

\- Associated zone

\- Objective category

\- Brief explanation of why it is suggested

\- Click-through to supporting detail



When suggestions cannot be generated reliably, display an appropriate empty state.



\### 5.6 Recent Milestones



Show recently detected accomplishments.



Examples:



\- Discovering a new exploration area

\- Completing a zone exploration checklist

\- Completing a tracked quest

\- Reaching full tracked completion for a zone



Azerfolio may store milestone events in SavedVariables.



The milestone system must not invent timestamps for progress completed before the addon was installed.



Historical completion detected during first-time initialization should not be presented as a newly earned accomplishment.



\---



\## 6. Zones Tab



The Zones tab provides a visual catalogue of zones and their completion status.



\### 6.1 Default Zone Catalogue



The default display is \*\*Illustrated Card View\*\*.



Each zone is represented by a visually rich card featuring:



\- Zone name

\- Zone illustration

\- Recommended level range, if reliable

\- Faction applicability

\- Tracked completion percentage

\- Completion progress bar

\- Exploration progress

\- Quest progress where available

\- Fully completed indicator when justified



Zone artwork should use a consistent aspect ratio and image treatment.



The layout should adapt to the window size without creating unreadably small cards.



\### 6.2 Display Mode Toggle



Provide a prominent but unobtrusive control to switch between:



\*\*Illustrated Card View\*\*

\- Default mode

\- Large zone artwork

\- Rich presentation

\- More spacious layout



\*\*Compact List View\*\*

\- Smaller artwork or zone icon

\- Denser layout

\- Easy comparison between zones

\- More zones visible simultaneously



Both modes must use the same underlying progression data and respect the same filters and sorting.



The selected mode must be saved between sessions.



\### 6.3 Zone Filtering



Support the following filters:



\*\*Faction relevance\*\*

\- Relevant to my character (default)

\- All zones



\*\*Completion\*\*

\- All

\- Incomplete

\- Completed



\*\*Level relevance\*\*

\- All levels

\- Appropriate for current level



\*\*Search\*\*

\- Case-insensitive zone-name search



Faction filtering should not incorrectly hide contested, neutral, or cross-faction zones.



A zone's presence in the catalogue does not imply every objective in that zone is eligible for the character.



\### 6.4 Zone Sorting



Support:



\- Recommended progression order (default)

\- Alphabetical

\- Highest completion

\- Lowest completion

\- Closest to completion



Recommended progression order should use reliable level and zone metadata, with stable tie-breaking.



Zones lacking completion data must be treated separately from zones with confirmed `0%` completion.



\### 6.5 Zone Catalogue Behavior



\- Scrollable content.

\- Smooth navigation at different window sizes.

\- Consistent progress indicators.

\- Visual distinction between completed and incomplete zones.

\- Tooltips describing completion calculations.

\- Helpful empty state when filters return no zones.

\- Preserve current filters, sort, view mode, and scroll position.



\### 6.6 Zone Eligibility



The zone catalogue should use faction-aware metadata to establish likely character relevance.



Relevant zones may include:



\- Faction-specific starting zones

\- Faction-specific questing zones

\- Contested zones

\- Neutral zones

\- Shared higher-level zones



Zone applicability and individual objective eligibility must be calculated separately.



\---



\## 7. Zone Detail Page



Selecting a zone opens its detailed progression report.



\### 7.1 Zone Header



Display:



\- Large zone illustration

\- Zone name

\- Level range

\- Faction applicability

\- Tracked completion percentage

\- Overall completion progress bar

\- Back navigation to Zones



The illustration should complement the journal's visual style.



\### 7.2 Progress Categories



The initial categories are:



\*\*Exploration\*\*

\- Total known eligible exploration objectives

\- Number completed

\- Number remaining

\- Percentage complete

\- Expandable or scrollable checklist



\*\*Quests\*\*

\- Total known eligible quests where reliable

\- Confirmed completed quests

\- Remaining known eligible quests

\- Completion percentage when valid

\- Quest checklist

\- Coverage indicator when the database is incomplete



Additional categories can appear in later versions without changing the overall layout structure.



\### 7.3 Exploration Checklist



Each exploration objective should display:



\- Location name

\- Completion state

\- Appropriate completed or incomplete indicator

\- Additional information where available

\- Map navigation or location guidance when supported



Exploration progress must come from real game data, not manually inferred player movement.



\### 7.4 Quest Checklist



Where supported, each quest entry should display:



\- Quest name

\- Quest level where known

\- Completion status

\- Eligibility or availability status

\- Prerequisites where known

\- Relevant quest chain information where available



Quest totals must account for eligibility and mutually exclusive objectives.



Repeatable quests must not inflate completion totals.



Incomplete quest database coverage must be clearly communicated.



\### 7.5 Objective States



The progression system must distinguish between:



\*\*Complete\*\*

\- Verified as completed by the game.



\*\*Incomplete\*\*

\- Verified eligible but not completed.



\*\*Locked\*\*

\- Not currently accessible, but expected to become available through future progression.



\*\*Unavailable\*\*

\- Definitively ineligible due to faction, class, mutually exclusive choices, or other permanent restrictions.



\*\*Unknown\*\*

\- Completion or eligibility cannot be determined reliably.



Unknown objectives must not silently count as incomplete or completed.



\### 7.6 Completion Indicators



A zone can only display a full-completion indicator when every included eligible tracked objective is verified complete and the required objective catalogue has sufficient coverage.



If a category has unknown or incomplete coverage, the interface must avoid implying the entire zone has been completed.



A zone may display \*\*Tracked Objectives Complete\*\* independently from a broader full-zone completion claim.



\### 7.7 Zone Navigation



Where supported, provide:



\- Open world map for the selected zone.

\- Show location information for exploration objectives.

\- Display relevant objective tooltips.

\- Navigate back to the zone catalogue.



Optional waypoint integration is deferred.



\---



\## 8. Progression Data Architecture



\### 8.1 Overall Design



Azerfolio must separate:



1\. Game-state collection

2\. Static objective catalogues

3\. Eligibility evaluation

4\. Completion evaluation

5\. Progress aggregation

6\. Presentation



UI components must not contain independent implementations of progression calculations.



\### 8.2 Unified Objective Model



Each objective should have a stable identifier and expose the following information when available:



\- Unique objective ID

\- Category

\- Associated zone

\- Display name

\- Description

\- Eligibility requirements

\- Completion state

\- Data source

\- Data confidence or coverage classification

\- Optional navigation metadata

\- Optional grouping or prerequisite information



The model should support future non-zone categories.



\### 8.3 Exploration Tracking



Exploration tracking must be implemented directly by Azerfolio.



There must be no mandatory dependency on Legacy Forever.



The implementation should investigate Forever's native exploration and Legacy criteria capabilities.



Preferred approach:



1\. Identify supported exploration-related client APIs.

2\. Determine reliable completion signals.

3\. Build a versioned zone exploration catalogue.

4\. Map exploration objectives to zone identifiers.

5\. Query the player's completion state.

6\. Aggregate completed and eligible objectives.

7\. Refresh affected views when exploration changes.



Where reliable client criteria are available, prefer those over approximations derived from map appearance.



If an objective cannot be verified, classify its completion state as unknown.



\### 8.4 Exploration Database



Ship bundled Lua data containing exploration objective definitions.



Each entry should use stable game identifiers wherever possible.



Names alone should not be used as identifiers when game IDs are available.



The database should include relevant zone and objective metadata.



Data generation should be reproducible where practical.



Database versions should be tracked to accommodate future Forever updates.



\### 8.5 Quest Tracking



Quest tracking should use the client's supported quest-completion APIs.



A bundled catalogue may be required to determine total eligible quests.



The system must account for:



\- Faction requirements

\- Class requirements

\- Profession requirements

\- Quest prerequisites

\- Mutually exclusive choices

\- Repeatable quests

\- Breadcrumb quests

\- Quest availability changes



A quest should only count toward a verified total when its eligibility and completion can be reliably determined.



A partial quest catalogue must not be represented as exhaustive.



\### 8.6 Aggregation Rules



A single progression service should calculate:



\- Completed objectives

\- Eligible objectives

\- Locked objectives

\- Unknown objectives

\- Excluded objectives

\- Completion percentages

\- Coverage information



Percentages should be based on verified, applicable objective sets.



Each aggregate should identify the categories included and whether the result is complete, partial, or unavailable.



\### 8.7 Updates and Events



The addon should listen to supported game events for:



\- Zone changes

\- Exploration changes

\- Quest completion or updates

\- Character initialization

\- Other relevant progression changes



Use selective refreshes and cached results.



Where events are missing or unreliable, provide a safe refresh mechanism.



Avoid expensive polling and full-database recalculation.



\### 8.8 Persistence



Use SavedVariables to store:



\- Window position and size

\- Last selected tab

\- Zones display mode

\- Zone filters and sorting

\- Recent milestone history

\- Optional cached metadata

\- Addon preferences



SavedVariables should be versioned to support future schema migrations.



Do not persist redundant character-state data unless necessary.



\---



\## 9. Technical Requirements



\### 9.1 Client Compatibility



\- Target World of Warcraft: Forever.

\- Confirm actual client interface version and available APIs before implementation.

\- Use Lua syntax and APIs supported by the Forever client.

\- Avoid unsupported Retail-specific assumptions.

\- Gracefully handle absent or changed APIs.



\### 9.2 Architecture



Use modular Lua files.



Recommended high-level modules:



\- Initialization and lifecycle

\- Configuration and SavedVariables

\- Character information

\- Zone metadata

\- Exploration catalogue

\- Quest catalogue

\- Eligibility engine

\- Progression engine

\- Progress event handling

\- Main window

\- Overview page

\- Zones catalogue

\- Zone Detail page

\- Shared UI components



The implementation plan may refine the exact file structure.



\### 9.3 UI Performance



\- Avoid unnecessary frame recreation.

\- Reuse UI elements where practical.

\- Support efficient scrolling.

\- Cache expensive progression calculations.

\- Recalculate only affected data when possible.

\- Avoid per-frame progression scans.

\- Support UI scaling and window resizing.



\### 9.4 Error Handling



The addon must handle:



\- Missing zone data

\- Unsupported APIs

\- Invalid or absent client responses

\- Incomplete objective catalogues

\- Missing artwork

\- Unsaved or outdated settings

\- Data schema changes



Errors should fail gracefully without preventing the entire journal from opening.



\### 9.5 Diagnostics



Provide an optional debug mode for development.



Diagnostic output should help identify:



\- Current map and zone IDs

\- Exploration criteria

\- Quest completion state

\- Eligibility decisions

\- Aggregate counts

\- Missing objective data

\- API failures



Debug output must be disabled by default.



\---



\## 10. User Experience Requirements



\### 10.1 Readability



\- Clear progress indicators.

\- High-contrast text.

\- Appropriate UI scaling.

\- Consistent spacing.

\- Readable checklist entries.

\- Tooltips for non-obvious statistics.



\### 10.2 Feedback



When a tracked objective is completed:



\- Refresh the relevant progress indicator.

\- Update corresponding dashboard summaries.

\- Record a milestone when appropriate.

\- Optionally display a subtle completion notification.



Notifications must be configurable and should avoid excessive interruptions.



\### 10.3 Completion Satisfaction



When all verified objectives in a category or zone are completed, provide an appropriately satisfying visual state.



Examples:



\- Gold completion accent

\- Checkmark or completion emblem

\- Completed progress bar

\- Optional celebratory notification



Do not celebrate a full-zone completion when coverage is unknown or incomplete.



\### 10.4 Empty and Unavailable States



The UI should distinguish between:



\- No matching zones

\- No tracked objectives

\- Data loading

\- Data unavailable

\- Partial catalogue coverage

\- Fully completed objectives



Never substitute misleading zeros for unknown data.



\---



\## 11. Privacy and Data Handling



Azerfolio runs locally inside WoW.



The initial release must not require:



\- External user accounts

\- Cloud services

\- Network requests

\- External companion software

\- Personal data uploads



SavedVariables remain local to the player's WoW installation.



\---



\## 12. Explicitly Out of Scope for v1



\- Class tab

\- Professions tab

\- Collections tab

\- Legacy tab

\- Dungeon and raid encounter journal

\- Rare enemy completion system

\- Full account-wide aggregation

\- External data synchronization

\- Automated route optimization

\- Advanced goal recommendation engine

\- Sharing completion between players

\- Manual custom objective creation

\- Gear and talent build recommendations

\- Dependencies on other addons



\---



\## 13. Acceptance Criteria



The release is considered successful when the following conditions are met.



\### Main Window

\- \[ ] Azerfolio opens via `/azerfolio` and `/azf`.

\- \[ ] Minimap button opens the addon.

\- \[ ] Window is draggable and resizable.

\- \[ ] Window position and dimensions persist.

\- \[ ] Overview and Zones tabs work.

\- \[ ] UI matches a cohesive native Warcraft visual style.

\- \[ ] Escape closes the window where supported.



\### Overview

\- \[ ] Shows accurate character information.

\- \[ ] Shows useful tracked completion statistics.

\- \[ ] Distinguishes verified progress from unavailable data.

\- \[ ] Displays current-zone progress when available.

\- \[ ] Supports navigation to Zone Detail.

\- \[ ] Shows relevant unfinished objectives when available.

\- \[ ] Records new milestones without inventing historical events.



\### Zones

\- \[ ] Shows applicable zones.

\- \[ ] Uses illustrated cards by default.

\- \[ ] Supports compact list mode.

\- \[ ] Persists the chosen display mode.

\- \[ ] Supports faction and completion filtering.

\- \[ ] Supports search and sorting.

\- \[ ] Opens a Zone Detail page.

\- \[ ] Preserves catalogue state when navigating back.



\### Exploration

\- \[ ] Uses Azerfolio's own exploration tracking.

\- \[ ] Does not require Legacy Forever.

\- \[ ] Displays verified exploration progress.

\- \[ ] Shows individual exploration objectives.

\- \[ ] Correctly distinguishes discovered and undiscovered locations.

\- \[ ] Refreshes when exploration progress changes.

\- \[ ] Handles missing data without false completion claims.



\### Quest Tracking

\- \[ ] Reads supported quest completion state.

\- \[ ] Shows known quests where supported.

\- \[ ] Handles relevant eligibility rules.

\- \[ ] Excludes repeatable and permanently unavailable quests from inappropriate totals.

\- \[ ] Clearly indicates incomplete database coverage.

\- \[ ] Does not display unverifiable totals as complete.



\### General Quality

\- \[ ] No required third-party addons.

\- \[ ] No excessive performance impact during normal gameplay.

\- \[ ] No blocking Lua errors during supported workflows.

\- \[ ] SavedVariables survive reloads and restarts.

\- \[ ] Missing data is handled gracefully.

\- \[ ] UI remains usable across supported window sizes and scales.



\---



\## 14. Development Validation Requirements



Before implementing completion calculations, verify the Forever client's actual capabilities.



Initial technical investigation should determine:



1\. Exact client interface version and supported Lua environment.

2\. Available exploration APIs and completion signals.

3\. Available exploration or Legacy criteria data.

4\. Feasibility of generating a complete exploration database.

5\. Available quest-completion APIs.

6\. Availability and completeness of quest catalogues.

7\. Availability of native zone artwork and interface components.

8\. Reliability of relevant in-game update events.



These findings should be documented and used to finalize the implementation strategy.



\---



\## 15. Definition of v1 Success



A player opens Azerfolio and immediately understands their progression through Azeroth.



They can browse beautifully illustrated zones, switch to a compact list when desired, select a zone, inspect verified exploration progress, and identify specific unfinished objectives.



When they discover a new area or complete a supported objective, their progression updates accurately.



The experience should be visually satisfying, intuitive, standalone, and reliable.



The addon does not need to track every activity in WoW Forever on day one. It does need to provide an excellent foundation for eventually doing so.



\*\*The long-term goal is to make Azerfolio the definitive completionist dashboard for World of Warcraft: Forever.\*\*

