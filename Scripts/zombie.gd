extends CharacterBody2D

# --- إعدادات الزومبي ---
const SPEED = 100.0
const JUMP_VELOCITY = -125.0
const WALL_CHECK_DISTANCE = 20
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 1.5 # الوقت بين كل هجمة بالثواني
var health = 20
var is_dead = false

# --- متغيرات الحالة (State) ---
var player_in_range: bool = false
var player_in_attack_range: bool = false
var player: Node = null # لتخزين مرجع للاعب عندما يكون قريبًا
var can_attack = true # هل يمكن للزومبي الهجوم الآن؟

# --- روابط العقد ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_cooldown_timer: Timer = $AttackCooldown
@onready var wander_timer: Timer = $WanderTimer
@onready var wall_check_ray: RayCast2D = $WallCheckRay

enum State { IDLE_WANDER, CHASE }
var current_state = State.IDLE_WANDER
var wander_direction: int = 0

# ===================================================================
#  الدوال الأساسية لـ Godot
# ===================================================================

func _ready():
	# ابدأ أول تبديل للحركة العشوائية
	_set_new_wander_target()

func _set_new_wander_target():
	# اختيار عشوائي للاتجاه: -1 (يسار)، 0 (خمول)، 1 (يمين)
	wander_direction = randi_range(-1, 1)
	
	# تعيين وقت عشوائي للحركة التالية (بين 1.5 و 3.5 ثانية مثلاً)
	var new_wait_time = randf_range(1.5, 3.5)
	wander_timer.start(new_wait_time)

func _physics_process(delta: float):
	# جاذبية بسيطة
	if not is_on_floor():
		velocity.y += get_gravity().y * delta / 2.5
	
	# التحقق من وضع المبدع واللاعب
	var is_creative = SettingsManager.current_settings.is_creative_mode
	var should_chase = (not is_creative) and player_in_range and player != null

	# 1. 🔄 تبديل الحالة 🔄
	if should_chase:
		current_state = State.CHASE
		wander_timer.stop() # أوقف الحركة العشوائية عند المطاردة
	elif current_state == State.CHASE and not should_chase:
		current_state = State.IDLE_WANDER
		_set_new_wander_target() # ابدأ الحركة العشوائية مجدداً
	
	# 2. 🏃 تطبيق الحركة بناءً على الحالة 🏃
	match current_state:
		State.CHASE:
			_chase_player()
		
		State.IDLE_WANDER:
			_wander_randomly()
	
	_handle_jump()
	
	# 3. تحديث الرسوم المتحركة والاصطدام
	_update_sprite_direction()
	animated_sprite.play("idle")
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
	
	print("Mob died!")
	
	# 2. حذف الكائن
	# يمكن تأخير الحذف لإظهار رسوم متحركة للموت أولاً
	queue_free()

# ===================================================================
#  دوال الهجوم
# ===================================================================

func attempt_attack():
	# تحقق مما إذا كان اللاعب لا يزال في منطقة الهجوم وهل يمكننا الهجوم
	if player != null and can_attack:
		print("Zombie attacks player!")
		
		# استدعاء دالة الضرر في اللاعب
		player.take_damage(ATTACK_DAMAGE)
		animated_sprite.play("attack")
		
		# بدء مؤقت فترة الانتظار
		can_attack = false
		attack_cooldown_timer.start(ATTACK_COOLDOWN)

# دالة يتم استدعاؤها عند انتهاء مؤقت الهجوم
func _on_attack_cooldown_timer_timeout():
	can_attack = true
	# إذا كان اللاعب لا يزال في منطقة الهجوم، قم بالهجوم مرة أخرى
	if player_in_attack_range and not SettingsManager.current_settings.is_creative_mode: 
		attempt_attack()

# ===================================================================
#  دوال مناطق الكشف (الإشارات)
# ===================================================================

# --- منطقة الكشف الكبيرة (المطاردة) ---
func _on_detection_zone_body_entered(body):
	# تحقق مما إذا كان الجسم الذي دخل هو اللاعب
	if body.is_in_group("Player"):
		player = body
		player_in_range = true

func _on_detection_zone_body_exited(body):
	if body.is_in_group("Player"):
		if body == player:
			player = null
		player_in_range = false

# --- منطقة الهجوم الصغيرة ---
func _on_attack_zone_body_entered(body):
	if body.is_in_group("Player"):
		player_in_attack_range = true
		can_attack = true
		attempt_attack()

func _on_attack_zone_body_exited(body):
	if body.is_in_group("Player"):
		player_in_attack_range = false
		can_attack = false

# ===================================================================
#  دوال الحالات
# ===================================================================

func _chase_player():
	# التحرك نحو اللاعب
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * SPEED

func _wander_randomly():
	# تطبيق الحركة العشوائية
	velocity.x = wander_direction * SPEED * 0.5

func _update_sprite_direction():
	# تحديث اتجاه الصورة بناءً على السرعة
	if velocity.x > 0.1:
		wall_check_ray.target_position.x = 20
		animated_sprite.flip_h = false
	elif velocity.x < -0.1:
		wall_check_ray.target_position.x = -20
		animated_sprite.flip_h = true

# ===================================================================
#  دالة التعامل مع القفز
# ===================================================================

func _handle_jump():
	if is_on_floor():
		# تحديث اتجاه RayCast بناءً على اتجاه الحركة الحالي
		var check_dir = sign(velocity.x)
		if check_dir == 0:
			# إذا كان خاملاً، فليستمر في الاتجاه الأخير
			check_dir = sign(animated_sprite.scale.x)
			
		wall_check_ray.target_position.x = check_dir * WALL_CHECK_DISTANCE

		# إذا اكتشف RayCast شيئًا (جدار أو عائق)
		if wall_check_ray.is_colliding():
			var collider = wall_check_ray.get_collider()
			# تأكد من أن الاصطدام ليس باللاعب أو كائن آخر غير الجدار/الأرضية
			if collider != player and not collider.is_in_group("Enemy"):
				
				velocity.y = JUMP_VELOCITY 
				# إذا كان في حالة الحركة العشوائية، غير الاتجاه بعد القفز 
				if current_state == State.IDLE_WANDER:
					wander_direction = -wander_direction
					# أعد تشغيل المؤقت فوراً لإضافة حركة عشوائية جديدة
					_set_new_wander_target()

# ===================================================================
#  الإشارات
# ===================================================================

func _on_wander_timer_timeout():
	# هذه الدالة تتفعل عند انتهاء المؤقت
	if current_state == State.IDLE_WANDER:
		_set_new_wander_target()
