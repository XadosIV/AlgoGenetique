extends Camera2D

var currently_watching = -1
var base_cam_pos = Vector2(768,432)
var bestIndex

func getCamFor(index):
	currently_watching = index
	position = Vector2((index+1) * 2500, 0) + base_cam_pos


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("ui_right"):
		currently_watching += 1
		if currently_watching > get_parent().population_size-1:
			currently_watching = -1
		getCamFor(currently_watching)
		
	elif Input.is_action_just_pressed("ui_left"):
		currently_watching -= 1
		if currently_watching < -1:
			currently_watching = get_parent().population_size-1
		getCamFor(currently_watching)
	
	elif Input.is_action_just_pressed("ui_up"):
		currently_watching = -1
		getCamFor(currently_watching)
	
	elif Input.is_action_just_pressed("ui_down"):
		getCamFor(bestIndex)
	
	
	if currently_watching != -1:
		$Label2.text = "Watching : " + str(currently_watching)
	else:
		$Label2.text = "Watching : ALL"
		
