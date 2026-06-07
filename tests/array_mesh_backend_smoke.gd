extends SceneTree

var failed: bool = false


func _initialize() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var provider: Node = Provider.new()
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()
	var chunk_coord := Vector3i(3, 0, 1)
	var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
	var visual_plan: Dictionary = builder.build_visual_plan(chunk_coord, logic_grid)
	var multimesh_root: Node3D = builder.build_chunk_visual(
		chunk_coord,
		visual_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
	)
	var array_mesh_root: Node3D = builder.build_chunk_visual_array_mesh(
		chunk_coord,
		visual_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
	)

	_assert(multimesh_root.get_meta("visual_backend") == "multimesh", "primary backend is tagged")
	_assert(array_mesh_root.get_meta("visual_backend") == "array_mesh", "array backend is tagged")
	_assert(
		array_mesh_root.get_meta("visual_tile_count") == multimesh_root.get_meta("visual_tile_count"),
		"array backend consumes the same visual tile count"
	)
	_assert(array_mesh_root.get_child_count() == 1, "array backend creates one mesh instance")
	var mesh_instance := array_mesh_root.get_child(0) as MeshInstance3D
	_assert(mesh_instance.mesh is ArrayMesh, "array backend creates ArrayMesh")
	_assert((mesh_instance.mesh as ArrayMesh).get_surface_count() > 0, "array mesh has a surface")
	_assert(_total_multimesh_instances(multimesh_root) == int(visual_plan["tiles"].size()), "multimesh count matches plan")

	multimesh_root.free()
	array_mesh_root.free()
	provider.free()
	quit(1 if failed else 0)


func _total_multimesh_instances(root_node: Node3D) -> int:
	var total := 0
	for child in root_node.get_children():
		var instance := child as MultiMeshInstance3D
		total += instance.multimesh.instance_count
	return total


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("array_mesh_backend_smoke failed: %s" % message)

