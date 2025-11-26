
extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -600.0
const MAX_JUMPS = 2  # Allow double jump

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var jump_count: int = 0

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reset jump count when on floor
	if is_on_floor():
		jump_count = 0

	# Handle jump (including double jump)
	if Input.is_action_just_pressed("jump") and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1

	# Get input direction (-1, 0, 1)
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the sprite based on direction
	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true
	
	# Play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite_2d.play("idle")
		else:
			animated_sprite_2d.play("run")
	else:
		if velocity.y < 0:
			animated_sprite_2d.play("jump")  # Ascending
		else:
			animated_sprite_2d.play("fall")  # Descending
	
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
