extends Control
## Cheezy Tunes — main menu. Title, big pixel cheese, Start / Credits / Quit.

const TITLE_FONT = preload("res://Fonts/PPEditorialNew-Ultrabold-BF644b21500840c.otf")
const BODY_FONT = preload("res://Fonts/PPEditorialNew-Regular-BF644b214ff145f.otf")
const DEFAULT_ITEM_TEXTURE = preload("res://Sprites/milkBucket.png")

const SPRITE_SIZE := 64
const LANE_WIDTH := 96
const SPRITES_PER_LANE := 5
const MIN_FALL_SPEED := 40.0
const MAX_FALL_SPEED := 90.0

var _falling: Array = []

const BG_COLOR := Color("1a140b")
const ACCENT_YELLOW := Color("f4d06f")
const ACCENT_RED := Color("8a2f2f")
const TEXT_DARK := Color("221c10")

# Classic cartoon cheese wedge: pointed top, wide rind base, two clear holes.
# 18 wide x 14 tall, scaled up for the hero slot.
const CHEESE_PATTERN := [
	"........YYY.......",
	".......YYYYY......",
	"......YYYYYYY.....",
	".....YYYYYYYYY....",
	"....YYYYYHHYYYY...",
	"...YYYYYHOOHYYYY..",
	"..YYYYYYYHHYYYYYY.",
	".YYYYYYYYYYYYYYYYY",
	"YYYYHHYYYYYYYYYYYY",
	"YYYHOOHYYYHHYYYYYY",
	"YYYYHHYYYHOOHYYYYY",
	"YYYYYYYYYYHHYYYYYY",
	"RRRRRRRRRRRRRRRRRR",
	"DDDDDDDDDDDDDDDDDD",
]

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"Y": Color("f6c84c"),  # bright cheddar yellow
	"H": Color("c47e1a"),  # hole ring / shadow
	"O": Color("5a3a0a"),  # hole interior (dark)
	"R": Color("e8a83b"),  # rind highlight
	"D": Color("8a5a18"),  # rind dark
}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_falling_lanes()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	center.add_child(col)

	# --- title with drop-shadow ---
	col.add_child(_make_title())

	# --- pixel cheese hero ---
	var cheese_tex := PixelArt.texture_from_pattern(CHEESE_PATTERN, PALETTE, 6)
	var cheese_rect := TextureRect.new()
	cheese_rect.texture = cheese_tex
	cheese_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cheese_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cheese_rect.custom_minimum_size = Vector2(96 * 2, 72 * 2)
	col.add_child(cheese_rect)

	# --- buttons ---
	col.add_child(_make_menu_button("Start", _on_start))
	col.add_child(_make_menu_button("Credits", _on_credits))
	col.add_child(_make_menu_button("Quit", _on_quit))


func _make_title() -> Control:
	# Cheap drop-shadow: red label behind, yellow label in front, offset.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(640, 100)

	var shadow := Label.new()
	shadow.text = "CHEESY TUNES"
	shadow.add_theme_font_override("font", TITLE_FONT)
	shadow.add_theme_font_size_override("font_size", 84)
	shadow.add_theme_color_override("font_color", ACCENT_RED)
	shadow.position = Vector2(6, 6)
	shadow.size = Vector2(640, 100)
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(shadow)

	var front := Label.new()
	front.text = "CHEESY TUNES"
	front.add_theme_font_override("font", TITLE_FONT)
	front.add_theme_font_size_override("font_size", 84)
	front.add_theme_color_override("font_color", ACCENT_YELLOW)
	front.size = Vector2(640, 100)
	front.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(front)

	return wrap


func _make_menu_button(label: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(280, 56)
	btn.add_theme_font_override("font", BODY_FONT)
	btn.add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ACCENT_YELLOW.lightened(0.1) if state == "hover" else ACCENT_YELLOW
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(10)
		if state == "hover" or state == "pressed":
			sb.set_border_width_all(3)
			sb.border_color = TEXT_DARK
		btn.add_theme_stylebox_override(state, sb)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, TEXT_DARK)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(handler)
	return btn


func _build_falling_lanes() -> void:
	_spawn_lane(true)
	_spawn_lane(false)
	set_process(true)


func _spawn_lane(is_left: bool) -> void:
	var viewport_h := get_viewport_rect().size.y
	for i in range(SPRITES_PER_LANE):
		var rect := TextureRect.new()
		rect.texture = _random_ingredient_texture()
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var initial_y := lerpf(-float(SPRITE_SIZE), viewport_h, float(i) / float(SPRITES_PER_LANE))
		rect.position = Vector2(_random_lane_x(is_left), initial_y)
		add_child(rect)
		_falling.append({
			"node": rect,
			"speed": randf_range(MIN_FALL_SPEED, MAX_FALL_SPEED),
			"is_left": is_left,
		})


func _process(delta: float) -> void:
	var viewport_h := get_viewport_rect().size.y
	for entry in _falling:
		var node: TextureRect = entry["node"]
		node.position.y += entry["speed"] * delta
		if node.position.y > viewport_h:
			node.position.y = -float(SPRITE_SIZE)
			node.position.x = _random_lane_x(entry["is_left"])
			entry["speed"] = randf_range(MIN_FALL_SPEED, MAX_FALL_SPEED)
			node.texture = _random_ingredient_texture()


func _random_lane_x(is_left: bool) -> float:
	var viewport_w := get_viewport_rect().size.x
	var jitter := randf_range(0.0, float(LANE_WIDTH - SPRITE_SIZE))
	return jitter if is_left else viewport_w - LANE_WIDTH + jitter


func _random_ingredient_texture() -> Texture2D:
	var ids := CheeseDB.TILES.keys()
	var data = CheeseDB.TILES[ids[randi() % ids.size()]]
	if data.has("texture") and data["texture"] is Texture2D:
		return data["texture"]
	if data.has("texture") and data["texture"] is String and data["texture"] != "":
		return load(data["texture"])
	return DEFAULT_ITEM_TEXTURE


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_credits() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")


func _on_quit() -> void:
	get_tree().quit()
