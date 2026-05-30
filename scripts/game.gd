extends Control
## Cheezy Tunes — timed service-rush game manager.
## Builds the whole UI in code (placeholder programmer art) and runs the loop:
## show a cheese order -> player clicks ingredient/step tiles -> Serve -> score
## or strike. 3 strikes ends the game.

const START_TIME := 12.0   # seconds for the first order
const MIN_TIME := 5.0      # floor as orders speed up
const TIME_DECAY := 0.4    # seconds shaved off each completed order
const MAX_STRIKES := 3

# --- runtime state ---
var score := 0
var best := 0
var strikes := 0
var order_time := START_TIME
var time_left := 0.0
var current_cheese: Dictionary = {}
var selected: Array[String] = []
var running := false

# --- node references (created in _build_ui) ---
var order_label: Label
var hint_label: Label
var score_label: Label
var strikes_label: Label
var best_label: Label
var timer_bar: ProgressBar
var vat_box: HFlowContainer
var tile_buttons: Dictionary = {}   # tile_id -> Button
var overlay: Panel
var overlay_label: Label
var card_panel: PanelContainer
var card_style: StyleBoxFlat


func _ready() -> void:
	_build_ui()
	_update_strikes()
	start_new_order()


func _process(delta: float) -> void:
	if not running:
		return
	time_left = max(0.0, time_left - delta)
	timer_bar.value = time_left
	# tint the timer red as it runs low
	timer_bar.modulate = Color(1, 1, 1) if time_left > order_time * 0.33 else Color(1, 0.5, 0.5)
	if time_left <= 0.0:
		fail_order("Time's up!")


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# background
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
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)

	# --- top bar: score | strikes | best ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	col.add_child(top)

	score_label = _make_label("Score: 0", 22)
	top.add_child(score_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	strikes_label = _make_label("", 22)
	top.add_child(strikes_label)

	best_label = _make_label("Best: 0", 22)
	top.add_child(best_label)

	# --- order card ---
	card_panel = PanelContainer.new()
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("4a3d24")
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(16)
	card_panel.add_theme_stylebox_override("panel", card_style)
	col.add_child(card_panel)

	var card_col := VBoxContainer.new()
	card_col.add_theme_constant_override("separation", 6)
	card_panel.add_child(card_col)

	order_label = _make_label("Make: ...", 34)
	card_col.add_child(order_label)
	hint_label = _make_label("", 16)
	hint_label.modulate = Color(1, 1, 1, 0.7)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_col.add_child(hint_label)

	# --- timer bar ---
	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.min_value = 0.0
	timer_bar.max_value = START_TIME
	timer_bar.custom_minimum_size = Vector2(0, 22)
	col.add_child(timer_bar)

	# --- vat (selected tiles) ---
	var vat_title := _make_label("Vat:", 18)
	col.add_child(vat_title)
	var vat_panel := PanelContainer.new()
	var vat_style := StyleBoxFlat.new()
	vat_style.bg_color = Color("211b12")
	vat_style.set_corner_radius_all(8)
	vat_style.set_content_margin_all(12)
	vat_panel.add_theme_stylebox_override("panel", vat_style)
	vat_panel.custom_minimum_size = Vector2(0, 80)
	col.add_child(vat_panel)
	vat_box = HFlowContainer.new()
	vat_box.add_theme_constant_override("h_separation", 8)
	vat_box.add_theme_constant_override("v_separation", 8)
	vat_panel.add_child(vat_box)

	# --- ingredient/step tiles ---
	var tiles_title := _make_label("Ingredients & Steps:", 18)
	col.add_child(tiles_title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)

	for tile_id in CheeseDB.get_tile_pool():
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

	# --- action row ---
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	col.add_child(actions)

	var serve_btn := Button.new()
	serve_btn.text = "Serve"
	serve_btn.custom_minimum_size = Vector2(160, 56)
	serve_btn.add_theme_font_size_override("font_size", 22)
	serve_btn.pressed.connect(serve)
	actions.add_child(serve_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(160, 56)
	clear_btn.add_theme_font_size_override("font_size", 22)
	clear_btn.pressed.connect(_on_clear_pressed)
	actions.add_child(clear_btn)

	# --- game over overlay ---
	_build_overlay()


func _build_overlay() -> void:
	overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0.8)
	overlay.add_theme_stylebox_override("panel", ov_style)
	overlay.visible = false
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := _make_label("Game Over", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	overlay_label = _make_label("", 24)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_label)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(200, 56)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.pressed.connect(restart)
	box.add_child(restart_btn)


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _style_tile_button(btn: Button, color: Color) -> void:
	# dark text on the tile's pastel color; brighter when toggled on.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, sb)
	# selected (toggled) state gets a highlight border
	for state in ["pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.15)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		sb.set_border_width_all(4)
		sb.border_color = Color("ffffff")
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("221c10"))
	btn.add_theme_color_override("font_hover_color", Color("221c10"))
	btn.add_theme_color_override("font_pressed_color", Color("221c10"))
	btn.add_theme_color_override("font_focus_color", Color("221c10"))
	btn.add_theme_font_size_override("font_size", 16)


# ---------------------------------------------------------------------------
# Game loop
# ---------------------------------------------------------------------------
func start_new_order() -> void:
	var cheeses := CheeseDB.get_active_cheeses()
	current_cheese = cheeses[randi() % cheeses.size()]
	selected.clear()
	_reset_tiles()
	_refresh_vat()
	order_label.text = "Make: %s" % current_cheese["name"]
	hint_label.text = current_cheese["hint"]
	time_left = order_time
	timer_bar.max_value = order_time
	timer_bar.value = order_time
	running = true


func _on_tile_toggled(pressed: bool, tile_id: String) -> void:
	if not running:
		return
	if pressed:
		if not selected.has(tile_id):
			selected.append(tile_id)
	else:
		selected.erase(tile_id)
	_refresh_vat()


func _on_clear_pressed() -> void:
	if not running:
		return
	selected.clear()
	_reset_tiles()
	_refresh_vat()


func serve() -> void:
	if not running:
		return
	var recipe: Array = current_cheese["recipe"]
	if _same_set(selected, recipe):
		complete_order()
	else:
		fail_order("Wrong recipe!")


func complete_order() -> void:
	score += 1
	score_label.text = "Score: %d" % score
	order_time = max(MIN_TIME, order_time - TIME_DECAY)
	_flash_card(Color("3e7d3a"))
	start_new_order()


func fail_order(reason: String) -> void:
	strikes += 1
	_update_strikes()
	_flash_card(Color("8a2f2f"))
	if strikes >= MAX_STRIKES:
		game_over()
	else:
		hint_label.text = reason
		# brief beat so the player sees the result, then next order
		await get_tree().create_timer(0.6).timeout
		if running and strikes < MAX_STRIKES:
			start_new_order()


func game_over() -> void:
	running = false
	best = max(best, score)
	best_label.text = "Best: %d" % best
	overlay_label.text = "You served %d cheese%s.\nBest: %d" % [
		score, ("" if score == 1 else "s"), best
	]
	overlay.visible = true


func restart() -> void:
	score = 0
	strikes = 0
	order_time = START_TIME
	score_label.text = "Score: 0"
	_update_strikes()
	overlay.visible = false
	start_new_order()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _refresh_vat() -> void:
	for child in vat_box.get_children():
		child.queue_free()
	if selected.is_empty():
		var empty := _make_label("(empty)", 16)
		empty.modulate = Color(1, 1, 1, 0.4)
		vat_box.add_child(empty)
		return
	for tile_id in selected:
		var data: Dictionary = CheeseDB.TILES[tile_id]
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = data["color"]
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(8)
		chip.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.text = data["label"]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color("221c10"))
		chip.add_child(lbl)
		vat_box.add_child(chip)


func _reset_tiles() -> void:
	for tile_id in tile_buttons:
		tile_buttons[tile_id].set_pressed_no_signal(false)


func _update_strikes() -> void:
	var marks := ""
	for i in range(MAX_STRIKES):
		marks += "X" if i < strikes else "O"
	strikes_label.text = "Strikes: " + marks


func _flash_card(color: Color) -> void:
	var original := Color("4a3d24")
	card_style.bg_color = color
	var tween := create_tween()
	tween.tween_method(
		func(c: Color): card_style.bg_color = c,
		color, original, 0.5
	)


## True if `a` and `b` contain exactly the same set of tile ids (order ignored).
func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for item in b:
		if not a.has(item):
			return false
	return true
