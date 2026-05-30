class_name CheeseDB
extends RefCounted
## Static data for Cheezy Tunes: the ingredient tiles and the simplified cheese recipes.
## Pure data — no scene logic here. Referenced statically, e.g. CheeseDB.CHEESES.

## Tile id -> display label + color. Completely stripped down to the active ingredients.
const TILES: Dictionary = {
	"milk":     {"label": "Milk",     "color": Color("f7f3e8")},
	"acid":     {"label": "Acid",     "color": Color("eaf06a")},
	"salt":     {"label": "Salt",     "color": Color("e8e8ee")},
	"bacteria": {"label": "Bacteria", "color": Color("c9d6a3")},
	"rennet":   {"label": "Rennet",   "color": Color("d9b38c")},
	"mold":     {"label": "Mold",     "color": Color("8fa9d6")},
	"wine":     {"label": "Wine",     "color": Color("9e2a2b")},
}

## Each cheese mapped exactly to your updated rules.
## Set 'active' to false for cheeses you want to hide until later levels.
const CHEESES: Array[Dictionary] = [
	{
		"name": "Paneer",
		"hint": "Basic unaged cheese made by curdling milk with acid.",
		"recipe": ["milk", "acid"],
		"active": true,
	},
	{
		"name": "Mozzarella",
		"hint": "Fresh curd cheese made simple with milk, acid, and salt.",
		"recipe": ["milk", "acid", "salt"],
		"active": true,
	},
	{
		"name": "Cream Cheese",
		"hint": "Smooth, mild tasting fresh cheese enriched with bacteria.",
		"recipe": ["milk", "salt", "bacteria"],
		"active": true, # Set to false if you want it completely locked out of level 1 rotation
	},
	{
		"name": "Brie",
		"hint": "Soft, creamy surface-ripened cheese.",
		"recipe": ["milk", "salt", "acid", "bacteria"],
		"active": true,
	},
	{
		"name": "Comte",
		"hint": "Hard pressed cheese made with bacteria and rennet.",
		"recipe": ["milk", "bacteria", "rennet", "salt"],
		"active": true,
	},
	{
		"name": "Roquefort",
		"hint": "Intense blue-veined sheep milk cheese containing pungent mold.",
		"recipe": ["milk", "salt", "rennet", "bacteria", "mold"],
		"active": true,
	},
	{
		"name": "Taleggio",
		"hint": "Smelly, wash-rind cheese regularly wiped down with wine.",
		"recipe": ["milk", "bacteria", "rennet", "salt", "wine"],
		"active": true,
	},
]

## Every ingredient is used, so the distractor array is completely empty now.
## Kept as an empty array to prevent the main script loop from breaking.
const DISTRACTORS: PackedStringArray = []


## Adjusted cost parameters in $ for your 7 unique components.
const INGREDIENT_PRICES: Dictionary = {
	"milk":     2,
	"acid":     4,
	"salt":     2,
	"bacteria": 3,
	"rennet":   4,
	"mold":     6,
	"wine":     7,
}

## Scaled reward structures scaled to the structural complexity of each recipe.
const CHEESE_PAYOUT_RANGE: Dictionary = {
	"Paneer":       Vector2i(8, 10),
	"Cream Cheese": Vector2i(8, 12),
	"Comte":        Vector2i(14, 18),
	"Mozzarella":   Vector2i(15, 21),
	"Brie":         Vector2i(21, 29),
	"Roquefort":    Vector2i(23, 31),
	"Taleggio":     Vector2i(25, 33),
	"Mozzarella (Alt)": Vector2i(15, 21),
}

## Updated track layer maps matching the clean tool-pool configuration.
const MUSIC_COMPONENT: Dictionary = {
	"milk":     "bass",
	"acid":     "arpeggio",
	"salt":     "percussion",
	"bacteria": "harmony",
	"rennet":   "lead",
	"mold":     "pad",
	"wine":     "sweep",
}

## Clean audio target hooks for your updated cheese library.
const CHEESE_TUNE: Dictionary = {
	"Paneer":         "res://audio/paneer.ogg",
	"Mozzarella":     "res://audio/mozzarella.ogg",
	"Cream Cheese":   "res://audio/cream_cheese.ogg",
	"Brie":           "res://audio/brie.ogg",
	"Comte":          "res://audio/comte.ogg",
	"Mozzarella (Alt)": "res://audio/mozzarella_alt.ogg",
	"Roquefort":      "res://audio/roquefort.ogg",
	"Taleggio":       "res://audio/taleggio.ogg",
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
