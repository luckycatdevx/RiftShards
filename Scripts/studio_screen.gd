extends CanvasLayer

var menu = "res://Scenes/menu.tscn"

func _ready() -> void:
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(menu)

func _process(delta: float) -> void:
	if Input.is_anything_pressed():
		get_tree().change_scene_to_file(menu)
