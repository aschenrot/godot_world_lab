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
	var product_source: Dictionary = provider._generate_world_chunk_internal(chunk_coord).to_canonical_record(true)

	_assert(
		product_source.get("product_type", "") == GeneratedWorldChunk.CANONICAL_RECORD_PRODUCT_TYPE,
		"host adapter source is canonical GeneratedWorldChunkRecord"
	)
	_assert(product_source.has("formation_products"), "host adapter source carries FormationProductSet")
	_assert(product_source.has("topology_projection_set"), "host adapter source carries topology projection set")
	_assert(product_source.has("topology_layers"), "host adapter source carries compact topology layers")
	_assert(not product_source.has("logic_grid"), "host adapter source omits logic_grid compatibility alias")

	var visual_contract: Dictionary = visual_builder.host_adapter_contract()
	var collision_contract: Dictionary = collision_builder.host_adapter_contract()
	var visual_plan: Dictionary = visual_builder.build_visual_plan_from_canonical_source(
		product_source,
		catalog
	)
	var visual_root: Node3D = visual_builder.build_chunk_visual(
		chunk_coord,
		visual_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
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
		visual_plan.get("source_generated_product_type", "") == GeneratedWorldChunk.CANONICAL_RECORD_PRODUCT_TYPE,
		"visual plan records canonical record as its source product"
	)
	_assert(
		visual_plan.get("source_consumed_fields", PackedStringArray()).has("formation_products"),
		"visual adapter consumes formation products before topology or logic aliases"
	)
	_assert(
		not visual_plan.get("bucket_payloads", []).is_empty(),
		"visual adapter emits packed bucket payloads for runtime realization"
	)
	_assert(
		int(visual_root.get_meta("last_visual_bucket_count", 0))
		== visual_plan.get("bucket_payloads", []).size(),
		"visual realization creates one MultiMesh child per packed bucket"
	)
	_assert(
		not _contains_forbidden_generation_payload_key(visual_plan),
		"visual plan does not retain generation truth payloads"
	)
	_assert(
		collision_plan.get("source_product_type", "") == GeneratedWorldChunk.CANONICAL_RECORD_PRODUCT_TYPE,
		"collision plan records canonical record as its source product"
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
		== collision_plan.get("collision_boxes", collision_plan.get("merged_boxes", [])).size(),
		"collision realization still matches collision plan"
	)

	visual_root.free()
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
