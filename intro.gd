
extends Control

@export var lines: Array[String] = [
	"The world, as we know it, overcame long-lasting chaos by great effort. ",
	"Everything was shaped by balance.",
	"That is until recent events.",
	"Now by unknown forces, the world is losing its balance and once again,",
    "returning to chaos."
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
		return

	var text = lines[current_line]
	if current_index < text.length():
		if skipping:
			print("Skipping typing...")
			$Label.text = ""
			for line in lines:
				$Label.text += line + "\n"
			typing_done = true
			print("All text shown instantly.")
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
		print("Click detected! typing_done =", typing_done)
		if not typing_done:
			skipping = true
		else:
			if ResourceLoader.exists(next_scene_path):
				print("Changing scene to:", next_scene_path)
				get_tree().change_scene_to_file(next_scene_path)
			else:
				push_error("Scene path does not exist: " + next_scene_path)
