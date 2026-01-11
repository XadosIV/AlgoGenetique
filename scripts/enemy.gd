extends CharacterBody2D
class_name Enemy

enum State { PATROL, CHASE, SEEK_PLAYER, CATCH_PLAYER, THROW, TAKE_PROJECTILE, GOTO_JAIL, GOTO_PATROL }

@export var MAX_SPEED := 250
var SPEED := MAX_SPEED

@export var jail_point : Marker2D
@export var projectile : PackedScene
@export var patrol_points_node : Node2D  # positions Vector2 pour patrouiller
var patrol_points : Array[Vector2] = []  # positions Vector2 pour patrouiller
@export var player : CharacterBody2D
@export var projectile_pickup_node : Node2D
var pickups = []

@onready var agent := $NavigationAgent2D
@export var label : Label

var recover_max_timer = 3
var recover_timer = 3

var state = State.PATROL
var patrol_index = 0

var player_not_found = false
var player_close = false
var closest_projectile
var closest_projectile_dist
var hasProjectile = false

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
			patrol_points.append(node.position)
	for node in projectile_pickup_node.get_children():
		if node != null:
			pickups.append(node)
	agent.radius = 16
	agent.path_desired_distance = 4
	agent.target_desired_distance = 8
	
	

func _process(delta):
	$Projectile.visible = hasProjectile
	throw_timer -= delta

	handle_states(delta)

func is_player_in_sight():
	return fov.player_in_sight or player_close

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
			label.text = "STATE : PATROL"
			if is_player_in_sight(): # Joueur vu
				state = State.CHASE
			else:
				_patrol()
		State.CHASE:
			label.text = "STATE : CHASE"
			if not is_player_in_sight(): # Joueur perdu
				state = State.SEEK_PLAYER
			elif player_close: # Joueur proche
				state = State.CATCH_PLAYER
			elif is_projectile_close() and not hasProjectile: # Projectile proche
				state = State.TAKE_PROJECTILE
			else:
				if hasProjectile and lineup_with_player():
					var to_player = (player.global_position - global_position).normalized()
					var angle_to_player = to_player.angle_to(Vector2.RIGHT.rotated(rotation))
					if abs(angle_to_player) < throw_angle_tolerance and throw_timer <= 0:
						state = State.THROW
					else:
						_chase()
				else:
					_chase()
		State.SEEK_PLAYER:
			label.text = "STATE : SEEK_PLAYER"
			if is_player_in_sight(): # Joueur vu
				state = State.CHASE
			elif player_not_found: # Joueur perdu
				player_not_found = false
				state = State.GOTO_PATROL
			else:
				_seek_player()
		
		State.CATCH_PLAYER:
			label.text = "STATE : CATCH_PLAYER"
			if not player_close:
				state = State.CHASE
			elif player_collide:
				state = State.GOTO_JAIL
			else:
				_catch_player(delta)
		
		State.GOTO_JAIL:
			label.text = "STATE : GOTO_JAIL"
			if not player_collide and not player_attached:
				state = State.GOTO_PATROL
			else:
				_goto_jail()
		
		State.GOTO_PATROL:
			label.text = "STATE : GOTO_PATROL"
			if to_patrol:
				to_patrol = false
				state = State.PATROL
			else:
				_goto_patrol()
		
		State.THROW:
			label.text = "STATE : THROW"
			if not hasProjectile:
				state = State.CHASE
			else:
				_throw()

		
		State.TAKE_PROJECTILE:
			label.text = "STATE : TAKE_PROJECTILE"
			if hasProjectile:
				closest_projectile = null
				state = State.THROW
			elif not is_projectile_close():
				state = State.CHASE
			else:
				_take_projectile()

func _patrol():
	if patrol_points.size() == 0:
		return
	agent.target_position = patrol_points[patrol_index]
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	move_and_slide()
	
	if global_position.distance_to(patrol_points[patrol_index]) < 10:
		patrol_index = (patrol_index + 1) % patrol_points.size()

func _chase():
	agent.target_position = player.global_position
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	move_and_slide()

func _seek_player():
	agent.target_position = fov.last_player_pos
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	move_and_slide()
	
	if global_position.distance_to(fov.last_player_pos) < 10:
		player_not_found = true

func _take_projectile():
	agent.target_position = closest_projectile.position
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	move_and_slide()

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

func _throw():
	var num_projectiles = 4  # nombre de projectiles en shotgun
	var min_spread = deg_to_rad(5)   # spread minimal à courte distance
	var max_spread = deg_to_rad(30)  # spread maximal à longue distance
	var dist = global_position.distance_to(player.global_position)

	# calcul du spread selon la distance (linéaire)
	var spread = clamp(dist / 600.0, 0, 1) * (max_spread - min_spread) + min_spread

	for i in range(num_projectiles):
		var proj = projectile.instantiate()
		proj.position = global_position

		var angle_offset = randf_range(-spread / 2, spread / 2)
		var to_player = (player.global_position - global_position)
		proj.direction = to_player.normalized().rotated(angle_offset)

		proj.projectile_owner = name
		get_parent().add_child(proj)

	hasProjectile = false
	throw_timer = throw_cooldown

func _goto_jail():
	player_collide = false
	player_attached = true
	player.attached()
	
	agent.target_position = jail_point.position
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * SPEED
	look_at(next_pos)
	move_and_slide()
	
	player.position = position + Vector2.RIGHT * 16
	
	if global_position.distance_to(jail_point.position) < 10:
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
	velocity = dir * SPEED
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

func is_projectile_close():
	var proj = null
	var dist = INF
	for i in pickups:
		if i.available:
			var distanceToI = position.distance_to(i.position)
			if distanceToI < dist:
				dist = distanceToI
				proj = i
	closest_projectile = proj
	closest_projectile_dist = dist
	
	return dist < 300
