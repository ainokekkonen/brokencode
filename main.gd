
extends Node2D



func _ready():
	$AnimatedSprite2D.play("BG")  # Replace "BG" with your animation name

var button_type = null

func _on_play_pressed():
	button_type = "Play"
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")

func _on_exit_pressed():
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "Play" :
		get_tree().change_scene_to_file("res://intro.tscn")
