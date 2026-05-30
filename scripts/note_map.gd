class_name NoteMap
extends RefCounted
## Maps ingredient/step tiles to musical notes for a given target recipe.
## Pure data/logic — no scene code. The mapping is contextual: a tile that
## belongs to the target recipe gets a consonant major-pentatonic note (so any
## correct combination auto-harmonizes), while a tile that does NOT belong gets
## a deliberately dissonant off-scale note (m2 / tritone / M7). Milk is the
## tonic and sounds on a soft triangle bass.

# C3 — milk, the root of every recipe. Low enough that the sample pitch-shift
# ratios stay modest (~1.8x–6x), which keeps aliasing down.
const TONIC_MIDI := 48

## Semitone offsets above the tonic for correct (non-milk) tiles.
## Major pentatonic across two octaves; 0 is reserved for the milk tonic.
const PENTATONIC: Array[int] = [2, 4, 7, 9, 12, 14, 16, 19, 21]

## Semitone offsets for wrong tiles: m2, tritone, M7, b9, #11 — all clash
## against the tonic and the pentatonic notes.
const DISSONANT: Array[int] = [1, 6, 11, 13, 18]


## Returns tile_id -> {midi, waveform, correct} for EVERY tile in CheeseDB.TILES,
## evaluated against `recipe` (the target cheese's required tile ids).
## Deterministic: the same recipe always yields the same mapping.
static func build(recipe: Array) -> Dictionary:
	var result: Dictionary = {}
	# stable index for each tile, used to vary which dissonant note wrong tiles get
	var tile_keys: Array = CheeseDB.TILES.keys()
	var penta_index := 0
	for tile_id in tile_keys:
		var info: Dictionary
		if tile_id == "milk":
			info = {"midi": TONIC_MIDI, "waveform": "triangle", "correct": true}
		elif recipe.has(tile_id):
			var offset: int = PENTATONIC[penta_index % PENTATONIC.size()]
			penta_index += 1
			info = {"midi": TONIC_MIDI + offset, "waveform": "square", "correct": true}
		else:
			var idx: int = tile_keys.find(tile_id)
			var offset: int = DISSONANT[idx % DISSONANT.size()]
			info = {"midi": TONIC_MIDI + offset, "waveform": "square", "correct": false}
		result[tile_id] = info
	return result


## Human-readable note name for a MIDI number (e.g. 60 -> "C", 62 -> "D").
static func note_name(midi: int) -> String:
	var names := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return names[midi % 12]
