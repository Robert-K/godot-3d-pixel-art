extends CharacterBody3D

@export var camera: Camera3D

const SPEED = 5.0
const JUMP_VELOCITY = 10

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _animation_player: AnimationPlayer = $fox/AnimationPlayer

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta * 3 # magic number to make the jump feel better.
		_animation_player.play("Fall")

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# project camera direction onto the xz plane
	var camera_dir = camera.global_transform.basis.z - camera.global_transform.basis.y
	camera_dir.y = 0
	camera_dir = camera_dir.normalized()

	var direction = camera_dir * input_dir.y + camera.global_transform.basis.x * input_dir.x

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		rotation.y = atan2(direction.x, direction.z)
		if is_on_floor():
			_animation_player.play("Run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if is_on_floor():
			if _animation_player.current_animation != "Idle":
				_animation_player.play("Idle")
				var offset : float = randf_range(0, _animation_player.current_animation_length)
				_animation_player.advance(offset)
				rotation.y -= deg_to_rad(20)

	move_and_slide()
