extends Control
## Cheezy Tunes — credits. Six contributors, each with a small pixel-art avatar.

const TITLE_FONT = preload("res://Fonts/PPEditorialNew-Ultrabold-BF644b21500840c.otf")
const BODY_FONT = preload("res://Fonts/PPEditorialNew-Regular-BF644b214ff145f.otf")

const BG_COLOR := Color("1a140b")
const CARD_COLOR := Color("2b2418")
const ACCENT_YELLOW := Color("f4d06f")
const TEXT_DARK := Color("221c10")

# Shared palette for all avatars. Per-avatar extras (W = white, K = black,
# G = gray, P = pink, R = red, B = blue) are added on top.
const PALETTE := {
	".": Color(0, 0, 0, 0),
	"Y": Color("f6c84c"),  # bright cheddar yellow
	"H": Color("c47e1a"),  # hole ring / shadow
	"O": Color("5a3a0a"),  # hole interior (dark)
	"R": Color("e8a83b"),  # rind highlight
	"D": Color("8a5a18"),  # rind dark
	"W": Color("f7f3e8"),  # white (chef hat, mozz string)
	"K": Color("221c10"),  # black (sunglasses, eyes, mouse)
	"G": Color("4a4a4a"),  # gray
	"P": Color("e0a0a0"),  # mouse pink
	"B": Color("8fa9d6"),  # blue
}

# Each avatar is a 14x14 grid. Subtle variants give each contributor character.

# Ghaseen — chef's cheese (white puffy hat on top of a cheese wedge)
const ART_GHASEEN := [
	"..WWWWWWWWWW..",
	".WWWWWWWWWWWW.",
	"WWWWWWWWWWWWWW",
	".WWWWWWWWWWWW.",
	"..WWWWWWWWWW..",
	"YYYYYYYYYYYYYY",
	"YYYHHYYYHHYYYY",
	"YYHOOHYHOOHYYY",
	"YYYHHYYYHHYYYY",
	"YYYYYYYYYYYYYY",
	"YYYYYYYYYYYYYY",
	"RRRRRRRRRRRRRR",
	"DDDDDDDDDDDDDD",
	"..............",
]

# Rak — cheese wedge with a bite taken out of the top + tiny mouse below
const ART_RAK := [
	".....YYY......",
	"....YYY.......",
	"...YYYY.......",
	"..YYYYYY......",
	".YYYYYYYY.....",
	"YYYYYYYYYYYY..",
	"YYYHHYYYHHYYY.",
	"YYHOOHYHOOHYY.",
	"YYYHHYYYHHYYY.",
	"YYYYYYYYYYYYYY",
	"RRRRRRRRRRRRRR",
	"DDDDDDDDDDDDDD",
	"..............",
	"....KPPPPK....",
]

# Magnus — cheese wedge wearing a thick black sunglasses bar (the edgy one)
const ART_MAGNUS := [
	".....YYYY.....",
	"....YYYYYY....",
	"...YYYYYYYY...",
	"..YYYYYYYYYY..",
	".KKKKKKKKKKKK.",
	".KWKKKKKKKWKK.",
	".KKKKKKKKKKKK.",
	"YYYYYYYYYYYYYY",
	"YYYHHYYYHHYYYY",
	"YYHOOHYHOOHYYY",
	"YYYHHYYYHHYYYY",
	"YYYYYYYYYYYYYY",
	"RRRRRRRRRRRRRR",
	"DDDDDDDDDDDDDD",
]

# Tino — rectangular Swiss block packed with holes
const ART_TINO := [
	"..............",
	"YYYYYYYYYYYYYY",
	"YHHYYYYHHYYYYY",
	"HOOHYYHOOHYYYY",
	"YHHYYYYHHYYYYY",
	"YYYYYYYYYYYYYY",
	"YYYHHYYYHHYYYY",
	"YYHOOHYHOOHYYY",
	"YYYHHYYYHHYYYY",
	"YYYYYYYYYYYYYY",
	"YYHHYYYYYHHYYY",
	"YHOOHYYYHOOHYY",
	"RRRRRRRRRRRRRR",
	"DDDDDDDDDDDDDD",
]

# Kathi — cheese wedge with a friendly smiley face
const ART_KATHI := [
	".....YYYY.....",
	"....YYYYYY....",
	"...YYYYYYYY...",
	"..YYYYYYYYYY..",
	".YYYYYYYYYYYY.",
	"YYYKKYYYYKKYYY",
	"YYYKKYYYYKKYYY",
	"YYYYYYYYYYYYYY",
	"YYYYYYYYYYYYYY",
	"YYKYYYYYYYYKYY",
	"YYKKKKKKKKKKYY",
	"YYYKKKKKKKKYYY",
	"RRRRRRRRRRRRRR",
	"DDDDDDDDDDDDDD",
]

# Khushaal — cheese with stretchy mozzarella strings dangling and tapering off
const ART_KHUSHAAL := [
	".....YYYY.....",
	"....YYYYYY....",
	"...YYYHHYYYY..",
	"..YYYHOOHYYYY.",
	".YYYYYHHYYYYYY",
	"YYYHHYYYYYHHYY",
	"YYHOOHYYYHOOHY",
	"YYYHHYYYYYHHYY",
	"..W..W...W..W.",
	"..W..W...W..W.",
	"..W..W...W..W.",
	"..W..W...W....",
	"..W..W........",
	"..W...........",
]

const CREDITS: Array = [
	{"name": "Ghaseen", "art": ART_GHASEEN, "tagline": "Management, Code, Design, Composition, Music, Git"},
	{"name": "Rak", "art": ART_RAK, "tagline": "Management, Production, Design, Systems, Code, UI"},
	{"name": "Magnus", "art": ART_MAGNUS, "tagline": "Design, Art"},
	{"name": "Tino", "art": ART_TINO, "tagline": "Narrative, Research, Code"},
	{"name": "Kathi", "art": ART_KATHI, "tagline": "Code, Design"},
	{"name": "Khushaal", "art": ART_KHUSHAAL, "tagline": "Code, Design, UI"},
]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 40)
	root.add_theme_constant_override("margin_top", 28)
	root.add_theme_constant_override("margin_bottom", 28)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(col)

	# --- title ---
	var title := Label.new()
	title.text = "CREDITS"
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", ACCENT_YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# --- grid of 6 cards ---
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	var grid_wrap := CenterContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.add_child(grid)
	col.add_child(grid_wrap)

	for entry in CREDITS:
		grid.add_child(_make_card(entry))

	# --- back button ---
	var back_wrap := CenterContainer.new()
	col.add_child(back_wrap)
	back_wrap.add_child(_make_back_button())


func _make_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_COLOR
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT_YELLOW
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(220, 200)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	# avatar
	var avatar := TextureRect.new()
	avatar.texture = PixelArt.texture_from_pattern(entry["art"], PALETTE, 6)
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(96, 96)
	v.add_child(avatar)

	var name_lbl := Label.new()
	name_lbl.text = entry["name"]
	name_lbl.add_theme_font_override("font", BODY_FONT)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", ACCENT_YELLOW)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = entry["tagline"]
	tag_lbl.add_theme_font_override("font", BODY_FONT)
	tag_lbl.add_theme_font_size_override("font_size", 14)
	tag_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag_lbl)

	return card


func _make_back_button() -> Button:
	var btn := Button.new()
	btn.text = "Back to Menu"
	btn.custom_minimum_size = Vector2(260, 52)
	btn.add_theme_font_override("font", BODY_FONT)
	btn.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ACCENT_YELLOW.lightened(0.1) if state == "hover" else ACCENT_YELLOW
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override(state, sb)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, TEXT_DARK)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_back)
	return btn


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
