class_name Bonbon

extends Area2D

@export var bonus : int = 2

func _on_body_entered(body):
	if body.name == "Player":
		get_parent().fitness *= bonus
		queue_free()
