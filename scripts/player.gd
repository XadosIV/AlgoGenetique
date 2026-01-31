extends CharacterBody2D

class_name Player

var SPEED = 300
var inJail = true
var canMove = true

func attached():
	canMove = false
	$CollisionShape2D.disabled = true

func released():
	canMove = true
	$CollisionShape2D.disabled = false

func _physics_process(_delta):
	if not canMove:
		return

	var direction = get_parent().compute_ai().normalized()

	"""direction = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()"""
	
	velocity = direction * SPEED
	move_and_slide()

func _on_jail_area_body_entered(body):
	if body == self:
		inJail = true

func _on_jail_area_body_exited(body):
	if body == self:
		inJail = false
