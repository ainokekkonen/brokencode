
extends CharacterBody2D

# --- Nodes ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox1
@onready var hurtbox: Area2D = $Hurtbox
@onready var detection: Area2D = $DetectionZone

# --- Player reference (either via group "player" or set player_path) ---
@export var player_path: NodePath
var player: Node2D = null

# --- Movement (no jumping) ---
@export var gravity: float = 980.0
@export var move_speed: float = 140.0

# --- The ONLY range you set in the editor is DetectionZone's CollisionShape ---
# When the player is INSIDE DetectionZone -> boss follows and may attack.
# To avoid swinging from far away, we use a SMALL "close distance" gate (in pixels).
@export var close_distance: float = 32.0  # must be very near to start the attack

# --- Attack (two swings) ---
@export var attack_cooldown: float = 1.0
@export var attack_damage: int = 20
@export var first_swing_active: float = 0.15
@export var gap_between_swings: float = 0.30
@export var second_swing_active: float = 0.15

# --- State ---
var player_in_zone: bool = false
var is_attacking: bool = false
var can_attack: bool = true

func _ready() -> void:
	set_process_input(false)
	set_process_unhandled_input(false)

	# Areas
	hitbox.monitoring = false        # ON only during swing
	hurtbox.monitoring = true
	detection.monitoring = true

	# Signals (connect if not already wired in the editor)
	if not detection.is_connected("area_entered", Callable(self, "_on_detection_enter")):
		detection.area_entered.connect(_on_detection_enter)
	if not detection.is_connected("area_exited", Callable(self, "_on_detection_exit")):
		detection.area_exited.connect(_on_detection_exit)

	if not hitbox.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	if not hurtbox.is_connected("area_entered", Callable(self, "_on_hurtbox_area_entered")):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	_resolve_player()

	# Start idle/walk (make sure your sprite is NOT set to auto-play "attack")
	if anim_has("idle"):
		anim.play("idle")
	else:
		anim.play("walk")

func _physics_process(delta: float) -> void:
	# Keep grounded; never jump
	if not is_on_floor():
		velocity.y += gravity * delta

	if player == null:
		_resolve_player()

	var vx: float = 0.0

	if player_in_zone and player != null:
		# Face player
		anim.flip_h = (player.global_position.x < global_position.x)

		var dx: float = player.global_position.x - global_position.x
		var dist_x: float = abs(dx)

		if not is_attacking:
			if dist_x > close_distance:
				# Follow horizontally until we're close enough
				vx = sign(dx) * move_speed
			else:
				# Close enough: stop and attack (only if off cooldown)
				vx = 0.0
				if can_attack:
					attempt_attack()
		else:
			# Lock movement during the whole attack sequence
			vx = 0.0
	else:
		# Player not in Detection Zone -> stand idle
		vx = 0.0

	velocity.x = vx
	move_and_slide()

	# Drive non-attack animations
	if not is_attacking:
		if abs(velocity.x) < 1.0:
			if anim_has("idle"): anim.play("idle")
			# else keep last animation to avoid spam
		else:
			anim.play("walk")

# --- Detection Zone handlers ---
func _on_detection_enter(area: Area2D) -> void:
	var owner := area.get_parent()
	# Expect the player's Hurtbox Area to be a child of the player
	if owner and owner.is_in_group("player"):
		player_in_zone = true

func _on_detection_exit(area: Area2D) -> void:
	var owner := area.get_parent()
	if owner and owner.is_in_group("player"):
		player_in_zone = false

# --- Two-swing attack sequence ---
func attempt_attack() -> void:
	if player == null or not can_attack or is_attacking or not player_in_zone:
		return

	# Check "close enough" RIGHT NOW (horizontal proximity gate)
	var dist_x: float = abs(player.global_position.x - global_position.x)
	if dist_x > close_distance:
		return

	can_attack = false
	is_attacking = true

	anim.play("attack")  # animation with both swings

	# Swing 1
	await enable_hitbox_for(first_swing_active)

	# Gap
	await get_tree().create_timer(gap_between_swings).timeout

	# Swing 2
	await enable_hitbox_for(second_swing_active)

	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
	can_attack = true

func enable_hitbox_for(duration: float) -> void:
	# Only enable hitbox if the player is still in zone and still close
	if player == null or not player_in_zone:
		await get_tree().create_timer(duration).timeout
		return

	var dist_x: float = abs(player.global_position.x - global_position.x)
	if dist_x > close_distance:
		await get_tree().create_timer(duration).timeout
		return

	hitbox.monitoring = true
	await get_tree().create_timer(duration).timeout
	hitbox.monitoring = false

# --- Combat overlaps ---
func _on_hitbox_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target and target.is_in_group("player") and target.has_method("take_damage"):
		var dir_vec: Vector2 = (target.global_position - global_position).normalized()
		target.take_damage(attack_damage, dir_vec * 180.0)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var attacker := area.get_parent()
	var dmg: int = 10
	if attacker and attacker.has_method("get_attack_damage"):
		dmg = int(attacker.get_attack_damage())
	_take_damage(dmg)

func _take_damage(amount: int) -> void:
	if anim_has("PowerDown"):               # matches your animation name/case
		anim.play("PowerDown")
	else:
		anim.play("attack")                  # simple flinch fallback

# --- Helpers ---
func anim_has(name: String) -> bool:
	return anim.sprite_frames != null and anim.sprite_frames.has_animation(name)

func _resolve_player() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n:
			player = n as Node2D
			return
	var candidates := get_tree().get_nodes_in_group("player")
	if candidates.size() > 0:
		player = candidates[0] as Node2D
