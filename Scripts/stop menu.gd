extends CanvasLayer

func _on_back_button_pressed() -> void:
	ButtonAudio.play()
	visible = false
	get_tree().paused = false

func _on_settings_button_pressed() -> void:
	ButtonAudio.play()
	SceneManager.store_and_change_scene("res://Scenes/settings.tscn")

func _on_menu_button_pressed() -> void:
	ButtonAudio.play()
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

func _physics_process(delta: float) -> void:
	# إيقاف اللعبة مؤقتًا
	if Input.is_action_just_pressed("paused"):
		visible = !visible
		get_tree().paused = !get_tree().paused
