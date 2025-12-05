
# World.gd (Godot 4)
extends Node2D

@onready var objective_label: Label = $Cutscene/Label
@onready var dialogue_box: Control = $Cutscene/Dialogue
@onready var dialogue_label: Label = $Cutscene/Dialogue/Background/Label
@onready var glitch: Node2D = $Cutscene/glitch
@onready var glitch_sprite: AnimatedSprite2D = glitch.get_node("AnimatedSprite2D")
@onready var animation_player: AnimationPlayer = $Cutscene/AnimationPlayer
@onready var camera: Camera2D = $Player/Camera2D

# Dialogue UI and NPC references
@onready var dialogue_ui: CanvasLayer = $DialogueUI    # Dialogue UI node in the scene
@onready var npc: Node = $npc                          # NPC node in the world

func _ready() -> void:
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
	var tween := create_tween()
	tween.tween_property(glitch, "position", glitch.position + Vector2(300, 0), 1.0)
	await tween.finished

	glitch.set_physics_process(true)

	# Wait until glitch leaves camera view
	await wait_until_glitch_out_of_view()

	# Hide glitch and show dialogue
	glitch.visible = false
	show_player_reaction()

	# Keep dialogue for 3 seconds
	await get_tree().create_timer(3.0).timeout

	# Hide dialogue box
	dialogue_box.visible = false

	# Show main objective
	show_objective()

	# ✅ Connect NPC interaction for dialogue (bind sender so handler receives the NPC)
	if npc and npc.has_signal("interacted"):
		if not npc.is_connected("interacted", _on_npc_interacted):
			npc.interacted.connect(_on_npc_interacted.bind(npc))
	else:
		push_warning("World.gd: NPC not found at $npc or 'interacted' signal missing.")

func wait_until_glitch_out_of_view() -> void:
	while true:
		# Convert Vector2i to Vector2 for float math
		var viewport_rect_i := camera.get_viewport_rect()
		var viewport_size: Vector2 = Vector2(viewport_rect_i.size)
		var half_size: Vector2 = viewport_size / 2.0
		var cam_center: Vector2 = camera.get_screen_center_position()
		var visible_rect: Rect2 = Rect2(cam_center - half_size, viewport_size)

		if not visible_rect.has_point(glitch.position):
			break
		await get_tree().process_frame

func show_player_reaction() -> void:
	dialogue_box.visible = true
	dialogue_label.text = "Woah, what was that?"

func show_objective() -> void:
	objective_label.text = "Main Objective: Find the glitch"
	objective_label.visible = true

# --- NPC interaction callback (receives the bound sender) ---
func _on_npc_interacted(npc_sender: Node) -> void:
	if dialogue_ui == null:
		push_warning("World.gd: DialogueUI not found at $DialogueUI.")
		return

	# Provide the clicked NPC to the Dialogue UI so its hurt/death calls affect the right one
	dialogue_ui.npc = npc_sender

	# Start dialogue (Dialogue UI reads its JSON internally)
	dialogue_ui.start_dialogue()
