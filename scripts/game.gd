extends Control
## Cheezy Tunes — pot-and-cook cheese factory.
## Buy ingredients with money, click them into the central pot, press Cook to
## produce a wheel. Wheels auto-fulfill matching orders from a timed queue.
## Wrong recipes waste the ingredients in the pot.

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
var stock: Dictionary = {}            # cheese_name -> int
var orders: Array = []                # {cheese, time_left, time_max, payout, priority}
var running: bool = false
var _priority_timer: float = 0.0

# --- node references ---
var money_label: Label
var score_label: Label
var orders_box: VBoxContainer
var stock_box: VBoxContainer
var pot_label: Label
var pot_progress: ProgressBar
var cook_btn: Button
var clear_btn: Button
var inventory_row: HBoxContainer
var ingredient_ring: GridContainer
var overlay: Panel
var overlay_label: Label
var penalty_label: Label

var inv_labels: Dictionary = {}       # ingredient_id -> Label (count in inventory row)
var buy_buttons: Dictionary = {}      # ingredient_id -> Button (buy [+])
var ring_buttons: Dictionary = {}     # ingredient_id -> Button (click-into-pot)
var stock_labels: Dictionary = {}     # cheese_name -> Label


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
	_tick_cook(delta)
	_tick_orders(delta)
	_tick_priority_timer(delta)
	_auto_fulfill()
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

	# --- middle: orders+stock (left) | pot (right) ---
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	mid.add_child(left)
	left.add_child(_make_label("Orders:", 20))
	orders_box = VBoxContainer.new()
	orders_box.add_theme_constant_override("separation", 6)
	left.add_child(_panel(orders_box, Color("3a2f1c")))
	left.add_child(_make_label("Stock:", 20))
	stock_box = VBoxContainer.new()
	stock_box.add_theme_constant_override("separation", 4)
	left.add_child(_panel(stock_box, Color("241d12")))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	mid.add_child(right)
	right.add_child(_build_pot_area())

	# --- bottom: buy strip ---
	col.add_child(_make_label("Buy ingredients:", 18))
	inventory_row = HBoxContainer.new()
	inventory_row.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 78)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(inventory_row)
	col.add_child(scroll)
	_build_buy_strip()

	_build_overlay()


func _build_pot_area() -> Control:
	# Pot on top, then a flow of every active ingredient below it so nothing is hidden.
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.add_child(_make_label("Pot — click ingredients to compose, then Cook", 18))

	var pot_center_wrap := CenterContainer.new()
	pot_center_wrap.add_child(_build_pot_center())
	wrap.add_child(pot_center_wrap)

	wrap.add_child(_make_label("Ingredients on hand:", 16))

	ingredient_ring = GridContainer.new()
	ingredient_ring.columns = 4
	ingredient_ring.add_theme_constant_override("h_separation", 8)
	ingredient_ring.add_theme_constant_override("v_separation", 8)
	wrap.add_child(ingredient_ring)

	for id in _all_ingredient_ids():
		ingredient_ring.add_child(_build_ring_button(id))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(btn_row)
	cook_btn = Button.new()
	cook_btn.text = "Cook"
	cook_btn.custom_minimum_size = Vector2(140, 48)
	cook_btn.add_theme_font_size_override("font_size", 20)
	cook_btn.pressed.connect(_on_cook_pressed)
	btn_row.add_child(cook_btn)
	clear_btn = Button.new()
	clear_btn.text = "Clear (waste)"
	clear_btn.custom_minimum_size = Vector2(140, 48)
	clear_btn.add_theme_font_size_override("font_size", 18)
	clear_btn.pressed.connect(_on_clear_pot)
	btn_row.add_child(clear_btn)

	return wrap


func _build_pot_center() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3d2f1a")
	sb.set_corner_radius_all(60)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color("7a5a2a")
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(180, 160)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	pot_label = _make_label("(empty)", 14)
	pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pot_label.custom_minimum_size = Vector2(160, 80)
	inner.add_child(pot_label)

	pot_progress = ProgressBar.new()
	pot_progress.show_percentage = false
	pot_progress.min_value = 0.0
	pot_progress.max_value = 1.0
	pot_progress.value = 0.0
	pot_progress.custom_minimum_size = Vector2(150, 16)
	pot_progress.visible = false
	inner.add_child(pot_progress)
	return panel


func _build_ring_button(id: String) -> Button:
	var data: Dictionary = CheeseDB.TILES[id]
	var btn := Button.new()
	btn.text = data["label"]
	btn.custom_minimum_size = Vector2(130, 56)
	btn.focus_mode = Control.FOCUS_NONE
	_style_tile_button(btn, data["color"])
	btn.pressed.connect(_on_ring_clicked.bind(id))
	ring_buttons[id] = btn
	return btn


func _build_buy_strip() -> void:
	for id in _all_ingredient_ids():
		var data: Dictionary = CheeseDB.TILES[id]
		var price: int = CheeseDB.INGREDIENT_PRICES[id]
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1a140b")
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(140, 64)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = data["color"]
		swatch.custom_minimum_size = Vector2(14, 14)
		row.add_child(swatch)
		var name_lbl := _make_label("%s  $%d" % [data["label"], price], 13)
		row.add_child(name_lbl)
		var bottom := HBoxContainer.new()
		bottom.add_theme_constant_override("separation", 6)
		v.add_child(bottom)
		var count_lbl := _make_label("x0", 14)
		bottom.add_child(count_lbl)
		inv_labels[id] = count_lbl
		var btn := Button.new()
		btn.text = "[+]"
		btn.custom_minimum_size = Vector2(40, 28)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_buy.bind(id))
		bottom.add_child(btn)
		buy_buttons[id] = btn
		inventory_row.add_child(card)


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
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(restart)
	box.add_child(restart_btn)


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
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


func _style_tile_button(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if state != "disabled" else color.darkened(0.4)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", Color("221c10"))
	btn.add_theme_color_override("font_hover_color", Color("221c10"))
	btn.add_theme_color_override("font_pressed_color", Color("221c10"))
	btn.add_theme_color_override("font_disabled_color", Color("221c10"))
	btn.add_theme_font_size_override("font_size", 15)


# ---------------------------------------------------------------------------
# Ingredient sets
# ---------------------------------------------------------------------------
## Ingredients used by any active cheese — what the player buys & composes with.
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
	for cheese in CheeseDB.get_active_cheeses():
		stock[cheese["name"]] = 0


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
		stock[cook_target] = int(stock.get(cook_target, 0)) + 1
		_on_cook_success(cook_target)
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
	_refresh_stock()


func _tick_orders(delta: float) -> void:
	var i := orders.size() - 1
	while i >= 0:
		orders[i]["time_left"] -= delta
		if orders[i]["time_left"] <= 0.0:
			if orders[i].get("priority", false):
				money = max(0, money - PRIORITY_PENALTY)
				_show_penalty_flash()
				_refresh_money()
			orders.remove_at(i)
		i -= 1
	_refill_orders()
	_refresh_orders()


func _auto_fulfill() -> void:
	var changed := false
	var i := 0
	while i < orders.size():
		var cheese: String = orders[i]["cheese"]
		if int(stock.get(cheese, 0)) > 0:
			stock[cheese] -= 1
			money += int(orders[i]["payout"])
			score += 1
			orders.remove_at(i)
			changed = true
		else:
			i += 1
	if changed:
		_refresh_money()
		_refresh_score()
		_refresh_stock()
		_refresh_orders()
		_refill_orders()


func _refill_orders() -> void:
	var active := CheeseDB.get_active_cheeses()
	if active.is_empty():
		return
	var normal_count := 0
	for o in orders:
		if not o.get("priority", false):
			normal_count += 1
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
		})
		normal_count += 1


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
	# Insert at front so auto-fulfill prefers it over normal orders of the same cheese
	orders.insert(0, {
		"cheese": cheese_name,
		"time_left": PRIORITY_TIME,
		"time_max": PRIORITY_TIME,
		"payout": payout,
		"priority": true,
	})
	_refresh_orders()


func _show_penalty_flash() -> void:
	penalty_label.text = "!! Priority order missed — $%d penalty" % PRIORITY_PENALTY
	penalty_label.modulate = Color(1, 1, 1, 1)
	penalty_label.visible = true
	var tween := create_tween()
	tween.tween_property(penalty_label, "modulate", Color(1, 1, 1, 0), 2.5)
	tween.tween_callback(func(): penalty_label.visible = false)


## Returns the cheese name whose recipe set-equals `current_pot`, or "" if none.
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
# Game over / restart
# ---------------------------------------------------------------------------
func _is_game_over() -> bool:
	if cooking:
		return false
	# Any stock we hold could still fulfill an order, so we're alive.
	for cheese_name in stock.keys():
		if int(stock[cheese_name]) > 0:
			return false
	# Pot already has ingredients in it — player can still try to cook.
	if not pot.is_empty():
		return false
	# Can we afford to make any cheese currently ordered?
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
	for cheese_name in stock.keys():
		stock[cheese_name] = 0
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
	_refresh_stock()
	_refresh_orders()


func _refresh_money() -> void:
	money_label.text = "Money: $%d" % money


func _refresh_score() -> void:
	score_label.text = "Score: %d" % score


func _refresh_inventory() -> void:
	for id in inv_labels.keys():
		inv_labels[id].text = "x%d" % int(inventory.get(id, 0))
		var price: int = CheeseDB.INGREDIENT_PRICES[id]
		buy_buttons[id].disabled = money < price


func _refresh_pot() -> void:
	if pot.is_empty():
		pot_label.text = "(empty)" if not cooking else "(cooking…)"
	else:
		var parts: Array[String] = []
		for id in pot:
			parts.append(CheeseDB.TILES[id]["label"])
		pot_label.text = ", ".join(parts)
	cook_btn.disabled = cooking or pot.is_empty()
	clear_btn.disabled = cooking or pot.is_empty()


func _refresh_stock() -> void:
	for child in stock_box.get_children():
		child.queue_free()
	stock_labels.clear()
	var any := false
	for cheese_name in stock.keys():
		var count: int = int(stock[cheese_name])
		if count <= 0:
			continue
		any = true
		var lbl := _make_label("%s x%d" % [cheese_name, count], 16)
		stock_box.add_child(lbl)
		stock_labels[cheese_name] = lbl
	if not any:
		var empty := _make_label("(none)", 14)
		empty.modulate = Color(1, 1, 1, 0.5)
		stock_box.add_child(empty)


func _refresh_orders() -> void:
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
		var pay_lbl := _make_label("+$%d" % int(order["payout"]), 16)
		pay_lbl.modulate = Color(0.7, 1.0, 0.7)
		row.add_child(pay_lbl)
		orders_box.add_child(row)


# ---------------------------------------------------------------------------
# Audio integration hooks (stubbed for v1).
# When chiptune assets land, wire these to AudioStreamPlayer nodes.
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
