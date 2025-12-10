
extends CharacterBody2D

# --- Movement & combat config ---
const SPEED := 400.0
const JUMP_VELOCITY := -600.0
const MAX_JUMPS := 2

# Animation names (only AnimatedSprite2D for now)
const ATTACK_SPRITE_ANIM := "attack"

@export var attack_cooldown: float = 0.30
@export var attack_damage: int = 20
@export var max_health: int = 100

# Nodes
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox1
@onready var hurtbox: Area2D = $Hurtbox   # <-- Add this Area2D under Player

# State
var is_attacking := false
var can_attack := true
var jump_count := 0
var health := 0

signal health_changed(new_health)

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health)

	# Hitbox starts OFF
	hitbox.monitoring = false
	if not hitbox.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	# Hurtbox should be ON to receive enemy hits
	hurtbox.monitoring = true
	if not hurtbox.is_connected("area_entered", Callable(self, "_on_hurtbox_area_entered")):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reset jumps when grounded
	if is_on_floor():
		jump_count = 0

	# Jump / double jump
	if Input.is_action_just_pressed("jump") and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1

	# Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")

	# Face direction
	if direction > 0.0:
		animated_sprite_2d.flip_h = false
	elif direction < 0.0:
		animated_sprite_2d.flip_h = true

	# Movement while attacking is locked (optional)
	if is_attacking:
		velocity.x = 0.0
	else:
		if direction != 0.0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

	# Simple sprite animations
	if not is_attacking:
		if is_on_floor():
			animated_sprite_2d.play("idle" if direction == 0.0 else "run")
		else:
			animated_sprite_2d.play("jump" if velocity.y < 0.0 else "fall")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		attempt_attack()

# --- Attack (no AnimationPlayer needed) ---
func attempt_attack() -> void:
	if not can_attack or is_attacking:
		return

	can_attack = false
	is_attacking = true

	animated_sprite_2d.play(ATTACK_SPRITE_ANIM)

	# Turn hitbox ON briefly
	enable_hitbox_for(0.15)

	# After cooldown, allow next attack
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func enable_hitbox_for(duration: float) -> void:
	# Optional: flip hitbox position if your Hitbox1 is offset to one side
	# var local := $Hitbox1.position
	# $Hitbox1.position.x = abs(local.x) * (animated_sprite_2d.flip_h ? -1 : 1)

	hitbox.monitoring = true
	await get_tree().create_timer(duration).timeout
	hitbox.monitoring = false

# --- Deal damage to enemies when player hitbox overlaps their Hurtbox ---
func _on_hitbox_area_entered(area: Area2D) -> void:
	var enemy := area.get_owner()
	if enemy and enemy.is_in_group("enemies") and enemy.has_method("take_damage"):
		var dir: Vector2 = (enemy.global_position - global_position).normalized()
		enemy.take_damage(attack_damage, dir * 120.0)
		# Optional: micro-hitstop for feel
		# await micro_hitstop(0.05)

# --- Receive damage when enemy Hitbox overlaps player Hurtbox ---
func _on_hurtbox_area_entered(area: Area2D) -> void:
	var enemy := area.get_owner()
	var dmg := 10
	if enemy and enemy.has_method("get_attack_damage"):
		dmg = int(enemy.get_attack_damage())
	take_damage(dmg)

# --- Health handling ---
func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	emit_signal("health_changed", health)
	if health == 0:
		_on_player_defeated()

func heal(amount: int) -> void:
	health = clamp(health + amount, 0, max_health)
	emit_signal("health_changed", health)

func _on_player_defeated() -> void:
	is_attacking = false
	velocity = Vector2.ZERO
	animated_sprite_2d.play("idle")
	set_physics_process(false)
	set_process(false)

# Exposed helpers enemies can call
func get_attack_damage() -> int:
	return attack_damage

func apply_knockback(force: Vector2) -> void:
	velocity += force

# Optional impact feel
func micro_hitstop(duration := 0.05) -> void:
	Engine.time_scale = 0.25
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

# Debug keys (optional)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("damage"):
		take_damage(20)
	if event.is_action_pressed("heal"):
		heal(20)


func _on_hurt_box_area_entered(area: Area2D) -> void:
	pass # Replace with function body.


func _on_hit_box_area_entered(area: Area2D) -> void:
	pass # Replace with function body.
