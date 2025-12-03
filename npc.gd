
# NPC.gd
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $Area2D if has_node("Area2D") else null

var is_dead: bool = false
var is_hurt: bool = false

signal interacted

func _ready() -> void:
	# Allow clicking the NPC (optional)
	if interact_area:
		interact_area.input_event.connect(_on_area_input_event)

	_play_idle()

func _on_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interacted.emit()

func _play_idle() -> void:
	if is_dead: return
	# Only play idle if we are not hurt or already in a terminal animation
	if not is_hurt and _has_animation("idle"):
		anim.play("idle")

func play_hurt_animation() -> void:
	if is_dead: return
	is_hurt = true
	if _has_animation("hurt"):
		anim.play("hurt")
	# (Optional) after hurt finishes, return to idle:
	# await anim.animation_finished
	# is_hurt = false
	# _play_idle()

func play_death_then_static() -> void:
	if is_dead: return
	is_dead = true
	if _has_animation("death"):
		anim.play("death")
		await anim.animation_finished
	if _has_animation("static"):
		anim.play("static")
	if interact_area:
		interact_area.monitoring = false
		interact_area.set_deferred("monitorable", false)

func _has_animation(name: String) -> bool:
	var frames: SpriteFrames = anim.sprite_frames
	return frames != null and frames.has_animation(name)
