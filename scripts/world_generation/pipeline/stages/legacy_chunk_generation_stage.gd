extends GenerationStage

class_name LegacyChunkGenerationStage

const STAGE_ID := "legacy_chunk_generation_stage"
const PRIVATE_LEGACY_METHOD := "_generate_legacy_chunk_generation_result"
const PUBLIC_COMPATIBILITY_METHOD := "generate_chunk_generation_result"
const SEMANTIC_WORLD_LAYER_SET_KEY := "semantic_world_layer_set"
const SEMANTIC_LEGACY_TERRAIN_LAYER_KEY := "semantic_legacy_terrain_cells"
const WorldLayerSetScript := preload("res://scripts/world_generation/layers/world_layer_set.gd")
const WorldFeatureSetScript := preload("res://scripts/world_generation/features/world_feature_set.gd")
const ContinuityFactSetScript := preload("res://scripts/world_generation/continuity/continuity_fact_set.gd")
const PlacementCandidateSetScript := preload("res://scripts/world_generation/placement/placement_candidate_set.gd")
const TopologyProjectionSetScript := preload("res://scripts/world_generation/topology/topology_projection_set.gd")

var provider: Object = null


static func from_provider(p_provider: Object) -> LegacyChunkGenerationStage:
	var stage := LegacyChunkGenerationStage.new()
	return stage.configure_for_provider(p_provider)


func configure_for_provider(p_provider: Object) -> LegacyChunkGenerationStage:
	provider = p_provider
	configure(STAGE_ID, GenerationStage.CATEGORY_LAYER, true, {"compatibility_mode": true})
	return self


func duplicate_stage() -> GenerationStage:
	return LegacyChunkGenerationStage.from_provider(provider)


func can_run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> bool:
	return super.can_run(snapshot, context, working_set) \
		and provider != null \
		and _legacy_method_name() != ""


func _run(
	_snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> GenerationStageResult:
	if provider == null:
		return GenerationStageResult.failed(stage_id, stage_category, "missing_legacy_provider")

	var method_name := _legacy_method_name()
	if method_name.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "missing_legacy_generation_method")

	var called_result: Variant = provider.call(method_name, context.chunk_coord)
	if typeof(called_result) != TYPE_DICTIONARY:
		return GenerationStageResult.failed(stage_id, stage_category, "legacy_generation_result_not_dictionary")

	var generation_result: Dictionary = called_result
	if generation_result.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "empty_legacy_generation_result")

	var normalized_result := GeneratedChunkDataAdapter.normalize_generation_result(generation_result)
	normalized_result["topology_layers"] = _filter_requested_topology_layers(
		_snapshot,
		normalized_result.get("topology_layers", {})
	)
	var internal_result := GeneratedChunkDataAdapter.generation_result_without_logic_grid_alias(normalized_result)
	if not _has_required_compatibility_shape(internal_result):
		return GenerationStageResult.failed(stage_id, stage_category, "invalid_legacy_generation_result_shape")

	var context_bounds := _context_bounds(context)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_PRODUCTS,
		GeneratedWorldChunk.LEGACY_GENERATION_RESULT_KEY,
		internal_result
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_LAYERS,
		"legacy_terrain_cells",
		internal_result.get("terrain_cells", [])
	)

	var semantic_layer_set := WorldLayerSetScript.from_legacy_generation_result(
		internal_result,
		context_bounds,
		context.domain_descriptor
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_LAYERS,
		SEMANTIC_WORLD_LAYER_SET_KEY,
		semantic_layer_set.to_dictionary()
	)
	var semantic_legacy_terrain_layer: RefCounted = semantic_layer_set.get_layer(WorldLayerSetScript.LEGACY_TERRAIN_LAYER_ID)
	if semantic_legacy_terrain_layer != null:
		working_set.set_store_value(
			GenerationWorkingSet.STORE_LAYERS,
			SEMANTIC_LEGACY_TERRAIN_LAYER_KEY,
			semantic_legacy_terrain_layer.to_dictionary()
		)

	var debug_markers: Array = internal_result.get("debug_markers", [])
	working_set.set_store_value(
		GenerationWorkingSet.STORE_FEATURES,
		"legacy_debug_markers",
		debug_markers
	)
	var world_feature_set := WorldFeatureSetScript.from_legacy_debug_markers(
		debug_markers,
		context_bounds
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_FEATURES,
		GeneratedWorldChunk.WORLD_FEATURE_SET_KEY,
		world_feature_set.to_dictionary()
	)
	var continuity_fact_set := ContinuityFactSetScript.from_context_bounds(context_bounds)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_CONTINUITY,
		GeneratedWorldChunk.CONTINUITY_FACT_SET_KEY,
		continuity_fact_set.to_dictionary()
	)
	var placement_candidate_set := PlacementCandidateSetScript.from_legacy_debug_markers(
		debug_markers,
		context_bounds
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_PLACEMENT,
		GeneratedWorldChunk.PLACEMENT_CANDIDATE_SET_KEY,
		placement_candidate_set.to_dictionary()
	)

	var topology_layers: Dictionary = internal_result.get("topology_layers", {})
	var topology_projection_set := TopologyProjectionSetScript.from_legacy_topology_layers(
		topology_layers,
		context_bounds,
		context.domain_descriptor
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_PRODUCTS,
		GeneratedWorldChunk.TOPOLOGY_PROJECTION_SET_KEY,
		topology_projection_set.to_dictionary()
	)
	for layer_id in topology_layers.keys():
		working_set.set_store_value(
			GenerationWorkingSet.STORE_TOPOLOGY,
			String(layer_id),
			topology_layers[layer_id]
		)

	var diagnostics: Dictionary = internal_result.get("diagnostics", {})
	working_set.set_diagnostic("legacy_generator_diagnostics", diagnostics)
	working_set.set_diagnostic("legacy_logic_grid_alias", "adapter.compatibility.logic_grid=topology_projections.solid")
	working_set.set_diagnostic("legacy_provider_method", method_name)

	var result := GenerationStageResult.success(stage_id, stage_category)
	result.increment_emitted_count("legacy_generation_result")
	result.increment_emitted_count("topology_projection_set")
	result.increment_emitted_count("topology_projection", topology_layers.size())
	result.increment_emitted_count("world_layer_set")
	result.increment_emitted_count("world_layer", 1)
	result.increment_emitted_count("world_feature_set", 1)
	result.increment_emitted_count("world_feature", world_feature_set.feature_ids().size())
	result.increment_emitted_count("continuity_fact_set", 1)
	result.increment_emitted_count("continuity_fact", continuity_fact_set.fact_ids().size())
	result.increment_emitted_count("placement_candidate_set", 1)
	result.increment_emitted_count("placement_candidate", placement_candidate_set.candidate_ids().size())
	result.set_diagnostic("logic_grid_alias", "adapter.compatibility.logic_grid=topology_layers.solid")
	result.set_diagnostic("provider_method", method_name)
	result.set_diagnostic("requested_topology_projections", _snapshot.requested_topology_projections.duplicate())
	return result


func _legacy_method_name() -> String:
	if provider == null:
		return ""
	if provider.has_method(PRIVATE_LEGACY_METHOD):
		return PRIVATE_LEGACY_METHOD
	if provider.has_method(PUBLIC_COMPATIBILITY_METHOD):
		return PUBLIC_COMPATIBILITY_METHOD
	return ""


func _has_required_compatibility_shape(generation_result: Dictionary) -> bool:
	return generation_result.has("terrain_cells") \
		and generation_result.has("topology_layers") \
		and generation_result.has("debug_markers") \
		and generation_result.has("diagnostics")


func _filter_requested_topology_layers(
	snapshot: WorldDefinitionSnapshot,
	topology_layers: Dictionary
) -> Dictionary:
	if snapshot == null or snapshot.requested_topology_projections.is_empty():
		return topology_layers
	var filtered: Dictionary = {}
	for projection_id in snapshot.requested_topology_projections:
		var layer_id := String(projection_id)
		if topology_layers.has(layer_id):
			filtered[layer_id] = topology_layers[layer_id]
	return filtered


func _context_bounds(context: GenerationContext) -> Dictionary:
	if context == null:
		return {}
	return {
		"chunk_coord": context.chunk_coord,
		"domain_descriptor": context.domain_descriptor,
		"owned_cell_bounds": context.owned_cell_bounds,
		"sample_cell_bounds": context.sample_cell_bounds,
		"chunk_size_cells": context.chunk_size_cells,
		"halo_cells": context.halo_cells,
	}
