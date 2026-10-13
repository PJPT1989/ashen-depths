# Innistrad Horrors: Act I (Godot 4)

A Diablo-style isometric action RPG set in the world of Magic: The Gathering. Three planeswalkers fight
through the black act, a swamp ruled by Sheoldred: a starting town and eight areas. Unofficial fan work;
Magic: The Gathering and its characters belong to Wizards of the Coast.

## Run it
1. Install Godot 4.3 or newer (standard build, no .NET needed).
2. In the Project Manager choose **Import**, pick this folder's `project.godot`, then press **F5**.
3. Pick a planeswalker on the title screen.

| Key | Action |
| --- | --- |
| Left click | Walk, talk, use waypoints and doorways, pick up (hold to keep walking). On a monster: your left-click skill |
| Right click | Your right-click skill, at the cursor |
| 1 · 2 · 3 · 4 | Put the skill on that key on the right mouse button. Over a skill in the tree or picker: put it on that key |
| Q · W | Drink a healing or mana draught from the belt |
| S | Skill tree: spend skill points (click the left or right skill button to choose what it uses) |
| C · I · Tab | Character panel, inventory, automap |
| T | Open a town portal |
| M · Esc | Sound, close panels |
| L | Graphics quality: Low, Medium or High (remembered). The browser starts at Medium |

## Act I: the Black Mire
| # | Area | Kind | Monster rank | Boss |
| --- | --- | --- | --- | --- |
| 0 | Mirewatch | town | none | none |
| 1 | The Blackwater Fen | open | 1 | Ayara, First of Locthwain |
| 2 | Gallows Bog | open | 2 | Kalitas, Traitor of Ghet |
| 3 | Leechroot Hollow | dungeon | 3 | Sidisi, Brood Tyrant |
| 4 | The Drowned Ossuary | dungeon | 4 | Lord of Tresserhorn |
| 5 | Rotwillow Swamp | open | 5 | Grimgrin, Corpse-Born |
| 6 | Ruins of Graymire | open | 6 | Drana, Liberator of Malakir |
| 7 | Cathedral of Whispers | dungeon | 7 | Ob Nixilis, the Fallen |
| 8 | The Phyrexian Sanctum | dungeon | 8 | Sheoldred, the Apocalypse |

- The game is planned as five acts, one per Magic colour; Act I is black: bog ground, mud roads, black
  water, willows and reeds.
- Names and order never change; the shape of every area is generated from its own seed once per run.
- **Open areas** are wide (about 100 x 110 tiles), with a road from the entrance to the exit and their
  own dressing: pools, reeds and rock fields in the fen; farmhouses, gallows and bog pools in the bog;
  dense willows in Rotwillow; ruined houses, cobbles, pillars and a graveyard in Graymire.
- **Dungeons** are narrow: a cave grown by cellular automaton, crypts of rooms and corridors, the
  cathedral split into halls and chambers with doorways, and the cavernous sanctum.
- **Waypoints**: one per area. Walking onto one activates it; clicking one opens the list of every
  waypoint found so far, the town's included.
- **Town**: Elder Maelis (advice for the next area), Sister Wren (heals for free, sells draughts, rings,
  amulets and charms), Garrick the Smith (weapons and armour). Stock is rerolled each visit.
- **Bosses** are legendary creatures. They wait near the way on with a large escort and seal it until
  they die. Bosses and unique sub-bosses (also legends) stay dead for the rest of the run; ordinary
  monsters return when you re-enter an area.
- Dying sends you back to town with a tenth of your gold lost.

## Monsters and ranks
- 15 kinds, each named after black Magic creatures, with a new name every three ranks: rats (Typhoid
  Rats ... Rat Colony), skeletons, vampire hexmages, Phyrexians, demons (Abyssal Gatekeeper ... Grave
  Titan), zombies, hounds and bats, carrion beetles and imps, skeleton archers and assassins, shades,
  black knights, vampire warriors, specters, plague spitters and swamp horrors (Gurmag Angler ...
  Archfiend of Despair). Some throw hexes, arrows, quills or bile (poison); shades chill.
- **Rank** 1 to 12 sets monster level (1, 3, 5 ... 23), life (x1.3 per rank), damage (x1.17 per rank),
  defense, attack rating and experience. Every rank has its own colour.
- Ordinary packs use the area's rank; about one monster in eight is a veteran one or two ranks higher.
- 2 to 4 **unique sub-bosses** per area: rank +2, gold name, one or two modifiers (Extra Strong, Extra Fast,
  Stone Skin, Fire Enchanted, Cold Enchanted, Mana Burn), with minions at rank +1.
- The **area boss** is rank +4, larger, with one modifier and five to seven minions.
- Slain monsters lie as corpses for 45 seconds (Liliana uses them).

## The planeswalkers
| Hero | Plays like | Str / Dex / Vit / Ene | Life per Vitality | Resource |
| --- | --- | --- | --- | --- |
| Ajani Goldmane | Barbarian: melee, tough | 30 / 20 / 25 / 10 | 4 | Mana (little of it) |
| Chandra Nalaar | Sorceress: fragile, big spells | 10 / 25 / 10 / 35 | 2 | Mana (most of it) |
| Liliana Vess | Necromancer: minions, curses, corpses | 15 / 25 / 15 / 25 | 2 | Mana |

Attributes, life and mana follow the Diablo II class each hero stands in for. 5 stat points and 1 skill
point per level. Every hero uses mana, which fills completely in 30 seconds (faster with Inner Fire).
Strength adds 1% weapon damage per point; Dexterity adds 5 attack rating per point, 1 defense per 4
points, and block chance. Chance to hit is Diablo II's: 2 x AR / (AR + defense) x your level / (your
level + monster level), held between 5% and 95%. Block chance = shield block x (Dexterity - 15) /
(level x 2), at most 75%. Resistances cap at 75%. Damage Reduced subtracts from physical hits.

## Skills (like Diablo II)
Each hero has three skill trees of ten skills. A tree has six rows that open at levels 1, 6, 12, 18, 24
and 30, and lines show which skills need a point in another first. One skill point per level; a skill
takes up to 20 points, but no more than your level minus its row's level plus one. Every point makes
it stronger, and many skills also get more damage per point in related skills (synergies, shown in the
skill's text). Passive skills work all the time. "+N to All Skills" on gear and Ajani's Crusade raise
every skill that has a point. Each hero starts with one point in a first skill.

The left and right mouse buttons each hold one skill (or the plain attack): click the button on the bar
to choose. Keys 1-4 switch the right-click skill, like the F keys in Diablo II; a newly learned skill
goes on the right button and the first free key. Weapon skills deal a share of weapon damage and can
miss; spells deal their own damage, raised by +% spell damage on gear.

| Hero | Trees (row by row) |
| --- | --- |
| Ajani | **Combat**: Savage Swipe · Twin Claws, Bound · Thundering Blow, Hurled Blades · Steady Claws, Pounce · Flurry of Claws · Whirling Mane, Berserk Rage. **Pride** (passive): Blade, Axe and Hammer Mastery · Pridewarden's Guard, Leonin Vigor · Thick Hide · Pride's Hunger, Fleet Paws · Relentless · Unbowed. **Roars**: Fearsome Roar, Scavenge · Provoke, Ajani's Presence · Battle Cry, Hunter's Eye · Pride's Strength · Thunderous Roar, Grim Totem · Crusade |
| Chandra | **Fire**: Shock, Inner Fire · Flame Slash · Flamewake, Fireball · Wall of Fire, Fervor · Fireblast · Pyromancer's Gauntlet, Fire Elemental. **Lightning**: Fling, Spark Volley · Static Discharge · Lightning, Storm Nova · Firewalk, Chain Lightning · Mana Barrier, Living Storm · Storm Mastery. **Pyromancy**: Lava Spike, Flame Ward · Pyroclasm · Magma Blast, Searing Aegis · Volcanic Eruption, Rain of Embers · Fiery Mantle · Firebrand, Flame Wave |
| Liliana | **Reanimation**: Death Mastery, Raise Dead · Grave Golem · Bone Archers, Golem Mastery · Blood Golem · Deathless Host, Bone Golem · Unearth, Flesh Golem. **Bone and Rot**: Drain Life, Bone Splinters, Bone Shroud · Grasp of Darkness, Grisly Spectacle · Death Cloud, Bone Spear · Bone Cage · Pestilence · Soul Reap. **Curses**: Agony Warp · Darkness, Weakness · Torment · Terror, Delirium · Dread, Vampiric Embrace, Lure of the Grave · Death's Hold |

They follow the Diablo II Barbarian, Sorceress and Necromancer trees (Chandra's third tree is fire
where the Sorceress has cold). Skeletons and archers rise from corpses; one golem at a time; Unearth
brings back a slain monster. Minions follow you between areas, attack the nearest foe, and monsters
next to them strike back. Curses weaken foes, blind them, turn their blows back on them, set them on
each other, or heal you as you hit them; burns and rot deal damage over time.

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
  reduction, thorns, regeneration, magic and gold find, +% spell damage and +1 or +2 to all skills.
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
| `scripts/player.gd` | The three heroes: attributes, equipment, inventory grid, combat, running skills |
| `scripts/skills.gd` | Every skill of the three skill trees as data, with how it grows per point |
| `scripts/minion.gd`, `skill_fx.gd` | Creatures that fight for the hero; lightning, beams, meteors and clouds |
| `scripts/monster.gd` | The 15 monster kinds, ranks, uniques, bosses and AI |
| `scripts/projectile.gd` | Hero and minion missiles; monster hexes, arrows, quills and bile |
| `scripts/items.gd`, `item_art.gd` | Item bases, affixes, uniques and charms; the painted inventory pictures |
| `scripts/hud.gd`, `inv_view.gd`, `automap.gd`, `orb.gd` | Title and hero choice, bar, orbs, character, skills, inventory, trade and waypoint panels, map |
| `scripts/game.gd` (autoload `Game`) | Isometric math, sprite sheets, rank colours, hit chance, input, sound, lights |
| `shaders/rank.gdshader` | Recolours a monster by rank |

## Art pipeline
Characters are low-poly 3D models built in code (`tools/models.gd`) and baked into 8-direction sprite
sheets (idle, walk, attack, death, plus cast for the hero) with colour, normal and glow layers. Each hero
is baked as its own body (Ajani, Chandra, Liliana, built on one shared skeleton) plus one sheet per gear
piece, each with everything in front of it cut out, so the game can stack them on any of the three.
Minions reuse the monster sheets, tinted. Ground and wall textures come from `tools/gen_textures.py`.
```
godot --path . --rendering-driver opengl3 --script res://tools/bake_sprites.gd   # -- --preview, --only=a,b, --layers=x,y
python3 tools/finish_glow.py
python3 tools/gen_textures.py
```

## Smoke test and web build
- `tools/setup_godot.sh` installs Godot 4.3 on Linux and imports the project.
- `tools/smoke_test.sh` runs `godot --path . -- --autotest --shots=DIR` (under `xvfb-run` when there is
  no display). It shows the hero choice and all three heroes, visits the town, the inventory and trader,
fights on the moor, casts every skill of every hero, checks the skill point rules, shows each skill
  tree, then visits every area,
  kills the act boss, dies and wakes in town, printing a summary and saving screenshots.
- `tools/export_web.sh` exports the browser version to `build/web/` (`--threads`: the faster multi-threaded one to `build/web-mt/`, which needs the cross-origin isolation headers in `tools/web/.htaccess`); upload that folder to any HTTPS site
  (see `tools/web/HOW-TO-UPLOAD.txt`).

Developer notes for Claude Code sessions are in `CLAUDE.md`; the request-by-request history is in
`docs/HISTORY.md`. `prototype/index.html` is the original single-file browser prototype.

Fonts: Grenze Gotisch and Alegreya Sans, both under the SIL Open Font License.
