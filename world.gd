extends Node2D


func _ready():
	# Load and instance the fade transition scene
	var fade_scene = preload("res://fadetransition.tscn").instantiate()
	get_tree().root.add_child(fade_scene)  # Add it on top of everything
	fade_scene.z_index = 9999  # Ensure it's above all other nodes

	# Get the AnimationPlayer inside the fade scene
	var anim_player = fade_scene.get_node("AnimationPlayer")  # Adjust if needed
	anim_player.play("fade_out")
