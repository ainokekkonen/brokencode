extends AnimatedSprite2D






func _ready():
	# Play the background animation
	play("menu_bgreal")
	
	# Scale the background to fit the window
	var window_size = DisplayServer.window_get_size()
	var texture_size = sprite_frames.get_frame_texture("menu_bgreal", 0).get_size()
	var scale_x = window_size.x / texture_size.x
	var scale_y = window_size.y / texture_size.y
	scale = Vector2(scale_x, scale_y)
