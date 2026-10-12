class_name Items
extends RefCounted
## Item bases, affixes, uniques, charms and random generation, modelled on Diablo II.
## Items are plain Dictionaries:
##   { type, base, name, rarity, ilvl, w, h, art, look, tint, seed,
##     dmg: [min, max] | [], spd, def, block, potions, req_lvl, req_str, req_dex, mods: {key: value}, value }
## type is one of TYPES; the equipment slot comes from SLOT_OF (rings fit either ring slot).
## Charms are never worn: they work while they sit in the pack.

const TYPES := ["weapon", "shield", "armor", "helm", "gloves", "belt", "boots", "amulet", "ring", "charm"]
const EQUIP_SLOTS := ["helm", "amulet", "armor", "mainhand", "offhand", "gloves", "belt", "boots", "ring1", "ring2"]
const SLOT_OF := {"weapon": ["mainhand"], "shield": ["offhand"], "armor": ["armor"], "helm": ["helm"], "gloves": ["gloves"],
	"belt": ["belt"], "boots": ["boots"], "amulet": ["amulet"], "ring": ["ring1", "ring2"], "charm": []}
const SLOT_NAMES := {"helm": "Helm", "amulet": "Amulet", "armor": "Armor", "mainhand": "Weapon", "offhand": "Shield",
	"gloves": "Gloves", "belt": "Belt", "boots": "Boots", "ring1": "Ring", "ring2": "Ring"}
const TYPE_NAMES := {"weapon": "Weapon", "shield": "Shield", "armor": "Body Armor", "helm": "Helm", "gloves": "Gloves",
	"belt": "Belt", "boots": "Boots", "amulet": "Amulet", "ring": "Ring", "charm": "Charm"}
const DROP_WEIGHTS := {"weapon": 18, "shield": 8, "armor": 10, "helm": 9, "gloves": 7, "belt": 6, "boots": 7, "amulet": 3, "ring": 5, "charm": 4}

## lvl: lowest item level it drops at. str/dex: requirements. w x h: size in the pack.
## look: which hero layer shows it. art: how its icon is drawn. spd: attack time factor.
const BASES := {
	"weapon": [
		{"n": "Short Sword", "lvl": 1, "dmg": [2, 7], "spd": 1.0, "str": 0, "dex": 0, "w": 1, "h": 3, "look": "weapon_sword", "art": "sword", "tint": Color(0.75, 0.76, 0.8)},
		{"n": "Hand Axe", "lvl": 1, "dmg": [3, 6], "spd": 1.0, "str": 0, "dex": 0, "w": 1, "h": 3, "look": "weapon_axe", "art": "axe", "tint": Color(0.7, 0.7, 0.72)},
		{"n": "Club", "lvl": 1, "dmg": [1, 6], "spd": 0.95, "str": 0, "dex": 0, "w": 1, "h": 3, "look": "weapon_mace", "art": "club", "tint": Color(0.55, 0.42, 0.3)},
		{"n": "Scimitar", "lvl": 3, "dmg": [2, 6], "spd": 0.85, "str": 0, "dex": 21, "w": 1, "h": 3, "look": "weapon_sword", "art": "sword", "tint": Color(0.8, 0.78, 0.72)},
		{"n": "Mace", "lvl": 4, "dmg": [3, 10], "spd": 1.0, "str": 27, "dex": 0, "w": 1, "h": 3, "look": "weapon_mace", "art": "mace", "tint": Color(0.68, 0.68, 0.7)},
		{"n": "Axe", "lvl": 5, "dmg": [4, 11], "spd": 1.0, "str": 32, "dex": 0, "w": 2, "h": 3, "look": "weapon_axe", "art": "axe", "tint": Color(0.66, 0.66, 0.68)},
		{"n": "Sabre", "lvl": 6, "dmg": [3, 8], "spd": 0.9, "str": 25, "dex": 25, "w": 1, "h": 3, "look": "weapon_sword", "art": "sword", "tint": Color(0.8, 0.8, 0.84)},
		{"n": "Spiked Club", "lvl": 7, "dmg": [5, 8], "spd": 0.95, "str": 0, "dex": 0, "w": 1, "h": 3, "look": "weapon_mace", "art": "club", "tint": Color(0.5, 0.38, 0.26)},
		{"n": "Morning Star", "lvl": 10, "dmg": [7, 16], "spd": 1.05, "str": 36, "dex": 0, "w": 1, "h": 3, "look": "weapon_mace", "art": "mace", "tint": Color(0.62, 0.62, 0.66)},
		{"n": "Falchion", "lvl": 11, "dmg": [9, 17], "spd": 1.0, "str": 33, "dex": 0, "w": 1, "h": 3, "look": "weapon_sword", "art": "sword", "tint": Color(0.78, 0.78, 0.8)},
		{"n": "Double Axe", "lvl": 13, "dmg": [5, 13], "spd": 0.95, "str": 43, "dex": 0, "w": 2, "h": 3, "look": "weapon_axe", "art": "axe", "tint": Color(0.64, 0.64, 0.68)},
		{"n": "Broad Sword", "lvl": 15, "dmg": [7, 14], "spd": 0.95, "str": 48, "dex": 0, "w": 2, "h": 3, "look": "weapon_sword", "art": "sword", "tint": Color(0.82, 0.82, 0.86)},
		{"n": "Military Pick", "lvl": 17, "dmg": [7, 11], "spd": 0.85, "str": 49, "dex": 33, "w": 2, "h": 3, "look": "weapon_axe", "art": "pick", "tint": Color(0.6, 0.6, 0.64)},
		{"n": "Flail", "lvl": 19, "dmg": [1, 24], "spd": 1.0, "str": 41, "dex": 35, "w": 2, "h": 3, "look": "weapon_mace", "art": "flail", "tint": Color(0.6, 0.6, 0.62)},
		{"n": "Long Sword", "lvl": 20, "dmg": [3, 19], "spd": 0.95, "str": 55, "dex": 39, "w": 2, "h": 3, "look": "weapon_sword", "art": "sword", "tint": Color(0.86, 0.86, 0.9)},
		{"n": "War Axe", "lvl": 22, "dmg": [10, 18], "spd": 1.0, "str": 67, "dex": 0, "w": 2, "h": 3, "look": "weapon_axe", "art": "axe", "tint": Color(0.66, 0.64, 0.62)},
		{"n": "War Hammer", "lvl": 25, "dmg": [19, 29], "spd": 1.15, "str": 53, "dex": 0, "w": 2, "h": 3, "look": "weapon_mace", "art": "hammer", "tint": Color(0.6, 0.6, 0.62)},
	],
	"shield": [
		{"n": "Buckler", "lvl": 1, "def": [4, 6], "block": 25, "str": 12, "w": 2, "h": 2, "look": "shield_buckler", "art": "round", "tint": Color(0.6, 0.45, 0.3)},
		{"n": "Small Shield", "lvl": 5, "def": [8, 10], "block": 30, "str": 22, "w": 2, "h": 2, "look": "shield_buckler", "art": "round", "tint": Color(0.55, 0.45, 0.35)},
		{"n": "Large Shield", "lvl": 11, "def": [12, 14], "block": 37, "str": 34, "w": 2, "h": 3, "look": "shield_kite", "art": "heater", "tint": Color(0.5, 0.42, 0.34)},
		{"n": "Kite Shield", "lvl": 15, "def": [16, 18], "block": 42, "str": 47, "w": 2, "h": 3, "look": "shield_kite", "art": "kite", "tint": Color(0.62, 0.62, 0.66)},
		{"n": "Gothic Shield", "lvl": 22, "def": [30, 35], "block": 46, "str": 60, "w": 2, "h": 3, "look": "shield_kite", "art": "tower", "tint": Color(0.68, 0.68, 0.72)},
	],
	"armor": [
		{"n": "Quilted Armor", "lvl": 1, "def": [8, 11], "str": 12, "w": 2, "h": 3, "look": "armor_light", "art": "quilted", "tint": Color(0.62, 0.56, 0.45)},
		{"n": "Leather Armor", "lvl": 3, "def": [14, 17], "str": 15, "w": 2, "h": 3, "look": "armor_light", "art": "leather", "tint": Color(0.5, 0.36, 0.24)},
		{"n": "Hard Leather Armor", "lvl": 5, "def": [21, 24], "str": 20, "w": 2, "h": 3, "look": "armor_light", "art": "leather", "tint": Color(0.42, 0.3, 0.2)},
		{"n": "Studded Leather", "lvl": 8, "def": [32, 35], "str": 27, "w": 2, "h": 3, "look": "armor_medium", "art": "studded", "tint": Color(0.48, 0.38, 0.28)},
		{"n": "Ring Mail", "lvl": 11, "def": [45, 48], "str": 36, "w": 2, "h": 3, "look": "armor_medium", "art": "mail", "tint": Color(0.6, 0.62, 0.66)},
		{"n": "Scale Mail", "lvl": 13, "def": [57, 60], "str": 44, "w": 2, "h": 3, "look": "armor_medium", "art": "scale", "tint": Color(0.55, 0.6, 0.55)},
		{"n": "Breast Plate", "lvl": 16, "def": [65, 68], "str": 30, "w": 2, "h": 3, "look": "armor_heavy", "art": "plate", "tint": Color(0.7, 0.7, 0.74)},
		{"n": "Chain Mail", "lvl": 18, "def": [72, 75], "str": 48, "w": 2, "h": 3, "look": "armor_medium", "art": "mail", "tint": Color(0.68, 0.7, 0.74)},
		{"n": "Splint Mail", "lvl": 21, "def": [90, 95], "str": 51, "w": 2, "h": 3, "look": "armor_heavy", "art": "plate", "tint": Color(0.6, 0.6, 0.64)},
		{"n": "Plate Mail", "lvl": 24, "def": [108, 116], "str": 65, "w": 2, "h": 3, "look": "armor_heavy", "art": "plate", "tint": Color(0.78, 0.78, 0.82)},
	],
	"helm": [
		{"n": "Cap", "lvl": 1, "def": [3, 5], "str": 0, "w": 2, "h": 2, "look": "helm_hood", "art": "hood", "tint": Color(0.55, 0.45, 0.35)},
		{"n": "Skull Cap", "lvl": 5, "def": [8, 11], "str": 15, "w": 2, "h": 2, "look": "helm_cap", "art": "skullcap", "tint": Color(0.65, 0.66, 0.7)},
		{"n": "Helm", "lvl": 11, "def": [15, 18], "str": 26, "w": 2, "h": 2, "look": "helm_cap", "art": "nasal", "tint": Color(0.7, 0.7, 0.74)},
		{"n": "Full Helm", "lvl": 15, "def": [23, 26], "str": 41, "w": 2, "h": 2, "look": "helm_great", "art": "full", "tint": Color(0.66, 0.66, 0.7)},
		{"n": "Crown", "lvl": 20, "def": [25, 45], "str": 55, "w": 2, "h": 2, "look": "helm_great", "art": "crown", "tint": Color(0.85, 0.7, 0.35)},
		{"n": "Great Helm", "lvl": 23, "def": [30, 35], "str": 63, "w": 2, "h": 2, "look": "helm_great", "art": "full", "tint": Color(0.74, 0.74, 0.78)},
	],
	"gloves": [
		{"n": "Leather Gloves", "lvl": 1, "def": [2, 3], "str": 0, "w": 2, "h": 2, "art": "gloves", "tint": Color(0.5, 0.36, 0.24)},
		{"n": "Heavy Gloves", "lvl": 7, "def": [5, 6], "str": 0, "w": 2, "h": 2, "art": "gloves", "tint": Color(0.4, 0.3, 0.22)},
		{"n": "Chain Gloves", "lvl": 12, "def": [8, 9], "str": 25, "w": 2, "h": 2, "art": "gauntlets", "tint": Color(0.62, 0.64, 0.68)},
		{"n": "Gauntlets", "lvl": 20, "def": [12, 15], "str": 60, "w": 2, "h": 2, "art": "gauntlets", "tint": Color(0.74, 0.74, 0.78)},
	],
	"belt": [
		{"n": "Sash", "lvl": 1, "def": [2, 2], "str": 0, "potions": 4, "w": 2, "h": 1, "art": "sash", "tint": Color(0.55, 0.4, 0.3)},
		{"n": "Light Belt", "lvl": 6, "def": [3, 3], "str": 0, "potions": 5, "w": 2, "h": 1, "art": "belt", "tint": Color(0.5, 0.36, 0.24)},
		{"n": "Belt", "lvl": 12, "def": [5, 5], "str": 25, "potions": 6, "w": 2, "h": 1, "art": "belt", "tint": Color(0.42, 0.3, 0.2)},
		{"n": "Plated Belt", "lvl": 20, "def": [8, 11], "str": 60, "potions": 8, "w": 2, "h": 1, "art": "plated_belt", "tint": Color(0.66, 0.66, 0.7)},
	],
	"boots": [
		{"n": "Boots", "lvl": 1, "def": [2, 3], "str": 0, "w": 2, "h": 2, "art": "boots", "tint": Color(0.5, 0.36, 0.24)},
		{"n": "Heavy Boots", "lvl": 7, "def": [5, 6], "str": 18, "w": 2, "h": 2, "art": "boots", "tint": Color(0.38, 0.28, 0.2)},
		{"n": "Chain Boots", "lvl": 12, "def": [8, 9], "str": 30, "w": 2, "h": 2, "art": "greaves", "tint": Color(0.62, 0.64, 0.68)},
		{"n": "Greaves", "lvl": 21, "def": [12, 15], "str": 70, "w": 2, "h": 2, "art": "greaves", "tint": Color(0.74, 0.74, 0.78)},
	],
	"amulet": [{"n": "Amulet", "lvl": 1, "w": 1, "h": 1, "art": "amulet", "tint": Color(0.85, 0.7, 0.35)}],
	"ring": [{"n": "Ring", "lvl": 1, "w": 1, "h": 1, "art": "ring", "tint": Color(0.85, 0.72, 0.4)}],
	"charm": [
		{"n": "Small Charm", "lvl": 1, "w": 1, "h": 1, "art": "charm_small", "power": 1.0, "tint": Color(0.6, 0.55, 0.75)},
		{"n": "Large Charm", "lvl": 6, "w": 1, "h": 2, "art": "charm_large", "power": 1.8, "tint": Color(0.55, 0.65, 0.6)},
		{"n": "Grand Charm", "lvl": 12, "w": 1, "h": 3, "art": "charm_grand", "power": 2.6, "tint": Color(0.7, 0.55, 0.45)},
	],
}

const WEAPON := ["weapon"]
const ARMORS := ["armor", "helm", "shield", "gloves", "belt", "boots"]
const JEWELRY := ["amulet", "ring"]
## Affix families. Each tier: [item level, min, max, name]. s: item types it can roll on.
const PREFIXES := [
	{"k": "ed", "s": ["weapon"], "t": [[1, 10, 20, "Jagged"], [5, 21, 30, "Deadly"], [11, 31, 40, "Vicious"], [18, 41, 65, "Brutal"]]},
	{"k": "edef", "s": ARMORS, "t": [[1, 10, 20, "Sturdy"], [6, 21, 30, "Strong"], [12, 31, 40, "Glorious"], [19, 41, 60, "Blessed"]]},
	{"k": "ar", "s": ["weapon", "gloves", "ring", "amulet", "helm"], "t": [[1, 10, 20, "Bronze"], [4, 21, 40, "Iron"], [9, 41, 65, "Steel"], [15, 66, 100, "Silver"]]},
	{"k": "mana", "s": ["ring", "amulet", "helm", "weapon", "armor"], "t": [[1, 3, 8, "Lizard's"], [5, 9, 15, "Snake's"], [11, 16, 25, "Serpent's"], [17, 26, 40, "Drake's"]]},
	{"k": "res_fire", "s": ARMORS + JEWELRY, "t": [[1, 5, 10, "Red"], [8, 11, 20, "Crimson"], [15, 21, 30, "Burgundy"]]},
	{"k": "res_cold", "s": ARMORS + JEWELRY, "t": [[1, 5, 10, "Azure"], [8, 11, 20, "Lapis"], [15, 21, 30, "Cobalt"]]},
	{"k": "res_lit", "s": ARMORS + JEWELRY, "t": [[1, 5, 10, "Ocher"], [8, 11, 20, "Tangerine"], [15, 21, 30, "Coral"]]},
	{"k": "res_pois", "s": ARMORS + JEWELRY, "t": [[1, 5, 10, "Beryl"], [8, 11, 20, "Jade"], [15, 21, 30, "Viridian"]]},
	{"k": "res_all", "s": ["shield", "armor", "amulet", "ring"], "t": [[10, 4, 8, "Shimmering"], [18, 9, 15, "Rainbow"]]},
	{"k": "spell", "s": ["weapon", "helm", "amulet", "ring"], "t": [[2, 8, 15, "Smoldering"], [9, 16, 25, "Burning"], [17, 26, 40, "Infernal"]]},
	{"k": "mf", "s": ["helm", "amulet", "ring", "gloves", "boots"], "t": [[4, 5, 10, "Lucky"], [14, 11, 20, "Fortuitous"]]},
	{"k": "skills", "s": ["amulet", "helm", "weapon"], "t": [[12, 1, 1, "Planeswalker's"], [24, 2, 2, "Archmage's"]]},
	{"k": "def", "s": ARMORS, "t": [[1, 2, 6, "Hard"], [7, 7, 15, "Reinforced"], [16, 16, 30, "Ironclad"]]},
]
const SUFFIXES := [
	{"k": "str", "s": ["weapon", "armor", "helm", "gloves", "belt", "ring", "amulet"], "t": [[1, 1, 2, "of Strength"], [5, 3, 5, "of Might"], [11, 6, 9, "of the Ox"], [18, 10, 15, "of the Giant"]]},
	{"k": "dex", "s": ["weapon", "gloves", "boots", "ring", "amulet", "helm"], "t": [[1, 1, 2, "of Dexterity"], [5, 3, 5, "of Skill"], [11, 6, 9, "of Accuracy"], [18, 10, 15, "of Precision"]]},
	{"k": "vit", "s": ["armor", "shield", "belt", "ring", "amulet", "helm"], "t": [[1, 1, 2, "of Vigor"], [5, 3, 5, "of Vitality"], [11, 6, 9, "of Stamina"], [18, 10, 15, "of the Titan"]]},
	{"k": "ene", "s": ["helm", "ring", "amulet", "weapon", "armor"], "t": [[1, 1, 2, "of Energy"], [5, 3, 5, "of the Mind"], [11, 6, 9, "of Brilliance"], [18, 10, 15, "of Sorcery"]]},
	{"k": "life", "s": ARMORS + JEWELRY, "t": [[1, 1, 5, "of the Jackal"], [5, 6, 10, "of the Fox"], [11, 11, 20, "of the Wolf"], [17, 21, 30, "of the Tiger"], [24, 31, 40, "of the Mammoth"]]},
	{"k": "maxd", "s": ["weapon", "gloves", "ring"], "t": [[1, 1, 2, "of Maiming"], [7, 3, 5, "of Butchery"], [15, 6, 9, "of Carnage"]]},
	{"k": "fdmg", "s": ["weapon", "gloves", "ring"], "t": [[3, 3, 6, "of Flame"], [10, 7, 14, "of Fire"], [18, 15, 25, "of Burning"]]},
	{"k": "cdmg", "s": ["weapon", "gloves"], "t": [[4, 2, 4, "of Frost"], [12, 5, 9, "of Icicle"], [20, 10, 16, "of Glacier"]]},
	{"k": "ldmg", "s": ["weapon", "amulet"], "t": [[4, 5, 10, "of Shock"], [12, 11, 20, "of Lightning"], [20, 21, 35, "of Thunder"]]},
	{"k": "leech", "s": ["weapon", "ring", "gloves", "amulet"], "t": [[4, 2, 4, "of the Leech"], [14, 5, 7, "of the Locust"]]},
	{"k": "mleech", "s": ["weapon", "ring", "amulet"], "t": [[4, 2, 4, "of the Bat"], [14, 5, 7, "of the Vampire"]]},
	{"k": "ias", "s": ["weapon", "gloves", "ring"], "t": [[3, 10, 10, "of Readiness"], [9, 20, 20, "of Alacrity"], [16, 30, 30, "of Swiftness"]]},
	{"k": "frw", "s": ["boots"], "t": [[1, 10, 10, "of Pacing"], [8, 20, 20, "of Haste"], [16, 30, 30, "of Speed"]]},
	{"k": "block", "s": ["shield"], "t": [[3, 10, 10, "of Blocking"], [12, 20, 20, "of Deflecting"]]},
	{"k": "dr", "s": ["armor", "shield", "helm", "belt"], "t": [[5, 1, 2, "of Protection"], [13, 3, 4, "of Absorption"], [21, 5, 7, "of Guarding"]]},
	{"k": "thorns", "s": ["armor", "shield"], "t": [[3, 1, 3, "of Spikes"], [10, 4, 8, "of Thorns"], [18, 9, 15, "of Bramble"]]},
	{"k": "regen", "s": ["armor", "helm", "ring", "amulet", "belt"], "t": [[4, 1, 2, "of Regeneration"], [13, 3, 5, "of Regrowth"]]},
	{"k": "gold", "s": ["helm", "gloves", "ring", "amulet", "boots"], "t": [[1, 10, 30, "of Greed"], [10, 31, 60, "of Avarice"]]},
]
## Charms take smaller versions of a few affixes, scaled by charm size.
const CHARM_AFFIXES := [
	{"k": "life", "a": 3, "b": 8, "pre": "Robust", "suf": "of Vita"},
	{"k": "mana", "a": 3, "b": 8, "pre": "Lizard's", "suf": "of the Well"},
	{"k": "ar", "a": 6, "b": 15, "pre": "Bronze", "suf": "of Aim"},
	{"k": "maxd", "a": 1, "b": 2, "pre": "Fine", "suf": "of Edges"},
	{"k": "res_fire", "a": 3, "b": 6, "pre": "Red", "suf": "of Embers"},
	{"k": "res_cold", "a": 3, "b": 6, "pre": "Azure", "suf": "of Frostbite"},
	{"k": "res_lit", "a": 3, "b": 6, "pre": "Ocher", "suf": "of Sparks"},
	{"k": "res_pois", "a": 3, "b": 6, "pre": "Beryl", "suf": "of Antidotes"},
	{"k": "str", "a": 1, "b": 2, "pre": "Burly", "suf": "of Strength"},
	{"k": "dex", "a": 1, "b": 2, "pre": "Nimble", "suf": "of Dexterity"},
	{"k": "mf", "a": 2, "b": 5, "pre": "Lucky", "suf": "of Good Luck"},
	{"k": "frw", "a": 2, "b": 3, "pre": "Swift", "suf": "of Inertia"},
	{"k": "fdmg", "a": 1, "b": 4, "pre": "Hot", "suf": "of Flame"},
]

const MOD_TEXT := {
	"str": "+%d to Strength", "dex": "+%d to Dexterity", "vit": "+%d to Vitality", "ene": "+%d to Energy",
	"life": "+%d to Life", "mana": "+%d to Mana", "ed": "+%d%% Enhanced Damage", "edef": "+%d%% Enhanced Defense",
	"ar": "+%d to Attack Rating", "def": "+%d Defense", "maxd": "+%d to Maximum Damage",
	"fdmg": "Adds fire damage up to %d", "cdmg": "Adds cold damage up to %d (chills)", "ldmg": "Adds 1-%d lightning damage",
	"res_fire": "Fire Resist +%d%%", "res_cold": "Cold Resist +%d%%", "res_lit": "Lightning Resist +%d%%",
	"res_pois": "Poison Resist +%d%%", "res_all": "All Resistances +%d", "spell": "+%d%% Spell Damage", "skills": "+%d to All Skills",
	"mf": "%d%% Better Chance of Getting Magic Items", "gold": "%d%% Extra Gold from Monsters",
	"leech": "%d%% Life stolen per hit", "mleech": "%d%% Mana stolen per hit", "ias": "+%d%% Increased Attack Speed",
	"frw": "+%d%% Faster Run/Walk", "block": "+%d%% Increased Chance of Blocking", "dr": "Damage Reduced by %d",
	"thorns": "Attacker Takes Damage of %d", "regen": "Replenish Life +%d", "all": "+%d to all Attributes",
}

const UNIQUES := [
	{"n": "Lamplighter", "type": "weapon", "base": "Short Sword", "lvl": 2, "tint": Color(1.0, 0.75, 0.45), "mods": {"ed": 45, "fdmg": 6, "life": 10, "ar": 25}},
	{"n": "Gravecutter", "type": "weapon", "base": "Hand Axe", "lvl": 5, "tint": Color(0.55, 0.75, 0.6), "mods": {"ed": 60, "ar": 40, "leech": 5, "str": 5}},
	{"n": "Cinderbrand", "type": "weapon", "base": "Falchion", "lvl": 11, "tint": Color(1.0, 0.5, 0.3), "mods": {"ed": 70, "fdmg": 14, "spell": 30, "leech": 4}},
	{"n": "Ossuary Bell", "type": "weapon", "base": "Morning Star", "lvl": 14, "tint": Color(0.9, 0.88, 0.75), "mods": {"ed": 90, "life": 25, "ias": 20, "res_cold": 20}},
	{"n": "Bark of the Old Wood", "type": "shield", "base": "Buckler", "lvl": 4, "tint": Color(0.45, 0.6, 0.35), "mods": {"edef": 60, "dr": 3, "thorns": 8, "vit": 5}},
	{"n": "Widow's Door", "type": "shield", "base": "Kite Shield", "lvl": 16, "tint": Color(0.45, 0.4, 0.6), "mods": {"edef": 80, "block": 15, "res_all": 15, "life": 20}},
	{"n": "Mantle of the Last Lamp", "type": "armor", "base": "Studded Leather", "lvl": 9, "tint": Color(0.75, 0.55, 0.3), "mods": {"edef": 90, "life": 40, "res_fire": 25, "regen": 4}},
	{"n": "Rimeplate", "type": "armor", "base": "Breast Plate", "lvl": 17, "tint": Color(0.6, 0.8, 0.95), "mods": {"edef": 80, "res_cold": 40, "dr": 6, "str": 10}},
	{"n": "Gnasher's Skull", "type": "helm", "base": "Skull Cap", "lvl": 6, "tint": Color(0.85, 0.8, 0.65), "mods": {"edef": 50, "leech": 4, "ar": 30, "str": 4}},
	{"n": "The Hollow Crown", "type": "helm", "base": "Crown", "lvl": 20, "tint": Color(0.7, 0.6, 0.9), "mods": {"edef": 70, "mana": 40, "skills": 1, "ene": 10}},
	{"n": "Grip of Embers", "type": "gloves", "base": "Heavy Gloves", "lvl": 8, "tint": Color(0.9, 0.4, 0.2), "mods": {"edef": 60, "fdmg": 5, "ias": 15, "dex": 6}},
	{"n": "Rope of the Hanged", "type": "belt", "base": "Light Belt", "lvl": 7, "tint": Color(0.55, 0.5, 0.4), "mods": {"edef": 50, "life": 25, "res_pois": 30, "regen": 2}},
	{"n": "Mirewalkers", "type": "boots", "base": "Heavy Boots", "lvl": 8, "tint": Color(0.35, 0.45, 0.3), "mods": {"edef": 60, "frw": 30, "res_pois": 25, "dex": 5}},
	{"n": "Eye of the Mire", "type": "amulet", "base": "Amulet", "lvl": 10, "tint": Color(0.5, 0.8, 1.0), "mods": {"res_all": 15, "mf": 25, "life": 20, "ene": 8}},
	{"n": "Thornloop", "type": "ring", "base": "Ring", "lvl": 6, "tint": Color(0.6, 0.75, 0.4), "mods": {"ias": 15, "leech": 5, "ed": 15, "thorns": 5}},
	{"n": "Widow's Ember", "type": "ring", "base": "Ring", "lvl": 9, "tint": Color(1.0, 0.45, 0.35), "mods": {"spell": 30, "mana": 25, "mf": 15, "res_fire": 20}},
]

const RARE_FIRST := ["Grim", "Dusk", "Bone", "Storm", "Hollow", "Blood", "Ash", "Wraith", "Raven", "Gloom", "Pale", "Cinder", "Doom", "Rune", "Viper", "Shadow"]
const RARE_SECOND := {
	"weapon": ["Fang", "Bite", "Edge", "Reaver", "Song", "Mercy", "Spike", "Wrack"],
	"shield": ["Wall", "Ward", "Guard", "Bulwark", "Aegis"],
	"armor": ["Shroud", "Carapace", "Hide", "Ward", "Vestment", "Shell"],
	"helm": ["Visage", "Brow", "Crest", "Mask", "Halo", "Horn"],
	"gloves": ["Grip", "Fist", "Hand", "Claw", "Clutch"],
	"belt": ["Coil", "Lash", "Strap", "Cord", "Wrap"],
	"boots": ["Stride", "Track", "Trail", "March", "Spur"],
	"amulet": ["Heart", "Eye", "Star", "Torc", "Talisman"],
	"ring": ["Loop", "Band", "Coil", "Eye", "Knot"],
}


static func base_by_name(type: String, n: String) -> Dictionary:
	for b in BASES[type]:
		if b.n == n:
			return b
	return BASES[type][0]


static func pick_type() -> String:
	var total := 0
	for t in DROP_WEIGHTS:
		total += DROP_WEIGHTS[t]
	var r := randi() % total
	for t in DROP_WEIGHTS:
		r -= DROP_WEIGHTS[t]
		if r < 0:
			return t
	return "weapon"


## Rarity roll; mf is the hero's magic find, boost comes from champions and bosses.
static func roll_rarity(boost: float, mf := 0) -> String:
	var m := boost * (1.0 + mf / 100.0)
	var r := randf()
	if r < 0.012 * m:
		return "unique"
	if r < 0.075 * m:
		return "rare"
	if r < 0.36 * minf(m, 2.2):
		return "magic"
	return "normal"


static func _jitter(c: Color, amount: float) -> Color:
	var h := c.h + randf_range(-amount, amount) * 0.5
	return Color.from_hsv(fposmod(h, 1.0), clampf(c.s * randf_range(0.7, 1.4), 0.0, 1.0), clampf(c.v * randf_range(0.82, 1.15), 0.0, 1.0))


static func _new(type: String, b: Dictionary, ilvl: int) -> Dictionary:
	var it := {"type": type, "base": b.n, "name": b.n, "rarity": "normal", "ilvl": ilvl,
		"w": b.w, "h": b.h, "art": b.art, "look": b.get("look", type), "tint": _jitter(b.tint, 0.15), "seed": randi(),
		"dmg": (b.dmg as Array).duplicate() if b.has("dmg") else [], "spd": b.get("spd", 1.0),
		"def": randi_range(b.def[0], b.def[1]) if b.has("def") else 0, "block": b.get("block", 0),
		"potions": b.get("potions", 0), "req_lvl": 1, "req_str": b.get("str", 0), "req_dex": b.get("dex", 0),
		"mods": {}, "value": 0}
	if type == "charm":
		it.power = b.power
	return it


## A random item of `type` with item level ilvl.
static func make(type: String, rarity: String, ilvl: int) -> Dictionary:
	if type in ["ring", "amulet", "charm"] and rarity == "normal":
		rarity = "magic"
	if type == "charm" and rarity in ["rare", "unique"]:
		rarity = "magic"
	if rarity == "unique":
		var pool_u := UNIQUES.filter(func(u): return u.type == type and u.lvl <= ilvl + 3)
		if not pool_u.is_empty():
			return _unique(pool_u.pick_random())
		rarity = "rare"
	var pool: Array = BASES[type].filter(func(b): return b.lvl <= ilvl)
	if pool.is_empty():
		pool = [BASES[type][0]]
	# favour bases near the item level
	pool.sort_custom(func(a, b): return a.lvl > b.lvl)
	var b: Dictionary = pool[mini(pool.size() - 1, int(pow(randf(), 1.8) * pool.size()))]
	var it := _new(type, b, ilvl)
	it.req_lvl = maxi(1, b.lvl - 2)
	it.rarity = rarity
	if type == "charm":
		_charm(it)
	elif rarity == "magic":
		var pre := randf() < 0.6
		var suf := not pre or randf() < 0.5
		var names := ["", "", ""]
		if pre:
			names[0] = _roll_affix(it, PREFIXES)
		if suf:
			names[2] = _roll_affix(it, SUFFIXES)
		names[1] = b.n
		it.name = _join(names)
	elif rarity == "rare":
		var n := randi_range(3, 5)
		var pres := 0
		var sufs := 0
		for i in n * 3:
			if it.mods.size() >= n:
				break
			if randf() < 0.5 and pres < 3:
				if _roll_affix(it, PREFIXES) != "":
					pres += 1
			elif sufs < 3:
				if _roll_affix(it, SUFFIXES) != "":
					sufs += 1
		it.name = "%s %s" % [RARE_FIRST.pick_random(), RARE_SECOND[type].pick_random()]
	_apply_edef(it)
	it.value = _value(it, b)
	return it


static func _unique(u: Dictionary) -> Dictionary:
	var b := base_by_name(u.type, u.base)
	var it := _new(u.type, b, u.lvl)
	it.rarity = "unique"
	it.name = u.n
	it.tint = u.tint
	it.mods = (u.mods as Dictionary).duplicate()
	it.req_lvl = maxi(u.lvl, b.lvl)
	_apply_edef(it)
	it.value = _value(it, b) * 2
	return it


## Rolls one affix of a family that fits this item and isn't on it yet. Returns its name.
static func _roll_affix(it: Dictionary, table: Array) -> String:
	var fits := table.filter(func(a): return it.type in a.s and not it.mods.has(a.k) and a.t[0][0] <= it.ilvl)
	if fits.is_empty():
		return ""
	var a: Dictionary = fits.pick_random()
	var tiers: Array = a.t.filter(func(t): return t[0] <= it.ilvl)
	# the best tiers are the rarest
	var ti := tiers.size() - 1 - mini(tiers.size() - 1, int(pow(randf(), 0.6) * tiers.size()))
	var t: Array = tiers[ti]
	it.mods[a.k] = randi_range(t[1], t[2])
	it.req_lvl = maxi(it.req_lvl, int(t[0] * 0.85))
	return t[3]


static func _charm(it: Dictionary) -> void:
	var p: float = it.power
	var names := ["", it.base, ""]
	var n := 1 if randf() < 0.55 else 2
	var picks := CHARM_AFFIXES.duplicate()
	picks.shuffle()
	for i in n:
		var a: Dictionary = picks[i]
		var lvl_scale: float = 1.0 + it.ilvl / 12.0
		it.mods[a.k] = maxi(1, roundi(randf_range(a.a, a.b) * p * lvl_scale))
		names[0 if i == 0 else 2] = a.pre if i == 0 else a.suf
	it.req_lvl = maxi(1, int(it.ilvl * 0.7))
	it.name = _join(names)


static func _apply_edef(it: Dictionary) -> void:
	if it.def > 0 and it.mods.has("edef"):
		it.def = roundi(it.def * (1.0 + it.mods.edef / 100.0))
	if it.mods.has("def"):
		it.def += it.mods.def


static func _value(it: Dictionary, b: Dictionary) -> int:
	var v: float = 4.0 + b.lvl * 3.0 + it.mods.size() * 6.0
	return roundi(v * {"normal": 1.0, "magic": 2.0, "rare": 4.0, "unique": 6.0}[it.rarity])


static func _join(parts: Array) -> String:
	return " ".join(PackedStringArray(parts.filter(func(p): return p != "")))


## Damage this weapon shows with its own Enhanced Damage and +max damage applied.
static func weapon_damage(it: Dictionary) -> Array:
	if it.dmg.is_empty():
		return []
	var ed: float = 1.0 + it.mods.get("ed", 0) / 100.0
	return [floori(it.dmg[0] * ed), floori(it.dmg[1] * ed) + it.mods.get("maxd", 0)]


## BBCode description for tooltips. With a hero, unmet requirements turn red.
static func describe(it: Dictionary, p = null) -> String:
	var col: Color = Game.RARITY_COLORS[it.rarity]
	var s := "[center][b][color=#%s]%s[/color][/b]\n" % [col.to_html(false), it.name]
	if it.rarity in ["rare", "unique"]:
		s += "[color=#%s]%s[/color]\n" % [col.to_html(false), it.base]
	var blue := "8597ff"
	if not it.dmg.is_empty():
		var wd := weapon_damage(it)
		var changed: bool = wd[0] != it.dmg[0] or wd[1] != it.dmg[1]
		s += "Damage: [color=#%s]%d to %d[/color]\n" % [blue if changed else "ddd3c0", wd[0], wd[1]]
		var speed: String = "Fast" if it.spd < 0.95 else ("Slow" if it.spd > 1.05 else "Normal")
		s += "[color=#8f8575]%s attack speed[/color]\n" % speed
	if it.def > 0:
		s += "Defense: [color=#%s]%d[/color]\n" % [blue if (it.mods.has("edef") or it.mods.has("def")) else "ddd3c0", it.def]
	if it.block > 0:
		s += "Chance to Block: %d%%\n" % it.block
	if it.potions > 0:
		s += "Holds %d of each draught\n" % it.potions
	var red := "ff4a4a"
	if it.req_str > 0:
		s += "[color=#%s]Required Strength: %d[/color]\n" % [red if p and p.st.str < it.req_str else "ddd3c0", it.req_str]
	if it.req_dex > 0:
		s += "[color=#%s]Required Dexterity: %d[/color]\n" % [red if p and p.st.dex < it.req_dex else "ddd3c0", it.req_dex]
	if it.req_lvl > 1:
		s += "[color=#%s]Required Level: %d[/color]\n" % [red if p and p.level < it.req_lvl else "ddd3c0", it.req_lvl]
	for k in it.mods:
		if k == "def":
			continue
		s += "[color=#%s]%s[/color]\n" % [blue, MOD_TEXT[k] % it.mods[k]]
	if it.type == "charm":
		s += "[color=#8f8575]Works while carried in the pack[/color]\n"
	s += "[color=#8f8575]%s · item level %d · sells for %d gold[/color][/center]" % [TYPE_NAMES[it.type], it.ilvl, it.value]
	return s
