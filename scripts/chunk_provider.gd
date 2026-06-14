extends Node

const TERRAIN_AUTHORITY := "local_lab_only"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")
const LegacyChunkGeneratorScript := preload("res://scripts/world_generation/legacy/legacy_chunk_generator.gd")

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
	return record.get("generated_chunk_data", {})


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
	var logic_grid := GeneratedChunkDataAdapter.logic_grid_from_generation_result(generation_result)
	var generated_chunk_data := make_generated_chunk_data(chunk_coord, logic_grid, generation_result)
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
		var generated := generate_chunk_generation_result(chunk_coord)
		chunk_cache.store_generation_result_for_identity(cache_identity, generated)
		return generated

	return generate_chunk_generation_result(chunk_coord)


func _ensure_cache() -> void:
	if chunk_cache != null:
		return
	var Cache := load("res://scripts/chunk_cache.gd")
	chunk_cache = Cache.new()


func generate_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	return GeneratedChunkDataAdapter.logic_grid_from_generation_result(generate_chunk_generation_result(chunk_coord))


func generate_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	var definition := _world_definition_for_generation()
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		effective_chunk_size_cells(),
		1,
		snapshot.requested_product_set,
		{"provider": "chunk_provider"}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var pipeline := GenerationPipeline.from_stages([
		LegacyChunkGenerationStage.from_provider(self)
	])
	var working_set := pipeline.run(snapshot, context)
	if working_set.has_validation_errors():
		push_error("chunk generation pipeline validation issues: %s" % str(working_set.validation_issues))
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	return GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)


func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	return _legacy_chunk_generator().generate_chunk_generation_result(chunk_coord)


func generate_chunk_debug_markers(chunk_coord: Vector3i) -> Array:
	return generate_chunk_generation_result(chunk_coord)["debug_markers"]


func effective_chunk_size_cells() -> int:
	return maxi(chunk_size_cells, 4)


func make_generated_chunk_data(
	chunk_coord: Vector3i,
	logic_grid: Array = [],
	generation_result: Dictionary = {}
) -> Dictionary:
	if generation_result.is_empty():
		if logic_grid.is_empty():
			generation_result = generate_chunk_generation_result(chunk_coord)
			logic_grid = GeneratedChunkDataAdapter.logic_grid_from_generation_result(generation_result)
		else:
			generation_result = _generation_result_from_logic_grid(logic_grid)

	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	if topology_layers.is_empty():
		topology_layers = _topology_layers_from_logic_grid(logic_grid)
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, logic_grid)
	var formation_layers := make_formation_layers(chunk_coord, topology_layers)
	var formation_product_set: Dictionary = FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		_world_generation_bounds_for_chunk(chunk_coord)
	).to_dictionary()
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
	})
	var world_chunk := _world_chunk_from_compatibility_generation_result(
		chunk_coord,
		compatibility_result,
		formation_product_set
	)
	return GeneratedChunkDataAdapter.generated_chunk_data_from_world_chunk(
		world_chunk,
		{},
		generation_diagnostics()
	)


func make_formation_layers(chunk_coord: Vector3i, topology_layers: Dictionary) -> Dictionary:
	var formation_layers: Dictionary = {}
	for layer_id in _ordered_layer_ids(topology_layers):
		formation_layers[layer_id] = _make_formation_data_for_layer(
			chunk_coord,
			layer_id,
			topology_layers[layer_id]
		)
	return formation_layers


func make_formation_data(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	return _make_formation_data_for_layer(chunk_coord, LAYER_SOLID, logic_grid)


func sample_final_logic_cell(chunk_coord: Vector3i, local_cell: Vector2i) -> int:
	var world_cell := _world_cell_from_chunk_local(chunk_coord, local_cell)
	return sample_world_logic_cell(world_cell, chunk_coord.y)


func sample_world_logic_cell(world_cell: Vector2i, chunk_y: int = 0) -> int:
	return sample_world_topology_cell(world_cell, LAYER_SOLID, chunk_y)


func sample_world_topology_cell(world_cell: Vector2i, layer_id: String, chunk_y: int = 0) -> int:
	var owner := world_cell_owner_chunk_coord(world_cell, chunk_y)
	var local_cell := local_cell_for_world_cell(world_cell)
	return _grid_cell(_get_generated_topology_layer_for_sampling(owner, layer_id), local_cell)


func world_cell_owner_chunk_coord(world_cell: Vector2i, chunk_y: int = 0) -> Vector3i:
	var size := effective_chunk_size_cells()
	return Vector3i(_floor_div(world_cell.x, size), chunk_y, _floor_div(world_cell.y, size))


func local_cell_for_world_cell(world_cell: Vector2i) -> Vector2i:
	var size := effective_chunk_size_cells()
	return Vector2i(_positive_mod(world_cell.x, size), _positive_mod(world_cell.y, size))


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
		"generation_settings_hash": generation_settings_hash(),
	}


func _world_definition_for_generation() -> WorldDefinition:
	var definition := WorldDefinition.new()
	definition.world_definition_id = "godot_lab_legacy_provider"
	definition.world_definition_version = generator_version
	definition.world_seed = world_seed
	definition.domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	definition.generation_settings = _world_generation_settings_dictionary()
	definition.stage_ids = PackedStringArray([LegacyChunkGenerationStage.STAGE_ID])
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
	formation_product_set: Dictionary = {}
) -> GeneratedWorldChunk:
	var identity := _generated_chunk_identity_for_chunk(chunk_coord)
	var world_chunk := GeneratedWorldChunk.from_legacy_generation_result(
		identity,
		_world_generation_bounds_for_chunk(chunk_coord),
		generation_result,
		generation_result.get("diagnostics", {})
	)
	world_chunk.formation_products = formation_product_set.duplicate(true)
	return world_chunk


func _world_generation_bounds_for_chunk(chunk_coord: Vector3i) -> Dictionary:
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


func _legacy_chunk_generator() -> RefCounted:
	return LegacyChunkGeneratorScript.from_settings(_world_generation_settings_dictionary())


func _generate_base_terrain_cells(chunk_coord: Vector3i, size: int, solid_layer: Array) -> Array:
	return _legacy_chunk_generator().generate_base_terrain_cells(chunk_coord, size, solid_layer)


func _make_terrain_cell(height_percent: int, liquid: bool, solid: bool) -> Dictionary:
	return _legacy_chunk_generator().make_terrain_cell(height_percent, liquid, solid)


func _set_cell_flags(cell: Dictionary, liquid: bool, solid: bool, height_percent: int = -1) -> Dictionary:
	return _legacy_chunk_generator().set_cell_flags(cell, liquid, solid, height_percent)


func _generate_smoothed_solid_layer(chunk_coord: Vector3i, size: int) -> Array:
	return _legacy_chunk_generator().generate_smoothed_solid_layer(chunk_coord, size)


func _carve_rooms_and_paths(chunk_coord: Vector3i, terrain_cells: Array, debug_markers: Array) -> void:
	_legacy_chunk_generator().carve_rooms_and_paths(chunk_coord, terrain_cells, debug_markers)


func _repair_walkable_connectivity(terrain_cells: Array, debug_markers: Array) -> void:
	_legacy_chunk_generator().repair_walkable_connectivity(terrain_cells, debug_markers)


func _balance_walkable_percent(terrain_cells: Array, debug_markers: Array) -> void:
	_legacy_chunk_generator().balance_walkable_percent(terrain_cells, debug_markers)


func _derive_topology_layers(terrain_cells: Array) -> Dictionary:
	return _legacy_chunk_generator().derive_topology_layers(terrain_cells)


func _terrain_diagnostics(terrain_cells: Array, topology_layers: Dictionary) -> Dictionary:
	return _legacy_chunk_generator().terrain_diagnostics(terrain_cells, topology_layers)


func _make_formation_data_for_layer(chunk_coord: Vector3i, layer_id: String, layer_grid: Array) -> Dictionary:
	var size := _logic_grid_dimension(layer_grid)
	var formation_grid: Array = []
	var source_chunks: Dictionary = {}

	for local_y in range(-1, size):
		var row: Array = []
		for local_x in range(-1, size):
			var world_cell := _world_cell_from_chunk_local(chunk_coord, Vector2i(local_x, local_y))
			var owner := world_cell_owner_chunk_coord(world_cell, chunk_coord.y)
			source_chunks[_chunk_key(owner)] = owner
			row.append(_sample_world_topology_cell_with_current_grid(
				world_cell,
				chunk_coord.y,
				chunk_coord,
				layer_id,
				layer_grid
			))
		formation_grid.append(row)

	return {
		"layer_id": layer_id,
		"formation_grid": formation_grid,
		"formation_origin_cell": Vector2i(-1, -1),
		"owned_visual_origin": Vector2i.ZERO,
		"owned_visual_size": Vector2i(size, size),
		"formation_mode": "owned_halo",
		"source_chunk_coords": _sorted_chunk_coords(source_chunks),
	}


func _sample_world_topology_cell_with_current_grid(
	world_cell: Vector2i,
	chunk_y: int,
	current_chunk_coord: Vector3i,
	layer_id: String,
	current_layer_grid: Array
) -> int:
	var owner := world_cell_owner_chunk_coord(world_cell, chunk_y)
	var local_cell := local_cell_for_world_cell(world_cell)
	if owner == current_chunk_coord:
		return _grid_cell(current_layer_grid, local_cell)
	return _grid_cell(_get_generated_topology_layer_for_sampling(owner, layer_id), local_cell)


func _get_generated_topology_layer_for_sampling(chunk_coord: Vector3i, layer_id: String) -> Array:
	var result := _get_generated_result_for_sampling(chunk_coord)
	var topology_layers: Dictionary = result.get("topology_layers", {})
	if topology_layers.has(layer_id):
		return topology_layers[layer_id]
	if topology_layers.has(LAYER_SOLID):
		return topology_layers[LAYER_SOLID]
	return result.get("logic_grid", [])


func _get_generated_logic_grid_for_sampling(chunk_coord: Vector3i) -> Array:
	return _get_generated_topology_layer_for_sampling(chunk_coord, LAYER_SOLID)


func _get_generated_result_for_sampling(chunk_coord: Vector3i) -> Dictionary:
	var cache_identity := _generated_chunk_identity_for_chunk(chunk_coord)
	var loaded_record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	if (
		not loaded_record.is_empty()
		and loaded_record.get("cache_key", "") == cache_identity.cache_key()
	):
		var loaded_data: Dictionary = loaded_record.get("generated_chunk_data", {})
		if loaded_data.has("topology_layers"):
			return loaded_data

	var cache_key := cache_identity.cache_key()
	if formation_sample_cache.has(cache_key):
		return formation_sample_cache[cache_key]

	var result: Dictionary = {}
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_identity(cache_identity):
			result = chunk_cache.load_generation_result_for_identity(cache_identity)

	if result.is_empty():
		result = generate_chunk_generation_result(chunk_coord)

	formation_sample_cache[cache_key] = result
	return result


func _generated_chunk_identity_for_chunk(chunk_coord: Vector3i) -> GeneratedChunkIdentity:
	var definition := _world_definition_for_generation()
	var snapshot := definition.compile_snapshot()
	return snapshot.identity_for_chunk(chunk_coord, snapshot.requested_product_set)


func _generation_result_from_logic_grid(logic_grid: Array) -> Dictionary:
	return _legacy_chunk_generator().generation_result_from_logic_grid(logic_grid)


func _topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
	return _legacy_chunk_generator().topology_layers_from_logic_grid(logic_grid)


func _terrain_cells_from_logic_grid(logic_grid: Array) -> Array:
	return _legacy_chunk_generator().terrain_cells_from_logic_grid(logic_grid)


func _ordered_layer_ids(topology_layers: Dictionary) -> Array:
	var ordered: Array[String] = []
	for layer_id in TOPOLOGY_LAYER_ORDER:
		if topology_layers.has(layer_id):
			ordered.append(layer_id)
	var extra: Array = topology_layers.keys()
	extra.sort()
	for layer_id in extra:
		if not ordered.has(String(layer_id)):
			ordered.append(String(layer_id))
	return ordered


func _grid_contains(grid: Array, x: int, y: int) -> bool:
	return y >= 0 and y < grid.size() and x >= 0 and x < int(grid[y].size())


func _grid_cell(grid: Array, local_cell: Vector2i) -> int:
	if (
		local_cell.y < 0
		or local_cell.y >= grid.size()
		or local_cell.x < 0
		or local_cell.x >= int(grid[local_cell.y].size())
	):
		return 0
	return int(grid[local_cell.y][local_cell.x])


func _logic_grid_cell(logic_grid: Array, local_cell: Vector2i) -> int:
	return _grid_cell(logic_grid, local_cell)


func _logic_grid_dimension(logic_grid: Array) -> int:
	if logic_grid.is_empty():
		return effective_chunk_size_cells()
	return logic_grid.size()


func _grid_dimension_vec(grid: Array) -> Vector2i:
	var height := grid.size()
	var width := 0
	for row in grid:
		width = maxi(width, int(row.size()))
	return Vector2i(width, height)


func _world_cell_from_chunk_local(chunk_coord: Vector3i, local_cell: Vector2i) -> Vector2i:
	var size := effective_chunk_size_cells()
	return Vector2i(chunk_coord.x * size + local_cell.x, chunk_coord.z * size + local_cell.y)


func _floor_div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	return floori(float(value) / float(divisor))


func _positive_mod(value: int, modulus: int) -> int:
	if modulus <= 0:
		return 0
	var result := value % modulus
	return result + modulus if result < 0 else result


func _sorted_chunk_coords(chunks_by_key: Dictionary) -> Array:
	var keys := chunks_by_key.keys()
	keys.sort()
	var coords: Array[Vector3i] = []
	for key in keys:
		coords.append(chunks_by_key[key])
	return coords


func _cell_key(cell: Vector2i) -> String:
	return "%s:%s" % [cell.x, cell.y]


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


func _mix(seed: int, value: int) -> int:
	var h := seed ^ (value * 0x45d9f3b)
	h = h ^ (h >> 16)
	h *= 0x45d9f3b
	h = h ^ (h >> 16)
	return h


func _finalize_hash(value: int) -> int:
	var h := value
	h = h ^ (h >> 16)
	h *= 0x7feb352d
	h = h ^ (h >> 15)
	h *= 0x846ca68b
	h = h ^ (h >> 16)
	return h
