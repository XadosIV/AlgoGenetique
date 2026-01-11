extends CharacterBody2D

@export var speed := 1000
var direction := Vector2.RIGHT
var projectile_owner


func _physics_process(delta):
	var c = move_and_collide(direction * speed * delta)
	if c:
		var collider = c.get_collider()
		if collider.name != projectile_owner:
			if collider.name == "Enemy" or collider.name == "Player":
				collider.injured += 1
			queue_free()
