extends Control

signal changed

var player: Node = null
var item_name: String = ""
var quantity: int = 0

@onready var tex: TextureRect = $ItemTexture
@onready var label: Label = $QuantityLabel

func set_context(p: Node) -> void:
	player = p
	_refresh()

func is_empty() -> bool:
	return item_name == "" or quantity <= 0

func get_item_name() -> String:
	return item_name

func get_quantity() -> int:
	return quantity

func clear() -> void:
	item_name = ""
	quantity = 0
	_refresh()
	emit_signal("changed")

func remove_one() -> bool:
	if quantity > 0:
		quantity -= 1
		if quantity == 0:
			clear()
		else:
			_refresh()
		emit_signal("changed")
		return true
	return false

func remove_amount(amount: int) -> int:
	var removed := 0
	while removed < amount and quantity > 0:
		if remove_one():
			removed += 1
	return removed

func _refresh() -> void:
	var textures: Dictionary = {}
	if player != null:
		var maybe_textures = player.get("item_textures")
		if maybe_textures is Dictionary:
			textures = maybe_textures
	if not is_empty() and textures.has(item_name):
		tex.texture = textures[item_name]
		tex.visible = true
		label.text = str(quantity)
		label.visible = quantity > 1
	else:
		tex.visible = false
		label.visible = false

# Drag out of slot
func _get_drag_data(_at_position: Vector2):
	if is_empty():
		return null
	var drag_data: Dictionary = {
		"type": "crafting_item",
		"name": item_name,
		"quantity": quantity,
		"source_path": String(get_path())
	}
	# preview
	var preview := TextureRect.new()
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tex.texture:
		preview.texture = tex.texture
		preview.scale = Vector2(2, 2)
	set_drag_preview(preview)
	return drag_data

# Accept inventory items or other crafting slot items
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not (data is Dictionary):
		return false
	var dtype = data.get("type")
	if dtype == "inventory_item":
		# only need from_index; name/quantity may not be provided
		return data.has("from_index")
	elif dtype == "crafting_item":
		return data.has("name") and data.has("quantity")
	return false

func _drop_data(_at_position: Vector2, data) -> void:
	if player == null or not (data is Dictionary):
		return
	var dtype = data.get("type")
	if dtype == "inventory_item":
		# place one at a time from inventory
		var inv: Array = []
		if player != null:
			var maybe_inv = player.get("inventory_slots")
			if maybe_inv is Array:
				inv = maybe_inv
		if inv.is_empty():
			return
		var from_index: int = int(data.get("from_index", -1))
		if from_index < 0 or from_index >= inv.size():
			return
		var slot_data: Variant = inv[from_index]
		if slot_data == null or not (slot_data is Dictionary) or not slot_data.has("name") or int(slot_data.get("quantity", 0)) <= 0:
			return
		var name: String = String(slot_data["name"])
		# Only place if slot empty or same item
		if not is_empty() and name != item_name:
			return
		if player.has_method("remove_item"):
			player.remove_item(name, 1)
			if is_empty():
				item_name = name
				quantity = 1
			else:
				quantity += 1
			_refresh()
			emit_signal("changed")
	elif dtype == "crafting_item":
		var name: String = String(data.get("name", ""))
		var qty: int = int(data.get("quantity", 0))
		var source_path_val = data.get("source_path")
		var source_slot: Node = null
		if source_path_val is String:
			source_slot = get_node_or_null(String(source_path_val))
		# If dropping onto same slot, nothing
		if source_slot == self:
			return
		if is_empty():
			item_name = name
			quantity = qty
			if source_slot and source_slot.has_method("clear"):
				source_slot.clear()
			_refresh()
			emit_signal("changed")
			return
		if item_name == name:
			quantity += qty
			if source_slot and source_slot.has_method("clear"):
				source_slot.clear()
			_refresh()
			emit_signal("changed")
			return
		# swap different items
		var tmp_name: String = item_name
		var tmp_qty: int = quantity
		item_name = name
		quantity = qty
		if source_slot and source_slot is Control:
			if "item_name" in source_slot:
				source_slot.item_name = tmp_name
			if "quantity" in source_slot:
				source_slot.quantity = tmp_qty
			if source_slot.has_method("_refresh"):
				source_slot._refresh()
			if source_slot.has_signal("changed"):
				source_slot.emit_signal("changed")
		_refresh()
		emit_signal("changed")

func _gui_input(event: InputEvent) -> void:
	# Right-click returns one item to inventory
	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_RIGHT and event.pressed:
		if not is_empty() and player and player.has_method("add_item"):
			player.add_item(item_name, 1)
			quantity -= 1
			if quantity <= 0:
				clear()
			else:
				_refresh()
				emit_signal("changed")
