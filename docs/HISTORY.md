# Development history

What Petr asked for in each round, what was built, and what was left open. Newest last. Petr's
words are quoted as he wrote them.

## 1. Browser prototype (2026-10-11)
> I want to create Diablo 2 game

Built a single-file HTML5 canvas game (now `prototype/index.html`) with original names and art:
isometric view, click to walk/attack, Fireball (right-click/F), Frost Nova (Space, level 3+), life and
mana orbs, potions on 1/2, random dungeon depths with four monster types and champion packs, a guardian
boss per depth that opens the stairs, loot in four rarities with affixes, a pack (I), an automap (Tab)
and sound.

## 2. Port to Godot (2026-10-11)
> lets switch this into godot engine

Ported everything to a Godot 4.3 project (GL Compatibility so it also runs on the web): separate
player, monster and projectile scenes, `AStarGrid2D` pathfinding, real 2D lights instead of the
canvas darkness effect. Verified with a scripted playtest (the start of `scripts/autotest.gd`).

## 3. Visual upgrade (2026-10-11)
> now that we have it in engine, can we upgrade the visuals?

Generated stone and brick textures with normal maps (`tools/gen_textures.py`), shadow-casting walls,
flickering braziers, a post-processing pass (bloom, vignette, colour grade, grain, red edge pulse when
hurt), particles (fire trails, explosions, embers, dust) and hit feedback (screen shake, crits with
gold numbers, hit-stop on champion and boss kills, death falls).

## 4. 3D models baked to sprites (2026-10-11)
> lets improve visuals of character and monsters, can you improve their models?

Built low-poly 3D models in code (`tools/models.gd`) and baked them, Diablo II style, into
8-direction sprite sheets with idle, walk, attack, death and cast animations, plus normal maps (so
lights shade the figures) and glow layers (eyes, orbs). Open points at the time: models still fairly
blocky, and equipped armour no longer changed the hero's look (fixed in round 5).

## 5. Town and Act I (2026-10-12)
Petr's full spec:

> Lets add starting town. After which I want to create "Act 1" similar to diablo game.
>
> * The map will have
>    * "dungeon" type narrow places such the one we now have - typical are caves, building insides, dungeon etc as visual types
>    *  "open" place - a places which are much wider areas to explore (place with much wider map) -typical example are plains, fields,  wood - those are typical open areas from diablo
> * Even open places will have certain area characteristics in it  such as rocks, buildings etc which gives the area certain profile and possible kitting possibilities
> * Both dungeon and open places will have particular shape randomly generated for a given run
> * Act 1 - will have same sequence of areas following each other
>    * open
>    * open
>    * dungeon
>    * dungeon
>    * open
>    * open
>    * dungeon
>    * dungeon
>
> * This predefined areas in sequence will always have same predefined name (create one)
> * each area will have "way point" - a portal between the place and any other place that had way point portal dicovered, will include even home town - much like in original diablo 2
> * creatures will get progresively toughher trhoughout the Act
>    * make scale - rank- of monster difficulty
>    * as game and areas progresses rank of creatures will increase - giving them more hp, defense and dmg
> * increase the number of basic monster types to 15 and then increase the variability by changing colour of each monster type.
>    * Different colours will belong to different ranks
> * end of each area will have its own boss
>    * boss is several ranks harder to beat then surrounding creatures - much like we have now
>    * It will also be in some larger group - also like we have now
> * Each area will have several sub- bosses as part of spawning. Idea is that even spawned common creatures will have sometimes amoung them harder(higher ranked) creature
> * Add stats to hero (Strength, dexterity, vitality and Energy) -same as in original diablo. Look up what each stat was doing in original game and implement it same way (e.g. strength - increasing weapon damage, dexterity chance to hit and block etc...)
> * increase variability of items in terms of their abilities, their requirements (level, strenght, dexterity)
> * improve visual model of items in inventory. Also each item class should have certain visual variablity in its look (for example 2 weapons will each look slightly differently in inventory ). Also keep the adjustment, that different items will slighly adjust how hero will look with it when equiped.
> * Increase items portolio - e.g. belt, boots, mainhand, offhand weapon, amulet,
> * introduce charms - much like in original diablo

Built (details in `README.md`):
- Town **Vell's Hollow** with Elder Maelis (hints), Sister Wren (free heal; sells draughts, rings,
  amulets, charms) and Garrick the Smith (weapons, armour); stock rerolls each visit.
- Eight named areas in the required order (`scripts/act.gd`), generated per run by `scripts/area_gen.gd`:
  The Ashen Moor, Gallows Fields, Hollowroot Cave, The Sunken Ossuary, Witherwood, Ruins of Calder,
  The Abbey of Vell, The Lampless Deep. Open areas about 100-110 tiles across with biome landmarks;
  dungeons grown by cellular automaton, rooms and corridors, or halls.
- Waypoints in every area plus the town; town portal on T.
- 15 monster types, ranks 1-12 with a colour per rank and a new name every three ranks; veterans in
  ordinary packs; 2-4 unique sub-bosses per area with D2-style modifiers; area bosses at rank +4 with
  5-7 minions that seal the exit. Bosses and uniques stay dead for the run.
- Diablo II attributes and formulas (hit chance, block, resist caps), 5 points per level.
- Items: 17 weapon bases, shields, armours, helms, gloves, belts, boots, amulets, rings, small/large/grand
  charms; requirements; about 30 affix families with item-level tiers; 16 uniques; 10x4 grid inventory;
  seeded inventory pictures; worn gear drawn as layers on the hero.
- Dying returns you to town and costs a tenth of your gold.

Not done: hand-tuned difficulty (only the automated test has played it), real-mouse playtesting.

## 6. Web build (2026-10-12)
> can this be played from web browser?
> I have my own website, can this run in there?

Exported with Godot's no-threads web template (no cross-origin isolation headers needed), about
65 MB. Added `.htaccess` (wasm MIME type) and upload notes, now in `tools/web/`. Fixed two web-only
bugs: the bloom pass raised WebGL errors (the web build now uses `shaders/post_web.gdshader`) and the
panel close button glyph was missing from the font. Tested in headless Chromium. Petr uploads the
build to his own site; rebuild with `tools/export_web.sh`.

## 7. Moved to GitHub (2026-10-12)
The project moved from a Claude project's shared folder into this repository so any Claude Code
session can continue it. Added `CLAUDE.md`, this file, the `tools/*.sh` helpers and the cloud
SessionStart hook. Built zips are not kept in git; regenerate them with the scripts.

## 8. On the Tomano shop, and a faster web build (2026-10-12)
> I want to add that game to my eshop, under section games
> is there a way how to improve performance? all the movement seems very "laggy"

The web build now runs on www.tomano.cz under "Hry" (the shop repo copies `build/web` with its
`tools/game_import.py`). Movement felt laggy because the browser frame rate was low. Added
`scripts/bench.gd` (`-- --bench [--web] [--area=N] [--off=...]`) to measure what costs what: the
web bloom (16 screen samples per pixel) took about 40% of the frame, and drawing at the screen's
full resolution (high-DPI and full screen multiply the pixels) most of the rest. The web build
(`Main.web`, or `-- --web` on desktop) now draws at the base 1280x800 size and scales up, and
`post_web.gdshader` brightens highlights in place instead of blurring. About 3x the frame rate in
the benchmark at 1920x1080 (moor 3.2 -> 10.1 fps in software rendering); the desktop build is unchanged.
