extends Control
## Cheezy Tunes — pot-and-cook cheese factory.
## Buy ingredients with money, click them into the central pot, press Cook to
## produce a wheel.
## Wheels directly fulfill matching orders from a timed queue.
## Wastes ingredients if there is no matching active order or recipe mismatch.

# --- Custom Font Preload ---
const GAME_FONT: Font = preload("res://Fonts/PPEditorialNew-Regular-BF644b214ff145f.otf")
const DEFAULT_ITEM_TEXTURE: Texture2D = preload("res://Sprites/milkBucket.png")

const START_MONEY: int = 50
const COOK_TIME: float = 4.0

# ---------------------------------------------------------------------------
# LEVEL DEFINITIONS
# Each level is a Dictionary with:
#   "flavor"      : String   — shown on the interstitial screen before the level
#   "ingredients" : Array    — which ingredient IDs are available this level
#   "orders"      : Array    — each entry is [cheese_name, spawn_time, duration]
#             
#                  spawn_time  = seconds after level start when the order appears
#                              duration    = how many seconds the player has to fulfill it
# ---------------------------------------------------------------------------
const LEVELS: Array = [
	{
		"flavor": "You have some light orders coming in.\nThe smell of warm milk fills the air.",
		"ingredients": ["milk", "acid", "salt", "bacteria"],
		"orders": [
			["Mozzarella", 0.0,  60.0],
			["Mozzarella", 15.0, 60.0],
			["Paneer",     22.0, 60.0],
			["Mozzarella",     26.0, 60.0],
			["Paneer",     32.0, 60.0],
			["Mozzarella",     37.0, 55.0],
		],
	},
	{
		"flavor": "Word spreads.\nA local distributor wants more of the good stuff.\nThe morning shift feels longer than it should.",
		"ingredients": ["milk", "acid", "salt", "rennet", "bacteria"],
		"orders": [
			["Mozzarella", 0.0,  50.0],
			["Mozzarella",    10.0, 50.0],
			["Paneer", 20.0, 50.0],
			["Cream Cheese",    35.0, 50.0],
			["Cream Cheese",    35.0, 50.0],
			["Paneer",    35.0, 48.0],
			["Mozzarella",    35.0, 48.0],
			["Cream Cheese",    35.0, 48.0],
		],
	},
	{
		"flavor": "A new batch of orders arrived.\nStrange order forms. No Company name in the form.\nThe foreman says not to ask questions.",
		"ingredients": ["milk", "acid", "salt", "rennet", "bacteria"],
		"orders": [
			["Comte", 0.0,  50.0],
			["Mozzarella",    10.0, 50.0],
			["Paneer", 20.0, 50.0],
			["Cream Cheese",    35.0, 50.0],
			["Cream Cheese",    35.0, 50.0],
			["Paneer",    45.0, 48.0],
			["Mozzarella",    60.0, 48.0],
			["Comte",    75.0, 48.0],
			["Cream Cheese",    85.0, 48.0],
			["Cream Cheese",    95.0, 48.0],
			["Comte",    105.0, 48.0],
		],
	},
	{
		"flavor": "The factory grows cold at night.\nSomething is fermenting that shouldn't be.",
		"ingredients": ["milk", "acid", "salt", "rennet", "bacteria", "mold"],
		"orders": [
			["Comte", 0.0,  40.0],
			["Mozzarella",    10.0, 40.0],
			["Brie", 20.0, 40.0],
			["Cream Cheese",    35.0, 40.0],
			["Cream Cheese",    35.0, 40.0],
			["Paneer",    45.0, 40.0],
			["Mozzarella",    60.0, 40.0],
			["Comte",    75.0, 40.0],
			["Cream Cheese",    85.0, 40.0],
			["Roquefort",    95.0, 40.0],
			["Comte",    105.0, 40.0],
			["Brie",    105.0, 38.0],
			["Roquefort",    105.0, 38.0],
		],
	},
	{
		"flavor": "The last day.\nAn inspector is coming.\nMake it count. Make it perfect.",
		"ingredients": ["milk", "acid", "salt", "rennet", "bacteria", "mold", "wine", "fungus"],
		"orders": [
			["Comte", 0.0,  35.0],
			["Mozzarella",    10.0, 35.0],
			["Brie", 20.0, 35.0],
			["Taleggio",    35.0, 35.0],
			["Cream Cheese",    35.0, 35.0],
			["Paneer",    45.0, 35.0],
			["Mozzarella",    60.0, 35.0],
			["Comte",    75.0, 35.0],
			["Cream Cheese",    85.0, 35.0],
			["Roquefort",    95.0, 35.0],
			["Comte",    105.0, 35.0],
			["Brie",    105.0, 35.0],
			["Roquefort",    105.0, 35.0],
			["Taleggio",    105.0, 32.0],
			["Roquefort",    105.0, 32.0],
		],
	},
]

# --- runtime state ---
var money: int = START_MONEY
var current_displayed_money: int = START_MONEY # ROLLING COUNTER: Tracks visual money ticker
var money_tween: Tween                         # ROLLING COUNTER: Animates visual ticker changes

var score: int = 0
var inventory: Dictionary = {}        # ingredient_id -> int
var pot: Array[String] = []           # ingredient_ids in click order
var cooking: bool = false
var cook_progress: float = 0.0
var cook_target: String = ""          # cheese name, "" if mismatch
var orders: Array = []                # active orders (with UI node refs)
var running: bool = false

# --- level state ---
var current_level: int = 0            # 0-indexed into LEVELS
var level_time: float = 0.0           # seconds elapsed since level start
var pending_orders: Array = []        # orders not yet spawned this level [{cheese,spawn,duration}]
var level_complete: bool = false      # waiting to transition after last order done

# --- node references ---
var money_label: Label
var dollar_lbl: Label                 # ROLLING COUNTER: Track reference to sync properties
var orders_box: VBoxContainer
var inventory_container: GridContainer
var plate_canvas: Control
var pot_progress: ProgressBar
var cook_btn: Button
var clear_btn: Button
var overlay: Panel
var overlay_label: Label

# --- interstitial (between-level) screen ---
var interstitial: Panel
var interstitial_label: Label
var interstitial_begin_btn: Button

# --- custom tooltip references ---
var custom_tooltip: PanelContainer
var custom_tooltip_label: RichTextLabel

var inv_labels: Dictionary = {}       # ingredient_id -> Label (count in inventory slot)
var buy_buttons: Dictionary = {}      # ingredient_id -> Button
var inv_cards: Dictionary = {}        # ingredient_id -> root card Control (for show/hide)

# --- musical ingredient hints (mirrors sound_test.gd) ---
var synth: Synth
var sequencer: Sequencer
var music_target: String = ""         # current target cheese name
var target_cheeses: Array[String] = []  # selectable targets for the current level (index-aligned with target_select)
var target_select: OptionButton
var transport_label: Label            # "♪ <cheese> — <song title>"
var dots_label: Label                 # looping riff playhead indicator


func _ready() -> void:
	randomize()
	_build_ui()
	_init_inventory()
	_init_audio()
	_show_interstitial(current_level)   # Start at level 0 interstitial


# Build the synth + sequencer that drive the musical ingredient hints
# (same setup as sound_test.gd). The sequencer runs its own _process; it stays
# idle until a level loads a song and the player selects ingredients.
func _init_audio() -> void:
	synth = Synth.new()
	add_child(synth)
	sequencer = Sequencer.new()
	sequencer.synth = synth
	sequencer.step_advanced.connect(_on_step_advanced)
	add_child(sequencer)


func _process(delta: float) -> void:
	if not running:
		return

	# Frame-by-frame mouse tracking for instant tooltips
	if custom_tooltip and custom_tooltip.visible:
		custom_tooltip.global_position = get_global_mouse_position() + Vector2(14, 14)

	_tick_cook(delta)
	_tick_level(delta)

	if _is_game_over():
		_show_game_over()


# ---------------------------------------------------------------------------
# Level flow
# ---------------------------------------------------------------------------
func _show_interstitial(level_idx: int) -> void:
	running = false
	if sequencer:
		sequencer.stop()
		synth.all_off()
	interstitial_label.text = LEVELS[level_idx]["flavor"]
	interstitial_begin_btn.text = "Begin Level %d" % (level_idx + 1)
	interstitial.visible = true


func _begin_level(level_idx: int) -> void:
	interstitial.visible = false

	var level: Dictionary = LEVELS[level_idx]

	# Reset per-level state
	pot.clear()
	cooking = false
	cook_progress = 0.0
	cook_target = ""
	orders.clear()
	level_time = 0.0
	level_complete = false

	# Build pending order queue from definition with Random configurations
	pending_orders.clear()
	for entry in level["orders"]:
		var cheese_name: String = entry[0]
		
		if cheese_name == "Random1":
			var options: Array = ["Mozzarella", "Paneer", "Cream Cheese"]
			cheese_name = options[randi() % options.size()]
		elif cheese_name == "Random2":
			var options: Array = ["Brie", "Comte", "Roquefort"]
			cheese_name = options[randi() % options.size()]
		elif cheese_name == "Random3":
			var options: Array = []
			for cheese in CheeseDB.get_active_cheeses():
				options.append(cheese["name"])
			if options.is_empty():
				options = ["Paneer", "Mozzarella", "Cheddar", "Brie", "Roquefort", "Comte", "Taleggio"]
			cheese_name = options[randi() % options.size()]

		pending_orders.append({
			"cheese":    cheese_name,
			"spawn":     float(entry[1]),
			"duration":  float(entry[2]),
		})

	# Show/hide ingredient cards based on what this level allows
	_apply_level_ingredients(level["ingredients"])

	# Clear inventory counts (slots already filtered by visibility)
	for id in inventory.keys():
		inventory[id] = 0

	pot_progress.visible = false
	cook_btn.disabled = false
	clear_btn.disabled = false

	# Tune the musical hints to this level's cheeses and start the looping riff.
	_populate_target_select()
	sequencer.start()

	running = true
	_refresh_all()


func _apply_level_ingredients(allowed: Array) -> void:
	for id in inv_cards.keys():
		var card: Control = inv_cards[id]
		card.visible = allowed.has(id)
		# Reset inventory for hidden ingredients too
		inventory[id] = 0


func _tick_level(delta: float) -> void:
	level_time += delta

	# Spawn any orders whose time has come
	var spawned: bool = false
	var i: int = pending_orders.size() - 1
	while i >= 0:
		var pending: Dictionary = pending_orders[i]
		if level_time >= pending["spawn"]:
			_spawn_order(pending["cheese"], pending["duration"])
			pending_orders.remove_at(i)
			spawned = true
		i -= 1

	# Tick active orders
	var structure_changed: bool = false
	var j: int = orders.size() - 1
	while j >= 0:
		orders[j]["time_left"] -= delta
		if orders[j]["time_left"] <= 0.0:
			orders.remove_at(j)
			structure_changed = true
		else:
			if orders[j].has("time_label") and is_instance_valid(orders[j]["time_label"]):
				var lbl: Label = orders[j]["time_label"]
				lbl.text = _format_time(orders[j]["time_left"])
				if orders[j]["time_left"] < orders[j]["time_max"] * 0.33:
					lbl.modulate = Color(1, 0.55, 0.55)
				else:
					lbl.modulate = Color(1, 1, 1)
		j -= 1

	if spawned or structure_changed:
		_refresh_orders()

	# Check if level is finished: no pending, no active orders, not cooking
	if pending_orders.is_empty() and orders.is_empty() and not cooking and not level_complete:
		level_complete = true
		_on_level_complete()


func _spawn_order(cheese_name: String, duration: float) -> void:
	var rng: Vector2i = CheeseDB.CHEESE_PAYOUT_RANGE.get(cheese_name, Vector2i(20, 30))
	var payout: int = rng.x + (randi() % max(1, rng.y - rng.x + 1))
	orders.append({
		"cheese":    cheese_name,
		"time_left": duration,
		"time_max":  duration,
		"payout":    payout,
		"revealed":  false,
	})
	_refresh_orders()


func _on_level_complete() -> void:
	running = false
	var next: int = current_level + 1
	if next >= LEVELS.size():
		# All levels done — show a victory screen
		_show_victory()
	else:
		current_level = next
		_show_interstitial(current_level)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color("2b2418")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root: MarginContainer = MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	# --- top bar: money + level readout ---
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	col.add_child(top)

	var money_container: HBoxContainer = HBoxContainer.new()
	money_container.add_theme_constant_override("separation", 4)
	top.add_child(money_container)

	dollar_lbl = _make_label("$", 42)
	dollar_lbl.modulate = Color("4eff4e")
	money_container.add_child(dollar_lbl)

	money_label = _make_label("", 44)
	money_label.modulate = Color("4eff4e")
	money_container.add_child(money_label)

	# --- middle: layout splitter ---
	var mid: HBoxContainer = HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)

	# --- left column: Orders & Inventory ---
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	mid.add_child(left)

	left.add_child(_make_bold_label("Orders", 20))
	orders_box = VBoxContainer.new()
	orders_box.add_theme_constant_override("separation", 6)
	left.add_child(_panel(orders_box, Color("3a2f1c")))

	left.add_child(_make_bold_label("Inventory", 20))
	inventory_container = GridContainer.new()
	inventory_container.columns = 3
	inventory_container.add_theme_constant_override("h_separation", 16)
	inventory_container.add_theme_constant_override("v_separation", 16)
	left.add_child(_panel(inventory_container, Color("241d12")))

	# --- right column: pot area ---
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	mid.add_child(right)
	right.add_child(_build_pot_area())

	# --- Build the Grid Layout contents (all cards, hidden by default) ---
	_build_buy_strip()

	# --- Instant Custom Tooltip Box ---
	custom_tooltip = PanelContainer.new()
	var tooltip_sb: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_sb.bg_color = Color("111111", 0.95)
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.border_color = Color("555555")
	tooltip_sb.set_content_margin_all(2)
	custom_tooltip.add_theme_stylebox_override("panel", tooltip_sb)
	custom_tooltip.visible = false
	custom_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	custom_tooltip_label = RichTextLabel.new()
	custom_tooltip_label.bbcode_enabled = true
	custom_tooltip_label.fit_content = true
	custom_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	custom_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_tooltip_label.add_theme_font_override("normal_font", GAME_FONT)
	custom_tooltip_label.add_theme_font_size_override("normal_font_size", 14)
	custom_tooltip.add_child(custom_tooltip_label)

	add_child(custom_tooltip)

	_build_overlay()
	_build_interstitial()


func _build_interstitial() -> void:
	interstitial = Panel.new()
	interstitial.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_style: StyleBoxFlat = StyleBoxFlat.new()
	ov_style.bg_color = Color("2b2418", 0.97)
	interstitial.add_theme_stylebox_override("panel", ov_style)
	interstitial.visible = false
	add_child(interstitial)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	interstitial.add_child(center)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 32)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	interstitial_label = _make_label("", 22)
	interstitial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interstitial_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	interstitial_label.custom_minimum_size = Vector2(480, 0)
	interstitial_label.modulate = Color("e0cb9b")
	box.add_child(interstitial_label)

	# Spacer so button sits clearly below the text
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	interstitial_begin_btn = Button.new()
	interstitial_begin_btn.text = "Begin Level 1"
	interstitial_begin_btn.custom_minimum_size = Vector2(220, 56)
	interstitial_begin_btn.add_theme_font_override("font", GAME_FONT)
	interstitial_begin_btn.add_theme_font_size_override("font_size", 22)
	interstitial_begin_btn.pressed.connect(_on_begin_pressed)
	box.add_child(interstitial_begin_btn)


func _on_begin_pressed() -> void:
	_begin_level(current_level)


func _build_pot_area() -> Control:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.add_child(_make_bold_label("Cooking Area", 20))

	# --- musical hint: target selector + looping riff transport (mirrors sound_test) ---
	var tune_row: HBoxContainer = HBoxContainer.new()
	tune_row.add_theme_constant_override("separation", 10)
	tune_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tune_row.add_child(_make_label("Tune to:", 16))
	target_select = OptionButton.new()
	target_select.add_theme_font_override("font", GAME_FONT)
	target_select.add_theme_font_size_override("font_size", 16)
	target_select.item_selected.connect(_select_music_target)
	tune_row.add_child(target_select)
	wrap.add_child(tune_row)

	transport_label = _make_label("♪ riff", 15)
	transport_label.modulate = Color("9fd3a0")
	transport_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(transport_label)

	dots_label = _make_label("", 18)
	dots_label.modulate = Color("9fd3a0")
	dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(dots_label)

	var pot_center_wrap: CenterContainer = CenterContainer.new()
	pot_center_wrap.add_child(_build_pot_center())
	wrap.add_child(pot_center_wrap)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(btn_row)

	cook_btn = Button.new()
	cook_btn.text = "Cook"
	cook_btn.custom_minimum_size = Vector2(140, 48)
	cook_btn.add_theme_font_override("font", GAME_FONT)
	cook_btn.add_theme_font_size_override("font_size", 20)
	cook_btn.pressed.connect(_on_cook_pressed)
	btn_row.add_child(cook_btn)

	clear_btn = Button.new()
	clear_btn.text = "Discard"
	clear_btn.custom_minimum_size = Vector2(140, 48)
	clear_btn.add_theme_font_override("font", GAME_FONT)
	clear_btn.add_theme_font_size_override("font_size", 18)
	clear_btn.pressed.connect(_on_clear_pot)
	btn_row.add_child(clear_btn)

	return wrap


func _build_pot_center() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("3d2f1a")
	sb.set_corner_radius_all(80)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color("7a5a2a")
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(180, 160)

	var container: VBoxContainer = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(container)

	plate_canvas = Control.new()
	plate_canvas.custom_minimum_size = Vector2(160, 140)
	plate_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(plate_canvas)

	pot_progress = ProgressBar.new()
	pot_progress.show_percentage = false
	pot_progress.min_value = 0.0
	pot_progress.max_value = 1.0
	pot_progress.value = 0.0
	pot_progress.custom_minimum_size = Vector2(140, 12)
	pot_progress.visible = false
	pot_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(pot_progress)

	return panel


func _build_buy_strip() -> void:
	var flavor_dict: Dictionary = {
		"milk":     "A very happy cow's produce.",
		"acid":     "Popular among chefs and drug addicts alike.",
		"salt":     "Adds flavor to milkier cheese.",
		"bacteria": "This grew in a dead reindeer's gut.",
		"rennet":   "This also grew in a dead reindeer's gut.",
		"mold":     "Once popular with hippies. Once.",
		"fungus":   "Once popular with hippies. Once.",
		"wine":     "Used in a fancy cheese.",
	}

	for id in _all_ingredient_ids():
		var data: Dictionary = CheeseDB.TILES[id]
		var price: int = CheeseDB.INGREDIENT_PRICES[id]

		var clean_id: String = id.strip_edges().to_lower()
		var display_label: String = data["label"]

		# Root card — this is what gets hidden per-level
		var card: Control = Control.new()
		card.custom_minimum_size = Vector2(76, 76)
		card.visible = false   # hidden until a level enables it
		inv_cards[id] = card   # store reference for show/hide

		var bg_panel: PanelContainer = PanelContainer.new()
		bg_panel.custom_minimum_size = Vector2(76, 76)
		bg_panel.pivot_offset = Vector2(38, 38) # Ensures scaling scales cleanly from center
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("1a140b")
		sb.set_corner_radius_all(6)
		bg_panel.add_theme_stylebox_override("panel", sb)
		card.add_child(bg_panel)

		var tex_btn: TextureButton = TextureButton.new()
		tex_btn.custom_minimum_size = Vector2(76, 76)
		tex_btn.ignore_texture_size = true
		tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		if data.has("texture") and data["texture"] is Texture2D:
			tex_btn.texture_normal = data["texture"]
		elif data.has("texture") and data["texture"] is String and data["texture"] != "":
			tex_btn.texture_normal = load(data["texture"])
		else:
			tex_btn.texture_normal = DEFAULT_ITEM_TEXTURE

		tex_btn.pressed.connect(_on_ring_clicked.bind(id))

		var flav: String = flavor_dict.get(clean_id, "")
		if flav == "":
			flav = flavor_dict.get(data.get("label", "").strip_edges().to_lower(), "")

		var final_hover_text: String = "[color=white]" + display_label + "[/color]"
		if flav != "":
			final_hover_text += "\n[color=#b5b5b5]" + flav + "[/color]"

		# Hover behaviors for the asset image button
		tex_btn.mouse_entered.connect(_show_instant_tooltip.bind(final_hover_text, Color.WHITE))
		tex_btn.mouse_entered.connect(func(): bg_panel.scale = Vector2(1.1, 1.1))
		tex_btn.mouse_exited.connect(_hide_instant_tooltip)
		tex_btn.mouse_exited.connect(func(): bg_panel.scale = Vector2(1.0, 1.0))
		bg_panel.add_child(tex_btn)

		var count_lbl: Label = Label.new()
		count_lbl.text = "0"
		count_lbl.add_theme_font_override("font", GAME_FONT)
		count_lbl.add_theme_font_size_override("font_size", 18)
		count_lbl.add_theme_color_override("font_outline_color", Color("000000"))
		count_lbl.add_theme_constant_override("outline_size", 5)
		count_lbl.position = Vector2(8, 58)
		card.add_child(count_lbl)
		inv_labels[id] = count_lbl

		var btn: Button = Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(22, 22)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", GAME_FONT)
		btn.add_theme_color_override("font_color", Color("4eff4e"))
		btn.add_theme_color_override("font_hover_color", Color("a3ffa3"))
		btn.add_theme_font_size_override("font_size", 14)

		var btn_sb: StyleBoxFlat = StyleBoxFlat.new()
		btn_sb.bg_color = Color("111111", 0.8)
		btn_sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_sb)
		var btn_sb_h: StyleBoxFlat = btn_sb.duplicate() as StyleBoxFlat
		btn_sb_h.bg_color = Color("222222", 0.9)
		btn.add_theme_stylebox_override("hover", btn_sb_h)

		var lowercase_item_name: String = display_label.to_lower()
		var buy_text_color: Color = Color("ff4e4e")

		# Hover behaviors for the transaction (+) button
		btn.mouse_entered.connect(_show_instant_tooltip.bind("Buy " + lowercase_item_name + " ($" + str(price) + ")", buy_text_color))
		btn.mouse_entered.connect(func(): bg_panel.scale = Vector2(1.1, 1.1))
		btn.mouse_exited.connect(_hide_instant_tooltip)
		btn.mouse_exited.connect(func(): bg_panel.scale = Vector2(1.0, 1.0))
		btn.pressed.connect(_on_buy.bind(id))

		btn.position = Vector2(58, 58)
		card.add_child(btn)
		buy_buttons[id] = btn

		inventory_container.add_child(card)


func _build_overlay() -> void:
	overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_style: StyleBoxFlat = StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0.82)
	overlay.add_theme_stylebox_override("panel", ov_style)
	overlay.visible = false
	add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title: Label = _make_label("Bankrupt!", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	overlay_label = _make_label("", 22)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_label)
	var restart_btn: Button = Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(200, 56)
	restart_btn.add_theme_font_override("font", GAME_FONT)
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(restart)
	box.add_child(restart_btn)


func _make_label(text: String, font_size: int) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", GAME_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _make_bold_label(text: String, font_size: int) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", GAME_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _panel(child: Control, color: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(child)
	return p


# ---------------------------------------------------------------------------
# Dynamic Cost Equation
# ---------------------------------------------------------------------------
func _get_reveal_cost(order: Dictionary) -> int:
	return int(round(float(order["payout"]) * 0.20))


# ---------------------------------------------------------------------------
# Time Formatting Utility
# ---------------------------------------------------------------------------
func _format_time(seconds: float) -> String:
	var total_secs: int = int(max(0.0, ceil(seconds)))
	var mins: int = total_secs / 60
	var secs: int = total_secs % 60
	return "%02d:%02d" % [mins, secs]


# ---------------------------------------------------------------------------
# Ingredient sets
# ---------------------------------------------------------------------------
func _all_ingredient_ids() -> PackedStringArray:
	var seen: Dictionary = {}
	for cheese: Dictionary in CheeseDB.get_active_cheeses():
		for id: String in cheese["recipe"]:
			seen[id] = true
	var out: PackedStringArray = PackedStringArray()
	for id: String in CheeseDB.TILES.keys():
		if seen.has(id):
			out.append(id)
	return out


# ---------------------------------------------------------------------------
# Game loop pieces
# ---------------------------------------------------------------------------
func _init_inventory() -> void:
	for id: String in _all_ingredient_ids():
		inventory[id] = 0


func _on_buy(id: String) -> void:
	if not running:
		return
	var price: int = CheeseDB.INGREDIENT_PRICES[id]
	if money < price:
		return
	money -= price
	inventory[id] = int(inventory.get(id, 0)) + 1
	_refresh_money()
	_refresh_inventory()
	_update_hint_buttons_disabled_state()


func _on_ring_clicked(id: String) -> void:
	if not running or cooking:
		return
	if int(inventory.get(id, 0)) <= 0:
		return
	inventory[id] -= 1
	pot.append(id)
	_on_pot_add(id)
	_refresh_inventory()
	_refresh_pot()


func _on_clear_pot() -> void:
	if not running or cooking:
		return
	if pot.is_empty():
		return
		
	# Sum total ingredient value inside pot and provide a 20% refund
	var total_pot_value: int = 0
	for id in pot:
		total_pot_value += CheeseDB.INGREDIENT_PRICES.get(id, 0)
	
	var refund_amount: int = int(floor(total_pot_value * 0.20))
	money += refund_amount
	
	_on_pot_clear()
	pot.clear()
	
	_refresh_money()
	_refresh_inventory()
	_update_hint_buttons_disabled_state()
	_refresh_pot()


func _on_cook_pressed() -> void:
	if not running or cooking or pot.is_empty():
		return
	cook_target = _match_recipe(pot)
	cooking = true
	cook_progress = 0.0
	pot_progress.visible = true
	pot_progress.value = 0.0
	cook_btn.disabled = true
	clear_btn.disabled = true
	_on_cook_start(cook_target)
	_refresh_pot()


func _tick_cook(delta: float) -> void:
	if not cooking:
		return
	cook_progress = min(1.0, cook_progress + delta / COOK_TIME)
	pot_progress.value = cook_progress
	if cook_progress >= 1.0:
		_finish_cook()


func _finish_cook() -> void:
	if cook_target != "":
		var matching_order_idx: int = -1
		for i: int in range(orders.size()):
			if orders[i]["cheese"] == cook_target:
				matching_order_idx = i
				break

		if matching_order_idx != -1:
			var completed_order: Dictionary = orders[matching_order_idx]
			money += int(completed_order["payout"])
			score += 1
			_on_cook_success(cook_target)
			orders.remove_at(matching_order_idx)
			_refresh_money()
			_refresh_orders()
		else:
			_on_cook_fail()
	else:
		_on_cook_fail()

	pot.clear()
	if sequencer:
		sequencer.set_selected(pot)   # riff resets to silence after a cook
	cooking = false
	cook_progress = 0.0
	pot_progress.visible = false
	cook_btn.disabled = false
	clear_btn.disabled = false
	cook_target = ""
	_refresh_pot()


func _match_recipe(current_pot: Array[String]) -> String:
	for cheese: Dictionary in CheeseDB.get_active_cheeses():
		if _same_set(current_pot, cheese["recipe"]):
			return cheese["name"]
	return ""


func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for item: String in b:
		if not a.has(item):
			return false
	return true


# ---------------------------------------------------------------------------
# Hint Button Trigger Callbacks
# ---------------------------------------------------------------------------
func _on_reveal_recipe_pressed(order: Dictionary) -> void:
	var cost: int = _get_reveal_cost(order)
	if money < cost:
		return
	money -= cost
	order["revealed"] = true
	_refresh_all()


func _update_hint_buttons_disabled_state() -> void:
	for order: Dictionary in orders:
		if order.has("reveal_button") and is_instance_valid(order["reveal_button"]):
			order["reveal_button"].disabled = money < _get_reveal_cost(order)


# ---------------------------------------------------------------------------
# Custom Tooltip Toggles
# ---------------------------------------------------------------------------
func _show_instant_tooltip(full_text: String, text_color: Color) -> void:
	if custom_tooltip_label and custom_tooltip:
		custom_tooltip_label.text = full_text
		custom_tooltip_label.add_theme_color_override("default_color", text_color)
		custom_tooltip.visible = true
		custom_tooltip.reset_size()


func _hide_instant_tooltip() -> void:
	if custom_tooltip:
		custom_tooltip.visible = false


# ---------------------------------------------------------------------------
# Game over / victory / restart
# ---------------------------------------------------------------------------
func _is_game_over() -> bool:
	if cooking:
		return false
	if not pot.is_empty():
		return false
	if level_complete:
		return false
	if not pending_orders.is_empty():
		return false
	if orders.is_empty():
		return false
	for order: Dictionary in orders:
		if _can_afford_recipe(order["cheese"]):
			return false
	return true


func _can_afford_recipe(cheese_name: String) -> bool:
	for cheese: Dictionary in CheeseDB.CHEESES:
		if cheese["name"] != cheese_name:
			continue
		var needed: Dictionary = {}
		for id: String in cheese["recipe"]:
			needed[id] = int(needed.get(id, 0)) + 1
		var cash: int = money
		for id: String in needed.keys():
			var have: int = int(inventory.get(id, 0))
			var short: int = max(0, int(needed[id]) - have)
			cash -= short * int(CheeseDB.INGREDIENT_PRICES[id])
			if cash < 0:
				return false
		return true
	return false


func _show_game_over() -> void:
	running = false
	if sequencer:
		sequencer.stop()
		synth.all_off()
	overlay_label.text = "You fulfilled %d order%s.\nFinal money: %s" % [
		score, ("" if score == 1 else "s"), _format_money(money),
	]
	overlay.visible = true


func _show_victory() -> void:
	running = false
	if sequencer:
		sequencer.stop()
		synth.all_off()
	for child: Node in overlay.get_children():
		child.queue_free()
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title: Label = _make_label("The factory closes.", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("e0cb9b")
	box.add_child(title)
	var sub: Label = _make_label(
		"You fulfilled %d order%s across %d levels.\nFinal earnings: %s" % [
			score, ("" if score == 1 else "s"),
			LEVELS.size(), _format_money(money)
		], 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var restart_btn: Button = Button.new()
	restart_btn.text = "Play Again"
	restart_btn.custom_minimum_size = Vector2(200, 56)
	restart_btn.add_theme_font_override("font", GAME_FONT)
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(restart)
	box.add_child(restart_btn)
	overlay.visible = true


func restart() -> void:
	money = START_MONEY
	current_displayed_money = START_MONEY # ROLLING COUNTER: Snap counter value back instantly on restart
	score = 0
	current_level = 0
	pot.clear()
	cooking = false
	cook_progress = 0.0
	cook_target = ""
	level_time = 0.0
	level_complete = false
	pending_orders.clear()
	for id: String in inventory.keys():
		inventory[id] = 0
	orders.clear()
	pot_progress.visible = false
	cook_btn.disabled = false
	clear_btn.disabled = false
	overlay.visible = false

	for id in inv_cards.keys():
		inv_cards[id].visible = false

	_refresh_all()
	_show_interstitial(current_level)


# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_refresh_money()
	_refresh_inventory()
	_refresh_pot()
	_refresh_orders()


# ROLLING COUNTER: Kicks off a fast rolling tween towards the target money balance
func _refresh_money() -> void:
	if money_tween:
		money_tween.kill()
	money_tween = create_tween()
	money_tween.tween_method(_set_displayed_money, current_displayed_money, money, 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


# ROLLING COUNTER: Frame-by-frame callback method executing formatting updates
func _set_displayed_money(value: int) -> void:
	current_displayed_money = value
	if money_label:
		money_label.text = _format_money(current_displayed_money)


func _format_money(val: int) -> String:
	if val >= 1000:
		var k_val: float = float(val) / 1000.0
		if is_equal_approx(k_val, round(k_val)):
			return "%dK" % int(round(k_val))
		else:
			return "%.1fK" % k_val
	return str(val)


func _refresh_inventory() -> void:
	for id: String in inv_labels.keys():
		inv_labels[id].text = str(inventory.get(id, 0))
		var price: int = CheeseDB.INGREDIENT_PRICES[id]
		buy_buttons[id].disabled = money < price


func _refresh_pot() -> void:
	# Clear the old bowl contents
	for child in plate_canvas.get_children():
		child.queue_free()
		
	# Add an icon for each item in the pot
	for i in range(pot.size()):
		var id = pot[i]
		var img = TextureRect.new()
		
		# Look up the correct texture from your CheeseDB dictionary
		if CheeseDB.TILES.has(id) and CheeseDB.TILES[id].has("texture"):
			img.texture = CheeseDB.TILES[id]["texture"]
		else:
			img.texture = DEFAULT_ITEM_TEXTURE # Fallback
			
		img.custom_minimum_size = Vector2(40, 40)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Randomized offset for the "pile" effect
		img.position = Vector2(randf_range(0, 50), randf_range(0, 50))
		plate_canvas.add_child(img)


func _refresh_orders() -> void:
	if custom_tooltip:
		custom_tooltip.visible = false

	for child: Node in orders_box.get_children():
		child.queue_free()
	if orders.is_empty():
		var empty: Label = _make_label("(no orders)", 14)
		empty.modulate = Color(1, 1, 1, 0.5)
		orders_box.add_child(empty)
		return

	for order: Dictionary in orders:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl: Label = _make_label(order["cheese"], 16)
		name_lbl.custom_minimum_size = Vector2(110, 0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP

		var clean_name: String = order["cheese"].strip_edges().to_lower()
		var quality_color: Color = Color.WHITE

		if clean_name == "roquefort" or clean_name == "taleggio":
			quality_color = Color("ccff33")
		elif clean_name == "comte":
			quality_color = Color("4eff4e")

		name_lbl.modulate = quality_color

		var combined_order_text: String = order["cheese"] + " ($" + str(int(order["payout"])) + ")"
		name_lbl.mouse_entered.connect(_show_instant_tooltip.bind(combined_order_text, quality_color))
		name_lbl.mouse_exited.connect(_hide_instant_tooltip)
		row.add_child(name_lbl)

		var time_lbl: Label = _make_label(_format_time(order["time_left"]), 16)
		time_lbl.custom_minimum_size = Vector2(54, 0)
		if order["time_left"] < order["time_max"] * 0.33:
			time_lbl.modulate = Color(1, 0.55, 0.55)
		row.add_child(time_lbl)
		order["time_label"] = time_lbl

		if order.get("revealed", false):
			var recipe_string: String = _get_recipe_string(order["cheese"])
			var recipe_lbl: Label = _make_label("[%s]" % recipe_string, 13)
			recipe_lbl.modulate = Color("e0cb9b")
			row.add_child(recipe_lbl)
		else:
			var reveal_btn: Button = Button.new()
			reveal_btn.text = "?"
			reveal_btn.focus_mode = Control.FOCUS_NONE
			reveal_btn.add_theme_font_override("font", GAME_FONT)

			var dynamic_cost: int = _get_reveal_cost(order)
			reveal_btn.disabled = money < dynamic_cost

			if not reveal_btn.disabled:
				reveal_btn.mouse_entered.connect(_show_instant_tooltip.bind("Reveal recipe ($" + str(dynamic_cost) + ")", Color("ff4e4e")))
				reveal_btn.mouse_exited.connect(_hide_instant_tooltip)

			reveal_btn.pressed.connect(_on_reveal_recipe_pressed.bind(order))
			row.add_child(reveal_btn)
			order["reveal_button"] = reveal_btn

		orders_box.add_child(row)


func _get_recipe_string(cheese_name: String) -> String:
	var clean_name: String = cheese_name.strip_edges().to_lower()
	var ingredients: Array[String] = []

	for cheese: Dictionary in CheeseDB.CHEESES:
		if cheese.get("name", "").strip_edges().to_lower() == clean_name:
			for id: String in cheese.get("recipe", []):
				if CheeseDB.TILES.has(id):
					ingredients.append(CheeseDB.TILES[id]["label"])
				else:
					ingredients.append(id)
			break

	if not ingredients.is_empty():
		return "+".join(ingredients)
	return "???"


# ---------------------------------------------------------------------------
# Musical ingredient hints
# Mirrors sound_test.gd: the player picks a target cheese, its riff loops, and
# the pot drives the selection — correct ingredients fill in the tune (right
# note), wrong ones tack on an off-key clash (wrong note).
# ---------------------------------------------------------------------------

# Recipe (Array of tile ids) for a cheese name, or [] if it isn't in CheeseDB.
func _recipe_for(cheese_name: String) -> Array:
	for cheese: Dictionary in CheeseDB.CHEESES:
		if cheese["name"] == cheese_name:
			return cheese["recipe"]
	return []


# Rebuild the "Tune to:" options from the distinct cheeses this level orders,
# keeping only those CheeseDB knows a recipe for, then tune to the first one.
func _populate_target_select() -> void:
	target_cheeses.clear()
	var seen: Dictionary = {}
	for pending: Dictionary in pending_orders:
		var cname: String = pending["cheese"]
		if seen.has(cname):
			continue
		if _recipe_for(cname).is_empty():
			continue   # unknown cheese (no recipe) — can't build a note map
		seen[cname] = true
		target_cheeses.append(cname)

	target_select.clear()
	for cname: String in target_cheeses:
		target_select.add_item(cname)

	if target_cheeses.is_empty():
		music_target = ""
		transport_label.text = "♪ —"
		dots_label.text = ""
		return

	target_select.select(0)
	_select_music_target(0)   # select() doesn't emit item_selected


# Port of sound_test.gd:_select_target — load the target cheese's riff.
func _select_music_target(index: int) -> void:
	if index < 0 or index >= target_cheeses.size():
		return
	var cheese_name: String = target_cheeses[index]
	var recipe: Array = _recipe_for(cheese_name)
	music_target = cheese_name
	transport_label.text = "♪ %s — \"%s\"" % [cheese_name, Songs.title_for(cheese_name)]
	sequencer.load_song(recipe, Songs.phrases_for(cheese_name, recipe))
	sequencer.set_selected(pot)


# Looping-riff playhead: a compact dot row with the current step glowing.
func _on_step_advanced(index: int, total: int, _sounding: bool) -> void:
	var s: String = ""
	for i: int in total:
		s += "●" if i == index else "·"
	dots_label.text = s


# ---------------------------------------------------------------------------
# Audio integration hooks — drive the sequencer selection from the pot.
# ---------------------------------------------------------------------------
func _on_pot_add(_id: String) -> void:
	if sequencer:
		sequencer.set_selected(pot)


func _on_pot_clear() -> void:
	if sequencer:
		sequencer.set_selected(pot)


func _on_cook_start(_target: String) -> void:
	pass


func _on_cook_success(_cheese_name: String) -> void:
	pass


func _on_cook_fail() -> void:
	pass
