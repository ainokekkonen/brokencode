extends Node2D



func _ready():
	var fade_scene = preload("res://fadetransition.tscn").instantiate()
	get_tree().root.add_child(fade_scene)  # CanvasLayer ignores camera
	fade_scene.z_index = 9999

	var anim_player = fade_scene.get_node("AnimationPlayer")
	anim_player.play("fade_out")
