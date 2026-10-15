extends Control

var player: Node = null
var slot_index: int = -1

func set_context(p: Node, idx: int) -> void:
	player = p
	slot_index = idx

func _get_inventory() -> Array:
	if player == null:
		return []
	var inv_var = player.get("inventory_slots")
	if inv_var is Array:
		return inv_var
	return []

func _get_drag_data(at_position: Vector2):
	if player == null or slot_index < 0:
		return null
	var inv: Array = _get_inventory()
	if slot_index >= inv.size():
		return null
	var slot_data = inv[slot_index]
	if slot_data == null:
		return null
	var drag_data := {
		"type": "inventory_item",
		"from_index": slot_index,
		"source_path": get_path()
	}
	# Drag preview
	var preview := TextureRect.new()
	var tex = null
	if slot_data is Dictionary and slot_data.has("name") and player != null:
		var item_textures = player.get("item_textures")
		if item_textures is Dictionary and item_textures.has(slot_data["name"]):
			tex = item_textures[slot_data["name"]]
	if tex:
		preview.texture = tex
		preview.scale.x = 2
		preview.scale.y = 2
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return drag_data

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not (data is Dictionary):
		return false
	var dtype = data.get("type")
	if dtype == "inventory_item":
		return data.has("from_index")
	elif dtype == "crafting_item":
		# need at least name, quantity, and a source path to update the crafting slot
		return data.has("name") and data.has("quantity") and data.has("source_path")
	return false

func _drop_data(at_position: Vector2, data) -> void:
	if player == null or slot_index < 0:
		return
	if not (data is Dictionary):
		return
	var dtype = data.get("type")
	var inv: Array = _get_inventory()
	if dtype == "inventory_item":
		if inv.is_empty():
			return
		var from_index: int = int(data.get("from_index", -1))
		if from_index < 0 or from_index >= inv.size() or from_index == slot_index:
			return
		# Swap items within inventory
		var tmp = inv[slot_index]
		inv[slot_index] = inv[from_index]
		inv[from_index] = tmp
		if player.has_method("update_all_ui"):
			player.update_all_ui()
	elif dtype == "crafting_item":
		# Add crafted or grid items into inventory, then remove from crafting slot
		var name: String = String(data.get("name", ""))
		var qty: int = int(data.get("quantity", 0))
		var src_path_val = data.get("source_path")
		var src: Node = null
		if src_path_val is String:
			src = get_node_or_null(String(src_path_val))
		if name == "" or qty <= 0:
			return
		# Try to add as many as possible
		var added: int = 0
		for i in range(qty):
			if player.has_method("add_item") and player.add_item(name, 1):
				added += 1
			else:
				break
		# Remove from crafting slot
		if src:
			if src.has_method("remove_amount"):
				src.remove_amount(added)
			elif src.has_method("clear") and added > 0:
				src.clear()
		# Final UI refresh
		if player.has_method("update_all_ui"):
			player.update_all_ui()
