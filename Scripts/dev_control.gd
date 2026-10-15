extends CanvasLayer

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("devcontrol"):
		visible = !visible
	$Time/Time.text = "Current Time Is X" + str(Engine.time_scale)
	$Scene/Scene.text = "Current Scene Is " + str(get_tree().current_scene)

func set_time_scale(scale: float) -> void:
	scale = clampf(scale, 0.1, 10.0)
	Engine.time_scale = scale
	print("Game Time Scale set to: x%0.1f" % scale)

func _on_set_pressed() -> void:
	set_time_scale($Time/SetTime.value)

func _on_rest_time_pressed() -> void:
	Engine.time_scale = 1

func _on_go_to_scene_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/" + $Scene/SceneName.text + ".tscn")
