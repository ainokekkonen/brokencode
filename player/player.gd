
extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -600.0
const MAX_JUMPS = 2  # Allow double jump
const ATTACK_ANIM := "attack1"
const ATTACK_SPRITE_ANIM := "attack"

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox1

var is_attacking: bool = false
var can_attack: bool = true
var attack_cooldown: float = 0.30
var attack_damage: int = 20
var move_speed: float = 160.0


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
	if not is_attacking:
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
	if is_attacking:
		velocity.x = 0
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _process(_delta):
	if Input.is_action_just_pressed("attack"):
			attempt_attack()


func _ready():
	# Hitbox ei tarkkaile koko ajan
	hitbox.monitoring = false
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	emit_signal("health_changed", health) # Lähetetään alkuarvo

# --- Hyökkäyksen aloitus ---
func attempt_attack():
	if not can_attack or is_attacking:
		return

	can_attack = false
	is_attacking = true
	
	animated_sprite_2d.play(ATTACK_SPRITE_ANIM)
	
	if anim.has_animation(ATTACK_ANIM):
		anim.play(ATTACK_ANIM)
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
	
	else:
		push_error("Animation '%s' not found on %s" % [ATTACK_ANIM, anim.name])
		# fail-safe: restore state so controls don't get stuck
	is_attacking = false
	can_attack = true
	return
	


# --- Osumaikkuna (kutsutaan animaation Call Method Trackista) ---
func enable_hitbox_for(duration: float) -> void:
	hitbox.monitoring = true
	await get_tree().create_timer(duration).timeout
	hitbox.monitoring = false

# --- Animaation lopussa palautus ---
func end_attack_state() -> void:
	is_attacking = false

# --- Vahinko viholliselle ---
func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		var dir: Vector2 = (body.global_position - global_position).normalized()
		body.take_damage(attack_damage, dir * 120.0)
		# Valinnainen pieni hitstop:
		# await micro_hitstop(0.05)

# Valinnainen: pieni hitstop parantamaan tuntumaa
func micro_hitstop(duration := 0.05) -> void:
	Engine.time_scale = 0.25
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


signal health_changed(new_health)

@export var max_health: int = 100
var health: int = max_health


func take_damage(amount: int):
		health = clamp(health - amount, 0, max_health)
		emit_signal("health_changed", health)

func heal(amount: int):
		health = clamp(health + amount, 0, max_health)
		emit_signal("health_changed", health)


func _on_enemy_hit():
		take_damage(20)


func _input(event):
		if event.is_action_pressed("damage"):
			take_damage(20)
		if event.is_action_pressed("heal"):
			heal(20)
