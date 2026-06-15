extends SceneTree

var failed: bool = false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		quit(1)
		return

	var Provider := load("res://scripts/chunk_provider.gd")
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var provider: Node = Provider.new()
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()
	var chunk_coord := Vector3i(2, 0, -4)
	var generation_result: Dictionary = GeneratedChunkDataAdapter.generation_result_from_world_chunk(
		provider._world_generation_session().generate_world_chunk(
			chunk_coord,
			true,
			true,
			{"diagnostics_enabled": true}
		),
		true
	)
	var logic_grid: Array = generation_result["logic_grid"]

	var generated_data: Dictionary = provider.make_generated_chunk_data(chunk_coord, logic_grid, generation_result)
	_assert(generated_data["product_type"] == "GeneratedChunkData", "generated product is typed")
	_assert(generated_data["authority"] == "godot_grid_native", "generated product is native adapter authority")
	_assert(generated_data["chunk_coord"] == chunk_coord, "generated product keeps chunk coord")
	_assert(generated_data["generator_version"] == provider.generator_version, "generated product keeps generator version")
	_assert(generated_data.has("generation_settings_hash"), "generated product has settings hash")
	_assert(generated_data["logic_grid"].size() == provider.chunk_size_cells, "generated product keeps logic grid")
	_assert(generated_data.has("terrain_cells"), "generated product has terrain cells")
	_assert(generated_data.has("topology_layers"), "generated product has topology layers")
	_assert(generated_data.has("formation_layers"), "generated product has formation layers")
	_assert(_grid_signature(generated_data["logic_grid"]) == _grid_signature(generated_data["topology_layers"]["solid"]), "logic grid aliases solid layer")
	_assert(generated_data["formation_layers"].has("ground"), "ground layer has formation halo")
	_assert(generated_data["formation_layers"].has("water"), "water layer has formation halo")
	_assert(generated_data["formation_layers"].has("solid"), "solid layer has formation halo")

	var visual_plan: Dictionary = builder.build_visual_plan_from_generated_chunk(generated_data, catalog)
	_assert(visual_plan["product_type"] == "ChunkVisualPlan", "visual plan is typed")
	_assert(visual_plan["chunk_coord"] == chunk_coord, "visual plan keeps chunk coord")
	_assert(visual_plan.has("visual_layers"), "visual plan has layer products")
	_assert(visual_plan["visual_layers"].size() >= 3, "visual plan includes terrain layers")
	_assert(visual_plan.has("visual_tiles"), "visual plan has visual tiles")
	_assert(visual_plan.has("asset_keys"), "visual plan has asset keys")
	_assert(visual_plan.has("missing_assets"), "visual plan has missing assets")
	_assert(visual_plan.has("bounds"), "visual plan has bounds")
	_assert(visual_plan.has("diagnostics"), "visual plan has diagnostics")
	_assert(bool(visual_plan["diagnostics"].get("is_valid", false)), "visual plan is valid")

	var instantiation_plan: Dictionary = builder.build_instantiation_plan(
		chunk_coord,
		visual_plan,
		catalog,
		"multimesh"
	)
	_assert(instantiation_plan["product_type"] == "ChunkInstantiationPlan", "instantiation plan is typed")
	_assert(instantiation_plan["chunk_coord"] == chunk_coord, "instantiation plan keeps chunk coord")
	_assert(instantiation_plan["visual_backend"] == "multimesh", "instantiation plan keeps backend")
	_assert(instantiation_plan.has("multimesh_buckets"), "instantiation plan has buckets")
	_assert(instantiation_plan["multimesh_buckets"].has("ground"), "instantiation buckets are keyed by ground layer")
	_assert(instantiation_plan["multimesh_buckets"].has("solid"), "instantiation buckets are keyed by solid layer")
	_assert(instantiation_plan.has("root_metadata"), "instantiation plan has root metadata")
	_assert(instantiation_plan.has("diagnostics"), "instantiation plan has diagnostics")
	_assert(
		int(instantiation_plan["diagnostics"].get("visual_tile_count", -1)) == visual_plan["visual_tiles"].size(),
		"instantiation diagnostics match visual tile count"
	)

	provider.free()
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _grid_signature(grid: Array) -> String:
	var parts: Array[String] = []
	for row in grid:
		var row_parts: Array[String] = []
		for cell in row:
			row_parts.append(str(cell))
		parts.append("".join(row_parts))
	return "|".join(parts)


func _fail(message: String) -> void:
	failed = true
	push_error("formation_products_smoke failed: %s" % message)
