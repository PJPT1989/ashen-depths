class_name Skills
extends RefCounted
## Skills of the three planeswalkers, laid out like Diablo II: each hero has three skill trees of
## ten skills. A skill sits on one of six rows that open at character level 1, 6, 12, 18, 24 and 30,
## and needs a point in the skills it hangs from (req). The hero gets one skill point per level and
## can put up to 20 in a skill; a skill can't have more points than character level minus its row
## level plus one. Each point makes it stronger (per), and many skills grow stronger still from
## points in related skills (syn, % damage per point). "+N to All Skills" on items and Crusade add
## levels to every skill that has at least one point. Passive skills work all the time.
## The left and right mouse buttons each hold one skill; keys 1-4 swap the right-click skill.
## Player.use_skill() runs them.
##
## Skill fields:
##   tab, row, col  where it sits in its tree; req: skills that need a point first
##   kind   melee, cone, missile, chain, beam, nova, blast, cloud, leap, charge, teleport, buff,
##          shout, curse, summon, corpse, shield, scavenge, passive
##   dmg    [min, max] damage of a spell (grows with "per"); weapon skills instead have
##          pct (% of weapon damage dealt) and ar (% more attack rating)
##   cost   mana; cd: casting delay in seconds; elem: phys, fire, cold, lit, pois
##   on-hit slow, stun, fear (seconds), knock (tiles), burn (% dealt again over 3 s), leech (% of damage)
##   fx     buff on the hero for dur seconds, or what a passive gives (see FX_TEXT)
##   debuff on monsters for dur seconds: weak, vuln, slow, fear, stun, blind, reflect, confuse,
##          tap, bait, dot (see Monster.afflict)
##   summon minion type, count, max, dur (0 = until killed), hp and dmg multipliers
##   per    added for each skill level above 1 (numbers, [min, max] pairs and nested fx/debuff)
##   syn    {skill id: % more damage per point in that skill}

const RESOURCE := {
	"ajani": {"name": "Mana", "color": Color("4f7cff"), "regen_frac": 1.0 / 30.0},
	"chandra": {"name": "Mana", "color": Color("4f7cff"), "regen_frac": 1.0 / 30.0},
	"liliana": {"name": "Mana", "color": Color("4f7cff"), "regen_frac": 1.0 / 30.0},
}

const TABS := {
	"ajani": ["Combat", "Pride", "Roars"],
	"chandra": ["Fire", "Lightning", "Pyromancy"],
	"liliana": ["Reanimation", "Bone and Rot", "Curses"],
}
const ROW_LVL := [1, 6, 12, 18, 24, 30]
const MAX_POINTS := 20
## The one point every hero starts with, already spent.
const START := {"ajani": "savage_swipe", "chandra": "shock", "liliana": "drain_life"}
## Fields that stay whole numbers as they grow.
const INT_KEYS := ["count", "max", "jumps", "corpses", "corpse", "wall"]

## How hero effects read in the skill tree. Each takes one number.
const FX_TEXT := {
	"dmg": "+%d%% damage", "def": "+%d%% defense", "life": "+%d%% maximum life", "rmax": "+%d%% maximum mana",
	"speed": "+%d%% walk speed", "aspd": "+%d%% attack and cast speed", "leech": "%.1f%% of damage healed",
	"regen": "Heals %.1f%% of life per second", "thorns": "Attackers take %d%% of your weapon damage",
	"wdmg": "+%d%% weapon damage", "ar_pct": "+%d%% attack rating", "block": "+%d%% chance to block",
	"res": "+%d%% to all resistances", "dr_pct": "Damage taken reduced by %d%%",
	"low_dr": "Below 30%% life, damage taken reduced by %d%%", "rfast": "Mana regenerates %d%% faster",
	"fire_pct": "+%d%% fire damage", "lit_pct": "+%d%% lightning damage", "burn": "Fire hits burn for another %d%%",
	"minion": "Minions get +%d%% life and damage", "golem": "Golems get +%d%% life and damage",
	"minion_dr": "Minions take %d%% less damage", "skills": "+%d to all skills", "blaze": "Leaves fire where you walk: %d damage per burst",
	"storm": "A bolt strikes a nearby foe every 1.6 s: about %d damage", "mana_shield": "%d%% of damage taken comes off mana instead",
	"taken": "Damage taken x%.2f",
}
const DEBUFF_TEXT := {
	"weak": "Foes deal %d%% less damage", "vuln": "Foes take %d%% more damage", "fear": "Foes flee for %.1f s",
	"stun": "Foes are held for %.1f s", "slow": "Foes are slowed", "blind": "Foes can barely see",
	"reflect": "Foes take %d%% of the damage their blows deal you", "confuse": "Foes attack each other",
	"tap": "Hits on them heal you for %d%% of the damage", "bait": "Nearby foes attack the one you curse",
}

const SKILLS := {
	# ================= Ajani: Combat =================
	"savage_swipe": {"hero": "ajani", "tab": 0, "row": 0, "col": 0, "req": [], "name": "Savage Swipe", "kind": "melee", "src": "weapon",
		"pct": 145, "ar": 20, "knock": 0.6, "cost": 2, "per": {"pct": 5, "ar": 5}, "syn": {"thundering_blow": 5, "steady_claws": 5},
		"desc": "A heavy claw strike that knocks the foe back."},
	"twin_claws": {"hero": "ajani", "tab": 0, "row": 1, "col": 1, "req": ["savage_swipe"], "name": "Twin Claws", "kind": "melee", "src": "weapon",
		"hits": 2, "pct": 105, "ar": 15, "cost": 2, "per": {"pct": 5, "ar": 5}, "syn": {"flurry": 5},
		"desc": "Strike twice in quick succession."},
	"bound": {"hero": "ajani", "tab": 0, "row": 1, "col": 2, "req": [], "name": "Bound", "kind": "leap", "src": "weapon",
		"pct": 30, "dist": 5.0, "radius": 1.6, "knock": 1.5, "cost": 4, "per": {"dist": 0.4, "pct": 5},
		"desc": "Leap away, knocking back foes where you land."},
	"thundering_blow": {"hero": "ajani", "tab": 0, "row": 2, "col": 0, "req": ["savage_swipe"], "name": "Thundering Blow", "kind": "melee", "src": "weapon",
		"pct": 110, "ar": 15, "stun": 1.2, "cost": 2, "per": {"pct": 3, "ar": 5, "stun": 0.15},
		"desc": "A blow that leaves the foe stunned."},
	"hurled_blade": {"hero": "ajani", "tab": 0, "row": 2, "col": 1, "req": ["twin_claws"], "name": "Hurled Blades", "kind": "missile", "src": "weapon",
		"pct": 100, "ar": 20, "count": 2, "spread": 0.18, "speed": 12.0, "look": "arrow", "cost": 2, "per": {"pct": 6, "ar": 5},
		"desc": "Throw two blades at once."},
	"steady_claws": {"hero": "ajani", "tab": 0, "row": 3, "col": 0, "req": ["thundering_blow"], "name": "Steady Claws", "kind": "melee", "src": "weapon",
		"pct": 170, "ar": 40, "self": {"dur": 2.0, "fx": {"def": 100}}, "cost": 2, "per": {"pct": 5, "ar": 10, "self": {"fx": {"def": 5}}}, "syn": {"berserk_rage": 10},
		"desc": "A focused strike; your defense rises for 2 seconds after."},
	"pounce": {"hero": "ajani", "tab": 0, "row": 3, "col": 2, "req": ["bound"], "name": "Pounce", "kind": "leap", "src": "weapon",
		"pct": 200, "ar": 30, "dist": 7.0, "radius": 1.5, "cost": 9, "per": {"pct": 25, "ar": 10, "radius": 0.05}, "syn": {"bound": 10},
		"desc": "Leap onto your foes and strike all of them where you land."},
	"flurry": {"hero": "ajani", "tab": 0, "row": 4, "col": 1, "req": ["twin_claws"], "name": "Flurry of Claws", "kind": "melee", "src": "weapon",
		"hits": 2, "pct": 110, "ar": 20, "self": {"dur": 4.0, "fx": {"aspd": 20, "speed": 25}}, "cost": 3,
		"per": {"pct": 6, "ar": 5, "self": {"fx": {"aspd": 3, "speed": 3}}}, "syn": {"twin_claws": 5},
		"desc": "Strike twice; for 4 seconds you attack and move faster."},
	"whirling_mane": {"hero": "ajani", "tab": 0, "row": 5, "col": 0, "req": ["steady_claws", "pounce"], "name": "Whirling Mane", "kind": "charge", "src": "weapon",
		"pct": 150, "dist": 6.0, "lunge_speed": 7.0, "cost": 18, "per": {"pct": 8, "dist": 0.3, "cost": -0.5},
		"desc": "Spin through the crowd toward the cursor, striking every foe you pass."},
	"berserk_rage": {"hero": "ajani", "tab": 0, "row": 5, "col": 2, "req": ["steady_claws"], "name": "Berserk Rage", "kind": "melee", "src": "weapon",
		"pct": 250, "ar": 100, "sure": true, "self": {"dur": 2.5, "fx": {"taken": 1.3}}, "cost": 4, "per": {"pct": 15, "ar": 15},
		"desc": "A blow that never misses, but you take 30% more damage for 2.5 seconds."},

	# ================= Ajani: Pride (passives) =================
	"blade_mastery": {"hero": "ajani", "tab": 1, "row": 0, "col": 0, "req": [], "name": "Blade Mastery", "kind": "passive", "weapon": "weapon_sword",
		"fx": {"wdmg": 28, "ar_pct": 28}, "per": {"fx": {"wdmg": 6, "ar_pct": 8}}, "desc": "Better with swords."},
	"axe_mastery": {"hero": "ajani", "tab": 1, "row": 0, "col": 1, "req": [], "name": "Axe Mastery", "kind": "passive", "weapon": "weapon_axe",
		"fx": {"wdmg": 28, "ar_pct": 28}, "per": {"fx": {"wdmg": 6, "ar_pct": 8}}, "desc": "Better with axes."},
	"hammer_mastery": {"hero": "ajani", "tab": 1, "row": 0, "col": 2, "req": [], "name": "Hammer Mastery", "kind": "passive", "weapon": "weapon_mace",
		"fx": {"wdmg": 28, "ar_pct": 28}, "per": {"fx": {"wdmg": 6, "ar_pct": 8}}, "desc": "Better with clubs, maces and hammers."},
	"shield_guard": {"hero": "ajani", "tab": 1, "row": 1, "col": 0, "req": [], "name": "Pridewarden's Guard", "kind": "passive",
		"fx": {"block": 8, "def": 10}, "per": {"fx": {"block": 2, "def": 4}}, "desc": "Block more often with a shield."},
	"leonin_vigor": {"hero": "ajani", "tab": 1, "row": 1, "col": 2, "req": [], "name": "Leonin Vigor", "kind": "passive",
		"fx": {"life": 10}, "per": {"fx": {"life": 4}}, "desc": "More life."},
	"thick_hide": {"hero": "ajani", "tab": 1, "row": 2, "col": 1, "req": ["shield_guard"], "name": "Thick Hide", "kind": "passive",
		"fx": {"def": 30}, "per": {"fx": {"def": 10}}, "desc": "Your hide turns blows aside."},
	"prides_hunger": {"hero": "ajani", "tab": 1, "row": 3, "col": 0, "req": ["shield_guard"], "name": "Pride's Hunger", "kind": "passive",
		"fx": {"leech": 2}, "per": {"fx": {"leech": 0.5}}, "desc": "Your blows heal you."},
	"fleet_paws": {"hero": "ajani", "tab": 1, "row": 3, "col": 2, "req": ["leonin_vigor"], "name": "Fleet Paws", "kind": "passive",
		"fx": {"speed": 13}, "per": {"fx": {"speed": 1.5}}, "desc": "Move faster."},
	"relentless": {"hero": "ajani", "tab": 1, "row": 4, "col": 1, "req": ["thick_hide"], "name": "Relentless", "kind": "passive",
		"fx": {"low_dr": 20}, "per": {"fx": {"low_dr": 2.5}}, "desc": "Hard to finish off."},
	"unbowed": {"hero": "ajani", "tab": 1, "row": 5, "col": 1, "req": ["relentless"], "name": "Unbowed", "kind": "passive",
		"fx": {"res": 12, "dr_pct": 5}, "per": {"fx": {"res": 3, "dr_pct": 0.5}}, "desc": "Fire, frost, storm and venom wash over you."},

	# ================= Ajani: Roars =================
	"fearsome_roar": {"hero": "ajani", "tab": 2, "row": 0, "col": 0, "req": [], "name": "Fearsome Roar", "kind": "shout", "radius": 4.0, "dur": 3.0,
		"debuff": {"fear": 3.0}, "cost": 4, "per": {"radius": 0.4, "debuff": {"fear": 0.4}}, "desc": "A roar that sends nearby foes fleeing."},
	"scavenge": {"hero": "ajani", "tab": 2, "row": 0, "col": 2, "req": [], "name": "Scavenge", "kind": "scavenge", "mode": "potion", "chance": 15, "radius": 3.0,
		"cost": 0, "per": {"chance": 3}, "desc": "Search a corpse near the cursor for a draught."},
	"provoke": {"hero": "ajani", "tab": 2, "row": 1, "col": 0, "req": ["fearsome_roar"], "name": "Provoke", "kind": "curse", "radius": 2.0, "dur": 6.0,
		"debuff": {"weak": 25, "slow": 0.5}, "cost": 3, "per": {"dur": 1.0, "debuff": {"weak": 2}}, "desc": "Goad foes near the cursor: they come at you, slowed and weakened."},
	"ajanis_presence": {"hero": "ajani", "tab": 2, "row": 1, "col": 1, "req": ["fearsome_roar"], "name": "Ajani's Presence", "kind": "buff", "dur": 10.0,
		"fx": {"def": 100}, "cost": 6, "per": {"dur": 2.0, "fx": {"def": 10}}, "desc": "Your defense rises."},
	"battle_cry": {"hero": "ajani", "tab": 2, "row": 2, "col": 0, "req": ["provoke"], "name": "Battle Cry", "kind": "shout", "radius": 4.0, "dur": 12.0,
		"debuff": {"weak": 25, "vuln": 25}, "cost": 5, "per": {"radius": 0.3, "dur": 1.2, "debuff": {"weak": 1, "vuln": 2}},
		"desc": "Nearby foes deal less damage and take more."},
	"hunters_eye": {"hero": "ajani", "tab": 2, "row": 2, "col": 2, "req": ["scavenge"], "name": "Hunter's Eye", "kind": "scavenge", "mode": "item", "chance": 13, "radius": 3.0,
		"cost": 7, "per": {"chance": 2.5}, "desc": "Search a corpse near the cursor for an item."},
	"prides_strength": {"hero": "ajani", "tab": 2, "row": 3, "col": 1, "req": ["ajanis_presence"], "name": "Pride's Strength", "kind": "buff", "dur": 30.0,
		"fx": {"life": 35, "rmax": 35}, "cost": 7, "per": {"dur": 6.0, "fx": {"life": 3, "rmax": 3}}, "desc": "More life and mana for a while."},
	"thunderous_roar": {"hero": "ajani", "tab": 2, "row": 4, "col": 0, "req": ["battle_cry"], "name": "Thunderous Roar", "kind": "nova", "src": "spell",
		"dmg": [10, 12], "radius": 3.3, "stun": 1.0, "cost": 10, "per": {"dmg": [4, 5], "stun": 0.1, "cost": 1},
		"syn": {"fearsome_roar": 6, "provoke": 6, "battle_cry": 6}, "desc": "A roar that hurts and stuns every foe around you."},
	"grim_totem": {"hero": "ajani", "tab": 2, "row": 4, "col": 2, "req": ["hunters_eye"], "name": "Grim Totem", "kind": "scavenge", "mode": "ward", "radius": 2.5, "dur": 8.0,
		"cost": 4, "per": {"radius": 0.2, "dur": 1.0}, "desc": "Raise a corpse into a totem that keeps foes away."},
	"crusade": {"hero": "ajani", "tab": 2, "row": 5, "col": 1, "req": ["prides_strength"], "name": "Crusade", "kind": "buff", "dur": 10.0,
		"fx": {"skills": 1}, "cost": 11, "per": {"dur": 4.0}, "desc": "Every skill you know works one level higher."},

	# ================= Chandra: Fire =================
	"shock": {"hero": "chandra", "tab": 0, "row": 0, "col": 1, "req": [], "name": "Shock", "kind": "missile", "src": "spell",
		"dmg": [4, 7], "speed": 13.0, "look": "spark", "elem": "fire", "cost": 2.5, "per": {"dmg": [3, 4]}, "syn": {"fireball": 10, "fireblast": 10},
		"desc": "A quick bolt of fire."},
	"inner_fire": {"hero": "chandra", "tab": 0, "row": 0, "col": 2, "req": [], "name": "Inner Fire", "kind": "passive",
		"fx": {"rfast": 30}, "per": {"fx": {"rfast": 12}}, "desc": "Mana comes back faster."},
	"flame_slash": {"hero": "chandra", "tab": 0, "row": 1, "col": 0, "req": [], "name": "Flame Slash", "kind": "cone", "src": "spell",
		"dmg": [6, 12], "range": 3.0, "angle": 1.2, "elem": "fire", "cost": 6, "per": {"dmg": [4, 6], "range": 0.1, "cost": 0.5},
		"syn": {"flamewake": 8, "wall_of_fire": 8}, "desc": "A sweep of flame in front of you."},
	"flamewake": {"hero": "chandra", "tab": 0, "row": 2, "col": 0, "req": ["flame_slash"], "name": "Flamewake", "kind": "buff", "dur": 5.0,
		"fx": {"blaze": 8}, "cost": 11, "per": {"dur": 1.0, "fx": {"blaze": 4}, "cost": 0.5}, "desc": "Fire springs up wherever you walk."},
	"fireball": {"hero": "chandra", "tab": 0, "row": 2, "col": 1, "req": ["shock"], "name": "Fireball", "kind": "missile", "src": "spell",
		"dmg": [8, 14], "speed": 9.0, "boom": 1.6, "look": "fire", "elem": "fire", "cost": 5, "per": {"dmg": [5, 7], "cost": 0.5},
		"syn": {"shock": 10, "fireblast": 10}, "desc": "A ball of fire that explodes on impact."},
	"wall_of_fire": {"hero": "chandra", "tab": 0, "row": 3, "col": 0, "req": ["flamewake"], "name": "Wall of Fire", "kind": "cloud", "src": "spell",
		"dmg": [30, 40], "wall": 5, "radius": 0.8, "dur": 4.0, "cd": 1.4, "elem": "fire", "cost": 18, "per": {"dmg": [14, 18], "dur": 0.2, "cost": 1},
		"syn": {"flamewake": 4}, "desc": "A line of fire across your path. Damage is per section, over its duration."},
	"fervor": {"hero": "chandra", "tab": 0, "row": 3, "col": 2, "req": ["inner_fire", "fireball"], "name": "Fervor", "kind": "buff", "dur": 30.0,
		"fx": {"dmg": 15}, "cost": 15, "per": {"dur": 6.0, "fx": {"dmg": 5}, "cost": 1}, "desc": "Everything you do burns hotter."},
	"fireblast": {"hero": "chandra", "tab": 0, "row": 4, "col": 1, "req": ["wall_of_fire", "fireball"], "name": "Fireblast", "kind": "blast", "src": "spell",
		"dmg": [40, 52], "radius": 2.0, "delay": 0.8, "burn": 40, "cd": 1.2, "elem": "fire", "cost": 17, "per": {"dmg": [14, 18], "cost": 1},
		"syn": {"wall_of_fire": 5, "fireball": 5}, "desc": "A meteor of fire crashes down at the cursor and leaves the ground burning."},
	"gauntlet": {"hero": "chandra", "tab": 0, "row": 5, "col": 1, "req": [], "name": "Pyromancer's Gauntlet", "kind": "passive",
		"fx": {"fire_pct": 30}, "per": {"fx": {"fire_pct": 7}}, "desc": "All your fire burns hotter."},
	"fire_elemental": {"hero": "chandra", "tab": 0, "row": 5, "col": 2, "req": ["fervor"], "name": "Fire Elemental", "kind": "summon", "minion": "wraith",
		"tint": Color(2.2, 0.9, 0.3), "shot": "fire", "count": 1, "max": 3, "dur": 10.0, "hp": 2.0, "dmg": 1.5, "cost": 20,
		"per": {"dur": 1.0, "hp": 0.2, "dmg": 0.25, "cost": 1}, "desc": "Conjure an elemental that hurls fire at your foes. Up to three at once."},

	# ================= Chandra: Lightning =================
	"fling": {"hero": "chandra", "tab": 1, "row": 0, "col": 0, "req": [], "name": "Fling", "kind": "missile", "src": "spell",
		"dmg": [1, 4], "knock": 1.5, "stun": 0.4, "speed": 14.0, "look": "spark", "elem": "lit", "cost": 4, "per": {"dmg": [1, 2], "stun": 0.05},
		"desc": "A jolt of force that throws a foe back."},
	"spark_volley": {"hero": "chandra", "tab": 1, "row": 0, "col": 1, "req": [], "name": "Spark Volley", "kind": "missile", "src": "spell",
		"dmg": [2, 4], "count": 3, "spread": 0.9, "speed": 10.0, "look": "spark", "elem": "lit", "cost": 3, "per": {"dmg": [1, 1.5], "count": 0.5, "cost": 0.25},
		"syn": {"static_discharge": 6, "chain_lightning": 6}, "desc": "A fan of crackling sparks; more of them as it grows."},
	"static_discharge": {"hero": "chandra", "tab": 1, "row": 1, "col": 2, "req": [], "name": "Static Discharge", "kind": "nova", "src": "spell",
		"hp_pct": 25, "dmg": [1, 1], "radius": 2.5, "elem": "lit", "cost": 9, "per": {"radius": 0.35},
		"desc": "Takes a quarter of the life of every foe around you (half that on bosses)."},
	"lightning_bolt": {"hero": "chandra", "tab": 1, "row": 2, "col": 1, "req": ["spark_volley"], "name": "Lightning", "kind": "beam", "src": "spell",
		"dmg": [1, 40], "length": 8.0, "elem": "lit", "cost": 8, "per": {"dmg": [0, 8], "length": 0.2, "cost": 0.5},
		"syn": {"electro_nova": 8, "chain_lightning": 8}, "desc": "A bolt that tears through every foe in a line. Wild damage."},
	"electro_nova": {"hero": "chandra", "tab": 1, "row": 2, "col": 2, "req": ["static_discharge"], "name": "Storm Nova", "kind": "nova", "src": "spell",
		"dmg": [2, 20], "radius": 3.5, "elem": "lit", "cost": 15, "per": {"dmg": [3, 4], "cost": 1}, "desc": "A ring of lightning bursts out around you."},
	"chain_lightning": {"hero": "chandra", "tab": 1, "row": 3, "col": 1, "req": ["lightning_bolt"], "name": "Chain Lightning", "kind": "chain", "src": "spell",
		"dmg": [1, 40], "jumps": 3, "range": 8.0, "elem": "lit", "cost": 9, "per": {"dmg": [0, 7], "jumps": 0.25, "cost": 0.5},
		"syn": {"lightning_bolt": 4, "electro_nova": 4}, "desc": "Lightning leaps from foe to foe."},
	"firewalk": {"hero": "chandra", "tab": 1, "row": 3, "col": 0, "req": ["fling"], "name": "Firewalk", "kind": "teleport", "dist": 9.0,
		"cost": 24, "cost_min": 9, "per": {"cost": -1}, "desc": "Vanish in flame and reappear at the cursor."},
	"living_storm": {"hero": "chandra", "tab": 1, "row": 4, "col": 2, "req": ["electro_nova", "chain_lightning"], "name": "Living Storm", "kind": "buff", "dur": 32.0,
		"fx": {"storm": 25}, "elem": "lit", "cost": 19, "per": {"dur": 8.0, "fx": {"storm": 9}}, "desc": "A storm follows you and strikes foes nearby."},
	"mana_barrier": {"hero": "chandra", "tab": 1, "row": 4, "col": 0, "req": ["firewalk", "chain_lightning"], "name": "Mana Barrier", "kind": "buff", "dur": 144.0,
		"fx": {"mana_shield": 20}, "cost": 5, "per": {"dur": 30.0, "fx": {"mana_shield": 4}}, "desc": "Part of the damage you take comes off your mana (1.5 mana per point)."},
	"storm_mastery": {"hero": "chandra", "tab": 1, "row": 5, "col": 1, "req": [], "name": "Storm Mastery", "kind": "passive",
		"fx": {"lit_pct": 50}, "per": {"fx": {"lit_pct": 12}}, "desc": "All your lightning strikes harder."},

	# ================= Chandra: Pyromancy =================
	"lava_spike": {"hero": "chandra", "tab": 2, "row": 0, "col": 1, "req": [], "name": "Lava Spike", "kind": "missile", "src": "spell",
		"dmg": [4, 7], "slow": 1.5, "speed": 11.0, "look": "spark", "elem": "fire", "cost": 3, "per": {"dmg": [3, 3], "slow": 0.15, "cost": 0.25},
		"syn": {"magma_blast": 15, "volcanic_eruption": 15}, "desc": "A spike of molten rock that slows the foe it hits."},
	"flame_ward": {"hero": "chandra", "tab": 2, "row": 0, "col": 2, "req": [], "name": "Flame Ward", "kind": "buff", "buff_id": "armor", "dur": 120.0,
		"fx": {"def": 30}, "cost": 7, "per": {"dur": 12.0, "fx": {"def": 5}}, "desc": "A shell of heat that turns blows. Only one ward at a time."},
	"pyroclasm": {"hero": "chandra", "tab": 2, "row": 1, "col": 0, "req": [], "name": "Pyroclasm", "kind": "nova", "src": "spell",
		"dmg": [4, 8], "radius": 3.5, "slow": 2.0, "knock": 0.8, "elem": "fire", "cost": 9, "per": {"dmg": [3, 4], "cost": 1},
		"desc": "A ring of fire throws back and slows every foe around you."},
	"magma_blast": {"hero": "chandra", "tab": 2, "row": 2, "col": 1, "req": ["lava_spike"], "name": "Magma Blast", "kind": "missile", "src": "spell",
		"dmg": [12, 18], "stun": 1.0, "speed": 9.0, "look": "fire", "elem": "fire", "cost": 6, "per": {"dmg": [6, 8], "stun": 0.1, "cost": 0.5},
		"syn": {"lava_spike": 8, "volcanic_eruption": 8}, "desc": "A heavy glob of magma that stuns its target."},
	"searing_aegis": {"hero": "chandra", "tab": 2, "row": 2, "col": 2, "req": ["flame_ward"], "name": "Searing Aegis", "kind": "buff", "buff_id": "armor", "dur": 120.0,
		"fx": {"def": 45, "thorns": 60}, "cost": 11, "per": {"dur": 12.0, "fx": {"def": 6, "thorns": 15}}, "desc": "A ward that burns whoever strikes you."},
	"volcanic_eruption": {"hero": "chandra", "tab": 2, "row": 3, "col": 0, "req": ["magma_blast"], "name": "Volcanic Eruption", "kind": "missile", "src": "spell",
		"dmg": [18, 26], "boom": 1.8, "stun": 1.5, "speed": 8.0, "look": "fire", "elem": "fire", "cost": 10, "per": {"dmg": [8, 10], "stun": 0.1, "cost": 0.5},
		"syn": {"lava_spike": 5, "magma_blast": 5}, "desc": "A bolt of lava that bursts and stuns everything near it."},
	"rain_of_embers": {"hero": "chandra", "tab": 2, "row": 3, "col": 1, "req": ["magma_blast", "pyroclasm"], "name": "Rain of Embers", "kind": "blast", "src": "spell",
		"dmg": [20, 30], "count": 5, "radius": 1.6, "delay": 0.6, "cd": 1.8, "elem": "fire", "cost": 23, "per": {"dmg": [9, 12], "count": 0.25, "cost": 1},
		"syn": {"lava_spike": 5, "magma_blast": 5}, "desc": "Burning stones rain down around the cursor."},
	"fiery_mantle": {"hero": "chandra", "tab": 2, "row": 4, "col": 2, "req": ["searing_aegis"], "name": "Fiery Mantle", "kind": "buff", "buff_id": "armor", "dur": 144.0,
		"fx": {"def": 45, "thorns": 120}, "cost": 17, "per": {"dur": 6.0, "fx": {"def": 5, "thorns": 25}}, "desc": "The strongest ward: attackers are badly burned."},
	"flame_wave": {"hero": "chandra", "tab": 2, "row": 5, "col": 1, "req": ["rain_of_embers"], "name": "Flame Wave", "kind": "nova", "src": "spell",
		"dmg": [40, 50], "radius": 6.0, "burn": 40, "cd": 1.0, "elem": "fire", "cost": 25, "per": {"dmg": [14, 18], "cost": 1.5},
		"syn": {"lava_spike": 2}, "desc": "A wall of fire rolls out in every direction."},
	"firebrand": {"hero": "chandra", "tab": 2, "row": 5, "col": 0, "req": [], "name": "Firebrand", "kind": "passive",
		"fx": {"burn": 20}, "per": {"fx": {"burn": 6}}, "desc": "Your fire leaves foes burning."},

	# ================= Liliana: Reanimation =================
	"death_mastery": {"hero": "liliana", "tab": 0, "row": 0, "col": 0, "req": [], "name": "Death Mastery", "kind": "passive",
		"fx": {"minion": 15}, "per": {"fx": {"minion": 7}}, "desc": "Your dead fight harder and last longer."},
	"raise_dead": {"hero": "liliana", "tab": 0, "row": 0, "col": 1, "req": [], "name": "Raise Dead", "kind": "summon", "minion": "bonewalker", "corpse": 1,
		"count": 1, "max": 2, "dur": 0, "hp": 1.5, "dmg": 0.8, "cost": 6, "per": {"max": 0.5, "hp": 0.15, "dmg": 0.12, "cost": 1},
		"desc": "Raise a corpse near the cursor as a skeleton warrior."},
	"grave_golem": {"hero": "liliana", "tab": 0, "row": 1, "col": 2, "req": [], "name": "Grave Golem", "kind": "summon", "minion": "brute", "group": "golem", "golem": true,
		"tint": Color(0.7, 0.55, 1.0), "count": 1, "max": 1, "dur": 0, "hp": 4.0, "dmg": 1.2, "cost": 15, "per": {"hp": 0.6, "dmg": 0.15, "cost": 3},
		"desc": "Stitch together a golem of grave earth. One golem at a time."},
	"bone_archers": {"hero": "liliana", "tab": 0, "row": 2, "col": 1, "req": ["raise_dead"], "name": "Bone Archers", "kind": "summon", "minion": "bone_archer",
		"shot": "arrow", "corpse": 1, "count": 1, "max": 2, "dur": 0, "hp": 1.0, "dmg": 0.8, "cost": 8, "per": {"max": 0.5, "hp": 0.1, "dmg": 0.1, "cost": 1},
		"desc": "Raise a corpse near the cursor as a skeleton archer."},
	"golem_mastery": {"hero": "liliana", "tab": 0, "row": 2, "col": 2, "req": ["grave_golem"], "name": "Golem Mastery", "kind": "passive",
		"fx": {"golem": 20}, "per": {"fx": {"golem": 15}}, "desc": "Your golems are stronger."},
	"blood_golem": {"hero": "liliana", "tab": 0, "row": 3, "col": 2, "req": ["grave_golem"], "name": "Blood Golem", "kind": "summon", "minion": "brute", "group": "golem", "golem": true,
		"tint": Color(1.5, 0.35, 0.35), "count": 1, "max": 1, "dur": 0, "hp": 4.0, "dmg": 1.6, "lifelink": 1.0, "cost": 25,
		"per": {"hp": 0.5, "dmg": 0.2, "lifelink": 0.1, "cost": 4}, "desc": "A golem whose blows heal you."},
	"deathless_host": {"hero": "liliana", "tab": 0, "row": 4, "col": 0, "req": ["death_mastery"], "name": "Deathless Host", "kind": "passive",
		"fx": {"minion_dr": 20}, "per": {"fx": {"minion_dr": 2.5}}, "desc": "Your minions shrug off blows."},
	"bone_golem": {"hero": "liliana", "tab": 0, "row": 4, "col": 2, "req": ["blood_golem"], "name": "Bone Golem", "kind": "summon", "minion": "brute", "group": "golem", "golem": true,
		"tint": Color(1.45, 1.4, 1.2), "count": 1, "max": 1, "dur": 0, "hp": 9.0, "dmg": 1.6, "cost": 35, "per": {"hp": 1.0, "dmg": 0.2, "cost": 3},
		"desc": "A golem of fused bone, very hard to destroy."},
	"flesh_golem": {"hero": "liliana", "tab": 0, "row": 5, "col": 2, "req": ["bone_golem"], "name": "Flesh Golem", "kind": "summon", "minion": "brute", "group": "golem", "golem": true,
		"tint": Color(1.3, 0.85, 0.75), "count": 1, "max": 1, "dur": 0, "hp": 6.0, "dmg": 3.0, "cost": 40, "per": {"hp": 0.8, "dmg": 0.4, "cost": 2},
		"desc": "A hulking golem of flesh that hits very hard."},
	"unearth": {"hero": "liliana", "tab": 0, "row": 5, "col": 1, "req": ["bone_archers", "bone_golem"], "name": "Unearth", "kind": "summon", "revive": true,
		"minion": "bonewalker", "corpse": 1, "count": 1, "max": 1, "dur": 180.0, "hp": 2.0, "dmg": 1.0, "cost": 45, "per": {"max": 1},
		"desc": "Bring a slain creature back to fight for you for three minutes, with twice its life."},

	# ================= Liliana: Bone and Rot =================
	"drain_life": {"hero": "liliana", "tab": 1, "row": 0, "col": 0, "req": [], "name": "Drain Life", "kind": "missile", "src": "spell",
		"dmg": [3, 6], "leech": 20, "speed": 11.0, "look": "hex", "elem": "phys", "cost": 3, "per": {"dmg": [2, 3], "leech": 1, "cost": 0.25},
		"syn": {"grasp": 10}, "desc": "A bolt of death that heals you for part of the damage."},
	"bone_splinters": {"hero": "liliana", "tab": 1, "row": 0, "col": 1, "req": [], "name": "Bone Splinters", "kind": "missile", "src": "spell",
		"dmg": [2, 4], "count": 2, "spread": 0.7, "speed": 12.0, "look": "bone", "cost": 3, "per": {"dmg": [1, 2], "count": 0.5, "cost": 0.5},
		"syn": {"bone_spear": 15, "soul_reap": 15}, "desc": "A fan of bone shards; more of them as it grows."},
	"bone_shroud": {"hero": "liliana", "tab": 1, "row": 0, "col": 2, "req": [], "name": "Bone Shroud", "kind": "shield",
		"absorb": 20, "cost": 11, "per": {"absorb": 10, "cost": 1}, "desc": "A cage of whirling bone soaks up blows until it breaks."},
	"grasp": {"hero": "liliana", "tab": 1, "row": 1, "col": 0, "req": ["drain_life"], "name": "Grasp of Darkness", "kind": "cone", "src": "spell",
		"dmg": [5, 10], "range": 2.6, "angle": 1.5, "slow": 2.0, "elem": "cold", "cost": 5, "per": {"dmg": [3, 5], "cost": 0.5},
		"desc": "Shadow hands rake and slow the foes in front of you."},
	"grisly_spectacle": {"hero": "liliana", "tab": 1, "row": 1, "col": 1, "req": ["bone_splinters"], "name": "Grisly Spectacle", "kind": "corpse", "src": "spell",
		"dmg": [4, 8], "corpse_pct": 30, "corpses": 1, "radius": 3.0, "boom": 2.0, "cost": 15, "per": {"dmg": [2, 3], "corpse_pct": 2, "corpses": 0.2, "boom": 0.15, "cost": 1},
		"desc": "A corpse near the cursor bursts, hurting foes around it by a share of the dead creature's life."},
	"death_cloud": {"hero": "liliana", "tab": 1, "row": 2, "col": 0, "req": ["grasp", "grisly_spectacle"], "name": "Death Cloud", "kind": "cloud", "src": "spell",
		"dmg": [20, 30], "radius": 2.2, "dur": 4.0, "elem": "pois", "cost": 10, "per": {"dmg": [10, 14], "cost": 1.5},
		"syn": {"pestilence": 10}, "desc": "A cloud of rot at the cursor poisons everything in it."},
	"bone_spear": {"hero": "liliana", "tab": 1, "row": 2, "col": 1, "req": ["grisly_spectacle"], "name": "Bone Spear", "kind": "missile", "src": "spell",
		"dmg": [16, 24], "pierce": true, "speed": 13.0, "look": "bone", "cost": 7, "per": {"dmg": [8, 8], "cost": 0.25},
		"syn": {"bone_splinters": 8, "soul_reap": 8}, "desc": "A spear of bone that pierces every foe in its path."},
	"bone_cage": {"hero": "liliana", "tab": 1, "row": 3, "col": 2, "req": ["bone_spear", "bone_shroud"], "name": "Bone Cage", "kind": "curse", "radius": 1.5, "dur": 2.0,
		"debuff": {"stun": 2.0}, "cost": 12, "per": {"radius": 0.1, "dur": 0.2, "debuff": {"stun": 0.2}}, "desc": "Bones burst from the ground and hold the foes near the cursor."},
	"pestilence": {"hero": "liliana", "tab": 1, "row": 4, "col": 0, "req": ["death_cloud"], "name": "Pestilence", "kind": "nova", "src": "spell", "as_dot": true,
		"dmg": [30, 40], "radius": 4.5, "elem": "pois", "cost": 20, "per": {"dmg": [12, 16], "cost": 3}, "syn": {"death_cloud": 10},
		"desc": "A ring of plague poisons every foe around you over 2 seconds."},
	"soul_reap": {"hero": "liliana", "tab": 1, "row": 5, "col": 1, "req": ["bone_spear", "bone_cage"], "name": "Soul Reap", "kind": "missile", "src": "spell",
		"dmg": [40, 50], "boom": 1.2, "speed": 7.0, "look": "hex", "cost": 12, "per": {"dmg": [10, 12], "cost": 1},
		"syn": {"bone_splinters": 8, "bone_spear": 8}, "desc": "A wailing spirit that bursts on the first foe it touches."},

	# ================= Liliana: Curses =================
	"agony_warp": {"hero": "liliana", "tab": 2, "row": 0, "col": 1, "req": [], "name": "Agony Warp", "kind": "curse", "radius": 1.3, "dur": 8.0,
		"debuff": {"vuln": 50}, "cost": 4, "per": {"radius": 0.17, "dur": 3.0}, "desc": "Cursed foes take far more damage."},
	"darkness": {"hero": "liliana", "tab": 2, "row": 1, "col": 0, "req": [], "name": "Darkness", "kind": "curse", "radius": 1.3, "dur": 7.0,
		"debuff": {"blind": 1}, "cost": 9, "per": {"radius": 0.4, "dur": 2.0}, "desc": "Cursed foes can barely see and lose track of you."},
	"weakness": {"hero": "liliana", "tab": 2, "row": 1, "col": 2, "req": [], "name": "Weakness", "kind": "curse", "radius": 2.4, "dur": 14.0,
		"debuff": {"weak": 33}, "cost": 4, "per": {"radius": 0.2, "dur": 2.0}, "desc": "Cursed foes deal a third less damage."},
	"torment": {"hero": "liliana", "tab": 2, "row": 2, "col": 1, "req": ["agony_warp"], "name": "Torment", "kind": "curse", "radius": 1.3, "dur": 12.0,
		"debuff": {"reflect": 200}, "cost": 5, "per": {"radius": 0.2, "dur": 2.4, "debuff": {"reflect": 25}}, "desc": "Cursed foes suffer the damage of their own blows."},
	"terror": {"hero": "liliana", "tab": 2, "row": 3, "col": 0, "req": ["darkness"], "name": "Terror", "kind": "curse", "radius": 2.6, "dur": 4.0,
		"debuff": {"fear": 4.0}, "cost": 7, "per": {"dur": 0.5, "debuff": {"fear": 0.5}}, "desc": "Cursed foes flee in terror."},
	"delirium": {"hero": "liliana", "tab": 2, "row": 3, "col": 2, "req": ["weakness"], "name": "Delirium", "kind": "curse", "radius": 2.6, "dur": 10.0,
		"debuff": {"confuse": 1}, "cost": 13, "per": {"radius": 0.2, "dur": 2.0}, "desc": "Cursed foes attack whatever is nearest, friend or foe."},
	"dread": {"hero": "liliana", "tab": 2, "row": 4, "col": 0, "req": ["terror"], "name": "Dread", "kind": "curse", "radius": 2.6, "dur": 4.0,
		"debuff": {"slow": 1, "weak": 25, "vuln": 25}, "cost": 11, "per": {"dur": 0.6}, "desc": "Cursed foes slow down, hit softer and take more damage."},
	"vampiric_embrace": {"hero": "liliana", "tab": 2, "row": 4, "col": 1, "req": ["torment"], "name": "Vampiric Embrace", "kind": "curse", "radius": 2.0, "dur": 13.0,
		"debuff": {"tap": 50}, "cost": 9, "per": {"radius": 0.2, "dur": 2.0}, "desc": "Every hit on a cursed foe heals you."},
	"lure": {"hero": "liliana", "tab": 2, "row": 4, "col": 2, "req": ["delirium"], "name": "Lure of the Grave", "kind": "curse", "radius": 6.0, "dur": 12.0,
		"debuff": {"bait": 1}, "cost": 17, "per": {"dur": 3.6}, "desc": "Curse the foe nearest the cursor: the others around it turn on it."},
	"deaths_hold": {"hero": "liliana", "tab": 2, "row": 5, "col": 1, "req": ["vampiric_embrace"], "name": "Death's Hold", "kind": "curse", "src": "spell", "radius": 2.6, "dur": 20.0,
		"dmg": [10, 14], "debuff": {"vuln": 30, "dot": 1}, "elem": "pois", "cost": 22, "per": {"dur": 2.0, "dmg": [4, 6], "debuff": {"vuln": 2}},
		"desc": "Cursed foes take more damage and rot away for the length of the curse."},
}


## The skill at level lvl: "per" added for every level above the first; damage synergies from
## the hard points in pts (skill id -> points) are summed into syn_bonus (%).
static func resolve(id: String, lvl: int, pts: Dictionary = {}) -> Dictionary:
	var s: Dictionary = SKILLS[id].duplicate(true)
	s.id = id
	s.lvl = lvl
	var n := maxi(0, lvl - 1)
	if s.has("per"):
		_grow(s, s.per, n)
	if s.has("cost"):
		s.cost = maxf(s.get("cost_min", 0.0), s.cost)
	var bonus := 0.0
	for k in s.get("syn", {}):
		bonus += s.syn[k] * pts.get(k, 0)
	s.syn_bonus = bonus
	return s


static func _grow(s: Dictionary, per: Dictionary, n: int) -> void:
	for k in per:
		var v = per[k]
		if v is Dictionary:
			if not s.has(k):
				s[k] = {}
			_grow(s[k], v, n)
		elif v is Array:
			s[k] = [s[k][0] + v[0] * n, s[k][1] + v[1] * n]
		elif k in INT_KEYS:
			s[k] = int(floor(s.get(k, 0) + v * n + 0.001))
		else:
			s[k] = s.get(k, 0.0) + v * n


## A hero's skills in tree order: tab, then row, then column.
static func of_hero(hero: String) -> Array:
	var ids: Array = []
	for id in SKILLS:
		if SKILLS[id].hero == hero:
			ids.append(id)
	ids.sort_custom(func(a, b): return _order(a) < _order(b))
	return ids


static func _order(id: String) -> int:
	return SKILLS[id].tab * 100 + SKILLS[id].row * 10 + SKILLS[id].col


static func of_tab(hero: String, tab: int) -> Array:
	return of_hero(hero).filter(func(id): return SKILLS[id].tab == tab)


static func req_level(id: String) -> int:
	return ROW_LVL[SKILLS[id].row]


static func is_passive(id: String) -> bool:
	return SKILLS[id].kind == "passive"


## Skills that need a target under the cursor or walk into melee range.
static func is_melee(s: Dictionary) -> bool:
	return s.kind == "melee"


## What a skill does at its level, line by line, for the skill tree. dmg: the damage range a
## hit really deals, worked out by the hero (synergies and gear included), or empty.
static func lines(s: Dictionary, dmg: Array) -> Array:
	var out: Array = []
	if s.get("src", "") == "weapon":
		out.append("Damage: %d%% of weapon damage" % roundi(s.pct))
		if s.get("ar", 0) > 0:
			out.append("Attack rating: +%d%%" % roundi(s.ar))
		if s.get("hits", 1) > 1:
			out.append("Strikes %d times" % s.hits)
		if s.get("sure", false):
			out.append("Always hits")
	if s.has("hp_pct"):
		out.append("Takes %d%% of each foe's life" % s.hp_pct)
	elif not dmg.is_empty():
		var what: String = {"fire": "Fire damage", "lit": "Lightning damage", "cold": "Cold damage", "pois": "Poison damage"}.get(s.get("elem", ""), "Damage")
		out.append("%s: %d-%d" % [what, dmg[0], dmg[1]] + (" (per section)" if s.has("wall") else ""))
	if s.has("corpse_pct"):
		out.append("Plus %d%% of the corpse's life" % roundi(s.corpse_pct))
	if s.get("count", 1) > 1 and s.kind in ["missile", "blast"]:
		out.append("%d at once" % s.count)
	if s.kind == "chain":
		out.append("Leaps to %d more foes" % s.jumps)
	if s.kind == "corpse":
		out.append("Corpses: %d" % s.corpses)
	if s.kind == "summon":
		out.append("Up to %d" % s.max + (" for %d seconds" % roundi(s.dur) if s.dur > 0 else ""))
		out.append("Life x%.1f, damage x%.1f" % [s.hp, s.dmg])
		if s.get("lifelink", 0.0) > 0.0:
			out.append("Each hit heals you %.1f%% of your life" % s.lifelink)
	if s.kind == "scavenge" and s.has("chance"):
		out.append("Chance: %d%%" % roundi(s.chance))
	if s.kind == "shield":
		out.append("Absorbs %d physical damage" % roundi(s.absorb))
	if s.has("radius") and s.kind in ["nova", "blast", "cloud", "curse", "shout", "leap", "corpse", "scavenge"]:
		out.append("Radius: %.1f tiles" % s.radius)
	if s.kind in ["leap", "teleport", "charge"]:
		out.append("Distance: %.1f tiles" % s.dist)
	if s.kind == "beam":
		out.append("Length: %.1f tiles" % s.length)
	for k in ["stun", "slow"]:
		if s.has(k) and not s.has("debuff"):
			out.append(("Stuns for %.1f s" if k == "stun" else "Slows for %.1f s") % s[k])
	if s.has("knock"):
		out.append("Knocks foes back")
	if s.has("burn"):
		out.append("Burns for another %d%% over 3 s" % roundi(s.burn))
	if s.has("leech"):
		out.append("Heals you for %d%% of the damage" % roundi(s.leech))
	for k in s.get("debuff", {}):
		if DEBUFF_TEXT.has(k):
			var txt: String = DEBUFF_TEXT[k]
			out.append(txt % s.debuff[k] if "%" in txt.replace("%%", "") else txt)
	for k in s.get("fx", {}):
		if FX_TEXT.has(k):
			out.append(FX_TEXT[k] % s.fx[k])
	if s.has("self"):
		for k in s.self.fx:
			if FX_TEXT.has(k):
				out.append((FX_TEXT[k] % s.self.fx[k]) + " for %.1f s" % s.self.dur)
	if s.get("dur", 0) > 0 and s.kind in ["buff", "shout", "curse", "cloud", "scavenge"]:
		out.append("Duration: %d seconds" % roundi(s.dur))
	if s.get("cd", 0) > 0:
		out.append("Casting delay: %.1f s" % s.cd)
	if s.get("cost", 0) > 0:
		out.append("Mana cost: %s" % (str(snappedf(s.cost, 0.1)) if fmod(s.cost, 1.0) > 0.01 else str(roundi(s.cost))))
	return out
