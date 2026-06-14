extends SceneTree

const LegacyRetentionDecisionScript := preload("res://scripts/world_generation/legacy/legacy_retention_decision.gd")
const WorldLayerSetScript := preload("res://scripts/world_generation/layers/world_layer_set.gd")
const TopologyProjectionSetScript := preload("res://scripts/world_generation/topology/topology_projection_set.gd")
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")

var failed: bool = false


func _initialize() -> void:
	test_current_gate_retains_legacy_until_replacement_authority_exists()
	quit(1 if failed else 0)


func test_current_gate_retains_legacy_until_replacement_authority_exists() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var VisualBuilder := load("res://scripts/chunk_visual_builder.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")
	var provider: Node = Provider.new()
	var visual_builder: RefCounted = VisualBuilder.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
	var chunk_coord := Vector3i(-1, 0, 2)
	var generation_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var generated_data: Dictionary = provider.make_generated_chunk_data(
		chunk_coord,
		generation_result["logic_grid"],
		generation_result
	)
	var product_only_world_chunk := _world_chunk_from_products_without_legacy(
		provider,
		chunk_coord,
		generation_result
	)
	var product_only_data: Dictionary = GeneratedChunkDataAdapter.generated_chunk_data_from_world_chunk(
		product_only_world_chunk,
		{},
		provider.generation_diagnostics()
	)
	var criteria := {
		"semantic_layer_adapter_parity_proven": (
			_variant_signature(product_only_data.get("terrain_cells", []))
			== _variant_signature(generated_data.get("terrain_cells", []))
		),
		"topology_projection_adapter_parity_proven": (
			_variant_signature(product_only_data.get("topology_layers", {}))
			== _variant_signature(generated_data.get("topology_layers", {}))
			and _variant_signature(product_only_data.get("logic_grid", []))
			== _variant_signature(generated_data.get("logic_grid", []))
		),
		"formation_product_adapter_parity_proven": (
			_variant_signature(product_only_data.get("formation_layers", {}))
			== _variant_signature(generated_data.get("formation_layers", {}))
			and _variant_signature(product_only_data.get("formation_grid", []))
			== _variant_signature(generated_data.get("formation_grid", []))
		),
		"host_adapter_product_consumption_proven": _host_adapter_contracts_are_non_authoritative(
			visual_builder,
			collision_builder
		),
		"compatibility_output_preserved": _has_required_generated_chunk_data_shape(generated_data)
			and _has_required_generated_chunk_data_shape(product_only_data),
		"replacement_generation_authority_proven": false,
		"legacy_stage_dependency_removed": not _legacy_stage_can_still_run(provider, chunk_coord),
		"legacy_wrapper_dependency_removed": not provider.has_method("_generate_legacy_chunk_generation_result"),
	}
	var decision: RefCounted = LegacyRetentionDecisionScript.from_criteria(
		criteria,
		{
			"authority": "world_generation_legacy_retention_decision_smoke",
			"chunk_coord": chunk_coord,
		}
	)
	var decision_data: Dictionary = decision.to_dictionary()

	_assert(product_only_world_chunk.legacy_generation_result.is_empty(), "product-only world chunk omits legacy_generation_result")
	_assert(bool(criteria["semantic_layer_adapter_parity_proven"]), "semantic layer adapter parity is proven")
	_assert(bool(criteria["topology_projection_adapter_parity_proven"]), "topology projection adapter parity is proven")
	_assert(bool(criteria["formation_product_adapter_parity_proven"]), "formation product adapter parity is proven")
	_assert(bool(criteria["host_adapter_product_consumption_proven"]), "host adapter product consumption is proven")
	_assert(bool(criteria["compatibility_output_preserved"]), "compatibility output is preserved")
	_assert(not bool(criteria["replacement_generation_authority_proven"]), "replacement generation authority is not proven")
	_assert(not bool(criteria["legacy_stage_dependency_removed"]), "legacy stage dependency remains")
	_assert(not bool(criteria["legacy_wrapper_dependency_removed"]), "legacy wrapper dependency remains")
	_assert(decision.is_valid(), "legacy retention decision is valid")
	_assert(
		decision.decision == LegacyRetentionDecisionScript.DECISION_RETAIN,
		"legacy retention gate chooses retain"
	)
	_assert(not decision.removal_allowed, "legacy removal is not allowed by current gate")
	_assert(
		decision.blocking_criteria_ids.has("replacement_generation_authority_proven"),
		"decision records missing replacement generation authority blocker"
	)
	_assert(
		decision.blocking_criteria_ids.has("legacy_stage_dependency_removed"),
		"decision records legacy stage dependency blocker"
	)
	_assert(
		decision.blocking_criteria_ids.has("legacy_wrapper_dependency_removed"),
		"decision records legacy wrapper dependency blocker"
	)
	_assert(
		decision.signature_hash() == decision.duplicate_decision().signature_hash(),
		"legacy retention decision signature is deterministic"
	)
	_assert(
		decision_data.get("product_type", "") == LegacyRetentionDecisionScript.PRODUCT_TYPE,
		"legacy retention decision dictionary is typed"
	)

	provider.free()


func _world_chunk_from_products_without_legacy(
	provider: Node,
	chunk_coord: Vector3i,
	generation_result: Dictionary
) -> GeneratedWorldChunk:
	var bounds: Dictionary = provider._world_generation_bounds_for_chunk(chunk_coord)
	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	var formation_layers: Dictionary = provider.make_formation_layers(chunk_coord, topology_layers)
	var semantic_layer_set: Dictionary = WorldLayerSetScript.from_legacy_generation_result(
		generation_result,
		bounds,
		bounds.get("domain_descriptor", WorldSpace.DOMAIN_CELL_GRID_2D)
	).to_dictionary()
	var topology_projection_set: Dictionary = TopologyProjectionSetScript.from_legacy_topology_layers(
		topology_layers,
		bounds,
		bounds.get("domain_descriptor", WorldSpace.DOMAIN_CELL_GRID_2D)
	).to_dictionary()
	var formation_product_set: Dictionary = FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		bounds
	).to_dictionary()
	return GeneratedWorldChunk.new().configure(
		provider._generated_chunk_identity_for_chunk(chunk_coord),
		bounds,
		{LegacyChunkGenerationStage.SEMANTIC_WORLD_LAYER_SET_KEY: semantic_layer_set},
		{"legacy_debug_markers": generation_result.get("debug_markers", [])},
		{},
		{},
		topology_layers,
		topology_projection_set,
		formation_product_set,
		generation_result.get("diagnostics", {}),
		[],
		PackedStringArray(),
		{}
	)


func _legacy_stage_can_still_run(provider: Node, chunk_coord: Vector3i) -> bool:
	var definition: WorldDefinition = provider._world_definition_for_generation()
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		provider.effective_chunk_size_cells(),
		1,
		snapshot.requested_product_set,
		{"legacy_retention_decision_smoke": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var working_set := GenerationWorkingSet.from_snapshot_and_context(snapshot, context)
	return LegacyChunkGenerationStage.from_provider(provider).can_run(snapshot, context, working_set)


func _host_adapter_contracts_are_non_authoritative(
	visual_builder: RefCounted,
	collision_builder: RefCounted
) -> bool:
	var visual_contract: Dictionary = visual_builder.host_adapter_contract()
	var collision_contract: Dictionary = collision_builder.host_adapter_contract()
	return not bool(visual_contract.get("owns_generation_truth", true)) \
		and not bool(collision_contract.get("owns_generation_truth", true)) \
		and _array_has(visual_contract.get("consumes", PackedStringArray()), "GeneratedChunkData.formation_layers") \
		and _array_has(collision_contract.get("consumes", PackedStringArray()), "GeneratedChunkData.topology_layers.solid")


func _has_required_generated_chunk_data_shape(generated_data: Dictionary) -> bool:
	var required_fields := PackedStringArray([
		"terrain_cells",
		"topology_layers",
		"logic_grid",
		"debug_markers",
		"diagnostics",
		"formation_layers",
		"formation_grid",
		"formation_origin_cell",
		"owned_visual_origin",
		"owned_visual_size",
		"formation_mode",
		"source_chunk_coords",
	])
	for field_id in required_fields:
		if not generated_data.has(field_id):
			return false
	return true


func _array_has(values: Variant, target: String) -> bool:
	if typeof(values) == TYPE_PACKED_STRING_ARRAY:
		var packed_values: PackedStringArray = values
		return packed_values.has(target)
	if typeof(values) == TYPE_ARRAY:
		var array_values: Array = values
		return array_values.has(target)
	return false


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_legacy_retention_decision_smoke failed: %s" % message)
