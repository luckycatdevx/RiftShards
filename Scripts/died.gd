extends CanvasLayer

func _on_respawn_button_pressed() -> void:
	ButtonAudio.play()
	
	# إعادة تفعيل حركة اللاعب
	var player = get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player):
		player.set_physics_process(true)
	player.health = 20
	player.hanger = 20
	
	queue_free()

func _on_menu_button_pressed() -> void:
	ButtonAudio.play()
	
	# إعادة تفعيل حركة اللاعب
	var player = get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player):
		player.set_physics_process(true)
	
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")
	
	queue_free()
