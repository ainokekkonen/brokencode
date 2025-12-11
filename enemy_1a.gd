
extends CharacterBody2D   # Change to Node2D if your root isn't a physics body

# --- Config ---
@export var max_hp: int = 50
@export var move_speed: float = 60.0
@export var attack_damage: int = 10
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 0.8

# --- State ---
var hp: int = max_hp
var target: Node2D = null
var can_attack: bool = true

# --- Nodes ---
@onready var spr: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection: Area2D = $DetectionArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox

func _ready() -> void:
	add_to_group("enemies")
	_play_anim("Idle")

	# Optional: aggro via detection area (works if masks target Player root or Hurtbox)
	if detection:
		detection.body_entered.connect(_on_detection_body_entered)
		detection.body_exited.connect(_on_detection_body_exited)
		detection.area_entered.connect(_on_detection_area_entered)
		detection.area_exited.connect(_on_detection_area_exited)

	_set_attack_enabled(false)

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return

	if target:
		var to_target: Vector2 = target.global_position - global_position
		spr.flip_h = to_target.x < 0

		if to_target.length() > attack_range:
			# CharacterBody2D movement
			velocity = to_target.normalized() * move_speed
			move_and_slide()
			_play_anim("Walk")

			# If your root is Node2D, use this instead:
			# global_position += to_target.normalized() * move_speed * delta
		else:
			velocity = Vector2.ZERO
			if can_attack:
				_do_attack()
			else:
				_play_anim("Idle")
	else:
		velocity = Vector2.ZERO
		_play_anim("Idle")

# --- Damage from Player ---
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if hp <= 0:
		return
	hp = max(hp - amount, 0)
	print("%s took %d (HP=%d)" % [name, amount, hp])
	_play_anim("Damage")

	# Basic knockback if CharacterBody2D
	velocity += knockback

	if hp == 0:
		_die()

func _die() -> void:
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
	print("[Enemy] AttackHitbox ENABLED")
	await get_tree().create_timer(0.20).timeout
	_set_attack_enabled(false)
	print("[Enemy] AttackHitbox DISABLED")

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _set_attack_enabled(on: bool) -> void:
	if attack_hitbox:
		var shape := attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.disabled = not on
		attack_hitbox.monitoring = on

# --- Detection (aggro) ---
func _on_detection_body_entered(body: Node) -> void:
	if body is Node2D and _is_player(body):
		target = body as Node2D

func _on_detection_body_exited(body: Node) -> void:
	if body == target:
		target = null

func _on_detection_area_entered(area: Area2D) -> void:
	var owner := area.get_owner()
	if owner and owner is Node2D and _is_player(owner):
		target = owner as Node2D

func _on_detection_area_exited(area: Area2D) -> void:
	var owner := area.get_owner()
	if owner == target:
		target = null

# --- Helpers ---
func _is_player(n: Node) -> bool:
	return n.name == "Player" or (n.has_method("is_player") and n.is_player())

func _play_anim(name: String) -> void:
	if not spr:
		return
	var frames := spr.sprite_frames
	if frames and frames.has_animation(name):
		if spr.animation != name or not spr.is_playing():
			spr.play(name)
