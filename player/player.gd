extends CharacterBody2D

# --- Movement & combat config ---
const SPEED := 400.0
const JUMP_VELOCITY := -600.0
const MAX_JUMPS := 2

# Animation names
const ATTACK_ANIM := "attack1"
const ATTACK_SPRITE_ANIM := "attack"

# Exported so designers can tweak in the editor
@export var attack_cooldown: float = 0.30
@export var attack_damage: int = 30
@export var max_health: int = 100
@export var move_speed: float = 160.0

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

# NEW: lock to block attacks (e.g., while dialogue is open)
@export var attack_locked: bool = false

# Signals
signal health_changed(new_health)

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health)
	hitbox.add_to_group("PlayerAttack")
	hurtbox.add_to_group("Player")

	hitbox.monitoring = false
	if not hitbox.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	hurtbox.monitoring = true
	if not hurtbox.is_connected("area_entered", Callable(self, "_on_hurtbox_area_entered")):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

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
	# Block attack input while locked (e.g., during dialogue)
	if not attack_locked and Input.is_action_just_pressed("attack"):
		attempt_attack()

# --- Attack flow ---
func attempt_attack() -> void:
	# Respect the lock and other gates
	if attack_locked or not can_attack or is_attacking:
		return

	can_attack = false
	is_attacking = true

	animated_sprite_2d.play(ATTACK_SPRITE_ANIM)

	if anim.has_animation(ATTACK_ANIM):
		anim.play(ATTACK_ANIM)
	else:
		push_error("Animation '%s' not found on %s" % [ATTACK_ANIM, anim.name])
		end_attack_state()
		return
	
	await get_tree().create_timer(0.2).timeout
	hitbox.monitoring = false
	is_attacking = false
	
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# Called from AnimationPlayer
func hitbox_enable() -> void:
	hitbox.monitoring = true

func hitbox_disable() -> void:
	hitbox.monitoring = false

func end_attack_state() -> void:
	is_attacking = false

# --- NEW: external API to lock/unlock attacks (used by World/DialogueUI) ---
func lock_attacks(lock: bool) -> void:
	attack_locked = lock
	if lock and is_attacking:
		# Cancel any ongoing attack immediately
		hitbox_disable()
		is_attacking = false
		if anim and anim.is_playing():
			anim.stop()
		# Snap to a safe state
		if is_on_floor():
			animated_sprite_2d.play("idle")
		else:
			animated_sprite_2d.play("fall")

# --- Damage application to enemies ---
func _on_hitbox_area_entered(area: Area2D) -> void:
	print("player hitbox osui", area.name)
	var enemy := area.get_owner()
	if enemy and enemy.is_in_group("enemies") and enemy.has_method("take_damage"):
		var dir: Vector2 = (enemy.global_position - global_position).normalized()
		enemy.take_damage(attack_damage, dir * 120.0)


# --- Damage animaatio ---
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
	animated_sprite_2d.play("hurt")   # tee animaatio nimellä "damage"
	anim.play("hurt")                 # jos AnimationPlayerissä on vastaava animaatio
	# Pieni viive ennen paluuta normaaliin tilaan
	await get_tree().create_timer(damage_recovery_time).timeout
	is_taking_damage = false
	# Palauta sopiva animaatio
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

# --- Taking damage from enemy hitboxes ---
func _on_hurtbox_area_entered(area: Area2D) -> void:
	print("player hurtbox osui:", area.name)
	var enemy := area.get_owner()
	var dmg := 10
	if enemy and enemy.has_method("get_attack_damage"):
		dmg = int(enemy.get_attack_damage())
	take_damage(dmg)
