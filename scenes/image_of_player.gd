extends Area2D

var index

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		get_node("/root/GeneticManager/Camera").getCamFor(index)
