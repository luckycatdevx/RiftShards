extends CharacterBody2D

var SPEED = 100.0
const JUMP_VELOCITY = -225.0
const WALL_CHECK_DISTANCE = 35

var health = 16
var is_dead = false

# الحالات الممكنة
enum State { IDLE, WANDER } 
var current_state = State.IDLE

# مؤقت تحديد الحركة العشوائية
@onready var movement_timer: Timer = $MovementTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_check_ray: RayCast2D = $WallCheckRay

# ===================================================================
#  الدوال الأساسية لـ Godot
# ===================================================================

func _ready():
	# بدء الحركة العشوائية
	movement_timer.start(randf_range(1.0, 3.0)) # يبدأ الحركة بعد 1-3 ثوانٍ

func _physics_process(delta):
	# تطبيق الجاذبية
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# منطق آلة الحالة
	match current_state:
		State.IDLE:
			# عندما يكون الكائن خاملاً، لا يغير سرعته الأفقية
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		State.WANDER:
			# يتحرك بالسرعة المحددة (SPEED سيحدده الـ Timer)
			velocity.x = move_toward(velocity.x, SPEED, 5.0) 
			
			_handle_jump()
			
			# تحديث اتجاه الصورة بناءً على الحركة
			if velocity.x > 0.0:
				animated_sprite.flip_h = false
				wall_check_ray.target_position.x = 35
			elif velocity.x < 0.0:
				wall_check_ray.target_position.x = -35
				animated_sprite.flip_h = true
				
	move_and_slide()

func take_mob_damage(damage_amount: int):
	if is_dead:
		return
	health -= damage_amount
	
	# اهتزاز الكائن أو تغيير لونه للحظة
	modulate = Color.RED # تغيير اللون للأحمر
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if health <= 0:
		_die()

# ===================================================================
#  دالة الموت
# ===================================================================

func _die():
	if is_dead:
		return
		
	is_dead = true
	
	# توقف عن الحركة
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Drop meat when sheep dies
	var player = get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("add_item"):
		player.add_item("meat", randi_range(1,2))  # Drop 1 or 2 meat when sheep dies 
	
	# 2. حذف الكائن
	# يمكن تأخير الحذف لإظهار رسوم متحركة للموت أولاً
	queue_free()

# ===================================================================
#  دالة التعامل مع القفز
# ===================================================================

func _handle_jump():
	if is_on_floor() and current_state == State.WANDER:
		# 1. تحديد الاتجاه (يعتمد على سرعة الحركة الحالية)
		var check_dir = sign(velocity.x)
		if check_dir == 0:
			# إذا كان خاملاً (وهو أمر غير متوقع في حالة WANDER)، فليستخدم الاتجاه الأخير
			check_dir = 1.0 

		wall_check_ray.target_position.x = check_dir * WALL_CHECK_DISTANCE
		
		# 2. إذا اكتشف RayCast شيئًا أمامه (جدار أو عائق)
		if wall_check_ray.is_colliding():
			var collider = wall_check_ray.get_collider()
			# تأكد من أنه لا يقفز إذا كان أمامه كائن يمكنه الاصطدام به (ليس اللاعب، ليس عدو)
			# يمكنك تعديل هذا الشرط بناءً على المجموعات الخاصة بك
			if collider and not collider.is_in_group("Player") and not collider.is_in_group("Enemy"):
				
				velocity.y = JUMP_VELOCITY
				
				# 3. تغيير الاتجاه بعد القفز (لمنع التعليق)
				# بما أن SPEED يحمل إشارة الاتجاه، نعكسه
				SPEED = -SPEED 
				
				# إعادة تشغيل المؤقت فوراً لإضافة حركة عشوائية جديدة
				_set_new_wander_target_after_jump()

# ===================================================================
#  دالة تحديد الحركة العشوائية (FSM)
# ===================================================================

func _on_movement_timer_timeout():
	# 1. اختيار الحركة العشوائية
	var next_move = randi_range(0, 2) # 0: قف، 1: تحرك يسار، 2: تحرك يمين
	
	# 2. تغيير الحالة
	match next_move:
		0: # Idle
			current_state = State.IDLE
			movement_timer.start(randf_range(1.5, 4.0)) # وقت خمول أطول
			
		1: # Wander Left
			current_state = State.WANDER
			SPEED = -100.0 # لجعل السرعة سلبية (لليسار)
			movement_timer.start(randf_range(0.5, 2.0)) # وقت حركة أقصر
			
		2: # Wander Right
			current_state = State.WANDER
			SPEED = 100.0 # لجعل السرعة إيجابية (لليمين)
			movement_timer.start(randf_range(0.5, 2.0)) # وقت حركة أقصر

func _set_new_wander_target_after_jump():
	# لضمان عدم إعادة تشغيل المؤقت بشكل عشوائي مباشرة بعد القفز، 
	# نبدأ مؤقت حركة جديد قصير يتبع الاتجاه المعكوس
	movement_timer.start(0.5)

func _on_despawn_timer_timeout() -> void:
	queue_free()
