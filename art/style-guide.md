# Azerfolio art style guide

Azerfolio's zone illustrations are custom art in the spirit of classic Warcraft key art: hand-painted, warm and heroic. Every image must look like part of **one set**: same style, camera, light and level of detail. This guide is the source for every prompt in [prompts.md](prompts.md).

## 1. What needs art

| Asset | Count | Notes |
|---|---|---|
| Zone illustrations | 43 tracked zones | One per zone with an Explore achievement |
| Capitals and other places | 7 | Stormwind, Ironforge, Darnassus, Orgrimmar, Thunder Bluff, Undercity, Zephras Isle (shown greyed as "not tracked") |
| Fallback | 1 | Used for any zone without finished art; must not look like a specific zone |

Everything else uses native client textures (verified in Phase 0) or simple shapes drawn in Lua:

| UI element | Source |
|---|---|
| Parchment backgrounds | `Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal`, `Interface\QuestFrame\QuestBG` |
| Gold borders | `Interface\DialogFrame\UI-DialogBox-Gold-Border` |
| Class icons | `Interface\TargetingFrame\UI-Classes-Circles` |
| Pips, bars, emblems, focus glow | Solid textures tinted with the state colours in `UI/Theme.lua` |

So the art pipeline covers **51 images**.

## 2. Look and feel

**Do**
- Hand-painted, stylized fantasy illustration: bold simplified shapes, chunky silhouettes, slightly exaggerated proportions.
- Rich, saturated colour with a clear dominant hue per zone (see §4).
- Warm key light with golden rim light on edges; soft atmospheric perspective (distance fades into the sky colour).
- Visible but soft brush texture; painterly clouds; simple, readable foliage masses rather than individual leaves.
- A single, recognizable **landmark** per zone (an inn, a dam, a tower, a tree) that sits in the safe area.
- Calm, inviting moods for friendly zones; moodier light for dangerous ones, but never pitch black.

**Don't**
- Photorealism, 3D-render gloss, lens flares, film grain.
- People, creatures, faces or characters (they draw focus and date the image).
- Text, logos, watermarks, signatures, UI elements, frames or borders.
- Busy fine detail in the top and bottom thirds (those get cropped).
- Pure black or blown-out white areas (they fight the UI's text overlays).

## 3. Camera and composition

- **Camera:** wide establishing shot from a slightly elevated viewpoint (as if from a hilltop or a flying mount), about 20–30° down, no fisheye. The same camera for every zone.
- **Horizon:** close to the vertical middle (45–55% from the top).
- **Time of day:** golden hour by default. Use dusk, night or overcast only where §4 says so.

### Safe area

The same image is cropped four ways in the window. Keep the landmark and anything important inside the **core**.

```
Generated image (16:9)
┌─────────────────────────────────────────────────────────────┐
│                     sky (may be cropped)                     │
│      ┌───────────────── processed 2:1 ─────────────────┐      │
│      │ ┌──────────── card strip (16:5) ─────────────┐ │      │
│      │ │            ┌──────── core ────────┐        │ │      │
│      │ │  banner ═══│══ landmark here ═════│═══════ │ │      │
│      │ │  (9:1)     └──────────────────────┘        │ │      │
│      │ └─────────────────────────────────────────────┘ │      │
│      └─────────────────────────────────────────────────┘      │
│                foreground (may be cropped)                   │
└─────────────────────────────────────────────────────────────┘
```

| Crop | Where it's used | Keeps |
|---|---|---|
| 2:1 master (processed file) | Stored in the addon | Middle 89% of the generated height |
| 16:5 strip | Zone cards | Middle 62% of the master's height |
| 9:1 banner | Zone Detail header | Middle 22% of the master's height (40–62%) |
| ~1.2:1 | Continue card | Middle 58% of the master's width |
| 16:9 | List thumbnails | Middle 89% of the master's width |

**Core = the middle 40% of the width × the 40–62% band of the height.** The landmark must sit there. Readable silhouettes should also extend left and right along the horizon, so the wide banner doesn't look empty.

The title and percentage are overlaid on the left of the banner and the bottom of the cards, so keep those areas calm (soft gradients, no high-contrast detail).

## 4. Palette by region type

| Type | Dominant hues | Light | Zones |
|---|---|---|---|
| Green and pastoral | Spring greens, wheat gold, sky blue | Golden hour | Elwynn Forest, Westfall, Hillsbrad Foothills, Loch Modan, Redridge Mountains, Arathi Highlands, Mulgore, Riverglades |
| Lush and ancient | Emerald, teal, violet accents | Dappled, soft | Teldrassil, Ashenvale, Feralas, The Hinterlands, Stranglethorn Vale, Un'Goro Crater, Moonglade, Mount Hyjal |
| Dry and hot | Ochre, rust, terracotta, sand | Strong sun, heat haze | Durotar, The Barrens, Thousand Needles, Desolace, Tanaris, Silithus, Badlands |
| Snow and stone | Ice blue, slate, white | Crisp, cold | Dun Morogh, Alterac Mountains, Winterspring, Stonetalon Mountains |
| Fire and ash | Charcoal, ember orange, red | Glow from below, smoky | Searing Gorge, Burning Steppes, Blasted Lands |
| Gloom | Desaturated green-grey, purple, sickly yellow | Overcast, moonlight, fog | Tirisfal Glades, Silverpine Forest, Duskwood, Western Plaguelands, Eastern Plaguelands, Deadwind Pass, Swamp of Sorrows, Wetlands, Dustwallow Marsh, Felwood, Darkshore, Azshara, Shen'dralas |

Even gloomy zones keep a warm accent (a lantern, a sunset edge) so the set feels unified.

## 5. Image specification

| Item | Value |
|---|---|
| Generate at | 16:9 landscape, at least 1792×1008 (1920×1080 or larger preferred) |
| Format from the generator | PNG or JPG (WebP isn't supported by the processing script; convert first) |
| Processed file | 1024×512 PNG, cropped to 2:1 around the focal point |
| Game path | `Azerfolio\Media\Zones\<mapID>.png` (fallback: `fallback.png`) |
| Variants | Generate 3–4 per zone and pick the best against the review checklist |

## 6. Workflow

1. **Generate:** use the prompt for the zone from [prompts.md](prompts.md) with any image model. Paste the shared style block plus the zone line. Use the negative prompt if your tool supports one.
2. **Save the chosen image** as `art/source/<mapID>-<slug>.png`, e.g. `art/source/1429-elwynn-forest.png`. The map ID prefix is what matters.
3. **Optionally adjust the crop:** if the landmark isn't centred, add the focal point to `art/focal.json` (0–1 from the left and top; default 0.5, 0.5), e.g. `{ "1429": { "x": 0.45, "y": 0.55 } }`.
4. **Process:** `powershell -File tools/process-art.ps1`. It crops and resizes every source image, writes the game files to `Azerfolio/Media/Zones/`, copies them into the mockup, and regenerates `Azerfolio/Data/Art.lua` (the list of zones that have art; the game can't check whether a file exists).
5. **Review** in the mockup (cards, banner, Continue card, list), then in game with `/azf shots`.

`art/source/` is kept in the repo so images can be reprocessed later. The processed files are what the addon ships.

## 7. Review checklist

- [ ] Same style, camera and light as the rest of the set (compare it beside two existing zones).
- [ ] Landmark inside the core; still recognizable in the 9:1 banner crop.
- [ ] No people, creatures, text, logos, frames or watermarks.
- [ ] No pure black or white areas; the title area on the left of the banner is calm.
- [ ] The dominant hue matches §4.
- [ ] Reads at thumbnail size (64×36): a clear silhouette and colour.
- [ ] Still pleasant when greyed out (untouched zones are shown desaturated).

## 8. Legal note

These images are generated new for personal use and aren't distributed. Prompts describe places and visual qualities. They don't name artists, and they ask for no logos, characters or copied artwork.
