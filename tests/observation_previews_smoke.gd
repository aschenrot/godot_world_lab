extends SceneTree

var failed := false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		quit(1)
		return

	var Catalog := load("res://scripts/tile_mesh_catalog.gd")
	var catalog: RefCounted = Catalog.new()

	var catalog_preview: Node3D = load("res://scripts/previews/tile_catalog_preview.gd").new()
	var catalog_diagnostics: Dictionary = catalog_preview.build_catalog_preview(catalog)
	_assert(catalog_preview.get_child_count() == 6, "catalog preview creates one node per base mesh")
	_assert(catalog_diagnostics["catalog"]["catalog_source"] == "authored_glb", "catalog preview uses authored catalog")
	_assert(catalog_diagnostics["catalog"]["missing_asset_key_count"] == 0, "catalog preview has no missing meshes")
	_assert(catalog_diagnostics["catalog"]["missing_material_key_count"] == 0, "catalog preview has no missing materials")

	var chunk_preview: Node3D = load("res://scripts/previews/generated_chunk_preview.gd").new()
	var chunk_diagnostics: Dictionary = chunk_preview.build_generated_chunk_preview(Vector3i(1, 0, 1), null, null, catalog)
	_assert(chunk_preview.get_child_count() == 1, "chunk preview creates one chunk root")
	_assert(
		chunk_diagnostics["generated_chunk_data"]["product_type"] == "GeneratedChunkData",
		"chunk preview exposes generated product"
	)
	_assert(bool(chunk_diagnostics["visual_plan"].get("is_valid", false)), "chunk preview visual plan is valid")
	_assert(
		chunk_diagnostics["instantiation_plan"].get("visual_tile_count", 0) > 0,
		"chunk preview instantiation plan has visual tiles"
	)

	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var builder: RefCounted = Builder.new()
	var plan: Dictionary = builder.build_visual_plan(Vector3i.ZERO, [[1]], catalog)
	catalog.mesh_by_key.erase("corner")
	catalog.material_by_key.erase("corner")
	var report: Dictionary = catalog.get_asset_report(plan)
	_assert(
		report["visual_plan_validation"]["missing_asset_keys"].has("corner_270"),
		"missing mesh diagnostic reports descriptor key"
	)
	_assert(
		report["visual_plan_validation"]["missing_material_keys"].has("corner_270"),
		"missing material diagnostic reports descriptor key"
	)

	catalog_preview.free()
	chunk_preview.free()
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("observation_previews_smoke failed: %s" % message)
