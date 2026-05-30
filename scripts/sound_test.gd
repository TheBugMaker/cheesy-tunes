extends Control
## Sound-feedback sandbox for Cheezy Tunes.
## Pick a target cheese; each recipe has a looping jazz riff where every ingredient
## owns one step. Select the correct ingredients and the tune fills in note by note
## (green); selecting a wrong tile tacks an off-key clash onto the loop (red). The
## sequencer does all the sounding — toggles just drive the selection. Run with F6.

var synth: Synth
var sequencer: Sequencer
var note_info: Dictionary = {}          # tile_id -> {midi, waveform, correct}
var tile_buttons: Dictionary = {}       # tile_id -> Button
var selected: Array[String] = []

var target_select: OptionButton
var order_label: Label
var hint_label: Label
var transport_label: Label
var dots_label: Label

# all cheeses, so every recipe (active or not) is testable in the sandbox
var cheeses: Array[Dictionary] = CheeseDB.CHEESES


func _ready() -> void:
	synth = Synth.new()
	add_child(synth)
	sequencer = Sequencer.new()
	sequencer.synth = synth
	sequencer.step_advanced.connect(_on_step_advanced)
	add_child(sequencer)
	_build_ui()
	_select_target(0)
	sequencer.start()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("2b2418")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	col.add_child(_make_label("Sound Test — build the recipe's riff", 26))

	# --- target selector row ---
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 12)
	col.add_child(target_row)
	target_row.add_child(_make_label("Target cheese:", 20))
	target_select = OptionButton.new()
	target_select.add_theme_font_size_override("font_size", 20)
	for cheese in cheeses:
		target_select.add_item(cheese["name"])
	target_select.item_selected.connect(_select_target)
	target_row.add_child(target_select)

	# --- order card ---
	order_label = _make_label("Make: ...", 30)
	col.add_child(order_label)
	hint_label = _make_label("", 16)
	hint_label.modulate = Color(1, 1, 1, 0.7)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint_label)

	# --- transport (looping riff playhead) ---
	transport_label = _make_label("♪ riff", 18)
	transport_label.modulate = Color("9fd3a0")
	col.add_child(transport_label)
	dots_label = _make_label("", 22)
	dots_label.add_theme_font_size_override("font_size", 22)
	col.add_child(dots_label)

	# --- ingredient/step boxes ---
	col.add_child(_make_label("Ingredients & Steps:", 18))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)

	for tile_id in CheeseDB.TILES.keys():
		var data: Dictionary = CheeseDB.TILES[tile_id]
		var btn := Button.new()
		btn.text = data["label"]
		btn.custom_minimum_size = Vector2(180, 52)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		_style_tile_button(btn, data["color"])
		btn.toggled.connect(_on_tile_toggled.bind(tile_id))
		grid.add_child(btn)
		tile_buttons[tile_id] = btn

	# --- clear / stop all ---
	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(220, 52)
	clear_btn.add_theme_font_size_override("font_size", 20)
	clear_btn.pressed.connect(_on_clear_pressed)
	col.add_child(clear_btn)


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------
func _select_target(index: int) -> void:
	var cheese: Dictionary = cheeses[index]
	var recipe: Array = cheese["recipe"]
	note_info = NoteMap.build(recipe)
	order_label.text = "Make: %s" % cheese["name"]
	hint_label.text = cheese["hint"]
	transport_label.text = "♪ %s — \"%s\"" % [cheese["name"], Songs.title_for(cheese["name"])]
	_clear_selection()
	sequencer.load_song(recipe, Songs.phrases_for(cheese["name"], recipe))
	sequencer.set_selected(selected)


func _on_tile_toggled(pressed: bool, tile_id: String) -> void:
	var correct: bool = note_info[tile_id]["correct"]
	if pressed:
		if not selected.has(tile_id):
			selected.append(tile_id)
		_set_border(tile_buttons[tile_id], true, correct)
	else:
		selected.erase(tile_id)
		_set_border(tile_buttons[tile_id], false, correct)
	sequencer.set_selected(selected)


func _on_clear_pressed() -> void:
	_clear_selection()
	sequencer.set_selected(selected)


func _clear_selection() -> void:
	selected.clear()
	for tile_id in tile_buttons:
		var btn: Button = tile_buttons[tile_id]
		btn.set_pressed_no_signal(false)
		var correct: bool = note_info.get(tile_id, {}).get("correct", false)
		_set_border(btn, false, correct)


func _on_step_advanced(index: int, total: int, _sounding: bool) -> void:
	# a compact row of dots (riffs can be ~20 steps now); the current step glows
	var s := ""
	for i in total:
		s += "●" if i == index else "·"
	dots_label.text = s


# ---------------------------------------------------------------------------
# Styling helpers (mirrors game.gd conventions)
# ---------------------------------------------------------------------------
func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _style_tile_button(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("221c10"))
	btn.add_theme_color_override("font_hover_color", Color("221c10"))
	btn.add_theme_color_override("font_pressed_color", Color("221c10"))
	btn.add_theme_color_override("font_focus_color", Color("221c10"))
	btn.add_theme_font_size_override("font_size", 16)


## Re-apply a tile's styleboxes with (or without) a correct/wrong border.
func _set_border(btn: Button, on: bool, correct: bool) -> void:
	var color: Color = CheeseDB.TILES[_tile_id_of(btn)]["color"]
	var border := Color("3ecf4a") if correct else Color("e0473e")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.15) if on else color
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		if on:
			sb.set_border_width_all(4)
			sb.border_color = border
		btn.add_theme_stylebox_override(state, sb)


func _tile_id_of(btn: Button) -> String:
	for tile_id in tile_buttons:
		if tile_buttons[tile_id] == btn:
			return tile_id
	return ""
