@tool
extends DirectionalLight3D

@export var orbit: bool = false
@export var rotation_speed: float = 1
@export var axis: Vector3 = Vector3.UP

var _previous_direction: Vector3 = Vector3.ZERO

func _process(_delta):
	if orbit:
		global_rotate(axis, rotation_speed * _delta * 0.01)
	var direction: Vector3 = -global_transform.basis.z
	if _previous_direction != direction:
		RenderingServer.global_shader_parameter_set("sun_direction", direction)
		_previous_direction = direction
	DebugDraw3D.draw_arrow_line(global_transform.origin, global_transform.origin + direction * 10, Color(1, 1, 0, 1))
