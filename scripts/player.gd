extends CharacterBody2D

class_name Player

var MAX_SPEED = 300.0
var SPEED = MAX_SPEED
var injured = 0
var recover_max_timer = 3
var recover_timer = 3
var inJail = true
var canMove = true

func _process(delta):
	if injured != 0:
		recover_timer -= delta
		if recover_timer <= 0:
			recover_timer = recover_max_timer
			injured -= 1
	SPEED = clamp(MAX_SPEED - injured * 50, 0, 300)

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

	"""var direction = Vector2(
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
