
extends CharacterBody2D

# --- Movement & combat config ---
const SPEED := 400.0
const JUMP_VELOCITY := -600.0
const MAX_JUMPS := 2

# Animation names
const ATTACK_ANIM := "attack1"           # AnimationPlayer clip
const ATTACK_SPRITE_ANIM := "attack"     # AnimatedSprite2D clip

# Tuning
@export var attack_cooldown: float = 0.30
@export var attack_damage: int = 30
@export var max_health: int = 100
@export var move_speed: float = 160.0
@export var attack_locked: bool = false   # lock attacks (e.g., during dialogue)

# Nodes
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

# State
var is_attacking: bool = false
var can_attack: bool = true
var jump_count: int = 0
var health: int = 0

# Signals
signal health_changed(new_health)

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health)

	hitbox.add_to_group("PlayerAttack")
	hurtbox.add_to_group("Player")

	# Signals (Godot 4 style)
	hitbox.monitoring = false
	if not hitbox.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
		hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))

	hurtbox.monitoring = true
	if not hurtbox.is_connected("area_entered", Callable(self, "_on_hurtbox_area_entered")):
		hurtbox.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reset jump count when grounded
	if is_on_floor():
		jump_count = 0

	# Jump & double-jump
	if Input.is_action_just_pressed("jump") and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1

	# Horizontal input
	var direction := Input.get_axis("move_left", "move_right")

	# Face direction
	if direction > 0.0:
		animated_sprite_2d.flip_h = false
	elif direction < 0.0:
		animated_sprite_2d.flip_h = true

	# Movement
	if is_attacking:
		velocity.x = 0.0
	else:
		if direction != 0.0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

	# Animation state (only when not attacking)
	if not is_attacking:
		if is_on_floor():
			if direction == 0.0:
				animated_sprite_2d.play("idle")
			else:
				animated_sprite_2d.play("run")
		else:
			if velocity.y < 0.0:
				animated_sprite_2d.play("jump")
			else:
				animated_sprite_2d.play("fall")

func _process(_delta: float) -> void:
	if not attack_locked and Input.is_action_just_pressed("attack"):
		attempt_attack()

# --- Attack flow (FORCE the hit window ON/OFF) ---
func attempt_attack() -> void:
	if attack_locked or not can_attack or is_attacking:
		return

	can_attack = false
	is_attacking = true

	# Play animations
	animated_sprite_2d.play(ATTACK_SPRITE_ANIM)
	if anim and anim.has_animation(ATTACK_ANIM):
		anim.play(ATTACK_ANIM)

	# Ensure hitbox is on during the strike
	await enable_hitbox_for(0.18)  # tune this to match your swing

	is_attacking = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# Allow AnimationPlayer tracks or other systems to call this too
func enable_hitbox_for(seconds: float) -> void:
	hitbox_enable()
	await get_tree().create_timer(seconds).timeout
	hitbox_disable()

func hitbox_enable() -> void:
	var shape := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = false
	hitbox.monitoring = true
	print("[Player] Hitbox ENABLED")

func hitbox_disable() -> void:
	var shape := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	if shape: shape.disabled = true
	hitbox.monitoring = false
	print("[Player] Hitbox DISABLED")

# --- Damage application to enemies ---
func _on_hitbox_area_entered(area: Area2D) -> void:
	print("player hitbox osui", area.name)
	var enemy := area.get_owner()
	if enemy and enemy.is_in_group("enemies") and enemy.has_method("take_damage"):
		var dir: Vector2 = (enemy.global_position - global_position).normalized()
		enemy.take_damage(attack_damage, dir * 120.0)

# --- Taking damage from enemy hitboxes ---
var damage_recovery_time := 0.4
var is_taking_damage: bool = false

func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health = clamp(health - amount, 0, max_health)
	emit_signal("health_changed", health)

	if health == 0:
		_on_player_defeated()
		return

	is_taking_damage = true

	# AnimatedSprite2D "hurt" fallbacks
	var frames := animated_sprite_2d.sprite_frames
	if frames:
		if frames.has_animation("hurt"):
			animated_sprite_2d.play("hurt")
		elif frames.has_animation("Damage"):
			animated_sprite_2d.play("Damage")
		elif frames.has_animation("damage"):
			animated_sprite_2d.play("damage")

	# AnimationPlayer fallback
	if anim:
		if anim.has_animation("hurt"):
			anim.play("hurt")
		elif anim.has_animation("Damage"):
			anim.play("Damage")
		elif anim.has_animation("damage"):
			anim.play("damage")

	await get_tree().create_timer(damage_recovery_time).timeout
	is_taking_damage = false

	if is_on_floor():
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("fall")

func heal(amount: int) -> void:
	health = clamp(health + amount, 0, max_health)
	emit_signal("health_changed", health)

func _on_player_defeated() -> void:
	is_attacking = false
	velocity = Vector2.ZERO
	animated_sprite_2d.play("death")
	set_physics_process(false)
	set_process(false)

func micro_hitstop(duration := 0.05) -> void:
	Engine.time_scale = 0.25
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func get_attack_damage() -> int:
	return attack_damage

func apply_knockback(force: Vector2) -> void:
	velocity += force

# Debug helpers
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("hurt"):
		take_damage(20)
	if event.is_action_pressed("heal"):
		heal(20)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	print("player hurtbox osui:", area.name)
	var enemy := area.get_owner()
	var dmg := 10
	if enemy and enemy.has_method("get_attack_damage"):
		dmg = int(enemy.get_attack_damage())
	take_damage(dmg)

# External API (World/DialogueUI)
func lock_attacks(lock: bool) -> void:
	attack_locked = lock
	if lock and is_attacking:
		hitbox_disable()
		is_attacking = false
		if anim and anim.is_playing():
			anim.stop()
		if is_on_floor():
			animated_sprite_2d.play("idle")
		else:
			animated_sprite_2d.play("fall")
