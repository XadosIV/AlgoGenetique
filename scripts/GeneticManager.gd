extends Node

@export var game_scene : PackedScene
@export var image_of_player_scene : PackedScene

# PARAMETRES
@export var population_size = 40
@export var simulation_time = 20.0
@export var percent_election = 0.2 # Pourcentage d'individu utilisé pour créer la gen d'après
@export var parent_still = true # garde les parents pour la génération suivante
@export var percent_mutation = 0.2 # pourcentage de mutation de chaque gène
@export var highlight_best_numbers = 8 # Nombre d'individus affichés en vert (= les meilleurs)

var timer = 0.0
var simulations = []
var imageOfPlayers = []
var generation = 0

var spawn_position = Vector2(72,97)

func _ready():
	for i in population_size:
		var p = image_of_player_scene.instantiate()
		p.index = i
		$SimulationScene/Players.add_child(p)
		imageOfPlayers.append(p)
	
	create_new_simulations()

func _process(delta):
	Engine.time_scale = 5
	timer += delta
	
	var maximum_score = simulations[0].fitness
	var maximum_index = 0
	var nb_exited = 0
	
	for i in range(simulations.size()):
		var refPlayer = simulations[i].player
		imageOfPlayers[i].position = refPlayer.position
		
		if not refPlayer.canMove:
			imageOfPlayers[i].modulate = Color.RED
			imageOfPlayers[i].visible = true
		else:
			imageOfPlayers[i].modulate = Color.WHITE
			imageOfPlayers[i].visible = true
			
		
		if simulations[i].fitness > maximum_score:
			maximum_index = i
			maximum_score = simulations[i].fitness
		
		if i == $Camera.currently_watching:
			simulations[i].visible = true
		else:
			simulations[i].visible = false
	
		if simulations[i].exit_reached:
			nb_exited += 1
	
	
	var scored = []
	for i in range(len(simulations)):
		var sim = simulations[i]
		scored.append({
			"index": i,
			"genome": sim.genome,
			"fitness": sim.fitness
	})
	
	# Trier par fitness décroissante
	scored = sort_by_fitness_desc(scored)
	
	for i in range(highlight_best_numbers):
		imageOfPlayers[scored[i]["index"]].modulate = Color.GREEN
	
	
	$Camera/Label.text = "Gen : " + str(generation)
	$Camera.bestIndex = maximum_index

	if $Camera.currently_watching != -1:
		var exit_reached = "Yes" if simulations[$Camera.currently_watching].exit_reached else "No"
		$Camera/Label3.text = "Fit : " + str(int(simulations[$Camera.currently_watching].fitness)) + " Exited : " + exit_reached
	else:
		$Camera/Label3.text = "Fit : " + str(int(round(maximum_score))) + " Exited : " + str(nb_exited)
	
	if timer >= simulation_time:
		end_generation()

func clear_simulations():
	for sim in simulations:
		sim.queue_free()
	simulations.clear()

func sort_by_fitness_desc(scored_array):
	for i in range(scored_array.size()):
		for j in range(i + 1, scored_array.size()):
			if scored_array[j]["fitness"] > scored_array[i]["fitness"]:
				var temp = scored_array[i]
				scored_array[i] = scored_array[j]
				scored_array[j] = temp
	return scored_array

func end_generation():
	# Récupérer les genomes et fitness
	var scored = []
	for i in range(len(simulations)):
		var sim = simulations[i]
		scored.append({
			"index": i,
			"genome": sim.genome,
			"fitness": sim.fitness
	})
	
	# Trier par fitness décroissante
	scored = sort_by_fitness_desc(scored)
	
	print("Génération %d, meilleur score : %f" % [generation, scored[0].fitness])
	
	# Sélection : garder les top X% comme parents
	var top_count = int(population_size * percent_election)
	var parents = scored.slice(0, top_count)
	
	var new_genomes = []
	
	var nb_enfant = population_size
	if parent_still:
		nb_enfant -= top_count
	
	# Générer la prochaine génération
	while new_genomes.size() < nb_enfant:
		# Choisir deux parents aléatoirement parmi les meilleurs
		var p1 = parents[randi() % top_count]["genome"]
		var p2 = parents[randi() % top_count]["genome"]
		
		# Crossover simple (moitié moitié)
		var child = PackedFloat32Array()
		child.resize(p1.size())
		for i in p1.size():
			child[i] = p1[i] if randi() % 2 == 0 else p2[i]
		
		# Mutation aléatoire
		for i in child.size():
			if randf() < percent_mutation: # X% chance de muter chaque gène
				child[i] += randf_range(-0.5, 0.5)
		
		new_genomes.append(child)
	
	if parent_still:
		for parent in parents:
			new_genomes.append(parent["genome"])
	
	new_genomes.shuffle()
	# Créer les nouvelles simulations
	create_new_simulations(new_genomes)
	
	generation += 1


func create_new_simulations(new_genomes=[]):
	# Supprimer les simulations actuelles
	timer = 0.0
	clear_simulations()
	
	if len(new_genomes) != 0:
		for i in len(new_genomes):
			var genome = new_genomes[i]
			var g = game_scene.instantiate()
			g.visible = false
			g.position = Vector2((i+1) * 2500, 0)
			$Simulations.add_child(g)
			g.genome = genome
			simulations.append(g)
	else:
		for i in population_size:
			var g = game_scene.instantiate()
			g.visible = false
			g.position = Vector2((i+1) * 2500, 0)
			# Si aucun génome n'est donné, c'est 
			# la simulation qui se charge d'en générer un.
			$Simulations.add_child(g)
			simulations.append(g)
