
extends Node2D

@onready var objective_label = $Cutscene/Label
@onready var dialogue_box = $Cutscene/Dialogue
@onready var dialogue_label = $Cutscene/Dialogue/Background/Label
@onready var glitch = $Cutscene/glitch
@onready var glitch_sprite = glitch.get_node("AnimatedSprite2D")
@onready var animation_player = $Cutscene/AnimationPlayer
@onready var camera = $Player/Camera2D

# NEW: Dialogue system references
@onready var dialogue_ui = $DialogueUI   # CanvasLayer for interactive dialogue
@onready var npc = $npc                  # NPC node in the world

func _ready():
	# Hide UI initially
	objective_label.visible = false
	dialogue_box.visible = false

	# Disable physics so Tween works
	glitch.set_physics_process(false)

	# Play glitch animation
	glitch_sprite.play("move")

	# Play AnimationPlayer animation
	animation_player.play("glitch_move")

	# Move glitch using Tween
	var tween = create_tween()
	tween.tween_property(glitch, "position", glitch.position + Vector2(300, 0), 1.0)
	await tween.finished

	glitch.set_physics_process(true)

	# Wait until glitch leaves camera view
	await wait_until_glitch_out_of_view()

	# Hide glitch and show dialogue
	glitch.visible = false
	show_player_reaction()

	# ✅ Keep dialogue for 3 seconds
	await get_tree().create_timer(3.0).timeout

	# Hide dialogue box
	dialogue_box.visible = false

	# Show main objective
	show_objective()

	# ✅ Connect NPC interaction for dialogue
	npc.connect("interacted", Callable(self, "_on_npc_interacted"))

func wait_until_glitch_out_of_view():
	while true:
		var viewport_size = camera.get_viewport_rect().size
		var half_size = viewport_size / 2
		var cam_center = camera.get_screen_center_position()
		var visible_rect = Rect2(cam_center - half_size, viewport_size)

		if not visible_rect.has_point(glitch.position):
			break
		await get_tree().process_frame

func show_player_reaction():
	dialogue_box.visible = true
	dialogue_label.text = "Woah, what was that?"

func show_objective():
	objective_label.text = "Main Objective: Find the glitch"
	objective_label.visible = true

# NEW: NPC interaction callback
func _on_npc_interacted():
	dialogue_ui.call("start_dialogue")  # Starts dialogue from first JSON entry
