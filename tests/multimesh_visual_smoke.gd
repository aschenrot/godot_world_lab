extends SceneTree

var failed: bool = false


func _initialize() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var provider: Node = Provider.new()
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()

	var chunk_coord := Vector3i(1, 0, -1)
	var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
	var visual_plan: Dictionary = builder.build_visual_plan(chunk_coord, logic_grid)
	var root_node: Node3D = builder.build_chunk_visual(
		chunk_coord,
		visual_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
	)

	_assert(root_node.get_child_count() > 0, "chunk visual creates MultiMesh buckets")
	_assert(_all_children_are_multimesh_instances(root_node), "all bucket children are MultiMeshInstance3D")
	_assert(_total_instance_count(root_node) == visual_plan["tiles"].size(), "instances match visual tile count")

	root_node.free()
	provider.free()
	quit(1 if failed else 0)


func _all_children_are_multimesh_instances(root_node: Node3D) -> bool:
	for child in root_node.get_children():
		if not child is MultiMeshInstance3D:
			return false
		var instance := child as MultiMeshInstance3D
		if instance.multimesh == null:
			return false
		if instance.multimesh.instance_count <= 0:
			return false
	return true


func _total_instance_count(root_node: Node3D) -> int:
	var total := 0
	for child in root_node.get_children():
		var instance := child as MultiMeshInstance3D
		total += instance.multimesh.instance_count
	return total


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("multimesh_visual_smoke failed: %s" % message)

