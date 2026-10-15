# ===================================================================
#  Overworld.gd - النسخة (لعبة فردية)
# ===================================================================
extends Node2D

# ===================================================================
#  1. روابط العقد والإعدادات الأساسية
# ===================================================================

# --- روابط العقد ---
@onready var ground_layer: TileMapLayer = $TileMap/TileMapLayer
@onready var player: CharacterBody2D = $Player
@onready var entity: Node2D = $Entity
@onready var day_night_cycle: CanvasModulate = $DayNightCycle
@onready var sun_light: DirectionalLight2D = $SunLight
@onready var zombie_spawn_timer: Timer = $ZombieSpawnTimer
@onready var fps_counter: Label = $Player/UI/FPSCounter
@onready var cracks_layer: TileMapLayer = $TileMap/CracksLayer
@onready var break_sound: AudioStreamPlayer2D = $"Break Sound"
@onready var place_sound: AudioStreamPlayer2D = $"Place Sound"

# --- نظام إضاءة المشاعل ---
var torch_lights = {}  # Dictionary to store torch lights: {cell_coords: PointLight2D}
@onready var torch_lights_container: Node2D = $TorchLightsContainer
# إعدادات ضوء المشعل: 5x5 بلاطات (نصف القطر ~2.5 بلاطة) عند السطح، ويتناقص في الأعماق
const TORCH_BASE_RADIUS_TILES: float = 2.5
const TORCH_MIN_RADIUS_TILES: float = 1.5
const TORCH_DEPTH_MAX: float = 200.0
var _torch_tex: GradientTexture2D = null  # نسيج ضوء شعلة افتراضي (مشع داخلياً)

# --- إعدادات نظام القطع (Chunks) ---
const CHUNK_SIZE = 18
const LOAD_RADIUS = 10
var loaded_chunks = {}
var current_player_chunk = Vector2i.ZERO

# --- تعريفات البلاطات ---
const GRASS_TILE = {"source": 0, "coords": Vector2i(0, 0), "name": "grass"}
const DIRT_TILE = {"source": 0, "coords": Vector2i(1, 0), "name": "dirt"}
const STONE_TILE = {"source": 0, "coords": Vector2i(0, 2), "name": "stone"}
const COAL_TILE = {"source": 0, "coords": Vector2i(1, 2), "name": "coal"}
const IRON_TILE = {"source": 0, "coords": Vector2i(2, 2), "name": "iron"}
const GOLD_TILE = {"source": 0, "coords": Vector2i(3, 2), "name": "gold"}
const DIAMOND_TILE = {"source": 0, "coords": Vector2i(0, 3), "name": "diamond"}
const WOOD_TILE = {"source": 0, "coords": Vector2i(3, 0), "name": "wood"}
const LEAVES_TILE = {"source": 0, "coords": Vector2i(0, 1), "name": "leaves"}
const PLANKS_TILE = {"source": 0, "coords": Vector2i(1, 1), "name": "planks"}
const WORKING_TABLE_TILE = {"source": 0, "coords": Vector2i(2, 1), "name": "working_table"}
const TORCH_TILE = {"source": 0, "coords": Vector2i(3, 1), "name": "torch"}
const WATER_TILE = {"source": 0, "coords": Vector2i(2, 0), "name": "water"}

# فيزياء الماء (مثل ماين كرافت): مستوى 8 = منبع، 1–7 = تدفق متدرج
const WATER_SOURCE_LEVEL = 8
const WATER_MAX_FLOW_LEVEL = 7
const WATER_PHYSICS_INTERVAL = 0.12
var water_levels: Dictionary = {}  # مفتاح "x,y" -> مستوى 1–8
var _water_physics_timer: float = 0.0

func _water_cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

# إرجاع إحداثيات بلاطة الماء حسب المستوى (للتدرج البصري لاحقاً يمكن استخدام صفوف مختلفة)
func _get_water_atlas_coords(_level: int) -> Vector2i:
	# لاحقاً يمكن ربط _level ببلاطات مختلفة (مثلاً صفوف 0–7) للتدرج البصري
	return WATER_TILE.coords

func _is_cell_solid(cell: Vector2i) -> bool:
	var sid = ground_layer.get_cell_source_id(cell)
	if sid == -1:
		return false
	var tiledata = ground_layer.get_cell_tile_data(cell)
	if not is_instance_valid(tiledata):
		return true
	var name_str = tiledata.get_custom_data("name")
	return name_str != "water"

func _set_water_cell(cell: Vector2i, level: int) -> void:
	water_levels[_water_cell_key(cell)] = level
	ground_layer.set_cell(cell, WATER_TILE.source, _get_water_atlas_coords(level))

func _remove_water_cell(cell: Vector2i) -> void:
	water_levels.erase(_water_cell_key(cell))
	ground_layer.set_cell(cell, -1)

func _is_water_cell(cell: Vector2i) -> bool:
	return water_levels.has(_water_cell_key(cell))

func _get_water_level(cell: Vector2i) -> int:
	return water_levels.get(_water_cell_key(cell), 0)

# للاعب: التحقق من أن الموضع العالمي داخل ماء (للغرق/التنفس)
func is_position_in_water(world_pos: Vector2) -> bool:
	var local_pos = ground_layer.to_local(world_pos)
	var cell = ground_layer.local_to_map(local_pos)
	return water_levels.has(_water_cell_key(cell))

func _update_water_physics() -> void:
	# جمع كل خلايا الماء وترتيبها من الأسفل للأعلى (التدفق للأسفل أولاً)
	var cells: Array = []
	for key in water_levels.keys():
		var parts = key.split(",")
		if parts.size() != 2:
			continue
		cells.append(Vector2i(int(parts[0]), int(parts[1])))
	cells.sort_custom(func(a, b): return a.y > b.y)  # y الأكبر أولاً (أسفل)
	
	for cell in cells:
		if not water_levels.has(_water_cell_key(cell)):
			continue
		var level: int = water_levels[_water_cell_key(cell)]
		if level <= 1:
			continue
		var next_level: int = level - 1
		if level == WATER_SOURCE_LEVEL:
			next_level = WATER_MAX_FLOW_LEVEL
		# 1) التدفق للأسفل
		var down = cell + Vector2i(0, 1)
		if not _is_cell_solid(down):
			var down_cur = _get_water_level(down)
			if down_cur == 0 or down_cur < next_level:
				_set_water_cell(down, next_level)
				continue
		# 2) التدفق أفقياً (يسار ويمين)
		for offset in [Vector2i(-1, 0), Vector2i(1, 0)]:
			var side = cell + offset
			if not _is_cell_solid(side):
				var side_cur = _get_water_level(side)
				if side_cur == 0 or side_cur < next_level:
					_set_water_cell(side, next_level)
					break  # تدفق واحد أفقياً لكل خلية في هذه الدورة

# عناصر قابلة للبناء من خلال الأسماء الموجودة في المخزون
var PLACEABLE_ITEM_TO_TILE := {
	"grass": GRASS_TILE,
	"dirt": DIRT_TILE,
	"stone": STONE_TILE,
	"coal": COAL_TILE,
	"iron": IRON_TILE,
	"gold": GOLD_TILE,
	"diamond": DIAMOND_TILE,
	"wood": WOOD_TILE,
	"planks": PLANKS_TILE,
	"working_table": WORKING_TABLE_TILE,
	"torch": TORCH_TILE,
	"water": WATER_TILE,
}

var buildable_tiles = [
	GRASS_TILE,DIRT_TILE,STONE_TILE,
	COAL_TILE,IRON_TILE,GOLD_TILE,
	DIAMOND_TILE,PLANKS_TILE,
	WORKING_TABLE_TILE,TORCH_TILE,
	]
var current_tile_index = 0

# --- مولدات الضوضاء ---
var terrain_noise = FastNoiseLite.new()
var tree_noise = FastNoiseLite.new()
var cave_noise = FastNoiseLite.new()
var ore_noise = FastNoiseLite.new()
var biome_noise = FastNoiseLite.new()
var ore_vein_noise = FastNoiseLite.new()
var lake_noise = FastNoiseLite.new()
var cave_scale = randf_range(0.6,0.05)

# --- نظام الحفظ ---
var world_modifications = {} # قاموس لتخزين التغييرات على العالم

# --- نظام التكسير ---
const BLOCK_BREAK_TIME = 0.5
var breaking_pos = Vector2i(-1, -1)
var breaking_timer = 0.0
var current_breaking_cell = Vector2i(-1, -1)
var time_held = 0.0
const CRACKS_SOURCE_ID = 0
const CRACK_STAGES = 6

# --- إعدادات العالم ---
const SEA_LEVEL = 75
const LAKE_THRESHOLD = -0.32   # أقل من هذا = بحيرة على السطح
const LAKE_MAX_DEPTH = 3       # أقصى عمق للبحيرة (بلاطات)

# --- إعدادات الكائنات ---
var zombie_scene = preload("res://Scenes/zombie.tscn")
var sheep_scene = preload("res://Scenes/sheep.tscn")
var cow_scene = preload("res://Scenes/cow.tscn")

const PLAYER_SPAWN_POSITION = Vector2(-10 - 10, 608)
const DIED_SCREEN_SCENE = preload("res://Scenes/died.tscn")

# ===================================================================
#  2. إعدادات نظام الليل والنهار
# ===================================================================
var time_of_day: float = 1 # 1.0 = نهار، 0.0 = ليل
var time_direction: int = 1
const DAY_LENGTH_IN_SECONDS: float = 900

const DAY_COLOR = Color(1, 1, 1)
const NIGHT_COLOR = Color(0.0, 0.0, 0.180)

# ===================================================================
	#  3. الدوال الأساسية لـ Godot
# ===================================================================

func _ready():
	
	fps_counter.visible = SettingsManager.current_settings.show_fps
	
	if player.has_signal("died"):
		player.died.connect(player_died())
	
	await do_load()
	if SaveManager.has_save_data(): return
	
	# إعداد مولدات الضوضاء
	terrain_noise.seed = randi()
	terrain_noise.frequency = 0.008
	cave_noise.seed = terrain_noise.seed
	cave_noise.frequency = 0.04
	ore_noise.seed = terrain_noise.seed
	
	# توليد العالم الأولي حول اللاعب
	ore_noise.seed = terrain_noise.seed
	
	# إعداد مولد العروق
	ore_vein_noise.seed = terrain_noise.seed + 1 # استخدم seed مختلف قليلاً
	ore_vein_noise.frequency = 0.08 # تردد أعلى لإنشاء تكتلات أصغر
	ore_vein_noise.fractal_type = FastNoiseLite.FRACTAL_PING_PONG
	ore_vein_noise.fractal_ping_pong_strength = 4.0
	
	biome_noise.seed = terrain_noise.seed + 10 # استخدم نفس البذرة لتكون البايومات متناسقة
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.frequency = 0.002 # تردد منخفض جدًا لإنشاء مناطق كبيرة
	biome_noise.cellular_jitter = 0.8
	
	tree_noise.seed = terrain_noise.seed + 2 # استخدم بذرة مختلفة قليلاً
	tree_noise.frequency = 0.02 # تردد مناسب للأشجار (يمكن تعديله)
	
	lake_noise.seed = terrain_noise.seed + 5
	lake_noise.frequency = 0.025 # بحيرات متوسطة الحجم
	lake_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	lake_noise.fractal_octaves = 2
	
	time_of_day = 1
	
	update_chunks()
	do_save()

func _process(delta: float):
	# تحديث كل الأنظمة في كل إطار
	update_day_night_cycle(delta)
	handle_building_and_breaking()
	update_player_chunk_movement()
	# فيزياء الماء (تدفق وتدرج)
	_water_physics_timer += delta
	if _water_physics_timer >= WATER_PHYSICS_INTERVAL:
		_water_physics_timer = 0.0
		_update_water_physics()
	
	# تحديث نص العداد إذا كان مرئيًا
	if fps_counter.visible:
		fps_counter.text = "FPS:" + str(int(Engine.get_frames_per_second()))
	

func _unhandled_input(event: InputEvent):
	# تغيير البلاطة للبناء باستخدام عجلة الماوس
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_tile_index = (current_tile_index + 1) % buildable_tiles.size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_tile_index = (current_tile_index - 1 + buildable_tiles.size()) % buildable_tiles.size()

# ===================================================================
#  نظام إضاءة المشاعل
# ===================================================================

func _create_torch_light_container():
	# Create container node if it doesn't exist
	if not has_node("TorchLightsContainer"):
		var container = Node2D.new()
		container.name = "TorchLightsContainer"
		add_child(container)
		torch_lights_container = container

func _get_torch_texture() -> GradientTexture2D:
	# أنشئ نسيج تدرّجي دائري دافئ إذا لم يكن موجوداً
	if _torch_tex != null:
		return _torch_tex
	var grad := Gradient.new()
	# مركز ساطع
	grad.add_point(0.0, Color(1.0, 0.96, 0.80, 1.0))
	# انتقال ناعم داخل 5x5 مع تدرج
	grad.add_point(0.6, Color(1.0, 0.85, 0.45, 0.35))
	# الحافة تختفي
	grad.add_point(1.0, Color(1.0, 0.75, 0.25, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	_torch_tex = tex
	return _torch_tex

func _update_torch_light(cell_coords: Vector2i, is_torch: bool):
	# Create container if needed
	if not torch_lights_container:
		_create_torch_light_container()
	
	var key = str(cell_coords.x) + "," + str(cell_coords.y)
	
	if is_torch:
		# Check if light already exists
		if torch_lights.has(key):
			var existing_light: PointLight2D = torch_lights[key]
			existing_light.texture = _get_torch_texture()
			_apply_torch_light_params(existing_light, cell_coords)
			return
		
		# Create new torch light
		var new_light = PointLight2D.new()
		new_light.color = Color(1.0, 0.85, 0.5)
		new_light.texture = _get_torch_texture()
		new_light.blend_mode = PointLight2D.BLEND_MODE_ADD
		_apply_torch_light_params(new_light, cell_coords)
		# Add to container and store reference
		torch_lights_container.add_child(new_light)
		torch_lights[key] = new_light
	else:
		# Remove light if torch was broken (تلاشي تدريجي)
		if torch_lights.has(key):
			var old_light: PointLight2D = torch_lights[key]
			torch_lights.erase(key)
			if is_instance_valid(old_light):
				var tw := get_tree().create_tween()
				tw.tween_property(old_light, "energy", 0.0, 0.35)
				tw.tween_callback(Callable(old_light, "queue_free"))

func _calculate_torch_intensity(depth: int) -> float:
	# سطوع أساسي على السطح يتناقص مع العمق
	var base_intensity: float = 1.3
	var depth_factor: float = clampf(float(depth) / TORCH_DEPTH_MAX, 0.0, 1.0)
	return lerpf(base_intensity, 0.5, depth_factor)

func _apply_torch_light_params(light: PointLight2D, cell_coords: Vector2i) -> void:
	# طاقة حسب العمق
	var depth := cell_coords.y - SEA_LEVEL
	light.energy = _calculate_torch_intensity(depth)
	# نصف قطر حسب العمق (5x5 بلاطات على السطح يتناقص إلى ~1.5x1.5)
	var tsize: Vector2i = ground_layer.tile_set.tile_size
	var tile_px: float = float(tsize.x)
	var depth_factor: float = clampf(float(depth) / TORCH_DEPTH_MAX, 0.0, 1.0)
	var radius_tiles: float = lerpf(TORCH_BASE_RADIUS_TILES, TORCH_MIN_RADIUS_TILES, depth_factor)
	var radius_px: float = radius_tiles * tile_px
	var tex: GradientTexture2D = _get_torch_texture()
	var scale: float = (radius_px * 2.0) / float(tex.width) # width هو القطر
	light.texture_scale = scale
	# تمركز على منتصف الخلية
	var local_pos: Vector2 = ground_layer.map_to_local(cell_coords) + Vector2(tile_px, tile_px) * 0.5
	light.global_position = ground_layer.to_global(local_pos)

func _effective_light_radius(light: PointLight2D) -> float:
	if light.texture:
		var size: Vector2i = light.texture.get_size()
		var w: float = float(size.x)
		return w * 0.5 * light.texture_scale
	# احتياطي
	var tsize: Vector2i = ground_layer.tile_set.tile_size
	return TORCH_BASE_RADIUS_TILES * float(tsize.x)

func _clear_all_torch_lights() -> void:
	for k in torch_lights.keys():
		var n = torch_lights[k]
		if is_instance_valid(n):
			n.queue_free()
	torch_lights.clear()

# ===================================================================
#  دالة التكسير والبناء (مع نظام الأدوات)
# ===================================================================

func handle_building_and_breaking():
	if not is_instance_valid(player): return # فحص أمان
	
	var mouse_pos = get_global_mouse_position()
	var cell_coords = ground_layer.local_to_map(mouse_pos)

	# ---------------------------------------------------------------
	#  منطق التكسير (الزر الأيسر)
	# ---------------------------------------------------------------
	if Input.is_action_pressed("mleft"):
		# --- وضع الإبداع ---
		if SettingsManager.current_settings.is_creative_mode:
			# --- Remove torch light if breaking a torch ---
			var target_tile_data = ground_layer.get_cell_tile_data(cell_coords)
			if is_instance_valid(target_tile_data):
				var tile_name = target_tile_data.get_custom_data("name")
				if tile_name == "torch":
					_update_torch_light(cell_coords, false)
				if tile_name == "water":
					_remove_water_cell(cell_coords)

			# تكسير فوري في وضع الإبداع
			ground_layer.set_cell(cell_coords, -1)
			cracks_layer.set_cell(cell_coords, -1) # إزالة الشقوق
			time_held = 0
			current_breaking_cell = Vector2i(-1, -1)
			if break_sound.playing:
				await break_sound.finished
			break_sound.play()
			return
	
		
		# التحقق مما إذا كنا بدأنا في تكسير بلاطة جديدة
		if cell_coords != current_breaking_cell:
			# إذا انتقلنا إلى بلاطة جديدة، أعد تعيين المؤقت
			time_held = 0.0
			# مسح الشقوق من البلاطة القديمة إذا كانت موجودة
			if current_breaking_cell != Vector2i(-1, -1):
				cracks_layer.set_cell(current_breaking_cell, -1)
			current_breaking_cell = cell_coords

		# 1. الحصول على بيانات البلاطة المستهدفة
		var target_tile_data = ground_layer.get_cell_tile_data(cell_coords)
		
		# تأكد من وجود بلاطة قابلة للتكسير
		if is_instance_valid(target_tile_data):
			# 2. الحصول على خصائص البلاطة من البيانات المخصصة
			var tile_tool_type = target_tile_data.get_custom_data("tool_type")
			var tile_hardness_level = target_tile_data.get_custom_data("hardness_level")
			
			# 3. الحصول على خصائص الأداة الحالية من اللاعب
			var current_tool = player.TOOLS[player.current_tool_name]
			
			# 4. التحقق مما إذا كان اللاعب يستطيع تكسير هذه البلاطة
			if current_tool.level >= tile_hardness_level:
				# 5. حساب سرعة التكسير
				var break_speed = 1.0 # السرعة الأساسية (لليد أو الأداة الخاطئة)
				
				# إذا كانت الأداة من النوع الصحيح، قم بتسريع التكسير
				if current_tool.type == tile_tool_type:
					break_speed = current_tool.speed_multiplier
				# إذا كانت الأداة من النوع الخاطئ (لكنها قوية بما فيه الكفاية)
				elif tile_hardness_level > 0:
					break_speed = 0.3 # بطيئة جدًا
				
				# 6. زيادة وقت التكسير
				time_held += get_process_delta_time() * break_speed
				
				# 💡 تحديث بلاطة الشقوق باستمرار
				update_crack_tile(cell_coords, time_held, BLOCK_BREAK_TIME)
				
				# 7. التحقق من اكتمال التكسير
				if time_held >= BLOCK_BREAK_TIME:
					break_sound.play()
					# --- إعطاء الموارد للاعب ---
					var tile_name = target_tile_data.get_custom_data("name")
					if typeof(tile_name) == TYPE_STRING and not tile_name.is_empty():
						player.add_item(tile_name, 1)

						# --- Remove torch light if breaking a torch ---
					if tile_name == "torch":
						_update_torch_light(current_breaking_cell, false)


					# --- مسح البلاطة من العالم ---
					if tile_name == "water":
						_remove_water_cell(current_breaking_cell)
					else:
						ground_layer.set_cell(current_breaking_cell, -1)
					# 💡 إزالة الشقوق بعد التكسير
					cracks_layer.set_cell(current_breaking_cell, -1)
					# تسجيل التغيير في نظام الحفظ
					world_modifications[current_breaking_cell] = {"source": -1, "coords": {"x": -1, "y": -1}}
					
					# إعادة تعيين المؤقت
					time_held = 0.0
					current_breaking_cell = Vector2i(-1, -1) # لإيقاف التكسير التلقائي
			else:
				# إذا كانت الأداة ضعيفة جدًا، لا تفعل شيئًا وأعد تعيين المؤقت
				time_held = 0.0
				# 💡 إزالة الشقوق في حالة الفشل
				cracks_layer.set_cell(cell_coords, -1)
				current_breaking_cell = Vector2i(-1, -1)
		else:
			# إذا كانت الخانة فارغة، لا تفعل شيئًا
			time_held = 0.0
			# 💡 إزالة الشقوق إذا كان الهدف فارغًا
			cracks_layer.set_cell(cell_coords, -1)
			current_breaking_cell = Vector2i(-1, -1)
	else:
		# إذا لم يكن اللاعب يضغط على زر الماوس، أعد تعيين المؤقت
		time_held = 0.0
		# 💡 إزالة الشقوق عندما يتوقف اللاعب عن الضغط
		if current_breaking_cell != Vector2i(-1, -1):
			cracks_layer.set_cell(current_breaking_cell, -1)
		current_breaking_cell = Vector2i(-1, -1)

# ---------------------------------------------------------------
#  منطق البناء (الزر الأيمن)
# ---------------------------------------------------------------
	if Input.is_action_pressed("mright"):
		var existing_tile_source = ground_layer.get_cell_source_id(cell_coords)
		if existing_tile_source == -1:
			# استخدم العنصر المختار من الشريط السفلي (Hotbar)
			var hotbar_index = 0
			var _sel = player.get("selected_hotbar_index")
			if _sel != null:
				hotbar_index = int(_sel)
			var selected_slot = null
			if hotbar_index >= 0 and hotbar_index < player.inventory_slots.size():
				selected_slot = player.inventory_slots[hotbar_index]
			
			if selected_slot and selected_slot.has("name"):
				var item_name = String(selected_slot["name"])
				if PLACEABLE_ITEM_TO_TILE.has(item_name):
					var tile_def = PLACEABLE_ITEM_TO_TILE[item_name]
					# --- وضع الإبداع ---
					if not SettingsManager.current_settings.is_creative_mode:
						if player.has_item(item_name, 1):
							player.remove_item(item_name, 1)
						else:
							return # لا تملك العنصر المطلوب
					# ضع البلاطة (الماء يستخدم نظام المستويات والفيزياء)
					if item_name == "water":
						_set_water_cell(cell_coords, WATER_SOURCE_LEVEL)
					else:
						ground_layer.set_cell(cell_coords, tile_def.source, tile_def.coords)
					world_modifications[cell_coords] = {
						"source": tile_def.source,
						"coords": {"x": tile_def.coords.x, "y": tile_def.coords.y}
					}
					place_sound.play()
					
					# Create torch light if placing a torch
					if item_name == "torch":
						_update_torch_light(cell_coords, true)

func update_day_night_cycle(delta: float):
	var time_change = (delta / DAY_LENGTH_IN_SECONDS) * 2.0
	time_of_day += time_change * time_direction
	
	if time_of_day >= 1.0:
		time_of_day = 1.0; time_direction = -1
	elif time_of_day <= 0.0:
		time_of_day = 0.0; time_direction = 1
	
	day_night_cycle.color = NIGHT_COLOR.lerp(DAY_COLOR, time_of_day)
	
	sun_light.rotation = lerp(-PI / 2, PI / 2, time_of_day)
	if time_of_day > 0.01 and time_of_day < 0.99:
		zombie_spawn_timer.stop()
	else:
		if zombie_spawn_timer.is_stopped():
			zombie_spawn_timer.start()

# دالة لتحديث بلاطة التشقق
func update_crack_tile(cell_pos: Vector2i, current_time: float, required_time: float):
	if required_time <= 0:
		cracks_layer.set_cell(cell_pos, -1)
		return

	var progress_percent = current_time / required_time
	
	var crack_index = int(progress_percent * CRACK_STAGES)
	crack_index = clamp(crack_index, 0, CRACK_STAGES - 1)
	
	var crack_coords = Vector2i(crack_index, 0)
	
	cracks_layer.set_cell(cell_pos, CRACKS_SOURCE_ID, crack_coords)

# ===================================================================
#  5. منطق توليد العالم (Chunks)
# ===================================================================

func update_player_chunk_movement():
	var tile_size = ground_layer.tile_set.tile_size
	var chunk_size_in_pixels = CHUNK_SIZE * tile_size
	var new_player_chunk = Vector2i(
		floor(player.global_position.x / chunk_size_in_pixels.x),
		floor(player.global_position.y / chunk_size_in_pixels.y)
	)
	if new_player_chunk != current_player_chunk:
		current_player_chunk = new_player_chunk
		update_chunks()

func update_chunks():
	var chunks_to_keep = {}
	for x in range(current_player_chunk.x - LOAD_RADIUS, current_player_chunk.x + LOAD_RADIUS + 1):
		for y in range(current_player_chunk.y - LOAD_RADIUS, current_player_chunk.y + LOAD_RADIUS + 1):
			var chunk_pos = Vector2i(x, y)
			chunks_to_keep[chunk_pos] = true
			if not loaded_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks:
		if not chunks_to_keep.has(chunk_pos):
			chunks_to_unload.append(chunk_pos)
	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)

func generate_chunk(chunk_pos: Vector2i):
	loaded_chunks[chunk_pos] = true
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	
	for x in range(start_x, start_x + CHUNK_SIZE):
		var surface_height = int(terrain_noise.get_noise_1d(x) * 20 + 40)
		var biome_value = biome_noise.get_noise_1d(x)
		
		# بحيرات على السطح: ضوضاء منخفضة = منخفض نضع فيه ماء
		var lake_val = lake_noise.get_noise_2d(x, surface_height)
		var lake_depth: int = 0
		if lake_val < LAKE_THRESHOLD:
			lake_depth = 1 + int(remap(lake_val, -1.0, LAKE_THRESHOLD, 1.0, float(LAKE_MAX_DEPTH)))
			lake_depth = clampi(lake_depth, 1, LAKE_MAX_DEPTH)
		
		# تعيين البلاطات دائماً لتجنب قيم null التي تسبب حفراً (يمكن لاحقاً إضافة بايوم آخر في else)
		var surface_tile = GRASS_TILE
		var sub_surface_tile = DIRT_TILE
		if biome_value > 0:
			surface_tile = GRASS_TILE
			sub_surface_tile = DIRT_TILE
		# else: مستقبلاً يمكن استخدام عشب/رمل مختلف
		
		for y in range(start_y, start_y + CHUNK_SIZE):
			var current_cell = Vector2i(x, y)
			if world_modifications.has(current_cell):
				var mod_data = world_modifications[current_cell]
				if mod_data["source"] == -1:
					water_levels.erase(_water_cell_key(current_cell))
					ground_layer.set_cell(current_cell, -1)
				else:
					var coords_dict = mod_data["coords"]
					var coords_vec = Vector2i(coords_dict["x"], coords_dict["y"])
					ground_layer.set_cell(current_cell, mod_data["source"], coords_vec)
					# إذا كان الماء، استعادة المستوى من الحفظ
					if coords_vec == WATER_TILE.coords and mod_data["source"] == WATER_TILE.source:
						_set_water_cell(current_cell, water_levels.get(_water_cell_key(current_cell), WATER_SOURCE_LEVEL))
					# Check if this is a torch and create light for it
					var tile_data = ground_layer.get_cell_tile_data(current_cell)
					if is_instance_valid(tile_data):
						var tile_name = tile_data.get_custom_data("name")
						if tile_name == "torch":
							_update_torch_light(current_cell, true)
				continue
			
			# بحيرة على السطح: ماء بفيزياء (منبع مستوى 8 أو المستوى المحفوظ)
			if lake_depth > 0 and y >= surface_height and y < surface_height + lake_depth:
				_set_water_cell(current_cell, water_levels.get(_water_cell_key(current_cell), WATER_SOURCE_LEVEL))
			elif y < surface_height:
				ground_layer.set_cell(current_cell, -1) # هواء
			elif y == surface_height:
				ground_layer.set_cell(current_cell, surface_tile.source, surface_tile.coords)
			elif y > surface_height and y <= surface_height + 5:
				ground_layer.set_cell(current_cell, sub_surface_tile.source, sub_surface_tile.coords)
			else:
				# تحت الأرض
				var cave_value = cave_noise.get_noise_2d(x, y)
				if cave_value > 0.4:
					ground_layer.set_cell(current_cell, -1) # كهف فارغ
				else:
					#  منطق توليد الخامات
					var vein_value = ore_vein_noise.get_noise_2d(x, y)
					if vein_value < 0.6:
						ground_layer.set_cell(current_cell, STONE_TILE.source, STONE_TILE.coords)
						continue
					var placed_ore = false
					# --- الألماس (Diamond) ---
					# يظهر بشكل أساسي في الأعماق السحيقة
					if y > 180:
						var diamond_chance = remap(y, 180, 300, 0, 4.0) # تزيد فرصة ظهوره كلما نزلنا أعمق
						if ore_noise.get_noise_2d(x, y) * 100 < diamond_chance:
							ground_layer.set_cell(current_cell, DIAMOND_TILE.source, DIAMOND_TILE.coords)
							placed_ore = true

					# --- الذهب (Gold) ---
					# يظهر بشكل أساسي في الأعماق المتوسطة إلى العميقة
					if not placed_ore and y > 120:
						var gold_chance = remap(y, 120, 250, 0, 6.0)
						if ore_noise.get_noise_2d(x, y) * 100 < gold_chance:
							ground_layer.set_cell(current_cell, GOLD_TILE.source, GOLD_TILE.coords)
							placed_ore = true

					# --- الحديد (Iron) ---
					# يظهر في نطاق واسع جدًا، لكنه أكثر شيوعًا في الأعماق المتوسطة
					if not placed_ore and y > 70:
						var iron_chance = 15.0 # نسبة ثابتة نسبيًا
						if ore_noise.get_noise_2d(x, y) * 100 < iron_chance:
							ground_layer.set_cell(current_cell, IRON_TILE.source, IRON_TILE.coords)
							placed_ore = true

					# --- الفحم (Coal) ---
					# يظهر في كل مكان تقريبًا، لكنه أكثر شيوعًا بالقرب من السطح
					if not placed_ore and y > 55:
						var coal_chance = 25.0 # شائع جدًا
						if ore_noise.get_noise_2d(x, y) * 100 < coal_chance:
							ground_layer.set_cell(current_cell, COAL_TILE.source, COAL_TILE.coords)
							placed_ore = true

					# إذا لم يتم وضع أي خامة (لأننا لم نكن في العمق المناسب أو لم يحالفنا الحظ)
					if not placed_ore:
						ground_layer.set_cell(current_cell, STONE_TILE.source, STONE_TILE.coords)

		
		# ==========================================================
		#  5. وضع الأشجار (Trees)
		# ==========================================================
		
		# 1. شرط المسافة: نولد شجرة مرة واحدة فقط كل 4 خلايا (يمكنك تعدي 4)
		if x % 4 != 0:
			continue
		# لا نضع أشجار في البحيرات
		if lake_depth > 0:
			continue
		
		var tree_noise_val = tree_noise.get_noise_2d(x, 0) 
		
		# 2. شرط الضوضاء: يجب أن يكون فوق حد معين لتوليد شجرة
		if tree_noise_val > 0.1:
				var actual_surface_y = -1
				
				# ابحث من surface_height المحسوب إلى الأسفل بمسافة 5 بلاطات
				for search_y in range(surface_height, surface_height + 5):
					var check_pos = Vector2i(x, search_y)
					var check_source_id = ground_layer.get_cell_source_id(check_pos)
					
					# إذا وجدنا بلاطة عشب أو تراب، فهذا هو السطح الحقيقي
					if check_source_id == GRASS_TILE.source or check_source_id == DIRT_TILE.source:
						actual_surface_y = search_y
						break
				
				# إذا لم نجد سطحاً صالحاً، تخطّ هذا العمود فقط (لا تخرج من التوليد بالكامل)
				if actual_surface_y == -1:
					continue
				
				# 4. شرط عدم وجود كتلة صلبة فوق السطح (يمنع الزرع داخل صخرة)
				var tile_above = ground_layer.get_cell_source_id(Vector2i(x, actual_surface_y - 1))
				
				# يجب أن نتحقق من أن البلاطة فوق السطح ليست شيئاً يمنع النمو
				if tile_above == -1 or tile_above == LEAVES_TILE.source: # أو أي بلاطة شفافة أخرى
					
					# زرع الشجرة باستخدام الارتفاع الفعلي الذي تم العثور عليه
					_place_tree(x, actual_surface_y)

func unload_chunk(chunk_pos: Vector2i):
	loaded_chunks.erase(chunk_pos)
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	for x in range(start_x, start_x + CHUNK_SIZE):
			for y in range(start_y, start_y + CHUNK_SIZE):
				var cell := Vector2i(x, y)
				ground_layer.set_cell(cell, -1)
				# Remove torch light if it belongs to this cell
				var key := str(cell.x) + "," + str(cell.y)
				if torch_lights.has(key):
					var n: Node2D = torch_lights[key]
					if is_instance_valid(n):
						n.queue_free()
				torch_lights.erase(key)

func _place_tree(x: int, surface_y: int):
	# ارتفاع ثابت للجذع
	const TREE_HEIGHT = 6
	
	# 1. وضع جذع الشجرة
	# حلقة لـ 4 بلاطات خشبية (من 1 إلى 4)
	for h in range(1, TREE_HEIGHT):
		var tile_y = surface_y - h 
		ground_layer.set_cell(Vector2i(x, tile_y), WOOD_TILE.source, WOOD_TILE.coords) 
	
	var top_leaf_y = surface_y - TREE_HEIGHT 
	
	# وضع بلاطة واحدة فقط في المنتصف (إحداثي x)
	ground_layer.set_cell(Vector2i(x, top_leaf_y), LEAVES_TILE.source, LEAVES_TILE.coords)

# ===================================================================
#  6. منطق الوحوش
# ===================================================================

func _on_zombie_spawn_timer_timeout() -> void:
	# لا تفرخ في الوضع الإبداعي
	if SettingsManager.current_settings.is_creative_mode:
		return
	# جرّب عدة مرات لإيجاد مكان مظلم (كهوف/ليل)
	for i in range(3):
		var spawn_pos = _find_empty_spawn_position()
		if spawn_pos.x < -999000:
			continue
		if is_position_dark(spawn_pos):
			var new_zombie = zombie_scene.instantiate()
			new_zombie.global_position = spawn_pos
			entity.add_child(new_zombie)

func _on_mobs_spawn_timer_timeout() -> void:
	for i in range(4):
		var spawn_pos = _find_empty_spawn_position()
		# Check if we got a valid position (not the sentinel value)
		if spawn_pos.x < -999000:  # Sentinel value check
			continue  # Skip this spawn if no empty position found
		
		# اختيار عشوائي بين الخاروف والبقرة
		var new_mob: Node2D
		if randf() < 0.5:
			new_mob = sheep_scene.instantiate()
		else:
			new_mob = cow_scene.instantiate()
		
		if is_instance_valid(new_mob):
			new_mob.global_position = spawn_pos
			entity.add_child(new_mob)

func _find_empty_spawn_position() -> Vector2:
	# Try multiple random positions until we find an empty one
	for attempt in range(20):  # Try up to 20 times
		var offset = Vector2(randf_range(-900, 900), -100)
		var world_pos = player.global_position + offset
		
		# Convert world position to tile coordinates
		var cell_coords = ground_layer.local_to_map(world_pos)
		
		# Check if there's no tile at the spawn position and below it
		var tile_at_spawn = ground_layer.get_cell_source_id(cell_coords)
		var tile_below = ground_layer.get_cell_source_id(Vector2i(cell_coords.x, cell_coords.y + 1))
		
		# Spawn only if both positions are empty (no tiles)
		if tile_at_spawn == -1 and tile_below == -1:
			return world_pos
	
	# If we couldn't find an empty spot after 20 attempts, return sentinel value
	return Vector2(-999999, -999999)

# ============================
# أدوات الإضاءة/الظلام للعالم
# ============================
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local = ground_layer.to_local(world_pos)
	return ground_layer.local_to_map(local)

func _cell_exposed_to_sky(cell: Vector2i, max_scan: int = 200) -> bool:
	for y in range(cell.y - 1, cell.y - max_scan, -1):
		var src = ground_layer.get_cell_source_id(Vector2i(cell.x, y))
		if src != -1:
			return false
	return true

func is_position_in_sunlight(world_pos: Vector2) -> bool:
	# يعتبر مشمسًا إذا كان نهارًا ومكشوفًا للسماء
	if time_of_day < 0.55:
		return false
	var cell = _world_to_cell(world_pos)
	return _cell_exposed_to_sky(cell)

func is_position_dark(world_pos: Vector2) -> bool:
	# إذا كنا قريبين من شعلة مضاءة، فالموضع يعتبر مضاءً
	for key in torch_lights.keys():
		var node: PointLight2D = torch_lights[key]
		if is_instance_valid(node) and node.energy > 0.05:
			var r: float = _effective_light_radius(node)
			if node.global_position.distance_to(world_pos) <= r:
				return false
	# ظلام إذا كان ليل أو الموقع غير مكشوف للسماء (كهوف)
	if time_of_day <= 0.4:
		return true
	var cell = _world_to_cell(world_pos)
	return not _cell_exposed_to_sky(cell)

func player_died():
	# 1. مسح كل الأغراض (الإنفنتوري)
	if player and "inventory_slots" in player:
		player.inventory_slots.clear()
		# هنا قد تحتاج لاستدعاء تحديث لـ UI المخزون إذا كان في مكان آخر
	
	# 2. إعادة تعيين موضع اللاعب والصحة
	player.global_position = PLAYER_SPAWN_POSITION
	
	# 3. إيقاف حركة اللاعب وإعادة تعيين الصحة
	player.health = 20
	player.hunger = 20
	player.oxygen = float(player.MAX_OXYGEN)
	player.set_physics_process(false) # إيقاف مؤقت لحركة اللاعب
	
	# 4. حفظ اللعبة بعد إعادة تعيين حالة اللاعب
	do_save() 

	# 5. إظهار شاشة الموت
	var died_screen = DIED_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(died_screen)
	

# ===================================================================
#  7. منطق الحفظ والتحميل
# ===================================================================

func do_save():
	print("saveing game...")
	
	var serializable_mods = {}
	for cell_pos in world_modifications:
		var key_string = "%d,%d" % [cell_pos.x, cell_pos.y]
		serializable_mods[key_string] = world_modifications[cell_pos]

	var save_data = {
		"player_position_x": player.global_position.x,
		"player_position_y": player.global_position.y,
		"player_inventory": player.inventory_slots,
		"player_health": player.health,
		"player_hunger": player.hunger,
		"player_oxygen": player.oxygen,
		"world_seed": terrain_noise.seed,
		"cave_scale": cave_scale,
		"modifications": serializable_mods,
		"water_levels": water_levels,
		"time_of_day": time_of_day
	}
	SaveManager.save_game(save_data)

func do_load():
	if not SaveManager.has_save_data(): return
	var loaded_data = SaveManager.load_game()
	if loaded_data.is_empty():return
	
	print("loading game...")
	
	time_of_day = loaded_data.get("time_of_day")
	cave_scale = loaded_data.get("cave_scale")
	terrain_noise.seed = loaded_data.get("world_seed", randi())
	cave_noise.seed = terrain_noise.seed
	ore_noise.seed = terrain_noise.seed
	ore_vein_noise.seed = terrain_noise.seed + 1
	biome_noise.seed = terrain_noise.seed + 10
	tree_noise.seed = terrain_noise.seed + 2
	lake_noise.seed = terrain_noise.seed + 5
	lake_noise.frequency = 0.025
	lake_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	lake_noise.fractal_octaves = 2
	
	_clear_all_torch_lights()
	loaded_chunks.clear()
	world_modifications.clear()
	water_levels = loaded_data.get("water_levels", {})
	ground_layer.clear()
		
	var loaded_mods = loaded_data.get("modifications", {})
	for key_string in loaded_mods:
		var parts = key_string.split(",")
		if parts.size() != 2: continue
		var cell_pos = Vector2i(int(parts[0]), int(parts[1]))
		world_modifications[cell_pos] = loaded_mods[key_string]
	
		player.global_position = Vector2(
			loaded_data.get("player_position_x", 0),
			loaded_data.get("player_position_y", 0)
	)
	# Load inventory with proper fallback to empty array
	var loaded_inventory = loaded_data.get("player_inventory", [])
	if loaded_inventory is Array:
		player.inventory_slots = loaded_inventory
	else:
		player.inventory_slots = []
	
	# Ensure inventory is properly sized
	while player.inventory_slots.size() < player.INVENTORY_SIZE:
		player.inventory_slots.append(null)
	
	player.health = loaded_data.get("player_heath", 20)
	player.hunger = loaded_data.get("player_hunger", 20)
	player.oxygen = loaded_data.get("player_oxygen", float(player.MAX_OXYGEN))
	player.update_all_ui()
	
	if player.health == 0:
		player.health = 20
	
	update_chunks()

func _auto_save() -> void:
	do_save()
