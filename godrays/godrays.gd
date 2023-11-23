@tool
extends MultiMeshInstance3D

@export var count: int = 8
@export var depth: float = 20

@export var sun: Node3D


func _process(_delta):
	update()


func update():
	multimesh.instance_count = count
	for i in range(count):
		var offset = (float(i) / count - 0.5) * depth * -sun.global_basis.y
		multimesh.set_instance_transform(i, Transform3D(Basis.looking_at(sun.basis.y), offset))
		# multimesh.set_instance_custom_data(i, Color(float(i) / count, 0, 0))
