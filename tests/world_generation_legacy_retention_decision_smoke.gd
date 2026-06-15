extends SceneTree

const LegacyRetentionDecisionScript := preload("res://scripts/world_generation/legacy/legacy_retention_decision.gd")
const WorldLayerSetScript := preload("res://scripts/world_generation/layers/world_layer_set.gd")
const TopologyProjectionSetScript := preload("res://scripts/world_generation/topology/topology_projection_set.gd")
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")

var failed: bool = false


func _initialize() -> void:
	test_current_gate_marks_legacy_runtime_removal_ready()
	quit(1 if failed else 0)


func test_current_gate_marks_legacy_runtime_removal_ready() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var VisualBuilder := load("res://scripts/chunk_visual_builder.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")
	var provider: Node = Provider.new()
	var visual_builder: RefCounted = VisualBuilder.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
	var chunk_coord := Vector3i(-1, 0, 2)
	var canonical_world_chunk: GeneratedWorldChunk = provider._world_generation_session().generate_world_chunk(
		chunk_coord,
		true,
		true,
		{"diagnostics_enabled": true}
	)
	var canonical_record: Dictionary = canonical_world_chunk.to_canonical_record(true)
	var generated_data: Dictionary = GeneratedChunkDataAdapter.generated_chunk_data_from_world_chunk(
		canonical_world_chunk,
		{},
		provider.generation_diagnostics()
	)
	var canonical_formation_layers: Dictionary = canonical_record.get("formation_products", {}).get("formation_layers", {})
	var criteria := {
		"semantic_layer_adapter_parity_proven": not generated_data.get("terrain_cells", []).is_empty(),
			"topology_projection_adapter_parity_proven": (
				_variant_signature(canonical_record.get("topology_layers", {}))
				== _variant_signature(generated_data.get("topology_layers", {}))
				and _variant_signature(canonical_record.get("topology_layers", {}).get("solid", []))
				== _variant_signature(generated_data.get("logic_grid", []))
			),
		"formation_product_adapter_parity_proven": (
			_variant_signature(canonical_formation_layers)
			== _variant_signature(generated_data.get("formation_layers", {}))
			and _variant_signature(canonical_formation_layers.get("solid", {}).get("formation_grid", []))
			== _variant_signature(generated_data.get("formation_grid", []))
		),
		"host_adapter_product_consumption_proven": _host_adapter_contracts_are_non_authoritative(
			visual_builder,
			collision_builder
		),
		"compatibility_output_preserved": _has_required_generated_chunk_data_shape(generated_data),
		"replacement_generation_authority_proven": _canonical_record_is_runtime_authority(canonical_record),
		"legacy_stage_dependency_removed": _runtime_pipeline_excludes_legacy_stage(provider),
		"legacy_wrapper_dependency_removed": _legacy_wrappers_fail_with_migration_errors(provider, chunk_coord),
	}
	var decision: RefCounted = LegacyRetentionDecisionScript.from_criteria(
		criteria,
		{
			"authority": "world_generation_legacy_retention_decision_smoke",
			"chunk_coord": chunk_coord,
		}
	)
	var decision_data: Dictionary = decision.to_dictionary()

	_assert(canonical_world_chunk.legacy_generation_result.is_empty(), "canonical world chunk omits legacy_generation_result")
	_assert(bool(criteria["semantic_layer_adapter_parity_proven"]), "semantic layer adapter parity is proven")
	_assert(bool(criteria["topology_projection_adapter_parity_proven"]), "topology projection adapter parity is proven")
	_assert(bool(criteria["formation_product_adapter_parity_proven"]), "formation product adapter parity is proven")
	_assert(bool(criteria["host_adapter_product_consumption_proven"]), "host adapter product consumption is proven")
	_assert(bool(criteria["compatibility_output_preserved"]), "compatibility output is preserved")
	_assert(bool(criteria["replacement_generation_authority_proven"]), "replacement generation authority is proven")
	_assert(bool(criteria["legacy_stage_dependency_removed"]), "legacy stage dependency is removed")
	_assert(bool(criteria["legacy_wrapper_dependency_removed"]), "legacy wrappers fail with migration errors")
	_assert(decision.is_valid(), "legacy retention decision is valid")
	_assert(
		decision.decision == LegacyRetentionDecisionScript.DECISION_ELIGIBLE_FOR_EXPLICIT_REMOVAL_REVIEW,
		"legacy retention gate marks removal review ready"
	)
	_assert(decision.removal_allowed, "legacy removal is allowed by current gate")
	_assert(decision.blocking_criteria_ids.is_empty(), "decision has no legacy removal blockers")
	_assert(
		decision.signature_hash() == decision.duplicate_decision().signature_hash(),
		"legacy retention decision signature is deterministic"
	)
	_assert(
		decision_data.get("product_type", "") == LegacyRetentionDecisionScript.PRODUCT_TYPE,
		"legacy retention decision dictionary is typed"
	)

	provider.free()


func _canonical_record_is_runtime_authority(canonical_record: Dictionary) -> bool:
	return canonical_record.get("product_type", "") == GeneratedWorldChunk.CANONICAL_RECORD_PRODUCT_TYPE \
		and canonical_record.has("truth_signature_hash") \
		and canonical_record.has("product_signatures") \
		and not canonical_record.get("topology_layers", {}).is_empty() \
		and not canonical_record.get("formation_products", {}).get("formation_layers", {}).is_empty()


func _legacy_wrappers_fail_with_migration_errors(provider: Node, chunk_coord: Vector3i) -> bool:
	var public_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var legacy_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
	return public_result.get("error", "") == "legacy_generation_runtime_removed" \
		and legacy_result.get("error", "") == "legacy_generation_runtime_removed"


func _runtime_pipeline_excludes_legacy_stage(provider: Node) -> bool:
	var definition: WorldDefinition = provider._world_definition_for_generation()
	return not definition.stage_ids.has(LegacyChunkGenerationStage.STAGE_ID)


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
		and _array_has(visual_contract.get("consumes", PackedStringArray()), "GeneratedWorldChunkRecord.formation_products") \
		and _array_has(collision_contract.get("consumes", PackedStringArray()), "GeneratedWorldChunkRecord.topology_layers.solid")


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
