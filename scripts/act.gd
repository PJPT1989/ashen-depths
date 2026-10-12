class_name Act
extends RefCounted
## Act I, the black act: the swamp town and the eight areas that follow it, always in the same
## order and with the same names. Each run generates every area's shape from its own random seed.
## Monsters are Magic: The Gathering creatures; sub-bosses and bosses are its legends.
##
## kind: "town", "open" (wide outdoor ground) or "dungeon" (caves, crypts, buildings).
## rank: the rank of ordinary monsters there; sub-bosses are two ranks above, bosses four.

const AREAS := [
	{"id": "town", "name": "Mirewatch", "kind": "town", "biome": "town", "rank": 0, "size": Vector2i(46, 46)},
	{"id": "moor", "name": "The Blackwater Fen", "kind": "open", "biome": "moor", "rank": 1, "size": Vector2i(96, 120),
		"types": ["scrabbler", "rotling", "gloomhound", "quillback"],
		"boss": {"name": "Ayara, First of Locthwain", "type": "gloomhound"},
		"uniques": ["Marrow-Gnawer", "Ink-Eyes, Servant of Oni", "Horobi, Death's Wail", "Kagemaro, First to Suffer"]},
	{"id": "fields", "name": "Gallows Bog", "kind": "open", "biome": "fields", "rank": 2, "size": Vector2i(110, 110),
		"types": ["rotling", "reaver", "gloomhound", "scrabbler", "spitter"],
		"boss": {"name": "Kalitas, Traitor of Ghet", "type": "reaver"},
		"uniques": ["Josu Vess, Lich Knight", "Ghoulcaller Gisa", "Mikaeus, the Unhallowed", "Rankle, Master of Pranks"]},
	{"id": "cave", "name": "Leechroot Hollow", "kind": "dungeon", "biome": "cave", "rank": 3, "size": Vector2i(76, 76),
		"types": ["scrabbler", "quillback", "spitter", "brute", "hexcaller"],
		"boss": {"name": "Sidisi, Brood Tyrant", "type": "spitter"},
		"uniques": ["Endrek Sahr, Master Breeder", "Seizan, Perverter of Truth", "Kiku, Night's Flower", "Skithiryx, the Blight Dragon"]},
	{"id": "ossuary", "name": "The Drowned Ossuary", "kind": "dungeon", "biome": "crypt", "rank": 4, "size": Vector2i(70, 70),
		"types": ["bonewalker", "bone_archer", "rotling", "wraith", "hexcaller"],
		"boss": {"name": "Lord of Tresserhorn", "type": "bonewalker"},
		"uniques": ["Lim-Dûl the Necromancer", "Chainer, Dementia Master", "Volrath the Fallen", "Gisa, Glorious Resurrector"]},
	{"id": "wood", "name": "Rotwillow Swamp", "kind": "open", "biome": "forest", "rank": 5, "size": Vector2i(110, 110),
		"types": ["thornback", "gloomhound", "reaver", "moonsister", "quillback"],
		"boss": {"name": "Grimgrin, Corpse-Born", "type": "thornback"},
		"uniques": ["Massacre Girl", "Kothophed, Soul Hoarder", "Tergrid, God of Fright", "Baron Sengir"]},
	{"id": "ruins", "name": "Ruins of Graymire", "kind": "open", "biome": "ruins", "rank": 6, "size": Vector2i(110, 110),
		"types": ["reaver", "moonsister", "zealot", "brute", "spitter"],
		"boss": {"name": "Drana, Liberator of Malakir", "type": "moonsister"},
		"uniques": ["Gonti, Lord of Luxury", "Kels, Fight Fixer", "Erebos, God of the Dead", "Demonlord Belzenlok"]},
	{"id": "abbey", "name": "Cathedral of Whispers", "kind": "dungeon", "biome": "abbey", "rank": 7, "size": Vector2i(72, 72),
		"types": ["zealot", "hexcaller", "wraith", "bone_archer", "warden"],
		"boss": {"name": "Ob Nixilis, the Fallen", "type": "hexcaller"},
		"uniques": ["K'rrik, Son of Yawgmoth", "Geth, Lord of the Vault", "Yawgmoth, Thran Physician", "Shirei, Shizo's Caretaker"]},
	{"id": "deep", "name": "The Phyrexian Sanctum", "kind": "dungeon", "biome": "deep", "rank": 8, "size": Vector2i(76, 76),
		"types": ["warden", "wraith", "bonewalker", "brute", "hexcaller", "spitter"],
		"boss": {"name": "Sheoldred, the Apocalypse", "type": "warden", "act_boss": true},
		"uniques": ["Geth, Thane of Contracts", "Glissa Sunslayer", "Xantcha, Sleeper Agent", "Tsabo Tavoc"]},
]

## Look of each biome: ground texture(s), wall texture, colour of the ambient light, tint.
## Act I is the black act: swamps, bogs, crypts.
const BIOMES := {
	"town": {"floor": "bog", "path": "mud", "wall": "wood", "ambient": Color(0.38, 0.37, 0.43), "tint": Color(0.84, 0.86, 0.78), "outdoor": true},
	"moor": {"floor": "bog", "path": "mud", "wall": "rock", "ambient": Color(0.31, 0.34, 0.4), "tint": Color(0.8, 0.84, 0.76), "outdoor": true},
	"fields": {"floor": "heath", "path": "mud", "wall": "wall", "ambient": Color(0.35, 0.32, 0.38), "tint": Color(0.74, 0.74, 0.68), "outdoor": true},
	"forest": {"floor": "bog", "path": "mud", "wall": "rock", "ambient": Color(0.23, 0.28, 0.27), "tint": Color(0.72, 0.8, 0.68), "outdoor": true},
	"ruins": {"floor": "bog", "path": "cobble", "wall": "wall", "ambient": Color(0.31, 0.3, 0.4), "tint": Color(0.8, 0.8, 0.84), "outdoor": true},
	"cave": {"floor": "cave", "wall": "rock", "ambient": Color(0.045, 0.05, 0.04), "tint": Color(0.8, 0.86, 0.72), "outdoor": false},
	"crypt": {"floor": "floor", "wall": "wall", "ambient": Color(0.04, 0.045, 0.05), "tint": Color(0.66, 0.76, 0.68), "outdoor": false},
	"abbey": {"floor": "flags", "wall": "wall", "ambient": Color(0.055, 0.045, 0.065), "tint": Color(0.82, 0.74, 0.84), "outdoor": false},
	"deep": {"floor": "cave", "wall": "wall", "ambient": Color(0.035, 0.025, 0.045), "tint": Color(0.66, 0.6, 0.76), "outdoor": false},
}
## Standing water in the swamps: dark and light end.
const WATER := [Color(0.07, 0.1, 0.08), Color(0.13, 0.17, 0.12)]


static func area(i: int) -> Dictionary:
	return AREAS[i]


static func count() -> int:
	return AREAS.size()


static func biome(i: int) -> Dictionary:
	return BIOMES[AREAS[i].biome]


## Monster level for a rank, as used by the D2 to-hit formula.
static func mlvl(rank: int) -> int:
	return 1 + (rank - 1) * 2


## Unique sub-bosses are legendary creatures, a fixed set per area.
static func unique_name(i: int, k: int) -> String:
	var names: Array = AREAS[i].get("uniques", [])
	return names[k % names.size()] if names.size() > 0 else "Nameless Horror"
