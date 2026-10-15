extends Control

signal craft_requested(amount: int)

var player: Node = null
var item_name: String = ""
var quantity: int = 0

@onready var tex: TextureRect = $ItemTexture
@onready var label: Label = $QuantityLabel

func set_item(p: Node, name: String, qty: int) -> void:
	player = p
	item_name = name
	quantity = qty
	_refresh()

func clear() -> void:
	item_name = ""
	quantity = 0
	_refresh()

func _refresh() -> void:
	if item_name == "" or quantity <= 0:
		tex.visible = false
		label.visible = false
		return
	var textures: Dictionary = {}
	if player != null:
		var maybe_textures = player.get("item_textures")
		if maybe_textures is Dictionary:
			textures = maybe_textures
	if textures.has(item_name) and textures[item_name] is Texture2D:
		tex.texture = textures[item_name]
		tex.visible = true
		label.text = str(quantity)
		label.visible = quantity > 1
	else:
		tex.visible = false
		label.visible = false

func _can_drop_data(_at_position: Vector2, _data) -> bool:
	return false

func _drop_data(_at_position: Vector2, _data) -> void:
	pass

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		if item_name != "" and quantity > 0:
			var amount: int = 1
			if event.shift_pressed:
				amount = -1 # signal to craft max
			emit_signal("craft_requested", amount)
