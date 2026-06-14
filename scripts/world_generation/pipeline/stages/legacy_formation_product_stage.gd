extends GenerationStage

class_name LegacyFormationProductStage

const STAGE_ID := "legacy_formation_product_stage"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/pipeline/stages/legacy_formation_product_stage.gd"
const FormationHaloSamplerScript := preload("res://scripts/world_generation/formation/formation_halo_sampler.gd")
const FormationLayerBuilderScript := preload("res://scripts/world_generation/formation/formation_layer_builder.gd")
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")

var session: Object = null


static func from_session(p_session: Object) -> GenerationStage:
	var stage: GenerationStage = load(SELF_SCRIPT_PATH).new()
	return stage.configure_for_session(p_session)


func configure_for_session(p_session: Object) -> GenerationStage:
	session = p_session
	configure(STAGE_ID, GenerationStage.CATEGORY_FORMATION, true, {"compatibility_mode": true})
	return self


func duplicate_stage() -> GenerationStage:
	return load(SELF_SCRIPT_PATH).from_session(session)


func can_run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> bool:
	return super.can_run(snapshot, context, working_set) \
		and session != null \
		and session.has_method("identity_for_chunk") \
		and session.has_method("generate_topology_layers_only") \
		and session.has_method("effective_chunk_size_cells")


func _run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> GenerationStageResult:
	var topology_layers := _requested_topology_layers_for_formation(snapshot, working_set)
	if topology_layers.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "missing_requested_topology_layers_for_formation")

	var sampling_context := _formation_sampling_context()
	var sampler: RefCounted = FormationHaloSamplerScript.from_context(
		session,
		context.chunk_size_cells,
		sampling_context.get("loaded_chunks", {}),
		sampling_context.get("chunk_cache", null),
		bool(sampling_context.get("use_chunk_cache", false)),
		sampling_context.get("sample_cache", {})
	)
	var builder: RefCounted = FormationLayerBuilderScript.from_sampler(session, sampler)
	var formation_layers: Dictionary = builder.make_formation_layers(context.chunk_coord, topology_layers)
	var formation_product_set: Dictionary = FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		_context_bounds(context)
	).to_dictionary()

	working_set.set_store_value(
		GenerationWorkingSet.STORE_FORMATION,
		GeneratedWorldChunk.FORMATION_PRODUCT_SET_KEY,
		formation_product_set
	)
	working_set.set_store_value(
		GenerationWorkingSet.STORE_PRODUCTS,
		GeneratedWorldChunk.FORMATION_PRODUCT_SET_KEY,
		formation_product_set
	)
	working_set.set_diagnostic("formation_product_stage", {
		"requested_formation_products": snapshot.requested_formation_products.duplicate(),
		"emitted_formation_product_ids": formation_product_set.get("product_ids", PackedStringArray()),
		"topology_only_neighbor_generations": int(sampler.get("topology_only_fallback_count")),
		"full_neighbor_generations": int(sampler.get("full_neighbor_generation_count")),
	})

	var result := GenerationStageResult.success(stage_id, stage_category)
	var product_ids: PackedStringArray = formation_product_set.get("product_ids", PackedStringArray())
	result.increment_emitted_count("formation_product_set")
	result.increment_emitted_count("formation_product", product_ids.size())
	result.set_diagnostic("requested_formation_products", snapshot.requested_formation_products.duplicate())
	result.set_diagnostic("emitted_formation_product_ids", product_ids.duplicate())
	result.set_diagnostic("topology_only_neighbor_generations", int(sampler.get("topology_only_fallback_count")))
	result.set_diagnostic("full_neighbor_generations", int(sampler.get("full_neighbor_generation_count")))
	return result


func _requested_topology_layers_for_formation(
	snapshot: WorldDefinitionSnapshot,
	working_set: GenerationWorkingSet
) -> Dictionary:
	var available_layers: Dictionary = working_set.topology_projections
	var requested_layer_ids := _requested_layer_ids(snapshot.requested_formation_products, available_layers)
	var selected: Dictionary = {}
	for layer_id in requested_layer_ids:
		if available_layers.has(layer_id):
			selected[layer_id] = available_layers[layer_id]
	return selected


func _formation_sampling_context() -> Dictionary:
	if session != null and session.has_method("formation_sampling_context"):
		var context_data: Variant = session.call("formation_sampling_context")
		if typeof(context_data) == TYPE_DICTIONARY:
			return context_data
	return {
		"loaded_chunks": {},
		"chunk_cache": null,
		"use_chunk_cache": false,
		"sample_cache": {},
	}


func _requested_layer_ids(requested_ids: PackedStringArray, available_layers: Dictionary) -> PackedStringArray:
	var layer_ids := PackedStringArray()
	if requested_ids.is_empty():
		for layer_id in available_layers.keys():
			layer_ids.append(String(layer_id))
	else:
		for layer_id in requested_ids:
			layer_ids.append(String(layer_id))
	layer_ids.sort()
	return layer_ids


func _context_bounds(context: GenerationContext) -> Dictionary:
	return {
		"chunk_coord": context.chunk_coord,
		"domain_descriptor": context.domain_descriptor,
		"owned_cell_bounds": context.owned_cell_bounds,
		"sample_cell_bounds": context.sample_cell_bounds,
		"chunk_size_cells": context.chunk_size_cells,
		"halo_cells": context.halo_cells,
	}
