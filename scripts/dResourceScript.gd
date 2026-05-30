extends TextureRect

func _get_drag_data(at_position: Vector2) -> Variant:
	# Check if the node name contains "dResource"
	if not "dResource" in self.name:
		return null

	# Infinite repository: We pass the texture data itself, leaving the original node untouched
	var data_to_drop = self.texture

	# Create the visual preview that sticks to your cursor
	var drag_preview = TextureRect.new()
	drag_preview.texture = self.texture
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.size = self.size 
	drag_preview.modulate.a = 0.8 # Optional: Makes the dragged item slightly transparent

	# Center the preview exactly on the mouse cursor
	var control_wrapper = Control.new()
	control_wrapper.add_child(drag_preview)
	drag_preview.position = -0.5 * drag_preview.size
	set_drag_preview(control_wrapper)

	return data_to_drop
