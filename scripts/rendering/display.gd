extends Control

@export var viewport: SubViewport
@export var pixel_movement := true
@export var sub_pixel_movement_at_integer_scale := true

@onready var _sprite: Sprite2D = $Sprite2D


func _process(_delta: float) -> void:
	var screen_size := Vector2(get_window().size)
	# viewport size minus padding
	var game_size := Vector2(viewport.size - Vector2i(2, 2))
	var display_scale := screen_size / game_size
	# maintain aspect ratio
	var display_scale_min: float = minf(display_scale.x, display_scale.y)
	_sprite.scale = Vector2(display_scale_min, display_scale_min)
	# scale and center control node
	size = (_sprite.scale * game_size).round()
	position = ((screen_size - size) / 2).round()
	# smooth!
	if pixel_movement:
		var cam := viewport.get_camera_3d() as Camera3DTexelSnapped
		var pixel_error: Vector2 = cam.texel_error * _sprite.scale
		_sprite.position = -_sprite.scale + pixel_error
		var is_integer_scale := display_scale == display_scale.floor()
		if is_integer_scale and not sub_pixel_movement_at_integer_scale:
			_sprite.position = _sprite.position.round()
