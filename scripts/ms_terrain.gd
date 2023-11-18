@tool
extends MeshInstance3D

@export var heightmap: Texture2D
@export var square_size: float = 1
@export var draw_control_nodes: bool = false
@export var draw_outlines: bool = false

@export var height_scale: float = 8
@export var step_height: float = 1
@export var merge_threshold: float = 0.5
@export var slope_multiplier: float = 1

@export var terrace_material: Material

@export var grass_multimesh: MultiMeshInstance3D

var map: Array
var terraces: Array

var generation_time = 0


func _get_tool_buttons():
	return [test]


func _process(delta):
	for terrace in terraces:
		if draw_control_nodes:
			terrace.debug_draw_control_nodes()
		if draw_outlines:
			terrace.debug_draw_outlines()
	DebugDraw2D.set_text("Generation time", generation_time)


func test():
	# Random map
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
	map = []
	var image = heightmap.get_image()
	map.resize(heightmap.get_width())
	for x in range(map.size()):
		var col = []
		col.resize(heightmap.get_height())
		map[x] = col
		for y in range(map[x].size()):
			map[x][y] = MSMapTile.new(image.get_pixel(x, y).r * height_scale)
	var time = Time.get_ticks_msec()
	generate_terraces()
	var tmp_mesh = ArrayMesh.new()
	for terrace in terraces:
		add_terrace_surface_to_mesh(tmp_mesh, terrace, terrace_material)
		add_terrace_walls_to_mesh(tmp_mesh, terrace, terrace_material)
	mesh = tmp_mesh
	#mesh = generate_terrace_mesh_combined(terraces, terrace_material)
	create_trimesh_collision()
	generation_time = Time.get_ticks_msec() - time


func generate_terraces():
	terraces = []
	var current_height = 0
	while current_height < height_scale + step_height:
		terraces.append(
			MSTerrace.new(
				map, square_size, current_height, merge_threshold, slope_multiplier, terraces.size()
			)
		)
		current_height += step_height

func add_terrace_surface_to_mesh(
	array_mesh: ArrayMesh, terrace: MSTerrace, _terrace_material: Material
):
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = terrace.vertices
	surface_array[Mesh.ARRAY_TEX_UV] = terrace.uvs
	surface_array[Mesh.ARRAY_NORMAL] = terrace.normals
	surface_array[Mesh.ARRAY_INDEX] = terrace.indices

	if terrace.vertices.size() > 0:
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, _terrace_material)

func add_terrace_walls_to_mesh(
	array_mesh: ArrayMesh, terrace: MSTerrace, _wall_material: Material
):
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = terrace.wall_vertices
	# surface_array[Mesh.ARRAY_TEX_UV] = terrace.uvs
	# surface_array[Mesh.ARRAY_NORMAL] = terrace.normals
	surface_array[Mesh.ARRAY_INDEX] = terrace.wall_indices

	if terrace.vertices.size() > 0:
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, _wall_material)

func generate_terrace_mesh_combined(terraces: Array, _terrace_material: Material):
	var tmp_mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	surface_array[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	surface_array[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	surface_array[Mesh.ARRAY_INDEX] = PackedInt32Array()
	for terrace in terraces:
		surface_array[Mesh.ARRAY_VERTEX] += terrace.vertices
		surface_array[Mesh.ARRAY_TEX_UV] += terrace.uvs
		surface_array[Mesh.ARRAY_NORMAL] += terrace.normals
		surface_array[Mesh.ARRAY_INDEX] += terrace.indices
	if surface_array[Mesh.ARRAY_VERTEX].size() > 0:
		tmp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
		tmp_mesh.surface_set_material(0, _terrace_material)
	return tmp_mesh


class MSTerrace:
	var map: Array
	var square_size: float
	var square_grid: MSSquareGrid
	var vertices: PackedVector3Array
	var indices: PackedInt32Array
	var uvs: PackedVector2Array
	var normals: PackedVector3Array
	var triangle_dict: Dictionary
	var checked_vertices: PackedInt32Array
	var outlines: Array
	var height: float
	var merge_threshold: float
	var slope_multiplier: float
	var index: int
	var wall_vertices: PackedVector3Array
	var wall_indices: PackedInt32Array

	func _init(
		_map: Array,
		_square_size: float,
		_height: float,
		_merge_threshold: float,
		_slope_multiplier: float,
		_index: int
	):
		map = _map
		square_size = _square_size
		vertices = PackedVector3Array()
		indices = PackedInt32Array()
		uvs = PackedVector2Array()
		normals = PackedVector3Array()
		triangle_dict = {}
		checked_vertices = PackedInt32Array()
		outlines = []
		height = _height
		merge_threshold = _merge_threshold
		slope_multiplier = _slope_multiplier
		index = _index

		square_grid = MSSquareGrid.new(
			map, square_size, height, merge_threshold, slope_multiplier, index
		)

		for x in range(square_grid.squares.size()):
			for y in range(square_grid.squares[x].size()):
				triangulate_square(square_grid.squares[x][y])

		calculate_mesh_outlines()
		calculate_uvs()
		calculate_normals()
		create_wall_mesh()

	func debug_draw_control_nodes():
		for x in range(square_grid.control_nodes.size()):
			for control_node in square_grid.control_nodes[x]:
				var color = Color("red") if control_node.active else Color("blue")
				var size = 0.1
				var dimensions = Vector3(size, size, size)
				DebugDraw3D.draw_box(control_node.position - dimensions / 2, dimensions, color)

	func debug_draw_outlines():
		for outline in outlines:
			var vertex_a: Vector3
			var vertex_b: Vector3
			for i in range(outline.size() - 1):
				vertex_a = vertices[outline[i]]
				vertex_b = vertices[outline[i + 1]]
				DebugDraw3D.draw_line(vertex_a, vertex_b, Color("green"))
			vertex_a = vertices[outline[0]]
			vertex_b = vertices[outline[outline.size() - 1]]
			DebugDraw3D.draw_line(vertex_a, vertex_b, Color("green"))

	func triangulate_square(square: MSSquare):
		match square.configuration:
			# 0 points:
			0:
				return
			# 1 point:
			1:
				mesh_from_points([square.center_left, square.center_bottom, square.bottom_left])
			2:
				mesh_from_points([square.bottom_right, square.center_bottom, square.center_right])
			4:
				mesh_from_points([square.top_right, square.center_right, square.center_top])
			8:
				mesh_from_points([square.top_left, square.center_top, square.center_left])
			# 2 points:
			3:
				mesh_from_points(
					[
						square.center_right,
						square.bottom_right,
						square.bottom_left,
						square.center_left
					]
				)
			6:
				mesh_from_points(
					[square.center_top, square.top_right, square.bottom_right, square.center_bottom]
				)
			9:
				mesh_from_points(
					[square.top_left, square.center_top, square.center_bottom, square.bottom_left]
				)
			12:
				mesh_from_points(
					[square.top_left, square.top_right, square.center_right, square.center_left]
				)
			5:
				mesh_from_points(
					[
						square.center_top,
						square.top_right,
						square.center_right,
						square.center_bottom,
						square.bottom_left,
						square.center_left
					]
				)
			10:
				mesh_from_points(
					[
						square.top_left,
						square.center_top,
						square.center_right,
						square.bottom_right,
						square.center_bottom,
						square.center_left
					]
				)
			# 3 points:
			7:
				mesh_from_points(
					[
						square.center_top,
						square.top_right,
						square.bottom_right,
						square.bottom_left,
						square.center_left
					]
				)
			11:
				mesh_from_points(
					[
						square.top_left,
						square.center_top,
						square.center_right,
						square.bottom_right,
						square.bottom_left
					]
				)
			13:
				mesh_from_points(
					[
						square.top_left,
						square.top_right,
						square.center_right,
						square.center_bottom,
						square.bottom_left
					]
				)
			14:
				mesh_from_points(
					[
						square.top_left,
						square.top_right,
						square.bottom_right,
						square.center_bottom,
						square.center_left
					]
				)
			# 4 points:
			15:
				mesh_from_points(
					[square.top_left, square.top_right, square.bottom_right, square.bottom_left]
				)
				if not square.is_on_map_edge:
					checked_vertices.append(square.top_left.vertex_index)
					checked_vertices.append(square.top_right.vertex_index)
					checked_vertices.append(square.bottom_right.vertex_index)
					checked_vertices.append(square.bottom_left.vertex_index)

	func mesh_from_points(points: Array):
		assign_vertices(points)

		if points.size() >= 3:
			create_triangle(points[0], points[1], points[2])
		if points.size() >= 4:
			create_triangle(points[0], points[2], points[3])
		if points.size() >= 5:
			create_triangle(points[0], points[3], points[4])
		if points.size() >= 6:
			create_triangle(points[0], points[4], points[5])

	func assign_vertices(points: Array):
		for i in range(points.size()):
			if points[i].vertex_index == -1:
				points[i].vertex_index = vertices.size()
				vertices.append(points[i].position)

	func create_triangle(a: MSNode, b: MSNode, c: MSNode):
		# Going counter-clockwise, so the normal points up
		indices.append(c.vertex_index)
		indices.append(b.vertex_index)
		indices.append(a.vertex_index)

		var triangle = MSTriangle.new(a.vertex_index, b.vertex_index, c.vertex_index)
		add_triangle_to_dict(a.vertex_index, triangle)
		add_triangle_to_dict(b.vertex_index, triangle)
		add_triangle_to_dict(c.vertex_index, triangle)

	func add_triangle_to_dict(vertex_index_key: int, triangle: MSTriangle):
		if triangle_dict.has(vertex_index_key):
			triangle_dict[vertex_index_key].append(triangle)
		else:
			var triangle_list = []
			triangle_list.append(triangle)
			triangle_dict[vertex_index_key] = triangle_list

	func calculate_mesh_outlines():
		outlines = []
		for vertex_index in indices:
			if not checked_vertices.has(vertex_index):
				var new_outline_vertex_index = get_connected_outline_vertex(vertex_index)
				if new_outline_vertex_index != -1:
					checked_vertices.append(vertex_index)
					var new_outline = []
					new_outline.append(vertex_index)
					follow_outline(new_outline_vertex_index, new_outline)
					new_outline.append(vertex_index)
					outlines.append(new_outline)

	func follow_outline(vertex_index: int, outline: Array):
		outline.append(vertex_index)
		checked_vertices.append(vertex_index)
		var next_vertex_index = get_connected_outline_vertex(vertex_index)
		if next_vertex_index != -1:
			follow_outline(next_vertex_index, outline)

	func get_connected_outline_vertex(vertex_index: int):
		var triangles_containing_vertex = triangle_dict[vertex_index]
		for triangle in triangles_containing_vertex:
			for triangle_vertex_index in triangle.vertex_indices:
				if (
					vertex_index != triangle_vertex_index
					and not checked_vertices.has(triangle_vertex_index)
					and is_outline_edge(vertex_index, triangle_vertex_index)
				):
					return triangle_vertex_index
		return -1

	func is_outline_edge(vertex_index_a: int, vertex_index_b: int):
		var triangles_containing_a = triangle_dict[vertex_index_a]
		var shared_triangle_count = 0
		for triangle in triangles_containing_a:
			if triangle.contains_vertex(vertex_index_b):
				shared_triangle_count += 1
				if shared_triangle_count > 1:
					break
		return shared_triangle_count == 1

	func calculate_uvs():
		uvs.resize(vertices.size())
		for i in range(uvs.size()):
			var vertex = vertices[i]
			var node_count_x = map.size()
			var node_count_y = map[0].size()
			var map_width = node_count_x * square_size
			var map_height = node_count_y * square_size
			var uv = Vector2(
				(vertex.x + map_width / 2) / map_width, (vertex.z + map_height / 2) / map_height
			)
			uvs[i] = uv

	func calculate_normals():
		normals.resize(vertices.size())
		for i in range(normals.size()):
			normals[i] = Vector3.UP

	func create_wall_mesh():
		var wall_depth = height
		wall_vertices = []
		wall_indices = []
		for outline in outlines:
			for i in range(outline.size() - 1):
				var vertex_a = vertices[outline[i]]
				var vertex_b = vertices[outline[i + 1]]
				var wall_vertex_a = Vector3(vertex_a.x, vertex_a.y - wall_depth, vertex_a.z)
				var wall_vertex_b = Vector3(vertex_b.x, vertex_b.y - wall_depth, vertex_b.z)
				wall_vertices.append(wall_vertex_a)
				wall_vertices.append(wall_vertex_b)
				wall_vertices.append(vertex_b)
				wall_vertices.append(vertex_a)
				var wall_index_offset = wall_vertices.size() - 4
				wall_indices.append(wall_index_offset + 0)
				wall_indices.append(wall_index_offset + 1)
				wall_indices.append(wall_index_offset + 2)
				wall_indices.append(wall_index_offset + 2)
				wall_indices.append(wall_index_offset + 3)
				wall_indices.append(wall_index_offset + 0)

class MSSquareGrid:
	var squares: Array
	var control_nodes: Array = []
	var terrace_index: int

	func _init(
		map: Array,
		square_size: float,
		height: float,
		merge_threshold: float,
		slope_multiplier: float,
		_terrace_index: int
	):
		var node_count_x = map.size()
		var node_count_y = map[0].size()
		var map_width = node_count_x * square_size
		var map_height = node_count_y * square_size
		terrace_index = _terrace_index

		control_nodes.resize(node_count_x)
		for x in range(node_count_x):
			var col = []
			col.resize(node_count_y)
			control_nodes[x] = col
			for y in range(node_count_y):
				var map_tile: MSMapTile = map[x][y]
				var position = Vector3(
					-map_width / 2 + x * square_size,
					(map_tile.height - height) * slope_multiplier + height,
					-map_height / 2 + y * square_size
				)
				var active = (
					map_tile.terrace_index == -1 and abs(map_tile.height - height) < merge_threshold
				)
				control_nodes[x][y] = MSControlNode.new(position, active, square_size)
				if active:
					map[x][y].terrace_index = terrace_index

		squares = []
		squares.resize(node_count_x - 1)
		for x in range(node_count_x - 1):
			var col = []
			col.resize(node_count_y - 1)
			squares[x] = col
			for y in range(node_count_y - 1):
				squares[x][y] = (MSSquare.new(
					control_nodes[x][y + 1],
					control_nodes[x + 1][y + 1],
					control_nodes[x + 1][y],
					control_nodes[x][y],
					x == 0 or x == node_count_x - 2 or y == 0 or y == node_count_y - 2
				))


class MSSquare:
	var top_left: MSControlNode
	var top_right: MSControlNode
	var bottom_right: MSControlNode
	var bottom_left: MSControlNode

	var center_top: MSNode
	var center_right: MSNode
	var center_bottom: MSNode
	var center_left: MSNode

	var configuration: int = 0

	var is_on_map_edge: bool = false

	func _init(
		_top_left: MSControlNode,
		_top_right: MSControlNode,
		_bottom_right: MSControlNode,
		_bottom_left: MSControlNode,
		_is_on_map_edge: bool = false
	):
		top_left = _top_left
		top_right = _top_right
		bottom_right = _bottom_right
		bottom_left = _bottom_left

		center_top = top_left.right
		center_right = bottom_right.above
		center_bottom = bottom_left.right
		center_left = bottom_left.above

		if top_left.active:
			configuration += 8
		if top_right.active:
			configuration += 4
		if bottom_right.active:
			configuration += 2
		if bottom_left.active:
			configuration += 1

		is_on_map_edge = _is_on_map_edge


class MSControlNode:
	extends MSNode
	var active: bool
	var above: MSNode
	var right: MSNode

	func _init(_position: Vector3, _active: bool, square_size: float):
		position = _position
		active = _active
		above = MSNode.new(position + Vector3(0, 0, square_size / 2))
		right = MSNode.new(position + Vector3(square_size / 2, 0, 0))


class MSNode:
	var position: Vector3
	var vertex_index: int = -1

	func _init(_position: Vector3):
		position = _position


class MSTriangle:
	var vertex_index_a: int
	var vertex_index_b: int
	var vertex_index_c: int

	var vertex_indices: PackedInt32Array

	func _init(_vertex_index_a: int, _vertex_index_b: int, _vertex_index_c: int):
		vertex_index_a = _vertex_index_a
		vertex_index_b = _vertex_index_b
		vertex_index_c = _vertex_index_c

		vertex_indices = [vertex_index_a, vertex_index_b, vertex_index_c]

	func contains_vertex(vertex_index: int):
		return (
			vertex_index == vertex_index_a
			or vertex_index == vertex_index_b
			or vertex_index == vertex_index_c
		)


class MSMapTile:
	var height: float
	var terrace_index: int

	func _init(_height: float):
		height = _height
		terrace_index = -1
