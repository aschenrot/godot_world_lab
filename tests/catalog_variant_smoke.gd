extends SceneTree

var failed: bool = false


func _initialize() -> void:
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()
	var plan: Dictionary = builder.build_visual_plan(Vector3i.ZERO, [[1]])

	var default_report: Dictionary = catalog.validate_visual_plan(plan)
	_assert(default_report["is_valid"], "default catalog validates descriptor keys")
	_assert(default_report["missing_asset_keys"].is_empty(), "default catalog has no missing keys")

	var variant_mesh := BoxMesh.new()
	var variant_material := StandardMaterial3D.new()
	variant_material.albedo_color = Color(0.4, 1.0, 0.4, 1.0)
	catalog.register_mesh_variant("corner_270", "moss", variant_mesh)
	catalog.register_material_variant("corner_270", "moss", variant_material)
	catalog.set_selected_variant("moss")

	var variant_report: Dictionary = catalog.validate_visual_plan(plan)
	_assert(variant_report["is_valid"], "variant catalog falls back for unmapped default meshes")
	_assert(catalog.get_mesh("corner_270") == variant_mesh, "registered variant mesh is selected")
	_assert(catalog.get_material("corner_270") == variant_material, "registered variant material is selected")
	_assert(_plan_contains_asset_key(plan, "corner_270"), "variant selection does not change descriptor asset key")

	catalog.clear_missing_asset_keys()
	var fallback_mesh: Mesh = catalog.get_mesh("missing_shape_0")
	_assert(fallback_mesh != null, "missing mesh returns visible debug fallback")
	_assert(catalog.missing_asset_key_count() == 1, "missing asset key is recorded")

	quit(1 if failed else 0)


func _plan_contains_asset_key(plan: Dictionary, asset_key: String) -> bool:
	for tile in plan["tiles"]:
		var data: Dictionary = tile
		if data["asset_key"] == asset_key:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("catalog_variant_smoke failed: %s" % message)
