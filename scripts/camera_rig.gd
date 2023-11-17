extends Node3D

@export var move_speed: float = 8.0
var _velocity: Vector2 = Vector2.ZERO

@export_range(0, 50) var orbit_speed: float = 8.0
var _target_orbit := rotation.y
var _target_height: float = rotation.x

@onready var cam: Camera3D = $Camera3D


func _process(delta: float) -> void:
	# movement
	var input_vec := Input.get_vector("cam_left", "cam_right", "cam_back", "cam_forward")
	
	input_vec = lerp(_velocity, input_vec, 0.1)
	_velocity = input_vec
	
	# basis without pitch, so pretty much the yaw; who rolls a camera??
	var yaw := Basis(basis.x, Vector3.UP, basis.z).orthonormalized()
	# prevent infinite camera speed when camera is on with XZ plane
	if abs(sin(rotation.x)) < 0.1: input_vec.y = 0
	# scaling forward so pitched ortho camera speed seems constant as if 2D
	var move_vec := yaw * Vector3(input_vec.x, 0, input_vec.y / sin(rotation.x))
	position += move_vec * move_speed * delta
	
	# orbit
	if Input.is_action_just_pressed("cam_orbit_right"):
		_target_orbit += TAU/8
	if Input.is_action_just_pressed("cam_orbit_left"):
		_target_orbit -= TAU/8
	rotation.y = lerpf(rotation.y, _target_orbit, 1.0 - 2.0 ** (-4.0 * delta * orbit_speed))
	if absf(rotation.y - _target_orbit):
		var tween = get_tree().create_tween()
		tween.tween_property(self, "rotation:y", _target_orbit, 0.1)
		
	# height
	if Input.is_action_just_pressed("cam_height_up"):
		_target_height -= TAU/36
	if Input.is_action_just_pressed("cam_height_down"):
		_target_height += TAU/36
	rotation.x = lerpf(rotation.x, _target_height, 1.0 - 2.0 ** (-4.0 * delta * orbit_speed))
	if absf(rotation.x - _target_height) < 0.02:
		var tween = get_tree().create_tween()
		tween.tween_property(self, "rotation:x", _target_height, 0.1)
