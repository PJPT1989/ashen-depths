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

## 9. Low quality switch (2026-10-12)
> yes, my particular laptop is very slow... add that feature in there pls

**L** (or the "Quality" button on the title screen) switches low quality on and off; the choice is
saved in `user://settings.cfg`. Low quality turns off shadows, merges each shadowed light pair into
one light, drops monster glow lights and normal maps, swaps the finishing pass for
`post_low.gdshader` (vignette and hurt pulse only) and hides the drifting embers. In the browser,
if the first five seconds of play average under 24 fps and the player hasn't chosen, the game
switches to low quality once and says how to switch back. Benchmark (`--web --low`): about 15%
faster in open areas and 45% in dungeons on top of round 8. Also turned off SDF generation on
light occluders (unused) and drew small prop polygons with `draw_primitive`. Tried the same for
textured floor and wall tiles, but in Godot 4.3's compatibility renderer lit `draw_primitive` and
`draw_mesh` broke the normal-mapped lighting, so those stay `draw_polygon`.

## 10. Low, Medium and High quality (2026-10-12)
> I want to have viable options even for people with faster set up. Can we put there options so
> that if someone can afford better visuals they can run it like that?

The switch became three levels, cycled with L or the title screen button (Low, Medium, High) and remembered: **High**
(full resolution and the blurred bloom, the desktop default; in the browser the bloom is
`post_bloom_web.gdshader`, the round 6 web shader), **Medium** (round 8's base-size drawing and
in-place bloom, the browser's default, shader renamed `post_medium.gdshader`) and **Low** (round 9).
The browser still drops to Low by itself once if the first seconds are slow and nobody chose. The
smoke test and benchmark (`--quality=0|1|2`) never save the setting.

## 11. Multi-threaded web build (2026-10-12)
> Web version still feels way clunkier then what i see in godot desktop app, is that normal?
> [offered the multi-threaded web build] yes, try it pls

Added the export preset "Web Threads" (`tools/export_web.sh --threads`, output `build/web-mt/`).
It moves audio mixing and loading off the main thread; game logic and drawing stay on it, so the
gain is smoother frames rather than a big fps jump. It needs SharedArrayBuffer, so the page must be
cross-origin isolated (COOP `same-origin`, COEP `require-corp`): `tools/web/.htaccess` now sends
both, and the shop sets them for the game page in its `_headers`. The shop keeps the no-threads
build as a fallback for browsers that aren't isolated. The container's software-rendered Chromium
runs both builds at about 2 fps (the graphics emulation is the bottleneck), so the real difference
could only be judged on Petr's laptop.

## 12. Fewer draw calls (2026-10-12)
> what are generaly my options to make this webgame more smoother? ... do 1

Petr picked cutting draw calls. Floor tiles, wall faces and every part of every tree, rock and
fence were separate draw calls (about 3,200 a frame on the moor). Now they are triangle primitives
that Godot batches: floor tiles grouped by texture (`Game.quad`), wall faces the same, and props
drawn entirely from one small atlas (`Game.prop_atlas`: soft shadow, disc, plain white) so a prop is
one batch. Two Godot 4.3 quirks shaped it: a 4-point `draw_primitive` doesn't draw a quad (so quads
are two triangles), and a primitive batch keeps its first texture even into the next canvas item
(so `Game.begin_batch` starts a fresh batch with an invisible rect). Benchmark on the moor at
1920x1080: about 3,200 draw calls a frame down to about 700 (High and Medium alike); dungeons
600 down to 400. A screenshot on the same map layout (`--seed`) matches the old ground pixel for
pixel. Software rendering here barely notices draw calls, so the gain is for real browsers and GPUs.
Also fixed: rock highlights and other 4-point prop shapes were drawn as half a shape since round 9.

## 13. Magic: The Gathering theme (2026-10-12)
> Ok I want to do major theme change ... The theme will be Magic the gathering. Heroes will be
> individual planeswalkers ... Ajani ... melee tanky, Chandra ... squishy with strong spells, Liliana is
> counterpart to necromancer. Once you design visuals for these individual heroes, create skill tree for
> them (similiar to oriiginal diablo 3). Rename monsters ... names of creatures from MTG. Bosses and
> subbosses will have name of legendary cratures ... 5 acts, each act corresponding to MTG colour, Act
> one is going to be black ... swamp ... Adjust visual of common monsters ... Act 1 will have final boss
> called Sheoldred.

Built in four stages on a branch, never put live without Petr's word: Wizards' Fan Content Policy says
games using their IP need written permission, so whether to publish is his call.
1. **Black act.** Town Mirewatch and eight swamp areas with new names; every boss and unique is an MTG
   legend (Ayara, Kalitas, Sidisi, Lord of Tresserhorn, Grimgrin, Drana, Ob Nixilis, Sheoldred, the
   Apocalypse as act boss). Monster tiers renamed after black creatures. New bog and mud ground, black
   water, willows and reeds; elder, title and messages rewritten.
2. **Heroes.** Ajani (white leonin, gold mane, scar, harness, tail), Chandra (flame hair, goggles, red
   coat) and Liliana (violet gown, the Chain Veil) as body layers on the shared skeleton, so all gear
   still shows. Picked on the title screen; starting stats, life and mana copy the Diablo II Barbarian,
   Sorceress and Necromancer.
3. **Skills like Diablo III.** 12 skills per hero in 6 categories, unlocked by level, 3 runes each,
   6 passives with slots at levels 4, 10 and 16; six hotbar slots (left, right, 1-4) and a skills panel
   (S). Resources: Ferocity (built by hitting), Mana (fast refill), Soul (from rites). New systems:
   minions that follow between areas and draw aggro, corpses, curses (weaken, vulnerable, fear, rot),
   burns, stuns, knockback, leaps, charges, teleport, meteors, beams and clouds. Potions moved to Q/W.
   Fireball and Frost Nova as fixed spells are gone.
4. **Monsters.** Ten models remade after MTG creatures: rats, vampire hexmages, Phyrexians (porcelain
   over sinew, chrome, oil), winged demons, carrion beetles, black knights, vampire warriors, flying
   specters (now throw hexes), plague spitters and the Gurmag Angler with its lure.
The smoke test now shows the hero choice and casts every skill of every hero with every rune.

## 14. Diablo II skill system (2026-10-12)
> Adjust hero design, I want skill system to be more derived from Diablo 2 instead

Read as: keep the three planeswalkers and their looks, replace the Diablo III skill system with
Diablo II's. Each hero now has three trees of ten skills mirroring the Barbarian (Combat, masteries,
warcries), Sorceress (fire, lightning, and a fire "Pyromancy" tree where she has cold) and Necromancer
(summoning, poison and bone, curses), with MTG names. Rows open at levels 1, 6, 12, 18, 24 and 30;
prerequisite lines; one skill point per level; up to 20 points with Diablo II's level cap per point;
every point grows the skill, synergies add damage per point in related skills; passives (weapon
masteries, Inner Fire, Death Mastery...) work all the time; "+N to All Skills" affixes and Crusade
(Battle Command). Ferocity and Soul are gone: everyone uses mana, which refills in 30 seconds. Runes,
passive slots and the six-slot bar are gone: one skill per mouse button, keys 1-4 swap the right one
(Diablo II's F keys), a picker on the bar buttons. New mechanics: corpse-raised skeletons and archers,
one golem at a time (four kinds), Unearth revives a slain monster, Bone Shroud absorbs damage, Mana
Barrier, Flamewake fire trail, Living Storm, Wall of Fire, Static Discharge (a quarter of current life),
Scavenge/Hunter's Eye/Grim Totem on corpses, and curses that blind (Darkness), reflect melee (Torment),
confuse (Delirium), lure (Lure of the Grave) and heal on hit (Vampiric Embrace). Each hero starts with
one point in Savage Swipe, Shock or Drain Life. The smoke test casts all 73 active skills, checks the
point rules and a synergy, and shows each tree.


## 15. New name: Innistrad Horrors (2026-10-13)
> I want to rename the name of game, lets call it "Innistrad horrors", change the name everywhere

The game is now **Innistrad Horrors**: title screen, window and browser tab (`project.godot`), README,
notes and the web upload files. Earlier history entries and the HTML prototype keep the old name
Ashen Depths as a record. The repository itself is renamed on GitHub by Petr.


## 16. Saving progress, with a shop login in the browser (2026-10-13)
> ok, now I want to adjust the game in such a way, that If I want, the game is able to save the progress (we can condition that option by needing login)

`scripts/save.gd`: one saved hero per planeswalker, saved automatically (area change, level up, area
boss, every minute). A save is the hero (attributes, points, skills, keys, equipment, inventory, belt,
gold) and the act (area seeds, waypoints, slain uniques and bosses, explored map, items on the ground),
written with `var_to_str` so types survive; text naming objects or resources is refused. Loading wakes
the hero in Mirewatch as in Diablo II. The desktop saves to files in `user://`. In the browser the
game asks the page around it (`window.parent.tomanoGames`, shop repo `js/game-saves.js`), which stores
saves in the shop's Supabase table `game_saves` under the logged-in customer (own rows only, 20 per
customer); without a login it does not save, and the title screen and top-left corner open the
shop's login in a new tab. The title cards say "Continue · Level N · furthest area"; "Start a new ..."
(two clicks) replaces a saved hero. The smoke test saves, scrambles the hero, loads and compares.

