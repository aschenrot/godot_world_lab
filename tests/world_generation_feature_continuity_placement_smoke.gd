extends SceneTree

const CountingProviderScript := preload("res://tests/world_generation_migration_gate_counting_provider.gd")
const WorldFeatureScript := preload("res://scripts/world_generation/features/world_feature.gd")
const WorldFeatureSetScript := preload("res://scripts/world_generation/features/world_feature_set.gd")
const ContinuityFactScript := preload("res://scripts/world_generation/continuity/continuity_fact.gd")
const ContinuityFactSetScript := preload("res://scripts/world_generation/continuity/continuity_fact_set.gd")
const PlacementCandidateScript := preload("res://scripts/world_generation/placement/placement_candidate.gd")
const PlacementCandidateSetScript := preload("res://scripts/world_generation/placement/placement_candidate_set.gd")

var failed: bool = false


func _initialize() -> void:
	test_world_feature_set_from_legacy_debug_markers_is_data_only()
	test_continuity_fact_set_from_context_bounds_is_deterministic()
	test_placement_candidate_set_from_legacy_debug_markers_is_generation_only()
	test_pipeline_carries_feature_continuity_and_placement_sets()
	test_generated_world_chunk_from_legacy_result_populates_product_sets()
	quit(1 if failed else 0)


func test_world_feature_set_from_legacy_debug_markers_is_data_only() -> void:
	var debug_markers := _sample_debug_markers()
	var feature_set: RefCounted = WorldFeatureSetScript.from_legacy_debug_markers(
		debug_markers,
		_sample_bounds()
	)
	var feature_set_data: Dictionary = feature_set.to_dictionary()

	_assert(feature_set.is_valid(), "WorldFeatureSet from legacy debug markers is valid")
	_assert(
		feature_set.feature_ids() == PackedStringArray(["legacy_debug_marker_0000", "legacy_debug_marker_0001"]),
		"WorldFeatureSet feature ids are deterministic"
	)
	_assert(
		int(feature_set.feature_counts_by_kind().get("room", 0)) == 1,
		"WorldFeatureSet counts feature kinds"
	)
	_assert(
		feature_set.features_with_tag(WorldFeatureScript.SOURCE_LEGACY_DEBUG_MARKER).size() == debug_markers.size(),
		"WorldFeatureSet supports tag queries"
	)
	_assert(
		_variant_signature(feature_set.to_legacy_debug_markers()) == _variant_signature(debug_markers),
		"WorldFeatureSet preserves legacy debug marker compatibility data"
	)
	_assert(
		feature_set_data.get("product_type", "") == WorldFeatureSetScript.PRODUCT_TYPE,
		"WorldFeatureSet dictionary reports product type"
	)

	var runtime_feature: RefCounted = WorldFeatureScript.from_parts(
		"runtime_feature",
		"probe",
		{},
		1.0,
		0,
		"smoke",
		{},
		PackedStringArray(),
		{"node": Node.new()}
	)
	_assert(not runtime_feature.is_valid(), "WorldFeature rejects runtime object metadata")
	runtime_feature.metadata["node"].free()


func test_continuity_fact_set_from_context_bounds_is_deterministic() -> void:
	var bounds := _sample_bounds()
	var fact_set: RefCounted = ContinuityFactSetScript.from_context_bounds(bounds)
	var duplicate_fact_set: RefCounted = ContinuityFactSetScript.from_context_bounds(bounds.duplicate(true))

	_assert(fact_set.is_valid(), "ContinuityFactSet from context bounds is valid")
	_assert(
		fact_set.fact_ids() == PackedStringArray([
			"context_chunk_coord",
			"context_halo_cells",
			"context_owned_cell_bounds",
			"context_sample_cell_bounds",
		]),
		"ContinuityFactSet fact ids are sorted deterministically"
	)
	_assert(
		fact_set.signature_hash() == duplicate_fact_set.signature_hash(),
		"ContinuityFactSet signature is deterministic for same context bounds"
	)
	_assert(
		fact_set.facts_for_boundary("owned_cell_bounds").size() == 1,
		"ContinuityFactSet supports boundary queries"
	)
	_assert(
		int(fact_set.fact_counts_by_kind().get("owned_region", 0)) == 1,
		"ContinuityFactSet counts continuity kinds"
	)

	var runtime_fact: RefCounted = ContinuityFactScript.from_parts(
		"runtime_fact",
		"probe",
		"runtime",
		WorldSpace.DOMAIN_CELL_GRID_2D,
		{"node": Node.new()},
		"smoke"
	)
	_assert(not runtime_fact.is_valid(), "ContinuityFact rejects runtime object values")
	runtime_fact.deterministic_value["node"].free()


func test_placement_candidate_set_from_legacy_debug_markers_is_generation_only() -> void:
	var debug_markers := _sample_debug_markers()
	var candidate_set: RefCounted = PlacementCandidateSetScript.from_legacy_debug_markers(
		debug_markers,
		_sample_bounds()
	)
	var candidate_set_data: Dictionary = candidate_set.to_dictionary()

	_assert(candidate_set.is_valid(), "PlacementCandidateSet from legacy debug markers is valid")
	_assert(
		candidate_set.candidate_ids()
		== PackedStringArray(["legacy_debug_marker_candidate_0000", "legacy_debug_marker_candidate_0001"]),
		"PlacementCandidateSet candidate ids are deterministic"
	)
	_assert(
		candidate_set.candidates_with_tag("generation_opportunity").size() == debug_markers.size(),
		"PlacementCandidateSet supports tag queries"
	)
	_assert(
		int(candidate_set.candidate_counts_by_kind().get(
			PlacementCandidateScript.KIND_LEGACY_DEBUG_MARKER_OPPORTUNITY,
			0
		)) == debug_markers.size(),
		"PlacementCandidateSet counts candidate kinds"
	)
	_assert(
		not _contains_forbidden_spawn_key(candidate_set_data),
		"PlacementCandidateSet carries no spawn/ECS ownership keys"
	)

	var runtime_candidate: RefCounted = PlacementCandidateScript.from_parts(
		"runtime_candidate",
		"probe",
		{},
		"",
		0.0,
		{},
		PackedStringArray(),
		{"node": Node.new()}
	)
	_assert(not runtime_candidate.is_valid(), "PlacementCandidate rejects runtime object metadata")
	runtime_candidate.metadata["node"].free()


func test_pipeline_carries_feature_continuity_and_placement_sets() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(1, 0, -1)
	var working_set := _run_pipeline_for_provider(provider, chunk_coord)
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	var legacy_debug_markers: Array = world_chunk.world_features.get("legacy_debug_markers", [])
	var feature_set: Dictionary = world_chunk.world_features.get(GeneratedWorldChunk.WORLD_FEATURE_SET_KEY, {})
	var continuity_fact_set: Dictionary = world_chunk.continuity_facts.get(
		GeneratedWorldChunk.CONTINUITY_FACT_SET_KEY,
		{}
	)
	var placement_candidate_set: Dictionary = world_chunk.placement_candidates.get(
		GeneratedWorldChunk.PLACEMENT_CANDIDATE_SET_KEY,
		{}
	)
	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	var emitted_counts: Dictionary = world_chunk.stage_results[0].get("emitted_fact_counts", {}) \
		if not world_chunk.stage_results.is_empty() else {}

	_assert(not working_set.has_validation_errors(), "pipeline run has no validation errors")
	_assert(
		feature_set.get("product_type", "") == WorldFeatureSetScript.PRODUCT_TYPE,
		"GeneratedWorldChunk carries WorldFeatureSet"
	)
	_assert(
		continuity_fact_set.get("product_type", "") == ContinuityFactSetScript.PRODUCT_TYPE,
		"GeneratedWorldChunk carries ContinuityFactSet"
	)
	_assert(
		placement_candidate_set.get("product_type", "") == PlacementCandidateSetScript.PRODUCT_TYPE,
		"GeneratedWorldChunk carries PlacementCandidateSet"
	)
	_assert(
		int(feature_set.get("feature_count", -1)) == legacy_debug_markers.size(),
		"WorldFeatureSet wraps every legacy debug marker"
	)
	_assert(
		int(placement_candidate_set.get("candidate_count", -1)) == legacy_debug_markers.size(),
		"PlacementCandidateSet wraps every legacy debug marker"
	)
	_assert(
		int(continuity_fact_set.get("fact_count", 0)) >= 4,
		"ContinuityFactSet records context boundary facts"
	)
	_assert(
		_variant_signature(compatibility_result.get("debug_markers", [])) == _variant_signature(legacy_debug_markers),
		"GeneratedChunkDataAdapter keeps legacy debug marker compatibility output"
	)
	_assert(
		int(emitted_counts.get("world_feature", -1)) == legacy_debug_markers.size(),
		"LegacyChunkGenerationStage reports emitted world feature count"
	)
	_assert(
		int(emitted_counts.get("placement_candidate", -1)) == legacy_debug_markers.size(),
		"LegacyChunkGenerationStage reports emitted placement candidate count"
	)
	_assert(
		int(emitted_counts.get("continuity_fact", -1)) >= 4,
		"LegacyChunkGenerationStage reports emitted continuity fact count"
	)
	_assert(
		not _contains_forbidden_spawn_key(placement_candidate_set),
		"pipeline placement candidates remain generation-only data"
	)
	provider.free()


func test_generated_world_chunk_from_legacy_result_populates_product_sets() -> void:
	var generation_result := {
		"terrain_cells": [[{"solid": false, "walkable": true}]],
		"topology_layers": {"solid": [[0]], "ground": [[1]], "water": [[0]], "cliff": [[0]]},
		"logic_grid": [[0]],
		"debug_markers": _sample_debug_markers(),
		"diagnostics": {"authority": "feature_continuity_placement_smoke"},
	}
	var world_chunk := GeneratedWorldChunk.from_legacy_generation_result(
		null,
		_sample_bounds(),
		generation_result
	)

	_assert(
		world_chunk.world_features.has(GeneratedWorldChunk.WORLD_FEATURE_SET_KEY),
		"GeneratedWorldChunk.from_legacy_generation_result populates WorldFeatureSet"
	)
	_assert(
		world_chunk.continuity_facts.has(GeneratedWorldChunk.CONTINUITY_FACT_SET_KEY),
		"GeneratedWorldChunk.from_legacy_generation_result populates ContinuityFactSet"
	)
	_assert(
		world_chunk.placement_candidates.has(GeneratedWorldChunk.PLACEMENT_CANDIDATE_SET_KEY),
		"GeneratedWorldChunk.from_legacy_generation_result populates PlacementCandidateSet"
	)
	_assert(
		not world_chunk.legacy_generation_result.has("logic_grid"),
		"GeneratedWorldChunk.from_legacy_generation_result keeps logic_grid adapter-only"
	)


func _run_pipeline_for_provider(provider: Node, chunk_coord: Vector3i) -> GenerationWorkingSet:
	var definition: WorldDefinition = provider._world_definition_for_generation()
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		16,
		1,
		snapshot.requested_product_set,
		{"feature_continuity_placement_smoke": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var pipeline := GenerationPipeline.from_stages([
		LegacyChunkGenerationStage.from_provider(provider)
	])
	return pipeline.run(snapshot, context)


func _configured_provider() -> Node:
	var provider: Node = CountingProviderScript.new()
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


func _sample_debug_markers() -> Array:
	return [
		{
			"type": "room",
			"chunk_coord": Vector3i(0, 0, 0),
			"rect_position": Vector2i(1, 1),
			"rect_size": Vector2i(3, 4),
			"center": Vector2i(2, 3),
		},
		{
			"type": "path",
			"chunk_coord": Vector3i(0, 0, 0),
			"from": Vector2i(2, 3),
			"to": Vector2i(8, 6),
		},
	]


func _sample_bounds() -> Dictionary:
	return {
		"chunk_coord": Vector3i(0, 0, 0),
		"domain_descriptor": WorldSpace.DOMAIN_CELL_GRID_2D,
		"owned_cell_bounds": Rect2i(Vector2i.ZERO, Vector2i(16, 16)),
		"sample_cell_bounds": Rect2i(Vector2i(-1, -1), Vector2i(18, 18)),
		"chunk_size_cells": 16,
		"halo_cells": 1,
	}


func _contains_forbidden_spawn_key(value: Variant) -> bool:
	var forbidden := PackedStringArray(["spawned_entity", "scene", "node", "ecs"])
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			for key in dictionary_value.keys():
				if forbidden.has(String(key)):
					return true
				if _contains_forbidden_spawn_key(dictionary_value[key]):
					return true
			return false
		TYPE_ARRAY:
			var array_value: Array = value
			for item in array_value:
				if _contains_forbidden_spawn_key(item):
					return true
			return false
		_:
			return false


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_feature_continuity_placement_smoke failed: %s" % message)
