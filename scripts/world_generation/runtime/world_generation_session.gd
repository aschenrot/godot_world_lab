extends RefCounted

class_name WorldGenerationSession

const TERRAIN_AUTHORITY := "local_lab_only"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]
const SELF_SCRIPT_PATH := "res://scripts/world_generation/runtime/world_generation_session.gd"
const LegacyChunkGeneratorScript := preload("res://scripts/world_generation/legacy/legacy_chunk_generator.gd")
const LegacyFormationProductStageScript := preload("res://scripts/world_generation/pipeline/stages/legacy_formation_product_stage.gd")

var settings: Dictionary = {}
var settings_hash: int = 0
var legacy_stage_provider: Object = null
var full_generation_call_count: int = 0
var topology_only_generation_call_count: int = 0

var _snapshot_cache: Dictionary = {}
var _legacy_generator_cache: Dictionary = {}
var _pipeline_cache: Dictionary = {}


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
	definition.world_definition_id = "godot_lab_legacy_provider"
	definition.world_definition_version = _int_setting("generator_version", 2)
	definition.world_seed = _int_setting("world_seed", 1337)
	definition.domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	definition.generation_settings = settings.duplicate(true)
	definition.stage_ids = PackedStringArray([
		LegacyChunkGenerationStage.STAGE_ID,
		LegacyFormationProductStageScript.STAGE_ID,
	])
	definition.layer_schema_ids = PackedStringArray([
		LAYER_GROUND,
		LAYER_WATER,
		LAYER_SOLID,
		LAYER_CLIFF,
	])
	definition.feature_schema_ids = PackedStringArray(["legacy_debug_markers"])
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
		var stage_provider: Object = legacy_stage_provider if legacy_stage_provider != null else self
		_pipeline_cache[settings_hash] = GenerationPipeline.from_stages([
			LegacyChunkGenerationStage.from_provider(stage_provider),
			LegacyFormationProductStageScript.from_session(self)
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
	full_generation_call_count += 1
	var world_chunk := generate_world_chunk(
		chunk_coord,
		copy_output,
		include_stage_results,
		debug_flags
	)
	return GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk, copy_output)


func legacy_chunk_generator() -> RefCounted:
	if not _legacy_generator_cache.has(settings_hash):
		_legacy_generator_cache[settings_hash] = LegacyChunkGeneratorScript.from_settings(settings)
	return _legacy_generator_cache[settings_hash]


func legacy_generator_instance_id() -> int:
	return legacy_chunk_generator().get_instance_id()


func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	return legacy_chunk_generator().generate_chunk_generation_result(chunk_coord)


func generate_topology_layers_only(chunk_coord: Vector3i) -> Dictionary:
	topology_only_generation_call_count += 1
	if legacy_chunk_generator().has_method("generate_topology_layers_only"):
		return legacy_chunk_generator().generate_topology_layers_only(chunk_coord)
	var result: Dictionary = legacy_chunk_generator().generate_chunk_generation_result(chunk_coord)
	return result.get("topology_layers", {})


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
	return legacy_chunk_generator().generate_base_terrain_cells(chunk_coord, size, solid_layer)


func make_terrain_cell(height_percent: int, liquid: bool, solid: bool) -> Dictionary:
	return legacy_chunk_generator().make_terrain_cell(height_percent, liquid, solid)


func set_cell_flags(cell: Dictionary, liquid: bool, solid: bool, height_percent: int = -1) -> Dictionary:
	return legacy_chunk_generator().set_cell_flags(cell, liquid, solid, height_percent)


func generate_smoothed_solid_layer(chunk_coord: Vector3i, size: int) -> Array:
	return legacy_chunk_generator().generate_smoothed_solid_layer(chunk_coord, size)


func carve_rooms_and_paths(chunk_coord: Vector3i, terrain_cells: Array, debug_markers: Array) -> void:
	legacy_chunk_generator().carve_rooms_and_paths(chunk_coord, terrain_cells, debug_markers)


func repair_walkable_connectivity(terrain_cells: Array, debug_markers: Array) -> void:
	legacy_chunk_generator().repair_walkable_connectivity(terrain_cells, debug_markers)


func balance_walkable_percent(terrain_cells: Array, debug_markers: Array) -> void:
	legacy_chunk_generator().balance_walkable_percent(terrain_cells, debug_markers)


func derive_topology_layers(terrain_cells: Array) -> Dictionary:
	return legacy_chunk_generator().derive_topology_layers(terrain_cells)


func terrain_diagnostics(terrain_cells: Array, topology_layers: Dictionary) -> Dictionary:
	return legacy_chunk_generator().terrain_diagnostics(terrain_cells, topology_layers)


func generation_result_from_logic_grid(logic_grid: Array) -> Dictionary:
	return legacy_chunk_generator().generation_result_from_logic_grid(logic_grid)


func topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
	return legacy_chunk_generator().topology_layers_from_logic_grid(logic_grid)


func terrain_cells_from_logic_grid(logic_grid: Array) -> Array:
	return legacy_chunk_generator().terrain_cells_from_logic_grid(logic_grid)


func ordered_layer_ids(topology_layers: Dictionary) -> Array:
	return legacy_chunk_generator().ordered_layer_ids(topology_layers)


func effective_chunk_size_cells() -> int:
	return maxi(_int_setting("effective_chunk_size_cells", _int_setting("chunk_size_cells", 16)), 4)


func _int_setting(key: String, default_value: int) -> int:
	return int(settings.get(key, default_value))


func _float_setting(key: String, default_value: float) -> float:
	return float(settings.get(key, default_value))
