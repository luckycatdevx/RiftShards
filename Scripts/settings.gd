extends CanvasLayer

@onready var volume_edit: HSlider = $"Audio/Volume Edit"
@onready var fullscreen_check: CheckBox = $"Screen/Full Check"
@onready var v_sync_check: CheckBox = $"Screen/V-Sync Check"
@onready var mute_check: CheckBox = $"Audio/Mute Check"
@onready var fps_check: CheckBox = $"Screen/FPS Check"
@onready var max_fps_button: OptionButton = $"Screen/Max FPS Button"

func _ready() -> void:
	$Version.text = tr("version") + str(ProjectSettings.get_setting("application/config/version"))
	
	volume_edit.value = SettingsManager.current_settings.master_volume
	fullscreen_check.button_pressed = SettingsManager.current_settings.fullscreen
	mute_check.button_pressed = SettingsManager.current_settings.mute
	v_sync_check.button_pressed = SettingsManager.current_settings.vsync
	fps_check.button_pressed = SettingsManager.current_settings.show_fps
	# --- تحميل إعداد Max FPS ---
	var saved_max_fps = SettingsManager.current_settings.max_fps
	# ابحث عن الفهرس الذي يطابق القيمة المحفوظة
	for i in range(max_fps_button.item_count):
		if max_fps_button.get_item_id(i) == saved_max_fps:
			max_fps_button.select(i)
			break

func _on_back_button_pressed() -> void:
	ButtonAudio.play()
	SceneManager.go_back_to_previous_scene()

func _on_volume_edit_value_changed(value: float) -> void:
	# قم بتحديث الإعداد في SettingsManager (سيقوم هو بحفظه تلقائيًا)
	ButtonAudio.play()
	SettingsManager.set_setting("master_volume", value)
	# قم بتطبيق التغيير على الصوت فورًا
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_full_check_toggled(toggled_on: bool) -> void:
	SettingsManager.set_setting("fullscreen", toggled_on)
	ButtonAudio.play()
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_v_sync_check_toggled(toggled_on: bool) -> void:
	ButtonAudio.play()
	SettingsManager.set_setting("vsync", toggled_on)
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_mute_check_toggled(toggled_on: bool) -> void:
	ButtonAudio.play()
	SettingsManager.set_setting("mute", toggled_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), toggled_on)

func _on_fps_check_toggled(toggled_on: bool) -> void:
	ButtonAudio.play()
	SettingsManager.set_setting("show_fps", toggled_on)
	# ابحث عن العداد في المشهد الرئيسي وقم بتحديث رؤيته
	var world_node = get_tree().root.get_node("World")
	if world_node and world_node.has_node("FPSCounter"):
		world_node.get_node("FPSCounter").visible = toggled_on

func _on_max_fps_button_item_selected(index: int) -> void:
	# الخطوة 1: احصل على القيمة (ID) المرتبطة بالفهرس المحدد
	# هذه هي أهم خطوة
	ButtonAudio.play()
	
	var selected_fps_limit = max_fps_button.get_item_id(index)
	
	# الخطوة 2: قم بتحديث الإعداد في المدير باستخدام القيمة الصحيحة
	SettingsManager.set_setting("max_fps", selected_fps_limit)
	
	# الخطوة 3: قم بتطبيق التغيير فورًا باستخدام القيمة الصحيحة
	Engine.max_fps = selected_fps_limit
	
	print("Max FPS limit set to: ", selected_fps_limit) # للتأكد
