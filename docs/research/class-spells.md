# Class abilities along the road (Class tab, round 4; research started 2026-11-10)

The owner's idea: show the class abilities you get as you level on the Class tab's road (mockups/DESIGN.md "Class tab", round 4). Design proposal: a small inked scroll at levels that grant a **new** ability (not a new rank), three states (learned, available but not trained, later), "3 abilities waiting at your trainer" on the plaque, and the level's abilities on the right when a scroll is focused.

The rule that decides it: **honest data**. The tab may only show abilities and levels the game (or a checked source) confirms.

## What we know

- The client has the modern spellbook API: `C_SpellBook.GetNumSpellBookSkillLines`, `GetSpellBookSkillLineInfo`, `GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)` (items with `itemType`, `name`, `subName`, `spellID`, `isPassive`), and `C_Spell.GetSpellInfo` / `GetSpellName` / `GetSpellTexture` [verified-files: ForeverJournal 2.6.0, `KitUI.lua`, interface 16001; read to learn the API only].
- In the modern client the spellbook also lists **future spells** (`Enum.SpellBookItemType.FutureSpell`) with the level they're learned at (`C_SpellBook.GetSpellBookItemLevelLearned`, `C_Spell.GetSpellLevelLearned`) [external: the retail API; unverified on Forever].
- The trainer lists its services only while its window is open (`GetNumTrainerServices`, `GetTrainerServiceInfo`, `GetTrainerServiceLevelReq`) [external, classic API; unverified on Forever].
- QuestieDB has no spell data.

## Questions for the in-game probe (`/azfdiag spells`, report `luajit tools/diag-report.lua spells`)

1. Does Forever's spellbook list spells you haven't learned yet (future spells), and which `itemType` value marks them?
2. Does it give the level each is learned at (`GetSpellBookItemLevelLearned` or `C_Spell.GetSpellLevelLearned`)?
3. Are new ranks separate items (to tell a new ability from a new rank)?
4. With a class trainer's window open: what does the trainer list (names, ranks, levels), and does it agree with the spellbook?

## Findings (Gideon, Human Paladin 10; probe v1 19:27, v2 19:41, 2026-11-10)

- **The spellbook lists no future spells** [verified-ingame]: `Enum.SpellBookItemType.FutureSpell = 2` exists, but the 20 items are 18 spells (type 1) and 2 flyouts (type 4), all learned.
- `C_Spell.GetSpellLevelLearned(spellID)` and `C_SpellBook.GetSpellBookItemLevelLearned` work for learned spells (Blessing of Might 4, Holy Strike 6, Holy Light Rank 2 6) [verified-ingame].
- `C_SpellBook.GetCurrentLevelSpells(level)` returns tables but only Block and Dodge at level 1 over levels 1-60: **not a source** [verified-ingame].
- **The trainer is the source** [verified-ingame]: with every service-type filter on (`SetTrainerServiceTypeFilter("available"|"unavailable"|"used", 1)`, restored after), a Paladin trainer lists **147 services**: name, type (`used` = learned, `available` = trainable now, `unavailable` = later), icon, and `GetTrainerServiceLevelReq` (4 to 60). With the default filter it showed only the 9 available ones. Gideon has **8 abilities he could train now** (Hammer of Justice, Parry, Purify at 8; Blessing of Protection, Lay on Hands, Righteous Fury, Seal of Fury, Seal of Righteousness Rank 2 at 10).
- Names repeat per rank (Holy Light at 1, 6, 14, 22, 30, 38 …); the first time a name appears is a **new ability**, later ones are ranks. Where the rank text sits in `GetTrainerServiceInfo`'s returns is still to check (the report printed only the first three).

## Decision

**Record the trainer's list** whenever you open your class trainer (`TRAINER_SHOW`, all filters on for the read, then restored), save it per character with the time, and show the road's abilities from it: learned (`used`, or `IsSpellKnown` later), available, later. Before the first visit the tab says "Visit your class trainer to fill in your abilities" instead of guessing. No curated data needed.

## Plan (before the probe)

- **If the spellbook lists future spells with their levels:** read them live (no curated data), group by level, and tell new abilities from new ranks by name.
- **If not:** fall back to the trainer's list, recorded whenever you open your class trainer and saved per character, and show only levels the trainer has listed ("visit your trainer to fill in the road"). A hand-curated `Data/ClassSpells.lua` would be the last resort, and needs the owner's approval like any new data source.
