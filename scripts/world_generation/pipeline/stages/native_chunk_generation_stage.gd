extends GenerationStage

class_name NativeChunkGenerationStage

const STAGE_ID := "native_chunk_generation_stage"
const SEMANTIC_WORLD_LAYER_SET_KEY := "semantic_world_layer_set"
const SEMANTIC_NATIVE_TERRAIN_LAYER_KEY := "semantic_native_terrain_cells"
const WorldLayerSetScript := preload("res://scripts/world_generation/layers/world_layer_set.gd")
const WorldFeatureSetScript := preload("res://scripts/world_generation/features/world_feature_set.gd")
const ContinuityFactSetScript := preload("res://scripts/world_generation/continuity/continuity_fact_set.gd")
const PlacementCandidateSetScript := preload("res://scripts/world_generation/placement/placement_candidate_set.gd")
const TopologyProjectionSetScript := preload("res://scripts/world_generation/topology/topology_projection_set.gd")

var session: Object = null


static func from_session(p_session: Object) -> NativeChunkGenerationStage:
	var stage := NativeChunkGenerationStage.new()
	return stage.configure_for_session(p_session)


func configure_for_session(p_session: Object) -> NativeChunkGenerationStage:
	session = p_session
	configure(STAGE_ID, GenerationStage.CATEGORY_LAYER, true, {"native_backend": "godot_grid"})
	return self


func duplicate_stage() -> GenerationStage:
	return NativeChunkGenerationStage.from_session(session)


func can_run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> bool:
	return super.can_run(snapshot, context, working_set) \
		and session != null \
		and session.has_method("generate_native_chunk_payload")


func _run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> GenerationStageResult:
	if session == null:
		return GenerationStageResult.failed(stage_id, stage_category, "missing_native_generation_session")

	var native_start_us := Time.get_ticks_usec()
	var payload_variant: Variant = session.call("generate_native_chunk_payload", context.chunk_coord)
	var native_elapsed_us := Time.get_ticks_usec() - native_start_us
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return GenerationStageResult.failed(stage_id, stage_category, "native_chunk_payload_not_dictionary")

	var payload: Dictionary = payload_variant
	if payload.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "empty_native_chunk_payload")

	var terrain_cells: Array = payload.get("terrain_cells", [])
	var topology_layers: Dictionary = _filter_requested_topology_layers(
		snapshot,
		payload.get("topology_layers", {})
	)
	var debug_markers: Array = payload.get("debug_markers", [])
	var diagnostics: Dictionary = payload.get("diagnostics", {})
	if terrain_cells.is_empty() or topology_layers.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "invalid_native_chunk_payload_shape")

	var context_bounds := _context_bounds(context)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_LAYERS,
		GeneratedWorldChunk.NATIVE_TERRAIN_CELLS_KEY,
		terrain_cells
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_FEATURES,
		GeneratedWorldChunk.NATIVE_DEBUG_MARKERS_KEY,
		debug_markers
	)

	var projection_start_us := Time.get_ticks_usec()
	var topology_projection_set := TopologyProjectionSetScript.from_legacy_topology_layers(
		topology_layers,
		context_bounds,
		context.domain_descriptor,
		{
			"requested_topology_projections": snapshot.requested_topology_projections.duplicate(),
			"internal_required_topology_projections": snapshot.internal_required_topology_projections.duplicate(),
			"requested_formation_products": snapshot.requested_formation_products.duplicate(),
			"formation_product_dependencies": snapshot.formation_product_dependencies.duplicate(true),
			"source": "native_generation",
		}
	)
	var topology_projection_set_data: Dictionary = topology_projection_set.to_dictionary()
	var topology_projection_elapsed_us := Time.get_ticks_usec() - projection_start_us
	working_set.set_store_value(
		GenerationWorkingSet.STORE_PRODUCTS,
		GeneratedWorldChunk.TOPOLOGY_PROJECTION_SET_KEY,
		topology_projection_set_data
	)
	for layer_id in topology_layers.keys():
		working_set.set_store_value(
			GenerationWorkingSet.STORE_TOPOLOGY,
			String(layer_id),
			topology_layers[layer_id]
		)

	var optional_start_us := Time.get_ticks_usec()
	var optional_counts := _emit_optional_report_products(
		context,
		context_bounds,
		terrain_cells,
		debug_markers,
		working_set
	)
	var optional_elapsed_us := Time.get_ticks_usec() - optional_start_us

	working_set.set_diagnostic("native_generator_diagnostics", diagnostics)
	working_set.set_diagnostic("native_backend", "godot_grid")

	var result := GenerationStageResult.success(stage_id, stage_category)
	result.increment_emitted_count("native_terrain_cells")
	result.increment_emitted_count("topology_projection_set")
	result.increment_emitted_count("topology_projection", topology_layers.size())
	for count_id in optional_counts.keys():
		result.increment_emitted_count(String(count_id), int(optional_counts[count_id]))
	result.set_diagnostic("native_generation_us", native_elapsed_us)
	result.set_diagnostic("topology_projection_us", topology_projection_elapsed_us)
	result.set_diagnostic("optional_report_products_us", optional_elapsed_us)
	result.set_diagnostic("requested_topology_projections", snapshot.requested_topology_projections.duplicate())
	result.set_diagnostic("internal_required_topology_projections", snapshot.internal_required_topology_projections.duplicate())
	result.set_diagnostic("native_backend", "godot_grid")
	return result


func _emit_optional_report_products(
	context: GenerationContext,
	context_bounds: Dictionary,
	terrain_cells: Array,
	debug_markers: Array,
	working_set: GenerationWorkingSet
) -> Dictionary:
	var counts := {}
	if context == null or working_set == null or not context.wants_report_products():
		return counts

	var compatibility_result := {
		"terrain_cells": terrain_cells,
		"topology_layers": {},
		"debug_markers": debug_markers,
		"diagnostics": {},
	}
	if context.wants_report_products():
		var semantic_layer_set := WorldLayerSetScript.from_legacy_generation_result(
			compatibility_result,
			context_bounds,
			context.domain_descriptor
		)
		working_set.set_store_value(
			GenerationWorkingSet.STORE_LAYERS,
			SEMANTIC_WORLD_LAYER_SET_KEY,
			semantic_layer_set.to_dictionary()
		)
		var semantic_native_terrain_layer: RefCounted = semantic_layer_set.get_layer(
			WorldLayerSetScript.LEGACY_TERRAIN_LAYER_ID
		)
		if semantic_native_terrain_layer != null:
			working_set.set_store_value(
				GenerationWorkingSet.STORE_LAYERS,
				SEMANTIC_NATIVE_TERRAIN_LAYER_KEY,
				semantic_native_terrain_layer.to_dictionary()
			)
		counts["world_layer_set"] = 1
		counts["world_layer"] = 1

	if context.wants_report_products():
		var world_feature_set := WorldFeatureSetScript.from_legacy_debug_markers(
			debug_markers,
			context_bounds
		)
		working_set.set_store_value(
			GenerationWorkingSet.STORE_FEATURES,
			GeneratedWorldChunk.WORLD_FEATURE_SET_KEY,
			world_feature_set.to_dictionary()
		)
		counts["world_feature_set"] = 1
		counts["world_feature"] = world_feature_set.feature_ids().size()

	if context.wants_report_products():
		var continuity_fact_set := ContinuityFactSetScript.from_context_bounds(context_bounds)
		working_set.set_store_value(
			GenerationWorkingSet.STORE_CONTINUITY,
			GeneratedWorldChunk.CONTINUITY_FACT_SET_KEY,
			continuity_fact_set.to_dictionary()
		)
		counts["continuity_fact_set"] = 1
		counts["continuity_fact"] = continuity_fact_set.fact_ids().size()

	if context.wants_report_products():
		var placement_candidate_set := PlacementCandidateSetScript.from_legacy_debug_markers(
			debug_markers,
			context_bounds
		)
		working_set.set_store_value(
			GenerationWorkingSet.STORE_PLACEMENT,
			GeneratedWorldChunk.PLACEMENT_CANDIDATE_SET_KEY,
			placement_candidate_set.to_dictionary()
		)
		counts["placement_candidate_set"] = 1
		counts["placement_candidate"] = placement_candidate_set.candidate_ids().size()
	return counts


func _filter_requested_topology_layers(
	snapshot: WorldDefinitionSnapshot,
	topology_layers: Dictionary
) -> Dictionary:
	if snapshot == null or snapshot.internal_required_topology_projections.is_empty():
		return topology_layers
	var filtered: Dictionary = {}
	for projection_id in snapshot.internal_required_topology_projections:
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
