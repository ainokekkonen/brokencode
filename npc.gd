
# NPC.gd (Godot 4)
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var interact_area: Area2D = get_node_or_null("Area2D") as Area2D

var is_dead: bool = false
var is_hurt: bool = false

signal interacted
signal talk_to(npc: Node)

# Let the world know when the NPC has finished dying and is now static
signal became_static

func _ready() -> void:
	# Make the Area2D clickable via its CollisionShape2D
	if interact_area:
		interact_area.input_pickable = true
		if not interact_area.input_event.is_connected(Callable(self, "_on_area_input_event")):
			interact_area.input_event.connect(Callable(self, "_on_area_input_event"))
	_play_idle()

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			interacted.emit()
			talk_to.emit(self)
			# Stop the click from propagating to other listeners (optional)
			get_viewport().set_input_as_handled()

# ------------------ Anim helpers ------------------

func _has_animation(anim_name: String) -> bool:
	if anim == null or anim.sprite_frames == null:
		return false
	return anim.sprite_frames.has_animation(anim_name)

func _play_idle() -> void:
	if is_dead or anim == null:
		return
	var frames: SpriteFrames = anim.sprite_frames
	if frames and _has_animation("idle"):
		# Ensure idle loops (common for breathing/ambient)
		frames.set_animation_loop("idle", true)
		anim.play("idle")

func play_hurt_animation() -> void:
	if is_dead or anim == null:
		return
	is_hurt = true
	if _has_animation("hurt"):
		anim.play("hurt")
		await anim.animation_finished
	is_hurt = false
	_play_idle()

# ------------------ Death -> Static ------------------

func play_death_then_static() -> void:
	if is_dead or anim == null:
		return
	is_dead = true

	# Disable clicking when dead
	if interact_area:
		interact_area.input_pickable = false
		interact_area.monitoring = false
		interact_area.set_deferred("monitorable", false)

	var frames: SpriteFrames = anim.sprite_frames

	# Ensure "death" does NOT loop; otherwise animation_finished will never emit.
	if frames and frames.has_animation("death"):
		frames.set_animation_loop("death", false)
		anim.play("death")
		await anim.animation_finished
	else:
		push_error('NPC: "death" animation missing; skipping to static.')

	# After death finishes, play static (typically looped like TV static)
	if frames and frames.has_animation("static"):
		frames.set_animation_loop("static", true)  # set to false if you want it to stop
		anim.play("static")
	else:
		# Fallback: freeze on last frame (or stop)
		anim.stop()

	# ✅ Inform listeners the NPC is now static (World listens to this to arm the scene change)
	became_static.emit()
