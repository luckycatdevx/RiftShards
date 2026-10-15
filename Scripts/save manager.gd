extends Node

# المسار الأساسي لعوالم اللاعب
const WORLDS_DIR := "user://worlds"
const SAVE_FILE := "savegame.json"
const META_FILE := "meta.json"

var current_world: String = ""

# يضمن وجود مجلد العوالم
func _ensure_worlds_dir():
	if not DirAccess.dir_exists_absolute(WORLDS_DIR):
		DirAccess.make_dir_absolute(WORLDS_DIR)

# يعيد المسار الكامل لملف داخل عالم محدد
func _world_file_path(world_name: String, file_name: String) -> String:
	return "%s/%s/%s" % [WORLDS_DIR, world_name, file_name]

# يعيد مسار ملف الحفظ للعالم الحالي
func _current_save_path() -> String:
	if current_world.is_empty():
		return ""
	return _world_file_path(current_world, SAVE_FILE)

func _get_world_metadata(world_name: String) -> Dictionary:
	var path := _world_file_path(world_name, META_FILE)
	if not FileAccess.file_exists(path):
		return {}
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
		
	var content = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse_string(content)
	if typeof(json_result) == TYPE_DICTIONARY:
		return json_result
	return {}

# إنشاء عالم جديد باسم محدد
func create_world(world_name: String) -> bool:
	_ensure_worlds_dir()
	if world_name.is_empty():
		return false
	world_name = world_name.strip_edges()
	var world_dir := "%s/%s" % [WORLDS_DIR, world_name]
	if DirAccess.dir_exists_absolute(world_dir):
		return false
	if DirAccess.make_dir_absolute(world_dir) != OK:
		return false
	return true

func delete_world(world_name: String) -> bool:
	if world_name.is_empty():
		return false
		
	var world_dir := "%s/%s" % [WORLDS_DIR, world_name]
	
	# نستخدم DirAccess.open للتحقق من المسار
	var dir_check = DirAccess.open(WORLDS_DIR)
	if not dir_check or not dir_check.dir_exists(world_dir):
		print("Error: World directory not found at path: ", world_dir)
		return false

	# استخدام الدالة المساعدة للحذف المتكرر
	if _recursive_delete_dir(world_dir):
		print("World deleted successfully: ", world_name)
		
		# إذا كان العالم المحذوف هو العالم الحالي، قم بتفريع اسم العالم الحالي
		if current_world == world_name:
			current_world = "" 
			
		return true
	else:
		print("Error deleting world: ", world_name)
		return false

func _recursive_delete_dir(path: String) -> bool:
	var dir = DirAccess.open(path)
	if not dir:
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				# إذا كان المكون مجلدًا، نكرر الدالة (Recursion)
				_recursive_delete_dir(full_path)
			else:
				# إذا كان ملفًا، نحذفه
				DirAccess.remove_absolute(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# أخيرًا، نحذف المجلد الفارغ نفسه
	var error = DirAccess.remove_absolute(path)
	return error == OK

# تحديد العالم الحالي
func set_current_world(world_name: String) -> void:
	current_world = world_name.strip_edges()

func get_current_world() -> String:
	return current_world

# سرد العوالم المحفوظة
func list_worlds() -> Array:
	_ensure_worlds_dir()
	var results: Array = []
	var dir = DirAccess.open(WORLDS_DIR)
	if dir:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if dir.current_is_dir() and not name.begins_with("."):
				results.append(name)
			name = dir.get_next()
		dir.list_dir_end()
	return results

# ===================
#  دالة الحفظ
# ===================

# تستقبل البيانات من سكربت Overworld وتقوم بحفظها داخل مجلد العالم الحالي.
func save_game(game_data: Dictionary):
	_ensure_worlds_dir()
	var path := _current_save_path()
	if path.is_empty():
		return
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	if not save_file:
		return
	var json_string = JSON.stringify(game_data, "\t")
	save_file.store_string(json_string)
	save_file.close()

# ===================
#  دالة التحميل
# ===================

# تقرأ البيانات من ملف الحفظ للعالم الحالي وتعيدها كقاموس.
func load_game() -> Dictionary:
	var path := _current_save_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var save_file = FileAccess.open(path, FileAccess.READ)
	if not save_file:
		return {}
	var json_string = save_file.get_as_text()
	save_file.close()
	var parse_result = JSON.parse_string(json_string)
	if parse_result == null:
		return {}
	return parse_result

# ===================
#  دالة التحقق
# ===================

# دالة مساعدة للتحقق من وجود ملف حفظ للعالم الحالي
func has_save_data() -> bool:
	var path := _current_save_path()
	return (not path.is_empty()) and FileAccess.file_exists(path)
