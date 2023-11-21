extends Node3D

@export var follow_target: Node3D = null

@export var snap_threshold: float = 2

@export_range(0, 50) var orbit_speed: float = 8.0
var _target_yaw := rotation.y
var _target_pitch: float = rotation.x

@onready var cam: Camera3D = $Camera3D


func angle_difference(from, to):
	var difference = fmod(to - from, TAU)
	return fmod(2 * difference, TAU) - difference

func _ready():
	global_position = follow_target.global_position


func _process(delta: float):
	# movement
	global_position = global_position.lerp(follow_target.global_position, 0.7 * delta)
	
	var snap_radians = deg_to_rad(snap_threshold)

	# orbit
	if Input.is_action_just_pressed("cam_orbit_right"):
		_target_yaw += TAU / 8
	if Input.is_action_just_pressed("cam_orbit_left"):
		_target_yaw -= TAU / 8
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - 2.0 ** (-4.0 * delta * orbit_speed))
	if abs(angle_difference(rotation.y, _target_yaw)) < snap_radians:
		rotation.y = _target_yaw

	# height
	if Input.is_action_just_pressed("cam_height_up"):
		_target_pitch -= TAU / 36
	if Input.is_action_just_pressed("cam_height_down"):
		_target_pitch += TAU / 36
	_target_pitch = clamp(_target_pitch, -TAU / 4, TAU / 4)
	rotation.x = lerp_angle(rotation.x, _target_pitch, 1.0 - 2.0 ** (-4.0 * delta * orbit_speed))
	if abs(angle_difference(rotation.x, _target_pitch)) < snap_radians:
		rotation.x = _target_pitch
