
extends Control

@export var lines: Array[String] = [
	"To preserve reality, humanity forged minds of metal and code",
	"—machines designed to maintain balance.",
	"And balance did prevail,",
	"For a time.",
	"Now, unseen algorithms stir beneath the surface.",
	"Systems once built to preserve order have begun rewriting the rules.",
	"And with it,",
    "Reality itself."
]

@export var typing_speed: float = 0.05
@export var line_delay: float = 1.0
@export var next_scene_path: String = "res://world.tscn"

var current_line: int = 0
var current_index: int = 0
var typing_done: bool = false
var skipping: bool = false

func _ready():
	$Label.text = ""
	start_typing()

func start_typing():
	current_line = 0
	current_index = 0
	typing_done = false
	skipping = false
	type_next_character()

func type_next_character():
	if current_line >= lines.size():
		typing_done = true
		print("Typing finished!")
		return  # Do NOT auto-change scene; wait for click
	var text = lines[current_line]
	if current_index < text.length():
		if skipping:
			show_all_text()
			return
		$Label.text += text[current_index]
		current_index += 1
		await get_tree().create_timer(typing_speed).timeout
		type_next_character()
	else:
		current_line += 1
		current_index = 0
		if current_line < lines.size():
			await get_tree().create_timer(line_delay).timeout
			$Label.text += "\n"
			type_next_character()

func _process(delta):
	if Input.is_action_just_pressed("skip_cutscene"):
		if not typing_done:
			# First click during typing → skip typing
			skipping = true
			show_all_text()
		else:
			# Second click after typing done → change scene
			change_to_next_scene()

func show_all_text():
	$Label.text = ""
	for line in lines:
		$Label.text += line + "\n"
	typing_done = true
	print("All text shown instantly.")

func change_to_next_scene():
	if ResourceLoader.exists(next_scene_path):
		print("Changing scene to:", next_scene_path)
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_error("Scene path does not exist: " + next_scene_path)
