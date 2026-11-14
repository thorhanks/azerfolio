# Art prompts

Every piece of art the addon ships (`Azerfolio/Media`) has its prompt here, and only those: with this file alone the whole set can be regenerated. Sections: zone art, the war banner, interface chrome, the Atlas backdrop, celebrations, icons, and the Class tab (strips, map pieces, coins). When a piece is added or dropped, update this file in the same change.

How to use (see [style-guide.md](style-guide.md) §6):
1. Copy the section's **style block**.
2. Add the piece's line from the table after "Subject:".
3. Paste the **negative prompt** into your tool's negative field if it has one; otherwise append "Avoid: …".
4. Save your pick as `art/source/<file>.png` (zones: `<mapID>-<slug>.png`), then run `powershell -File tools/process-art.ps1`.

Descriptions name places and visual qualities only, never artists, studios, games or copyrighted characters.

## Zone art

### Style block

```
Hand-painted stylized fantasy landscape illustration, painterly with soft visible brush texture,
bold simplified shapes and chunky silhouettes, rich saturated colors, warm golden rim light,
soft atmospheric perspective, epic wide establishing shot from a slightly elevated viewpoint,
horizon near the middle of the image, the main landmark centered in the middle of the frame,
calm uncluttered sky in the upper left, no people, no creatures, no text.
16:9 landscape.
Subject:
```

### Negative prompt

```
photorealistic, photograph, 3D render, CGI gloss, people, person, character, face, creature, animal,
text, letters, logo, watermark, signature, frame, border, user interface, blurry, lens flare, film grain,
fisheye, pure black shadows, overexposed, pagoda, East Asian architecture, curved upturned roofs
```

Tip: give your tool **Elwynn Forest (1429)** as a style reference image if it supports one, so regenerated images match the set.

### Eastern Kingdoms

| mapID | Slug | Zone | Subject line |
|---|---|---|---|
| 1429 | elwynn-forest | Elwynn Forest | A lush green forest of tall oaks around a cozy village inn with warm glowing windows beside a cobbled road; a stone abbey on a hill and the white walls and blue roofs of a great city on the far horizon; golden hour |
| 1426 | dun-morogh | Dun Morogh | A snowy mountain valley with frosted pine trees and a frozen lake; enormous dwarven stone gates carved into the mountainside at the center; crisp blue sky, sunlit snow |
| 1420 | tirisfal-glades | Tirisfal Glades | *(v2)* A gloomy autumn forest with withered orange trees and abandoned pumpkin fields in the foreground; at the center, the dark jagged spires and broken walls of a great fallen human capital, large and clearly silhouetted against a glowing amber sunset; thin purple-gray fog low on the ground only, so the city stays sharp |
| 1436 | westfall | Westfall | Rolling golden wheat fields with old farmhouses and a wooden windmill; a tall stone lighthouse on sea cliffs at the center; warm harvest sunset |
| 1432 | loch-modan | Loch Modan | A wide blue mountain lake held back by a massive carved stone dwarven dam at the center; green hills and small farms; sunny afternoon |
| 1421 | silverpine-forest | Silverpine Forest | A dark pine forest beside a cold gray lake; a gothic stone keep on a cliff at the center; drifting mist, cool green-gray light |
| 1433 | redridge-mountains | Redridge Mountains | *(v2)* Red rock ridges around a calm blue lake; at the center, a human lakeside town of timber-framed houses with steep dark slate roofs and stone chimneys, some on wooden piers over the water, joined to the shore by a long gray stone bridge with plain round arches; medieval European style like an English village; warm autumn trees |
| 1431 | duskwood | Duskwood | A perpetually moonlit forest of gnarled black trees; a small village with warm lantern light and a chapel at the center; silver-blue mist |
| 1437 | wetlands | Wetlands | Rain-soaked marshland with tall grass and pools; a weathered stone harbor fortress on the coast at the center; a dark mountain far away; gray-green overcast with a break of sunlight |
| 1424 | hillsbrad-foothills | Hillsbrad Foothills | Gentle green hills with orchards and farms; a large stone keep ruin on a hill at the center; a river running to the sea; bright afternoon |
| 1416 | alterac-mountains | Alterac Mountains | Snow-dusted craggy peaks; the ruins of a walled human city on a high plateau at the center; cold blue light and drifting clouds |
| 1417 | arathi-highlands | Arathi Highlands | Rolling grassy highlands with standing stone circles; a ruined fortress keep on a hill at the center; troll-built stone ruins on distant hilltops; late afternoon |
| 1434 | stranglethorn-vale | Stranglethorn Vale | Dense tropical jungle; an ancient overgrown stepped stone temple at the center; a turquoise ocean cove with a pirate harbor in the distance; humid golden light |
| 1418 | badlands | Badlands | A red-orange canyon desert of mesas and dry riverbeds; giant ancient dragon bones half-buried at the center; heat haze, harsh sun |
| 1435 | swamp-of-sorrows | Swamp of Sorrows | A murky swamp of mangrove roots and still water; a half-sunken temple dome at the center; teal-green fog with soft light shafts |
| 1425 | the-hinterlands | The Hinterlands | Lush forested highlands with cliffs and waterfalls; a terraced troll temple city carved into a mountain at the center; vivid greens, bright clouds |
| 1427 | searing-gorge | Searing Gorge | A deep black-rock gorge with rivers of molten lava; huge iron mining machinery and cranes at the center; orange glow rising from below, smoky sky |
| 1428 | burning-steppes | Burning Steppes | Volcanic plains of black ash and glowing lava cracks; a colossal dark mountain fortress at the center; red smoky sky with embers |
| 1419 | blasted-lands | Blasted Lands | A cracked blood-red wasteland; a gigantic ancient stone portal on the horizon at the center; ominous green-red sky |
| 1430 | deadwind-pass | Deadwind Pass | A barren mountain pass of dead gray trees; a tall jagged wizard's tower at the center under swirling storm clouds; gray-purple dusk |
| 1422 | western-plaguelands | Western Plaguelands | Blighted farmland with dead trees and abandoned barns; a ruined town at the center; sickly yellow-green sky, a hopeful sunbeam breaking through |
| 1423 | eastern-plaguelands | Eastern Plaguelands | Corrupted purple-gray land with twisted trees; the burning ruins of a great walled city at the center; dark plague clouds lit orange at the edges |
| 2548 | riverglades | Riverglades | *(inferred from area names: Farholde Keep, Powderfuse Port, Meadowsbrook, Turner's Logging Camp, Twilight's Shroud; please confirm)* A fertile river valley with farms, granges and a logging camp along a winding river; a stone keep on a rise at the center; a small busy river port downstream; a shadowy twilight wood on one side; fresh spring morning |

### Kalimdor

| mapID | Slug | Zone | Subject line |
|---|---|---|---|
| 1411 | durotar | Durotar | *(v2)* A red rocky desert coast with dry canyons and scrub; at the center, a small frontier hilltop outpost of a few rough wooden huts behind a low spiked log palisade with one wooden watchtower, modest in size, not a fortress; turquoise sea and sea stacks on one side; hot afternoon sun |
| 1412 | mulgore | Mulgore | Vast golden grassland plains under a huge sky; towering flat-topped mesas with totems and tents at the center; windy, bright |
| 1413 | the-barrens | The Barrens | An endless dry savanna with yellow grass and thorny flat-topped trees; a small crossroads trading outpost at the center; enormous open sky |
| 1438 | teldrassil | Teldrassil | A colossal world tree rising from the sea with glowing violet forest on its branches; graceful elven architecture at the center; twilight with soft moonlight |
| 1439 | darkshore | Darkshore | A misty moonlit coastline with dark forest; elegant elven ruins on the beach at the center; pale blue light, gentle waves |
| 1440 | ashenvale | Ashenvale | An ancient lush forest of huge trees with purple and green foliage; a graceful elven shrine at the center; dappled soft light |
| 1442 | stonetalon-mountains | Stonetalon Mountains | Tall gray mountain peaks with a lone spire; a scarred logged valley below at the center; cold wind and clouds |
| 1441 | thousand-needles | Thousand Needles | Towering narrow rock pillars rising from a dusty canyon floor; rope bridges strung between pillar tops at the center; warm hazy light |
| 1443 | desolace | Desolace | A barren gray land with scattered giant bones; nomad tent camps and a lonely stone ruin at the center; desolate overcast with a pale sun |
| 1445 | dustwallow-marsh | Dustwallow Marsh | A foggy coastal swamp; a stone harbor fortress city on an island at the center; green-gray mist with warm windows |
| 1444 | feralas | Feralas | A rainforest of giant trees and waterfalls; a vast overgrown ruined elven city at the center; mossy greens, misty light |
| 1446 | tanaris | Tanaris | *(v2)* Vast golden sand dunes; at the center, a ramshackle goblin trading town behind patched walls of rusty riveted metal sheets and wooden scaffolding, with tall water towers, smokestacks, pipes and a big clock tower; ancient stone ruins half-buried in the sand nearby; blazing midday sun; no horns, spikes or curved roofs |
| 1447 | azshara | Azshara | An autumn forest of crimson and orange leaves on a rugged coast; grand ruined elven palaces at the center; pink-orange sunset |
| 1448 | felwood | Felwood | A corrupted forest of twisted trees with sickly green glowing pools; a ruined shrine at the center; toxic green haze with a warm sunset edge |
| 1449 | un-goro-crater | Un'Goro Crater | A primeval jungle inside a vast crater with giant ferns; a smoking volcano and glowing crystals at the center; humid golden light |
| 1450 | moonglade | Moonglade | A serene moonlit glade around a still lake; elegant druidic shrines and a bridge at the center; silver-blue night with soft stars |
| 1451 | silithus | Silithus | An alien yellow desert; enormous insect-hive spires and mounds at the center; hazy amber sky |
| 1452 | winterspring | Winterspring | *(v2)* A snowy pine valley with steaming turquoise hot springs; at the center, a small goblin trading post built from dark timber and corrugated metal sheets, with snow-covered flat and gabled roofs, smoking stovepipe chimneys, lanterns and a wooden wall; pale blue sky and drifting snow; no horns or curved roofs |
| 2482 | mount-hyjal | Mount Hyjal | *(from area names: Summit of Eternity, Shrine of Aviana, Felblood Scar, Tainted Foothills)* A sacred forested mountain with an immense world tree on the summit at the center; elegant shrines among the trees; scarred, smoldering foothills below; golden light on the summit |
| 2652 | shendralas | Shen'dralas | *(v2, from the owner's in-game reference)* A haunted twilight forest of huge gnarled dark trees draped in hanging moss; at the center, a clearing with a still pond covered in glowing teal mist; a distant tribal war camp of hide tents with small warm torchlight half-hidden in the fog; a tall dark rock spire looming in the misty background; crude wooden spears with red bindings planted in the ground in the foreground; deep blue-teal palette with warm orange torch accents |

### Capitals and other places (shown as "not tracked")

| mapID | Slug | Place | Subject line |
|---|---|---|---|
| 1453 | stormwind-city | Stormwind City | A grand white-stone human city with blue roofs, canals and a towering cathedral at the center; noble statues at the gate; golden hour |
| 1455 | ironforge | Ironforge | A colossal dwarven city carved inside a mountain; a great forge hall with molten metal light at the center; warm orange glow, stone and brass |
| 1457 | darnassus | Darnassus | A moonlit elven city of graceful temples and pools among giant tree branches; a temple at the center; violet-blue night |
| 1454 | orgrimmar | Orgrimmar | A fortified orcish city of spiked walls and red-earth buildings in a canyon; a great hall at the center; hot sunset |
| 1456 | thunder-bluff | Thunder Bluff | A city on tall flat-topped mesas joined by rope bridges, with totems and tents; the central mesa at the center; windy blue sky |
| 1458 | undercity | Undercity | The ruined walls of a once-great royal capital above ground, with an eerie green glow from underground passages at the center; misty dusk |
| 2521 | zephras-isle | Zephras Isle | *(v2, from the owner's in-game references; remove "curved upturned roofs" from the negative prompt for this one)* A lush misty island high among the clouds; at the center, a tall slender white stone elven tower rising into glowing haze, tethered to the ground by an enormous chain anchored to a carved wooden gate; a graceful elven village of pale wood with teal-blue scalloped tile roofs and gently curved eaves along winding cobblestone paths; gnarled trees with red-pink blossoms; a white-sailed sailing ship floating through the clouds on one side; more white towers fading into the mist behind; soft golden sunlight through bright fog |

### Fallback

| File | Subject line |
|---|---|
| fallback | A generic fantasy landscape: rolling hills, a winding road toward distant mountains, a lone signpost at the center, warm dusk sky. Nothing that identifies a specific place |

## War banner pieces (zone progress, spec §7.1; added 2026-11-08)

The zone's progress is the player's faction war banner hoisted up a pole (design: `mockups/DESIGN.md`). Each faction's set must look like **its own faction**: the Alliance banner is regal and ceremonial; the Horde banner is a battle-worn war standard. The two sets share only the camera and painting style. Pieces are separate images layered in game, so each is painted alone on a flat key colour that the processing script removes (pipeline support for transparency is still to be built; see `style-guide.md` §1).

**Not** the zone style block. Use this one:

```
Hand-painted stylized fantasy game asset, painterly with soft visible brush texture, bold simplified
shapes, rich saturated colors, warm golden rim light from the upper left, front-facing flat orthographic
view, the object centered and fully visible with even margins, isolated on a perfectly flat solid
pure magenta (#FF00FF) background, no shadow on the background, no text, no letters.
Subject:
```

Negative prompt: the zone one, plus `perspective, angled view, cropped edges, background scenery, magenta on the object, official logo, real-world flag`.

| File | Aspect | Subject line |
|---|---|---|
| banner-alliance | 2:3 portrait | A regal royal-blue silk war banner hanging straight down from a gilded crossbar with gold end caps; swallowtail bottom with two points; a wide embroidered gold border with fine stitching; a heavy gold fringe along the whole bottom edge; a gold tassel hanging from each point; at the center a proud golden heraldic lion's head on a shield, embroidered in gold thread; soft cloth folds catching light; clean, ceremonial, pristine |
| banner-horde | 2:3 portrait | A battle-worn crimson war banner of rough heavy cloth hanging from a crude timber crossbar lashed on with rope; torn ragged bottom edge with uneven strips, a few holes and slashes, scorch marks and dark stains; a patch of stitched leather with coarse cross-stitches; at the center a bold jagged black tribal sigil roughly painted by hand with visible brush drips; no fringe, no tassels, no gold; fierce and weathered |
| pole-alliance | 1:4 tall | A tall straight polished dark-wood flagpole with gold bands and a gleaming gold spearhead finial |
| pole-horde | 1:4 tall | A tall rough-hewn timber pole bound with leather straps, topped with a dark iron spike flanked by two curved tusks |
| badge-alliance | 1:1 | A small round embroidered patch: deep blue cloth disc edged with a raised gold-thread ring, empty center |
| badge-horde | 1:1 | A small round disc of tanned hide with an iron rim held by rivets, empty center |

Tips: generate 3–4 variants of each; pick the pair (cloth plus pole) that reads as one object. Save as `art/source/banner-alliance.png` and so on. The badges are no longer used (replaced by streamers, below; owner 2026-11-08).

### Streamers (battle honours)

One streamer is tied below the finial for each category the zone has finished (Explored, Quests, Flight paths). Same style block as the banner pieces. They hang straight down; the game sways them a little.

| File | Aspect | Subject line |
|---|---|---|
| streamer-alliance | 1:6 tall | A single long narrow ceremonial silk streamer ribbon hanging straight down, royal blue with a thin gold embroidered edge on both sides, a small gold knot at the top, the bottom end cut into a swallowtail with a tiny gold tassel; pristine, regal |
| streamer-horde | 1:6 tall | A single long narrow strip of torn crimson cloth hanging straight down, ragged frayed edges, tied at the top with a leather thong and a small carved bone bead, the bottom end torn and uneven; battle-worn, no gold |

## Interface chrome (frame kit; added 2026-11-08)

Frames and ornaments that dress the cards, tiles, bars and headers so they look like the client's own panels. **Faction-neutral**: antique gold and dark bronze, like the native frame around the window. Each piece is painted alone on flat magenta; frames have an **empty magenta centre** (the processing script measures the border from it and stretches the frame to any size without distorting the corners, a nine-slice).

Style block for chrome:

```
Hand-painted fantasy game user interface ornament in the style of a classic high-fantasy MMO,
ornate antique gold metal with dark aged bronze, fine engraved filigree, subtle warm highlights
and soft shading, crisp clean silhouette, perfectly symmetrical left to right and top to bottom,
front-facing flat orthographic view, the object fills the frame edge to edge with a small even
margin, isolated on a perfectly flat solid pure magenta (#FF00FF) background, no shadow on the
background, no text, no letters, no gems larger than a fingertip.
Subject:
```

Negative prompt: the banner one, plus `perspective, 3D render, glossy plastic, neon, sci-fi, busy background, uneven border thickness, asymmetric corners`.

| File | Aspect | Subject line |
|---|---|---|
| frame-card | 1:1 | A rectangular picture frame border made of a thin band of dark bronze with a fine gold inner rim, larger ornate gold filigree corner pieces with a small round boss in each corner, the four sides plain and even between the corners; the whole inside of the frame is empty magenta; the border band is about one twentieth of the image width |
| frame-bar | 8:1 | A long thin horizontal progress bar housing: a slim dark bronze casing with a fine gold rim, small ornate gold end caps at the left and right; the long inside channel is empty magenta |
| bar-fill | 8:1 | A long thin horizontal bar of glowing molten liquid gold with soft highlights along the top and slightly darker underside, filling the entire image edge to edge (no magenta, no border) |
| plate-header | 6:1 | A horizontal title plate: a long flat band of dark worn leather framed by thin gold rails top and bottom, with ornate gold filigree end pieces at the left and right; the centre band is plain dark leather (room for text) |
| divider | 8:1 | A thin horizontal ornamental divider line of gold filigree, slender and tapering to points at both ends, with a small diamond-shaped gold ornament in the centre |

Reputation bar fill (Phase 11, added 2026-11-08). Reputation isn't completion, so it carries **no gold**: a pale, colourless metal that the addon tints in the client's reaction colours (red, orange, yellow, green), the way the client tints `common-stat-bar-white`.

| File | Aspect | Subject line |
|---|---|---|
| bar-fill-white | 8:1 | A long thin horizontal bar of glowing pale silver liquid metal, almost white, with soft bright highlights along the top and a slightly darker grey underside, completely colourless (no gold, no blue, no warm tint), filling the entire image edge to edge (no magenta, no border) |

Tip: `bar-fill-white` must stay neutral grey-white: any colour in it shifts every reaction colour after tinting. Check it with `tools/art-contact-sheet.ps1`.

Reputation standing strip (Reputation tab, Phase 12; added 2026-11-09). Eight cells under the toolbar, one per reaction (Hated … Exalted), each with a count. One plaque frame used for all eight, and one emblem per reaction. The reaction colour stays on the cell's top edge (drawn by the addon), so the plaque itself is colourless bronze.

| File | Aspect | Subject line |
|---|---|---|
| frame-plaque | 2:1 | A small rectangular plaque frame: a slim band of dark aged bronze with a fine thin gold rim on its inner edge, small plain square corner studs, the four sides even and plain between the corners (no ornament in the middle of any side, since the sides are stretched); the whole inside is empty magenta; the band about one tenth of the image height |

**Plaque fills** (round 2, 2026-11-09; owner: the plaque's bare inside looked empty). A painted texture fills each plaque, tinted with the reaction colour by the addon (multiplied, like `bar-fill-white`), replacing the colour line along the top. One colourless piece for all eight cells. (Owner picked cloth over enamel, 2026-11-09.)

```
Hand-painted fantasy game texture in the style of a classic high-fantasy MMO, a flat swatch seen
straight on, even soft lighting with no shading, no folds, no vignette, no highlights, filling the
entire image edge to edge, no border, no frame, no object, completely colourless pale grey-white
(no colour, no warm tint, no blue), so it can be tinted any colour. 2:1 landscape.
Subject:
```

| File | Subject line |
|---|---|
| plaque-fill-cloth | Fine woven heraldic cloth with a subtle damask pattern of small repeating diamonds and tiny fleur motifs woven into it; the thread weave just visible; the pattern quiet and low contrast |

Negative prompt: `colour, gold, warm tint, blue tint, folds, wrinkles, shadow, vignette, frame, border, text, letters, objects, high contrast, busy pattern`.

Tips: like `bar-fill-white`, any colour in it shifts every reaction colour after tinting, and a busy pattern fights the emblem and the count on top; quiet and grey is right. The addon darkens the edges itself.

Tips for the plaque: it's drawn at about 120×52 px, eight in a row, so keep it plain. No crest or notch on the top edge: a nine-slice stretches the middle of each side, which would smear it.

**Reaction emblems** (`rep-<reaction>`): eight small metal emblems shown at about 32 px beside each count. The **metal climbs with the reaction**, so the row reads as a ladder: dark iron at Hated up to gold at Exalted. Each is a free-standing object (not a round painting) on flat magenta, one bold silhouette, no fine detail. Use this style block instead of the chrome one:

```
Hand-painted fantasy game user interface emblem in the style of a classic high-fantasy MMO,
a single small heraldic metal emblem with a bold simple silhouette that reads at very small
size, front-facing flat orthographic view, soft warm highlight from the upper left, centred
and filling about 80% of a square, isolated on a perfectly flat solid pure magenta (#FF00FF)
background, no shadow on the background, no text, no letters, no gems, no frame, no circle
behind it. 1:1 square.
Subject:
```

| File | Subject line |
|---|---|
| rep-hated | A broken sword with a wide blade, snapped clean in half: the hilt with a short jagged stub of blade upright, and the snapped-off upper half lying tilted beside it with a clear gap between them, made of blackened pitted iron with patches of red rust (round 2, 2026-11-09: the first one read as a whole dagger at 32 px) |
| rep-hostile | Two short swords crossed in an X, blades pointing up, made of dark rough iron with dull edges |
| rep-unfriendly | A plain kite shield held upright, closed and guarded, made of worn dull bronze with a few dents and a darker rim |
| rep-neutral | A simple balance scale with two pans hanging level, made of plain bronze |
| rep-friendly | Two hands clasped in a handshake, seen from the side, cast in polished warm bronze |
| rep-honored | A laurel wreath shaped like a cup: two leafy branches curving up and outward from a small ribbon bow tied at the bottom, the wreath open at the top, made of bright polished silver (round 2, 2026-11-09: the first one had the bow on top and looked like an upside-down horseshoe) |
| rep-revered | A five-pointed star set inside a small laurel wreath, made of gleaming bright silver with a soft white shine |
| rep-exalted | A royal crown with five points, each tipped with a small round ball, made of rich radiant gold with a soft warm golden glow around it |

Negative prompt: the chrome one, plus `text, letters, numbers, circle background, round frame, coin, many objects, tiny details, faces`.

Tips: keep each one a single object with a clear outline; the row is checked dimmed (count 0) as well as lit. Review all eight side by side with `tools/art-contact-sheet.ps1`: the metal should step up evenly from Hated to Exalted.

Tips: frames must be symmetrical, with an even band between the corners (it is stretched). If the processing script reports a border it couldn't measure, set it by hand in `art/slices.json` (`{ "frame-card": { "x": 0.08, "y": 0.08 } }`, fractions of width and height).

## Atlas backdrop (Phase 10; added 2026-11-08)

One painting behind the whole Atlas view: an old painted sea chart of the world with the two continents. **The zone cards sit on top of it**, and their places come from the game, not from the painting, so the land should be loose and impressionistic: soft shapes, no detailed coastline that the cards would contradict. It must stay **dark and quiet** so the cards stand out. Save as `art/source/atlas-backdrop.png` (4:3 landscape); `tools/process-art.ps1` makes `Media\Chrome\atlas-backdrop.blp`.

```
Hand-painted fantasy world map in the style of an old illuminated sea chart, painterly with soft
visible brush texture, seen straight from above. A deep dark teal and ink-blue ocean fills the image,
with faint swirling current lines and very faint compass rhumb lines radiating across the sea.
On the left third, one large tall landmass running from the top edge to near the bottom edge, its
shape loose and impressionistic: a narrow wooded north, a broad middle, a sandy southern end; on the
right third, a second large tall landmass, narrower, also running top to bottom: snowy hills in the
north, green lowlands in the middle, a jungle peninsula reaching down in the south. The middle third
is open sea, empty. Landmasses painted in muted earthy
parchment tones (olive, ochre, umber) with soft darker edges, low contrast, no fine detail. A small
faint gilded compass rose in the lower left corner. Dark aged vignette around all edges, overall
dark and calm so other things can be placed on top. No text, no labels, no letters, no borders.
4:3 landscape.
```

Negative prompt: the zone one, plus `bright, high contrast, labels, place names, grid lines, frame, border, modern map, satellite view, photograph`.

## Celebration pieces (Phase 10 round 2; added 2026-11-08)

Painted pieces for the celebration screens (mockups/DESIGN.md "Celebrations"): a gold laurel frame holding a round **seal** per category, a title ribbon, and a seal stamped beside the war standard when a zone is claimed. Use the **chrome style block** above (flat magenta background, symmetrical, no text) for every piece. Save each as `art/source/<file>.png`; `tools/process-art.ps1` keys and converts them.

The **seals** are round paintings that sit inside the laurel frame (and, small, on the on-screen alert): paint the emblem filling a circle edge to edge, with a thin plain dark rim, and only the corners outside the circle magenta. They should read at 40 px, so one bold subject each.

| File | Aspect | Subject line |
|---|---|---|
| cel-laurel | 1:1 | A circular victory medallion frame: a ring of ornate gold laurel leaves on a thin dark bronze band, a small gold star at the top and a small looped ribbon knot at the bottom; the whole circular inside of the ring (about 70% of the width) is empty magenta |
| cel-seal-explore | 1:1 | A round painted emblem: a golden compass rose lying on an old parchment map with a distant snowy mountain peak, warm light, a thin plain dark bronze rim around the circle |
| cel-seal-quests | 1:1 | A round painted emblem: a rolled parchment scroll tied with a red ribbon and a red wax seal, a feather quill crossing it, a small golden exclamation mark shining above, a thin plain dark bronze rim around the circle |
| cel-seal-flights-alliance | 1:1 | A round painted emblem: a majestic gryphon (eagle head and wings, lion body) soaring with wings spread across a bright blue sky with clouds, a thin plain dark bronze rim around the circle |
| cel-seal-flights-horde | 1:1 | A round painted emblem: a fierce wyvern (bat-like leathery wings, lion-like body, scorpion tail) flying across a red-orange dusk sky over a desert mesa, a thin plain dark iron rim around the circle |
| cel-ribbon | 6:1 | A long horizontal ceremonial ribbon banner: deep crimson cloth with a thin gold embroidered trim along the top and bottom edges, the left and right ends folded back with swallowtail notched tips; the long middle is plain flat crimson (room for text) |
| cel-claim-alliance | 1:1 | A round wax seal stamp: deep royal blue wax with a polished gold rim, a proud lion's head crest embossed in the centre, regal and clean |
| cel-claim-horde | 1:1 | A round wax seal stamp: dark blood-red wax with a rough black iron rim studded with small bone spikes, two crossed battle axes and a pair of tusks embossed in the centre, crude and battle-worn |

Negative prompt: the chrome one, plus `text, letters, numbers, faces of people`.

## Icons (tabs and categories; added 2026-11-08)

Square icons in the style of the game's ability icons, one set, so new tabs only need a new line here. No frame: the game draws the border. Save as `art/source/icon-<name>.png`.

Style block for icons:

```
Hand-painted fantasy game ability icon in the style of a classic high-fantasy MMO, a single bold
central object filling most of a square, strong silhouette readable at very small size, rich
saturated colors, warm golden rim light from the upper left, dark softly vignetted painted
background (not black), visible soft brush texture, no frame, no border, no text, no letters.
1:1 square.
Subject:
```

Negative prompt: the zone one, plus `frame, border, rounded corners, photo, tiny details`.

| File | Use | Subject line |
|---|---|---|
| icon-overview | Overview tab | An open leather-bound adventurer's journal with a red ribbon bookmark, pages showing a small hand-drawn map and check marks, a quill resting across it |
| icon-zones | Zones tab | A rolled-open parchment map of a fantasy continent with a brass compass lying on top |
| icon-explore | Exploration category | A brass spyglass held out over a misty valley with a distant mountain peak |
| icon-quests | Quests category | A tall golden exclamation mark glowing above a sealed parchment scroll |
| icon-flights | Flight paths category | A gryphon in flight with wings spread wide, seen from the side, against an evening sky |
| icon-reputation | Reputation tab | A heraldic tabard hanging from a short wooden crossbar, deep green cloth with a gold embroidered border and a bold gold sunburst emblem on the chest, gently folded (added 2026-11-09; green and gold so it's neither Alliance nor Horde and stands apart from the brown journal and the parchment map) |
| icon-class | Class tab | A knight's kite shield standing upright with a gilded rim, a winding golden road painted across its face from top to bottom, a small glowing star at the road's end (added 2026-11-10; a journey, not any one class) |

Future tabs add one line each (for example icon-dungeons: a dark stone archway with a glowing portal).

## Class tab art (Phase 13, 2026-11-10 to 11-13)

Design: mockups/DESIGN.md "Class tab" (round 5). Every piece below is in use; together they rebuild all of the Class tab's art. Never name a game, artist or studio in a prompt. Save each image as `art/source/<file>.png`; `tools/process-art.ps1` keys and converts it, stacks the strips (lining up the lane at each seam), and `tools/trace-strip.ps1 -Method lane` then traces each strip's lane (see CLAUDE.md "Zone art" for the whole run). The Codex CLI (`codex exec`, image generation) made all 51 panels and 8 coins from these prompts; the road panels took about 4 minutes each.

Backgrounds, so the pipeline can cut each piece out:
- **Map panels**: a full picture, no background to remove.
- **Coloured and metal pieces**: on perfectly flat pure magenta (#FF00FF).
- **Ink pieces** (the focus ring): drawn on pure white (#FFFFFF), no paper texture; the pipeline turns the white transparent and keeps the ink, so it sits on the map like more ink.

### The strips (18 roads, three panels each)

One tall map per class and side, read top to bottom from the class's first steps to its last, painted in the zone art's style with an antique map's colouring. **Paint no road**: leave a narrow plain lane where the addon draws it, with each stop's landmark **beside** the lane, never on it. The addon traces the lane and places each stop by its landmark (Theme.classStrip).

Final size 512×2048 (1:4); image tools rarely make 1:4, so each strip is **three stacked 3:4 portrait panels**.

Style block for strips:

```
Hand-painted stylized fantasy journey map seen from high above at a gentle angle, painterly with
soft visible brush texture, bold simplified shapes and chunky silhouettes, small landmark buildings
and landscape features painted in miniature, coloured like an antique map: aged parchment ground,
sepia and warm umber, muted sage and olive greens, faded slate blues, soft ochre, fine dark ink
outlines around shapes, subtle paper grain over everything, gently darkened worn edges, quiet
low saturation, no road, no path, no trail, no people, no creatures, no text.
3:4 portrait.
Subject:
```

Negative prompt: `text, letters, words, labels, place names, calligraphy, numbers, signature, compass rose, border, frame, road, path, trail, dotted line, wide empty band, saturated colors, neon, photograph, 3D render, people, creatures`.

**Same for every panel:**
- **References.** Gideon's road (Paladin, Alliance) is the set's model; make it first. Its panel 1 takes `art/source/1429-elwynn-forest.png` (the zone art) as the style reference. Every other panel takes Gideon's matching panel as the style reference (`strip-paladin-alliance-1.png` for panel 1, `-2` for panel 2, `-3` for panel 3), and panels 2 and 3 also take **the same road's previous panel** as the continuity reference (its bottom edge continues into the new panel's top edge).
- **The lane** is a narrow winding lane of plain bare ground, about one sixth of the image width, with nothing painted in it and the land coming right up to its edges. Write it out in full in each prompt. It follows the same route on every road so the panels join:
  - Panel 1: from the **top centre**, winding down, and leaves the **bottom edge near the left side** (about one tenth of the width in).
  - Panel 2: enters at the **top edge near the left side** (about one tenth in), winds across, and leaves the **bottom edge about a third of the way in from the left**.
  - Panel 3: enters at the **top edge about a third of the way in from the left**, winds down, and ends at the **bottom centre**, where a small radiant star is painted on the ground (the road's end).
- Keep the landmarks small and all at one scale, with open ground between them, so the stops don't crowd.
- The light changes down the road: the top of panel 1 is the morning of the journey; the colours follow the places named, and the bottom of panel 3 is the road's last, most dramatic place.
- A road's first stop is the class letter from the trainer at home, and home differs by race, so its landmark is a **modest starting place** (a small chapel, hall or hut camp) rather than any one race's town.

Save as `art/source/strip-<class>-<side>-<n>.png` (class and side in lower case: `strip-warrior-horde-2.png`). Make a road's three panels together, in order.

Subject lines start with "The top / middle / bottom of a long journey map."; each line below is what follows. Where a row says **"The same as `<file>`"**, the two roads share that part of the world: reuse that panel's subject line word for word, give that finished panel as an extra reference, and still continue this road's own previous panel at the top edge.

#### Paladin, Alliance (`strip-paladin-alliance-<n>`)

Stops: start, the abbey (1) · The Tome of Divinity, the cathedral city (12) · The Tome of Valor, the farm (20; side path: a strange artifact in the autumn wood's glade) · The Tome of Nobility, the keep in the hills (40; side path: the camp, Forging the Mightstone) · The Charger, the ossuary and ruined gate (60).

| File | Subject (after "The top / middle / bottom of a long journey map.") |
|---|---|
| strip-paladin-alliance-1 | At the top centre a small stone abbey with a bell tower in a sheltered wooded valley, soft morning light above it; pine forests painted close on both sides; a waterfall and a small pond on the left a third of the way down; on the right a third of the way down a walled city with a grand twin-spired cathedral, in miniature. The lane as described. The bottom edge continues into gentle hills |
| strip-paladin-alliance-2 | Gentle hills continuing from the top edge. On the left a third of the way down: a small farmstead with a windmill and fenced fields, and a little lighthouse on a rocky coast at the far left edge; below it on the left a dense autumn wood of small round trees with a tiny glowing glade inside; on the right a little past the top third, a proud stone keep with two banners on a rocky hill. The lane as described. Toward the bottom edge the colours turn greyer and the trees sparser |
| strip-paladin-alliance-3 | Grey fields continuing from the top edge into blighted land: bare dead trees, broken fences, a sickly pale green wash in places; on the right a third of the way down a small military camp of tents with a banner beside a little lake; on the left a grim stone ossuary and a ruined city gate; the land darkens toward the bottom, where a small radiant star is painted at the bottom centre, as if the end of the journey lies there. The lane as described |


### Map pieces (shared by every road)

#### The road band (tileable)

The addon lays short slices of these along the road's curve, each turned to follow it, so each is **a horizontal stretch of road whose left and right ends join seamlessly** (the same width and edge position at both ends; nothing that would repeat visibly). The band fills the frame's width and about a third of its height, centred. Gold up to your level, earth after. (`process-art.ps1` stores them 256×64 with the band in rows 23–40; generated images came out 3:1, which is fine.)

| File | Aspect | Background | Subject line |
|---|---|---|---|
| road-band | 4:1 | flat magenta | A short straight horizontal stretch of an old map's road, seamlessly tileable left to right: a band of warm light earth-brown ground with faint brush texture, bordered top and bottom by fine slightly uneven dark sepia ink lines, centred, filling the width, about a third of the height, on a perfectly flat pure magenta (#FF00FF) background |
| road-band-gold | 4:1 | flat magenta | The same stretch of road, seamlessly tileable left to right, its band filled with shining gold leaf with gentle warm highlights and a little crackle, the same fine dark sepia ink lines along both edges, on a perfectly flat pure magenta (#FF00FF) background |

Negative prompt: the chrome one, plus `curve, bend, end caps, rounded ends, pebbles, footprints, wheel ruts, text, letters`.

#### The cartouche (stop names)

A small parchment ribbon behind each stop's name. The addon writes the name on it (the quest pips go in a row under it) and **stretches the middle**, so the middle must be plain and even. (The ribbon sits in rows 33–94 of the 512×128 piece, its notched ends within 48 px of each side.)

| File | Aspect | Background | Subject line |
|---|---|---|---|
| cartouche | 4:1 | flat magenta | A small antique map cartouche: a flat horizontal ribbon of pale aged parchment with a fine dark sepia ink outline, both short ends cut in a swallowtail notch with a tiny curl, the long middle completely plain and evenly coloured with no writing and no decoration, seen straight on, centred, filling the width, on a perfectly flat pure magenta (#FF00FF) background |

Negative prompt: the chrome one, plus `text, letters, writing, scroll rolled ends, seal, wax, shadow on the background`.

#### Milestones (abilities on the road)

A stone at the road's edge for the levels where your class trainer has something, drawn about 26 px tall, so bold and simple. The plain stone means later; a rune fills its face otherwise: **gilded** when every ability there is learned, **red ink** when you can train something now. No flag or pennant (owner). Make `milestone` first and give it as the reference for the two rune stones.

| File | Aspect | Background | Subject line |
|---|---|---|---|
| milestone | 1:1 | flat magenta | A small old roadside milestone seen from the front: a short upright grey-beige stone with a rounded top, drawn with a confident dark sepia ink outline and light hatching on one side, a thin watercolour wash, centred, filling about two thirds of the frame's height, on a perfectly flat pure magenta (#FF00FF) background |
| milestone-rune-gold | 1:1 | flat magenta | The same small rounded grey-beige milestone, a single bold simple rune carved deep into its face and filled with shining gold leaf that glows softly, the rune a straight upright stave with two pairs of short branches angled upward, filling most of the face, dark sepia ink outline, on a perfectly flat pure magenta (#FF00FF) background |
| milestone-rune-red | 1:1 | flat magenta | The same small rounded milestone with the same bold rune drawn on its face in fresh deep red ink (not carved, not gilded), nothing beside the stone, dark sepia ink outline, on a perfectly flat pure magenta (#FF00FF) background |

Negative prompt: the chrome one, plus `text, letters, numbers, moss, grass base, several stones, glowing background, flag, pennant, pole` (and `several runes` for the rune stones, `carving, runes` for the plain one).

#### The focus ring (red ink)

What the gamepad (or mouse) has focused on the map: a cartographer's red-ink circle around the coin or stone. Ink piece, the inside empty.

| File | Aspect | Background | Subject line |
|---|---|---|---|
| focus-ring-red | 1:1 | pure white | One hand-drawn circle in deep red ink, a single confident pen stroke whose ends overlap a little, slightly uneven thickness like a cartographer marking a spot, the inside empty white, centred, filling the frame, on a pure white background |

Negative prompt: `several circles, fill, shading, paper texture, text, letters, arrows, frame, border`.

#### The You token's ring

You on the road: the player's own portrait (drawn by the game) inside a small brass ring, like a token pinned to the map. Metal piece, the centre empty; use the chrome style block.

| File | Aspect | Background | Subject line |
|---|---|---|---|
| you-ring | 1:1 | flat magenta | A small round antique brass ring frame seen straight on, polished warm brass with a fine engraved rope pattern around it and a tiny pin head at the top like a map pin, the whole inside of the ring (about 75% of its width) empty flat magenta, on a perfectly flat pure magenta (#FF00FF) background |

Negative prompt: the chrome one, plus `gems, text, letters, face, portrait inside`.

### The other 17 roads

#### Warrior, Alliance (`strip-warrior-alliance-<n>`)

Stops: start (1) · Defensive Stance, a city tavern (10) · The Shieldsmith, a cave in red hills (20; side paths: three armourers in three cities) · The Affray, a fighting ring in the savanna (30) · Whirlwind Weapon, a windswept mountain camp (30) · Voodoo Feathers, the gate of a blasted red wasteland (50).

| File | Subject (after "The top / middle / bottom of a long journey map.") |
|---|---|
| strip-warrior-alliance-1 | At the top centre a small walled training yard with wooden sparring posts and a stone bell tower, morning light; a third of the way down on the right a cobbled city square with a crooked timber tavern; the land turns to red rocky hills toward the bottom, where a dark cave mouth opens in a red cliff on the left. The lane as described. The bottom edge continues into red hills |
| strip-warrior-alliance-2 | Red rocky hills continuing from the top edge. Near the top: on the left a blacksmith's forge with a glowing chimney, on the right a dwarven gate carved into a mountainside with a forge's fire inside, and a little lower on the right a moonlit elven arbour of pale wood (three armourers). Below, the land opens into golden dry savanna with a ring of sharpened wooden stakes around a sandy fighting pit on the right, and toward the bottom snowy foothills with a windswept stone circle and torn banners on the left. The bottom edge continues into snowy foothills |
| strip-warrior-alliance-3 | Snowy foothills turning to grey marsh and then cracked red wasteland from the top edge. Two thirds of the way down on the right, a broken battle standard and a small stone cairn at the mouth of a red canyon pass; beyond it on the horizon the silhouette of an enormous dark stone gate under a red sky. The ground darkens toward the bottom centre, where a small radiant star is painted. The lane as described |

#### Warrior, Horde (`strip-warrior-horde-<n>`)

Stops: start (1) · Defensive Stance, a watch post on the savanna (10) · Trial at the Field of Giants, a camp of tents in the plains (20; side paths: a troll village by the sea, a mesa city of totems, a ruined city's crypt) · The Affray (30) · Whirlwind Weapon (30) · Voodoo Feathers (50).

| File | Subject |
|---|---|
| strip-warrior-horde-1 | At the top centre a rugged red-rock valley with a small camp of spiked huts and a burning brazier, morning light; a third of the way down on the right a wooden watch tower on a cliff above golden savanna; toward the bottom on the left a camp of hide tents and tall carved totems beside enormous old bones lying in the grass. The lane as described. The bottom edge continues into golden savanna |
| strip-warrior-horde-2 | Golden savanna continuing from the top edge. Near the top: on the left a troll village of thatched stilt huts by a turquoise shore, on the right tall flat-topped mesas with totem poles and longhouses on their tops, and a little lower on the right the sunken stone stairs of a ruined city's crypt among dead pines (three armourers). Below, a ring of sharpened wooden stakes around a sandy fighting pit on the right, and toward the bottom snowy foothills with a windswept stone circle and torn banners on the left. The bottom edge continues into snowy foothills |
| strip-warrior-horde-3 | The same as `strip-warrior-alliance-3`: snowy foothills turning to grey marsh and cracked red wasteland, a broken battle standard and cairn at a red canyon pass two thirds down on the right, an enormous dark stone gate on the horizon, the star at the bottom centre |

#### Hunter, Alliance (`strip-hunter-alliance-<n>`)

Stops: start (1) · Taming the Beast, a forest glade (10) · The Green Drake, a hermit's camp on a crimson coast (50). Few stops: let the wilds between them be wide and open.

| File | Subject |
|---|---|
| strip-hunter-alliance-1 | At the top centre a small timber lodge with antlers over the door in a frosty pine valley, morning light; a little past a third of the way down on the right, a sunlit glade in a giant forest with a beast's den under huge roots and a little archery target; below it rolling wild woodland and a river ford. The lane as described. The bottom edge continues into open woodland |
| strip-hunter-alliance-2 | Open woodland continuing from the top edge into wide grassy plains with distant herds drawn as tiny shapes, a winding river with a wooden footbridge beside the lane, rocky outcrops, then dense dark forest toward the bottom. No buildings. The bottom edge continues into dark forest turning autumn red |
| strip-hunter-alliance-3 | Dark forest from the top edge turning into a crimson and violet autumn forest by a deep blue sea, ancient pale elven ruins half in the trees; two thirds of the way down on the right, a lone hermit's camp with a small fire and a lean-to on a sea cliff. The bottom centre glows warmly around a small radiant star painted on the ground |

#### Hunter, Horde (`strip-hunter-horde-<n>`)

Stops: start (1) · Taming the Beast, a tauren village on the plains (10) · The Green Drake (50).

| File | Subject |
|---|---|
| strip-hunter-horde-1 | At the top centre a small camp of spiked huts and hide tents in a red-rock valley, morning light; a little past a third of the way down on the right, a village of tall hide tents and a windmill-like water pump on rolling golden-green plains, with tall birds' tracks in the grass; below it wild grassland and a river ford. The lane as described. The bottom edge continues into open grassland |
| strip-hunter-horde-2 | The same as `strip-hunter-alliance-2`: open grassland, tiny distant herds, a river with a footbridge, rocky outcrops, dark forest toward the bottom, no buildings |
| strip-hunter-horde-3 | The same as `strip-hunter-alliance-3`: the crimson and violet autumn forest by the sea, elven ruins, the hermit's camp on a sea cliff two thirds down on the right, the star at the bottom centre |

#### Mage, Alliance (`strip-mage-alliance-<n>`)

Stops: start (1) · First Errand, a still lake (10) · Manaweave Robe, a city's mage quarter (15) · Astral Knot Garment, a haunted ruined tower (26) · Mage's Wand and Celestial Power, a stilt hut in a swamp (30, 35) · Destroy Morphaz and Fragmented Magic, an arcane tower on sea cliffs and a sunken temple (50, 60).

| File | Subject |
|---|---|
| strip-mage-alliance-1 | At the top centre a small stone abbey in a sheltered green valley, morning light; a third of the way down on the left a perfectly still lake with a faint violet shimmer on its mirror surface; a little lower on the right, a walled city's quarter of slender towers with violet roofs and arcane lanterns. The lane as described. The bottom edge continues into darkening woods |
| strip-mage-alliance-2 | Darkening woods from the top edge: on the left a third of the way down, a crooked ruined stone tower in a gloomy haunted forest of black twisted trees, a pale glow in its window; further down the land sinks into misty green swamp, and on the right toward the bottom a lone wooden hut on stilts with a violet arcane lantern. The bottom edge continues into misty marsh |
| strip-mage-alliance-3 | Misty marsh from the top edge turning into a crimson autumn coast by a deep blue sea; two thirds of the way down on the right a tall slender arcane tower glowing violet on the top of sea cliffs; a little lower on the left the half-sunken ruins of a temple in the surf. The bottom centre glows around a small radiant star painted on the ground |

#### Mage, Horde (`strip-mage-horde-<n>`)

Stops: start (1) · First Errand, a farmstead's flower fields (10) · Spellfire Robes, a ruined city's crypt quarter (15) · Nether-lace Garment, a forest stream with glowing pools (26) · Mage's Wand and Celestial Power (30, 35) · Destroy Morphaz and Fragmented Magic (50, 60).

| File | Subject |
|---|---|
| strip-mage-horde-1 | At the top centre a small rugged starting camp of huts and a ruined chapel among dark pines, morning light; a third of the way down on the left a little farmstead with fields of bright snapdragon flowers on a hillside; a little lower on the right the sunken entrance of a ruined city's crypts lit by green-glowing arcane lamps. The lane as described. The bottom edge continues into ashen forest |
| strip-mage-horde-2 | Ashen grey-green forest from the top edge: on the left a third of the way down a forest stream with pools glowing violet among broken satyr-carved stones; further down the land sinks into misty green swamp, and on the right toward the bottom a lone wooden hut on stilts with a violet arcane lantern. The bottom edge continues into misty marsh |
| strip-mage-horde-3 | The same as `strip-mage-alliance-3`: the crimson autumn coast, the violet arcane tower on sea cliffs two thirds down on the right, the half-sunken temple ruins on the left, the star at the bottom centre |

#### Priest, Alliance (`strip-priest-alliance-<n>`)

Stops: start (1) · Garments of the Light, a village guard post (5) · Desperate Prayer, a cathedral (10) · Divine Grace, a glowing shrine (10) · A Lack of Fear, a mountain city gate (20) · Blood of Morphaz, a sunken jungle temple (50) · The Balance of Light and Shadow, a burning plagued village (60).

| File | Subject |
|---|---|
| strip-priest-alliance-1 | At the top centre a small stone abbey in a sheltered valley, morning light; just below on the left a little village with a well and a wooden guard post; a third of the way down on the right a grand white cathedral with tall spires, and opposite it on the left a small open-air shrine of white stone with a soft golden glow; toward the bottom, snowy mountains begin. The lane as described. The bottom edge continues into snowy foothills |
| strip-priest-alliance-2 | Snowy foothills from the top edge: near the top on the right a great stone gate carved into a mountainside with a warm glow inside; then a long descent through pine hills into misty lowlands, and toward the bottom the edge of a steaming swamp. No other buildings. The bottom edge continues into misty swamp |
| strip-priest-alliance-3 | Misty swamp from the top edge: a third of the way down on the left a half-sunken stepped jungle temple overgrown with vines in dark water; below, the land turns to pale plagued fields with dead trees, and two thirds of the way down on the right a small village of cottages with smoke rising and a shaft of golden light falling on a chapel. The ground darkens toward the bottom centre, where a small radiant star is painted |

#### Priest, Horde (`strip-priest-horde-<n>`)

Stops: start (1) · Garments of Spirituality, a spiked wooden fort town (5) · Hex of Weakness, a troll shrine (10) · Shadowguard, a canyon city (20) · Blood of Morphaz (50) · The Balance of Light and Shadow (60).

| File | Subject |
|---|---|
| strip-priest-horde-1 | At the top centre a small camp of spiked huts in a red-rock valley, morning light; just below on the left a small fort town of spiked wooden walls on red earth; a third of the way down on the right a troll shrine of carved masks and smoking braziers under palms; toward the bottom, great red canyon walls rise. The lane as described. The bottom edge continues into red canyon country |
| strip-priest-horde-2 | Red canyon country from the top edge: near the top on the left a great canyon city with spiked walls, banners and smoke rising behind its gate; then a long descent through dry hills and scrub into misty lowlands, the edge of a steaming swamp at the bottom. The bottom edge continues into misty swamp |
| strip-priest-horde-3 | The same as `strip-priest-alliance-3`: the half-sunken jungle temple a third down on the left, the plagued fields, the village and chapel in a shaft of golden light two thirds down on the right, the star at the bottom centre |

#### Rogue, Alliance (`strip-rogue-alliance-<n>`)

Stops: start (1) · Thieves' Errand, a harbour (10) · Lockpicking Trial, a lakeside town (16) · The Touch of Zanzil, farmland (20) · The Manor, Ravenholdt, a hidden manor (24) · The Syndicate Sting, a ruined keep (24) · The Eye of Bhossca, a monastery (25, side path) · The Azure Key, a crimson coast (50).

| File | Subject |
|---|---|
| strip-rogue-alliance-1 | At the top centre a small stone abbey with a stable behind it in a green valley, morning light; a third of the way down on the right a city harbour with wooden docks, moored sailing ships and crates; lower on the left a lakeside town with a long stone bridge among red hills; toward the bottom on the right golden farmland with a lone windmill and a ruined farmhouse. The lane as described. The bottom edge continues into wooded hills |
| strip-rogue-alliance-2 | Wooded green hills from the top edge: near the top on the left a dark gabled manor hidden among tall trees on a hillside, a single lit window; a little lower on the right a ruined stone keep on a hill with broken walls; on the far left, a little lower, a grand monastery cathedral with crimson banners. Below, a long journey through quiet hills and a river gorge. The bottom edge continues into hills turning autumn red |
| strip-rogue-alliance-3 | Autumn hills from the top edge turning into a crimson and violet forest by a deep blue sea, ancient pale ruins in the trees; two thirds of the way down on the right a camp of round huts with carved totems at the edge of the forest, and on the sea cliffs beyond it a slender arcane tower. The bottom centre glows around a small radiant star painted on the ground |

#### Rogue, Horde (`strip-rogue-horde-<n>`)

Stops: start (1) · The Shattered Hand, a shadowy cleft in a canyon city (10) · Lockpicking Trial, a walled city under a violet dome (16) · Hinott's Assistance, a hill village with a mill (20) · The Manor, Ravenholdt (24) · The Syndicate Sting (24) · The Eye of Bhossca (25, side path) · The Azure Key (50).

| File | Subject |
|---|---|
| strip-rogue-horde-1 | At the top centre a small camp of spiked huts in a red-rock valley, morning light; a third of the way down on the right a shadowy cleft in red canyon walls with hanging lanterns and a hidden door; lower on the left, beyond dark pine hills, a walled city covered by a huge translucent violet dome of magic; toward the bottom on the right a hill village with a big wooden mill. The lane as described. The bottom edge continues into wooded hills |
| strip-rogue-horde-2 | The same as `strip-rogue-alliance-2`: the hidden manor on the left near the top, the ruined keep a little lower on the right, the crimson-bannered monastery on the far left, then quiet hills and a river gorge |
| strip-rogue-horde-3 | The same as `strip-rogue-alliance-3`: the crimson forest by the sea, the camp of huts with totems and the arcane tower on the cliffs two thirds down on the right, the star at the bottom centre |

#### Shaman, Alliance (`strip-shaman-alliance-<n>`)

Stops: start (1) · Call of Earth, snowy foothills (4) · Call of Fire, a mountain lake and dam (10) · Call of Water, misty wetlands (20) · Call of Air, a stone circle on windswept highlands (30) · The Tempest's Weapons, a bramble warren (30).

| File | Subject |
|---|---|
| strip-shaman-alliance-1 | At the top centre a sturdy stone hall built into a snowy mountainside, morning light; just below on the right, snowy foothills with a tall carved earth totem of stacked stones; a third of the way down on the left a mountain lake held by a huge stone dam, with a burning brazier on a rock above the water; toward the bottom the snow gives way to green valleys. The lane as described. The bottom edge continues into green valleys |
| strip-shaman-alliance-2 | Green valleys from the top edge sinking into misty wetlands of reeds and pools; a third of the way down on the left a clear spring pouring from mossy rocks into a pool; lower on the right windswept highland moors with a ring of standing stones under swirling storm clouds; just below on the left a warren of enormous thorny brambles in dry grass. The bottom edge continues into dry plains |
| strip-shaman-alliance-3 | Dry plains from the top edge: a long open journey past rock outcrops, a river and distant mountains, with no buildings; the land grows wild and stormy toward the bottom centre, where a small radiant star is painted on the ground |

#### Shaman, Horde (`strip-shaman-horde-<n>`)

Stops: start (1) · Call of Earth, a hill with an earth totem (4) · Call of Fire, a brazier on red rock spires (10) · Call of Water, a savanna oasis (20) · Call of Air, towering rock needles (30) · The Tempest's Weapons, a bramble warren (30) · Da Voodoo, a windswept mountain stone circle (50) · The Darkreaver Menace, a gloomy academy on a lake island (58).

| File | Subject |
|---|---|
| strip-shaman-horde-1 | At the top centre a small camp of spiked huts in a red-rock valley, morning light; just below on the left a rocky hill crowned by a tall carved earth totem; a third of the way down on the right tall red rock spires with a burning brazier on the highest; toward the bottom, golden savanna. The lane as described. The bottom edge continues into golden savanna |
| strip-shaman-horde-2 | Golden savanna from the top edge: near the top on the left a palm-ringed oasis pool fed by a spring from a rock; a third of the way down on the right a forest of towering thin rock needles rising from a dry canyon floor; a little lower on the left a warren of enormous thorny brambles. Toward the bottom, the land climbs into snowy mountains. The bottom edge continues into snowy foothills |
| strip-shaman-horde-3 | Snowy foothills from the top edge: a third of the way down on the right a windswept stone circle with streaming banners on a mountain shoulder; below, the land falls to a dark lake, and two thirds of the way down on the left a grim gothic academy on a rocky island in the lake, its windows faintly green. The ground darkens toward the bottom centre, where a small radiant star is painted |

#### Druid, Alliance (`strip-druid-alliance-<n>`)

Stops: start (1) · Body and Heart, a moonlit glade (10) · Child of Nature, a city garden (10, side path) · Power over Poison, a bog of poison blooms (14) · Aquatic Form, a coastal cove (16) · The Great Cat Spirit, a cat statue at a jungle's edge (20) · A Better Ingredient, a volcanic crater jungle (50).

| File | Subject |
|---|---|
| strip-druid-alliance-1 | At the top centre a colossal ancient hollow tree with lanterns among violet-tinted night forest, early morning light; a third of the way down on the right a moonlit glade by a still lake ringed by standing stones; across from it on the far left a small walled garden of a stone city; toward the bottom on the left a misty bog of glowing purple and green poisonous blooms. The lane as described. The bottom edge continues into forest by the sea |
| strip-druid-alliance-2 | Forest by the sea from the top edge: near the top on the right a moonlit coastal cove with a small shrine of pale stone half in the shallows and shells on the sand; a third of the way down on the left a great stone cat statue at the edge of a lush jungle; below, a long journey through wild forest and hills. The bottom edge continues into warm wild hills |
| strip-druid-alliance-3 | Warm wild hills from the top edge sinking into a vast steaming crater of jungle with giant ferns and a smoking volcano; two thirds of the way down on the right a small hermit's camp under a huge fern beside a hot spring. The bottom centre glows around a small radiant star painted on the ground |

#### Druid, Horde (`strip-druid-horde-<n>`)

Stops: start (1) · Body and Heart (10) · Child of Nature, a mesa city of totems (10, side path) · Power over Poison (14) · Aquatic Form (16) · The Great Cat Spirit (20) · A Better Ingredient (50).

| File | Subject |
|---|---|
| strip-druid-horde-1 | At the top centre a camp of tall hide tents on a grassy mesa top, early morning light; a third of the way down on the right a moonlit glade by a still lake ringed by standing stones; across from it on the far left tall flat-topped mesas with totem poles and longhouses; toward the bottom on the left a misty bog of glowing purple and green poisonous blooms. The lane as described. The bottom edge continues into forest by the sea |
| strip-druid-horde-2 | The same as `strip-druid-alliance-2`: the moonlit cove with its half-sunken shrine near the top on the right, the great stone cat statue at the jungle's edge a third down on the left, then wild forest and hills |
| strip-druid-horde-3 | The same as `strip-druid-alliance-3`: the steaming volcanic crater jungle, the hermit's camp by a hot spring two thirds down on the right, the star at the bottom centre |

#### Warlock, Alliance (`strip-warlock-alliance-<n>`)

The busiest road: 7 stops and 6 side paths. Keep every landmark small.

Stops: start (1) · First Lessons, a gloomy cottage (1) · Summon Voidwalker, a crooked city tavern (10) · Summon Succubus, a seer's hut on the savanna (20; side path: a broken stone well with violet orb shards) · Summon Felhunter, a carved mountain library (30; side paths: a tailor's tent with violet runes, a lone tower on a cliff) · Summon Felsteed, a port town (40) · Trolls of a Feather, a corrupted green forest (50; side path: a burning crater) · Dreadsteed of Xoroth, a volcanic wasteland shrine (60; side path: an overgrown ruined elven city).

| File | Subject |
|---|---|
| strip-warlock-alliance-1 | At the top centre a small stone abbey in a green valley, morning light; just below on the left a gloomy little cottage with a dark cellar door; a third of the way down on the right a crooked city tavern with violet light glowing from its cellar windows; toward the bottom on the left a lone seer's hut on a hill in golden savanna, and on the right a broken stone well with faint violet shards around it. The lane as described. The bottom edge continues into savanna rising to mountains |
| strip-warlock-alliance-2 | Savanna from the top edge rising to mountains: near the top on the right a great hall carved into a mountainside with tall bookcase-like stone pillars at its entrance; a third of the way down on the left a dark tent embroidered with violet runes; lower down a small port town of wooden shacks with a pier and a crane on the coast, and above it on the right a lone narrow tower on a sea cliff. The bottom edge continues into sickly green forest |
| strip-warlock-alliance-3 | Sickly corrupted green forest with fel-lit pools from the top edge; a third of the way down on the left a smouldering crater with a black stone at its heart; below, the land burns into a volcanic wasteland of black rock and glowing lava rivers, and two thirds of the way down on the right a demonic shrine of jagged black spires; on the far left a little lower, an overgrown ruined elven city in jungle. The ground glows red toward the bottom centre, where a small radiant star is painted |

#### Warlock, Horde (`strip-warlock-horde-<n>`)

Stops: start (1) · First Lessons, a graveyard (1) · Summon Voidwalker, a crypt temple (10) · Summon Succubus (20; side path: the broken well) · Summon Felhunter, a ruined city's crypts (30; side paths: the tailor's tent, the cliff tower) · Summon Felsteed, the port town (40) · Trolls of a Feather (50; side path: the burning crater) · Dreadsteed of Xoroth (60; side path: the ruined elven city).

| File | Subject |
|---|---|
| strip-warlock-horde-1 | At the top centre a small rugged starting camp among dark pines, morning light; just below on the left a little graveyard of leaning stones and a broken fence; a third of the way down on the right a sunken crypt temple with green-lit braziers at its stairs; toward the bottom on the left a lone seer's hut on a hill in golden savanna, and on the right a broken stone well with faint violet shards around it. The lane as described. The bottom edge continues into savanna |
| strip-warlock-horde-2 | Savanna from the top edge: near the top on the right the sunken stairs of a ruined city's crypts with green-glowing lamps; a third of the way down on the left a dark tent embroidered with violet runes; lower down a small port town of wooden shacks with a pier and a crane on the coast, and above it on the right a lone narrow tower on a sea cliff. The bottom edge continues into sickly green forest |
| strip-warlock-horde-3 | The same as `strip-warlock-alliance-3`: the corrupted forest, the smouldering crater a third down on the left, the volcanic wasteland with the demonic shrine two thirds down on the right, the ruined elven city on the far left, the star at the bottom centre |

#### Paladin, Horde (`strip-paladin-horde-<n>`)

Stops (all by level 20; the rest of the road is open country to the star): start, a small chapel (1) · Rediscovering the Light, a palisade camp (2) · Bandarion Keep, a lakeside fortress (7; side path: a walled garden inside the keep) · A Lesson in Divinity, a ruined city's crypts (12) · Diplomatic Incident, a mausoleum in a dark pine forest (18) · The Moonsilver Blade, a moonlit shrine with a silver sword (20).

| File | Subject |
|---|---|
| strip-paladin-horde-1 | At the top centre a small ruined chapel with a faint golden light in its doorway, in a gloomy village of dead pines and old graves, morning light breaking through grey cloud; just below on the right a wooden palisade camp with tents; a third of the way down on the left a stone fortress on the shore of a grey lake, and beside it on the far left a small walled garden with a fountain; toward the bottom, dark pine forest. The lane as described. The bottom edge continues into dark pine forest |
| strip-paladin-horde-2 | Dark pine forest from the top edge: near the top on the right the sunken stone stairs of a ruined city's crypts with green-glowing lamps; a third of the way down on the left a stone mausoleum among black pines; a little lower on the right a moonlit clearing with a small shrine where a silver sword stands in a stone, glowing softly. Below, the forest thins into open hills. The bottom edge continues into open hills |
| strip-paladin-horde-3 | Open hills from the top edge: a long quiet journey through grassland, a river and rocky rises toward distant mountains, with no buildings; warm light gathers toward the bottom centre, where a small radiant star is painted on the ground |

### The class coins

A finished stop's mark (52 px on the map, 80 in the header; unfinished stops show it greyed and tinted bronze in code): one gold coin per class, shared by Alliance and Horde. Make `coin-paladin` first and give it as the reference for the others, so the rim, metal and lighting match. Use the **chrome style block** (flat magenta, symmetrical, no text); save as `art/source/coin-<class>.png`.

| File | Aspect | Subject line |
|---|---|---|
| coin-paladin | 1:1 | A thick round gold coin seen straight on, polished bright gold with a raised beaded rim, struck in the centre with a warhammer standing upright in a radiant burst of holy light, small rays around it, deep crisp relief, warm highlights, the coin filling the frame |
| coin-warrior | 1:1 | A thick round gold coin seen straight on, the same raised beaded rim and polished gold as the reference coin, struck in the centre with two crossed swords behind a round shield, deep crisp relief, warm highlights, the coin filling the frame |
| coin-hunter | 1:1 | The same gold coin, struck with a drawn longbow and an arrow pointing upward across it, with a small paw print below, deep crisp relief |
| coin-mage | 1:1 | The same gold coin, struck with a radiant eight-pointed star inside a ring of small runic dots, deep crisp relief |
| coin-priest | 1:1 | The same gold coin, struck with a radiant chalice under a small sunburst, deep crisp relief |
| coin-rogue | 1:1 | The same gold coin, struck with two crossed daggers point down and a small hood shape above them, deep crisp relief |
| coin-shaman | 1:1 | The same gold coin, struck with a carved totem pole between a small lightning bolt and a flame, deep crisp relief |
| coin-warlock | 1:1 | The same gold coin, struck with a horned skull above a small flame, deep crisp relief |
| coin-druid | 1:1 | The same gold coin, struck with a bear's paw print framed by two oak leaves, deep crisp relief |

Negative prompt: the chrome one, plus `text, letters, numbers, faces, crown, king's head, currency symbols, colours other than gold`.
