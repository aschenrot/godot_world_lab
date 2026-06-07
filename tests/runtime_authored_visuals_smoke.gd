extends SceneTree

const REQUIRED_BASE_MESHES: Array[String] = [
	"corner",
	"edge",
	"t",
	"diagonal",
	"full",
	"debug",
]

var failed := false


func _initialize() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var provider: Node = Provider.new()
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()
	var diagnostics: Dictionary = catalog.get_diagnostics()

	_assert(diagnostics["catalog_source"] == "authored_glb", "catalog loads authored GLB")
	_assert(diagnostics["tilekit_load_errors"].is_empty(), "catalog has no tilekit load errors")
	for base_mesh in REQUIRED_BASE_MESHES:
		_assert(diagnostics["loaded_base_meshes"].has(base_mesh), "catalog loaded %s" % base_mesh)
		_assert(catalog.get_mesh(base_mesh) is ArrayMesh, "%s uses authored ArrayMesh" % base_mesh)

	var chunk_coord := Vector3i(0, 0, 0)
	var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
	var visual_plan: Dictionary = builder.build_visual_plan(chunk_coord, logic_grid, catalog)
	_assert(bool(visual_plan["diagnostics"].get("is_valid", false)), "visual plan validates with authored catalog")
	_assert(visual_plan["missing_assets"].is_empty(), "authored catalog has no missing visual assets")

	var root_node: Node3D = builder.build_chunk_visual(
		chunk_coord,
		visual_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
	)
	_assert(root_node.get_child_count() > 0, "runtime visual creates authored MultiMesh buckets")
	for child in root_node.get_children():
		var bucket := child as MultiMeshInstance3D
		_assert(bucket != null, "bucket is MultiMeshInstance3D")
		if bucket != null:
			_assert(bucket.multimesh != null, "bucket has MultiMesh")
			_assert(bucket.multimesh.mesh is ArrayMesh, "bucket uses authored ArrayMesh")

	root_node.free()
	provider.free()
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("runtime_authored_visuals_smoke failed: %s" % message)
