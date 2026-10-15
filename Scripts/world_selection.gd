extends Control

@onready var list: ItemList = $WorldList
@onready var create_dialog: AcceptDialog = $CreateDialog
@onready var delete_dialog: AcceptDialog = $DeleteDialog
@onready var name_edit: LineEdit = $"CreateDialog/VBox/Name"

func _ready() -> void:
	_refresh_list()

func _refresh_list() -> void:
	list.clear()
	var worlds: Array = SaveManager.list_worlds()
	for w in worlds:
		list.add_item(String(w))

func _on_create_button_pressed() -> void:
	ButtonAudio.play()
	name_edit.text = ""
	create_dialog.popup_centered()

func _on_create_confirmed() -> void:
	name = name_edit.text.strip_edges()
	if name.is_empty():
		return
	ButtonAudio.play()
	if SaveManager.create_world(name):
		_refresh_list()
		# اختيار العالم الذي تم إنشاؤه حديثًا
		for i in range(list.get_item_count()):
			if list.get_item_text(i) == name:
				list.select(i)
				break

func _on_play_button_pressed() -> void:
	ButtonAudio.play()
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var world_name := list.get_item_text(selected[0])
	SaveManager.set_current_world(world_name)
	get_tree().change_scene_to_file("res://Scenes/overworld.tscn")

func _on_delete_button_pressed() -> void:
	ButtonAudio.play()
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
		
	var world_name := list.get_item_text(selected[0])
	delete_dialog.dialog_text = "Are you sure you want to delete the world:\n" + world_name + "\nThis action cannot be undone.!"
	delete_dialog.popup_centered()

func _on_delete_dialog_confirmed() -> void:
	ButtonAudio.play()
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
		
	var world_name := list.get_item_text(selected[0])
	if SaveManager.delete_world(world_name):
		print("World deleted: ", world_name)
		_refresh_list()
	else:
		print("Failed to delete world: ", world_name)

func _on_back_button_pressed() -> void:
	ButtonAudio.play()
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")
