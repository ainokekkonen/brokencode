
# DialogueUI.gd (Godot 4)
extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@export var dialogue_json_path: String = "res://Dialogue/json/npcdialogue.json"
@export var npc_path: NodePath

# Node references (cast results to avoid Variant inference warnings)
@onready var nine_patch: Control = get_node_or_null("NinePatchRect") as Control
@onready var name_label: RichTextLabel = get_node_or_null("NinePatchRect/name_label") as RichTextLabel
@onready var chat_label: RichTextLabel = get_node_or_null("NinePatchRect/chat_label") as RichTextLabel
@onready var choice_container: VBoxContainer = get_node_or_null("NinePatchRect/VBoxContainer") as VBoxContainer
@onready var continue_button: Button = get_node_or_null("NinePatchRect/ContinueButton") as Button

# NPC reference (World sets this before starting dialogue)
var npc: Node = null   # not @onready so World can assign any time

# Dialogue state
var dialogue_data: Array[Dictionary] = []
var current_index: int = 0
var hurt_played: bool = false

# Typing configuration/state
@export var typing_cps: int = 30  # characters per second
var _is_typing: bool = false
var _skip_requested: bool = false

# ---------------- Helpers ----------------

func _load_dialogue(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		push_error("Dialogue JSON not found at: %s" % file_path)
		return []

	var file := FileAccess.open(file_path, FileAccess.READ)
	var content: String = file.get_as_text()

	var parsed: Variant = JSON.parse_string(content)
	if parsed == null:
		push_error("Invalid JSON: parse returned null.")
		return []

	if parsed is Array:
		return parsed as Array

	push_error("Invalid JSON format: expected Array of entries.")
	return []

func _set_choices_enabled(enabled: bool) -> void:
	if choice_container == null:
		return
	for child in choice_container.get_children():
		if child is Button:
			(child as Button).disabled = not enabled

func _clear_choices() -> void:
	if choice_container == null:
		return
	for child in choice_container.get_children():
		child.queue_free()

func _show_text_typing(text: String, cps: int = 30) -> void:
	if chat_label == null:
		return

	_is_typing = true
	_skip_requested = false

	chat_label.clear()
	chat_label.append_text(text)
	chat_label.visible_characters = 0

	var total: int = chat_label.get_total_character_count()
	if total <= 0:
		_is_typing = false
		return

	var delay: float = 1.0 / max(1, cps)

	while chat_label.visible_characters < total:
		if _skip_requested:
			chat_label.visible_characters = total
			break
		chat_label.visible_characters += 1
		await get_tree().create_timer(delay).timeout

	_is_typing = false

# --------------- Lifecycle ----------------

func _ready() -> void:
	# Validate essential nodes; log but don't crash
	if nine_patch == null:
		push_error("DialogueUI: NinePatchRect not found under DialogueUI.")
	else:
		# Stop clicks from falling through the UI to the world/NPC
		nine_patch.mouse_filter = Control.MOUSE_FILTER_STOP

	if name_label == null:
		push_error("DialogueUI: name_label not found under NinePatchRect.")
	if chat_label == null:
		push_error("DialogueUI: chat_label not found under NinePatchRect.")
	if choice_container == null:
		push_error("DialogueUI: VBoxContainer not found under NinePatchRect.")
	if continue_button == null:
		push_error("DialogueUI: ContinueButton not found under NinePatchRect.")
	else:
		continue_button.text = "Continue"
		continue_button.visible = false
		continue_button.disabled = true
		if not continue_button.pressed.is_connected(Callable(self, "_on_continue_pressed")):
			continue_button.pressed.connect(Callable(self, "_on_continue_pressed"))

	# Load and normalize dialogue data
	var raw: Array = _load_dialogue(dialogue_json_path)
	dialogue_data.clear()
	for item in raw:
		if item is Dictionary:
			dialogue_data.append(item as Dictionary)
		else:
			push_error("Invalid JSON entry: expected Dictionary, got %s" % typeof(item))

	visible = false

# Optional param lets World pass the NPC explicitly; World can call with or without args
func start_dialogue(npc_sender: Node = null) -> void:
	if npc_sender != null:
		npc = npc_sender
	elif npc == null and npc_path != NodePath(""):
		npc = get_node_or_null(npc_path) as Node

	if dialogue_data.is_empty():
		push_error("DialogueUI: Dialogue data not loaded or empty.")
		return

	current_index = 0
	hurt_played = false
	visible = true
	emit_signal("dialogue_started")
	_render_current()

func _render_current() -> void:
	if current_index >= dialogue_data.size():
		_end_dialogue()
		return

	var entry: Dictionary = dialogue_data[current_index]

	if name_label:
		name_label.text = str(entry.get("name", ""))

	# Prepare text and do typewriter
	var text: String = str(entry.get("text", ""))

	# Clear choice buttons and hide/disable continue during typing
	_clear_choices()
	_set_choices_enabled(false)
	if continue_button:
		continue_button.visible = false
		continue_button.disabled = true

	await _show_text_typing(text, typing_cps)

	# After typing, build choices
	var raw_choices: Variant = entry.get("choices", [])
	var has_choices: bool = false

	if raw_choices is Array:
		var arr := raw_choices as Array
		if arr.size() > 0:
			has_choices = true
			for c in arr:
				_add_choice_button(str(c))

	# If no choices, show the dedicated Continue button
	if not has_choices and continue_button:
		continue_button.visible = true
		continue_button.disabled = false
	else:
		if continue_button:
			continue_button.visible = false
			continue_button.disabled = true

	_set_choices_enabled(true)

func _add_choice_button(text: String) -> void:
	if choice_container == null:
		push_error("DialogueUI: choice_container (VBoxContainer) is missing.")
		return
	var btn: Button = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(Callable(self, "_on_choice_pressed"))
	choice_container.add_child(btn)

func _on_choice_pressed() -> void:
	# If still typing, first press should finish the line (no advance)
	if _is_typing:
		_skip_requested = true
		return

	# First interaction triggers hurt animation (only once)
	if not hurt_played and current_index >= 1 and npc and npc.has_method("play_hurt_animation"):
		npc.call("play_hurt_animation")
		hurt_played = true

	current_index += 1
	_render_current()

func _on_continue_pressed() -> void:
	# If still typing, first press should finish the line (no advance)
	if _is_typing:
		_skip_requested = true
		return

	if not hurt_played and current_index >= 1 and npc and npc.has_method("play_hurt_animation"):
		npc.call("play_hurt_animation")
		hurt_played = true

	current_index += 1
	_render_current()

func _end_dialogue() -> void:
	# Notify world first so it can unlock attacks immediately
	emit_signal("dialogue_finished")

	# Trigger NPC death -> static flow; World listens for npc.became_static
	if npc and npc.has_method("play_death_then_static"):
		npc.call("play_death_then_static")

	visible = false

# Allow clicking / Space / Enter to skip the typewriter reveal
func _unhandled_input(event: InputEvent) -> void:
	if _is_typing:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_skip_requested = true
			get_viewport().set_input_as_handled()  # avoid other systems reacting
		elif event is InputEventKey and event.pressed:
			var key := (event as InputEventKey).keycode
			if key == KEY_SPACE or key == KEY_ENTER:
				_skip_requested = true
				get_viewport().set_input_as_handled()
