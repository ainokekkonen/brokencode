
extends CharacterBody2D

# --- Config ---
@export var max_hp: int = 100
@export var move_speed: float = 60.0
@export var attack_damage: int = 10
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 0.8

# Platformer-specific
@export var gravity: float = 1200.0
@export var use_floor_snap: bool = true
@export var snap_length_config: float = 6.0

# Hit response
@export var hit_stun_time: float = 0.20
@export var hurt_invuln_time: float = 0.15

# --- State ---
var hp: int = 0
var target: Node2D = null
var can_attack: bool = true
var can_take_damage: bool = true
var is_in_hitstun: bool = false

# --- Nodes ---
@onready var spr: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection: Area2D = $DetectionArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_play_anim("Idle")

	if use_floor_snap:
		floor_snap_length = snap_length_config
	else:
		floor_snap_length = 0.0

	if detection:
		detection.body_entered.connect(_on_detection_body_entered)
		detection.body_exited.connect(_on_detection_body_exited)
		detection.area_entered.connect(_on_detection_area_entered)
		detection.area_exited.connect(_on_detection_area_exited)

	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	_set_attack_enabled(false)

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = max(velocity.y, 0.0)

	# During hit-stun, do not override "Damage" animation or move horizontally
	if is_in_hitstun:
		velocity.x = 0.0
		move_and_slide()
		return

	# Targeting & movement (horizontal only)
	if target:
		var to_target: Vector2 = target.global_position - global_position
		spr.flip_h = to_target.x < 0

		if to_target.length() > attack_range:
			var dir_x: float = signf(to_target.x)
			velocity.x = dir_x * move_speed
			_play_anim("Walk")
		else:
			velocity.x = 0.0
			if can_attack:
				_do_attack()
			else:
				_play_anim("Idle")
	else:
		velocity.x = 0.0
		_play_anim("Idle")

	move_and_slide()

# --- Damage from Player (Hurtbox triggers this via signals) ---
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if hp <= 0:
		return
	if not can_take_damage:
		return

	can_take_damage = false
	is_in_hitstun = true

	hp = max(hp - amount, 0)
	print("%s took %d (HP=%d)" % [name, amount, hp])

	# Play "Damage" (capital D as requested)
	_play_anim("Damage")

	# Apply knockback
	velocity += knockback

	# Keep the "Damage" anim visible briefly
	await get_tree().create_timer(hit_stun_time).timeout
	is_in_hitstun = false

	# Brief i-frames to avoid multi-hit spam
	await get_tree().create_timer(hurt_invuln_time).timeout
	can_take_damage = true

	if hp == 0:
		_die()

func _die() -> void:
	# Play "Death" (capital D)
	_play_anim("Death")
	await get_tree().create_timer(0.6).timeout
	queue_free()

# --- Enemy -> Player ---
func get_attack_damage() -> int:
	return attack_damage

func _do_attack() -> void:
	can_attack = false
	_play_anim("Attack")

	_set_attack_enabled(true)
	await get_tree().create_timer(0.20).timeout
	_set_attack_enabled(false)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _set_attack_enabled(on: bool) -> void:
	if attack_hitbox:
		var shape: CollisionShape2D = attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.disabled = not on
		attack_hitbox.monitoring = on
		attack_hitbox.monitorable = true

# --- Detection (aggro) ---
func _on_detection_body_entered(body: Node) -> void:
	if body is Node2D and body.name == "Player":
		target = body as Node2D

func _on_detection_body_exited(body: Node) -> void:
	if body == target:
		target = null

func _on_detection_area_entered(area: Area2D) -> void:
	var owner_node: Node = area.get_owner()
	if owner_node and owner_node is Node2D and owner_node.name == "Player":
		target = owner_node as Node2D

func _on_detection_area_exited(area: Area2D) -> void:
	var owner_node: Node = area.get_owner()
	if owner_node == target:
		target = null

# --- Hurtbox handlers (player -> enemy hits) ---
func _on_hurtbox_area_entered(area: Area2D) -> void:
	var owner_node: Node = area.get_owner()
	if owner_node and owner_node.name == "Player":
		var dmg: int = attack_damage
		if area.has_method("get_attack_damage"):
			dmg = int(area.get_attack_damage())
		elif owner_node.has_method("get_attack_damage"):
			dmg = int(owner_node.get_attack_damage())

		var kb: Vector2 = Vector2.ZERO
		if area.has_method("get_attack_knockback"):
			var k: Variant = area.get_attack_knockback()
			if typeof(k) == TYPE_VECTOR2:
				kb = k as Vector2
		else:
			var dir: float = signf(global_position.x - owner_node.global_position.x)
			kb = Vector2(dir * 140.0, -80.0)

		take_damage(dmg, kb)

func _on_hurtbox_body_entered(body: Node) -> void:
	if body.name == "Player":
		var dmg: int = attack_damage
		if body.has_method("get_attack_damage"):
			dmg = int(body.get_attack_damage())

		var dir: float = signf(global_position.x - (body as Node2D).global_position.x)
		var kb: Vector2 = Vector2(dir * 140.0, -80.0)

		take_damage(dmg, kb)

# --- Animation helper ---
func _play_anim(name: String) -> void:
	if not spr:
		return
	var frames: SpriteFrames = spr.sprite_frames
	if frames and frames.has_animation(name):
		if spr.animation != name or not spr.is_playing():
			spr.play(name)
