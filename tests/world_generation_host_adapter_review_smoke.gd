extends SceneTree

var failed: bool = false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		quit(1)
		return

	test_visual_and_collision_adapters_consume_generated_products_without_owning_truth()
	quit(1 if failed else 0)


func test_visual_and_collision_adapters_consume_generated_products_without_owning_truth() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var VisualBuilder := load("res://scripts/chunk_visual_builder.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")
	var provider: Node = Provider.new()
	var visual_builder: RefCounted = VisualBuilder.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
	var catalog: RefCounted = Catalog.new()
	var chunk_coord := Vector3i(2, 0, -3)
	var generation_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var generated_chunk_data: Dictionary = provider.make_generated_chunk_data(
		chunk_coord,
		generation_result["logic_grid"],
		generation_result
	)
	var product_source := generated_chunk_data.duplicate(true)
	product_source.erase("logic_grid")

	_assert(
		product_source.get("product_type", "") == "GeneratedChunkData",
		"host adapter source is GeneratedChunkData"
	)
	_assert(product_source.has("formation_product_set"), "host adapter source carries FormationProductSet")
	_assert(product_source.has("formation_layers"), "host adapter source carries formation compatibility layers")
	_assert(product_source.has("topology_layers"), "host adapter source carries topology compatibility projections")
	_assert(not product_source.has("logic_grid"), "host adapter source can omit logic_grid compatibility alias")

	var visual_contract: Dictionary = visual_builder.host_adapter_contract()
	var collision_contract: Dictionary = collision_builder.host_adapter_contract()
	var visual_plan: Dictionary = visual_builder.build_visual_plan_from_generated_chunk(
		product_source,
		catalog
	)
	var collision_plan: Dictionary = collision_builder.build_collision_plan(
		chunk_coord,
		product_source,
		{"liquid_blocks_movement": provider.liquid_blocks_movement}
	)
	var collision_body: StaticBody3D = collision_builder.build_chunk_collision(
		chunk_coord,
		product_source,
		32.0,
		provider.chunk_size_cells,
		{"liquid_blocks_movement": provider.liquid_blocks_movement}
	)

	_assert(not bool(visual_contract.get("owns_generation_truth", true)), "visual adapter declares no generation ownership")
	_assert(not bool(collision_contract.get("owns_generation_truth", true)), "collision adapter declares no generation ownership")
	_assert(
		visual_plan.get("source_generated_product_type", "") == "GeneratedChunkData",
		"visual plan records GeneratedChunkData as its source product"
	)
	_assert(
		visual_plan.get("source_consumed_fields", PackedStringArray()).has("formation_layers"),
		"visual adapter consumes formation products before topology or logic aliases"
	)
	_assert(
		not _contains_forbidden_generation_payload_key(visual_plan),
		"visual plan does not retain generation truth payloads"
	)
	_assert(
		collision_plan.get("source_product_type", "") == "GeneratedChunkData",
		"collision plan records GeneratedChunkData as its source product"
	)
	_assert(
		collision_plan.get("source_consumed_fields", PackedStringArray()).has("topology_layers.solid"),
		"collision adapter consumes topology product fields"
	)
	_assert(
		not bool(collision_plan.get("diagnostics", {}).get("uses_logic_grid_compatibility_alias", true)),
		"collision adapter does not need logic_grid when topology layers are present"
	)
	_assert(
		not _contains_forbidden_generation_payload_key(collision_plan),
		"collision plan does not retain generation truth payloads"
	)
	_assert(
		not bool(collision_body.get_meta("host_adapter_contract", {}).get("owns_generation_truth", true)),
		"collision realization metadata keeps adapter non-ownership contract"
	)
	_assert(
		int(collision_body.get_meta("collision_shape_count", 0))
		== collision_plan.get("blocking_cells", []).size(),
		"collision realization still matches collision plan"
	)

	collision_body.free()
	provider.free()


func _contains_forbidden_generation_payload_key(value: Variant) -> bool:
	var forbidden_keys := PackedStringArray([
		"legacy_generation_result",
		"world_layers",
		"world_features",
		"continuity_facts",
		"placement_candidates",
		"terrain_cells",
		"topology_layers",
		"topology_projection_set",
		"formation_layers",
		"formation_product_set",
		"logic_grid",
	])
	return _contains_any_key(value, forbidden_keys)


func _contains_any_key(value: Variant, forbidden_keys: PackedStringArray) -> bool:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			for dictionary_key in dictionary_value.keys():
				if forbidden_keys.has(String(dictionary_key)):
					return true
				if _contains_any_key(dictionary_value[dictionary_key], forbidden_keys):
					return true
			return false
		TYPE_ARRAY:
			var array_value: Array = value
			for item in array_value:
				if _contains_any_key(item, forbidden_keys):
					return true
			return false
		_:
			return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("world_generation_host_adapter_review_smoke failed: %s" % message)
