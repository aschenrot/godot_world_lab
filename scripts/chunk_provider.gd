extends Node

const TERRAIN_AUTHORITY := "local_lab_only"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]

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
	var settings_hash := generation_settings_hash()
	var generation_result := _load_or_generate_chunk_result(chunk_coord, settings_hash)
	var logic_grid: Array = generation_result["logic_grid"]
	var generated_chunk_data := make_generated_chunk_data(chunk_coord, logic_grid, generation_result)
	loaded_chunks[_chunk_key(chunk_coord)] = {
		"coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": settings_hash,
		"generated_chunk_data": generated_chunk_data,
	}


func _load_or_generate_chunk_result(chunk_coord: Vector3i, settings_hash: int) -> Dictionary:
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_chunk(chunk_coord, generator_version, settings_hash):
			cache_hit_count += 1
			return chunk_cache.load_generation_result(chunk_coord, generator_version, settings_hash)

		cache_miss_count += 1
		var generated := generate_chunk_generation_result(chunk_coord)
		chunk_cache.store_generation_result(chunk_coord, generator_version, settings_hash, generated)
		return generated

	return generate_chunk_generation_result(chunk_coord)


func _ensure_cache() -> void:
	if chunk_cache != null:
		return
	var Cache := load("res://scripts/chunk_cache.gd")
	chunk_cache = Cache.new()


func generate_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	return generate_chunk_generation_result(chunk_coord)["logic_grid"]


func generate_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	var size: int = effective_chunk_size_cells()
	var solid_layer := _generate_smoothed_solid_layer(chunk_coord, size)
	var terrain_cells := _generate_base_terrain_cells(chunk_coord, size, solid_layer)
	var debug_markers: Array = []

	_carve_rooms_and_paths(chunk_coord, terrain_cells, debug_markers)
	if _should_enforce_walkable_target():
		_repair_walkable_connectivity(terrain_cells, debug_markers)
		_balance_walkable_percent(terrain_cells, debug_markers)

	if debug_force_chunk_border:
		_apply_forced_chunk_border(terrain_cells)

	var topology_layers := _derive_topology_layers(terrain_cells)
	var diagnostics := _terrain_diagnostics(terrain_cells, topology_layers)
	return {
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"logic_grid": topology_layers[LAYER_SOLID].duplicate(true),
		"debug_markers": debug_markers if debug_generation_markers_enabled else [],
		"diagnostics": diagnostics,
	}


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
			logic_grid = generation_result["logic_grid"]
		else:
			generation_result = _generation_result_from_logic_grid(logic_grid)

	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	if topology_layers.is_empty():
		topology_layers = _topology_layers_from_logic_grid(logic_grid)
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, logic_grid)
	var formation_layers := make_formation_layers(chunk_coord, topology_layers)
	var solid_formation: Dictionary = formation_layers.get(
		LAYER_SOLID,
		make_formation_data(chunk_coord, solid_grid)
	)
	var diagnostics: Dictionary = generation_result.get(
		"diagnostics",
		_terrain_diagnostics(
			generation_result.get("terrain_cells", _terrain_cells_from_logic_grid(solid_grid)),
			topology_layers
		)
	)

	return {
		"product_type": "GeneratedChunkData",
		"authority": TERRAIN_AUTHORITY,
		"chunk_coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": generation_settings_hash(),
		"terrain_cells": generation_result.get("terrain_cells", _terrain_cells_from_logic_grid(solid_grid)),
		"topology_layers": topology_layers,
		"formation_layers": formation_layers,
		"logic_grid": solid_grid,
		"formation_grid": solid_formation.get("formation_grid", []),
		"formation_origin_cell": solid_formation.get("formation_origin_cell", Vector2i(-1, -1)),
		"owned_visual_origin": solid_formation.get("owned_visual_origin", Vector2i.ZERO),
		"owned_visual_size": solid_formation.get("owned_visual_size", _grid_dimension_vec(solid_grid)),
		"formation_mode": solid_formation.get("formation_mode", "owned_halo"),
		"source_chunk_coords": solid_formation.get("source_chunk_coords", []),
		"debug_markers": generation_result.get("debug_markers", []),
		"generation_settings": generation_diagnostics(),
		"diagnostics": diagnostics,
	}


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


func _generate_base_terrain_cells(chunk_coord: Vector3i, size: int, solid_layer: Array) -> Array:
	var height_noise := _make_fast_noise(_mix(world_seed, 0x1101), terrain_noise_frequency)
	var liquid_noise := _make_fast_noise(_mix(world_seed, 0x2202), liquid_noise_frequency)
	var terrain_cells: Array = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			var local_cell := Vector2i(x, y)
			var world_cell := _world_cell_from_chunk_local(chunk_coord, local_cell)
			var height_percent := _noise_percent(height_noise, world_cell)
			var liquid_percent := _noise_percent(liquid_noise, world_cell + Vector2i(517, -911))
			var liquid := (
				height_percent < clampi(liquid_threshold_percent, 0, 100)
				or liquid_percent < clampi(liquid_threshold_percent / 2, 0, 100)
			)
			var solid := int(solid_layer[y][x]) == 1 and not liquid
			row.append(_make_terrain_cell(height_percent, liquid, solid))
		terrain_cells.append(row)
	return terrain_cells


func _make_terrain_cell(height_percent: int, liquid: bool, solid: bool) -> Dictionary:
	var surface := "water" if liquid else "ground"
	var material := "water" if liquid else ("rock" if solid else "ground")
	return {
		"product_type": "LabTerrainCell",
		"authority": TERRAIN_AUTHORITY,
		"surface": surface,
		"walkable": _walkable_from_flags(liquid, solid),
		"solid": solid,
		"liquid": liquid,
		"height": float(height_percent) / 100.0,
		"height_percent": height_percent,
		"material": material,
		"flags": ["minable"] if solid else [],
	}


func _set_cell_flags(cell: Dictionary, liquid: bool, solid: bool, height_percent: int = -1) -> Dictionary:
	var next_cell := cell.duplicate(true)
	next_cell["liquid"] = liquid
	next_cell["solid"] = solid
	next_cell["walkable"] = _walkable_from_flags(liquid, solid)
	next_cell["surface"] = "water" if liquid else "ground"
	next_cell["material"] = "water" if liquid else ("rock" if solid else "ground")
	next_cell["flags"] = ["minable"] if solid else []
	if height_percent >= 0:
		next_cell["height_percent"] = height_percent
		next_cell["height"] = float(height_percent) / 100.0
	return next_cell


func _walkable_from_flags(liquid: bool, solid: bool) -> bool:
	return not solid and not (liquid_blocks_movement and liquid)


func _generate_smoothed_solid_layer(chunk_coord: Vector3i, size: int) -> Array:
	var margin: int = maxi(smoothing_passes, 0)
	var solid_noise := _make_fast_noise(_mix(world_seed, 0x3303), solid_noise_frequency)
	var expanded: Array = []
	for local_y in range(-margin, size + margin):
		var row: Array = []
		for local_x in range(-margin, size + margin):
			row.append(_initial_solid_cell(chunk_coord, Vector2i(local_x, local_y), solid_noise))
		expanded.append(row)

	for _pass_index in range(margin):
		expanded = _smooth_expanded_grid(expanded)

	var grid: Array = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			row.append(expanded[y + margin][x + margin])
		grid.append(row)
	return grid


func _cell_is_wall(chunk_coord: Vector3i, cell: Vector2i, size: int) -> int:
	if (
		debug_force_chunk_border
		and (cell.x == 0 or cell.y == 0 or cell.x == size - 1 or cell.y == size - 1)
	):
		return 1
	return _initial_cell_is_wall(chunk_coord, cell)


func _initial_cell_is_wall(chunk_coord: Vector3i, cell: Vector2i) -> int:
	var solid_noise := _make_fast_noise(_mix(world_seed, 0x3303), solid_noise_frequency)
	return _initial_solid_cell(chunk_coord, cell, solid_noise)


func _initial_solid_cell(chunk_coord: Vector3i, cell: Vector2i, solid_noise: FastNoiseLite) -> int:
	if wall_threshold_percent <= 0:
		return 0
	if wall_threshold_percent >= 100:
		return 1
	var size := effective_chunk_size_cells()
	var world_cell := Vector2i(chunk_coord.x * size + cell.x, chunk_coord.z * size + cell.y)
	var noise_percent := _noise_percent(solid_noise, world_cell + Vector2i(-193, 389))
	return 1 if noise_percent < clampi(wall_threshold_percent, 0, 100) else 0


func _noise_0_99(chunk_coord: Vector3i, cell: Vector2i) -> int:
	var size := effective_chunk_size_cells()
	var world_x: int = chunk_coord.x * size + cell.x
	var world_z: int = chunk_coord.z * size + cell.y
	return _noise_world_0_99(world_x, world_z)


func _noise_world_0_99(world_x: int, world_z: int) -> int:
	var h: int = _mix(0x1f123bb5, world_seed)
	h = _mix(h, generator_version)
	h = _mix(h, world_x)
	h = _mix(h, world_z)
	return abs(_finalize_hash(h)) % 100


func _make_fast_noise(seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = maxf(frequency, 0.001)
	return noise


func _noise_percent(noise: FastNoiseLite, world_cell: Vector2i) -> int:
	var sample := float(noise.get_noise_2d(float(world_cell.x), float(world_cell.y)))
	return clampi(int(round((sample * 0.5 + 0.5) * 100.0)), 0, 100)


func _smooth_expanded_grid(grid: Array) -> Array:
	var height := grid.size()
	var width := int(grid[0].size()) if height > 0 else 0
	var next_grid := grid.duplicate(true)
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var wall_count := 0
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					if offset_x == 0 and offset_y == 0:
						continue
					wall_count += int(grid[y + offset_y][x + offset_x])
			next_grid[y][x] = 1 if wall_count >= 5 else 0
	return next_grid


func _carve_rooms_and_paths(chunk_coord: Vector3i, terrain_cells: Array, debug_markers: Array) -> void:
	var rooms := _room_rects_for_chunk(chunk_coord, terrain_cells.size())
	var centers: Array[Vector2i] = []
	for room in rooms:
		var rect: Rect2i = room
		_carve_rect(terrain_cells, rect)
		var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
		centers.append(center)
		debug_markers.append({
			"type": "room",
			"chunk_coord": chunk_coord,
			"rect_position": rect.position,
			"rect_size": rect.size,
			"center": center,
		})

	for index in range(1, centers.size()):
		_carve_path(terrain_cells, centers[index - 1], centers[index])
		debug_markers.append({
			"type": "path",
			"chunk_coord": chunk_coord,
			"from": centers[index - 1],
			"to": centers[index],
		})


func _room_rects_for_chunk(chunk_coord: Vector3i, size: int) -> Array:
	var rects: Array[Rect2i] = []
	var clamped_min := clampi(room_min_size, 2, size)
	var clamped_max := clampi(maxi(room_max_size, clamped_min), clamped_min, size)
	for index in range(maxi(room_attempts, 0)):
		var seed := _mix(_mix(_mix(world_seed, generator_version), chunk_coord.x), chunk_coord.z)
		seed = _mix(seed, index)
		var width := _range_from_hash(_mix(seed, 11), clamped_min, clamped_max)
		var height := _range_from_hash(_mix(seed, 17), clamped_min, clamped_max)
		var max_x := maxi(size - width - 1, 1)
		var max_y := maxi(size - height - 1, 1)
		var x := _range_from_hash(_mix(seed, 23), 1, max_x)
		var y := _range_from_hash(_mix(seed, 29), 1, max_y)
		rects.append(Rect2i(Vector2i(x, y), Vector2i(width, height)))
	return rects


func _range_from_hash(hash_value: int, min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return min_value + abs(_finalize_hash(hash_value)) % (max_value - min_value + 1)


func _carve_rect(terrain_cells: Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if _grid_contains(terrain_cells, x, y):
				terrain_cells[y][x] = _set_cell_flags(terrain_cells[y][x], false, false)


func _carve_path(terrain_cells: Array, start: Vector2i, end: Vector2i) -> void:
	var x_step := 1 if end.x >= start.x else -1
	for x in range(start.x, end.x + x_step, x_step):
		if _grid_contains(terrain_cells, x, start.y):
			terrain_cells[start.y][x] = _set_cell_flags(terrain_cells[start.y][x], false, false)
	var y_step := 1 if end.y >= start.y else -1
	for y in range(start.y, end.y + y_step, y_step):
		if _grid_contains(terrain_cells, end.x, y):
			terrain_cells[y][end.x] = _set_cell_flags(terrain_cells[y][end.x], false, false)


func _apply_forced_chunk_border(terrain_cells: Array) -> void:
	var size := terrain_cells.size()
	for i in range(size):
		terrain_cells[0][i] = _set_cell_flags(terrain_cells[0][i], false, true)
		terrain_cells[size - 1][i] = _set_cell_flags(terrain_cells[size - 1][i], false, true)
		terrain_cells[i][0] = _set_cell_flags(terrain_cells[i][0], false, true)
		terrain_cells[i][size - 1] = _set_cell_flags(terrain_cells[i][size - 1], false, true)


func _should_enforce_walkable_target() -> bool:
	return wall_threshold_percent > 0 and wall_threshold_percent < 100 and not debug_force_chunk_border


func _repair_walkable_connectivity(terrain_cells: Array, debug_markers: Array) -> void:
	var components := _walkable_components(terrain_cells)
	if components.size() <= 1:
		return

	var anchor_component: Array = components[0]
	var anchor: Vector2i = anchor_component[0]
	for index in range(1, components.size()):
		var component: Array = components[index]
		if component.is_empty():
			continue
		var start: Vector2i = component[0]
		_carve_walkable_path(terrain_cells, start, anchor)
		debug_markers.append({
			"type": "connectivity_repair",
			"from": start,
			"to": anchor,
			"component_size": component.size(),
		})


func _balance_walkable_percent(terrain_cells: Array, debug_markers: Array) -> void:
	var target_min := clampi(target_walkable_min_percent, 0, 100)
	var target_max := clampi(maxi(target_walkable_max_percent, target_min), target_min, 100)
	var total := terrain_cells.size() * int(terrain_cells[0].size()) if not terrain_cells.is_empty() else 0
	if total <= 0:
		return

	var walkable_count := _walkable_cell_count(terrain_cells)
	var min_count := int(ceil(float(total * target_min) / 100.0))
	var max_count := int(floor(float(total * target_max) / 100.0))

	if walkable_count < min_count:
		var candidates := _sorted_cells_by_hash(terrain_cells, false)
		for cell in candidates:
			if walkable_count >= min_count:
				break
			var coord: Vector2i = cell
			terrain_cells[coord.y][coord.x] = _set_cell_flags(terrain_cells[coord.y][coord.x], false, false)
			walkable_count += 1
		debug_markers.append({
			"type": "walkability_balance_open",
			"target_min_percent": target_min,
			"walkable_count": walkable_count,
		})
	elif walkable_count > max_count:
		var blockers := _sorted_cells_by_hash(terrain_cells, true)
		for cell in blockers:
			if walkable_count <= max_count:
				break
			var coord: Vector2i = cell
			terrain_cells[coord.y][coord.x] = _set_cell_flags(terrain_cells[coord.y][coord.x], false, true)
			walkable_count -= 1
		debug_markers.append({
			"type": "walkability_balance_block",
			"target_max_percent": target_max,
			"walkable_count": walkable_count,
		})


func _sorted_cells_by_hash(terrain_cells: Array, want_walkable: bool) -> Array:
	var scored: Array[Dictionary] = []
	for y in range(terrain_cells.size()):
		for x in range(int(terrain_cells[y].size())):
			var cell: Dictionary = terrain_cells[y][x]
			if bool(cell.get("walkable", false)) != want_walkable:
				continue
			var h := _mix(_mix(_mix(world_seed, generator_version), x), y)
			scored.append({"cell": Vector2i(x, y), "score": abs(_finalize_hash(h))})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) < int(b["score"]))
	var cells: Array[Vector2i] = []
	for entry in scored:
		cells.append(entry["cell"])
	return cells


func _carve_walkable_path(terrain_cells: Array, start: Vector2i, end: Vector2i) -> void:
	var x_step := 1 if end.x >= start.x else -1
	for x in range(start.x, end.x + x_step, x_step):
		if _grid_contains(terrain_cells, x, start.y):
			terrain_cells[start.y][x] = _set_cell_flags(terrain_cells[start.y][x], false, false)
	var y_step := 1 if end.y >= start.y else -1
	for y in range(start.y, end.y + y_step, y_step):
		if _grid_contains(terrain_cells, end.x, y):
			terrain_cells[y][end.x] = _set_cell_flags(terrain_cells[y][end.x], false, false)


func _derive_topology_layers(terrain_cells: Array) -> Dictionary:
	var ground: Array = []
	var solid: Array = []
	var water: Array = []
	var cliff: Array = []
	for row in terrain_cells:
		var ground_row: Array = []
		var solid_row: Array = []
		var water_row: Array = []
		var cliff_row: Array = []
		for value in row:
			var cell: Dictionary = value
			var is_liquid := bool(cell.get("liquid", false))
			ground_row.append(0 if is_liquid else 1)
			solid_row.append(1 if bool(cell.get("solid", false)) else 0)
			water_row.append(1 if is_liquid else 0)
			cliff_row.append(0)
		ground.append(ground_row)
		solid.append(solid_row)
		water.append(water_row)
		cliff.append(cliff_row)
	return {
		LAYER_GROUND: ground,
		LAYER_SOLID: solid,
		LAYER_WATER: water,
		LAYER_CLIFF: cliff,
	}


func _terrain_diagnostics(terrain_cells: Array, topology_layers: Dictionary) -> Dictionary:
	var total := 0
	var walkable := 0
	var solid := 0
	var liquid := 0
	for row in terrain_cells:
		for value in row:
			var cell: Dictionary = value
			total += 1
			if bool(cell.get("walkable", false)):
				walkable += 1
			if bool(cell.get("solid", false)):
				solid += 1
			if bool(cell.get("liquid", false)):
				liquid += 1

	var components := _walkable_components(terrain_cells)
	var dominant := 0
	if not components.is_empty():
		dominant = int(components[0].size())
	return {
		"authority": TERRAIN_AUTHORITY,
		"layer_ids": _ordered_layer_ids(topology_layers),
		"cell_count": total,
		"walkable_cell_count": walkable,
		"solid_cell_count": solid,
		"liquid_cell_count": liquid,
		"open_percent": _percent(walkable, total),
		"solid_percent": _percent(solid, total),
		"liquid_percent": _percent(liquid, total),
		"connected_walkable_region_count": components.size(),
		"dominant_walkable_region": dominant,
		"dominant_walkable_percent": _percent(dominant, total),
		"generation_settings_hash": generation_settings_hash(),
		"generator_version": generator_version,
		"logic_grid_alias": "topology_layers.solid",
	}


func _percent(count: int, total: int) -> int:
	if total <= 0:
		return 0
	return int(round(float(count) * 100.0 / float(total)))


func _walkable_components(terrain_cells: Array) -> Array:
	var components: Array = []
	var visited: Dictionary = {}
	for y in range(terrain_cells.size()):
		for x in range(int(terrain_cells[y].size())):
			var start := Vector2i(x, y)
			if visited.has(_cell_key(start)) or not _terrain_cell_walkable(terrain_cells, start):
				continue
			var component := _flood_walkable_component(terrain_cells, start, visited)
			components.append(component)
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return components


func _flood_walkable_component(terrain_cells: Array, start: Vector2i, visited: Dictionary) -> Array:
	var component: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	visited[_cell_key(start)] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		component.append(cell)
		for neighbor in [
			cell + Vector2i.LEFT,
			cell + Vector2i.RIGHT,
			cell + Vector2i.UP,
			cell + Vector2i.DOWN,
		]:
			if visited.has(_cell_key(neighbor)) or not _terrain_cell_walkable(terrain_cells, neighbor):
				continue
			visited[_cell_key(neighbor)] = true
			queue.append(neighbor)
	return component


func _terrain_cell_walkable(terrain_cells: Array, cell: Vector2i) -> bool:
	if not _grid_contains(terrain_cells, cell.x, cell.y):
		return false
	return bool(terrain_cells[cell.y][cell.x].get("walkable", false))


func _walkable_cell_count(terrain_cells: Array) -> int:
	var count := 0
	for row in terrain_cells:
		for value in row:
			var cell: Dictionary = value
			if bool(cell.get("walkable", false)):
				count += 1
	return count


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
	var settings_hash := generation_settings_hash()
	var loaded_record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	if (
		not loaded_record.is_empty()
		and int(loaded_record.get("generator_version", -1)) == generator_version
		and int(loaded_record.get("generation_settings_hash", -1)) == settings_hash
	):
		var loaded_data: Dictionary = loaded_record.get("generated_chunk_data", {})
		if loaded_data.has("topology_layers"):
			return loaded_data

	var cache_key := "%s|%s" % [settings_hash, _chunk_key(chunk_coord)]
	if formation_sample_cache.has(cache_key):
		return formation_sample_cache[cache_key]

	var result: Dictionary = {}
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_chunk(chunk_coord, generator_version, settings_hash):
			result = chunk_cache.load_generation_result(chunk_coord, generator_version, settings_hash)

	if result.is_empty():
		result = generate_chunk_generation_result(chunk_coord)

	formation_sample_cache[cache_key] = result
	return result


func _generation_result_from_logic_grid(logic_grid: Array) -> Dictionary:
	var topology_layers := _topology_layers_from_logic_grid(logic_grid)
	var terrain_cells := _terrain_cells_from_logic_grid(logic_grid)
	return {
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"logic_grid": topology_layers[LAYER_SOLID].duplicate(true),
		"debug_markers": [],
		"diagnostics": _terrain_diagnostics(terrain_cells, topology_layers),
	}


func _topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
	var ground: Array = []
	var water: Array = []
	var cliff: Array = []
	for row in logic_grid:
		var ground_row: Array = []
		var water_row: Array = []
		var cliff_row: Array = []
		for _cell in row:
			ground_row.append(1)
			water_row.append(0)
			cliff_row.append(0)
		ground.append(ground_row)
		water.append(water_row)
		cliff.append(cliff_row)
	return {
		LAYER_GROUND: ground,
		LAYER_SOLID: logic_grid.duplicate(true),
		LAYER_WATER: water,
		LAYER_CLIFF: cliff,
	}


func _terrain_cells_from_logic_grid(logic_grid: Array) -> Array:
	var terrain_cells: Array = []
	for row in logic_grid:
		var terrain_row: Array = []
		for cell in row:
			terrain_row.append(_make_terrain_cell(50, false, int(cell) == 1))
		terrain_cells.append(terrain_row)
	return terrain_cells


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
