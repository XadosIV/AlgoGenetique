extends CharacterBody2D
class_name Enemy

enum State { PATROL, CHASE, SEEK_PLAYER, CATCH_PLAYER, GOTO_JAIL, GOTO_PATROL }

@export var MAX_SPEED := 250
var SPEED := MAX_SPEED

@export var jail_point : Marker2D
@export var patrol_points_node : Node2D  # positions Vector2 pour patrouiller
var patrol_points : Array[Vector2] = []  # positions Vector2 pour patrouiller
@export var player : CharacterBody2D

@onready var agent := $NavigationAgent2D

var recover_max_timer = 3
var recover_timer = 3

var state = State.PATROL
var patrol_index = 0

var player_not_found = false
var player_close = false

var last_player_pos

var player_collide = false
var player_attached = false

var to_patrol = false

@onready var fov = $FOV

@export var throw_cooldown := 1.0
var throw_timer := 0.0
@export var throw_angle_tolerance := deg_to_rad(10)  # tolérance pour être “aligné”


func _ready():
	# Convertir les NodePath en Node
	for node in patrol_points_node.get_children():
		if node != null:
			patrol_points.append(node.global_position)
	agent.radius = 16
	agent.path_desired_distance = 4
	agent.target_desired_distance = 8

func _process(delta):
	throw_timer -= delta

	handle_states(delta)

func is_player_in_sight():
	if (fov.player_in_sight or player_close) and not player.inJail:
		if fov.player_in_sight:
			last_player_pos = fov.last_player_pos
		else:
			last_player_pos = player.global_position
		return true
	return false

func lineup_with_player():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.new()
	params.from = global_position
	params.to = player.global_position
	params.exclude = [self]
	var result = space_state.intersect_ray(params)
	if result.collider.name == "Player":
		look_at(player.global_position)
		return true
	else:
		return false


func handle_states(delta):
	match state:
		State.PATROL:
			if is_player_in_sight(): # Joueur vu
				state = State.CHASE
			else:
				_patrol()
		State.CHASE:
			if not is_player_in_sight(): # Joueur perdu
				state = State.SEEK_PLAYER
			elif player_close: # Joueur proche
				state = State.CATCH_PLAYER
			else:
				_chase()
		State.SEEK_PLAYER:
			if is_player_in_sight(): # Joueur vu
				state = State.CHASE
			elif player_not_found: # Joueur perdu
				player_not_found = false
				state = State.GOTO_PATROL
			else:
				_seek_player()
		
		State.CATCH_PLAYER:
			if not player_close:
				state = State.CHASE
			elif player_collide:
				state = State.GOTO_JAIL
			else:
				_catch_player(delta)
		
		State.GOTO_JAIL:
			if not player_collide and not player_attached:
				state = State.GOTO_PATROL
			else:
				_goto_jail()
		
		State.GOTO_PATROL:
			if to_patrol:
				to_patrol = false
				state = State.PATROL
			else:
				_goto_patrol()

func _patrol():
	if patrol_points.size() == 0:
		return
	
	var target = patrol_points[patrol_index]
	agent.target_position = target
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	
	var distance_to_target = global_position.distance_to(target)
	var frame_distance = SPEED * get_process_delta_time()
	
	var current_speed = SPEED
	if frame_distance > distance_to_target:
		current_speed = distance_to_target / get_process_delta_time()
	
	velocity = dir * current_speed
	
	# rotation progressive
	var target_angle = (next_pos - global_position).angle()
	rotation = lerp_angle(rotation, target_angle, 5 * get_process_delta_time())
	
	move_and_slide()
	
	if global_position.distance_to(target) < 10:
		patrol_index = (patrol_index + 1) % patrol_points.size()



func _chase():
	agent.target_position = player.global_position
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	move_and_slide()

func _seek_player():
	var target = last_player_pos
	
	agent.target_position = target
	
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	
	var distance_to_target = global_position.distance_to(target)
	var frame_distance = SPEED * get_process_delta_time()
	
	var current_speed = SPEED
	if frame_distance > distance_to_target:
		current_speed = distance_to_target / get_process_delta_time()
	
	velocity = dir * current_speed
	look_at(next_pos)
	move_and_slide()
	
	if global_position.distance_to(last_player_pos) < 10:
		player_not_found = true

func _catch_player(delta):
	agent.target_position = player.global_position
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	var c = move_and_collide(velocity * delta)
	if c:
		var collider = c.get_collider()
		if collider.name == "Player":
			player_collide = true

func _goto_jail():
	player_collide = false
	player_attached = true
	player.attached()
	
	var target = jail_point.global_position
	agent.target_position = target
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	
	var distance_to_target = global_position.distance_to(target)
	var frame_distance = SPEED * get_process_delta_time()
	
	var current_speed = SPEED
	if frame_distance > distance_to_target:
		current_speed = distance_to_target / get_process_delta_time()
	
	velocity = dir * current_speed
	look_at(next_pos)
	move_and_slide()
	
	player.global_position = global_position + Vector2.RIGHT * 16
	
	if global_position.distance_to(target) < 10:
		player_attached = false
		player.released()

func _goto_patrol():
	if patrol_points.is_empty():
		return

	var closest_point = patrol_points[0]
	var min_dist = global_position.distance_to(closest_point)

	for i in range(len(patrol_points)):
		var p = patrol_points[i]
		var d = global_position.distance_to(p)
		if d < min_dist:
			min_dist = d
			closest_point = p
			patrol_index = i

	agent.target_position = closest_point
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	
	var distance_to_target = global_position.distance_to(closest_point)
	var frame_distance = SPEED * get_process_delta_time()
	
	var current_speed = SPEED
	if frame_distance > distance_to_target:
		current_speed = distance_to_target / get_process_delta_time()
	
	velocity = dir * current_speed
	look_at(next_pos)
	move_and_slide()

	if global_position.distance_to(closest_point) < 10:
		to_patrol = true

func _on_player_detection_body_entered(body):
	if body == player:
		player_close = true

func _on_player_detection_body_exited(body):
	if body == player:
		player_close = false
