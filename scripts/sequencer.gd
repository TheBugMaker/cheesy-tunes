class_name Sequencer
extends Node
## Loops a recipe's riff as a melody and drives a Synth. UI-agnostic and
## reusable: hand it a Synth, load a song, feed it the current selection, and it
## plays. Each step is owned by one ingredient — selected ingredients sound their
## note for its duration, unselected ones rest for that duration, and selected
## WRONG tiles tack an off-key clash onto the tail of the loop until deselected.
## Notes have per-step durations (short/long), so the riff keeps its rhythm.

signal step_advanced(index: int, total: int, sounding: bool)

const WRONG_DUR := 2   # clash note length, in STEP units

var synth: Synth

var _recipe: Array = []
var _recipe_slots: Array[Dictionary] = []   # fixed per song: {tile, midi, waveform, dur}
var _wrong_slots: Array[Dictionary] = []     # dynamic: one per selected non-recipe tile
var _selected: Dictionary = {}               # tile_id -> true (set membership)

var _running := false
var _index := 0
var _accum := 0.0
var _slot_len := 0.0    # seconds the current slot lasts
var _armed := false     # has the current slot been triggered yet?


func _process(delta: float) -> void:
	if not _running:
		return
	var seq := _recipe_slots + _wrong_slots
	if seq.is_empty():
		return
	_index = _index % seq.size()
	if not _armed:
		_play_slot(seq, _index)
		_slot_len = maxf(0.01, seq[_index]["dur"] * Songs.STEP)
		_armed = true
	_accum += delta
	if _accum >= _slot_len:
		_accum -= _slot_len
		_index = (_index + 1) % seq.size()
		_armed = false   # next frame triggers the new slot


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
## Load a recipe + its riff. `phrases` is one phrase per ingredient (recipe order);
## each phrase is {notes, durs} (semitone offsets + STEP-unit lengths). The phrases
## are flattened into per-note slots, each tagged with its owning ingredient — so a
## selected ingredient sounds its whole phrase and an unselected one rests for it.
func load_song(recipe: Array, phrases: Array) -> void:
	_recipe = recipe
	_recipe_slots.clear()
	for i in recipe.size():
		var tile: String = recipe[i]
		var waveform: String = "triangle" if tile == "milk" else "square"
		var phrase: Dictionary = phrases[i] if i < phrases.size() else {}
		var notes: Array = phrase.get("notes", [0])
		var durs: Array = phrase.get("durs", [])
		for j in notes.size():
			_recipe_slots.append({
				"tile": tile,
				"midi": NoteMap.TONIC_MIDI + int(notes[j]),
				"waveform": waveform,
				"dur": int(durs[j]) if j < durs.size() else 1,
				"wrong": false,
			})
	_index = 0
	_accum = 0.0
	_armed = false
	_rebuild_wrong_slots()


## Update which tiles are currently selected (Array of tile ids).
func set_selected(selected: Array) -> void:
	_selected.clear()
	for tile in selected:
		_selected[tile] = true
	_rebuild_wrong_slots()


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------
## Sound a slot (if its ingredient is selected, or it's a clash) and report it.
func _play_slot(seq: Array, i: int) -> void:
	var slot: Dictionary = seq[i]
	var sounding: bool = slot["wrong"] or _selected.has(slot["tile"])
	if sounding:
		var length: float = slot["dur"] * Songs.STEP * 0.9   # slight detach between notes
		synth.pluck(slot["midi"], slot["waveform"], length)
	step_advanced.emit(i, seq.size(), sounding)


## One clash slot per selected tile that isn't part of the recipe. The dissonant
## pitch comes from NoteMap.DISSONANT, varied by the tile's stable index.
func _rebuild_wrong_slots() -> void:
	_wrong_slots.clear()
	var tile_keys: Array = CheeseDB.TILES.keys()
	for tile in _selected:
		if _recipe.has(tile):
			continue
		var idx: int = tile_keys.find(tile)
		var offset: int = NoteMap.DISSONANT[idx % NoteMap.DISSONANT.size()]
		_wrong_slots.append({
			"tile": tile,
			"midi": NoteMap.TONIC_MIDI + offset,
			"waveform": "square",
			"dur": WRONG_DUR,
			"wrong": true,
		})
