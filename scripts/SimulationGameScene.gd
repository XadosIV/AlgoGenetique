extends Node2D

# ** -- Genetique -- **
var genome = PackedFloat32Array()
var exit_reached = false
var player : Player
var fitness = 0
var caught_last_frame = false

func init_random_genome():
	var input_count = get_inputs().size()
	var size = input_count * 2
	genome.resize(size)
	for i in size:
		genome[i] = randf_range(-1.0, 1.0)

func get_inputs():
	var inputs = []

	# 1. État du joueur
	inputs.append(float(player.inJail))
	inputs.append(player.velocity.length() / player.SPEED)
	var vel_dir = Vector2.ZERO
	if player.velocity.length() > 0.01:
		vel_dir = player.velocity.normalized()
	inputs.append(vel_dir.x)
	inputs.append(vel_dir.y)

	# 2. Sortie : distance
	var to_exit = $EXIT_AREA.global_position - player.global_position
	var exit_dist = to_exit.length() / 1762.0  # diagonale écran
	inputs.append(exit_dist)
	
	# 3. Direction du chemin
	var agent = player.get_node("NavigationAgent2D")
	agent.radius = 30
	agent.path_desired_distance = 8
	agent.target_desired_distance = 8
	agent.avoidance_enabled = true
	agent.target_position = $EXIT_AREA.global_position
	var next_pos = agent.get_next_path_position()
	var path_dir = (next_pos - player.global_position).normalized()
	inputs.append(path_dir.x)
	inputs.append(path_dir.y)

	# 3. Ennemis : direction + distance + visibilité
	for enemy in $Enemies.get_children():
		var to_guard = enemy.global_position - player.global_position
		var guard_dir = to_guard.normalized()
		var guard_dist = to_guard.length() / 1762.0

		inputs.append(guard_dir.x)
		inputs.append(guard_dir.y)
		inputs.append(guard_dist)
		inputs.append(1.0 if enemy.state != 0 else 0.0)

	# 4. Distance aux murs
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for dir in directions:
		var params = PhysicsRayQueryParameters2D.new()
		params.from = player.global_position
		params.to = player.global_position + dir * 300
		params.exclude = [player]

		var hit = get_world_2d().direct_space_state.intersect_ray(params)
		var dist = 300.0
		if hit:
			dist = (hit.position - player.global_position).length()
		inputs.append(dist / 300.0)

	return inputs


func compute_ai():
	var inputs = get_inputs()
	var x = 0.0
	var y = 0.0
	
	for i in inputs.size():
		x += inputs[i] * genome[i]
		y += inputs[i] * genome[i + inputs.size()]
	
	var ai_direction = Vector2(x, y).normalized()
	
	return ai_direction


func get_path_distance(path: PackedVector2Array) -> float:
	var d = 0.0
	for i in range(path.size() - 1):
		d += path[i].distance_to(path[i + 1])
	return d


var last_distance_to_exit = 0.0
@onready var exit_area_x = $EXIT_AREA.global_position.x
@onready var best_distance = abs($Player.global_position.x -  exit_area_x)

func _ready():
	player = $Player
	if genome.is_empty():
		init_random_genome()

func _process(_delta):
	# -----------------------------
	# Progrès vers la sortie
	# -----------------------------
	var dist = abs(player.global_position.x -  exit_area_x)
	if dist < best_distance:
		fitness += (abs(best_distance - dist)) * 50
		best_distance = dist

	# -----------------------------
	# Se faire capturer
	# -----------------------------
	if not player.canMove and not caught_last_frame:
		fitness *= 0.5

	caught_last_frame = not player.canMove

	# -----------------------------
	# Malus pour temps passé en prison
	# -----------------------------
	if player.inJail:
		fitness /= 1.2
		fitness -= 1 # passer en négatif

func _on_exit_area_body_entered(body):
	if body == player and not exit_reached:
		fitness += 10000000
		exit_reached = true
