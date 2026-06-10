extends GenerationStage

class_name LegacyChunkGenerationStage

const STAGE_ID := "legacy_chunk_generation_stage"
const LEGACY_METHOD := "_generate_legacy_chunk_generation_result"

var provider: Node = null


static func from_provider(p_provider: Node) -> LegacyChunkGenerationStage:
	var stage := LegacyChunkGenerationStage.new()
	return stage.configure_for_provider(p_provider)


func configure_for_provider(p_provider: Node) -> LegacyChunkGenerationStage:
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
		and provider.has_method(LEGACY_METHOD)


func _run(
	_snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> GenerationStageResult:
	if provider == null:
		return GenerationStageResult.failed(stage_id, stage_category, "missing_legacy_provider")
	if not provider.has_method(LEGACY_METHOD):
		return GenerationStageResult.failed(stage_id, stage_category, "missing_legacy_generation_method")

	var called_result: Variant = provider.call(LEGACY_METHOD, context.chunk_coord)
	if typeof(called_result) != TYPE_DICTIONARY:
		return GenerationStageResult.failed(stage_id, stage_category, "legacy_generation_result_not_dictionary")

	var generation_result: Dictionary = called_result
	if generation_result.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "empty_legacy_generation_result")

	var normalized_result := GeneratedChunkDataAdapter.normalize_generation_result(generation_result)
	if not _has_required_compatibility_shape(normalized_result):
		return GenerationStageResult.failed(stage_id, stage_category, "invalid_legacy_generation_result_shape")

	working_set.set_store_value(
		GenerationWorkingSet.STORE_PRODUCTS,
		GeneratedWorldChunk.LEGACY_GENERATION_RESULT_KEY,
		normalized_result
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_LAYERS,
		"legacy_terrain_cells",
		normalized_result.get("terrain_cells", [])
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_FEATURES,
		"legacy_debug_markers",
		normalized_result.get("debug_markers", [])
	)

	var topology_layers: Dictionary = normalized_result.get("topology_layers", {})
	for layer_id in topology_layers.keys():
		working_set.set_store_value(
			GenerationWorkingSet.STORE_TOPOLOGY,
			String(layer_id),
			topology_layers[layer_id]
		)

	var diagnostics: Dictionary = normalized_result.get("diagnostics", {})
	working_set.set_diagnostic("legacy_generator_diagnostics", diagnostics)
	working_set.set_diagnostic("legacy_logic_grid_alias", "topology_projections.solid")

	var result := GenerationStageResult.success(stage_id, stage_category)
	result.increment_emitted_count("legacy_generation_result")
	result.increment_emitted_count("topology_projection", topology_layers.size())
	result.increment_emitted_count("world_layer", 1)
	result.increment_emitted_count("world_feature_set", 1)
	result.set_diagnostic("logic_grid_alias", "topology_layers.solid")
	return result


func _has_required_compatibility_shape(generation_result: Dictionary) -> bool:
	return generation_result.has("terrain_cells") \
		and generation_result.has("topology_layers") \
		and generation_result.has("logic_grid") \
		and generation_result.has("debug_markers") \
		and generation_result.has("diagnostics")
