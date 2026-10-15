extends Node

# المسار إلى ملف الحفظ
const SAVE_PATH = "user://settings.cfg"

# قاموس لتخزين الإعدادات الحالية في الذاكرة
var current_settings = {
	"is_creative_mode": false,
	"master_volume": 100.0,
	"fullscreen": true,
	"mute": false,
	"vsync": true,
	"show_fps": false,
	"max_fps": 60,
}

func _ready():
	TranslationServer.set_locale("ar`")
	load_settings()

# --- دالة لحفظ الإعدادات في الملف ---
func save_settings():
	var config = ConfigFile.new()
	
	# مر على كل الإعدادات في القاموس واكتبها في الملف
	for key in current_settings:
		config.set_value("Settings", key, current_settings[key])
		
	# احفظ الملف
	var error = config.save(SAVE_PATH)
	if error != OK:
		print("ERROR: Failed to save settings file.")

# --- دالة لتحميل الإعدادات من الملف ---
func load_settings():
	var config = ConfigFile.new()
	
	# حاول تحميل الملف
	var error = config.load(SAVE_PATH)
	
	# إذا لم يكن الملف موجودًا أو كان فارغًا، احفظ الإعدادات الافتراضية
	if error != OK:
		print("No settings file found. Creating one with default values.")
		save_settings()
		return

	# إذا تم تحميل الملف بنجاح، اقرأ القيم
	for key in current_settings:
		# get_value(section, key, default_value)
		var loaded_value = config.get_value("Settings", key, current_settings[key])
		current_settings[key] = loaded_value
		
	
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"),linear_to_db(current_settings.get("master_volume")))
	
	if current_settings.get("fullscreen") == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if current_settings.get("vsync") == true:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),current_settings.get("mute"))
	
	Engine.max_fps = current_settings.get("max_fps")
	
	print("Settings loaded successfully: ", current_settings)
	

# --- دالة لتغيير إعداد واحد وحفظه فورًا ---
func set_setting(key: String, value):
	if current_settings.has(key):
		current_settings[key] = value
		save_settings() # احفظ فورًا بعد كل تغيير
	else:
		print("ERROR: Attempted to set an unknown setting: ", key)
