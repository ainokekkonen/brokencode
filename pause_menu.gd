
extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing even when paused
	visible = false  # Start hidden

func _unhandled_input(event):
	if event.is_action_pressed("esc"):
		if get_tree().paused:
			resume()
		else:
			pause()

func pause():
	get_tree().paused = true
	visible = true
	$AnimationPlayer.play("blur")

func resume():
	get_tree().paused = false
	visible = false
	$AnimationPlayer.play_backwards("blur")

func _on_resume_pressed():
	resume()

func _on_quit_pressed():
	get_tree().quit()
