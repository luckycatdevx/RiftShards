extends Control

@onready var list: ItemList = $WorldList
@onready var ip_address_entry: LineEdit = $IPAddressEntry
# ===================================================================
#  الدوال الأساسية
# ===================================================================

func _ready() -> void:
	ip_address_entry.text = "127.0.0.1"
	_refresh_list()

func _refresh_list() -> void:
	list.clear()
	var worlds: Array = SaveManager.list_worlds()
	for w in worlds:
		list.add_item(String(w))

# ===================================================================
#  دوال الأزرار
# ===================================================================

func _on_host_button_pressed():
	ButtonAudio.play()
	# تعطيل
	ip_address_entry.editable = false
	# إنشاء السيرفر
	await get_tree().process_frame
	start_game()
	print("Game Started")
	

func _on_join_button_pressed():
	ButtonAudio.play()
	var ip = ip_address_entry.text
	if ip.is_valid_ip_address():
		# تعطيل بعد محاولة الانضمام
		ip_address_entry.editable = false
		on_connection_succeeded()
		print("Game joined")
	else:
		on_connection_failed()
		print("Invalid IP address")

# ===================================================================
#  الدوال التي تستقبل الإشارات
# ===================================================================

func start_game():
	var selected = list.get_selected_items()
	if selected.is_empty():
		return
	var world_name = list.get_item_text(selected[0])
	SaveManager.set_current_world(world_name)
	get_tree().change_scene_to_file("res://Scenes/overworld.tscn")

# ===================================================================
#  الخطوة 1: أضف الدوال
# ===================================================================

func on_server_create_failed():
	print("Failed to create server.")

func on_connection_succeeded():
	# عندما ينجح العميل في الاتصال، قم بتغيير المشهد
	start_game()

func on_connection_failed():
	print("Connection failed.")
