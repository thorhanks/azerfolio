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
| icon-professions | Professions tab | A heavy dark iron blacksmith's anvil seen from a three-quarter front view, a smith's hammer with a wooden handle resting across its top at an angle, a few bright orange sparks flying from the anvil's face, a warm forge glow from below and behind (added 2026-11-14, Phase 15; Codex, with icon-class, icon-reputation and icon-zones attached as the set's reference) |
| icon-dungeons | Dungeons tab | A heavy arched dungeon gateway of dark rough-hewn stone seen from the front, an iron portcullis half raised, warm orange torchlight and a faint ember glow spilling out from the depths beyond, a small carved skull on the keystone, two iron torch brackets with flames either side (added 2026-11-15, Phase 16; Codex, with icon-professions, icon-class, icon-reputation and icon-zones attached as the set's reference; used as made) |

Future tabs add one line each.

### Small glyphs (Phase 15, 2026-11-14)

Painted icons blur below 24 px (review 2026-11-14), so the category icons have flat glyphs for small places. Black silhouette on pure white: `tools/process-art.ps1` keys the white to transparency and turns the ink white (a mask), and the addon tints it. Save as `art/source/glyph-<name>.png`; out: `Media/Chrome/glyph-<name>.blp` (64×64).

```
Simple flat interface glyph, one bold solid pure black (#000000) silhouette on a perfectly flat pure
white (#FFFFFF) background, no shading, no gradients, no grey, no outlines in other colours, no texture,
thick chunky shapes with wide clear gaps between parts so it still reads when shrunk to 16 pixels,
centred, filling about 80% of the square with an even margin, symmetrical where the subject allows,
no text, no letters, no frame, no circle background. 1:1 square.
Subject:
```

Negative prompt: `shading, gradient, grey, colour, texture, 3D, glossy, photo, thin lines, tiny details, text, letters, border, frame, circle background, drop shadow`.

| File | Subject line |
|---|---|
| glyph-explore | A four-pointed compass star (long north-south points, slightly shorter east-west points) inside a thick plain ring, a small white dot cut out at the centre |
| glyph-quests | A single tall bold exclamation mark, the bar slightly wider at the top and tapering down, a round dot below it with a clear gap |
| glyph-flights | A gryphon (eagle head, wings, lion body) flying, seen straight from the front-above with both wide feathered wings spread out to the sides and slightly raised, the head small in the middle; the wing feathers shown as three or four big separate tips on each wing |

## Faction crests (Phase 15 step 8, 2026-11-14)

The Reputation tab's faction mark (36 px on its rows, 30 in the wide split, 72 on the faction page's banner, 24 in the zone ledger; greyed by the addon while not met). Owner's choice in the mockup: a **heraldic shield** (enamel seal and hanging pennant were the alternatives). Twelve majors are painted; every other faction gets `crest-blank` with its initial drawn by the addon. The Codex CLI made Stormwind and Cenarion Circle first (approved as the set's model), then the other ten and the blank in one run with those two attached. Save as `art/source/crest-<key>.png` (1:1); out: `Media/Chrome/crest-<key>.blp` (128×128, keyed). The faction IDs per key are `Theme.crests`.

Style (the chrome block, recoloured):

```
Hand-painted fantasy game user interface ornament in the style of a classic high-fantasy MMO,
aged dark bronze and steel metal with rich coloured enamel, soft shading, subtle warm highlights,
crisp clean silhouette, perfectly symmetrical left to right, front-facing flat orthographic view,
the object fills the frame edge to edge with a small even margin, isolated on a perfectly flat
solid pure magenta (#FF00FF) background, no shadow on the background, no text, no letters.
Subject: a heraldic heater shield (flat top, pointed bottom) with a narrow dark bronze rim and
small rivets, the field in coloured enamel, one emblem raised in relief filling most of the field,
```

Prompt preamble for the set: attach the two approved crests; match their shape, size in the frame, rim, rivets, metal and lighting, changing only the field colour and the emblem; one bold emblem that reads at 24 to 36 px, in a pale metal or colour that contrasts strongly with the field.

Negative prompt: `perspective, 3D render, glossy plastic, neon, sci-fi, busy background, text, letters, numbers, gems, bright polished gold rim, fine filigree, tiny details, drop shadow, asymmetric shape, human faces`.

| File | Faction(s) | Subject line |
|---|---|---|
| crest-stormwind | Stormwind | a proud human kingdom: deep royal blue field, the emblem in pale gold: a lion's head facing front with a full mane |
| crest-cenarion | Cenarion Circle | a circle of nature druids: deep forest green field, the emblem in pale silver-green: a crescent moon cradling three oak leaves |
| crest-ironforge | Ironforge | a mountain dwarf kingdom: deep crimson field, the emblem in pale bronze: a heavy war hammer standing upright before a twin-peaked mountain |
| crest-darnassus | Darnassus | a night elf city in a great tree: deep violet field, the emblem in pale silver: a tall slender tree with a broad rounded crown and a small crescent moon above it |
| crest-gnomeregan | Gnomeregan Exiles | an exiled gnome city of inventors: deep teal field, the emblem in pale brass: a large cogwheel with a small spark at its centre |
| crest-orgrimmar | Orgrimmar | an orc warrior city: deep blood-red field, the emblem in blackened iron with pale edges: a broad double-bladed war axe standing upright |
| crest-thunderbluff | Thunder Bluff | a tauren city on high mesas: warm tan-brown field, the emblem in pale bone white: a bull's head seen from the front with long curved horns |
| crest-undercity | Undercity | an undead city beneath a ruined capital: near-black deep purple field, the emblem in pale sickly green: a bat with wide spread wings seen from the front |
| crest-darkspear | Darkspear Trolls | a jungle troll tribe: deep sea-blue field, the emblem in pale bone white: two crossed spears with small feathers and a pair of curved tusks below them |
| crest-steamwheedle | Steamwheedle Cartel, Booty Bay, Gadgetzan, Ratchet, Everlook | a goblin trading cartel of port towns: deep bottle-green field, the emblem in pale gold-brass: a bulging money sack tied at the top with a rope |
| crest-argentdawn | Argent Dawn | a crusading order against the undead: pale silver-white field, the emblem in deep sky blue: a radiant sun disc with straight rays |
| crest-timbermaw | Timbermaw Hold | a reclusive furbolg tribe of the forest: dark earthy brown field, the emblem in pale moss green: a bear's paw print with four claws above a small pine tree |
| crest-blank | every other faction | the shield left plain: dark warm brown-black enamel field with no emblem at all, only a faint soft highlight; the same bronze rim and rivets |

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

Stops: start (1) · Body and Heart (10) · Child of Nature, a mesa city of totems (10, side path) · Power over Poison, a crossroads outpost on dry savanna (14; the Horde's version is in the northern Barrens, not a bog) · Aquatic Form (16) · The Great Cat Spirit (20) · A Better Ingredient (50).

| File | Subject |
|---|---|
| strip-druid-horde-1 | *(v2, Phase 15 step 10: the poison bog was the Alliance's)* At the top centre a camp of tall hide tents on a grassy mesa top, early morning light; a third of the way down on the right a moonlit glade by a still lake ringed by standing stones; across from it on the far left tall flat-topped mesas with totem poles and longhouses; toward the bottom on the left a patch of dry golden savanna with pale wilting grass and a few lone acacia trees, where a small outpost of spiked timber walls and hide roofs stands beside a tall wooden watchtower. The lane as described. The bottom edge continues into forest by the sea. Give the current panel as an extra reference and keep its layout: the lane, the tents, the lake and the mesas where they are |
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

## Professions tab art (Phase 14, 2026-11-14)

Design: mockups/DESIGN.md "Professions tab". A painted banner (the Journey view's header, cropped to about 3:1 to 5:1 with the skill road over its lower part) and a gold coin per profession (the rail, the road's end, the Overview panel; greyed with a bronze tint until mastered). The Codex CLI (`codex exec`, image generation) made all 24 from these prompts in two runs of about five minutes. Save as `art/source/prof-<key>.png` (banners, 2:1) and `art/source/coin-prof-<key>.png` (coins); `tools/process-art.ps1` converts them to `Media/Professions/<key>.blp` and `Media/Chrome/coin-prof-<key>.blp`. Each banner's subject height is `Theme.profBannerFocus` (default 0.62).

### Banners (12)

Use the **zone art style block and negative prompt** (`art/prompts.md` § Zone art), give Elwynn Forest (1429) as the style reference, and add to the style block: `Keep the lower third calm and simple (a strip covers it) and the upper left quiet for a title. 2:1 landscape.`

| File | Subject line |
|---|---|
| prof-blacksmithing | A village smithy under a timber roof, a stone forge glowing orange with coals, a heavy anvil with a hammer resting on it, a rack of swords and shields, sparks drifting, warm firelight against cool evening shadows |
| prof-mining | The timber-framed mouth of a mine in a rocky hillside, rails leading out to a wooden cart heaped with copper ore, glinting veins of ore in the rock face, lanterns on posts, a pickaxe leaning on the cart |
| prof-herbalism | A sunlit forest glade full of tall flowering herbs, white star-shaped blossoms and silvery leaves, a woven basket of gathered herbs on a mossy stone, soft dappled light |
| prof-skinning | A hunter's camp at a forest edge, pelts stretched on wooden drying frames, a curved knife resting on a tree stump, a small campfire smoking, pines behind |
| prof-alchemy | An alchemist's workshop corner, bubbling glass alembics and flasks of glowing green, blue and red liquids on a wooden bench, bundles of herbs hanging from the beams, warm candlelight |
| prof-enchanting | A quiet tower study at dusk, a stone table carved with glowing violet runes, a slender enchanting rod lying across it, motes of arcane light floating, tall arched window with stars |
| prof-engineering | A cluttered tinker's workshop, brass gears and copper pipes, a half-built mechanical contraption on a workbench, wrenches and blueprints, small puffs of steam, warm lamp light |
| prof-leatherworking | A tannery yard behind a cottage, hides stretched on wooden frames, a workbench with leather tools and a finished leather satchel, barrels, late afternoon light |
| prof-tailoring | A tailor's loft, bolts of coloured cloth stacked on shelves, a spinning wheel, spools of thread and a pincushion on a table, soft light through a round window |
| prof-cooking | A rustic inn kitchen hearth, a cauldron of stew over the fire, copper pots hanging, loaves of bread, vegetables and a joint of meat on a wooden table, cosy warm light |
| prof-firstaid | A field medic's tent interior, rolled linen bandages and small clay jars of salve on a wooden chest, a cot with a folded blanket, lantern light, a red teardrop sigil sewn on a hanging cloth (no cross symbol) |
| prof-fishing | A quiet wooden pier on a calm lake at golden hour, a fishing rod leaning against a post, a bobber floating on still water, reeds and distant hills |

### Skill roads (12, three panels each; owner's choice 2026-11-14)

All 36 panels were made with the Codex CLI (`codex exec`, image generation, about 1.5 minutes a panel; four roads' runs in parallel), Blacksmithing first and approved as the model in the mockup.

The Journey's skill road (1 to 300, left to right, in the banner's foot) on a painted map per profession, in the Class tab strips' antique-map style, so it reads as a map laid over the banner's scene. Left is the trade's humble start, right its mastery; the addon draws the road band, scale, rank stones, gate, You and the coin on top. The road is straight, so **paint no road**: leave a straight plain lane at half height across the whole width, with landmarks beside it, never on it.

Final size 2048×256 (8:1). Image tools make at most 3:2, so each road is **three 3:2 landscape panels side by side** (4.5:1); the pipeline scales them to 2048 wide and keeps the middle 256 rows, centred on the lane. So **everything that matters sits in the middle half of the height**; above it soft distant land fading into parchment, below it plain low ground. The page shows a window of it (about 7:1 to 10:1 by window size), cropping a little top and bottom.

Where the stones fall (default window): Journeyman (50) about halfway across panel 1; Expert (125) a fifth of the way into panel 2; Artisan (200) four fifths across panel 2; the coin (300) at about seven tenths of panel 3. Landmarks need not sit exactly there; the stages just read left to right.

Style block for skill roads (the strips' block, turned on its side):

```
Hand-painted stylized fantasy journey map seen from high above at a gentle angle, a long
panorama read from left to right, painterly with soft visible brush texture, bold simplified
shapes and chunky silhouettes, small landmark buildings and landscape features painted in
miniature, coloured like an antique map: aged parchment ground, sepia and warm umber, muted
sage and olive greens, faded slate blues, soft ochre, fine dark ink outlines around shapes,
subtle paper grain over everything, quiet low saturation, no road, no path, no trail, no people,
no creatures, no text. Everything important sits in the middle half of the image height; the top
quarter is soft distant land fading into pale parchment, the bottom quarter plain low ground.
A narrow straight horizontal lane of plain bare ground, about one tenth of the image height,
runs straight across the whole width at exactly half the image height, from the left edge to the
right edge, with nothing painted in it and the land coming right up to its edges.
Keep the landmarks small and all at one scale, mostly just above the lane, with open ground
between them. 3:2 landscape.
Subject:
```

Negative prompt: the strips' (`text, letters, words, labels, place names, calligraphy, numbers, signature, compass rose, border, frame, road, path, trail, dotted line, wide empty band, saturated colors, neon, photograph, 3D render, people, creatures`) plus `curved lane, diagonal lane`.

**Same for every panel:**
- **References.** Blacksmithing is the set's model; make it first. Its panel 1 takes `art/source/strip-paladin-alliance-1.png` as the style reference. Every other road's panel takes Blacksmithing's matching panel as the style reference. Panels 2 and 3 also take **the same road's previous panel** as the continuity reference: its right edge, the lane at the same height, continues into the new panel's left edge.
- The light changes along the road: morning at the left of panel 1, the most dramatic place at the right of panel 3. Keep the last fifth of panel 3 calm and a little darker (the coin sits there).

Save as `art/source/profroad-<key>-<n>.png` (n = 1 left, 2 middle, 3 right). Subject lines start with "The left / middle / right part of a long journey map."; each line below is what follows.

#### Blacksmithing (`profroad-blacksmithing-<n>`)

| File | Subject line |
|---|---|
| profroad-blacksmithing-1 | At the far left a small thatched village smithy with a smoking chimney beside a few cottages, soft morning light; a charcoal burners' clearing with smouldering mounds in a little wood; a small stone bridge over a stream; just right of the middle a stone forge workshop with a turning waterwheel on the stream. The lane as described. The right edge continues into rocky foothills |
| profroad-blacksmithing-2 | Rocky foothills continuing from the left edge: a quarry and a small mine entrance with an ore cart a fifth of the way across; a walled market town with a tall smiths' guild hall and banners in the middle; four fifths across, great forge halls carved into a grey mountain cliff, glowing orange doorways and tall chimneys. The lane as described. The right edge continues into dark volcanic land |
| profroad-blacksmithing-3 | Dark volcanic land continuing from the left edge: black rock, a river of glowing lava in a gorge below the lane, smoking vents; in the middle a mighty fortress forge built against a fiery mountain, an enormous anvil shape on its terrace, molten light; to the right the land quiets into dark ash plains under a smouldering red dusk. The lane as described |

#### The other 11 (`profroad-<key>-<n>`)

| File | Subject line |
|---|---|
| profroad-mining-1 | At the far left a small timber-framed mine mouth in a green hillside with a wooden ore cart and a lantern post, soft morning light; grey boulders with glinting copper veins; a little smelting hut with a smoking clay furnace; just right of the middle a stony ravine with a deeper mine entrance shored with beams. The lane as described. The right edge continues into high grey hills |
| profroad-mining-2 | High grey hills continuing from the left edge: a terraced open-pit quarry with wooden cranes a fifth of the way across; in the middle a dwarven mining town gate carved into the rock with tall chimneys; four fifths across, a deep shaft head with a great wooden winding wheel above dark caverns glittering with silver and gold veins. The lane as described. The right edge continues into dark mountains |
| profroad-mining-3 | Dark mountains continuing from the left edge: huge crystal-studded rock faces, a cavern mouth glowing with pale blue veins; in the middle an immense ancient mine carved into a mountain's heart, giant stone pillars and glittering dark thorium veins; to the right the land quiets into bare high moorland under a cold violet dusk. The lane as described |
| profroad-herbalism-1 | At the far left a small herbalist's cottage with a walled kitchen garden and drying racks, soft morning light; meadows of white and yellow wildflowers; a little brook with reeds; just right of the middle a sunny forest edge with clumps of tall flowering herbs. The lane as described. The right edge continues into deep green woods |
| profroad-herbalism-2 | Deep green woods continuing from the left edge: a mossy glade with mushrooms and a ring of standing stones a fifth of the way across; in the middle a misty marsh with lilies and twisted willows; four fifths across, a high mountain meadow of silvery-leaved herbs beside a waterfall. The lane as described. The right edge continues into an ancient enchanted forest |
| profroad-herbalism-3 | An ancient enchanted forest continuing from the left edge: giant trees with glowing pale blossoms, soft motes of light; in the middle a sacred grove around a great old tree with luminous flowers at its roots; to the right the land quiets into a moonlit clearing under a deep blue dusk. The lane as described |
| profroad-skinning-1 | At the far left a small hunter's lodge with antlers over the door and pelts drying on frames, soft morning light; open grassland with a few low fences; a tanning tub beside a stream; just right of the middle a forest edge camp with a smoking fire and stretched hides. The lane as described. The right edge continues into rugged wild hills |
| profroad-skinning-2 | Rugged wild hills continuing from the left edge: a trapper's camp with tents and racks of furs a fifth of the way across; in the middle a trading post of log cabins with bundles of hides on carts; four fifths across, a jagged rocky savanna with huge bleached bones of great beasts. The lane as described. The right edge continues into frozen northern wilds |
| profroad-skinning-3 | Frozen northern wilds continuing from the left edge: snowy pine forest, a frozen lake; in the middle a great hunting hall of timber and stone hung with enormous white pelts and dragon scales, banners of hide; to the right the land quiets into snowfields under a pale cold dusk. The lane as described |
| profroad-alchemy-1 | At the far left a small apothecary cottage with a herb garden and a bubbling cauldron in the yard, soft morning light; a pond with glowing green reeds; a little stone well; just right of the middle a stone workshop with glass alembic chimneys puffing coloured smoke. The lane as described. The right edge continues into misty marshland |
| profroad-alchemy-2 | Misty marshland continuing from the left edge: bubbling springs of coloured water a fifth of the way across; in the middle a walled town with a tall alchemists' guild hall crowned by a great glass dome; four fifths across, a twisted tower on a rocky hill wreathed in green and violet vapours. The lane as described. The right edge continues into strange crystalline land |
| profroad-alchemy-3 | Strange crystalline land continuing from the left edge: pools of glowing liquid, crystal spires; in the middle a grand laboratory citadel with copper domes and a vast glowing flask-shaped tower, coloured light spilling out; to the right the land quiets into still dark plains under a shimmering violet dusk. The lane as described |
| profroad-enchanting-1 | At the far left a small stone cottage with a pointed roof and a faintly glowing window, soft morning light; a circle of standing stones with faint violet runes; a little bridge over a quiet stream; just right of the middle a slim stone tower with a glowing crystal at its top. The lane as described. The right edge continues into twilight hills |
| profroad-enchanting-2 | Twilight hills continuing from the left edge: floating rune stones above a hilltop a fifth of the way across; in the middle a walled town with a tall violet-roofed mages' academy; four fifths across, ancient elven ruins with arches glowing with arcane light. The lane as described. The right edge continues into a starlit arcane land |
| profroad-enchanting-3 | A starlit arcane land continuing from the left edge: floating islands of rock, ribbons of violet light; in the middle a towering spire of white stone wrapped in glowing runes with a great floating crystal above it; to the right the land quiets into dark plains under a deep starry indigo dusk. The lane as described |
| profroad-engineering-1 | At the far left a small tinker's shed with a crooked chimney and a weathervane of gears, soft morning light; a little windmill with patched sails; a wooden test ramp with a scorched crater; just right of the middle a brick workshop with a water-driven gear wheel. The lane as described. The right edge continues into rocky badlands |
| profroad-engineering-2 | Rocky badlands continuing from the left edge: rickety pipelines and pumping derricks a fifth of the way across; in the middle a gnomish town of copper roofs, cog towers and puffing smokestacks; four fifths across, a great workshop hangar with a half-built flying machine on its roof. The lane as described. The right edge continues into a desert of brass machines |
| profroad-engineering-3 | A desert continuing from the left edge, dotted with brass machines and steam vents; in the middle a mighty mechanical city with enormous turning gears, clock towers and a zeppelin moored above it; to the right the land quiets into dusky dunes under a smoky orange dusk. The lane as described |
| profroad-leatherworking-1 | At the far left a small cottage with a tanning yard, hides stretched on wooden frames, soft morning light; barrels and a tanning pit beside a stream; a little cattle pasture; just right of the middle a workshop with leather saddles and harness hanging outside. The lane as described. The right edge continues into rolling grassland |
| profroad-leatherworking-2 | Rolling grassland continuing from the left edge: a nomad camp of round hide tents a fifth of the way across; in the middle a market town with a tall leatherworkers' guild hall and hanging hide banners; four fifths across, a mountain stronghold of timber walls draped with great scaled hides. The lane as described. The right edge continues into wild swamp and jungle |
| profroad-leatherworking-3 | Wild swamp and jungle continuing from the left edge: enormous ferns, a misty river; in the middle a grand lodge built of huge timbers hung with giant dragon hides and gleaming scale armour on stands; to the right the land quiets into dark wetland under a deep green dusk. The lane as described |
| profroad-tailoring-1 | At the far left a small thatched cottage with a spinning wheel by the door and linen drying on a line, soft morning light; a flax field and a sheep pen; a little dye vat by a stream; just right of the middle a weaver's house with a large loom visible through an open wall. The lane as described. The right edge continues into gentle farmland |
| profroad-tailoring-2 | Gentle farmland continuing from the left edge: rows of mulberry trees and a silk house a fifth of the way across; in the middle a walled town with a tall tailors' guild hall hung with long coloured cloth banners; four fifths across, a hilltop manor with bright dye vats and bolts of rich fabric drying in the wind. The lane as described. The right edge continues into a magical twilight land |
| profroad-tailoring-3 | A magical twilight land continuing from the left edge: trees hung with glimmering threads; in the middle a grand palace of white towers draped with flowing banners of shimmering runecloth and moonlit silk; to the right the land quiets into soft plains under a silvery blue dusk. The lane as described |
| profroad-cooking-1 | At the far left a small farmhouse with a smoking chimney and a vegetable garden, soft morning light; a chicken coop and an apple orchard; a little mill by a stream; just right of the middle a village inn with a big outdoor bread oven. The lane as described. The right edge continues into fields and hills |
| profroad-cooking-2 | Fields and hills continuing from the left edge: a smokehouse and drying fish racks by a lake a fifth of the way across; in the middle a busy market town with food stalls, awnings and a great tavern; four fifths across, a hunting lodge with roasting spits over big fire pits. The lane as described. The right edge continues into a grand coastal land |
| profroad-cooking-3 | A grand coastal land continuing from the left edge: vineyards and spice gardens; in the middle a magnificent feast hall with long tables under great arches, steaming cauldrons and banners; to the right the land quiets into calm shore under a warm golden dusk. The lane as described |
| profroad-firstaid-1 | At the far left a small stone chapel cottage with a herb garden and white linen drying on a line, soft morning light; a little well; a field tent with a red teardrop banner (no cross); just right of the middle a small healer's house with bandage rolls on its porch. The lane as described. The right edge continues into a quiet valley |
| profroad-firstaid-2 | A quiet valley continuing from the left edge: a roadside shrine with a spring a fifth of the way across; in the middle a walled town with a large infirmary hall and rows of white tents; four fifths across, a military field hospital of canvas tents with red teardrop banners (no cross) behind a palisade. The lane as described. The right edge continues into a rugged frontier |
| profroad-firstaid-3 | A rugged frontier continuing from the left edge: a ruined watchtower, a field of tents; in the middle a great white stone house of healing with a tall tower and a softly glowing teardrop emblem (no cross); to the right the land quiets into calm plains under a gentle rose dusk. The lane as described |
| profroad-fishing-1 | At the far left a small fisherman's hut on stilts beside a pond, nets hung to dry, soft morning light; reeds and lily pads; a little wooden jetty with a rowing boat; just right of the middle a stream with a stone bridge and a weir. The lane as described. The right edge continues into a wide lake |
| profroad-fishing-2 | A wide lake continuing from the left edge: a fishing village with boathouses on the shore a fifth of the way across; in the middle a river harbour town with sailing boats and a lighthouse; four fifths across, a rocky coast with a long pier and crab pots. The lane as described. The right edge continues into open sea |
| profroad-fishing-3 | Open sea continuing from the left edge: rocky islets with a tall sea stack; in the middle a grand harbour of stone quays with tall ships at anchor and a great lighthouse; to the right the water quiets into calm sea under a deep amber dusk. The lane as described |

### Coins (12)

Use the **chrome style block** (flat magenta, symmetrical, no text) and the class coins' negative prompt, and give `coin-paladin` as the reference so rim, metal and lighting match the class coins. Save as `art/source/coin-prof-<key>.png`.

| File | Subject line |
|---|---|
| coin-prof-blacksmithing | The same gold coin, struck with an anvil and a hammer above it, deep crisp relief |
| coin-prof-mining | The same gold coin, struck with two crossed pickaxes over a nugget of ore, deep crisp relief |
| coin-prof-herbalism | The same gold coin, struck with a five-petalled flower on a stem with two leaves, deep crisp relief |
| coin-prof-skinning | The same gold coin, struck with a curved skinning knife over a small stretched pelt, deep crisp relief |
| coin-prof-alchemy | The same gold coin, struck with a round-bottomed flask with a few bubbles rising, deep crisp relief |
| coin-prof-enchanting | The same gold coin, struck with a slender rod topped by a four-pointed sparkle, deep crisp relief |
| coin-prof-engineering | The same gold coin, struck with a cogwheel crossed by a wrench, deep crisp relief |
| coin-prof-leatherworking | The same gold coin, struck with a rounded knife over a folded hide, deep crisp relief |
| coin-prof-tailoring | The same gold coin, struck with a spool of thread pierced by a needle, deep crisp relief |
| coin-prof-cooking | The same gold coin, struck with a round cooking pot with three wisps of steam, deep crisp relief |
| coin-prof-firstaid | The same gold coin, struck with a rolled bandage and a teardrop above it (no cross), deep crisp relief |
| coin-prof-fishing | The same gold coin, struck with a fish leaping over a fishing hook, deep crisp relief |

### Dull coins (12; Phase 15 step 3, 2026-11-14)

A profession you haven't mastered shows a painted bronze coin (the code-greyed gold coin read as the same brown disc for every trade at 48 px, review R5). Same coin, same emblem in the same place, struck in worn dark bronze with the emblem polished lighter against a darker field and a quiet border, so the emblem reads at 40 px. The Codex CLI made Blacksmithing and Herbalism first from their gold coins (owner picked them in `mockups/small-art.html`, option C), then the other ten in two runs with those two attached as the approved model. Save as `art/source/coin-prof-<key>-dull.png`; out: `Media/Chrome/coin-prof-<key>-dull.blp`.

Style: the chrome style block with its metal line replaced by `aged dark bronze and dull pewter metal, soft shading`, and the gold coin attached as the reference. Subject line: `the same coin in worn dark bronze, <the gold coin's emblem from the table above>, deep crisp relief, the emblem polished lighter bronze against a darker field.` Prompt preamble: keep the emblem bold and readable at 40 pixels, a little lighter than the field; keep the border plain and quiet.

Negative prompt: `gold, shiny gold, glow, gems, perspective, 3D render, glossy plastic, neon, busy background, text, letters, numbers, faces, crown, currency symbols, busy filigree border`.

## Dungeons and raids (Dungeons tab, 2026-11-15)

Design: mockups/DESIGN.md "Dungeons tab". One painting per instance (41, keys from `Azerfolio/Data/Dungeons.lua`), shown big on the tab's cards (16:10), in the page's banner (about 5:1), as a round medallion on the adventurer's road, and on Zone Detail's dungeon tile. Until a painting exists, the entrance zone's art stands in. Save as `art/source/dungeon-<key>.png` (2:1, like zone art); `tools/process-art.ps1` converts it to `Media/Dungeons/<key>.blp` and `mockups/dungeon-art/<key>.png` and lists it in `Data/Art.lua` (`dungeons`). The Codex CLI (`codex exec`, image generation) can make them in batches, with the approved zone art attached as the style reference. **First six made 2026-11-15** (two runs of three in parallel, `art/source/1429-elwynn-forest.png` attached, about 6 minutes; 1774×887): deadmines, wailing, scholomance, moltenCore, hallOfThanes, drownedCity. **The other 35 the same day** (six runs of five or six in parallel, `dungeon-deadmines` and `dungeon-hallOfThanes` attached as the style reference, about 15 minutes; all used as made, reviewed on contact sheets).

Use the **zone art style block and negative prompt** (§ Zone art) with Elwynn Forest (1429) as the style reference, and add to the style block: `An interior or entrance of a dungeon: the place's signature hall, gate or landmark large and centred so it still reads when cropped to a circle; dramatic light from one source; the lower fifth simple and dark (a title sits over it). 2:1 landscape.` The negative prompt's "no creatures" still holds: show the place, never the bosses.

| File | Subject line |
|---|---|
| dungeon-ragefire | A volcanic cavern under a city, rivers of glowing lava between black basalt ledges, crude orcish wooden walkways and spiked banners, red-orange glow, rising smoke |
| dungeon-deadmines | A vast underground mine cavern opening onto a hidden cove, a huge half-built wooden pirate warship moored at a rough dock inside the cave, mine carts and rails, lanterns, shafts of daylight from the cave mouth |
| dungeon-wailing | A deep green cavern system with pools of glowing teal water, giant twisted roots and luminous mushrooms, ancient night elf stone carvings overgrown with vines, misty dim light |
| dungeon-shadowfang | The courtyard of a dark gothic keep at night, tall stone towers with lit arched windows, iron gates and a wolf-head stone crest, cold moonlight and drifting fog |
| dungeon-stockade | A grim stone prison block beneath a city, rows of iron-barred cells along a torch-lit corridor, damp flagstones, chains on the walls, a heavy portcullis |
| dungeon-blackfathom | A sunken night elf temple half-drowned in a dark sea cave, moonwell-blue water, broken marble columns and a great carved archway, bioluminescent light on the water |
| dungeon-gnomeregan | A colossal gnomish city of brass and steel inside a mountain, gears, pipes and catwalks, sickly green radiation glow pooling below, flickering electric lamps |
| dungeon-razorfenKraul | A maze of enormous thorny brambles in a dusty savanna, tunnels woven from giant barbed vines, crude quillboar totems and bone fetishes, warm dusty light |
| dungeon-smGraveyard | A walled monastery graveyard at dusk, crooked tombstones and stone crypts, a crimson-bannered cloister wall behind, pale mist between the graves |
| dungeon-smLibrary | A grand monastery library, towering oak bookshelves and reading desks, crimson banners with a gold flame sigil, candlelight and dust in the air |
| dungeon-smArmory | A monastery armory and training hall, racks of polished swords, shields and crimson tabards, practice dummies, a long hall with high windows |
| dungeon-smCathedral | The nave of a vast crimson-and-gold cathedral, tall stained-glass windows, rows of pews leading to a raised altar, shafts of holy light |
| dungeon-razorfenDowns | A huge mound of withered thorny brambles under a dark sky, bone-strewn paths spiralling up to a skull-crowned summit, cold blue unholy light |
| dungeon-uldaman | An ancient titan vault deep under a desert canyon, enormous carved stone doors and statues of giant stone guardians, glowing blue runes, dusty excavation scaffolding |
| dungeon-zulfarrak | A sand-blasted troll city in a desert, stepped sandstone pyramids and broken walls, a great stairway to a temple, a dry pool at its foot, harsh noon sun |
| dungeon-maraudon | A vast crystal cavern with a waterfall pouring into a lush underground garden, purple and orange crystals, ancient twisted trees, soft magical light |
| dungeon-sunkenTemple | The interior of a sunken troll temple, a great domed chamber half-flooded with green water, carved serpent pillars, an altar on a stepped dais, eerie green light |
| dungeon-blackrockDepths | A colossal dwarven city of black iron built inside a volcano, forges and lava channels, a great throne hall behind a huge iron gate, orange glow and smoke |
| dungeon-lowerSpire | The lower halls of a black volcanic fortress, rough orc and ogre camps, war banners, spider-web-filled side passages, torches and red light |
| dungeon-dmEast | Overgrown ruins of an elven city in a forest, a twisted corrupted ancient tree growing through broken marble halls, green-violet light |
| dungeon-dmWest | The gardens of a ruined elven capital, ornate courtyards with crumbling statues, pylons of arcane crystal, a pale violet glow at dusk |
| dungeon-dmNorth | A ruined elven palace taken over by ogres, crude wooden fortifications and stolen banners in a grand marble hall, a rough throne at the end |
| dungeon-scholomance | A haunted castle school's dungeon, a vaulted stone chamber with dusty desks, tall bookshelves, a glowing green ritual circle on the floor, candles |
| dungeon-stratholme | A burning plagued city street at night, timber-framed houses and a cathedral spire, green plague fog, glowing embers, a slaughterhouse ziggurat in the distance |
| dungeon-upperSpire | The top of a black volcanic fortress, a great dragon-perch hall with chains and huge iron braziers, red dragon banners, lava glow below |
| dungeon-hallOfThanes | A royal dwarven burial hall beneath a mountain city, rows of carved stone thane statues with hammers, tombs and runic pillars, a ghostly blue light |
| dungeon-ruinsOfLordaeron | The ruined throne room of a fallen human capital, broken marble columns and a shattered throne, torn blue-and-gold banners, ivy and grey mist |
| dungeon-excavationSite | A deep dwarven excavation pit in a marsh, wooden scaffolding and ladders around a half-uncovered ancient stone relic, lanterns, rain clouds overhead |
| dungeon-dalaran | The sewers beneath a magical city, stone tunnels with violet glowing runes, arcane crystals growing from the walls, a grate opening to a violet sky |
| dungeon-drownedCity | A sunken city under a tropical sea, coral-covered stone towers and archways, shafts of sunlight through the water, a wrecked pirate ship among the ruins |
| dungeon-kroldok | A huge ogre war stronghold of rough timber and stone in a river valley, spiked palisades, slave pens and twilight-purple banners, campfires at dusk |
| dungeon-alcazPrison | A grim island prison fortress of grey stone on a rocky sea crag, high walls and watchtowers, a dark cellar entrance, stormy marsh light |
| dungeon-blackmawHold | A corrupted furbolg den deep under a forested mountain, a long-sealed carved stone gate opening into tunnels, sickly green fel glow, giant roots |
| dungeon-shapersTerrace | A vast titan terrace on a jungle crater rim, huge carved stone platforms and four great glowing coloured crystals (red, blue, green, yellow), lush prehistoric jungle below |
| dungeon-zulgurub | A great troll temple city in a jungle, a huge stepped pyramid with a blood-red altar at its top, serpent statues, river and mist, red evening sky |
| dungeon-onyxia | A volcanic dragon's lair, a huge cavern littered with bones and eggs, lava vents, a raised rocky nest in the centre, red-orange glow |
| dungeon-moltenCore | The molten heart of a volcano, rivers and lakes of lava, black rock bridges and runes glowing on stone, a fiery pool at the centre |
| dungeon-blackwingLair | A black dragon's fortress at the peak of a mountain, laboratories with glowing vats and chains, dragon banners, a high balcony over lava |
| dungeon-ruinsOfAhnQiraj | Ruined insectoid temples half-buried in desert sand, giant curved carved pillars and scarab sigils, a dusty golden haze |
| dungeon-templeOfAhnQiraj | The entrance of a colossal insectoid temple carved into a desert cliff, giant carved figures and curved spires, an eerie violet glow from within |
| dungeon-naxxramas | A dark floating necropolis ziggurat in a stormy sky above a plagued land, green runes glowing on its stone, sickly green light |

### The adventurer's road (optional, if the owner picks that view)

One long painted strip behind the medallions, like the Class tab's strips: left to right the world grows darker and higher-level, from green farmland and a lighthouse coast (low levels) through savanna, swamp and desert, to volcanic black mountains and a plagued land at the far right, with a dark citadel at the end for the raids. A pale dirt road winds along the middle. Three 3:2 panels stacked into one strip, like the profession roads (`process-art.ps1`); prompts to write once the view is chosen.

### Card corner flourish (round 3, owner 2026-11-15: "the cards need a custom art border flourish")

The big art cards (Dungeons and Zones) wear the painted gilded card frame (`frame-card`) and a filigree ornament on each corner; the mockup draws the corners as a stand-in. One painted corner, mirrored by code for the other three. Save as `art/source/card-corner.png`; `process-art.ps1` treats it as chrome (`Media/Chrome/card-corner.blp`).

Use the **interface chrome style block** (§ Interface chrome) with `frame-card` attached as the reference. Subject line: `one top-left corner ornament for a gilded picture frame: a gold filigree scroll curling out from the corner along both edges, a small leaf and a round boss at the turn, deep relief, polished gold with dark bronze shadows, on a transparent background; the two arms end in fine points about 80% of the way along; square image.` Negative prompt: `full frame, four corners, text, gems, faces, perspective, background scenery, glow`.

### The adventurer's road backdrop (round 3: the owner kept the Road view)

One long painted strip behind the road, like the Class tab's strips: three 3:2 panels stacked into one 6:1 strip by `process-art.ps1` (as `profroad-<key>-<n>`; here `dungeonroad-<1..3>`, out `Media/Chrome/dungeon-road.blp`). Left to right the land grows darker and higher-level; a pale dirt road winds along the middle third; the top fifth and bottom fifth plain parchment-coloured ground (signs and name plates sit there).

Use the **zone art style block and negative prompt**, with `paladin-alliance` strip panels attached as the style reference, and add: `A panoramic antique-map landscape seen from above at a gentle angle, seamless where panels meet, no buildings larger than a small hut, no landmarks in the top and bottom fifths.`

| File | Subject line |
|---|---|
| dungeonroad-1 | Green farmland and a lighthouse on a sea cliff, a mine entrance in a hillside, then dry golden savanna with thorny brambles |
| dungeonroad-2 | A misty swamp, then red desert canyons with a sand-buried pyramid, then grey highlands with a ruined monastery on a hill |
| dungeonroad-3 | Black volcanic mountains with lava glow, then a plagued land of dead trees and green fog, ending in a dark spiked citadel at the right edge |

### Subtle card frames (round 4, owner 2026-11-15: "on style/theme but more subtle")

Replaces the round 3 corner flourish for the art cards (Dungeons and Zones grids). Three options made with the Codex CLI in one run, `frame-card` attached as the style reference; saved as `art/source/card-frame-a.png`, `-b`, `-c` (1024 square, transparent centre and outside); `process-art.ps1` treats them as nine-slice chrome (`Media/Chrome/card-frame-<x>.blp`, 256 square). Prompt (abridged): a square nine-slice picture-frame border for a grid of cards showing landscape paintings; same painted style as the attached frame but much more subtle and thin (band at most about 3% of the width), small corner accents only, straight uniform sides, transparent centre with a clean inner edge, aged gold, bronze and dark leather, soft shading, no glow, gems, text or faces. A (**chosen by the owner, 2026-11-15**): a single thin line of worn bronze-gold with a darker inner bevel and a tiny stud at each corner. B: a double gold hairline meeting in a small diamond knot at each corner. C: a thin dark-iron band with a faint gold inner edge and a small angular bronze corner bracket reaching about 6% along each side.

### Boss seals and the road's regions (round 6, 2026-11-15; made with the Codex CLI)

**Boss seals** (`art/source/boss-seal.png`, `-rare`, `-opt`; 1024 square on flat magenta; `process-art.ps1` keys them like the coins: `Media/Chrome/boss-seal*.blp`, 128 square, DXT5). The UI paints the boss's number on top. Chrome style block, a coin and frame A attached. Subject: a round numbered seal for marking a dungeon's bosses in order, the centre a smooth plain slightly recessed light field (for a dark number). `boss-seal`: a thick warm bronze disc with a raised rim of small beads and a thin gold edge. `boss-seal-rare`: the same in cool blue steel and silver. `boss-seal-opt`: an open thin bronze ring with a beaded rim, the inside empty (hollow).

**The adventurer's road regions** replace the three-panel strip above: the road is about 16:1 (41 stops), too long for one painting, so **one 2:1 painting per level region** (`art/source/dungeon-road1.png` .. `-road6`; processed like the dungeon paintings to `Media/Dungeons/road<n>.blp`), each drawn behind its stretch of road and cross-faded into the next (80 px). Zone and dungeon style, the Deadmines painting and Elwynn Forest attached; each a wide panorama with no centred landmark, a pale dirt road crossing left to right through the middle at mid-height so they join, open ground at both edges, slightly muted. 1: green farmland by a sea coast, a lighthouse far off, a mine entrance. 2: dry golden savanna with thorny brambles giving way to a misty swamp. 3: grey-green highlands, a distant ruined monastery. 4: red desert canyons and mesas, a distant sand-buried pyramid. 5: black volcanic mountains with lava becoming a plagued land of dead trees and green fog. 6: a dark approach to a spiked citadel and a floating necropolis under a stormy red-violet sky, braziers along the road.

### Medallion rings (round 8, 2026-11-15; Codex)

The Road view's round dungeon pictures sit in a painted ring (`art/source/medallion-ring.png`, `-raid`, `-gold`; 1024 square on flat magenta, the whole inside empty; `process-art.ps1` keys them like the coins: `Media/Chrome/medallion-ring*.blp`, 128 square). Chrome style block, the boss seal and frame A attached. Subject: a round picture-frame ring around a circular dungeon painting on a map, the band about one eighth of the width with a crisp inner edge, small ornaments only on the band (nothing sticking out). `medallion-ring`: warm dark bronze, a fine raised beaded inner rim, a thin gold outer edge, four tiny studs at top, bottom, left and right. `-raid`: the same in blood-red enamel and blackened bronze. `-gold`: polished bright gold with a laurel-leaf pattern along the band (every quest done). The painting sits inside at 78% of the ring's diameter.
