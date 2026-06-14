extends GenerationStage

class_name NativeFormationProductStage

const STAGE_ID := "native_formation_product_stage"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/pipeline/stages/native_formation_product_stage.gd"
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")

var session: Object = null


static func from_session(p_session: Object) -> GenerationStage:
	var stage: GenerationStage = load(SELF_SCRIPT_PATH).new()
	return stage.configure_for_session(p_session)


func configure_for_session(p_session: Object) -> GenerationStage:
	session = p_session
	configure(STAGE_ID, GenerationStage.CATEGORY_FORMATION, true, {"native_backend": "godot_grid"})
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
		and session.has_method("generate_native_formation_layer")


func _run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> GenerationStageResult:
	var topology_selection := _requested_topology_layers_for_formation(snapshot, working_set)
	var missing_dependencies: PackedStringArray = topology_selection.get("missing_dependencies", PackedStringArray())
	if not missing_dependencies.is_empty():
		var missing_result := GenerationStageResult.failed(
			stage_id,
			stage_category,
			"missing_topology_dependency_for_formation"
		)
		missing_result.set_diagnostic("missing_topology_dependencies", missing_dependencies.duplicate())
		return missing_result

	var topology_layers: Dictionary = topology_selection.get("topology_layers", {})
	if topology_layers.is_empty():
		return GenerationStageResult.failed(stage_id, stage_category, "missing_requested_topology_layers_for_formation")

	var formation_start_us := Time.get_ticks_usec()
	var formation_layers: Dictionary = {}
	for layer_id in topology_layers.keys():
		var id := String(layer_id)
		var layer_payload: Variant = session.call(
			"generate_native_formation_layer",
			context.chunk_coord,
			id,
			topology_layers[layer_id]
		)
		if typeof(layer_payload) != TYPE_DICTIONARY:
			return GenerationStageResult.failed(stage_id, stage_category, "native_formation_layer_not_dictionary:%s" % id)
		var layer_data: Dictionary = layer_payload
		if not layer_data.has("formation_grid"):
			return GenerationStageResult.failed(stage_id, stage_category, "native_formation_layer_missing_grid:%s" % id)
		formation_layers[id] = layer_data
	var formation_elapsed_us := Time.get_ticks_usec() - formation_start_us

	var product_start_us := Time.get_ticks_usec()
	var formation_product_set: Dictionary = FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		_context_bounds(context)
	).to_dictionary()
	var product_elapsed_us := Time.get_ticks_usec() - product_start_us

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
		"backend": "godot_grid",
		"requested_formation_products": snapshot.requested_formation_products.duplicate(),
		"formation_product_dependencies": snapshot.formation_product_dependencies.duplicate(true),
		"emitted_formation_product_ids": formation_product_set.get("product_ids", PackedStringArray()),
		"native_formation_us": formation_elapsed_us,
	})

	var result := GenerationStageResult.success(stage_id, stage_category)
	var product_ids: PackedStringArray = formation_product_set.get("product_ids", PackedStringArray())
	result.increment_emitted_count("formation_product_set")
	result.increment_emitted_count("formation_product", product_ids.size())
	result.set_diagnostic("native_formation_us", formation_elapsed_us)
	result.set_diagnostic("formation_product_set_build_us", product_elapsed_us)
	result.set_diagnostic("requested_formation_products", snapshot.requested_formation_products.duplicate())
	result.set_diagnostic("emitted_formation_product_ids", product_ids.duplicate())
	result.set_diagnostic("native_backend", "godot_grid")
	return result


func _requested_topology_layers_for_formation(
	snapshot: WorldDefinitionSnapshot,
	working_set: GenerationWorkingSet
) -> Dictionary:
	var available_layers := _topology_layers_from_projection_set(
		working_set.get_store_value(
			GenerationWorkingSet.STORE_PRODUCTS,
			GeneratedWorldChunk.TOPOLOGY_PROJECTION_SET_KEY,
			{}
		)
	)
	var requested_layer_ids := _requested_layer_ids(snapshot, available_layers)
	var selected: Dictionary = {}
	var missing_dependencies := PackedStringArray()
	for layer_id in requested_layer_ids:
		if available_layers.has(layer_id):
			selected[layer_id] = available_layers[layer_id]
		else:
			missing_dependencies.append(layer_id)
	return {
		"topology_layers": selected,
		"missing_dependencies": missing_dependencies,
	}


func _requested_layer_ids(snapshot: WorldDefinitionSnapshot, available_layers: Dictionary) -> PackedStringArray:
	var seen := {}
	var layer_ids := PackedStringArray()
	if snapshot == null or snapshot.requested_formation_products.is_empty():
		for layer_id in available_layers.keys():
			var available_id := String(layer_id)
			if not seen.has(available_id):
				seen[available_id] = true
				layer_ids.append(available_id)
	else:
		for product_id in snapshot.requested_formation_products:
			var dependencies: PackedStringArray = snapshot.formation_product_dependencies.get(
				String(product_id),
				PackedStringArray()
			)
			if dependencies.is_empty():
				var requested_id := String(product_id)
				if not seen.has(requested_id):
					seen[requested_id] = true
					layer_ids.append(requested_id)
				continue
			for dependency_id in dependencies:
				var id := String(dependency_id)
				if not seen.has(id):
					seen[id] = true
					layer_ids.append(id)
	layer_ids.sort()
	return layer_ids


func _topology_layers_from_projection_set(projection_set_data: Variant) -> Dictionary:
	if typeof(projection_set_data) != TYPE_DICTIONARY:
		return {}
	var projection_set: Dictionary = projection_set_data
	var projections: Variant = projection_set.get("projections", {})
	if typeof(projections) == TYPE_DICTIONARY:
		var topology_layers: Dictionary = {}
		var projection_dictionary: Dictionary = projections
		for projection_id in projection_dictionary.keys():
			var projection_data: Variant = projection_dictionary[projection_id]
			if typeof(projection_data) != TYPE_DICTIONARY:
				continue
			var grid: Variant = projection_data.get("grid", [])
			if typeof(grid) == TYPE_ARRAY:
				topology_layers[String(projection_id)] = grid
		if not topology_layers.is_empty():
			return topology_layers
	var legacy_layers: Variant = projection_set.get("topology_layers", {})
	if typeof(legacy_layers) == TYPE_DICTIONARY:
		return legacy_layers
	return {}


func _context_bounds(context: GenerationContext) -> Dictionary:
	return {
		"chunk_coord": context.chunk_coord,
		"domain_descriptor": context.domain_descriptor,
		"owned_cell_bounds": context.owned_cell_bounds,
		"sample_cell_bounds": context.sample_cell_bounds,
		"chunk_size_cells": context.chunk_size_cells,
		"halo_cells": context.halo_cells,
	}
