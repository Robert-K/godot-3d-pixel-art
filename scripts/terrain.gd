@tool
extends MeshInstance3D

@export var heightmap: Texture2D = null
@export var bounds := Vector3(64, 8, 64):
	set(value):
		bounds = value
		generate_terrain()


func _get_tool_buttons():
	return [generate_terrain]


func generate_terrain():
	var image = heightmap.get_image()
	var plane = PlaneMesh.new()
	plane.size = Vector2(bounds.x, bounds.z)
	plane.subdivide_depth = heightmap.get_height() -1
	plane.subdivide_width = heightmap.get_width() -1

	# TODO: Give it a material

	var st = SurfaceTool.new()
	var mdt = MeshDataTool.new()
	st.create_from(plane, 0)
	var array_plane = st.commit()
	var error = mdt.create_from_surface(array_plane, 0)
	for x in range(heightmap.get_width()):
		for z in range(heightmap.get_height()):
			var color = image.get_pixel(x, z)
			var height = color.r * bounds.y
			mdt.set_vertex(x + z * heightmap.get_width(), Vector3(x, height, z))
			mdt.set_vertex_color(x + z * heightmap.get_width(), color)
			mdt.set_vertex_uv(x + z * heightmap.get_width(), Vector2(x, z))

	mdt.commit_to_surface(array_plane)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.create_from(array_plane, 0)
	st.generate_normals()

	mesh = st.commit()
	create_trimesh_collision()
