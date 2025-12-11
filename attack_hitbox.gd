
# res://scripts/attack_hitbox_enemy.gd
extends Area2D
@export var damage: int = 10

func _ready() -> void:
	monitoring = false  # turned on/off by the enemy script during attack
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_area_entered(area: Area2D) -> void:
	_apply(area)

func _on_body_entered(body: Node) -> void:
	_apply(body)

func _apply(target: Node) -> void:
	var recipient := target
	if target is Area2D:
		var owner := target.get_owner()
		if owner:
			recipient = owner
	# Avoid self-hits
	if recipient == owner:
		return
	if recipient and recipient.has_method("apply_damage"):
		recipient.apply_damage(damage, owner)
