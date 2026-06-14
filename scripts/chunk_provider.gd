extends Node

const TERRAIN_AUTHORITY := "local_lab_only"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]
const FormationHaloSamplerScript := preload("res://scripts/world_generation/formation/formation_halo_sampler.gd")
const FormationLayerBuilderScript := preload("res://scripts/world_generation/formation/formation_layer_builder.gd")
const WorldGenerationSessionScript := preload("res://scripts/world_generation/runtime/world_generation_session.gd")

@export var chunk_size_cells: int = 16
@export var generator_version: int = 2
@export var world_seed: int = 1337
@export_range(0, 100, 1) var wall_threshold_percent: int = 16
@export var debug_force_chunk_border: bool = false
@export_range(0, 4, 1) var smoothing_passes: int = 1
@export_range(0, 8, 1) var room_attempts: int = 3
@export_range(2, 12, 1) var room_min_size: int = 3
@export_range(2, 16, 1) var room_max_size: int = 6
@export var terrain_noise_frequency: float = 0.065
@export var liquid_noise_frequency: float = 0.045
@export var solid_noise_frequency: float = 0.09
@export_range(0, 100, 1) var liquid_threshold_percent: int = 35
@export_range(0, 100, 1) var target_walkable_min_percent: int = 70
@export_range(0, 100, 1) var target_walkable_max_percent: int = 80
@export var liquid_blocks_movement: bool = true
@export var debug_generation_markers_enabled: bool = true
@export var async_provider_enabled: bool = false
@export var provider_delay_frames: int = 0
@export var use_chunk_cache: bool = false

var streaming_node: Node
var pending_requests: Dictionary = {}
var loaded_chunks: Dictionary = {}
var chunk_cache: RefCounted
var completed_load_count: int = 0
var completed_unload_count: int = 0
var cache_hit_count: int = 0
var cache_miss_count: int = 0
var formation_sample_cache: Dictionary = {}
var _world_generation_session_instance: RefCounted = null
var _world_generation_session_hash: int = -1


func _ready() -> void:
	_ensure_cache()


func bind_streaming_node(node: Node) -> void:
	streaming_node = node
	if streaming_node == null:
		return

	streaming_node.chunk_load_requested.connect(_on_chunk_load_requested)
	streaming_node.chunk_unload_requested.connect(_on_chunk_unload_requested)


func _on_chunk_load_requested(request_id: int, x: int, y: int, z: int) -> void:
	if streaming_node == null:
		return
	var chunk_coord := Vector3i(x, y, z)
	_enqueue_request(request_id, "load", chunk_coord)
	streaming_node.provider_started(request_id, x, y, z)
	if not async_provider_enabled:
		_complete_request(request_id)


func _on_chunk_unload_requested(request_id: int, x: int, y: int, z: int) -> void:
	if streaming_node == null:
		return
	var chunk_coord := Vector3i(x, y, z)
	_enqueue_request(request_id, "unload", chunk_coord)
	streaming_node.provider_started(request_id, x, y, z)
	if not async_provider_enabled:
		_complete_request(request_id)


func pending_request_count() -> int:
	return pending_requests.size()


func loaded_chunk_count() -> int:
	return loaded_chunks.size()


func cache_entry_count() -> int:
	if chunk_cache == null:
		return 0
	return chunk_cache.entry_count()


func formation_sample_cache_count() -> int:
	return formation_sample_cache.size()


func get_loaded_chunk_data(chunk_coord: Vector3i) -> Dictionary:
	var record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	var generated_chunk_data: Dictionary = record.get("generated_chunk_data", {})
	return generated_chunk_data.duplicate(true)


func get_loaded_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	var generated_chunk_data := get_loaded_chunk_data(chunk_coord)
	return generated_chunk_data.get("logic_grid", [])


func configure_async_provider(enabled: bool, delay_frames: int) -> void:
	async_provider_enabled = enabled
	provider_delay_frames = maxi(delay_frames, 0)


func configure_chunk_cache(enabled: bool) -> void:
	use_chunk_cache = enabled
	_ensure_cache()


func _process(_delta: float) -> void:
	if not async_provider_enabled:
		return

	var request_ids: Array = pending_requests.keys()
	request_ids.sort()
	for request_id in request_ids:
		var record: Dictionary = pending_requests[request_id]
		record["frames_remaining"] = int(record["frames_remaining"]) - 1
		pending_requests[request_id] = record
		if int(record["frames_remaining"]) <= 0:
			_complete_request(request_id)


func _enqueue_request(request_id: int, kind: String, chunk_coord: Vector3i) -> void:
	pending_requests[request_id] = {
		"kind": kind,
		"chunk": chunk_coord,
		"frames_remaining": maxi(provider_delay_frames, 0),
	}


func _complete_request(request_id: int) -> void:
	if not pending_requests.has(request_id):
		return

	var record: Dictionary = pending_requests[request_id]
	var chunk_coord: Vector3i = record["chunk"]
	var kind: String = record["kind"]

	if kind == "load":
		_load_chunk_content(chunk_coord)
		streaming_node.provider_completed(request_id, chunk_coord.x, chunk_coord.y, chunk_coord.z)
		completed_load_count += 1
	elif kind == "unload":
		loaded_chunks.erase(_chunk_key(chunk_coord))
		streaming_node.provider_completed(request_id, chunk_coord.x, chunk_coord.y, chunk_coord.z)
		completed_unload_count += 1

	pending_requests.erase(request_id)


func _load_chunk_content(chunk_coord: Vector3i) -> void:
	var cache_identity := _generated_chunk_identity_for_chunk(chunk_coord)
	var generation_result := _load_or_generate_chunk_result(chunk_coord, cache_identity)
	var logic_grid := GeneratedChunkDataAdapter.logic_grid_from_generation_result(generation_result, false)
	var generated_chunk_data := make_generated_chunk_data(chunk_coord, logic_grid, generation_result, false)
	loaded_chunks[_chunk_key(chunk_coord)] = {
		"coord": chunk_coord,
		"generator_version": cache_identity.world_definition_version,
		"world_definition_id": cache_identity.world_definition_id,
		"world_definition_hash": cache_identity.world_definition_hash,
		"generation_settings_hash": cache_identity.generation_settings_hash,
		"requested_product_set": cache_identity.requested_product_set.duplicate(),
		"cache_key": cache_identity.cache_key(),
		"generated_chunk_data": generated_chunk_data,
	}


func _load_or_generate_chunk_result(chunk_coord: Vector3i, cache_identity: GeneratedChunkIdentity) -> Dictionary:
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_identity(cache_identity):
			cache_hit_count += 1
			return chunk_cache.load_generation_result_for_identity(cache_identity)

		cache_miss_count += 1
		var generated := _generate_chunk_generation_result_internal(chunk_coord)
		chunk_cache.store_generation_result_for_identity(cache_identity, generated)
		return generated

	return _generate_chunk_generation_result_internal(chunk_coord)


func _ensure_cache() -> void:
	if chunk_cache != null:
		return
	var Cache := load("res://scripts/chunk_cache.gd")
	chunk_cache = Cache.new()


func generate_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	return GeneratedChunkDataAdapter.logic_grid_from_generation_result(generate_chunk_generation_result(chunk_coord))


func generate_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	return _world_generation_session().generate_chunk_generation_result(
		chunk_coord,
		true,
		true,
		{"provider": "chunk_provider", "diagnostics_enabled": true}
	)


func _generate_chunk_generation_result_internal(chunk_coord: Vector3i) -> Dictionary:
	return _world_generation_session().generate_chunk_generation_result(
		chunk_coord,
		false,
		false,
		{"provider": "chunk_provider"}
	)


func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	return _world_generation_session()._generate_legacy_chunk_generation_result(chunk_coord)


func generate_chunk_debug_markers(chunk_coord: Vector3i) -> Array:
	return generate_chunk_generation_result(chunk_coord)["debug_markers"]


func effective_chunk_size_cells() -> int:
	return maxi(chunk_size_cells, 4)


func make_generated_chunk_data(
	chunk_coord: Vector3i,
	logic_grid: Array = [],
	generation_result: Dictionary = {},
	copy_output: bool = true
) -> Dictionary:
	if generation_result.is_empty():
		if logic_grid.is_empty():
			generation_result = _generate_chunk_generation_result_internal(chunk_coord)
			logic_grid = GeneratedChunkDataAdapter.logic_grid_from_generation_result(generation_result, false)
		else:
			generation_result = _generation_result_from_logic_grid(logic_grid)

	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	if topology_layers.is_empty():
		topology_layers = _topology_layers_from_logic_grid(logic_grid)
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, logic_grid)
	var formation_layers := make_formation_layers(chunk_coord, topology_layers)
	var formation_product_set: Dictionary = GeneratedChunkDataAdapter.formation_product_set_from_formation_layers(
		formation_layers,
		_world_generation_bounds_for_chunk(chunk_coord)
	)
	var diagnostics: Dictionary = generation_result.get(
		"diagnostics",
		_terrain_diagnostics(
			generation_result.get("terrain_cells", _terrain_cells_from_logic_grid(solid_grid)),
			topology_layers
		)
	)
	var compatibility_result := GeneratedChunkDataAdapter.normalize_generation_result({
		"terrain_cells": generation_result.get("terrain_cells", _terrain_cells_from_logic_grid(solid_grid)),
		"topology_layers": topology_layers,
		"debug_markers": generation_result.get("debug_markers", []),
		"diagnostics": diagnostics,
	}, copy_output)
	var world_chunk := _world_chunk_from_compatibility_generation_result(
		chunk_coord,
		compatibility_result,
		formation_product_set,
		copy_output
	)
	return GeneratedChunkDataAdapter.generated_chunk_data_from_world_chunk(
		world_chunk,
		{},
		generation_diagnostics(),
		copy_output
	)


func make_formation_layers(chunk_coord: Vector3i, topology_layers: Dictionary) -> Dictionary:
	return _formation_layer_builder().make_formation_layers(chunk_coord, topology_layers)


func make_formation_data(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	return _formation_layer_builder().make_formation_data(chunk_coord, logic_grid)


func sample_final_logic_cell(chunk_coord: Vector3i, local_cell: Vector2i) -> int:
	return _formation_halo_sampler().sample_final_logic_cell(chunk_coord, local_cell)


func sample_world_logic_cell(world_cell: Vector2i, chunk_y: int = 0) -> int:
	return _formation_halo_sampler().sample_world_logic_cell(world_cell, chunk_y)


func sample_world_topology_cell(world_cell: Vector2i, layer_id: String, chunk_y: int = 0) -> int:
	return _formation_halo_sampler().sample_world_topology_cell(
		world_cell,
		chunk_y,
		Vector3i(2147483647, chunk_y, 2147483647),
		layer_id,
		[]
	)


func world_cell_owner_chunk_coord(world_cell: Vector2i, chunk_y: int = 0) -> Vector3i:
	return FormationHaloSamplerScript.world_cell_owner_chunk_coord(
		world_cell,
		chunk_y,
		effective_chunk_size_cells()
	)


func local_cell_for_world_cell(world_cell: Vector2i) -> Vector2i:
	return FormationHaloSamplerScript.local_cell_for_world_cell(
		world_cell,
		effective_chunk_size_cells()
	)


func generation_settings_hash() -> int:
	var h: int = 0x2d2816fe
	h = _mix(h, world_seed)
	h = _mix(h, generator_version)
	h = _mix(h, chunk_size_cells)
	h = _mix(h, wall_threshold_percent)
	h = _mix(h, 1 if debug_force_chunk_border else 0)
	h = _mix(h, smoothing_passes)
	h = _mix(h, room_attempts)
	h = _mix(h, room_min_size)
	h = _mix(h, room_max_size)
	h = _mix(h, int(round(terrain_noise_frequency * 10000.0)))
	h = _mix(h, int(round(liquid_noise_frequency * 10000.0)))
	h = _mix(h, int(round(solid_noise_frequency * 10000.0)))
	h = _mix(h, liquid_threshold_percent)
	h = _mix(h, target_walkable_min_percent)
	h = _mix(h, target_walkable_max_percent)
	h = _mix(h, 1 if liquid_blocks_movement else 0)
	h = _mix(h, 1 if debug_generation_markers_enabled else 0)
	return abs(h)


func generation_diagnostics() -> Dictionary:
	return _world_generation_session().generation_diagnostics()


func _world_definition_for_generation() -> WorldDefinition:
	return _world_generation_session().world_definition()


func _world_generation_settings_dictionary() -> Dictionary:
	return {
		"authority": TERRAIN_AUTHORITY,
		"world_seed": world_seed,
		"generator_version": generator_version,
		"chunk_size_cells": chunk_size_cells,
		"effective_chunk_size_cells": effective_chunk_size_cells(),
		"wall_threshold_percent": wall_threshold_percent,
		"debug_force_chunk_border": debug_force_chunk_border,
		"smoothing_passes": smoothing_passes,
		"room_attempts": room_attempts,
		"room_min_size": room_min_size,
		"room_max_size": room_max_size,
		"terrain_noise_frequency": terrain_noise_frequency,
		"liquid_noise_frequency": liquid_noise_frequency,
		"solid_noise_frequency": solid_noise_frequency,
		"liquid_threshold_percent": liquid_threshold_percent,
		"target_walkable_min_percent": target_walkable_min_percent,
		"target_walkable_max_percent": target_walkable_max_percent,
		"liquid_blocks_movement": liquid_blocks_movement,
		"debug_generation_markers_enabled": debug_generation_markers_enabled,
		"legacy_provider_generation_settings_hash": generation_settings_hash(),
	}


func _world_chunk_from_compatibility_generation_result(
	chunk_coord: Vector3i,
	generation_result: Dictionary,
	formation_product_set: Dictionary = {},
	copy_inputs: bool = true
) -> GeneratedWorldChunk:
	var identity := _generated_chunk_identity_for_chunk(chunk_coord)
	var world_chunk := GeneratedWorldChunk.from_legacy_generation_result(
		identity,
		_world_generation_bounds_for_chunk(chunk_coord),
		generation_result,
		generation_result.get("diagnostics", {}),
		copy_inputs
	)
	world_chunk.formation_products = formation_product_set.duplicate(true) if copy_inputs else formation_product_set
	return world_chunk


func _world_generation_bounds_for_chunk(chunk_coord: Vector3i) -> Dictionary:
	return _world_generation_session().bounds_for_chunk(chunk_coord)


func get_diagnostics() -> Dictionary:
	return {
		"pending_requests": pending_request_count(),
		"loaded_chunks": loaded_chunk_count(),
		"cache_entries": cache_entry_count(),
		"formation_sample_cache_entries": formation_sample_cache_count(),
		"cache_hits": cache_hit_count,
		"cache_misses": cache_miss_count,
		"completed_loads": completed_load_count,
		"completed_unloads": completed_unload_count,
		"async_provider_enabled": async_provider_enabled,
		"provider_delay_frames": provider_delay_frames,
		"generation": generation_diagnostics(),
	}


func _world_generation_session() -> RefCounted:
	var current_hash := generation_settings_hash()
	if _world_generation_session_instance == null or _world_generation_session_hash != current_hash:
		_world_generation_session_instance = WorldGenerationSessionScript.from_settings(
			_world_generation_settings_dictionary(),
			self
		)
		_world_generation_session_hash = current_hash
		formation_sample_cache.clear()
	return _world_generation_session_instance


func _formation_halo_sampler() -> RefCounted:
	if use_chunk_cache:
		_ensure_cache()
	return FormationHaloSamplerScript.from_context(
		_world_generation_session(),
		effective_chunk_size_cells(),
		loaded_chunks,
		chunk_cache,
		use_chunk_cache,
		formation_sample_cache
	)


func _formation_layer_builder() -> RefCounted:
	return FormationLayerBuilderScript.from_sampler(
		_world_generation_session(),
		_formation_halo_sampler()
	)


func _legacy_chunk_generator() -> RefCounted:
	return _world_generation_session().legacy_chunk_generator()


func _generate_base_terrain_cells(chunk_coord: Vector3i, size: int, solid_layer: Array) -> Array:
	return _world_generation_session().generate_base_terrain_cells(chunk_coord, size, solid_layer)


func _make_terrain_cell(height_percent: int, liquid: bool, solid: bool) -> Dictionary:
	return _world_generation_session().make_terrain_cell(height_percent, liquid, solid)


func _set_cell_flags(cell: Dictionary, liquid: bool, solid: bool, height_percent: int = -1) -> Dictionary:
	return _world_generation_session().set_cell_flags(cell, liquid, solid, height_percent)


func _generate_smoothed_solid_layer(chunk_coord: Vector3i, size: int) -> Array:
	return _world_generation_session().generate_smoothed_solid_layer(chunk_coord, size)


func _carve_rooms_and_paths(chunk_coord: Vector3i, terrain_cells: Array, debug_markers: Array) -> void:
	_world_generation_session().carve_rooms_and_paths(chunk_coord, terrain_cells, debug_markers)


func _repair_walkable_connectivity(terrain_cells: Array, debug_markers: Array) -> void:
	_world_generation_session().repair_walkable_connectivity(terrain_cells, debug_markers)


func _balance_walkable_percent(terrain_cells: Array, debug_markers: Array) -> void:
	_world_generation_session().balance_walkable_percent(terrain_cells, debug_markers)


func _derive_topology_layers(terrain_cells: Array) -> Dictionary:
	return _world_generation_session().derive_topology_layers(terrain_cells)


func _terrain_diagnostics(terrain_cells: Array, topology_layers: Dictionary) -> Dictionary:
	return _world_generation_session().terrain_diagnostics(terrain_cells, topology_layers)


func _generated_chunk_identity_for_chunk(chunk_coord: Vector3i) -> GeneratedChunkIdentity:
	return _world_generation_session().identity_for_chunk(chunk_coord)


func _generation_result_from_logic_grid(logic_grid: Array) -> Dictionary:
	return _world_generation_session().generation_result_from_logic_grid(logic_grid)


func _topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
	return _world_generation_session().topology_layers_from_logic_grid(logic_grid)


func _terrain_cells_from_logic_grid(logic_grid: Array) -> Array:
	return _world_generation_session().terrain_cells_from_logic_grid(logic_grid)


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


func _mix(seed: int, value: int) -> int:
	var h := seed ^ (value * 0x45d9f3b)
	h = h ^ (h >> 16)
	h *= 0x45d9f3b
	h = h ^ (h >> 16)
	return h
