extends Node2D

# ** -- Genetique -- **
var genome = PackedFloat32Array()
var exit_reached = false
var player : Player
var fitness = 0
var caught_last_frame = false

var baseDistanceToExit

func init_random_genome():
	var input_count = get_inputs().size()
	var size = input_count * 2 + 1
	genome.resize(size)
	for i in size:
		genome[i] = randf_range(-1.0, 1.0)

func get_inputs():
	var inputs = []

	# 1. État du joueur
	inputs.append(float(player.inJail))
	inputs.append(player.SPEED / player.MAX_SPEED)
	inputs.append(player.velocity.length() / player.MAX_SPEED)

	# 2. Sortie : direction + distance réelle
	var to_exit = $EXIT_AREA.global_position - player.global_position
	var exit_dir = to_exit.normalized()
	var exit_dist = to_exit.length() / 1762.0  # diagonale écran

	inputs.append(exit_dir.x)
	inputs.append(exit_dir.y)
	inputs.append(exit_dist)

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

	# 5. Direction du chemin
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

	return inputs


func compute_ai():
	var inputs = get_inputs()
	var x = 0.0
	var y = 0.0
	
	for i in inputs.size():
		x += inputs[i] * genome[i]
		y += inputs[i] * genome[i + inputs.size()]
	
	var ai_direction = Vector2(x, y).normalized()
	
	# Action “se cacher” si le genome l’indique (dernier gène)
	var hide_gene = genome[inputs.size() * 2]
	if hide_gene > 0.5:
		ai_direction = Vector2.ZERO  # reste immobile

	return ai_direction

var last_path_dist = -1.0

func get_path_distance(path: PackedVector2Array) -> float:
	var d = 0.0
	for i in range(path.size() - 1):
		d += path[i].distance_to(path[i + 1])
	return d


var last_distance_to_exit = 0.0

func _ready():
	player = $Player
	if genome.is_empty():
		init_random_genome()
	last_distance_to_exit = player.position.distance_to($EXIT_AREA.position)

func _process(delta):
	var dist = player.position.distance_to($EXIT_AREA.position)
	var progress = last_distance_to_exit - dist  # progression vers la sortie

	# -----------------------------
	# 1. Progrès vers la sortie
	# -----------------------------
	if progress > 0:
		fitness += progress * 50  # ajuster le facteur pour l’échelle

	# -----------------------------
	# 2. Temps en vie
	# -----------------------------
	fitness += 1 * delta  # récompense continue pour survivre

	# -----------------------------
	# 3. Collision avec un mur
	# -----------------------------
	if player.is_on_wall():
		fitness -= 2 * delta

	# -----------------------------
	# 4. Toucher un ennemi
	# -----------------------------
	if not player.canMove and not caught_last_frame:
		fitness /= 1.2
		#fitness -= 1000  # reset ou grosse pénalité

	caught_last_frame = not player.canMove

	# -----------------------------
	# 5. Temps passé en prison
	# -----------------------------
	if player.inJail:
		fitness /= 1.2

	# -----------------------------
	# 6. Mettre à jour la distance
	# -----------------------------
	last_distance_to_exit = dist


"""var agent = player.get_node("NavigationAgent2D")
	agent.target_position = $EXIT_AREA.global_position

	# distance initiale du chemin
	var path = agent.get_current_navigation_path()
	last_path_dist = get_path_distance(path)"""

"""func _process(delta):
	var agent = player.get_node("NavigationAgent2D")
	agent.target_position = $EXIT_AREA.global_position
	agent.get_next_path_position()
	var path = agent.get_current_navigation_path()
	if path.size() < 2:
		return

	var path_dist = get_path_distance(path)

	# 1. Récompense UNIQUEMENT si on avance sur le chemin
	var progress = last_path_dist - path_dist
	if progress > 0:
		fitness += progress * 20.0

	last_path_dist = path_dist

	# 2. Petite pénalité temps (empêche le camping)
	fitness -= 1.0 * delta

	# 3. Grosse récompense si sortie atteinte
	if exit_reached:
		fitness += 1000.0"""


func _on_exit_area_body_entered(body):
	if body == player and not exit_reached:
		fitness += 10000000
		exit_reached = true
