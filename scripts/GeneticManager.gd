extends Node

@export var game_scene : PackedScene
@export var image_of_player_scene : PackedScene
@export var simulation_scene : Node2D

var population_size = 50
var simulation_time = 20.0
var timer = 0.0

var simulations = []
var imageOfPlayers = []
var generation = 0

var spawn_position = Vector2(72,97)



func _ready():
	Engine.time_scale = 5
	
	for i in population_size:
		var p = image_of_player_scene.instantiate()
		p.index = i
		$SimulationScene/Players.add_child(p)
		imageOfPlayers.append(p)
	
	create_new_simulations()



func _process(delta):
	timer += delta
	
	var maximum_score = simulations[0].fitness
	var maximum_index = 0
	
	for i in range(simulations.size()):
		var refPlayer = simulations[i].player
		imageOfPlayers[i].position = refPlayer.position
		
		if not refPlayer.canMove:
			imageOfPlayers[i].modulate = Color.RED
		else:
			imageOfPlayers[i].modulate = Color.WHITE
		
		
		if simulations[i].fitness > maximum_score:
			maximum_index = i
			maximum_score = simulations[i].fitness
		
		if i == $Camera.currently_watching:
			simulations[i].visible = true
		else:
			simulations[i].visible = false
		
	$Camera/Label.text = "Gen : " + str(generation)
	$Camera.bestIndex = maximum_index

	if $Camera.currently_watching != -1:
		$Camera/Label3.text = "Fitness : " + str(simulations[$Camera.currently_watching].fitness)
	else:
		$Camera/Label3.text = "Fitness : " + str(maximum_score)
	
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
	
	# Sélection : garder les top 20% comme parents
	var top_count = int(population_size * 0.2)
	var parents = scored.slice(0, top_count)
	
	var new_genomes = []
	
	# Générer la prochaine génération
	while new_genomes.size() < population_size:
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
			if randf() < 0.1: # 10% chance de muter chaque gène
				child[i] += randf_range(-0.5, 0.5)
		
		new_genomes.append(child)
	
	
	
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
			$Simulations.add_child(g)
			simulations.append(g)
