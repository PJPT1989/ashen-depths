class_name Skills
extends RefCounted
## Skills of the three planeswalkers, laid out like Diablo III: six categories per hero, two
## skills in each, unlocked by level. Every skill has three runes (variants) that unlock later
## and change how it works, and each hero has six passives for up to three passive slots.
## There are no skill points: the hero picks which skill sits on each of the six hotbar slots
## (left click, right click, 1-4) and which rune it uses. Player.use_skill() runs them.
##
## Skill fields (a rune's fields replace the skill's):
##   kind   melee, cone, missile, chain, beam, nova, blast, cloud, leap, charge, teleport,
##          buff, shout, curse, summon, corpse
##   src    "weapon" (weapon damage, Strength bonus included) or "spell" (grows with level and
##          the +% spell damage on items); pct is the percentage of it a hit deals
##   cost   resource spent; gen: resource gained when it hits; cd: cooldown in seconds
##   elem   phys, fire, cold, lit, pois
##   on-hit slow, stun, fear (seconds), knock (tiles), burn (pct dealt again over 3 s),
##          heal (% of max life per monster hit), leech (% of damage), vuln (% more damage taken, 4 s)
##   fx     buff on the hero for dur seconds: dmg, aspd, speed, def (%), taken (damage taken
##          multiplier), regen (% life per second), leech, thorns (% weapon damage), gen (resource
##          multiplier), cost (cost multiplier), rregen (resource per second)
##   debuff on monsters for dur seconds: weak (% less damage dealt), slow, vuln, fear, dot (pct)
##   summon minion: a monster type, count, max, dur (0 = until killed), hp and dmg multipliers

## Resource of each hero: name, colour, how it behaves.
##   Ferocity builds when Ajani hits and fades out of combat; mana refills quickly;
##   Soul comes from Liliana's rites and slowly on its own.
const RESOURCE := {
	"ajani": {"name": "Ferocity", "color": Color("e8a838"), "max": 100, "start": 0.0, "regen": -2.5},
	"chandra": {"name": "Mana", "color": Color("4f7cff"), "regen_frac": 0.1},
	"liliana": {"name": "Soul", "color": Color("7ad0a8"), "regen_frac": 0.02},
}

const CATEGORIES := {
	"ajani": ["Claw", "Maul", "Guard", "Might", "Hunt", "Roar"],
	"chandra": ["Spark", "Flame", "Ward", "Pyromancy", "Kindling", "Inferno"],
	"liliana": ["Rite", "Torment", "Corpse", "Reanimation", "Curse", "Blood"],
}

## The hotbar: left click, right click, then keys 1 to 4. Starting picks per hero.
const SLOT_KEYS := ["LMB", "RMB", "1", "2", "3", "4"]
const DEFAULT_BAR := {
	"ajani": ["savage_swipe", "crushing_maul", "", "", "", ""],
	"chandra": ["shock", "fireball", "", "", "", ""],
	"liliana": ["drain_life", "raise_dead", "", "", "", ""],
}
## Level at which each passive slot opens.
const PASSIVE_SLOTS := [4, 10, 16]

const SKILLS := {
	# ---------------- Ajani ----------------
	"savage_swipe": {"hero": "ajani", "cat": 0, "lvl": 1, "name": "Savage Swipe", "kind": "melee", "src": "weapon", "pct": 120, "gen": 8,
		"desc": "Rake a foe with your claws for 120% weapon damage. Builds 8 Ferocity.",
		"runes": [
			{"name": "Rending", "lvl": 3, "burn": 60, "elem": "phys", "desc": "Wounds bleed for another 60% over 3 seconds."},
			{"name": "Pouncing Strikes", "lvl": 6, "aspd": 0.75, "desc": "Attacks come a quarter faster."},
			{"name": "Lifeblood", "lvl": 10, "heal": 3, "desc": "Each hit heals 3% of your life."}]},
	"flurry": {"hero": "ajani", "cat": 0, "lvl": 4, "name": "Flurry of Claws", "kind": "melee", "src": "weapon", "pct": 90, "arc": 1.6, "gen": 10,
		"desc": "Sweep through every foe around your target for 90% weapon damage. Builds 10 Ferocity.",
		"runes": [
			{"name": "Wide Sweep", "lvl": 6, "arc": 2.5, "desc": "The sweep reaches much further."},
			{"name": "Thundering", "lvl": 9, "stun": 0.8, "desc": "Stuns foes for 0.8 seconds."},
			{"name": "Sun-Claw", "lvl": 13, "elem": "fire", "pct": 110, "desc": "Burns with the sun: 110% weapon damage as fire."}]},
	"crushing_maul": {"hero": "ajani", "cat": 1, "lvl": 1, "name": "Crushing Maul", "kind": "melee", "src": "weapon", "pct": 260, "arc": 1.2, "cost": 20,
		"desc": "A two-handed blow for 260% weapon damage that also hits foes beside the target. Costs 20 Ferocity.",
		"runes": [
			{"name": "Shockwave", "lvl": 5, "arc": 2.4, "desc": "The blow shakes the ground much further out."},
			{"name": "Bloodletting", "lvl": 8, "leech": 8, "desc": "Heals you for 8% of the damage dealt."},
			{"name": "Shattering", "lvl": 12, "stun": 1.2, "knock": 1.2, "desc": "Knocks foes back and stuns them for 1.2 seconds."}]},
	"whirling_mane": {"hero": "ajani", "cat": 1, "lvl": 6, "name": "Whirling Mane", "kind": "nova", "src": "weapon", "pct": 200, "radius": 2.2, "cost": 25,
		"desc": "Spin with your weapon out, hitting everything around you for 200% weapon damage. Costs 25 Ferocity.",
		"runes": [
			{"name": "Dust Devil", "lvl": 9, "radius": 3.2, "desc": "A much wider spin."},
			{"name": "Searing Spin", "lvl": 12, "elem": "fire", "burn": 80, "desc": "Deals fire damage and burns for another 80%."},
			{"name": "Second Wind", "lvl": 16, "heal": 2, "desc": "Heals 2% of your life for each foe hit."}]},
	"ajanis_presence": {"hero": "ajani", "cat": 2, "lvl": 3, "name": "Ajani's Presence", "kind": "buff", "cd": 15, "dur": 6, "fx": {"taken": 0.65},
		"desc": "For 6 seconds you take 35% less damage.",
		"runes": [
			{"name": "Indestructible", "lvl": 7, "dur": 9, "desc": "Lasts 9 seconds."},
			{"name": "Retaliation", "lvl": 10, "fx": {"taken": 0.65, "thorns": 100}, "desc": "Foes that strike you take 100% of your weapon damage."},
			{"name": "Inspired", "lvl": 14, "fx": {"taken": 0.65, "regen": 4}, "desc": "Also heals 4% of your life every second."}]},
	"pride_guardian": {"hero": "ajani", "cat": 2, "lvl": 8, "name": "Pride Guardian", "kind": "shout", "cd": 20, "dur": 8, "radius": 6.0,
		"debuff": {"weak": 30}, "fx": {"def": 50},
		"desc": "A roar that weakens foes within 6 tiles (they deal 30% less damage) and raises your defense by half, for 8 seconds.",
		"runes": [
			{"name": "Fearsome", "lvl": 11, "debuff": {"weak": 30, "fear": 2.5}, "desc": "Foes also flee in terror for 2.5 seconds."},
			{"name": "Bulwark", "lvl": 14, "fx": {"def": 100}, "desc": "Doubles your defense instead."},
			{"name": "Long Watch", "lvl": 18, "dur": 14, "desc": "Lasts 14 seconds."}]},
	"pounce": {"hero": "ajani", "cat": 3, "lvl": 5, "name": "Pounce", "kind": "leap", "src": "weapon", "pct": 180, "dist": 7.0, "radius": 1.8, "cd": 8, "slow": 2.0,
		"desc": "Leap up to 7 tiles and land for 180% weapon damage around you, slowing foes.",
		"runes": [
			{"name": "Earthshaker", "lvl": 8, "stun": 1.5, "desc": "Stuns foes where you land for 1.5 seconds."},
			{"name": "Far Leap", "lvl": 11, "dist": 11.0, "cd": 5, "desc": "Leap 11 tiles, every 5 seconds."},
			{"name": "Iron Hide", "lvl": 15, "self": {"dur": 3, "fx": {"taken": 0.5}}, "desc": "Take half damage for 3 seconds after landing."}]},
	"overrun": {"hero": "ajani", "cat": 3, "lvl": 10, "name": "Overrun", "kind": "charge", "src": "weapon", "pct": 200, "dist": 8.0, "cd": 10,
		"desc": "Charge up to 8 tiles, trampling everything in the way for 200% weapon damage.",
		"runes": [
			{"name": "Stampede", "lvl": 13, "cd": 5, "desc": "Every 5 seconds."},
			{"name": "Trample", "lvl": 16, "knock": 1.5, "desc": "Throws foes aside."},
			{"name": "Rallying", "lvl": 19, "gen": 15, "desc": "Builds 15 Ferocity for each foe hit."}]},
	"battle_cry": {"hero": "ajani", "cat": 4, "lvl": 7, "name": "Battle Cry", "kind": "buff", "cd": 20, "dur": 8, "fx": {"dmg": 25, "speed": 15},
		"desc": "For 8 seconds you deal 25% more damage and move 15% faster.",
		"runes": [
			{"name": "Glory", "lvl": 10, "fx": {"dmg": 25, "speed": 15, "rregen": 4}, "desc": "Also builds 4 Ferocity every second."},
			{"name": "Swiftness", "lvl": 13, "fx": {"dmg": 25, "speed": 30, "aspd": 25}, "desc": "Move 30% faster and attack 25% faster."},
			{"name": "Bloodthirst", "lvl": 17, "fx": {"dmg": 25, "speed": 15, "leech": 4}, "desc": "Your hits heal 4% of the damage dealt."}]},
	"pridemate": {"hero": "ajani", "cat": 4, "lvl": 12, "name": "Ajani's Pridemate", "kind": "summon", "minion": "gloomhound", "count": 1, "max": 1, "dur": 0, "cost": 30, "hp": 4.0, "dmg": 1.2,
		"desc": "Call a leonin war-cat that fights at your side until it falls. Costs 30 Ferocity.",
		"runes": [
			{"name": "Pride", "lvl": 14, "max": 2, "desc": "Up to two war-cats."},
			{"name": "Fierce", "lvl": 17, "dmg": 2.0, "desc": "The cat deals much more damage."},
			{"name": "Celestial", "lvl": 20, "hp": 9.0, "desc": "The cat is far tougher."}]},
	"day_of_judgment": {"hero": "ajani", "cat": 5, "lvl": 14, "name": "Day of Judgment", "kind": "nova", "src": "weapon", "pct": 400, "radius": 5.0, "cd": 30, "elem": "fire",
		"desc": "Call down the sun on everything within 5 tiles: 400% weapon damage as fire.",
		"runes": [
			{"name": "Dawn", "lvl": 16, "stun": 2.0, "desc": "Stuns survivors for 2 seconds."},
			{"name": "Purge", "lvl": 19, "radius": 7.0, "desc": "Reaches 7 tiles."},
			{"name": "Absolution", "lvl": 22, "self_heal": 30, "desc": "Heals you for 30% of your life."}]},
	"crusade": {"hero": "ajani", "cat": 5, "lvl": 16, "name": "Crusade", "kind": "buff", "cd": 45, "dur": 15, "fx": {"dmg": 60, "aspd": 25, "def": 50},
		"desc": "For 15 seconds: 60% more damage, 25% faster attacks, half again as much defense.",
		"runes": [
			{"name": "Holy Zeal", "lvl": 18, "fx": {"dmg": 60, "aspd": 25, "def": 50, "gen": 2.0}, "desc": "Ferocity builds twice as fast."},
			{"name": "Endless", "lvl": 20, "dur": 25, "desc": "Lasts 25 seconds."},
			{"name": "Radiance", "lvl": 23, "fx": {"dmg": 60, "aspd": 25, "def": 50, "thorns": 200}, "desc": "Foes that strike you take 200% weapon damage."}]},

	# ---------------- Chandra ----------------
	"shock": {"hero": "chandra", "cat": 0, "lvl": 1, "name": "Shock", "kind": "missile", "src": "spell", "pct": 70, "speed": 13.0, "look": "spark", "elem": "fire",
		"desc": "A quick bolt of fire for 70% spell damage. Free to cast.",
		"runes": [
			{"name": "Spark Volley", "lvl": 3, "count": 3, "spread": 0.5, "desc": "Throws three bolts in a fan."},
			{"name": "Piercing", "lvl": 6, "pierce": true, "desc": "Bolts pass through every foe in a line."},
			{"name": "Blazing Shock", "lvl": 10, "boom": 1.3, "desc": "Bolts explode, hitting foes around the target."}]},
	"flame_slash": {"hero": "chandra", "cat": 0, "lvl": 4, "name": "Flame Slash", "kind": "cone", "src": "spell", "pct": 90, "range": 2.6, "angle": 1.2, "elem": "fire",
		"desc": "A sweep of flame in front of you for 90% spell damage. Free to cast.",
		"runes": [
			{"name": "Wide Arc", "lvl": 6, "angle": 2.2, "range": 3.0, "desc": "A much wider sweep."},
			{"name": "Searing", "lvl": 9, "burn": 80, "desc": "Burns for another 80% over 3 seconds."},
			{"name": "Smoke Cloud", "lvl": 13, "slow": 2.5, "desc": "Slows foes for 2.5 seconds."}]},
	"fireball": {"hero": "chandra", "cat": 1, "lvl": 1, "name": "Fireball", "kind": "missile", "src": "spell", "pct": 190, "speed": 9.0, "boom": 1.6, "cost": 12, "look": "fire", "elem": "fire",
		"desc": "A ball of fire that explodes for 190% spell damage. Costs 12 mana.",
		"runes": [
			{"name": "Great Fireball", "lvl": 5, "boom": 2.6, "desc": "A far larger explosion."},
			{"name": "Cluster", "lvl": 8, "count": 3, "spread": 0.45, "cost": 18, "desc": "Three fireballs in a fan for 18 mana."},
			{"name": "Fiery Temper", "lvl": 12, "burn": 100, "desc": "Burns for another 100% over 3 seconds."}]},
	"chain_lightning": {"hero": "chandra", "cat": 1, "lvl": 6, "name": "Chain Lightning", "kind": "chain", "src": "spell", "pct": 170, "jumps": 3, "range": 8.0, "cost": 16, "elem": "lit",
		"desc": "Lightning strikes a foe and leaps to 3 more, 170% spell damage each. Costs 16 mana.",
		"runes": [
			{"name": "Fork", "lvl": 9, "jumps": 6, "desc": "Leaps to 6 more foes."},
			{"name": "Overload", "lvl": 12, "stun": 1.0, "desc": "Stuns each foe for a second."},
			{"name": "Static", "lvl": 16, "cost": 9, "desc": "Costs 9 mana."}]},
	"pyroclasm": {"hero": "chandra", "cat": 2, "lvl": 3, "name": "Pyroclasm", "kind": "nova", "src": "spell", "pct": 150, "radius": 3.5, "cd": 6, "cost": 10, "knock": 1.2, "elem": "fire",
		"desc": "A ring of fire bursts out around you for 150% spell damage and throws foes back.",
		"runes": [
			{"name": "Firestorm", "lvl": 6, "radius": 5.0, "desc": "Reaches 5 tiles."},
			{"name": "Scorching", "lvl": 9, "burn": 100, "desc": "Burns for another 100% over 3 seconds."},
			{"name": "Blinding Flash", "lvl": 13, "stun": 1.5, "desc": "Stuns foes for 1.5 seconds."}]},
	"firewalk": {"hero": "chandra", "cat": 2, "lvl": 8, "name": "Firewalk", "kind": "teleport", "dist": 8.0, "cd": 6, "src": "spell", "pct": 0, "elem": "fire",
		"desc": "Vanish in flame and reappear up to 8 tiles away.",
		"runes": [
			{"name": "Wildfire Wake", "lvl": 11, "pct": 150, "boom": 2.2, "desc": "Leaves an explosion behind for 150% spell damage."},
			{"name": "Quickstep", "lvl": 14, "cd": 3, "desc": "Every 3 seconds."},
			{"name": "Afterburn", "lvl": 18, "self": {"dur": 3, "fx": {"speed": 40}}, "desc": "Move 40% faster for 3 seconds after."}]},
	"fireblast": {"hero": "chandra", "cat": 3, "lvl": 5, "name": "Fireblast", "kind": "blast", "src": "spell", "pct": 330, "radius": 2.0, "delay": 0.7, "cost": 30, "elem": "fire",
		"desc": "A meteor of fire crashes down at the cursor for 330% spell damage. Costs 30 mana.",
		"runes": [
			{"name": "Molten Ground", "lvl": 8, "burn": 120, "desc": "Leaves foes burning for another 120%."},
			{"name": "Comet Storm", "lvl": 11, "count": 3, "pct": 200, "desc": "Three smaller comets for 200% each."},
			{"name": "Cataclysm", "lvl": 15, "radius": 3.2, "desc": "A much larger impact."}]},
	"incinerate": {"hero": "chandra", "cat": 3, "lvl": 10, "name": "Incinerate", "kind": "beam", "src": "spell", "pct": 260, "length": 7.0, "cost": 22, "elem": "fire",
		"desc": "A searing beam burns every foe in a 7 tile line for 260% spell damage. Costs 22 mana.",
		"runes": [
			{"name": "Lance", "lvl": 13, "length": 11.0, "desc": "The beam reaches 11 tiles."},
			{"name": "Seared Flesh", "lvl": 16, "burn": 120, "desc": "Burns for another 120% over 3 seconds."},
			{"name": "Focused", "lvl": 19, "cost": 12, "desc": "Costs 12 mana."}]},
	"fervor": {"hero": "chandra", "cat": 4, "lvl": 7, "name": "Fervor", "kind": "buff", "cd": 20, "dur": 10, "fx": {"dmg": 30},
		"desc": "Your spells deal 30% more damage for 10 seconds.",
		"runes": [
			{"name": "Mana Rush", "lvl": 10, "fx": {"dmg": 30, "rregen": 6}, "desc": "Also restores 6 mana every second."},
			{"name": "Overheat", "lvl": 13, "fx": {"dmg": 30, "speed": 20, "aspd": 20}, "desc": "Move and cast 20% faster as well."},
			{"name": "Lasting Flame", "lvl": 17, "dur": 16, "desc": "Lasts 16 seconds."}]},
	"fire_elemental": {"hero": "chandra", "cat": 4, "lvl": 12, "name": "Fire Elemental", "kind": "summon", "minion": "wraith", "tint": Color(2.2, 0.9, 0.3), "shot": "fire",
		"count": 1, "max": 1, "dur": 20, "cost": 35, "cd": 15, "hp": 3.0, "dmg": 1.5,
		"desc": "Conjure a fire elemental that hurls fire at your foes for 20 seconds. Costs 35 mana.",
		"runes": [
			{"name": "Twin Flames", "lvl": 15, "count": 2, "max": 2, "desc": "Two elementals."},
			{"name": "Everburning", "lvl": 18, "dur": 45, "desc": "Lasts 45 seconds."},
			{"name": "Blazing Core", "lvl": 21, "dmg": 2.6, "desc": "Much stronger fire."}]},
	"flame_wave": {"hero": "chandra", "cat": 5, "lvl": 14, "name": "Flame Wave", "kind": "nova", "src": "spell", "pct": 420, "radius": 6.0, "cd": 20, "cost": 30, "elem": "fire",
		"desc": "A wall of fire rolls out 6 tiles for 420% spell damage.",
		"runes": [
			{"name": "Scorched Earth", "lvl": 16, "burn": 150, "desc": "Burns for another 150% over 3 seconds."},
			{"name": "Heatwave", "lvl": 19, "radius": 8.5, "desc": "Rolls out 8.5 tiles."},
			{"name": "Aftershock", "lvl": 22, "again": 1.0, "desc": "A second wave follows a second later."}]},
	"ascension": {"hero": "chandra", "cat": 5, "lvl": 16, "name": "Pyromancer's Ascension", "kind": "buff", "cd": 40, "dur": 15, "fx": {"dmg": 50, "cost": 0.5},
		"desc": "Become living flame for 15 seconds: 50% more damage, spells cost half.",
		"runes": [
			{"name": "Ascended", "lvl": 18, "dur": 25, "desc": "Lasts 25 seconds."},
			{"name": "Flameborn", "lvl": 20, "fx": {"dmg": 50, "cost": 0.5, "leech": 3}, "desc": "Your spells heal 3% of the damage dealt."},
			{"name": "Overflow", "lvl": 23, "fx": {"dmg": 50, "cost": 0.5, "speed": 30}, "desc": "Move 30% faster."}]},

	# ---------------- Liliana ----------------
	"drain_life": {"hero": "liliana", "cat": 0, "lvl": 1, "name": "Drain Life", "kind": "missile", "src": "spell", "pct": 70, "speed": 11.0, "gen": 8, "look": "hex", "elem": "phys",
		"desc": "A bolt of death for 70% spell damage. Gathers 8 Soul when it hits.",
		"runes": [
			{"name": "Siphon", "lvl": 3, "heal": 3, "desc": "Each hit heals 3% of your life."},
			{"name": "Chilling", "lvl": 6, "elem": "cold", "slow": 2.0, "desc": "Cold damage that slows."},
			{"name": "Leech Swarm", "lvl": 10, "count": 3, "spread": 0.5, "desc": "Three bolts in a fan."}]},
	"grasp": {"hero": "liliana", "cat": 0, "lvl": 4, "name": "Grasp of Darkness", "kind": "cone", "src": "spell", "pct": 95, "range": 2.4, "angle": 1.6, "gen": 10, "elem": "cold",
		"desc": "Shadow hands rake the foes in front of you for 95% spell damage. Gathers 10 Soul.",
		"runes": [
			{"name": "Frostreap", "lvl": 6, "slow": 2.5, "desc": "Slows foes for 2.5 seconds."},
			{"name": "Cursed Touch", "lvl": 9, "vuln": 15, "desc": "Foes hit take 15% more damage for 4 seconds."},
			{"name": "Life Harvest", "lvl": 13, "heal": 1.5, "desc": "Heals 1.5% of your life per foe hit."}]},
	"bone_splinters": {"hero": "liliana", "cat": 1, "lvl": 2, "name": "Bone Splinters", "kind": "missile", "src": "spell", "pct": 200, "speed": 12.0, "cost": 18, "look": "bone", "pierce": true,
		"desc": "A spear of bone that pierces every foe in its path for 200% spell damage. Costs 18 Soul.",
		"runes": [
			{"name": "Shrapnel", "lvl": 5, "count": 3, "spread": 0.4, "pct": 140, "desc": "Three spears in a fan for 140% each."},
			{"name": "Marrow Burst", "lvl": 8, "boom": 1.5, "pierce": false, "pct": 260, "desc": "Bursts on the first foe for 260% around it."},
			{"name": "Bone Prison", "lvl": 12, "stun": 1.0, "desc": "Stuns foes for a second."}]},
	"death_cloud": {"hero": "liliana", "cat": 1, "lvl": 7, "name": "Death Cloud", "kind": "cloud", "src": "spell", "pct": 380, "radius": 2.2, "dur": 4, "cost": 25, "elem": "pois",
		"desc": "A cloud of rot at the cursor poisons foes for 380% spell damage over 4 seconds. Costs 25 Soul.",
		"runes": [
			{"name": "Spreading Rot", "lvl": 10, "radius": 3.2, "desc": "A much larger cloud."},
			{"name": "Lingering", "lvl": 13, "dur": 7, "pct": 600, "desc": "Lasts 7 seconds for 600% in all."},
			{"name": "Choking", "lvl": 17, "slow": 1.0, "desc": "Foes in the cloud are slowed."}]},
	"grisly_spectacle": {"hero": "liliana", "cat": 2, "lvl": 3, "name": "Grisly Spectacle", "kind": "corpse", "src": "spell", "pct": 160, "corpses": 4, "radius": 3.0, "boom": 2.0, "cost": 8, "elem": "phys",
		"desc": "Up to 4 corpses near the cursor burst, each for 160% spell damage plus a tenth of the dead creature's life. Costs 8 Soul.",
		"runes": [
			{"name": "Chain Blast", "lvl": 6, "corpses": 8, "desc": "Up to 8 corpses."},
			{"name": "Bloodspill", "lvl": 9, "self_heal_per": 3, "desc": "Heals 3% of your life for each corpse."},
			{"name": "Plague Burst", "lvl": 13, "elem": "pois", "pct": 220, "desc": "Bursts of poison for 220%."}]},
	"unearth": {"hero": "liliana", "cat": 2, "lvl": 8, "name": "Unearth", "kind": "summon", "minion": "bonewalker", "corpse": 1, "count": 1, "max": 8, "dur": 20, "cost": 10, "hp": 1.5, "dmg": 1.0,
		"desc": "Raise a corpse near the cursor as a skeleton that fights for 20 seconds. Costs 10 Soul.",
		"runes": [
			{"name": "Mass Grave", "lvl": 11, "corpse": 3, "count": 3, "desc": "Raises up to 3 corpses at once."},
			{"name": "Restless", "lvl": 14, "dur": 40, "desc": "Skeletons last 40 seconds."},
			{"name": "Death Knights", "lvl": 18, "dmg": 1.8, "hp": 2.5, "desc": "Stronger, tougher skeletons."}]},
	"raise_dead": {"hero": "liliana", "cat": 3, "lvl": 1, "name": "Raise Dead", "kind": "summon", "minion": "bonewalker", "count": 2, "max": 2, "dur": 0, "cost": 15, "hp": 2.0, "dmg": 0.8,
		"desc": "Raise two skeleton warriors that follow you until destroyed. Costs 15 Soul.",
		"runes": [
			{"name": "Army of Bone", "lvl": 5, "count": 4, "max": 4, "desc": "Four skeletons."},
			{"name": "Bone Archers", "lvl": 8, "minion": "bone_archer", "shot": "arrow", "desc": "Skeleton archers that shoot from range."},
			{"name": "Hardened Bone", "lvl": 12, "hp": 4.5, "desc": "Far tougher skeletons."}]},
	"grave_golem": {"hero": "liliana", "cat": 3, "lvl": 10, "name": "Grave Golem", "kind": "summon", "minion": "brute", "tint": Color(0.7, 0.55, 1.0), "count": 1, "max": 1, "dur": 0, "cost": 40, "hp": 6.0, "dmg": 1.8,
		"desc": "Stitch together a hulking golem that fights for you until destroyed. Costs 40 Soul.",
		"runes": [
			{"name": "Blood Golem", "lvl": 13, "lifelink": 1.0, "desc": "Each golem hit heals you for 1% of your life."},
			{"name": "Bone Golem", "lvl": 16, "hp": 14.0, "desc": "Far tougher."},
			{"name": "Flesh Golem", "lvl": 19, "dmg": 3.2, "desc": "Hits much harder."}]},
	"agony_warp": {"hero": "liliana", "cat": 4, "lvl": 5, "name": "Agony Warp", "kind": "curse", "radius": 3.0, "dur": 6, "cost": 10, "debuff": {"weak": 30, "slow": 1},
		"desc": "Curse foes near the cursor for 6 seconds: they deal 30% less damage and move slowly. Costs 10 Soul.",
		"runes": [
			{"name": "Spreading Agony", "lvl": 8, "radius": 4.5, "desc": "A much larger area."},
			{"name": "Prolonged", "lvl": 11, "dur": 10, "desc": "Lasts 10 seconds."},
			{"name": "Terror", "lvl": 15, "debuff": {"weak": 30, "slow": 1, "fear": 2.5}, "desc": "Foes also flee for 2.5 seconds."}]},
	"deaths_hold": {"hero": "liliana", "cat": 4, "lvl": 12, "name": "Curse of Death's Hold", "kind": "curse", "radius": 3.0, "dur": 8, "cost": 15, "debuff": {"vuln": 30},
		"desc": "Curse foes near the cursor to take 30% more damage for 8 seconds. Costs 15 Soul.",
		"runes": [
			{"name": "Decay", "lvl": 14, "debuff": {"vuln": 30, "dot": 150}, "src": "spell", "desc": "Also rots them for 150% spell damage over the curse."},
			{"name": "Wide Hold", "lvl": 17, "radius": 4.5, "desc": "A much larger area."},
			{"name": "Hollow", "lvl": 20, "debuff": {"vuln": 50}, "desc": "Foes take 50% more damage."}]},
	"army_of_the_damned": {"hero": "liliana", "cat": 5, "lvl": 14, "name": "Army of the Damned", "kind": "summon", "minion": "rotling", "count": 6, "max": 16, "dur": 15, "cd": 40, "cost": 30, "hp": 1.5, "dmg": 1.2,
		"desc": "Six zombies claw out of the ground and fight for 15 seconds.",
		"runes": [
			{"name": "Horde", "lvl": 16, "count": 10, "desc": "Ten zombies."},
			{"name": "Undying", "lvl": 19, "dur": 25, "desc": "They last 25 seconds."},
			{"name": "Plague Bearers", "lvl": 22, "dmg": 2.2, "desc": "Zombies hit far harder."}]},
	"sign_in_blood": {"hero": "liliana", "cat": 5, "lvl": 16, "name": "Sign in Blood", "kind": "buff", "cd": 30, "dur": 10, "life_cost": 20, "fill": true, "fx": {"dmg": 40},
		"desc": "Pay 20% of your life to fill your Soul and deal 40% more damage for 10 seconds.",
		"runes": [
			{"name": "Blood Pact", "lvl": 18, "life_cost": 10, "desc": "Costs 10% of your life."},
			{"name": "Bloodlust", "lvl": 20, "fx": {"dmg": 40, "leech": 5}, "desc": "Your damage heals 5% of what it deals."},
			{"name": "Long Ritual", "lvl": 23, "dur": 16, "desc": "Lasts 16 seconds."}]},
}

## Passive fields: dmg (% more), taken (multiplier), leech, life (% more max life), low_life
## (damage taken multiplier under 30% life), rmax (% more resource), rfast (% faster resource),
## decay (Ferocity fade multiplier), burn (fire hits burn for this % more), speed, cdr (cooldown
## multiplier), cheat_death (seconds between saves), minion (% more minion damage and life),
## cost (multiplier), soul_kill (Soul per kill).
const PASSIVES := {
	"thick_hide": {"hero": "ajani", "lvl": 3, "name": "Thick Hide", "taken": 0.85, "desc": "Take 15% less damage."},
	"prides_hunger": {"hero": "ajani", "lvl": 6, "name": "Pride's Hunger", "leech": 3, "desc": "Your hits heal 3% of the damage dealt."},
	"righteous_fury": {"hero": "ajani", "lvl": 9, "name": "Righteous Fury", "dmg": 20, "desc": "Deal 20% more damage."},
	"leonin_vigor": {"hero": "ajani", "lvl": 12, "name": "Leonin Vigor", "life": 20, "desc": "20% more life."},
	"relentless": {"hero": "ajani", "lvl": 15, "name": "Relentless", "low_life": 0.5, "desc": "Below 30% life you take half damage."},
	"unyielding": {"hero": "ajani", "lvl": 18, "name": "Unyielding", "decay": 0.4, "rmax": 25, "desc": "25% more Ferocity, and it fades far slower."},
	"fiery_temperament": {"hero": "chandra", "lvl": 3, "name": "Fiery Temperament", "dmg": 15, "desc": "Deal 15% more damage."},
	"firebrand": {"hero": "chandra", "lvl": 6, "name": "Firebrand", "burn": 40, "desc": "Fire damage burns for another 40% over 3 seconds."},
	"mana_spring": {"hero": "chandra", "lvl": 9, "name": "Mana Spring", "rfast": 40, "desc": "Mana refills 40% faster."},
	"blazing_speed": {"hero": "chandra", "lvl": 12, "name": "Blazing Speed", "speed": 15, "desc": "Move 15% faster."},
	"gauntlet": {"hero": "chandra", "lvl": 15, "name": "Pyromancer's Gauntlet", "cdr": 0.75, "desc": "Cooldowns are 25% shorter."},
	"phoenix_heart": {"hero": "chandra", "lvl": 18, "name": "Phoenix Heart", "cheat_death": 60, "desc": "A killing blow leaves you at half life instead, once a minute."},
	"lilianas_mastery": {"hero": "liliana", "lvl": 3, "name": "Liliana's Mastery", "minion": 30, "desc": "Your minions deal 30% more damage and have 30% more life."},
	"grave_pact": {"hero": "liliana", "lvl": 6, "name": "Grave Pact", "cost": 0.8, "desc": "Skills cost 20% less Soul."},
	"exsanguinate": {"hero": "liliana", "lvl": 9, "name": "Exsanguinate", "leech": 4, "desc": "Your damage heals 4% of what it deals."},
	"soul_harvest": {"hero": "liliana", "lvl": 12, "name": "Soul Harvest", "soul_kill": 4, "desc": "Gather 4 Soul whenever a foe dies near you."},
	"shroud": {"hero": "liliana", "lvl": 15, "name": "Shroud of Shadows", "taken": 0.85, "desc": "Take 15% less damage."},
	"necropotence": {"hero": "liliana", "lvl": 18, "name": "Necropotence", "rmax": 30, "desc": "30% more Soul."},
}


## The skill as it works with rune r (-1 = no rune): rune fields replace the skill's.
static func resolve(id: String, rune: int) -> Dictionary:
	var s: Dictionary = SKILLS[id].duplicate()
	s.id = id
	if rune >= 0 and rune < s.runes.size():
		for k in s.runes[rune]:
			if not k in ["name", "lvl", "desc"]:
				s[k] = s.runes[rune][k]
	return s


## Skills of a hero in category order, then by unlock level.
static func of_hero(hero: String) -> Array:
	var ids: Array = []
	for id in SKILLS:
		if SKILLS[id].hero == hero:
			ids.append(id)
	ids.sort_custom(func(a, b): return SKILLS[a].cat * 100 + SKILLS[a].lvl < SKILLS[b].cat * 100 + SKILLS[b].lvl)
	return ids


static func passives_of(hero: String) -> Array:
	var ids: Array = []
	for id in PASSIVES:
		if PASSIVES[id].hero == hero:
			ids.append(id)
	ids.sort_custom(func(a, b): return PASSIVES[a].lvl < PASSIVES[b].lvl)
	return ids


static func passive_slots(level: int) -> int:
	var n := 0
	for l in PASSIVE_SLOTS:
		if level >= l:
			n += 1
	return n


## Skills that need a target under the cursor or walk into melee range.
static func is_melee(s: Dictionary) -> bool:
	return s.kind == "melee"
