extends Node2D  # on ne peut pas dessiner directement sur RayCast2D

@export var ray_length := 1000
@export var angle_step := 5
@export var fov := 30  # degrés de chaque côté

var player_in_sight = false
var last_player_pos = Vector2.ZERO


var res = []

func _process(delta):
	queue_redraw()  # redessine à chaque frame
	res = []
	player_in_sight = false
	for i in range(-fov, fov + 1, angle_step):
		var dir = get_parent().transform.x.normalized().rotated(deg_to_rad(i))

		var params = PhysicsRayQueryParameters2D.new()
		params.from = global_position
		params.to = global_position + dir * ray_length
		params.exclude = [self, get_parent()]
		var space_state = get_world_2d().direct_space_state
		var result = space_state.intersect_ray(params)
		if result:
			res.append(result.position)
			if result.collider.name == "Player":
				player_in_sight = true
				last_player_pos = result.position

func _draw():
	for i in res:
		draw_line(Vector2.ZERO, to_local(i), Color.RED)
