@tool
extends DirectionalLight3D

@export var speed := 5.0;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_rotation_degrees.y += speed * delta;
