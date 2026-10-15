# ===================================================================
#  Player.gd - لاعب واحد
# ===================================================================
extends CharacterBody2D

# ===================================================================
#  1. إعدادات اللاعب الأساسية
# ===================================================================

# --- سرعات الحركة ---
const BASE_SPEED = 150.0  # السرعة الأساسية (مشى عادي)
const RUN_SPEED = BASE_SPEED + 50.0  # سرعة الركض: 200 (150 + 50)
const CROUCH_SPEED = BASE_SPEED - 50.0  # سرعة الزحف: 100 (150 - 50)
const JUMP_VELOCITY = -225.0

const BASE_ATTACK_DAMAGE = 4
var attack_cooldown: float = 0.25 # فترة تباطؤ بين الهجمات
var attack_timer: float = 0.0

# --- مقياس الاصطدام (Collision Scale) ---
const NORMAL_SCALE = Vector2(1, 1) # مقياس طبيعي
const CROUCH_SCALE = Vector2(1, 0.861)# مقياس الزحف (نصف الارتفاع) 
const NORMAL_POS = Vector2(-0.56, 0) # الموضع الطبيعي (المركز)
const CROUCH_POS = Vector2(-0.56, 2.25) # <--- الموضع عند الزحف: تم تحريكه للأسفل

var current_speed = BASE_SPEED

var max_health = 20
var health = 20

# --- التنفس والغرق ---
const MAX_OXYGEN = 20
var oxygen: float = 20.0
const OXYGEN_DRAIN_RATE = 1.0      # نقص التنفس تحت الماء (في الثانية)
const OXYGEN_RECOVER_RATE = 6.0    # استعادة التنفس في الهواء
const DROWN_DAMAGE_INTERVAL = 0.5   # ضرر الغرق كل ثانية
const DROWN_DAMAGE_AMOUNT = 2
var _drown_timer: float = 0.0

# --- روابط العقد ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_particles: CPUParticles2D = $Particles/Jump
@onready var run_particles: CPUParticles2D = $Particles/Run
@onready var eat_sound: AudioStreamPlayer2D = $Sounds/Eat
@onready var damge_sound: AudioStreamPlayer2D = $Sounds/Damge
@onready var health_bar: TextureProgressBar = $"UI/Health Bar"
@onready var hunger_bar: TextureProgressBar = $"UI/Hunger Bar"
@onready var breath_bar: ProgressBar = $"UI/Breath Bar"
@onready var crafting_ui: Control = $UI/InventoryPanel/CraftingUI
@onready var inventory_panel: Panel = $UI/InventoryPanel
@onready var hotbar_container: Control = $UI/HotbarContainer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $HitBox

# ===============================================================
#  قاموس بيانات العناصر
# ===============================================================

var ITEM_DATA = {
	# --- الموارد ---
	"bread": {"is_tool": false},
	"meat": {"is_tool": false},
	"wood": {"is_tool": false},
	"planks": {"is_tool": false},
	"working_table": {"is_tool": false},
	"stick": {"is_tool": false},
	"torch": {"is_tool": false},
	"grass": {"is_tool": false},
	"dirt": {"is_tool": false},
	"stone": {"is_tool": false},
	"coal": {"is_tool": false},
	"iron": {"is_tool": false},
	"gold": {"is_tool": false},
	"diamond": {"is_tool": false},
	
	# --- الأدوات ---
	"wood_pickaxe": {"is_tool": true, "tool_id": "wood_pickaxe"},
	"stone_pickaxe": {"is_tool": true, "tool_id": "stone_pickaxe"},
	"iron_pickaxe": {"is_tool": true, "tool_id": "iron_pickaxe"},
	"gold_pickaxe": {"is_tool": true, "tool_id": "gold_pickaxe"},
	"diamond_pickaxe": {"is_tool": true, "tool_id": "diamond_pickaxe"},
	"wood_axe": {"is_tool": true, "tool_id": "wood_axe"},
	"stone_axe": {"is_tool": true, "tool_id": "stone_axe"},
	"iron_axe": {"is_tool": true, "tool_id": "iron_axe"},
	"gold_axe": {"is_tool": true, "tool_id": "gold_axe"},
	"diamond_axe": {"is_tool": true, "tool_id": "diamond_axe"},
	"wood_shovel": {"is_tool": true, "tool_id": "wood_shovel"},
	"stone_shovel": {"is_tool": true, "tool_id": "stone_shovel"},
	"iron_shovel": {"is_tool": true, "tool_id": "iron_shovel"},
	"gold_shovel": {"is_tool": true, "tool_id": "gold_shovel"},
	"diamond_shovel": {"is_tool": true, "tool_id": "diamond_shovel"},
	"wood_sword": {"is_tool": true, "tool_id": "wood_sword"},
	"stone_sword": {"is_tool": true, "tool_id": "stone_sword"},
	"iron_sword": {"is_tool": true, "tool_id": "iron_sword"},
	"gold_sword": {"is_tool": true, "tool_id": "gold_sword"},
	"diamond_sword": {"is_tool": true, "tool_id": "diamond_sword"},
}

# ===============================================================
#  نظام الأدوات
# ===============================================================

var TOOLS = {
	"hand": {"type": "hand", "level": 0, "speed_multiplier": 0.5, "damage": 1},
	"wood_pickaxe":  {"type": "pickaxe", "level": 1, "speed_multiplier": 1.0, "damage": 2},
	"stone_pickaxe": {"type": "pickaxe", "level": 2, "speed_multiplier": 1.5, "damage": 2},
	"iron_pickaxe":  {"type": "pickaxe", "level": 3, "speed_multiplier": 2.0, "damage": 3},
	"gold_pickaxe":  {"type": "pickaxe", "level": 4, "speed_multiplier": 2.5, "damage": 3},
	"diamond_pickaxe":  {"type": "pickaxe", "level": 5, "speed_multiplier": 4.0, "damage": 4},
	"wood_axe": {"type": "axe", "level": 1, "speed_multiplier": 1.0, "damage": 2},
	"stone_axe": {"type": "axe", "level": 2, "speed_multiplier": 1.5, "damage": 2},
	"iron_axe": {"type": "axe", "level": 3, "speed_multiplier": 2.0, "damage": 3},
	"gold_axe": {"type": "axe", "level": 4, "speed_multiplier": 2.5, "damage": 3},
	"diamond_axe": {"type": "axe", "level": 5, "speed_multiplier": 4.0, "damage": 4},
	"wood_shovel": {"type": "shovel", "level": 1, "speed_multiplier": 1.0, "damage": 2},
	"stone_shovel": {"type": "shovel", "level": 2, "speed_multiplier": 1.5, "damage": 2},
	"iron_shovel": {"type": "shovel", "level": 3, "speed_multiplier": 2.0, "damage": 3},
	"gold_shovel": {"type": "shovel", "level": 4, "speed_multiplier": 2.5, "damage": 3},
	"diamond_shovel": {"type": "shovel", "level": 5, "speed_multiplier": 4.0, "damage": 4},
	"wood_sword": {"type": "sword", "level": 0, "speed_multiplier": 1.0, "damage": 2},
	"stone_sword": {"type": "sword", "level": 0, "speed_multiplier": 1.0, "damage": 4},
	"iron_sword": {"type": "sword", "level": 0, "speed_multiplier": 1.0, "damage": 6},
	"gold_sword": {"type": "sword", "level": 0, "speed_multiplier": 1.0, "damage": 6},
	"diamond_sword": {"type": "sword", "level": 0, "speed_multiplier": 1.0, "damage": 8},
}

var current_tool_name = "hand"

# ===================================================================
#  1. متغيرات الجوع
# ===================================================================

var max_hunger = 20
var hunger = 20
var hunger_timer = 240
const HUNGER_TICK_RATE = 25
const HEALTH_LOSS_RATE = 0.5

# ===============================================================
#  2. نظام المخزون (Inventory)
# ===============================================================

const INVENTORY_SIZE = 36
const MAX_STACK_SIZE = 64
var inventory_slots: Array

const HOTBAR_SIZE = 9
var selected_hotbar_index = 0

var item_textures = {}
var UI_SLOT_SCRIPT = preload("res://Scripts/ui_slot.gd")

# ===================================================================
#  3. الدوال الأساسية لـ Godot
# ===================================================================

func _ready():
	await get_tree().process_frame
	
	var ui_node = get_tree().root.get_node_or_null("World/UI")
	if ui_node:
		hotbar_container = ui_node.get_node_or_null("%HotbarContainer")
		inventory_panel = ui_node.get_node_or_null("%InventoryPanel")
	
	inventory_slots.resize(INVENTORY_SIZE)
	
	_load_item_textures()

	if is_instance_valid(inventory_panel):
		inventory_panel.visible = false
	
	update_all_ui()
	select_hotbar_slot(0)

func _physics_process(delta: float):
	if SettingsManager.current_settings.is_creative_mode:
		health = 20
		velocity = Vector2.ZERO
		var fly_direction = Input.get_vector("left", "right", "jump", "crouch")
		velocity = fly_direction * RUN_SPEED * 1.5
	else:
		if not is_on_floor():
			velocity.y += get_gravity().y * delta

	var is_crouching = Input.is_action_pressed("crouch")
	
	if Input.is_action_pressed("run"):
		current_speed = RUN_SPEED
		collision_shape.scale = NORMAL_SCALE
		collision_shape.position = NORMAL_POS # <--- موضع طبيعي
	elif is_crouching:
		current_speed = CROUCH_SPEED
		# تصغير Collision Shape عند الزحف وتعديل الموضع
		collision_shape.scale = CROUCH_SCALE
		collision_shape.position = CROUCH_POS # <--- موضع الزحف (تم تحريكه للأسفل)
	else:
		current_speed = BASE_SPEED
		# العودة إلى الحجم الطبيعي والموضع الطبيعي
		collision_shape.scale = NORMAL_SCALE
		collision_shape.position = NORMAL_POS # <--- موضع طبيعي
	
	if Input.is_action_pressed("mleft") and attack_timer <= 0:
		_attack()
		attack_timer = attack_cooldown # إعادة ضبط المؤقت
	
	if Input.is_action_just_pressed("mright"):
		eat_food_in_hand()
	
	$UI/AttackCooldown.value = attack_timer
	$HitBox.position = get_local_mouse_position()
	
	# تحديث مؤقت الهجوم
	if attack_timer > 0:
		attack_timer -= delta
	
	# 2. تطبيق الحركة والسرعة المحدثة
	handle_movement_input()
	move_and_slide()
	update_visuals()
	update_health_ui()
	update_all_ui()
	update_hunger(delta)
	update_breath(delta)


func _unhandled_input(event: InputEvent):
	if Input.is_action_just_pressed("F1"):
		SettingsManager.current_settings.is_creative_mode = false
		hunger_bar.visible = true
		health_bar.visible = true
		if is_instance_valid(breath_bar):
			breath_bar.visible = true
		update_all_ui()
	
	if Input.is_action_just_pressed("F2"):
		SettingsManager.current_settings.is_creative_mode = true
		for All_Items in ITEM_DATA:
			remove_item(All_Items,64)
			add_item(All_Items,64)
		hunger_bar.visible = false
		health_bar.visible = false
		if is_instance_valid(breath_bar):
			breath_bar.visible = false
		update_all_ui()
	
	if Input.is_action_just_pressed("F3"):
		$UI.visible = !$UI.visible
	
	if Input.is_action_just_pressed("inventory"):
		inventory_panel.visible = !inventory_panel.visible
		if crafting_ui.visible:
			crafting_ui.hide()
		else:
			crafting_ui.open_ui(self)
	
	if Input.is_action_just_pressed("crafting"):
		inventory_panel.visible = !inventory_panel.visible
		if crafting_ui.visible:
			crafting_ui.hide()
		else:
			crafting_ui.open_ui(self)
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_hotbar_slot((selected_hotbar_index - 1 + HOTBAR_SIZE) % HOTBAR_SIZE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_hotbar_slot((selected_hotbar_index + 1) % HOTBAR_SIZE)
	
	for i in range(1, HOTBAR_SIZE + 1):
		if Input.is_action_just_pressed("slot " + str(i)):
			select_hotbar_slot(i - 1)
	

func take_damage(amount: int):
	# 1. تقليل الصحة
	health -= amount
	damge_sound.play()
	
	# 2. التحقق من الموت
	if health <= 0:
		var overworld = get_parent() 
		if is_instance_valid(overworld) and "player_died" in overworld:
			overworld.player_died()
	
	update_health_ui()

func _attack():
	# 1. تحديد السلاح وقوة الضرر
	var equipped_item_name: String = "hand" # الافتراضي هو اليد
	var item_data: Dictionary = TOOLS.get(equipped_item_name, {})
	
	# يتم التحقق من العنصر في خانة الأشرطة السريعة المحددة
	var selected_slot_data = inventory_slots[selected_hotbar_index]
	
	if selected_slot_data and selected_slot_data.has("name"):
		var current_item_name = selected_slot_data["name"]
		
		# البحث عن ضرر العنصر في القاموس
		if TOOLS.has(current_item_name):
			item_data = TOOLS[current_item_name]
			equipped_item_name = current_item_name
# الحصول على قيمة الضرر	
	# نستخدم get("damage", 1) لضمان قيمة افتراضية (1) إذا لم يكن للعنصر مفتاح "damage"
	var actual_damage: int = int(item_data.get("damage", 1)) 
	
	# 2. الحصول على الكائنات الموجودة داخل نطاق HitBox
	var bodies_in_range = hitbox.get_overlapping_bodies()
	
	# 3. تمرير الضرر إلى جميع الكائنات القابلة للتضرر
	for body in bodies_in_range:
		
		# التحقق من دالة take_damage في الكائن (الزومبي/الخاروف)
		if body.has_method("take_mob_damage"):
			body.take_mob_damage(actual_damage)
			
			var push_direction = sign(body.global_position.x - global_position.x)
			body.velocity.x += push_direction * 4

func handle_movement_input():
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_particles.emitting = true
	
	var direction = Input.get_axis("left", "right")
	if direction:
		# استخدام current_speed المحدثة
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

func update_visuals():
	var direction = Input.get_axis("left", "right")
	
	if direction != 0:
		# تحديد اتجاه النظر
		if direction > 0:
			animated_sprite.flip_h = false
		elif direction < 0:
			animated_sprite.flip_h = true

		if Input.is_action_pressed("run"):
			animated_sprite.play("run")  # استخدام "run" للركض
			run_particles.emitting = true
		elif Input.is_action_pressed("crouch"):
			animated_sprite.play("crouch") # افترض وجود رسوم "crouch"
			run_particles.emitting = false
		else:
			animated_sprite.play("walk") # افترض وجود رسوم "walk" للمشي العادي
			run_particles.emitting = false
	else:
		# اللاعب واقف
		if Input.is_action_pressed("crouch"):
			animated_sprite.play("idle_crouch") # افترض وجود رسوم "idle_crouch"
		else:
			animated_sprite.play("idle")
		run_particles.emitting = false

func update_health_ui():
	if SettingsManager.current_settings.is_creative_mode:
		return
	health_bar.value = health

func update_breath(delta: float) -> void:
	if SettingsManager.current_settings.is_creative_mode:
		return
	if not is_instance_valid(breath_bar):
		return
	var world = get_parent()
	var in_water: bool = world.has_method("is_position_in_water") and world.is_position_in_water(global_position)
	if in_water:
		oxygen = max(0.0, oxygen - OXYGEN_DRAIN_RATE * delta)
		breath_bar.visible = true
		breath_bar.value = oxygen
		breath_bar.max_value = MAX_OXYGEN
		if oxygen <= 0.0:
			_drown_timer += delta
			if _drown_timer >= DROWN_DAMAGE_INTERVAL:
				_drown_timer = 0.0
				take_damage(DROWN_DAMAGE_AMOUNT)
	else:
		oxygen = min(float(MAX_OXYGEN), oxygen + OXYGEN_RECOVER_RATE * delta)
		_drown_timer = 0.0
		breath_bar.value = oxygen
		breath_bar.max_value = MAX_OXYGEN
		if oxygen >= MAX_OXYGEN:
			breath_bar.visible = false
		else:
			breath_bar.visible = true

# ===============================================================
#  دوال إدارة المخزون الأساسية
# ===============================================================

func add_item(item_name: String, quantity: int):
	var remaining_quantity = quantity
	
	# First, try to stack into existing slots with the same item
	for i in range(inventory_slots.size()):
		var slot_data = inventory_slots[i]
		if slot_data and slot_data["name"] == item_name and slot_data["quantity"] < MAX_STACK_SIZE:
			var can_add = MAX_STACK_SIZE - slot_data["quantity"]
			var to_add = min(remaining_quantity, can_add)
			slot_data["quantity"] += to_add
			remaining_quantity -= to_add
			if remaining_quantity <= 0:
				update_all_ui()
				return true
	
	# Then, place into empty slots
	if remaining_quantity > 0:
		for i in range(inventory_slots.size()):
			if inventory_slots[i] == null:
				var to_add = min(remaining_quantity, MAX_STACK_SIZE)
				inventory_slots[i] = {"name": item_name, "quantity": to_add}
				remaining_quantity -= to_add
				if remaining_quantity <= 0:
					break
	
	update_all_ui()
	return remaining_quantity <= 0

func remove_item(item_name: String, quantity: int):
	var quantity_to_remove = quantity
	
	for i in range(inventory_slots.size() - 1, -1, -1):
		var slot_data = inventory_slots[i]
		if slot_data and slot_data["name"] == item_name:
			var removed_amount = min(quantity_to_remove, slot_data["quantity"])
			slot_data["quantity"] -= removed_amount
			quantity_to_remove -= removed_amount
			
			if slot_data["quantity"] <= 0:
				inventory_slots[i] = null
			
			if quantity_to_remove <= 0:
				break

	update_all_ui()

func has_item(item_name: String, quantity: int) -> bool:
	var count = 0
	for slot_data in inventory_slots:
		if slot_data and slot_data["name"] == item_name:
			count += slot_data["quantity"]
		
	return count >= quantity

func remove_item_by_index(index: int) -> bool:
	# تأكد من أن المتغير inventory_slots موجود ومعرّف في player.gd
	if not has_method("get_inventory_slots"):
		# إذا لم يكن المخزون متاحًا، لا يمكننا الإزالة.
		print("ERROR: player.gd must have inventory_slots array.")
		return false
	
	# استخدم الدالة الموجودة في ui_slot.gd للحصول على المخزون (أو قم بالوصول المباشر إليه)
	# سنفترض أنه يمكنك الوصول مباشرة إلى inventory_slots
	
	# التحقق من أن المؤشر ضمن نطاق المخزون
	if index >= 0 and index < inventory_slots.size():
		# تأكد من أن هناك شيئًا ما في الخانة قبل إفراغها
		if inventory_slots[index] != null:
			# إفراغ الخانة بتعيينها إلى القيمة الفارغة (null)
			inventory_slots[index] = null
			
			# قد تحتاج أيضًا إلى تحديث واجهة المخزون هنا
			update_all_ui() # إذا كان لديك إشارة لتحديث واجهة المستخدم
			
			return true
	
	return false

# ===============================================================
#  دوال تحديث واجهة المستخدم
# ===============================================================

func update_all_ui():
	# Update hotbar UI
	if is_instance_valid(hotbar_container):
		for i in range(hotbar_container.get_child_count()):
			var slot_root = hotbar_container.get_child(i)
			var slot_node = slot_root.get_node_or_null("Panel") if slot_root else null
			if slot_node == null:
				slot_node = slot_root
			# Attach drag/drop script and context to the interactive Panel
			if slot_node and not slot_node.get_script():
				slot_node.set_script(UI_SLOT_SCRIPT)
			if slot_node and "set_context" in slot_node:
				slot_node.set_context(self, i)
			var slot_data = null
			if i < inventory_slots.size():
				slot_data = inventory_slots[i]
			update_slot_ui(slot_root, slot_data)
	
	# Update inventory grid UI
	if is_instance_valid(inventory_panel):
		var inventory_grid_container = inventory_panel.get_node_or_null("GridContainer")
		if is_instance_valid(inventory_grid_container):
			for i in range(inventory_grid_container.get_child_count()):
				var inventory_index = i + HOTBAR_SIZE
				var slot_root = inventory_grid_container.get_child(i)
				var slot_node = slot_root.get_node_or_null("ItemTexture") if slot_root else null
				if slot_node == null:
					slot_node = slot_root
				# Attach drag/drop script and context to the interactive Panel
				if slot_node and not slot_node.get_script():
					slot_node.set_script(UI_SLOT_SCRIPT)
				if slot_node and "set_context" in slot_node:
					slot_node.set_context(self, inventory_index)
				var slot_data = null
				if inventory_index < inventory_slots.size():
					slot_data = inventory_slots[inventory_index]
				update_slot_ui(slot_root, slot_data)

func update_slot_ui(slot_node, slot_data):
	# Try to resolve the texture and label nodes robustly, even if slot_node is a child (e.g., TextureRect)
	var texture_rect_node = slot_node.get_node_or_null("ItemTexture")
	var label_node = slot_node.get_node_or_null("QuantityLabel")
	if texture_rect_node == null:
		texture_rect_node = slot_node.find_child("ItemTexture", true, false)
	if label_node == null:
		label_node = slot_node.find_child("QuantityLabel", true, false)
	
	if not (texture_rect_node and label_node):
		# Try one level up (in case slot_node is the TextureRect itself)
		var parent = slot_node.get_parent()
		if parent:
			if texture_rect_node == null:
				texture_rect_node = parent.get_node_or_null("ItemTexture")
			if label_node == null:
				label_node = parent.get_node_or_null("QuantityLabel")
			if texture_rect_node == null:
				texture_rect_node = parent.find_child("ItemTexture", true, false)
			if label_node == null:
				label_node = parent.find_child("QuantityLabel", true, false)
	
	if not (texture_rect_node and label_node):
		# Silent return to avoid console spam when layout differs
		return
	
	if slot_data and item_textures.has(slot_data["name"]):
		texture_rect_node.texture = item_textures[slot_data["name"]]
		texture_rect_node.visible = true
		label_node.text = str(slot_data["quantity"])
		label_node.visible = not SettingsManager.current_settings.is_creative_mode
	else:
		texture_rect_node.visible = false
		label_node.visible = false

func select_hotbar_slot(new_index: int):
	selected_hotbar_index = new_index
	update_current_tool(selected_hotbar_index)
	
	if is_instance_valid(hotbar_container):
		for i in range(hotbar_container.get_child_count()):
			var slot = hotbar_container.get_child(i)
			if i == selected_hotbar_index:
				slot.modulate = Color(1, 1, 1) 
			else:
				slot.modulate = Color(0.6, 0.6, 0.6)

func update_current_tool(selected_index: int):
	var slot_data = null
	if selected_index < inventory_slots.size():
		slot_data = inventory_slots[selected_index]
	if slot_data and ITEM_DATA.has(slot_data["name"]) and ITEM_DATA[slot_data["name"]]["is_tool"]:
		current_tool_name = ITEM_DATA[slot_data["name"]]["tool_id"]
	else:
		current_tool_name = "hand"
	print("Equipped: ", current_tool_name)

func _load_item_textures():
	item_textures = {}
	var textures_path = "res://Assets/Texture/Items/"
	for item_name in ITEM_DATA.keys():
		var texture_path = textures_path + item_name + ".png"
		var loaded_texture = load(texture_path)
		if loaded_texture:
			item_textures[item_name] = loaded_texture
		else:
			print("Warning: Texture not found for item: ", item_name, " at path: ", texture_path)
			

# ===================================================================
#  4. إضافة دوال الجوع والأكل
# ===================================================================

func update_hunger(delta: float):
	if SettingsManager.current_settings.is_creative_mode:
		hunger = max_hunger
		return
	hunger_timer += delta
	hunger_bar.value = hunger
	
	if hunger_timer >= HUNGER_TICK_RATE:
		hunger_timer = 0.0
		if hunger > 0:
			hunger -= 1
		if hunger <= 0:
			take_damage(1)
			damge_sound.play()

func eat_food_in_hand():
	var selected_slot_data = inventory_slots[selected_hotbar_index]
	if not selected_slot_data:
		return
	
	if FoodDB.is_food(selected_slot_data["name"]):
		var hunger_to_restore = FoodDB.get_hunger_value(selected_slot_data["name"])
		
		if hunger >= max_hunger:
			print("Not hungry.")
			return
			
		remove_item(selected_slot_data["name"], 1)
		
		hunger = min(hunger + hunger_to_restore, max_hunger)
		
		print("Ate ", selected_slot_data["name"], ". Hunger is now: ", hunger)
		eat_sound.play()
