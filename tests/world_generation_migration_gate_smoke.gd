extends SceneTree

const ChunkProviderScript := preload("res://scripts/chunk_provider.gd")
const CountingProviderScript := preload("res://tests/world_generation_migration_gate_counting_provider.gd")

var failed: bool = false


class PrivateLegacyProbeProvider:
	extends Node

	var private_call_count: int = 0
	var public_call_count: int = 0

	func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
		private_call_count += 1
		return _minimal_generation_result(chunk_coord)

	func generate_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
		public_call_count += 1
		return _minimal_generation_result(chunk_coord)

	func _minimal_generation_result(chunk_coord: Vector3i) -> Dictionary:
		var terrain_cells := [
			[
				{"solid": false, "liquid": false, "walkable": true, "surface": "ground", "material": "ground"},
				{"solid": true, "liquid": false, "walkable": false, "surface": "ground", "material": "rock"},
			],
			[
				{"solid": false, "liquid": true, "walkable": false, "surface": "water", "material": "water"},
				{"solid": false, "liquid": false, "walkable": true, "surface": "ground", "material": "ground"},
			],
		]
		var topology_layers := {
			"ground": [[1, 1], [0, 1]],
			"solid": [[0, 1], [0, 0]],
			"water": [[0, 0], [1, 0]],
			"cliff": [[0, 0], [0, 0]],
		}
		return {
			"terrain_cells": terrain_cells,
			"topology_layers": topology_layers,
			"logic_grid": topology_layers["solid"].duplicate(true),
			"debug_markers": [{"type": "probe", "chunk_coord": chunk_coord}],
			"diagnostics": {"authority": "migration_gate_smoke", "chunk_coord": chunk_coord},
		}


func _initialize() -> void:
	test_ordered_hash_changes_when_order_changes()
	test_unordered_hash_does_not_change_when_order_changes()
	test_generated_chunk_identity_requested_products_are_unordered()
	test_world_definition_and_snapshot_hash_semantics_match()
	test_legacy_stage_calls_private_legacy_generation_method()
	test_provider_public_generation_path_routes_through_pipeline()
	test_pipeline_output_finalizes_into_generated_world_chunk()
	test_generated_chunk_data_adapter_preserves_compatibility_fields()
	test_pipeline_routed_generation_matches_old_legacy_generation_for_representative_chunks()
	quit(1 if failed else 0)


func test_ordered_hash_changes_when_order_changes() -> void:
	var a := PackedStringArray(["stage.a", "stage.b", "stage.a"])
	var b := PackedStringArray(["stage.b", "stage.a", "stage.a"])
	_assert(
		GeneratedChunkIdentity.stable_hash_ordered_string_ids(a)
		!= GeneratedChunkIdentity.stable_hash_ordered_string_ids(b),
		"ordered string id hash changes when order changes"
	)


func test_unordered_hash_does_not_change_when_order_changes() -> void:
	var a := PackedStringArray(["projection.solid", "projection.ground", "projection.solid"])
	var b := PackedStringArray(["projection.solid", "projection.solid", "projection.ground"])
	_assert(
		GeneratedChunkIdentity.stable_hash_unordered_string_ids(a)
		== GeneratedChunkIdentity.stable_hash_unordered_string_ids(b),
		"unordered string id hash ignores order while preserving duplicate handling"
	)


func test_generated_chunk_identity_requested_products_are_unordered() -> void:
	var identity_a := GeneratedChunkIdentity.from_parts(
		"identity_hash_smoke_world",
		3,
		101,
		202,
		Vector3i(4, 0, -2),
		PackedStringArray()
	)
	var identity_b := GeneratedChunkIdentity.from_parts(
		"identity_hash_smoke_world",
		3,
		101,
		202,
		Vector3i(4, 0, -2),
		PackedStringArray()
	)
	identity_a.requested_product_set = PackedStringArray([
		"generated_world_chunk",
		"formation_products",
		"generated_world_chunk",
	])
	identity_b.requested_product_set = PackedStringArray([
		"generated_world_chunk",
		"generated_world_chunk",
		"formation_products",
	])
	_assert(
		identity_a.signature_hash() == identity_b.signature_hash(),
		"GeneratedChunkIdentity requested_product_set signature hash ignores order"
	)


func test_world_definition_and_snapshot_hash_semantics_match() -> void:
	var ordered_fields := PackedStringArray([
		"stage_ids",
		"layer_schema_ids",
		"feature_schema_ids",
		"continuity_policy_ids",
	])
	for field_id in ordered_fields:
		var ordered_a := _test_definition()
		var ordered_b := _test_definition()
		ordered_a.set(field_id, PackedStringArray(["%s.a" % field_id, "%s.b" % field_id]))
		ordered_b.set(field_id, PackedStringArray(["%s.b" % field_id, "%s.a" % field_id]))
		_assert(
			ordered_a.definition_hash() != ordered_b.definition_hash(),
			"%s is ordered in WorldDefinition.definition_hash" % field_id
		)
		_assert(
			ordered_a.compile_snapshot().signature_hash()
			!= ordered_b.compile_snapshot().signature_hash(),
			"%s is ordered in WorldDefinitionSnapshot.signature_hash" % field_id
		)

	var unordered_fields := PackedStringArray([
		"requested_topology_projections",
		"requested_formation_products",
		"requested_product_set",
	])
	for field_id in unordered_fields:
		var unordered_a := _test_definition()
		var unordered_b := _test_definition()
		unordered_a.set(field_id, PackedStringArray(["%s.a" % field_id, "%s.b" % field_id, "%s.a" % field_id]))
		unordered_b.set(field_id, PackedStringArray(["%s.b" % field_id, "%s.a" % field_id, "%s.a" % field_id]))
		var snapshot_a := unordered_a.compile_snapshot()
		var snapshot_b := unordered_b.compile_snapshot()
		_assert(
			unordered_a.definition_hash() == unordered_b.definition_hash(),
			"%s is unordered in WorldDefinition.definition_hash" % field_id
		)
		_assert(
			snapshot_a.signature_hash() == snapshot_b.signature_hash(),
			"%s is unordered in WorldDefinitionSnapshot.signature_hash" % field_id
		)
		_assert(
			snapshot_a.world_definition_hash == unordered_a.definition_hash(),
			"%s snapshot keeps compiled definition hash" % field_id
		)


func test_legacy_stage_calls_private_legacy_generation_method() -> void:
	var provider := PrivateLegacyProbeProvider.new()
	var working_set := _run_pipeline_for_provider(provider, Vector3i(2, 0, -3))
	_assert(provider.private_call_count == 1, "legacy stage calls private legacy generation method")
	_assert(provider.public_call_count == 0, "legacy stage avoids public generation method when private method exists")
	_assert(not working_set.has_validation_errors(), "legacy stage pipeline run has no validation errors")
	provider.free()


func test_provider_public_generation_path_routes_through_pipeline() -> void:
	var provider: Node = _configured_provider(CountingProviderScript)
	var result: Dictionary = provider.generate_chunk_generation_result(Vector3i(0, 0, 0))
	_assert(provider.private_legacy_call_count == 1, "provider public path routes through legacy pipeline stage")
	_assert(_has_generation_result_shape(result), "provider public path returns compatibility generation result")
	provider.free()


func test_pipeline_output_finalizes_into_generated_world_chunk() -> void:
	var provider: Node = _configured_provider(ChunkProviderScript)
	var chunk_coord := Vector3i(1, 0, 0)
	var working_set := _run_pipeline_for_provider(provider, chunk_coord)
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	_assert(world_chunk != null, "pipeline finalizes into GeneratedWorldChunk")
	_assert(world_chunk.identity != null, "GeneratedWorldChunk has identity")
	_assert(world_chunk.identity.chunk_coord == chunk_coord, "GeneratedWorldChunk identity keeps chunk coord")
	_assert(not world_chunk.legacy_generation_result.is_empty(), "GeneratedWorldChunk keeps legacy generation result during migration")
	_assert(world_chunk.topology_projections.has("solid"), "GeneratedWorldChunk keeps solid topology projection")
	_assert(world_chunk.stage_results.size() == 1, "GeneratedWorldChunk keeps stage result")
	provider.free()


func test_generated_chunk_data_adapter_preserves_compatibility_fields() -> void:
	var provider: Node = _configured_provider(ChunkProviderScript)
	var chunk_coord := Vector3i(-1, 0, 1)
	var generation_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var generated_data: Dictionary = provider.make_generated_chunk_data(
		chunk_coord,
		generation_result["logic_grid"],
		generation_result
	)
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
		_assert(generated_data.has(field_id), "GeneratedChunkData preserves %s" % field_id)

	_assert(
		_variant_signature(generated_data["logic_grid"])
		== _variant_signature(generated_data["topology_layers"]["solid"]),
		"GeneratedChunkData logic_grid remains solid topology alias"
	)

	var world_chunk: GeneratedWorldChunk = provider._world_chunk_from_compatibility_generation_result(
		chunk_coord,
		generation_result
	)
	var adapter_data := GeneratedChunkDataAdapter.generated_chunk_data_from_world_chunk(
		world_chunk,
		generated_data["formation_layers"],
		provider.generation_diagnostics()
	)
	for field_id in required_fields:
		_assert(
			_variant_signature(adapter_data[field_id]) == _variant_signature(generated_data[field_id]),
			"GeneratedChunkDataAdapter preserves %s without drift" % field_id
		)
	provider.free()


func test_pipeline_routed_generation_matches_old_legacy_generation_for_representative_chunks() -> void:
	var provider: Node = _configured_provider(ChunkProviderScript)
	var representative_chunks: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(-1, 0, 1),
	]
	for chunk_coord in representative_chunks:
		var legacy_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
		var pipeline_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
		_assert(
			_variant_signature(pipeline_result) == _variant_signature(legacy_result),
			"pipeline-routed generation matches legacy generation for %s" % chunk_coord
		)
	provider.free()


func _run_pipeline_for_provider(provider: Node, chunk_coord: Vector3i) -> GenerationWorkingSet:
	var definition: WorldDefinition = provider._world_definition_for_generation() if provider.has_method("_world_definition_for_generation") else _test_definition()
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		16,
		1,
		snapshot.requested_product_set,
		{"smoke_test": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var pipeline := GenerationPipeline.from_stages([
		LegacyChunkGenerationStage.from_provider(provider)
	])
	return pipeline.run(snapshot, context)


func _configured_provider(provider_script: Script) -> Node:
	var provider: Node = provider_script.new()
	provider.chunk_size_cells = 16
	provider.generator_version = 7
	provider.world_seed = 42
	provider.wall_threshold_percent = 34
	provider.debug_force_chunk_border = false
	provider.smoothing_passes = 1
	provider.room_attempts = 3
	provider.room_min_size = 3
	provider.room_max_size = 6
	provider.terrain_noise_frequency = 0.065
	provider.liquid_noise_frequency = 0.045
	provider.solid_noise_frequency = 0.09
	provider.liquid_threshold_percent = 35
	provider.target_walkable_min_percent = 70
	provider.target_walkable_max_percent = 80
	provider.liquid_blocks_movement = true
	provider.debug_generation_markers_enabled = true
	provider.use_chunk_cache = false
	return provider


func _test_definition() -> WorldDefinition:
	var definition := WorldDefinition.new()
	definition.world_definition_id = "migration_gate_smoke_world"
	definition.world_definition_version = 1
	definition.world_seed = 99
	definition.domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	definition.generation_settings = {"mode": "smoke", "threshold": 3}
	definition.stage_ids = PackedStringArray([LegacyChunkGenerationStage.STAGE_ID, "diagnostic.stage"])
	definition.layer_schema_ids = PackedStringArray(["ground", "water", "solid", "cliff"])
	definition.feature_schema_ids = PackedStringArray(["legacy_debug_markers", "walkability_markers"])
	definition.continuity_policy_ids = PackedStringArray(["owned_cells", "sample_halo"])
	definition.requested_topology_projections = PackedStringArray(["ground", "water", "solid", "cliff"])
	definition.requested_formation_products = PackedStringArray(["ground", "water", "solid", "cliff"])
	definition.requested_product_set = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
	return definition


func _has_generation_result_shape(generation_result: Dictionary) -> bool:
	return generation_result.has("terrain_cells") \
		and generation_result.has("topology_layers") \
		and generation_result.has("logic_grid") \
		and generation_result.has("debug_markers") \
		and generation_result.has("diagnostics")


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_migration_gate_smoke failed: %s" % message)
