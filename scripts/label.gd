extends Label

func _process(_delta):
	# "test" cycles/toggles between °-° and °o°
	if Input.is_action_just_pressed("test"):
		if text == "'-'":
			text = "'o'"
		else:
			text = "'-'"
	
	# "test2" just forces it to x-x
	elif Input.is_action_just_pressed("test2"):
		text = "x-x"
