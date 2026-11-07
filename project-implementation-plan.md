\# Azerfolio — Technical Implementation Plan



\*\*Version:\*\* 1.0  

\*\*Project:\*\* Azerfolio  

\*\*Target:\*\* World of Warcraft: Forever  

\*\*Product specification:\*\* Azerfolio Product Specification v0.2  

\*\*Initial release:\*\* v1 — Overview + Zones  

\*\*Development environment:\*\* Codex, local repository, World of Warcraft: Forever client



\---



\# 1. Implementation Objectives



Build the first release of Azerfolio as a standalone World of Warcraft: Forever completionist addon.



The initial release must provide:



\- A polished, native Warcraft-style window.

\- Bottom navigation with Overview and Zones tabs.

\- An actionable character progression overview.

\- A zone catalogue featuring illustrated cards.

\- A toggle between illustrated cards and compact list mode.

\- Detailed zone completion pages.

\- Independently implemented exploration tracking.

\- Accurate exploration checklists and progress.

\- Quest tracking where supported by verified data.

\- Saved preferences, stable navigation, and reliable updates.



The architecture must support future progression systems such as Class, Professions, Collections, Dungeons, and Legacy without extensive restructuring.



\## 1.1 Development Philosophy



Prioritize:



1\. Correctness

2\. A polished player experience

3\. Maintainable architecture

4\. Performance

5\. Extensibility



Do not sacrifice data accuracy to produce attractive percentages.



Do not introduce unnecessary abstractions, external dependencies, or elaborate frameworks.



The completed addon should be straightforward to understand, maintain, and expand.



\## 1.2 Instructions for Codex



Before implementing a feature:



\- Inspect existing project files and applicable conventions.

\- Confirm the client APIs and assets required by the feature.

\- Prefer existing native Blizzard UI components.

\- Document significant discoveries and limitations.

\- Implement a small, testable vertical slice where practical.

\- Validate changes before moving to the next milestone.



Do not assume that APIs documented for Retail or Classic are necessarily available in Forever.



Do not replace missing game data with fabricated values.



If an API or game-data source is unavailable, document the limitation and implement an honest fallback.



\---



\# 2. Development Milestones



| Phase | Deliverable | Priority |

|---|---|---|

| 0 | Client and addon ecosystem investigation | Critical |

| 1 | Exploration proof of concept | Critical |

| 2 | Addon foundation and architecture | Critical |

| 3 | Native artwork and UI design system | High |

| 4 | Main window and navigation | High |

| 5 | Exploration data and progression engine | Critical |

| 6 | Zones catalogue and zone details | High |

| 7 | Overview dashboard | High |

| 8 | Quest tracking integration | Medium |

| 9 | Polish, performance, and release validation | High |



Phases may overlap when appropriate, but dependencies must be respected.



\*\*Critical sequencing rule:\*\* Do not finalize the exploration database architecture before Phase 1 validates the actual Forever client behavior.



A functioning exploration-only release is preferable to a superficially complete release containing unreliable quest progress.



\---



\# 3. Phase 0 — Technical Discovery



\## Goal



Understand the Forever client environment before creating the production architecture.



This phase is investigative, not primarily implementation-focused.



\## 3.1 Inspect the WoW Client



Determine:



\- Actual interface version.

\- Supported Lua version and syntax.

\- Available native UI APIs.

\- Supported addon events.

\- SavedVariables behavior.

\- Map and exploration systems.

\- Quest completion APIs.

\- UI texture and artwork availability.



Inspect the local client files and relevant existing addon examples.



Avoid relying solely on online documentation intended for different WoW versions.



\## 3.2 Investigate Exploration APIs



Research and test the availability and behavior of:



\- `C\_Map`

\- `C\_MapExplorationInfo`

\- `C\_AreaPoiInfo`, where relevant

\- Exploration-related events

\- Achievement or criteria APIs, where relevant

\- Forever-specific Legacy APIs, if exposed



Pay particular attention to:



`C\_MapExplorationInfo.GetExploredMapTextures(uiMapID)`



Determine exactly what it returns in Forever and whether it can reliably identify individual completed exploration objectives.



Investigate whether Legacy exploration criteria provide a more accurate completion source.



A discovered-map texture must not automatically be assumed to correspond one-to-one with a named exploration objective.



\## 3.3 Investigate Quest APIs



Determine whether the client exposes reliable methods for:



\- Checking completion of a specific quest.

\- Identifying active quests.

\- Receiving quest completion events.

\- Reading quest names and metadata.

\- Determining faction and class restrictions.

\- Identifying available quest chains.



Assess whether a complete quest catalogue can be generated or bundled independently.



\## 3.4 Investigate Existing Addons



Inspect publicly available implementations where permitted:



\- Legacy Forever

\- Questie

\- Quest Completist

\- Forever Journal

\- Other relevant Forever addons



Focus on understanding:



\- API compatibility.

\- Exploration objective identification.

\- Quest completion detection.

\- Data-generation techniques.

\- UI patterns.

\- Known limitations.



Respect licenses and do not copy protected code or data without appropriate permission and compliance.



\*\*Azerfolio must remain standalone.\*\*



\## 3.5 Investigate Native UI Artwork



Inspect Blizzard's bundled assets and UI components.



Look for usable:



\- Encounter Journal frame elements.

\- Decorative borders.

\- Parchment backgrounds.

\- Tab textures.

\- Buttons.

\- Progress bars.

\- Scrollbars.

\- Zone illustrations.

\- Map textures.

\- Character portraits.

\- Completion icons.



Test whether assets can be referenced by texture path or file ID.



Prefer native assets over custom artwork.



Do not assume that every asset visible in another WoW client exists in Forever.



\## Deliverable



Create:



`docs/research/client-capabilities.md`



Document:



\- Verified API availability.

\- Relevant API return structures.

\- Exploration and quest data findings.

\- Supported events.

\- Available UI artwork.

\- Client-specific limitations.

\- Recommended technical approaches.

\- Unresolved questions requiring in-game validation.



Classify findings as:



\- Verified in the running Forever client.

\- Confirmed by inspecting installed client files.

\- Supported by external documentation only.

\- Unverified.



\## Acceptance Criteria



\- \[ ] Actual client environment is documented.

\- \[ ] Exploration API candidates are identified.

\- \[ ] Quest completion mechanisms are identified.

\- \[ ] Native UI asset candidates are documented.

\- \[ ] No critical technical assumption is presented as verified without evidence.



\---



\# 4. Phase 1 — Exploration Proof of Concept



\## Goal



Prove that Azerfolio can independently calculate trustworthy exploration completion for an individual zone.



Use Elwynn Forest as the initial test zone.



Do not begin by implementing every zone.



\## 4.1 Build a Temporary Diagnostic Addon



Create a small diagnostic addon or development-only module that can:



\- Identify the current zone and map ID.

\- Read available exploration-related game state.

\- Inspect map texture information.

\- Inspect relevant Legacy exploration criteria.

\- Print or export diagnostic information.

\- Respond to exploration changes.



Provide a debug command such as:



`/azf debug exploration`



Avoid dumping excessively large outputs directly into chat.



The diagnostic must not be enabled by default in release builds.



\## 4.2 Test Exploration Detection



On a character with incomplete exploration:



1\. Enter a supported zone.

2\. Record the initial game-reported state.

3\. Discover a previously unexplored location.

4\. Record resulting API values and events.

5\. Compare the change with the in-game map and any native progress indicators.

6\. Reload the UI.

7\. Confirm that the completion state remains correct.



Repeat with more than one exploration objective.



Where practical, compare results between a relatively unexplored character and one with extensive exploration.



\## 4.3 Determine the Objective Model



Answer these questions:



\- How do we identify each exploration objective?

\- How do we know the full set of objectives for a zone?

\- How do we identify objective completion?

\- Does the API expose a reliable completion state?

\- Can different textures represent the same objective?

\- Can exploration objectives span multiple map layers?

\- How do we handle missing or mismatched identifiers?

\- Can we detect updates without repeatedly scanning everything?



Use stable IDs wherever possible.



\## 4.4 Evaluate Data Acquisition



Evaluate three possible approaches:



\*\*A. Native criteria-based tracking\*\*



Preferred when the client exposes a reliable, complete list of exploration criteria and their completion states.



\*\*B. Map overlay data with bundled objective mapping\*\*



Suitable when exploration textures can be reliably associated with a complete static catalogue of named objectives.



\*\*C. Hybrid approach\*\*



Combine native criteria, map APIs, and a bundled database.



Use whichever method produces the most reliable objective-level information.



The final architecture must be justified by actual findings.



\## 4.5 Validate the Denominator



The most important test is establishing a reliable total number of exploration objectives.



The system must know whether the zone has, for example, 8, 10, or 12 relevant objectives before calculating a completion percentage.



If only completed objectives can be identified, do not pretend the total is known.



Support unknown or partial coverage explicitly.



\## Deliverable



Create:



`docs/research/exploration-validation.md`



Include:



\- Tested APIs.

\- Representative outputs.

\- Tested zones and characters.

\- Evidence that exploration updates are detectable.

\- Proposed stable identifiers.

\- Proposed catalogue format.

\- Validation of completion totals.

\- Known edge cases.

\- Recommended implementation strategy.



Retain reusable diagnostics for future development.



\## Acceptance Criteria



\- \[ ] Exploration changes can be detected on the running client.

\- \[ ] Individual objectives can be identified, or limitations are documented.

\- \[ ] A full exploration total is independently validated for at least one zone.

\- \[ ] Completion counts match verified in-game state.

\- \[ ] Reloading does not corrupt progress.

\- \[ ] A viable strategy for additional zones is documented.



\*\*Decision gate:\*\* If reliable objective-level exploration tracking cannot be established, stop and revise the implementation strategy rather than proceeding with misleading completion calculations.



\---



\# 5. Phase 2 — Addon Foundation



\## Goal



Build the production addon skeleton and internal architecture.



\## 5.1 Recommended Project Structure



```text

Azerfolio/

├── Azerfolio.toc

├── Core/

│   ├── Init.lua

│   ├── Events.lua

│   ├── Config.lua

│   ├── SavedVariables.lua

│   ├── Debug.lua

│   └── Character.lua

│

├── Data/

│   ├── Zones.lua

│   ├── Exploration.lua

│   └── Quests.lua

│

├── Systems/

│   ├── ObjectiveModel.lua

│   ├── Eligibility.lua

│   ├── Progression.lua

│   ├── ExplorationTracker.lua

│   ├── QuestTracker.lua

│   ├── Milestones.lua

│   └── Recommendations.lua

│

├── UI/

│   ├── Theme.lua

│   ├── MainWindow.lua

│   ├── Navigation.lua

│   │

│   ├── Components/

│   │   ├── ProgressBar.lua

│   │   ├── StatCard.lua

│   │   ├── ZoneCard.lua

│   │   ├── ObjectiveRow.lua

│   │   ├── SectionHeader.lua

│   │   └── EmptyState.lua

│   │

│   └── Pages/

│       ├── Overview.lua

│       ├── Zones.lua

│       └── ZoneDetails.lua

│

├── Assets/

│   └── (custom assets only if needed)

│

├── Tools/

│   └── (optional development scripts)

│

├── docs/

│   ├── research/

│   ├── architecture.md

│   └── testing.md

│

└── README.md

```



This is a proposed structure rather than a requirement to create every file immediately.



Create modules as their functionality is implemented.



Avoid empty scaffolding and speculative abstraction.



\## 5.2 Initialization



Implement a predictable initialization sequence:



1\. Load addon files.

2\. Initialize configuration.

3\. Load SavedVariables.

4\. Validate and migrate settings.

5\. Initialize available data providers.

6\. Register relevant events.

7\. Initialize UI when safe.

8\. Refresh character and progression state.



Guard against missing API responses during early loading.



\## 5.3 Configuration



Create a central configuration module containing:



\- Default settings.

\- Debug mode.

\- UI preferences.

\- Notification preferences.

\- Data version metadata.

\- Feature availability.



Avoid spreading configuration constants throughout the codebase.



\## 5.4 SavedVariables



Define a versioned settings schema.



Store:



\- Window position and dimensions.

\- Last active tab.

\- Zone display mode.

\- Zone filters.

\- Search and sort preferences.

\- Recent milestones.

\- User preferences.



Decide account-wide versus character-specific ownership explicitly.



Recommended approach:



\- Account-wide UI appearance and layout preferences.

\- Character-specific milestone history and progression-related preferences.



Use the game as the source of truth for completion state whenever possible.



\## 5.5 Debug Facilities



Implement development-only commands:



\- `/azf debug`

\- `/azf debug zone`

\- `/azf debug exploration`

\- `/azf debug progress`

\- `/azf refresh`



Exact command organization may be refined.



Debug functionality must be disabled by default.



\## Deliverable



A loadable Azerfolio addon with working initialization, configuration, slash commands, and SavedVariables.



\## Acceptance Criteria



\- \[ ] Addon loads without Lua errors.

\- \[ ] `/azerfolio` and `/azf` are registered.

\- \[ ] SavedVariables persist across reloads.

\- \[ ] Debug commands work.

\- \[ ] No mandatory third-party dependencies.

\- \[ ] Core systems initialize in a predictable order.



\---



\# 6. Phase 3 — Native UI Art Direction



\## Goal



Establish the visual language before building every screen.



\*\*Use Blizzard's artwork first.\*\*



\## 6.1 Asset Selection



Use Phase 0's research to establish:



\- Main window background.

\- Outer frame and decorative borders.

\- Tab appearance.

\- Zone illustration approach.

\- Progress bar appearance.

\- Completion indicators.

\- Tooltip style.

\- Typography and colors.



Prefer referencing existing client assets.



Where suitable artwork does not exist, consider carefully selected bundled assets.



Avoid adding a large collection of custom images unnecessarily.



\## 6.2 Design Tokens



Centralize UI styling constants:



\- Colors.

\- Text styles.

\- Margins and padding.

\- Component dimensions.

\- Border sizes.

\- Progress bar appearance.

\- Card spacing.

\- Artwork aspect ratios.



All pages should share a coherent design system.



\## 6.3 Shared Components



Develop the reusable components required by v1:



\- Progress bars.

\- Completion badges.

\- Statistic cards.

\- Zone cards.

\- Objective checklist rows.

\- Section headers.

\- Empty and unavailable states.

\- Loading or initialization states.



Components should not independently calculate progression statistics.



\## 6.4 Readability



Test at multiple UI scales.



Ensure text remains legible over illustrated backgrounds.



Use background treatments where necessary to preserve contrast.



Avoid dense decoration that competes with functional content.



\## 6.5 Fallback Artwork



If a zone lacks a reliable illustration:



\- Use a consistent native-themed fallback.

\- Preserve card layout.

\- Avoid empty or broken image regions.

\- Do not substitute unrelated zone artwork.



\## Deliverable



A small UI design system and a representative styled window using verified game assets.



Document selected assets and fallback behavior in:



`docs/architecture.md`



\## Acceptance Criteria



\- \[ ] Native artwork candidates have been evaluated.

\- \[ ] Shared UI style constants exist.

\- \[ ] Core components are visually consistent.

\- \[ ] Fallback artwork works.

\- \[ ] UI remains readable at supported scales.



\---



\# 7. Phase 4 — Main Window and Navigation



\## Goal



Create the fully functioning Azerfolio window and navigation system.



\## 7.1 Main Window



Implement:



\- Azerfolio title.

\- Character header.

\- Native-style frame.

\- Dragging.

\- Resizing.

\- Close button.

\- Bottom navigation tabs.

\- Scrollable content region.

\- Proper frame layering and clipping.



\## 7.2 Slash Commands



Support:



`/azerfolio`



`/azf`



Both commands should toggle the main window.



\## 7.3 Minimap Button



Create a minimap launcher using an approach compatible with the Forever client.



Support:



\- Left-click to open or close.

\- Tooltip identifying Azerfolio.

\- Reasonable positioning and persistence.



Keep the implementation lightweight.



\## 7.4 Main Tabs



Implement two bottom tabs:



\- Overview

\- Zones



Do not show nonfunctional future tabs as though they're available.



The navigation system should make adding additional tabs straightforward.



\## 7.5 Subview Navigation



Implement Zone Details as a subview of Zones.



Opening and closing a detail page must not reset the underlying catalogue state.



Preserve:



\- Current search.

\- Filters.

\- Sort mode.

\- Display mode.

\- Scroll position.



\## 7.6 Window Persistence



Remember:



\- Position.

\- Size.

\- Last selected tab.



Opening the addon for the first time should display Overview.



Include safe defaults for missing or invalid settings.



Keep the window recoverable after resolution or UI-scale changes.



\## Deliverable



A fully usable journal shell with working navigation and representative content.



\## Acceptance Criteria



\- \[ ] Window opens from slash commands and minimap button.

\- \[ ] Tabs switch correctly.

\- \[ ] Window can be dragged and resized.

\- \[ ] Position and size persist.

\- \[ ] Escape closes the window where supported.

\- \[ ] Navigation survives repeated opening and closing.

\- \[ ] No protected-action errors during combat.



\---



\# 8. Phase 5 — Exploration Database and Progression Engine



\## Goal



Implement the first fully functional Azerfolio progression provider.



Use findings from Phase 1.



\## 8.1 Unified Objective Contract



Define a normalized internal objective representation.



Conceptual fields:



\- Stable ID.

\- Category.

\- Zone or map ID.

\- Display name.

\- Eligibility.

\- Completion state.

\- Prerequisites where relevant.

\- Source and coverage metadata.

\- Optional location metadata.



Do not require every provider to populate fields that are irrelevant to it.



\## 8.2 Objective State



Represent completion and availability separately.



Completion state:



\- Complete.

\- Incomplete.

\- Unknown.



Eligibility state:



\- Eligible now.

\- Locked but obtainable later.

\- Permanently unavailable.

\- Unknown.



The UI can derive its displayed status from these two dimensions.



This prevents confusing an unfinished objective with one that the character cannot currently access.



\## 8.3 Exploration Catalogue



Build a bundled, versioned exploration catalogue using verified game data.



Each objective should include:



\- Stable exploration objective ID.

\- Zone/map identifier.

\- Localized or resolvable name.

\- Relevant game criteria or texture mapping.

\- Optional map coordinates.

\- Applicable client-data version.



Use reliable game identifiers rather than names as keys whenever possible.



\## 8.4 Database Generation



If client-data extraction is required, create reproducible tooling.



The generation process should:



1\. Read source client data.

2\. Extract exploration objective definitions.

3\. Normalize identifiers.

4\. Associate objectives with zones.

5\. Validate mappings.

6\. Produce Lua-compatible output.

7\. Report missing and ambiguous records.



Do not introduce a runtime dependency on Python or external utilities.



Generated data should be committed with the addon.



\## 8.5 Exploration Tracker



Implement methods conceptually equivalent to:



\- Get exploration objectives for a zone.

\- Get completion status for an objective.

\- Get exploration summary for a zone.

\- Refresh exploration state.

\- Invalidate cached summaries when exploration changes.



The exact API interface can be adjusted based on technical findings.



\## 8.6 Progress Aggregation



Implement one central aggregation engine.



For each supported category and zone, calculate:



\- Completed objectives.

\- Incomplete eligible objectives.

\- Locked obtainable objectives.

\- Permanently unavailable objectives.

\- Unknown objectives.

\- Known supported objective totals.

\- Completion percentage, if valid.

\- Coverage classification.



Do not treat unknown as zero.



Exclude permanently unavailable objectives from applicable totals.



Prevent duplicate objective IDs from inflating totals.



\## 8.7 Coverage Model



A completion percentage must have clear scope.



Support at least:



\- \*\*Complete catalogue:\*\* The full applicable objective set is known.

\- \*\*Partial catalogue:\*\* Some objectives are known, but completeness is not established.

\- \*\*Unavailable:\*\* No reliable calculation can be made.



A partial catalogue may display known-objective progress, but must never imply full category completion.



Unknown completion states must prevent an unqualified 100% claim.



\## 8.8 Event Updates



Listen to verified exploration-related events.



On a relevant event:



1\. Identify affected map or zone where possible.

2\. Invalidate affected cached results.

3\. Recalculate only necessary summaries.

4\. Notify active UI components.

5\. Record newly completed milestones when appropriate.



Avoid recalculating all zones repeatedly.



\## 8.9 Initial Baseline



On first installation or first character load:



\- Read existing exploration completion.

\- Establish baseline state.

\- Do not generate fake historical completion events.

\- Do not celebrate already-completed locations as new discoveries.



Only subsequent verified transitions should create new milestone events.



\## Deliverable



A working exploration provider connected to the progression engine.



\## Acceptance Criteria



\- \[ ] Exploration data is independently owned by Azerfolio.

\- \[ ] No Legacy Forever dependency.

\- \[ ] Verified objectives display correct states.

\- \[ ] Percentages match known objective totals.

\- \[ ] Unknown states are handled correctly.

\- \[ ] Exploration updates refresh calculated progress.

\- \[ ] Reloading does not corrupt state.

\- \[ ] No fabricated historical milestones.

\- \[ ] The initial validated zone works end-to-end.



\---



\# 9. Phase 6 — Zones Catalogue and Zone Details



\## Goal



Deliver the primary user-facing completionist experience.



\## 9.1 Zone Metadata



Create a zone catalogue containing:



\- Stable map/zone ID.

\- Zone name.

\- Faction applicability.

\- Level range, when reliable.

\- Recommended progression order.

\- Artwork reference.

\- Available progression categories.

\- Coverage metadata.



Avoid guessing unsupported level ranges or faction restrictions.



\## 9.2 Zone Catalogue



Implement a scrollable collection of zone entries.



Default to illustrated cards.



Each entry displays:



\- Zone artwork.

\- Zone name.

\- Tracked progress.

\- Exploration progress.

\- Quest progress if supported.

\- Completion indication.

\- Level and faction metadata where available.



\## 9.3 Illustrated Card View



The primary visual experience.



Requirements:



\- Attractive artwork.

\- Clear progress bar.

\- Good spacing and typography.

\- Consistent card dimensions.

\- Responsive layout.

\- Obvious click affordance.

\- Full-card selection behavior.



Design the cards to evoke Blizzard's Encounter Journal.



\## 9.4 Compact List View



Provide a density-focused alternative.



Requirements:



\- Smaller artwork or icon.

\- Zone name.

\- Progress percentage.

\- Compact progress bar.

\- Relevant summary metrics.

\- Easy scanning of multiple zones.



Both modes must share the same underlying zone data.



\## 9.5 Display Mode Toggle



Provide a toggle near catalogue controls.



Save the player's preferred mode.



Do not reset search or filters when switching modes.



\## 9.6 Filtering



Implement:



\- Relevant to my faction.

\- All zones.

\- Completed.

\- Incomplete.

\- Appropriate for current level.

\- All levels.

\- Case-insensitive zone search.



Unknown completion states should not be incorrectly classified as confirmed incomplete.



\## 9.7 Sorting



Implement:



\- Recommended progression.

\- Alphabetical.

\- Highest completion.

\- Lowest completion.

\- Closest to completion.



Ensure stable ordering.



Do not mix unknown percentages into numeric ranking without explicit handling.



\## 9.8 Zone Detail Header



Display:



\- Large zone illustration.

\- Zone name.

\- Level range when available.

\- Faction relevance.

\- Tracked completion.

\- Progress bar.

\- Back button.



\## 9.9 Exploration Section



Show:



\- Completed objectives.

\- Remaining objectives.

\- Objective counts.

\- Progress percentage.

\- Checklist of individual locations.

\- Useful completion indicators.



Optional map guidance may be added when reliable metadata is available.



\## 9.10 Quest Section



Initially, include this section only when quest tracking has been implemented with useful, verified data.



If quest tracking is incomplete, prefer a concise, honest availability message or omit the section instead of filling it with placeholder rows.



\## 9.11 Navigation



Clicking a zone card opens its detail page.



Returning restores the previous catalogue state.



Support repeated transitions without frame leaks or unnecessary reconstruction.



\## 9.12 Empty States



Provide polished states for:



\- No matching zones.

\- No known objectives.

\- Unsupported zone.

\- Partial catalogue coverage.

\- Fully completed zone.

\- Unavailable progression data.



\## Deliverable



A polished, functional Zones tab with validated exploration tracking.



\## Acceptance Criteria



\- \[ ] Illustrated cards are the default.

\- \[ ] Compact mode is functional.

\- \[ ] Display preference persists.

\- \[ ] Filters and sorting work.

\- \[ ] Zone details open and close reliably.

\- \[ ] Exploration checklists reflect actual game state.

\- \[ ] Progress updates when exploration changes.

\- \[ ] Missing data does not produce misleading percentages.

\- \[ ] Zone artwork uses verified assets or consistent fallbacks.



\---



\# 10. Phase 7 — Overview Dashboard



\## Goal



Build a useful, attractive landing page driven by the same progression engine as the Zones tab.



\## 10.1 Character Header



Display verified information:



\- Name.

\- Race.

\- Class.

\- Faction.

\- Level.

\- Experience progress where applicable.

\- Portrait or class icon.



\## 10.2 Tracked Completion



Display an overall tracked completion figure only when its scope and denominator are clear.



The interface should explicitly identify which categories contribute to this total.



For the initial exploration-first release, this may represent exploration completion across supported zones.



Do not advertise it as total game completion.



\## 10.3 Statistics Cards



Recommended initial cards:



\- Zones completed.

\- Exploration progress.

\- Current zone.

\- Known tracked objectives.



Add quest progress once the quest provider is sufficiently reliable.



Each card should have a useful drill-down action where appropriate.



\## 10.4 Zone Highlights



Show relevant areas:



\- Current zone.

\- Recently visited zones, if known.

\- Zones close to completion.

\- Recently completed zones, if recorded.



Each entry should provide navigation to a Zone Detail page.



\## 10.5 Suggestions



Implement a small, deterministic recommendation system.



Use only reliable eligible objectives.



Suggested priorities:



1\. Incomplete objectives in the current zone.

2\. Exploration objectives in almost-completed zones.

3\. Other objectives near the character's current progression.



Provide the reason for each recommendation.



Do not recommend unavailable or unknown objectives as confirmed actionable tasks.



\## 10.6 Recent Milestones



Display a concise history of confirmed new accomplishments.



Only record milestones observed after baseline initialization.



Deduplicate events across reloads and repeated notifications.



Limit history size to prevent SavedVariables growth.



\## 10.7 Initial Experience



The dashboard should look complete even if only exploration tracking is available.



Use thoughtful layout and helpful explanations rather than disabled cards for unsupported future systems.



\## Deliverable



A polished Overview tab connected to real character and exploration progress.



\## Acceptance Criteria



\- \[ ] Accurate character details.

\- \[ ] Verified progress calculations.

\- \[ ] Current-zone progress is displayed where supported.

\- \[ ] Zone navigation works.

\- \[ ] Suggestions use reliable data.

\- \[ ] Milestone history does not fabricate past accomplishments.

\- \[ ] Unsupported categories do not clutter the UI.

\- \[ ] Dashboard and Zones tab use identical underlying progress results.



\---



\# 11. Phase 8 — Quest Tracking



\## Goal



Add quest completion as the second major progression provider.



This phase depends on Phase 0's quest research.



Do not assume the quest catalogue is complete.



\## 11.1 Quest Completion



Implement confirmed quest completion lookups using supported Forever APIs.



Handle quest history and relevant live events.



\## 11.2 Quest Catalogue



Create a versioned quest database with:



\- Quest ID.

\- Quest name.

\- Associated zone.

\- Faction eligibility.

\- Class restrictions.

\- Profession restrictions.

\- Prerequisites.

\- Quest type.

\- Repeatable status.

\- Mutually exclusive groups where known.



Use existing game data where possible.



\## 11.3 Quest Eligibility



Evaluate whether each quest:



\- Is completed.

\- Is currently available.

\- Is locked but obtainable.

\- Is permanently unavailable.

\- Cannot be classified reliably.



Do not infer permanent ineligibility solely from the quest not appearing in the player's log.



\## 11.4 Quest Counts



Prevent misleading denominators.



Exclude repeatable objectives from one-time completion counts unless explicitly modeled as milestones.



Avoid counting permanently unavailable alternatives.



Handle mutually exclusive quests carefully.



Unknown prerequisites or eligibility must affect the coverage classification.



\## 11.5 Zone Integration



Add a Quest section to Zone Detail when usable.



Show:



\- Completed quests.

\- Remaining known quests.

\- Status and eligibility.

\- Quest completion percentages where valid.

\- Coverage information.

\- Optional quest-chain grouping.



Update relevant dashboard statistics.



\## 11.6 Graceful Degradation



If comprehensive quest data cannot be obtained, allow a smaller supported subset.



Label it clearly.



Never present a subset as every quest in the zone.



\## Deliverable



A modular quest provider with useful, verified zone quest tracking.



\## Acceptance Criteria



\- \[ ] Quest completion detection works.

\- \[ ] Supported quests show correct states.

\- \[ ] Ineligible and repeatable quests are handled.

\- \[ ] Missing quest data is labeled.

\- \[ ] Quest progress updates correctly.

\- \[ ] Overall completion remains honest about coverage.

\- \[ ] Addon still functions without any quest database integrations.



\*\*Scope rule:\*\* If comprehensive quest tracking jeopardizes the quality or stability of the release, defer broad quest coverage to the next version rather than compromising the exploration-based experience.



\---



\# 12. Phase 9 — Polish and Release Readiness



\## Goal



Turn the working addon into a cohesive, stable release.



\## 12.1 Visual Review



Review every screen for:



\- Consistent layout.

\- Readable typography.

\- Native-style visual cohesion.

\- Correct artwork.

\- No clipped text.

\- Proper progress bar behavior.

\- Attractive completion states.

\- Useful tooltips.

\- Consistent empty and unavailable states.



\## 12.2 Interaction Review



Test:



\- Opening and closing.

\- Tab navigation.

\- Zone navigation.

\- Search.

\- Filtering.

\- Sorting.

\- Display mode switching.

\- Resizing.

\- Scrolling.

\- Reload persistence.

\- Minimap button behavior.



\## 12.3 Performance Review



Look for:



\- Unnecessary repeated scans.

\- Per-frame calculations.

\- Expensive frame recreation.

\- Large SavedVariables growth.

\- Excessive event callbacks.

\- Unbounded caches.

\- Slow zone catalogue rendering.



Use event-driven refreshes and caching where justified.



\## 12.4 Data Validation



Test exploration across multiple zones and characters.



Include:



\- Fully unexplored zones.

\- Partially explored zones.

\- Fully explored zones.

\- Alliance and Horde characters where possible.

\- Different level ranges.

\- Contested zones.

\- Missing or ambiguous data.



A zone must not be marked 100% complete unless the applicable tracked objective set and completion states justify that claim.



\## 12.5 Compatibility Testing



Verify:



\- Client reload.

\- Full game restart.

\- Combat.

\- UI scaling.

\- Resolution changes.

\- Addon enabled alone.

\- Addon enabled alongside common Forever addons.

\- Missing and invalid settings.

\- Unsupported or changed API responses.



\## 12.6 Release Documentation



Create or update:



\- `README.md`

\- Installation instructions.

\- Supported client version.

\- Feature list.

\- Known limitations.

\- Completion data coverage.

\- Debugging instructions.

\- Changelog.



\## Deliverable



Azerfolio v1 release candidate.



\## Acceptance Criteria



\- \[ ] No known blocking Lua errors.

\- \[ ] Functional without third-party addons.

\- \[ ] Verified progression results.

\- \[ ] No placeholder completion data.

\- \[ ] Stable settings persistence.

\- \[ ] Acceptable performance during normal gameplay.

\- \[ ] Visual consistency across supported pages.

\- \[ ] Clear documentation of limitations.



\---



\# 13. Testing Strategy



Testing must be divided into two categories.



\## 13.1 Automated Tests



Use lightweight tests where practical for pure Lua logic:



\- Eligibility evaluation.

\- Progress aggregation.

\- Percentage calculation.

\- Duplicate-objective handling.

\- Unknown-state handling.

\- Coverage classification.

\- Sorting and filtering.

\- SavedVariables migrations.

\- Recommendation ranking.



Mock game API responses instead of requiring a running client for all logic tests.



Do not build an unnecessarily complex testing framework.



\## 13.2 In-Game Tests



Use the Forever client for:



\- API behavior.

\- Exploration detection.

\- Real quest completion.

\- UI rendering.

\- Window interaction.

\- Map navigation.

\- Event delivery.

\- SavedVariables behavior.

\- Combat safety.



Pure unit tests cannot substitute for client validation.



\## 13.3 Manual Test Checklist



Maintain:



`docs/testing.md`



Record test cases, expected results, actual results, and any known failures.



Maintain a distinction between tests executed by Codex and tests requiring a human player.



\---



\# 14. Data Integrity Requirements



Azerfolio must make trustworthy claims.



\## 14.1 No Fabricated Data



Never invent:



\- Objective counts.

\- Completion states.

\- Quest totals.

\- Zone percentages.

\- Completion timestamps.

\- Map coordinates.

\- Exploration criteria.



Use an unavailable or unknown state when data cannot be established.



\## 14.2 Provenance



Track where objective data originates.



Examples:



\- Native game API.

\- Bundled client-derived database.

\- Verified manually curated database.



Document database generation and update procedures.



\## 14.3 Versioning



Version bundled data separately from addon code when useful.



Prepare for game patches to change objective requirements or identifiers.



\## 14.4 Reconciliation



When game state and static metadata disagree:



\- Prefer verified native completion state.

\- Do not silently alter catalogue totals.

\- Log useful diagnostics in debug mode.

\- Mark affected results as uncertain when appropriate.



\---



\# 15. Future Expansion Requirements



Although v1 includes only Overview and Zones, the architecture must support future providers.



Potential future modules:



\- ClassTracker

\- ProfessionTracker

\- CollectionTracker

\- DungeonTracker

\- LegacyTracker

\- ReputationTracker



Future modules should expose the same progression concepts:



\- Objectives.

\- Eligibility.

\- Completion.

\- Coverage.

\- Aggregation.

\- Navigation metadata.



The main Overview should eventually aggregate these providers without duplicating business logic.



Do not implement empty future modules in v1 merely for architectural completeness.



\---



\# 16. Required Codex Workflow



For each phase, Codex should:



1\. Inspect relevant existing code and research.

2\. Identify the smallest useful implementation.

3\. Make the changes.

4\. Run available automated checks.

5\. Document any required in-game validation.

6\. Summarize completed work.

7\. Record limitations and follow-up work.



Maintain:



`docs/implementation-status.md`



For each phase, record:



\- Status.

\- Completed work.

\- Files changed.

\- Tests performed.

\- Human validation required.

\- Known issues.

\- Next milestone.



\## 16.1 Work in Vertical Slices



Whenever possible, produce working end-to-end functionality.



For example:



\*\*Exploration vertical slice\*\*



\- Read exploration state for Elwynn Forest.

\- Match it to known objectives.

\- Calculate progress.

\- Display the progress in a Zone Detail page.

\- Update when exploration changes.



Only after this works should the implementation expand to additional zones.



\## 16.2 Avoid Premature Complexity



Do not implement:



\- A custom UI framework.

\- External services.

\- Runtime network dependencies.

\- Unnecessary generalized plugin systems.

\- Sophisticated recommendation algorithms.

\- Speculative features from future releases.



Simple, reliable Lua modules are preferred.



\## 16.3 Use Development Checkpoints



Recommended checkpoints:



\*\*Checkpoint A — Technical foundation\*\*



Client research and exploration proof of concept are complete.



\*\*Checkpoint B — First in-game interface\*\*



Azerfolio opens with native-style UI and functional navigation.



\*\*Checkpoint C — First completed zone report\*\*



A validated zone shows real exploration progress.



\*\*Checkpoint D — Functional Zones tab\*\*



Zone cards, compact view, filtering and detail pages work.



\*\*Checkpoint E — Functional Overview\*\*



Real progression appears on a polished dashboard.



\*\*Checkpoint F — Release candidate\*\*



Quest support where reliable, polish, tests and documentation.



Each checkpoint should leave the repository in a usable, testable state.



\---



\# 17. Final v1 Definition of Done



Azerfolio v1 is ready when a player can:



1\. Install the addon without third-party dependencies.

2\. Open a polished native-style Azerfolio window.

3\. View their character and meaningful progression statistics.

4\. Navigate between Overview and Zones.

5\. Browse zones using illustrated cards.

6\. Switch to compact list mode.

7\. Search, sort, and filter zones.

8\. Open a detailed zone report.

9\. See independently tracked exploration completion.

10\. Identify unfinished exploration locations.

11\. Discover a location and observe correct progress updates.

12\. Return to the catalogue without losing their place.

13\. Reload or restart without losing preferences.

14\. Understand when completion data is incomplete or unavailable.

15\. Use the addon without significant gameplay performance issues.



Quest tracking should be included to the extent that available data supports trustworthy results.



The release must not be blocked merely because every quest in Forever cannot yet be catalogued.



\---



\# 18. Immediate Next Action for Codex



\*\*Begin with Phase 0 and Phase 1, not the complete UI.\*\*



First inspect the actual Forever client and validate exploration tracking.



Specifically:



1\. Identify the client environment and relevant API capabilities.

2\. Find usable native Blizzard UI assets.

3\. Build a small exploration diagnostic.

4\. Test one zone end-to-end.

5\. Confirm the exploration objective denominator.

6\. Document results and unresolved limitations.

7\. Recommend the production exploration architecture.



Once those foundations are verified, proceed with the production addon implementation.



\*\*Primary objective:\*\* Build a beautiful completionist addon whose statistics are accurate enough that players can trust them.



\*\*Guiding principle:\*\* Azerfolio should make progress through Azeroth feel visible, meaningful, and satisfying.

