extends Control

func _process(delta: float) -> void:
	$Version.text = tr("version") + str(ProjectSettings.get_setting("application/config/version"))
	
	if Input.is_action_just_pressed("F1"):
		TranslationServer.set_locale("en")
	if Input.is_action_just_pressed("F2"):
		TranslationServer.set_locale("ar`")
	

func _on_singleplayer_button_pressed() -> void:
	ButtonAudio.play()
	get_tree().change_scene_to_file("res://Scenes/world_selection.tscn")

func _on_multiplayer_button_pressed() -> void:
	ButtonAudio.play()
	get_tree().change_scene_to_file("res://Scenes/lobby.tscn")

func _on_settings_button_pressed() -> void:
	ButtonAudio.play()
	SceneManager.store_and_change_scene("res://Scenes/settings.tscn")

func _on_quit_button_pressed() -> void:
	ButtonAudio.play()
	get_tree().quit()
