# Ashen Depths: Act I (Godot 4)

A Diablo II-style isometric action RPG: a starting town and the eight areas of Act I.

## Run it
1. Install Godot 4.3 or newer (standard build, no .NET needed).
2. In the Project Manager choose **Import**, pick this folder's `project.godot`, then press **F5**.

| Key | Action |
| --- | --- |
| Left click | Walk, attack, talk, use waypoints and doorways, pick up (hold to keep walking) |
| Right click / F | Fireball toward the cursor |
| Space | Frost Nova (from level 3) |
| 1 · 2 | Drink a healing or mana draught from the belt |
| C · I · Tab | Character panel, inventory, automap |
| T | Open a town portal |
| M · Esc | Sound, close panels |
| L | Graphics quality: Low, Medium or High (remembered). The browser starts at Medium |

## Act I
| # | Area | Kind | Monster rank | Boss |
| --- | --- | --- | --- | --- |
| 0 | Vell's Hollow | town | none | none |
| 1 | The Ashen Moor | open | 1 | Grisk the Gnawer |
| 2 | Gallows Fields | open | 2 | Hangman Orrel |
| 3 | Hollowroot Cave | dungeon | 3 | Mother Cinder |
| 4 | The Sunken Ossuary | dungeon | 4 | Ossric the Unburied |
| 5 | Witherwood | open | 5 | Old Thornhide |
| 6 | Ruins of Calder | open | 6 | The Pale Huntress |
| 7 | The Abbey of Vell | dungeon | 7 | The Hollow Abbot |
| 8 | The Lampless Deep | dungeon | 8 | The Lampless King |

- Names and order never change; the shape of every area is generated from its own seed once per run.
- **Open areas** are wide (about 100 x 110 tiles), with a road from the entrance to the exit. Each has its
  own dressing: ponds, rock fields and stone circles on the moor; farmhouses, fences, hay and gallows in the
  fields; dense trees in the Witherwood; ruined houses, cobbles, pillars and a graveyard in Calder.
- **Dungeons** are narrow: a cave grown by cellular automaton, crypts of rooms and corridors, the abbey
  split into halls and chambers with doorways, and the cavernous Deep.
- **Waypoints**: one per area. Walking onto one activates it; clicking one opens the list of every
  waypoint found so far, the town's included.
- **Town**: Elder Maelis (advice for the next area), Sister Wren (heals for free, sells draughts, rings,
  amulets and charms), Garrick the Smith (weapons and armour). Stock is rerolled each visit.
- **Bosses** wait near the way on with a large escort and seal it until they die. Bosses and unique
  sub-bosses stay dead for the rest of the run; ordinary monsters return when you re-enter an area.
- Dying sends you back to town with a tenth of your gold lost.

## Monsters and ranks
- 15 kinds: scrabbler, bonewalker, hexcaller, brute, warden, rotling, gloomhound, quillback, bone archer,
  wraith, zealot, reaver, moon sister, spitter and thornback. Some throw hexes (lightning), arrows, quills
  or bile (poison); wraiths chill.
- **Rank** 1 to 12 sets monster level (1, 3, 5 ... 23), life (x1.3 per rank), damage (x1.17 per rank),
  defense, attack rating and experience. Every rank has its own colour, and every three ranks a new name
  (Scrabbler, Gnasher, Pitspawn, Ashfiend).
- Ordinary packs use the area's rank; about one monster in eight is a veteran one or two ranks higher.
- 2 to 4 **unique sub-bosses** per area: rank +2, gold name, one or two modifiers (Extra Strong, Extra Fast,
  Stone Skin, Fire Enchanted, Cold Enchanted, Mana Burn), with minions at rank +1.
- The **area boss** is rank +4, larger, with one modifier and five to seven minions.

## The hero (Diablo II rules)
- Strength 25, Dexterity 20, Vitality 25, Energy 15 to start; 5 stat points per level, spent on the
  character panel.
- Strength adds 1% weapon damage per point. Dexterity adds 5 attack rating per point and 1 defense per
  4 points, and raises block chance. Vitality gives 3 life, Energy 2 mana.
- Chance to hit is Diablo II's: 2 x AR / (AR + defense) x your level / (your level + monster level), held
  between 5% and 95%. Monsters roll the same against your defense.
- Block chance = shield block x (Dexterity - 15) / (level x 2), at most 75%.
- Resistances (fire, cold, lightning, poison) cap at 75%. Damage Reduced subtracts from physical hits.

## Items
- Slots: helm, amulet, body armour, weapon, shield, gloves, belt, boots and two rings. The belt sets how
  many draughts you can carry (3 without one, up to 8).
- 10 x 4 inventory grid; items take 1x1 to 2x3 cells. Click to pick up and put down, right-click to wear
  (or to sell while trading). Click the ground to drop what you hold.
- 17 weapon bases, 5 shields, 10 body armours, 6 helms, 4 each of gloves, belts and boots, plus amulets,
  rings and Small, Large and Grand **charms**, which work while they sit in the inventory.
- Each base has level, Strength and Dexterity requirements. Unmet requirements show red and the item
  does nothing.
- Normal, magic (one prefix and/or suffix), rare (3 to 5 affixes) and 16 named uniques. About 30 affix
  families with item-level tiers: enhanced damage and defense, attack rating, the four attributes, life,
  mana, resistances, elemental damage, life and mana leech, attack and run speed, block, damage
  reduction, thorns, regeneration, magic and gold find.
- Every item has a seed, so its inventory picture varies: blade and guard shape, pommel, gems, rivets,
  trims, shoulder guards and colour. Worn gear also changes the hero: helm, armour (light, medium or
  heavy), gloves, belt, boots, shield and weapon are separate layers, tinted by the item.

## Layout
| File | What it does |
| --- | --- |
| `scripts/act.gd` | The nine areas: names, kind, rank, size, monster types, boss, biome look |
| `scripts/area_gen.gd` | Generates the town, open areas and dungeons into the map |
| `scripts/dungeon.gd`, `floor_chunk.gd` | The current map: collision, line of sight, pathfinding, ground drawing in chunks |
| `scripts/wall_block.gd`, `prop.gd` | Walls and palisades; trees, rocks, fences, tents, graves, pillars and more |
| `scripts/main.gd` | The run: area loading and travel, spawning, loot, trading, input |
| `scripts/interactable.gd` | Waypoints, gates, cave mouths, doors, stairs, town portals and townsfolk |
| `scripts/player.gd` | Attributes, equipment, inventory grid, combat, spells |
| `scripts/monster.gd` | The 15 monster kinds, ranks, uniques, bosses and AI |
| `scripts/projectile.gd` | Fireballs, hexes, arrows, quills and bile |
| `scripts/items.gd`, `item_art.gd` | Item bases, affixes, uniques and charms; the painted inventory pictures |
| `scripts/hud.gd`, `inv_view.gd`, `automap.gd`, `orb.gd` | Bar, orbs, character, inventory, trade and waypoint panels, map |
| `scripts/game.gd` (autoload `Game`) | Isometric math, sprite sheets, rank colours, hit chance, input, sound, lights |
| `shaders/rank.gdshader` | Recolours a monster by rank |

## Art pipeline
Characters are low-poly 3D models built in code (`tools/models.gd`) and baked into 8-direction sprite
sheets (idle, walk, attack, death, plus cast for the hero) with colour, normal and glow layers. The hero
is baked as a bare body plus one sheet per gear piece, each with everything in front of it cut out, so
the game can stack them. Ground and wall textures come from `tools/gen_textures.py`.
```
godot --path . --rendering-driver opengl3 --script res://tools/bake_sprites.gd   # -- --preview, --only=a,b, --layers=x,y
python3 tools/finish_glow.py
python3 tools/gen_textures.py
```

## Smoke test and web build
- `tools/setup_godot.sh` installs Godot 4.3 on Linux and imports the project.
- `tools/smoke_test.sh` runs `godot --path . -- --autotest --shots=DIR` (under `xvfb-run` when there is
  no display). It visits the town, the inventory and trader, fights on the moor, then visits every area,
  kills the act boss, dies and wakes in town, printing a summary and saving screenshots.
- `tools/export_web.sh` exports the browser version to `build/web/` (`--threads`: the faster multi-threaded one to `build/web-mt/`, which needs the cross-origin isolation headers in `tools/web/.htaccess`); upload that folder to any HTTPS site
  (see `tools/web/HOW-TO-UPLOAD.txt`).

Developer notes for Claude Code sessions are in `CLAUDE.md`; the request-by-request history is in
`docs/HISTORY.md`. `prototype/index.html` is the original single-file browser prototype.

Fonts: Grenze Gotisch and Alegreya Sans, both under the SIL Open Font License.
