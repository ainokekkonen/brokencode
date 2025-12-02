extends CharacterBody2D

@export var speed: float = 200
@export var jump_velocity: float = -300
@export var attack_range: float = 40
@export var attack_damage: int = 10
@export var gravity: float = 600
var hp: int = 50

@onready var player = get_tree().get_root().find_node("Player", true, false)
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.animation = "Idle"
	sprite.play()

func _physics_process(delta):
	if not player or hp <= 0:
		return
	
	#Gravity
	velocity.y += gravity * delta
	
	#Pelaajan suunta ja etäisyys
	var dir_vector = player.global_position - global_position
	var distance = dir_vector.length()
	var dir_x = sign(dir_vector.x)
	
	#Käännä sprite pelaajaa kohti
	sprite.flip_h = dir_x < 0
	
	#Hyppää, jos pelaaja on selvästi ylempänä
	if dir_vector.y < -20:
		velocity.y = jump_velocity
	
	#Liike tai hyökkäys
	if distance > attack_range:
		velocity.x = dir_x * speed
		if sprite.animation != "Walk":
			sprite.animation = "Walk"
			sprite.play()
	else:
		velocity.x = 0
		if sprite.animation != "Attack":
			sprite.animation = "Attack"
			sprite.play()
		attack()
		
	#Päivitä animaatio putoamiseen tai hyppyyn
	if velocity.y < 0 and sprite.animation != "Jump":
		sprite.animation = "Jump"
		sprite.play()
	elif velocity.y > 0 and sprite.animation != "Fall":
		sprite.animation = "Fall"
		sprite.play()
	elif velocity.y == 0 and distance > attack_range and sprite.animation != "Walk":
		sprite.animation = "Walk"
		sprite.play()
	elif velocity.y == 0 and distance <= attack_range and sprite.animation != "Attack":
		sprite.animation = "Attack"
		sprite.play()
	
	
func attack():
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: int):
	hp -= amount
	sprite.animation = "Damage"
	sprite.play()
	if hp <= 0:
		die()

func die():
	sprite.animation = "Death"
	sprite.play()
	queue_free()
