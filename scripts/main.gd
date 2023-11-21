extends Node3D

func _process(_delta):
	if Input.is_action_pressed("exit"):
		get_tree().quit()
