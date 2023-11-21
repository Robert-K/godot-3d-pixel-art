extends CharacterBody3D

@export var camera: Camera3D

@export var animation_framerate: float = 12.0

const SPEED = 5.0
const JUMP_VELOCITY = 10

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _animation_player: AnimationPlayer = $fox/AnimationPlayer

var _animation_timer: Timer

func _ready():
	_animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_MANUAL
	_animation_timer = Timer.new()
	add_child(_animation_timer)
	_animation_timer.connect("timeout", _on_animation_timer_timeout)
	_animation_timer.set_wait_time(1.0 / animation_framerate)
	_animation_timer.set_one_shot(false)
	_animation_timer.start()

func _on_animation_timer_timeout():
	_animation_player.advance(_animation_timer.get_wait_time())

func _process(_delta):
	_animation_player.advance(0) # update animation immediately if it changes

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
			_animation_player.play("Idle")

	move_and_slide()
