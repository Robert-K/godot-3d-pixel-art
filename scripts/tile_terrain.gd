@tool
extends MeshInstance3D

@export var heightmap: Texture2D = null
@export var bounds := Vector3(64, 8, 64):
	set(value):
		bounds = value
		generate_terrain()

func _get_tool_buttons():
	return [
		generate_terrain
	]

func get_map_value(image, x, z, grid_size):
	if x < 0 or x >= grid_size.x or z < 0 or z >= grid_size.y:
		return 0
	return image.get_pixel(x, z).r

func generate_tile(x, z, st, image, grid_size):
	var uv = Vector2(x, z) / grid_size
	var map_value = image.get_pixel(x, z).r
	var pos = Vector3(uv.x, map_value, uv.y) * bounds
	var pos_next = pos + Vector3(1, map_value, 1) / Vector3(grid_size.x, 1, grid_size.y) * bounds
	
	var add_floor_vertex = func(_x, _z):
		st.set_normal(Vector3.MODEL_TOP)
		st.set_uv(uv)
		st.add_vertex(Vector3(_x, pos.y, _z))
	
	# Generate quad
	add_floor_vertex.call(pos_next.x, pos_next.z)
	add_floor_vertex.call(pos.x, pos_next.z)
	add_floor_vertex.call(pos_next.x, pos.z)
	add_floor_vertex.call(pos_next.x, pos.z)
	add_floor_vertex.call(pos.x, pos_next.z)
	add_floor_vertex.call(pos.x, pos.z)

	var add_right_vertex = func(_x, _y, _z, normal):
		st.set_normal(normal)
		st.set_uv(uv)
		st.add_vertex(Vector3(_x, _y, _z))

	# Generate wall to next tile if height is different
	# x+
	var next_value = get_map_value(image, x + 1, z, grid_size)
	if map_value != next_value:
		var next_height = next_value * bounds.y
		var normal = Vector3.RIGHT if next_value < map_value else Vector3.LEFT
		add_right_vertex.call(pos_next.x, next_height, pos.z, normal)
		add_right_vertex.call(pos_next.x, next_height, pos_next.z, normal)
		add_right_vertex.call(pos_next.x, pos.y, pos.z, normal)
		add_right_vertex.call(pos_next.x, next_height, pos_next.z, normal)
		add_right_vertex.call(pos_next.x, pos.y, pos_next.z, normal)
		add_right_vertex.call(pos_next.x, pos.y, pos.z, normal)

	var add_forward_vertex = func(_x, _y, _z, normal):
		st.set_normal(normal)
		st.set_uv(uv)
		st.add_vertex(Vector3(_x, _y, _z))

	# z+
	next_value = get_map_value(image, x, z + 1, grid_size)
	if map_value != next_value:
		var next_height = next_value * bounds.y
		var normal = Vector3.BACK if next_value < map_value else Vector3.FORWARD
		add_forward_vertex.call(pos_next.x, pos.y, pos_next.z, normal)
		add_forward_vertex.call(pos_next.x, next_height, pos_next.z, normal)
		add_forward_vertex.call(pos.x, pos.y, pos_next.z, normal)
		add_forward_vertex.call(pos.x, pos.y, pos_next.z, normal)
		add_forward_vertex.call(pos_next.x, next_height, pos_next.z, normal)
		add_forward_vertex.call(pos.x, next_height, pos_next.z, normal)

func generate_terrain():
	var image = heightmap.get_image()
	var st = SurfaceTool.new()
	var grid_size = Vector2(image.get_width(), image.get_height())
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(image.get_width() - 1):
		for z in range(image.get_height() - 1):
			generate_tile(x, z, st, image, grid_size)
	st.index()
	mesh = st.commit()