extends CharacterBody2D

class_name Enemy1
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D 

const ENEMY_HURT_SPRITE := "damage"  # AnimatedSprite2D / SpriteFrames
const ENEMY_HURT_AP     := "hurt"    # AnimationPlayer

const speed = 80
var is_enemy_chase: bool = false

var health = 80
var health_max = 80
var health_min = 0

var dead: bool = false
var taking_damage: bool = false
var damage_to_deal = 20
var is_dealing_damage: bool = false
var is_hurt: bool = false

var dir: Vector2
const gravity = 900
var knockback_force = -20
var is_roaming: bool = true

var player: CharacterBody2D
var player_in_area = false

var attack_cooldown = 1.5
var can_attack = true

const jump_velocity = -400
var is_jumping: bool = false
var just_landed: bool = false
var was_on_floor: bool = false


func _process(delta):
	if !is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	
	move(delta)
	
	move_and_slide()

func move(delta):
	if is_dealing_damage:
		velocity.x = 0
		velocity.y = 0
		return
	if !dead:
		if !is_enemy_chase:
			velocity += dir * speed * delta
			if velocity.x != 0:
				dir.x = sign(player.position.x - position.x)
		elif is_enemy_chase and !taking_damage:
			var dir_to_player = (player.position - position).normalized() * speed
			velocity.x = dir_to_player.x
			dir.x = sign(player.position.x - position.x)
			if player.position.y < position.y - 150 and is_on_floor():
				velocity.y = jump_velocity
				is_jumping = true
				just_landed = false
		elif taking_damage:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
		is_roaming = true
	elif dead:
		velocity.x = 0

func handle_animation():
	if is_dealing_damage:
		print("soitetaan attack animaatio")
		anim_sprite.play("Attack")
		return
	if !dead and !taking_damage and !is_dealing_damage:
		if is_jumping:
			anim_sprite.play("JumpStart")
			await get_tree().create_timer(0.1).timeout
			is_jumping = false
			anim_sprite.flip_h = (dir.x < 0)
			return
		if just_landed:
			anim_sprite.play("Land")
			anim_sprite.flip_h = (dir.x < 0)
			return
		if !is_on_floor():
			if velocity.y < 0:
				anim_sprite.play("JumpLoop")
				anim_sprite.flip_h = (dir.x < 0)
				return
			elif velocity.y > 0:
				anim_sprite.play("Fall")
				anim_sprite.flip_h = (dir.x < 0)
				return
		else:
			anim_sprite.play("Walk")
			anim_sprite.flip_h = (dir.x < 0)
	elif !dead and taking_damage and !is_dealing_damage:
		anim_sprite.play("Damage")
		await get_tree().create_timer(0.8).timeout
		taking_damage = false
	elif dead and is_roaming:
		is_roaming = false
		anim_sprite.play("Death")
		await get_tree().create_timer(1.0).timeout
		handle_death()

func handle_death():
	self.queue_free()

func _on_anim_finished():
	var anim = $AnimatedSprite2D.animation
	
	if anim == "JumpStart":
		is_jumping = false
		if !is_on_floor() and velocity.y < 0:
			$AnimatedSprite2D.play("JumpLoop")
		elif !is_on_floor():
			$AnimatedSprite2D.play("Fall")
	
	elif anim == "Land":
		just_landed = false
		$AnimatedSprite2D.play("Walk")
	
	elif anim == "Attack":
		is_dealing_damage = false
		if !dead:
			$AnimatedSprite2D.play("Walk")
	
	elif anim == "Death":
		handle_death()

func _on_direction_timer_timeout() -> void:
	$DirectionTimer.wait_time = choose([1.5,2.0,2.5])
	if !is_enemy_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0

func choose(array):
	array.shuffle()
	return array.front()

func take_damage(damage: int) -> void:
	health -= damage
	taking_damage = true
	$AnimatedSprite2D.play("Damage")
	if health <= health_min:
		health = health_min
		dead = true

func _ready():
	$AnimatedSprite2D.animation_finished.connect(_on_anim_finished)


func start_hurt() -> void:
	is_hurt = true

func end_hurt_state() -> void:
	is_hurt = false


func _on_detection_area_body_entered(body):
	print("DetectionArea entered by:", body.name)
	if body.is_in_group("Player"):
		player = body
		is_enemy_chase = true
		player_in_area = true

func _on_detection_area_body_exited(body):
	if body.is_in_group("Player"):
		is_enemy_chase = false
		player_in_area = false

func attack():
	if player_in_area and !dead and !taking_damage and can_attack:
		can_attack = false
		is_dealing_damage = true
		anim_sprite.play("Attack")
		
		
		var attack_duration = 0.4
		var target_pos = player.position
		var tween = create_tween()
		tween.tween_property(self, "position", target_pos, attack_duration)
		
		$AttackHitbox.monitoring = true
		
		await get_tree().create_timer(attack_duration).timeout
		$AttackHitbox.monitoring = false
		
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true


func _on_Hitbox_area_entered(area):
	if area.name == "PlayerAttack":
		take_damage(20)


func _physics_process(delta):
	if !was_on_floor and is_on_floor():
		just_landed = true
	was_on_floor = is_on_floor()
	handle_animation()
	if player_in_area and can_attack and !dead and !taking_damage:
		attack()


func  _on_attack_hitbox_area_entered(area: Area2D) -> void:
	print("AttackHitbox osui:", area.name)
	if area.is_in_group("Player"):
		is_dealing_damage = true
		if area.has_method("take_damage"):
			area.take_damage(damage_to_deal)
		can_attack = false
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
		is_dealing_damage = false
