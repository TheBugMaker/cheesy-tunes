extends Control
## Cheezy Tunes — pot-and-cook cheese factory.
## Buy ingredients with money, click them into the central pot, press Cook to
## produce a wheel. Wheels directly fulfill matching orders from a timed queue.
## Wastes ingredients if there is no matching active order or recipe mismatch.

# --- Custom Font Preload ---
const GAME_FONT = preload("res://Fonts/PPEditorialNew-Regular-BF644b214ff145f.otf")
const DEFAULT_ITEM_TEXTURE = preload("res://Sprites/milkBucket.png")

const START_MONEY := 50
const COOK_TIME := 4.0
const ORDER_TIME_MIN := 20.0
const ORDER_TIME_MAX := 35.0
const MAX_ORDERS := 4

const PRIORITY_SPAWN_INTERVAL_MIN := 45.0
const PRIORITY_SPAWN_INTERVAL_MAX := 90.0
const PRIORITY_TIME := 15.0
const PRIORITY_PENALTY := 20
const PRIORITY_PAYOUT_BONUS := 15

# --- runtime state ---
var money: int = START_MONEY
var score: int = 0
var inventory: Dictionary = {}        # ingredient_id -> int
var pot: Array[String] = []           # ingredient_ids in click order
var cooking: bool = false
var cook_progress: float = 0.0
var cook_target: String = ""          # cheese name, "" if mismatch
var orders: Array = []                # {cheese, time_left, time_max, payout, priority, time_label, reveal_button, revealed}
var running: bool = false
var _priority_timer: float = 0.0

# --- node references ---
var money_label: Label
var score_label: Label
var orders_box: VBoxContainer
var inventory_container: GridContainer
var plate_canvas: Control
var pot_progress: ProgressBar
var cook_btn: Button
var clear_btn: Button
var overlay: Panel
var overlay_label: Label
var penalty_label: Label

# --- custom tooltip references ---
var custom_tooltip: PanelContainer
var custom_tooltip_name: Label
var custom_tooltip_price: Label

var inv_labels: Dictionary = {}       # ingredient_id -> Label (count in inventory slot)
var buy_buttons: Dictionary = {}      # ingredient_id -> Button (buy +)


func _ready() -> void:
	randomize()
	_priority_timer = randf_range(PRIORITY_SPAWN_INTERVAL_MIN, PRIORITY_SPAWN_INTERVAL_MAX)
	_build_ui()
	_init_inventory()
	_refill_orders()
	running = true
	_refresh_all()


func _process(delta: float) -> void:
	if not running:
		return
		
	# Frame-by-frame mouse tracking for instant tooltips
	if custom_tooltip and custom_tooltip.visible:
		custom_tooltip.global_position = get_global_mouse_position() + Vector2(16, 16)
		
	_tick_cook(delta)
	_tick_orders(delta)
	_tick_priority_timer(delta)
	if _is_game_over():
		_show_game_over()


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
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	# --- top bar: money | score ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	col.add_child(top)
	money_label = _make_label("Money: $%d" % money, 24)
	top.add_child(money_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	score_label = _make_label("Score: 0", 24)
	top.add_child(score_label)

	penalty_label = _make_label("", 17)
	penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	penalty_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	penalty_label.visible = false
	col.add_child(penalty_label)

	# --- middle: layout splitter ---
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)

	# --- left column: ORDERS & INVENTORY ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	mid.add_child(left)
	
	left.add_child(_make_label("ORDERS", 20))
	orders_box = VBoxContainer.new()
	orders_box.add_theme_constant_override("separation", 6)
	left.add_child(_panel(orders_box, Color("3a2f1c")))
	
	left.add_child(_make_label("INVENTORY", 20))
	inventory_container = GridContainer.new()
	inventory_container.columns = 3
	inventory_container.add_theme_constant_override("h_separation", 8)
	inventory_container.add_theme_constant_override("v_separation", 8)
	left.add_child(_panel(inventory_container, Color("241d12")))

	# --- right column: pot area ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	mid.add_child(right)
	right.add_child(_build_pot_area())

	# --- Build the Grid Layout contents ---
	_build_buy_strip()

	# --- Instant Custom Tooltip Box ---
	custom_tooltip = PanelContainer.new()
	var tooltip_sb := StyleBoxFlat.new()
	tooltip_sb.bg_color = Color("111111", 0.95)
	tooltip_sb.set_border_width_all(1)
	tooltip_sb.border_color = Color("555555")
	tooltip_sb.set_content_margin_all(8)
	custom_tooltip.add_theme_stylebox_override("panel", tooltip_sb)
	custom_tooltip.visible = false
	custom_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tooltip_vbox := VBoxContainer.new()
	tooltip_vbox.add_theme_constant_override("separation", 2)
	custom_tooltip.add_child(tooltip_vbox)
	
	custom_tooltip_name = Label.new()
	custom_tooltip_name.add_theme_font_override("font", GAME_FONT)
	custom_tooltip_name.add_theme_font_size_override("font_size", 14)
	custom_tooltip_name.add_theme_color_override("font_color", Color("ffffff")) 
	tooltip_vbox.add_child(custom_tooltip_name)
	
	custom_tooltip_price = Label.new()
	custom_tooltip_price.add_theme_font_override("font", GAME_FONT)
	custom_tooltip_price.add_theme_font_size_override("font_size", 13)
	custom_tooltip_price.add_theme_color_override("font_color", Color("ff5555")) 
	tooltip_vbox.add_child(custom_tooltip_price)
	
	add_child(custom_tooltip)

	_build_overlay()


func _build_pot_area() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.add_child(_make_label("Plate — click your inventory items to place them, then Cook", 18))

	var pot_center_wrap := CenterContainer.new()
	pot_center_wrap.add_child(_build_pot_center())
	wrap.add_child(pot_center_wrap)

	var btn_row := HBoxContainer.new()
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
	clear_btn.text = "Clear (waste)"
	clear_btn.custom_minimum_size = Vector2(140, 48)
	clear_btn.add_theme_font_override("font", GAME_FONT)
	clear_btn.add_theme_font_size_override("font_size", 18)
	clear_btn.pressed.connect(_on_clear_pot)
	btn_row.add_child(clear_btn)

	return wrap


func _build_pot_center() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3d2f1a")
	sb.set_corner_radius_all(80)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color("7a5a2a")
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(180, 160)

	var container := Control.new()
	container.custom_minimum_size = Vector2(160, 140)
	panel.add_child(container)

	# Canvas container for holding dynamic visual food items
	plate_canvas = Control.new()
	plate_canvas.custom_minimum_size = Vector2(160, 140)
	container.add_child(plate_canvas)

	pot_progress = ProgressBar.new()
	pot_progress.show_percentage = false
	pot_progress.min_value = 0.0
	pot_progress.max_value = 1.0
	pot_progress.value = 0.0
	pot_progress.custom_minimum_size = Vector2(140, 12)
	pot_progress.visible = false
	
	# FIXED LINE BELOW: Changed PRESET_BOTTOM_CENTER to PRESET_CENTER_BOTTOM
	pot_progress.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pot_progress.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pot_progress.position = Vector2(10, 120)
	container.add_child(pot_progress)
	
	return panel


func _build_buy_strip() -> void:
	for id in _all_ingredient_ids():
		var data: Dictionary = CheeseDB.TILES[id]
		var price: int = CheeseDB.INGREDIENT_PRICES[id]
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(76, 76)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1a140b")
		sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", sb)
		
		# Image Layer - Defaults to milkBucket.png unless overridden
		var tex_btn := TextureButton.new()
		tex_btn.custom_minimum_size = Vector2(76, 76)
		tex_btn.ignore_texture_size = true
		tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		if data.has("texture") and data["texture"] is Texture2D:
			tex_btn.texture_normal = data["texture"]
		elif data.has("texture") and data["texture"] is String and data["texture"] != "":
			tex_btn.texture_normal = load(data["texture"])
		else:
			tex_btn.texture_normal = DEFAULT_ITEM_TEXTURE
			
		# Clicking the card asset now pushes it straight to the plate canvas
		tex_btn.pressed.connect(_on_ring_clicked.bind(id))
		card.add_child(tex_btn)
			
		# Structural UI Info Layer Overlaid cleanly above the clickable asset
		var margin_container := MarginContainer.new()
		margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin_container.add_theme_constant_override("margin_left", 6)
		margin_container.add_theme_constant_override("margin_right", 6)
		margin_container.add_theme_constant_override("margin_top", 6)
		margin_container.add_theme_constant_override("margin_bottom", 6)
		card.add_child(margin_container)
		
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin_container.add_child(vbox)
		
		var top_spacer := Control.new()
		top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(top_spacer)
		
		var bottom_row := HBoxContainer.new()
		bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(bottom_row)
		
		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.add_theme_font_override("font", GAME_FONT)
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		count_lbl.add_theme_constant_override("outline_size", 5) 
		bottom_row.add_child(count_lbl)
		inv_labels[id] = count_lbl
		
		var mid_spacer := Control.new()
		mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_row.add_child(mid_spacer)
		
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(22, 22)
		btn.focus_mode = Control.FOCUS_NONE
		
		btn.add_theme_font_override("font", GAME_FONT)
		btn.add_theme_color_override("font_color", Color("4eff4e"))
		btn.add_theme_color_override("font_hover_color", Color("a3ffa3"))
		btn.add_theme_font_size_override("font_size", 14)
		
		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color("111111", 0.6)
		btn_sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_sb)
		var btn_sb_h := btn_sb.duplicate()
		btn_sb_h.bg_color = Color("222222", 0.8)
		btn.add_theme_stylebox_override("hover", btn_sb_h)
		
		btn.mouse_entered.connect(_show_instant_tooltip.bind(data["label"], "$%d" % price))
		btn.mouse_exited.connect(_hide_instant_tooltip)
		
		btn.pressed.connect(_on_buy.bind(id))
		bottom_row.add_child(btn)
		buy_buttons[id] = btn
		
		inventory_container.add_child(card)


func _build_overlay() -> void:
	overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0.82)
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
	var title := _make_label("Bankrupt!", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	overlay_label = _make_label("", 22)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_label)
	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(200, 56)
	restart_btn.add_theme_font_override("font", GAME_FONT)
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(restart)
	box.add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 48)
	menu_btn.add_theme_font_override("font", GAME_FONT)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(_on_return_to_menu)
	box.add_child(menu_btn)


func _on_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", GAME_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _panel(child: Control, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(child)
	return p


# ---------------------------------------------------------------------------
# Ingredient sets
# ---------------------------------------------------------------------------
func _all_ingredient_ids() -> PackedStringArray:
	var seen := {}
	for cheese in CheeseDB.get_active_cheeses():
		for id in cheese["recipe"]:
			seen[id] = true
	var out := PackedStringArray()
	for id in CheeseDB.TILES.keys():
		if seen.has(id):
			out.append(id)
	return out


# ---------------------------------------------------------------------------
# Game loop pieces
# ---------------------------------------------------------------------------
func _init_inventory() -> void:
	for id in _all_ingredient_ids():
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
	_on_pot_clear()
	pot.clear()
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
		var matching_order_idx := -1
		for i in range(orders.size()):
			if orders[i]["cheese"] == cook_target:
				matching_order_idx = i
				break
				
		if matching_order_idx != -1:
			var completed_order = orders[matching_order_idx]
			money += int(completed_order["payout"])
			score += 1
			_on_cook_success(cook_target)
			orders.remove_at(matching_order_idx)
			_refresh_money()
			_refresh_score()
			_refresh_orders()
			_refill_orders()
		else:
			_on_cook_fail()
	else:
		_on_cook_fail()
		
	pot.clear()
	cooking = false
	cook_progress = 0.0
	pot_progress.visible = false
	cook_btn.disabled = false
	clear_btn.disabled = false
	cook_target = ""
	_refresh_pot()


func _tick_orders(delta: float) -> void:
	var i := orders.size() - 1
	var structure_changed := false
	
	while i >= 0:
		orders[i]["time_left"] -= delta
		if orders[i]["time_left"] <= 0.0:
			if orders[i].get("priority", false):
				money = max(0, money - PRIORITY_PENALTY)
				_show_penalty_flash()
				_refresh_money()
			orders.remove_at(i)
			structure_changed = true
		else:
			if orders[i].has("time_label") and is_instance_valid(orders[i]["time_label"]):
				var lbl: Label = orders[i]["time_label"]
				lbl.text = "%ds" % int(ceil(orders[i]["time_left"]))
				if orders[i]["time_left"] < orders[i]["time_max"] * 0.33:
					lbl.modulate = Color(1, 0.55, 0.55)
				else:
					lbl.modulate = Color(1, 1, 1)
		i -= 1
		
	if structure_changed or orders.size() < MAX_ORDERS:
		_refill_orders()
		_refresh_orders()


func _refill_orders() -> void:
	var active := CheeseDB.get_active_cheeses()
	if active.is_empty():
		return
	var normal_count := 0
	for o in orders:
		if not o.get("priority", false):
			normal_count += 1
	var spawned_new := false
	while normal_count < MAX_ORDERS:
		var cheese: Dictionary = active[randi() % active.size()]
		var cheese_name: String = cheese["name"]
		var rng: Vector2i = CheeseDB.CHEESE_PAYOUT_RANGE.get(cheese_name, Vector2i(20, 30))
		var payout: int = rng.x + (randi() % max(1, rng.y - rng.x + 1))
		var t := randf_range(ORDER_TIME_MIN, ORDER_TIME_MAX)
		orders.append({
			"cheese": cheese_name,
			"time_left": t,
			"time_max": t,
			"payout": payout,
			"priority": false,
			"revealed": false,
		})
		normal_count += 1
		spawned_new = true

	if spawned_new:
		_refresh_orders()


func _tick_priority_timer(delta: float) -> void:
	_priority_timer -= delta
	if _priority_timer <= 0.0:
		_priority_timer = randf_range(PRIORITY_SPAWN_INTERVAL_MIN, PRIORITY_SPAWN_INTERVAL_MAX)
		_spawn_priority_order()


func _spawn_priority_order() -> void:
	# Only one priority order at a time
	for o in orders:
		if o.get("priority", false):
			return
	var active := CheeseDB.get_active_cheeses()
	if active.is_empty():
		return
	var cheese: Dictionary = active[randi() % active.size()]
	var cheese_name: String = cheese["name"]
	var rng: Vector2i = CheeseDB.CHEESE_PAYOUT_RANGE.get(cheese_name, Vector2i(20, 30))
	var payout: int = rng.x + (randi() % max(1, rng.y - rng.x + 1)) + PRIORITY_PAYOUT_BONUS
	orders.insert(0, {
		"cheese": cheese_name,
		"time_left": PRIORITY_TIME,
		"time_max": PRIORITY_TIME,
		"payout": payout,
		"priority": true,
		"revealed": false,
	})
	_refresh_orders()


func _show_penalty_flash() -> void:
	penalty_label.text = "!! Priority order missed — $%d penalty" % PRIORITY_PENALTY
	penalty_label.modulate = Color(1, 1, 1, 1)
	penalty_label.visible = true
	var tween := create_tween()
	tween.tween_property(penalty_label, "modulate", Color(1, 1, 1, 0), 2.5)
	tween.tween_callback(func(): penalty_label.visible = false)


func _match_recipe(current_pot: Array[String]) -> String:
	for cheese in CheeseDB.get_active_cheeses():
		if _same_set(current_pot, cheese["recipe"]):
			return cheese["name"]
	return ""


func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for item in b:
		if not a.has(item):
			return false
	return true


# ---------------------------------------------------------------------------
# Hint Button Trigger Callbacks
# ---------------------------------------------------------------------------
func _on_reveal_recipe_pressed(order: Dictionary) -> void:
	if money < 5:
		return
	money -= 5
	order["revealed"] = true
	_refresh_all()


func _update_hint_buttons_disabled_state() -> void:
	for order in orders:
		if order.has("reveal_button") and is_instance_valid(order["reveal_button"]):
			order["reveal_button"].disabled = money < 5


# ---------------------------------------------------------------------------
# Custom Tooltip Toggles
# ---------------------------------------------------------------------------
func _show_instant_tooltip(item_name: String, price_text: String) -> void:
	if custom_tooltip_name and custom_tooltip_price and custom_tooltip:
		custom_tooltip_name.text = item_name
		custom_tooltip_price.text = price_text
		custom_tooltip.visible = true


func _hide_instant_tooltip() -> void:
	if custom_tooltip:
		custom_tooltip.visible = false


# ---------------------------------------------------------------------------
# Game over / restart
# ---------------------------------------------------------------------------
func _is_game_over() -> bool:
	if cooking:
		return false
	if not pot.is_empty():
		return false
	for order in orders:
		if _can_afford_recipe(order["cheese"]):
			return false
	return true


func _can_afford_recipe(cheese_name: String) -> bool:
	for cheese in CheeseDB.CHEESES:
		if cheese["name"] != cheese_name:
			continue
		var needed: Dictionary = {}
		for id in cheese["recipe"]:
			needed[id] = int(needed.get(id, 0)) + 1
		var cash := money
		for id in needed.keys():
			var have: int = int(inventory.get(id, 0))
			var short: int = max(0, int(needed[id]) - have)
			cash -= short * int(CheeseDB.INGREDIENT_PRICES[id])
			if cash < 0:
				return false
		return true
	return false


func _show_game_over() -> void:
	running = false
	overlay_label.text = "You fulfilled %d order%s.\nFinal money: $%d" % [
		score, ("" if score == 1 else "s"), money,
	]
	overlay.visible = true


func restart() -> void:
	money = START_MONEY
	score = 0
	pot.clear()
	cooking = false
	cook_progress = 0.0
	cook_target = ""
	for id in inventory.keys():
		inventory[id] = 0
	orders.clear()
	_priority_timer = randf_range(PRIORITY_SPAWN_INTERVAL_MIN, PRIORITY_SPAWN_INTERVAL_MAX)
	_refill_orders()
	pot_progress.visible = false
	cook_btn.disabled = false
	clear_btn.disabled = false
	overlay.visible = false
	running = true
	_refresh_all()


# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_refresh_money()
	_refresh_score()
	_refresh_inventory()
	_refresh_pot()
	_refresh_orders()


func _refresh_money() -> void:
	money_label.text = "Money: $%d" % money


func _refresh_score() -> void:
	score_label.text = "Score: %d" % score


func _refresh_inventory() -> void:
	for id in inv_labels.keys():
		inv_labels[id].text = str(inventory.get(id, 0))
		var price: int = CheeseDB.INGREDIENT_PRICES[id]
		buy_buttons[id].disabled = money < price


func _refresh_pot() -> void:
	# Clear plate display sprites 
	for child in plate_canvas.get_children():
		child.queue_free()
		
	# Re-populate plate visually based on the item index quadrants
	for i in range(pot.size()):
		var img := TextureRect.new()
		img.texture = DEFAULT_ITEM_TEXTURE
		img.custom_minimum_size = Vector2(40, 40)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Exact targeted quad slots within canvas window dimensions (160x140)
		var base_pos := Vector2.ZERO
		match i % 4:
			0: base_pos = Vector2(18, 15)   # 1st: Top Left
			1: base_pos = Vector2(102, 75)  # 2nd: Bottom Right
			2: base_pos = Vector2(18, 75)   # 3rd: Bottom Left
			3: base_pos = Vector2(102, 15)  # 4th: Top Right
			
		# Sprinkle gentle placement variation across targeted quadrants
		var jitter := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		img.position = base_pos + jitter
		plate_canvas.add_child(img)

	cook_btn.disabled = cooking or pot.is_empty()
	clear_btn.disabled = cooking or pot.is_empty()


func _refresh_orders() -> void:
	if custom_tooltip:
		custom_tooltip.visible = false

	for child in orders_box.get_children():
		child.queue_free()
	if orders.is_empty():
		var empty := _make_label("(no orders)", 14)
		empty.modulate = Color(1, 1, 1, 0.5)
		orders_box.add_child(empty)
		return
		
	for order in orders:
		var is_priority: bool = order.get("priority", false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var cheese_text := ("!! " if is_priority else "") + (order["cheese"] as String)
		var name_lbl := _make_label(cheese_text, 16)
		name_lbl.custom_minimum_size = Vector2(110, 0)
		if is_priority:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
		row.add_child(name_lbl)
		
		var time_lbl := _make_label("%ds" % int(ceil(order["time_left"])), 16)
		time_lbl.custom_minimum_size = Vector2(48, 0)
		if is_priority or order["time_left"] < order["time_max"] * 0.33:
			time_lbl.modulate = Color(1, 0.45, 0.45)
		row.add_child(time_lbl)
		order["time_label"] = time_lbl
		
		var pay_lbl := _make_label("+$%d" % int(order["payout"]), 16)
		pay_lbl.modulate = Color(0.7, 1.0, 0.7)
		row.add_child(pay_lbl)
		
		if order.get("revealed", false):
			var recipe_string := _get_recipe_string(order["cheese"])
			var recipe_lbl := _make_label("[%s]" % recipe_string, 13)
			recipe_lbl.modulate = Color("e0cb9b") 
			row.add_child(recipe_lbl)
		else:
			var reveal_btn := Button.new()
			reveal_btn.text = "?" 
			reveal_btn.focus_mode = Control.FOCUS_NONE
			reveal_btn.add_theme_font_override("font", GAME_FONT)
			reveal_btn.disabled = money < 5
			
			if not reveal_btn.disabled:
				reveal_btn.mouse_entered.connect(_show_instant_tooltip.bind("Reveal Recipe", "-$5"))
				reveal_btn.mouse_exited.connect(_hide_instant_tooltip)
				
			reveal_btn.pressed.connect(_on_reveal_recipe_pressed.bind(order))
			row.add_child(reveal_btn)
			order["reveal_button"] = reveal_btn

		if is_priority:
			var bg := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.38, 0.1, 0.07)
			sb.set_corner_radius_all(4)
			sb.set_content_margin_all(4)
			bg.add_theme_stylebox_override("panel", sb)
			bg.add_child(row)
			orders_box.add_child(bg)
		else:
			orders_box.add_child(row)


func _get_recipe_string(cheese_name: String) -> String:
	var clean_name := cheese_name.strip_edges().to_lower()
	var ingredients: Array[String] = []
	
	for cheese in CheeseDB.CHEESES:
		if cheese.get("name", "").strip_edges().to_lower() == clean_name:
			for id in cheese.get("recipe", []):
				if CheeseDB.TILES.has(id):
					ingredients.append(CheeseDB.TILES[id]["label"])
				else:
					ingredients.append(id)
			break
			
	if not ingredients.is_empty():
		return "+".join(ingredients)
	return "???"


# ---------------------------------------------------------------------------
# Audio integration hooks
# ---------------------------------------------------------------------------
func _on_pot_add(id: String) -> void:
	var role: String = CheeseDB.MUSIC_COMPONENT.get(id, "?")
	print("[audio] layer +%s (%s)" % [id, role])


func _on_pot_clear() -> void:
	print("[audio] pot cleared — silence")


func _on_cook_start(target: String) -> void:
	print("[audio] cook start, target=", target if target != "" else "<mismatch>")


func _on_cook_success(cheese_name: String) -> void:
	var tune: String = CheeseDB.CHEESE_TUNE.get(cheese_name, "")
	print("[audio] clean chiptune for %s -> %s" % [cheese_name, tune])


func _on_cook_fail() -> void:
	print("[audio] distorted chiptune (wrong recipe)")
