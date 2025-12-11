
# World.gd (Godot 4)
extends Node2D

@onready var objective_label: Label = $Cutscene/Label
@onready var dialogue_box: Control = $Cutscene/Dialogue
@onready var dialogue_label: Label = $Cutscene/Dialogue/Background/Label
@onready var glitch: Node2D = $Cutscene/glitch
@onready var glitch_sprite: AnimatedSprite2D = glitch.get_node("AnimatedSprite2D")
@onready var animation_player: AnimationPlayer = $Cutscene/AnimationPlayer
@onready var camera: Camera2D = $Player/Camera2D

# Dialogue UI, Player, NPC references
@onready var dialogue_ui: CanvasLayer = $DialogueUI
@onready var npc: Node = $npc
@onready var player: Node = $Player   # used to lock/unlock attacks during dialogue

# OPTIONAL fade layer — now fetched safely
@onready var fade_layer: CanvasLayer = get_node_or_null("FadeLayer")
@onready var fade_rect: ColorRect = get_node_or_null("FadeLayer/FadeRect")
@onready var fade_anim: AnimationPlayer = get_node_or_null("FadeLayer/AnimationPlayer")

# Path to the next scene (set to your boss fight)
const NEXT_SCENE_PATH := "res://bossfight.tscn"

# Actions that count as "movement" for the change-on-next-move gate
const MOVEMENT_ACTIONS := [
	"ui_left", "ui_right", "ui_up", "ui_down",
	"move_left", "move_right", "move_up", "move_down"
]

var await_move_for_scene_change: bool = false

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

	# Connect NPC interaction for dialogue (bind sender so handler receives the NPC)
	if npc and npc.has_signal("interacted"):
		if not npc.is_connected("interacted", Callable(self, "_on_npc_interacted")):
			npc.interacted.connect(_on_npc_interacted.bind(npc))
	else:
		push_warning("World.gd: NPC not found at $npc or 'interacted' signal missing.")

	# Listen for NPC “became_static” so we can change scene on next movement
	if npc and npc.has_signal("became_static"):
		if not npc.is_connected("became_static", Callable(self, "_on_npc_became_static")):
			npc.became_static.connect(_on_npc_became_static)

func wait_until_glitch_out_of_view() -> void:
	while true:
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

	dialogue_ui.npc = npc_sender

	# Lock player attacks while dialogue is active
	if player and player.has_method("lock_attacks"):
		player.lock_attacks(true)
	elif player and player.has_variable("attack_locked"):
		player.attack_locked = true

	dialogue_ui.start_dialogue()

	if dialogue_ui.has_signal("dialogue_finished"):
		if not dialogue_ui.is_connected("dialogue_finished", Callable(self, "_on_dialogue_finished")):
			dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	else:
		push_warning("DialogueUI has no 'dialogue_finished' signal—add it and emit at the end.")

# --- Dialogue finished -> unlock attacks (and optionally arm scene change) ---
func _on_dialogue_finished() -> void:
	if player and player.has_method("lock_attacks"):
		player.lock_attacks(false)
	elif player and player.has_variable("attack_locked"):
		player.attack_locked = false
	# await_move_for_scene_change = true  # uncomment if desired

# --- NPC became static -> wait for next movement, then transition ---
func _on_npc_became_static() -> void:
	await_move_for_scene_change = true

# --------- Input gate: trigger scene change on next movement ---------
func _input(event: InputEvent) -> void:
	if not await_move_for_scene_change:
		return

	if _is_movement_event(event):
		get_viewport().set_input_as_handled()
		await_move_for_scene_change = false
		await fade_out_and_change_scene()

func _is_movement_event(event: InputEvent) -> bool:
	if event is InputEventAction and (event as InputEventAction).pressed:
		var a := (event as InputEventAction).action
		if a in MOVEMENT_ACTIONS:
			return true

	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		return key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

	if event is InputEventJoypadMotion:
		return abs((event as InputEventJoypadMotion).axis_value) > 0.2

	return false

# --- Scene transition helpers ---
func fade_out_and_change_scene() -> void:
	# If there's no fade layer, change immediately.
	if fade_anim == null or fade_rect == null or fade_layer == null:
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)
		return

	fade_layer.visible = true

	if fade_anim.has_animation("fade_out"):
		fade_anim.play("fade_out")
		await fade_anim.animation_finished
	else:
		var t := create_tween()
		fade_rect.modulate.a = 0.0
		t.tween_property(fade_rect, "modulate:a", 1.0, 0.4)
		await t.finished

	get_tree().change_scene_to_file("res://bossfight.tscn")
