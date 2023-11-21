extends MultiMeshInstance3D

@export var terrain: MeshInstance3D = null
@export var grass_count: int = 1000
@export var attempts_per_grass: int = 2
@export var noise: Noise = null
@export var noise_influence: float = 2.0

# Calculate the gradient of the noise at a given point
func gradient(x, y, d):
	var dx = noise.get_noise_2d(x + d, y) - noise.get_noise_2d(x - d, y)
	var dy = noise.get_noise_2d(x, y + d) - noise.get_noise_2d(x, y - d)
	return Vector2(dx, dy)

func scatter():
	multimesh.instance_count = 0
	#multimesh.use_custom_data = true
	#multimesh.use_colors = true
	multimesh.instance_count = int(sqrt(grass_count) * sqrt(grass_count))
	# get terrain bounds
	var bounds = terrain.mesh.get_aabb()
	var start = bounds.position
	var end = bounds.position + bounds.size

	print("scattering")

	var placed = 0
	for x in range(sqrt(grass_count)):
		for z in range(sqrt(grass_count)):
			var x_pos = lerp(start.x, end.x, x / sqrt(grass_count))
			var z_pos = lerp(start.z, end.z, z / sqrt(grass_count))
			var y_pos = terrain.global_position.y
			var pos = Vector2(x_pos, z_pos) + gradient(x_pos, z_pos, 1) * noise_influence
			multimesh.set_instance_transform(placed, Transform3D(Basis(), Vector3(pos.x, y_pos, pos.y)))
			#var color = Color.from_hsv(randf(), 1, 1)
			#multimesh.set_instance_color(placed, color)
			placed += 1
	print("Placed:", placed)

func _ready():
	scatter()