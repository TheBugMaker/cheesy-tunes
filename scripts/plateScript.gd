extends TextureRect

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Only accept the drop if the node name contains "plate" AND the data is an image
	if "plate" in self.name and data is Texture2D:
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Stick it to the plate: Create a new TextureRect with the dropped image
	var dropped_item = TextureRect.new()
	dropped_item.texture = data
	dropped_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dropped_item.size = Vector2(64, 64) # Adjust this size to fit your plate
	
	# Position it where the user released the mouse inside the plate
	dropped_item.position = at_position - (dropped_item.size / 2)
	
	add_child(dropped_item)
