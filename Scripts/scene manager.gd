extends Node

var previous_scene_path = ""
var current_scene_path = ""

# دالة لتخزين المشهد الحالي قبل الانتقال إلى مشهد جديد
func store_and_change_scene(next_scene_path: String):
	# 1. تخزين المشهد الحالي كـ "سابق"
	if get_tree().current_scene:
		previous_scene_path = get_tree().current_scene.scene_file_path
	
	# 2. الانتقال إلى المشهد الجديد
	get_tree().change_scene_to_file(next_scene_path)
	
	# 3. تحديث المشهد الحالي
	current_scene_path = next_scene_path

# دالة للرجوع إلى المشهد السابق المخزن
func go_back_to_previous_scene():
	if previous_scene_path:
		get_tree().change_scene_to_file(previous_scene_path)
		# تحديث المسارات بعد الرجوع (اختياري، حسب احتياجك)
		var temp_current = current_scene_path
		current_scene_path = previous_scene_path
		previous_scene_path = temp_current
		get_tree().paused = false
	else:
		print("لا يوجد مسار مشهد سابق مخزن للرجوع إليه.")
