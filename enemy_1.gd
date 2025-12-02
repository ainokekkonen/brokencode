extends CharacterBody2D

@export var speed: float = 200
@export var jump_velocity: float = -300
@export var attack_range: float = 40
@export var attack_damage: int = 10
@export var gravity: float = 600
@export var attack_cooldown: float = 1.0
var hp: int = 50
var attack_timer: float = 0.0

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("Idle")
	sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	if sprite.animation == "Attack":
		sprite.play("Idle")

func _physics_process(delta):
	if not player or hp <= 0:
		return
	
	#Pelaajan suunta ja etäisyys
	var dir_vector = player.global_position - global_position
	var distance = dir_vector.length()
	var dir_x = sign(dir_vector.x)
	
	#Gravity ennen move_and_slide
	if not is_on_floor():
		velocity.y = max(velocity.y, 0.0)
	
	#Käännä sprite pelaajaa kohti
	sprite.flip_h = dir_x < 0
	
	#Hyppää, jos pelaaja on selvästi ylempänä
	if dir_vector.y < -20:
		velocity.y = jump_velocity
		sprite.play("Jump")
	
	#Liike tai hyökkäys
	if distance > attack_range:
		velocity.x = dir_x * speed
		if is_on_floor():
			sprite.play("Walk")
	else:
		velocity.x = 0
		if attack_timer <= 0.0:
			sprite.play("Attack")
			attack()
			attack_timer = attack_cooldown
		
		if attack_timer > 0.0:
			attack_timer -= delta
			
		if not is_on_floor():
			if velocity.y < 0:
				sprite.play("Jump")
			elif velocity.y > 0:
				sprite.play("Fall")
			else:
				if abs(velocity.x) < 0.1 and distance > attack_range:
					sprite.play("Idle")
	
	
func attack():
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

func take_damage(amount: int):
	hp -= amount
	sprite.play("Damage")
	if hp <= 0:
		die()

func die():
	sprite.play("Death")
	queue_free()
