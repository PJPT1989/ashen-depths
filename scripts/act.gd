class_name Act
extends RefCounted
## Act I: the town and the eight areas that follow it, always in the same order and with the
## same names. Each run generates every area's shape from its own random seed.
##
## kind: "town", "open" (wide outdoor ground) or "dungeon" (caves, crypts, buildings).
## rank: the rank of ordinary monsters there; sub-bosses are two ranks above, bosses four.

const AREAS := [
	{"id": "town", "name": "Vell's Hollow", "kind": "town", "biome": "town", "rank": 0, "size": Vector2i(46, 46)},
	{"id": "moor", "name": "The Ashen Moor", "kind": "open", "biome": "moor", "rank": 1, "size": Vector2i(96, 120),
		"types": ["scrabbler", "rotling", "gloomhound", "quillback"],
		"boss": {"name": "Grisk the Gnawer", "type": "gloomhound"}},
	{"id": "fields", "name": "Gallows Fields", "kind": "open", "biome": "fields", "rank": 2, "size": Vector2i(110, 110),
		"types": ["rotling", "reaver", "gloomhound", "scrabbler", "spitter"],
		"boss": {"name": "Hangman Orrel", "type": "reaver"}},
	{"id": "cave", "name": "Hollowroot Cave", "kind": "dungeon", "biome": "cave", "rank": 3, "size": Vector2i(76, 76),
		"types": ["scrabbler", "quillback", "spitter", "brute", "hexcaller"],
		"boss": {"name": "Mother Cinder", "type": "spitter"}},
	{"id": "ossuary", "name": "The Sunken Ossuary", "kind": "dungeon", "biome": "crypt", "rank": 4, "size": Vector2i(70, 70),
		"types": ["bonewalker", "bone_archer", "rotling", "wraith", "hexcaller"],
		"boss": {"name": "Ossric the Unburied", "type": "bonewalker"}},
	{"id": "wood", "name": "Witherwood", "kind": "open", "biome": "forest", "rank": 5, "size": Vector2i(110, 110),
		"types": ["thornback", "gloomhound", "reaver", "moonsister", "quillback"],
		"boss": {"name": "Old Thornhide", "type": "thornback"}},
	{"id": "ruins", "name": "Ruins of Calder", "kind": "open", "biome": "ruins", "rank": 6, "size": Vector2i(110, 110),
		"types": ["reaver", "moonsister", "zealot", "brute", "spitter"],
		"boss": {"name": "The Pale Huntress", "type": "moonsister"}},
	{"id": "abbey", "name": "The Abbey of Vell", "kind": "dungeon", "biome": "abbey", "rank": 7, "size": Vector2i(72, 72),
		"types": ["zealot", "hexcaller", "wraith", "bone_archer", "warden"],
		"boss": {"name": "The Hollow Abbot", "type": "hexcaller"}},
	{"id": "deep", "name": "The Lampless Deep", "kind": "dungeon", "biome": "deep", "rank": 8, "size": Vector2i(76, 76),
		"types": ["warden", "wraith", "bonewalker", "brute", "hexcaller", "spitter"],
		"boss": {"name": "The Lampless King", "type": "warden", "act_boss": true}},
]

## Look of each biome: ground texture(s), wall texture, colour of the ambient light, tint.
const BIOMES := {
	"town": {"floor": "grass", "path": "dirt", "wall": "wood", "ambient": Color(0.44, 0.41, 0.46), "tint": Color(0.86, 0.84, 0.76), "outdoor": true},
	"moor": {"floor": "heath", "path": "dirt", "wall": "rock", "ambient": Color(0.38, 0.38, 0.46), "tint": Color(0.82, 0.82, 0.8), "outdoor": true},
	"fields": {"floor": "grass", "path": "dirt", "wall": "wall", "ambient": Color(0.44, 0.39, 0.36), "tint": Color(0.9, 0.84, 0.7), "outdoor": true},
	"forest": {"floor": "grass", "path": "dirt", "wall": "rock", "ambient": Color(0.27, 0.31, 0.3), "tint": Color(0.74, 0.8, 0.66), "outdoor": true},
	"ruins": {"floor": "heath", "path": "cobble", "wall": "wall", "ambient": Color(0.36, 0.35, 0.43), "tint": Color(0.84, 0.82, 0.86), "outdoor": true},
	"cave": {"floor": "cave", "wall": "rock", "ambient": Color(0.05, 0.045, 0.04), "tint": Color(0.9, 0.82, 0.72), "outdoor": false},
	"crypt": {"floor": "floor", "wall": "wall", "ambient": Color(0.045, 0.04, 0.06), "tint": Color(0.72, 0.78, 0.7), "outdoor": false},
	"abbey": {"floor": "flags", "wall": "wall", "ambient": Color(0.06, 0.05, 0.065), "tint": Color(0.92, 0.82, 0.78), "outdoor": false},
	"deep": {"floor": "cave", "wall": "wall", "ambient": Color(0.035, 0.03, 0.05), "tint": Color(0.72, 0.66, 0.85), "outdoor": false},
}

const UNIQUE_FIRST := ["Bone", "Rot", "Gore", "Ash", "Grim", "Pit", "Blight", "Rust", "Gloom", "Bile", "Dread", "Coal", "Mire", "Spite", "Hollow"]
const UNIQUE_SECOND := ["fang", "maw", "skull", "claw", "gut", "hide", "spine", "eye", "tooth", "heart", "brow", "grin"]
const UNIQUE_EPITHET := ["the Hungry", "the Vile", "the Unclean", "the Cold", "the Gnasher", "the Cruel", "the Wretched", "the Butcher", "the Pale", "the Twisted"]


static func area(i: int) -> Dictionary:
	return AREAS[i]


static func count() -> int:
	return AREAS.size()


static func biome(i: int) -> Dictionary:
	return BIOMES[AREAS[i].biome]


## Monster level for a rank, as used by the D2 to-hit formula.
static func mlvl(rank: int) -> int:
	return 1 + (rank - 1) * 2


static func unique_name() -> String:
	return "%s%s %s" % [UNIQUE_FIRST.pick_random(), UNIQUE_SECOND.pick_random(), UNIQUE_EPITHET.pick_random()]
