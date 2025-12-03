
extends CanvasLayer

@export var dialogue_json_path: String = "res://npcdialogue.json"
@export var npc_path: NodePath

@onready var name_label: RichTextLabel = $NinePatchRect/name_label
@onready var chat_label: RichTextLabel = $NinePatchRect/chat_label
@onready var choice_container: VBoxContainer = $NinePatchRect/VBoxContainer
@onready var npc: Node = get_node(npc_path)

var dialogue_data: Array = []
var current_index: int = 0
var hurt_played: bool = false

func _ready() -> void:
	dialogue_data = _load_dialogue(dialogue_json_path)
	visible = false

func start_dialogue() -> void:
	if dialogue_data.is_empty():
		push_error("Dialogue data not loaded or empty.")
		return
	current_index = 0
	hurt_played = false
	visible = true
	_render_current()

func _render_current() -> void:
	if current_index >= dialogue_data.size():
		_end_dialogue()
		return

	var entry: Dictionary = dialogue_data[current_index]
	name_label.text = str(entry.get("name", ""))
	chat_label.text = str(entry.get("text", ""))

	_clear_choices()
	var choices: Array = entry.get("choices", [])
	if choices.is_empty():
		_add_choice_button("Continue")
	else:
		for choice_text in choices:
			_add_choice_button(str(choice_text))

func _add_choice_button(text: String) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND
	btn.pressed.connect(_on_choice_pressed)
	choice_container.add_child(btn)

func _clear_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

func _on_choice_pressed() -> void:
	# First interaction triggers hurt animation
	if not hurt_played and current_index >= 1 and npc.has_method("play_hurt_animation"):
		npc.call("play_hurt_animation")
		hurt_played = true

	current_index += 1
	_render_current()

func _end_dialogue() -> void:
	if npc.has_method("play_death_then_static"):
		npc.call("play_death_then_static")
	visible = false

func _load_dialogue(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		push_error("Dialogue JSON not found at: %s" % file_path)
		return []

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	var content: String = file.get_as_text()
	var result: Variant = JSON.parse_string(content)
	if result == null or typeof(result) != TYPE_ARRAY:
		push_error("Invalid JSON format: expected Array")
		return []

	return result
