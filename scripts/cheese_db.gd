class_name CheeseDB
extends RefCounted
## Static data for Cheezy Tunes: the ingredient/step tiles and the cheese recipes.
## Pure data — no scene logic here. Referenced statically, e.g. CheeseDB.CHEESES.

## Tile id -> display label + color (placeholder programmer art).
const TILES: Dictionary = {
	"milk":       {"label": "Milk",            "color": Color("f7f3e8")},
	"culture":    {"label": "Starter Culture", "color": Color("c9d6a3")},
	"rennet":     {"label": "Rennet",          "color": Color("d9b38c")},
	"salt":       {"label": "Salt",            "color": Color("e8e8ee")},
	"citric":     {"label": "Citric Acid",     "color": Color("eaf06a")},
	"heat":       {"label": "Heat",            "color": Color("f0945a")},
	"cut_curd":   {"label": "Cut Curd",        "color": Color("bfe3c0")},
	"drain_whey": {"label": "Drain Whey",      "color": Color("a9d8e6")},
	"press":      {"label": "Press",           "color": Color("b8a99a")},
	"stretch":    {"label": "Stretch",         "color": Color("f4d06f")},
	"white_mold": {"label": "White Mold",      "color": Color("fbfbf5")},
	"blue_mold":  {"label": "Blue Mold",       "color": Color("8fa9d6")},
	"brine":      {"label": "Brine",           "color": Color("9fd3d6")},
	"propionic":  {"label": "Propionic Bact.", "color": Color("d6c98f")},
	"age":        {"label": "Age",             "color": Color("c2a86a")},
}

## Each cheese: display name, a short educational hint, and the required tile set.
## `active` controls whether it appears in the prototype's order rotation.
const CHEESES: Array[Dictionary] = [
	{
		"name": "Mozzarella",
		"hint": "Fresh stretched-curd cheese — acidified, then pulled while hot.",
		"recipe": ["milk", "citric", "rennet", "heat", "stretch", "salt"],
		"active": true,
	},
	{
		"name": "Cheddar",
		"hint": "Firm aged cheese — curds are cut, drained and pressed.",
		"recipe": ["milk", "culture", "rennet", "cut_curd", "drain_whey", "salt", "press"],
		"active": true,
	},
	{
		"name": "Brie",
		"hint": "Soft cheese ripened by a bloomy white surface mold.",
		"recipe": ["milk", "culture", "rennet", "drain_whey", "salt", "white_mold"],
		"active": true,
	},
	{
		"name": "Blue Cheese",
		"hint": "Veined cheese cultured with blue Penicillium mold.",
		"recipe": ["milk", "culture", "rennet", "salt", "blue_mold"],
		"active": false,
	},
	{
		"name": "Feta",
		"hint": "Brined curd cheese, cut and cured in salty brine.",
		"recipe": ["milk", "culture", "rennet", "cut_curd", "salt", "brine"],
		"active": false,
	},
	{
		"name": "Swiss",
		"hint": "Aged cheese with eyes (holes) from propionic bacteria.",
		"recipe": ["milk", "culture", "rennet", "propionic", "press", "age"],
		"active": false,
	},
]

## Distractor tiles that are never required by an active recipe — added difficulty.
const DISTRACTORS: PackedStringArray = ["blue_mold", "brine", "propionic", "age"]


## Cost in $ to buy one unit of each ingredient.
const INGREDIENT_PRICES: Dictionary = {
	"milk":       3,
	"culture":    4,
	"rennet":     5,
	"salt":       2,
	"citric":     2,
	"heat":       1,
	"cut_curd":   1,
	"drain_whey": 1,
	"press":      1,
	"stretch":    1,
	"white_mold": 4,
	"blue_mold":  4,
	"brine":      2,
	"propionic":  3,
	"age":        2,
}

## Min/max payout per fulfilled order (rolled at spawn). Keyed by cheese name.
const CHEESE_PAYOUT_RANGE: Dictionary = {
	"Mozzarella":  Vector2i(20, 30),
	"Cheddar":     Vector2i(30, 45),
	"Brie":        Vector2i(25, 40),
	"Blue Cheese": Vector2i(28, 42),
	"Feta":        Vector2i(22, 34),
	"Swiss":       Vector2i(32, 48),
}

## Audio hook (future): each ingredient maps to a musical role in the cheese's tune.
const MUSIC_COMPONENT: Dictionary = {
	"milk":       "bass",
	"culture":    "harmony",
	"rennet":     "lead",
	"salt":       "percussion",
	"citric":     "arpeggio",
	"heat":       "riser",
	"cut_curd":   "stab",
	"drain_whey": "sweep",
	"press":      "kick",
	"stretch":    "glide",
	"white_mold": "pad",
	"blue_mold":  "dissonant_pad",
	"brine":      "shaker",
	"propionic":  "bubble",
	"age":        "sustain",
}

## Audio hook (future): path to the clean chiptune for each cheese. Files not yet shipped.
const CHEESE_TUNE: Dictionary = {
	"Mozzarella":  "res://audio/mozzarella.ogg",
	"Cheddar":     "res://audio/cheddar.ogg",
	"Brie":        "res://audio/brie.ogg",
	"Blue Cheese": "res://audio/blue_cheese.ogg",
	"Feta":        "res://audio/feta.ogg",
	"Swiss":       "res://audio/swiss.ogg",
}

## Cheapest ingredient currently in the price table — used for bankruptcy checks.
static func cheapest_ingredient_price() -> int:
	var lowest := 999
	for price in INGREDIENT_PRICES.values():
		if price < lowest:
			lowest = price
	return lowest


## The cheeses currently in rotation.
static func get_active_cheeses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cheese in CHEESES:
		if cheese.get("active", false):
			result.append(cheese)
	return result


## The tile buttons to display: every tile used by an active recipe, plus a few
## distractors, returned in TILES declaration order for a stable layout.
static func get_tile_pool() -> PackedStringArray:
	var needed := {}
	for cheese in get_active_cheeses():
		for tile_id in cheese["recipe"]:
			needed[tile_id] = true
	for tile_id in DISTRACTORS:
		needed[tile_id] = true
	var pool := PackedStringArray()
	for tile_id in TILES.keys():
		if needed.has(tile_id):
			pool.append(tile_id)
	return pool
