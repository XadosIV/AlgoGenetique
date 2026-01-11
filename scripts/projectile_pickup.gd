extends Node2D

class_name ProjectilePickup

var available = true

var max_timer = 10
var timer = 10

func _process(delta):
	if not available:
		timer -= delta
		if timer < 0:
			available = true
			$Projectile.visible = true
			timer = max_timer

func _on_area_2d_body_entered(body):
	if not available:
		return
	if body is Enemy:
		if not body.hasProjectile:
			body.hasProjectile = true
			available = false
			$Projectile.visible = false
