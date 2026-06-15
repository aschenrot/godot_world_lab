extends RefCounted

class_name WorldGenerationSession

const TERRAIN_AUTHORITY := "local_lab_only"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]
const SELF_SCRIPT_PATH := "res://scripts/world_generation/runtime/world_generation_session.gd"
const NativeFormationProductStageScript := preload("res://scripts/world_generation/pipeline/stages/native_formation_product_stage.gd")

var settings: Dictionary = {}
var settings_hash: int = 0
var legacy_stage_provider: Object = null
var full_generation_call_count: int = 0
var topology_only_generation_call_count: int = 0

var _snapshot_cache: Dictionary = {}
var _pipeline_cache: Dictionary = {}
var _native_grid_mapper_cache: Dictionary = {}


static func from_settings(
	p_settings: Dictionary = {},
	p_legacy_stage_provider: Object = null
) -> RefCounted:
	var session: RefCounted = load(SELF_SCRIPT_PATH).new()
	return session.configure(p_settings, p_legacy_stage_provider)


func configure(
	p_settings: Dictionary = {},
	p_legacy_stage_provider: Object = null
) -> RefCounted:
	settings = p_settings.duplicate(true)
	settings_hash = int(settings.get(
		"legacy_provider_generation_settings_hash",
		GeneratedChunkIdentity.stable_hash_variant(settings)
	))
	legacy_stage_provider = p_legacy_stage_provider
	return self


func world_definition() -> WorldDefinition:
	var definition := WorldDefinition.new()
	definition.world_definition_id = "godot_lab_native_provider"
	definition.world_definition_version = _int_setting("generator_version", 2)
	definition.world_seed = _int_setting("world_seed", 1337)
	definition.domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	definition.generation_settings = settings.duplicate(true)
	definition.stage_ids = PackedStringArray([
		NativeChunkGenerationStage.STAGE_ID,
		NativeFormationProductStageScript.STAGE_ID,
	])
	definition.layer_schema_ids = PackedStringArray([
		GeneratedWorldChunk.NATIVE_TERRAIN_CELLS_KEY,
		LAYER_GROUND,
		LAYER_WATER,
		LAYER_SOLID,
		LAYER_CLIFF,
	])
	definition.feature_schema_ids = PackedStringArray([GeneratedWorldChunk.NATIVE_DEBUG_MARKERS_KEY])
	definition.continuity_policy_ids = PackedStringArray()
	definition.requested_topology_projections = PackedStringArray([
		LAYER_GROUND,
		LAYER_WATER,
		LAYER_SOLID,
		LAYER_CLIFF,
	])
	definition.requested_formation_products = PackedStringArray([
		LAYER_GROUND,
		LAYER_WATER,
		LAYER_SOLID,
		LAYER_CLIFF,
	])
	definition.requested_product_set = PackedStringArray([
		GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK,
	])
	return definition


func snapshot() -> WorldDefinitionSnapshot:
	if not _snapshot_cache.has(settings_hash):
		_snapshot_cache[settings_hash] = world_definition().compile_snapshot()
	return _snapshot_cache[settings_hash]


func identity_for_chunk(
	chunk_coord: Vector3i,
	requested_products: PackedStringArray = PackedStringArray()
) -> GeneratedChunkIdentity:
	return snapshot().identity_for_chunk(chunk_coord, requested_products)


func request_for_chunk(
	chunk_coord: Vector3i,
	request_id: int = -1,
	request_kind: String = ChunkGenerationRequest.KIND_LOAD,
	debug_flags: Dictionary = {}
) -> ChunkGenerationRequest:
	return ChunkGenerationRequest.from_provider_request(
		request_id,
		request_kind,
		chunk_coord,
		effective_chunk_size_cells(),
		1,
		snapshot().requested_product_set,
		debug_flags
	)


func context_for_chunk(
	chunk_coord: Vector3i,
	request_id: int = -1,
	request_kind: String = ChunkGenerationRequest.KIND_LOAD,
	debug_flags: Dictionary = {}
) -> GenerationContext:
	return GenerationContext.from_snapshot_and_request(
		snapshot(),
		request_for_chunk(chunk_coord, request_id, request_kind, debug_flags)
	)


func pipeline() -> GenerationPipeline:
	if not _pipeline_cache.has(settings_hash):
		_pipeline_cache[settings_hash] = GenerationPipeline.from_stages([
			NativeChunkGenerationStage.from_session(self),
			NativeFormationProductStageScript.from_session(self)
		])
	return _pipeline_cache[settings_hash]


func run_working_set(
	chunk_coord: Vector3i,
	debug_flags: Dictionary = {}
) -> GenerationWorkingSet:
	var next_snapshot := snapshot()
	var context := context_for_chunk(chunk_coord, -1, ChunkGenerationRequest.KIND_LOAD, debug_flags)
	return pipeline().run(next_snapshot, context)


func generate_world_chunk(
	chunk_coord: Vector3i,
	copy_inputs: bool = true,
	include_stage_results: bool = true,
	debug_flags: Dictionary = {}
) -> GeneratedWorldChunk:
	var working_set := run_working_set(chunk_coord, debug_flags)
	if working_set.has_validation_errors():
		push_error("chunk generation pipeline validation issues: %s" % str(working_set.validation_issues))
	return GeneratedWorldChunk.from_working_set(working_set, copy_inputs, include_stage_results)


func generate_chunk_generation_result(
	chunk_coord: Vector3i,
	copy_output: bool = true,
	include_stage_results: bool = true,
	debug_flags: Dictionary = {}
) -> Dictionary:
	_legacy_runtime_removed("generate_chunk_generation_result", {
		"chunk_coord": chunk_coord,
		"copy_output": copy_output,
		"include_stage_results": include_stage_results,
		"debug_flags": debug_flags,
	})
	return _removed_generation_result("generate_chunk_generation_result")


func legacy_chunk_generator() -> RefCounted:
	_legacy_runtime_removed("legacy_chunk_generator")
	return null


func legacy_generator_instance_id() -> int:
	_legacy_runtime_removed("legacy_generator_instance_id")
	return 0


func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	_legacy_runtime_removed("_generate_legacy_chunk_generation_result", {"chunk_coord": chunk_coord})
	return _removed_generation_result("_generate_legacy_chunk_generation_result")


func generate_topology_layers_only(chunk_coord: Vector3i) -> Dictionary:
	topology_only_generation_call_count += 1
	var payload := generate_native_topology_layers_payload(chunk_coord)
	return payload.get("topology_layers", {})


func generate_native_chunk_payload(chunk_coord: Vector3i) -> Dictionary:
	full_generation_call_count += 1
	var mapper := _native_grid_mapper()
	if mapper == null or not mapper.has_method("generate_lab_chunk_payload"):
		return _native_backend_error("generate_lab_chunk_payload")
	var payload_variant: Variant = mapper.call(
		"generate_lab_chunk_payload",
		chunk_coord,
		_native_settings_dictionary()
	)
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return _native_backend_error("generate_lab_chunk_payload_not_dictionary")
	return payload_variant


func generate_native_chunk_record_payload(
	chunk_coord: Vector3i,
	request_flags: Dictionary = {}
) -> Dictionary:
	full_generation_call_count += 1
	var mapper := _native_grid_mapper()
	if mapper == null:
		return _native_backend_error("generate_lab_chunk_record_payload")
	if mapper.has_method("generate_lab_chunk_record_payload"):
		var payload_variant: Variant = mapper.call(
			"generate_lab_chunk_record_payload",
			chunk_coord,
			_native_settings_dictionary(),
			request_flags
		)
		if typeof(payload_variant) != TYPE_DICTIONARY:
			return _native_backend_error("generate_lab_chunk_record_payload_not_dictionary")
		return payload_variant
	if not mapper.has_method("generate_lab_chunk_payload"):
		return _native_backend_error("generate_lab_chunk_record_payload")
	var fallback_payload: Variant = mapper.call(
		"generate_lab_chunk_payload",
		chunk_coord,
		_native_settings_dictionary()
	)
	if typeof(fallback_payload) != TYPE_DICTIONARY:
		return _native_backend_error("generate_lab_chunk_payload_not_dictionary")
	return fallback_payload


func generate_native_topology_layers_payload(chunk_coord: Vector3i) -> Dictionary:
	var mapper := _native_grid_mapper()
	if mapper == null or not mapper.has_method("generate_lab_topology_layers_payload"):
		return _native_backend_error("generate_lab_topology_layers_payload")
	var payload_variant: Variant = mapper.call(
		"generate_lab_topology_layers_payload",
		chunk_coord,
		_native_settings_dictionary()
	)
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return _native_backend_error("generate_lab_topology_layers_payload_not_dictionary")
	return payload_variant


func generate_native_formation_layer(
	chunk_coord: Vector3i,
	layer_id: String,
	layer_grid: Array
) -> Dictionary:
	var mapper := _native_grid_mapper()
	if mapper == null or not mapper.has_method("formation_layer_payload"):
		return _native_backend_error("formation_layer_payload")
	var payload_variant: Variant = mapper.call(
		"formation_layer_payload",
		chunk_coord,
		_native_settings_dictionary(),
		layer_id,
		layer_grid
	)
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return _native_backend_error("formation_layer_payload_not_dictionary")
	return payload_variant


func generate_native_formation_layers(
	chunk_coord: Vector3i,
	topology_layers: Dictionary,
	requested_layer_ids: PackedStringArray
) -> Dictionary:
	var mapper := _native_grid_mapper()
	if mapper != null and mapper.has_method("formation_layers_payload"):
		var requested_array: Array = []
		for layer_id in requested_layer_ids:
			requested_array.append(String(layer_id))
		var payload_variant: Variant = mapper.call(
			"formation_layers_payload",
			chunk_coord,
			_native_settings_dictionary(),
			topology_layers,
			requested_array
		)
		if typeof(payload_variant) != TYPE_DICTIONARY:
			return _native_backend_error("formation_layers_payload_not_dictionary")
		return payload_variant

	var formation_layers: Dictionary = {}
	for layer_id in requested_layer_ids:
		var id := String(layer_id)
		if not topology_layers.has(id):
			continue
		var layer_payload := generate_native_formation_layer(chunk_coord, id, topology_layers[id])
		if layer_payload.has("formation_grid"):
			formation_layers[id] = layer_payload
	return {
		"product_type": "NativeFormationLayersPayload",
		"formation_layers": formation_layers,
		"diagnostics": {
			"authority": "native_grid_generation",
			"formation_mode": "owned_halo_native_per_layer_fallback",
			"layer_count": formation_layers.size(),
			"neighbor_generation_count": -1,
		},
	}


func native_generation_available() -> bool:
	var mapper := _native_grid_mapper()
	return mapper != null \
		and (mapper.has_method("generate_lab_chunk_record_payload") or mapper.has_method("generate_lab_chunk_payload")) \
		and mapper.has_method("generate_lab_topology_layers_payload") \
		and (mapper.has_method("formation_layers_payload") or mapper.has_method("formation_layer_payload"))


func formation_sampling_context() -> Dictionary:
	if legacy_stage_provider != null and legacy_stage_provider.has_method("formation_sampling_context"):
		var context_data: Variant = legacy_stage_provider.call("formation_sampling_context")
		if typeof(context_data) == TYPE_DICTIONARY:
			return context_data
	return {
		"loaded_chunks": {},
		"chunk_cache": null,
		"use_chunk_cache": false,
		"sample_cache": {},
	}


func bounds_for_chunk(chunk_coord: Vector3i) -> Dictionary:
	var world_space := WorldSpace.from_parts(
		effective_chunk_size_cells(),
		1,
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	return {
		"chunk_coord": chunk_coord,
		"domain_descriptor": WorldSpace.DOMAIN_CELL_GRID_2D,
		"owned_cell_bounds": world_space.owned_cell_bounds_for_chunk(chunk_coord),
		"sample_cell_bounds": world_space.sample_cell_bounds_for_chunk(chunk_coord),
		"chunk_size_cells": effective_chunk_size_cells(),
		"halo_cells": 1,
	}


func generation_diagnostics() -> Dictionary:
	return {
		"authority": TERRAIN_AUTHORITY,
		"backend": "godot_grid",
		"world_seed": _int_setting("world_seed", 1337),
		"generator_version": _int_setting("generator_version", 2),
		"chunk_size_cells": _int_setting("chunk_size_cells", 16),
		"effective_chunk_size_cells": effective_chunk_size_cells(),
		"wall_threshold_percent": _int_setting("wall_threshold_percent", 16),
		"debug_force_chunk_border": bool(settings.get("debug_force_chunk_border", false)),
		"smoothing_passes": _int_setting("smoothing_passes", 1),
		"room_attempts": _int_setting("room_attempts", 3),
		"room_min_size": _int_setting("room_min_size", 3),
		"room_max_size": _int_setting("room_max_size", 6),
		"terrain_noise_frequency": _float_setting("terrain_noise_frequency", 0.065),
		"liquid_noise_frequency": _float_setting("liquid_noise_frequency", 0.045),
		"solid_noise_frequency": _float_setting("solid_noise_frequency", 0.09),
		"liquid_threshold_percent": _int_setting("liquid_threshold_percent", 35),
		"target_walkable_min_percent": _int_setting("target_walkable_min_percent", 70),
		"target_walkable_max_percent": _int_setting("target_walkable_max_percent", 80),
		"liquid_blocks_movement": bool(settings.get("liquid_blocks_movement", true)),
		"debug_generation_markers_enabled": bool(settings.get("debug_generation_markers_enabled", true)),
		"generation_settings_hash": settings_hash,
	}


func generate_base_terrain_cells(chunk_coord: Vector3i, size: int, solid_layer: Array) -> Array:
	_legacy_runtime_removed("generate_base_terrain_cells", {"chunk_coord": chunk_coord, "size": size, "solid_layer_size": solid_layer.size()})
	return []


func make_terrain_cell(height_percent: int, liquid: bool, solid: bool) -> Dictionary:
	_legacy_runtime_removed("make_terrain_cell", {"height_percent": height_percent, "liquid": liquid, "solid": solid})
	return {}


func set_cell_flags(cell: Dictionary, liquid: bool, solid: bool, height_percent: int = -1) -> Dictionary:
	_legacy_runtime_removed("set_cell_flags", {"liquid": liquid, "solid": solid, "height_percent": height_percent})
	return cell.duplicate(true)


func generate_smoothed_solid_layer(chunk_coord: Vector3i, size: int) -> Array:
	_legacy_runtime_removed("generate_smoothed_solid_layer", {"chunk_coord": chunk_coord, "size": size})
	return []


func carve_rooms_and_paths(chunk_coord: Vector3i, terrain_cells: Array, debug_markers: Array) -> void:
	_legacy_runtime_removed("carve_rooms_and_paths", {"chunk_coord": chunk_coord})


func repair_walkable_connectivity(terrain_cells: Array, debug_markers: Array) -> void:
	_legacy_runtime_removed("repair_walkable_connectivity", {"terrain_cell_rows": terrain_cells.size(), "debug_marker_count": debug_markers.size()})


func balance_walkable_percent(terrain_cells: Array, debug_markers: Array) -> void:
	_legacy_runtime_removed("balance_walkable_percent", {"terrain_cell_rows": terrain_cells.size(), "debug_marker_count": debug_markers.size()})


func derive_topology_layers(terrain_cells: Array) -> Dictionary:
	_legacy_runtime_removed("derive_topology_layers", {"terrain_cell_rows": terrain_cells.size()})
	return {}


func terrain_diagnostics(terrain_cells: Array, topology_layers: Dictionary) -> Dictionary:
	_legacy_runtime_removed("terrain_diagnostics", {"terrain_cell_rows": terrain_cells.size(), "topology_layer_count": topology_layers.size()})
	return {}


func generation_result_from_logic_grid(logic_grid: Array) -> Dictionary:
	_legacy_runtime_removed("generation_result_from_logic_grid", {"logic_grid_rows": logic_grid.size()})
	return _removed_generation_result("generation_result_from_logic_grid")


func topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
	_legacy_runtime_removed("topology_layers_from_logic_grid", {"logic_grid_rows": logic_grid.size()})
	return {}


func terrain_cells_from_logic_grid(logic_grid: Array) -> Array:
	_legacy_runtime_removed("terrain_cells_from_logic_grid", {"logic_grid_rows": logic_grid.size()})
	return []


func ordered_layer_ids(topology_layers: Dictionary) -> Array:
	var ids := topology_layers.keys()
	ids.sort()
	return ids


func effective_chunk_size_cells() -> int:
	return maxi(_int_setting("effective_chunk_size_cells", _int_setting("chunk_size_cells", 16)), 4)


func _int_setting(key: String, default_value: int) -> int:
	return int(settings.get(key, default_value))


func _float_setting(key: String, default_value: float) -> float:
	return float(settings.get(key, default_value))


func _native_grid_mapper() -> Object:
	if _native_grid_mapper_cache.has(settings_hash):
		return _native_grid_mapper_cache[settings_hash]
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		push_error("godot_grid native backend is unavailable: GodotGridTopologyMapper is not registered")
		return null
	var mapper: Object = ClassDB.instantiate("GodotGridTopologyMapper")
	if mapper == null:
		push_error("godot_grid native backend is unavailable: failed to instantiate GodotGridTopologyMapper")
		return null
	_native_grid_mapper_cache[settings_hash] = mapper
	return mapper


func _native_settings_dictionary() -> Dictionary:
	var native_settings := settings.duplicate(true)
	native_settings["effective_chunk_size_cells"] = effective_chunk_size_cells()
	native_settings["settings_hash"] = settings_hash
	return native_settings


func _native_backend_error(method_name: String) -> Dictionary:
	push_error("godot_grid native backend missing method: %s" % method_name)
	return {
		"error": "native_backend_unavailable",
		"method": method_name,
		"backend": "godot_grid",
	}


func _legacy_runtime_removed(function_name: String, detail: Dictionary = {}) -> void:
	var message := "legacy generation runtime API removed: %s; use generate_world_chunk or native canonical products" % function_name
	if not detail.is_empty():
		message = "%s detail=%s" % [message, str(detail)]
	push_warning(message)


func _removed_generation_result(function_name: String) -> Dictionary:
	return {
		"error": "legacy_generation_runtime_removed",
		"function": function_name,
		"replacement": "generate_world_chunk",
	}
