# Professions tab art: draft prompts (Phase 14, 2026-11-14)

The Professions tab ships with stand-ins: a tinted gradient banner with the profession's icon faint behind it (`Theme.layout.profTab.tones`), and the icon in a ring for the coin. The owner chose a painted banner and a coin per profession (decision log 2026-11-13). `art/prompts.md` holds only the prompts of shipped art (decision 2026-11-13), so these drafts live here until the pieces are made; move each one there when its art ships.

## Pipeline notes (to do when the art is made)

- **Banners:** shown 1:3.3 or wider (the page is about 1,000 px wide, the banner 250-330 px tall), with the skill road on a parchment strip over the bottom third and the name and skill over the top left and top right. Generate at **2:1 (1024×512 BLP, like zone art)** and crop by a focus like `Theme.bannerFocus`. `tools/process-art.ps1` needs a new kind for them (`art/source/prof-<key>.png` → `Media/Professions/<key>.blp`, an entry in `Data/Art.lua`); the page then sets the texture instead of the gradient.
- **Coins:** chrome pieces, like the class coins: `art/source/coin-prof-<key>.png` → `Media/Chrome/coin-prof-<key>.blp`. The page's `newCoin` uses the coin when `Theme.Chrome("coin-prof-<key>")` exists (dull bronze tint until mastered, as the class coins do), else the icon in a ring.
- Keys: alchemy, blacksmithing, enchanting, engineering, herbalism, leatherworking, mining, skinning, tailoring, cooking, firstaid, fishing (`Data/Professions.lua`).

## Banners (12)

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

## Coins (12)

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
