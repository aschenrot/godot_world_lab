extends Node

@export var chunk_size_cells: int = 16
@export var generator_version: int = 1
@export var world_seed: int = 1337
@export_range(0, 100, 1) var wall_threshold_percent: int = 34
@export var debug_force_chunk_border: bool = false
@export_range(0, 4, 1) var smoothing_passes: int = 1
@export_range(0, 8, 1) var room_attempts: int = 3
@export_range(2, 12, 1) var room_min_size: int = 3
@export_range(2, 16, 1) var room_max_size: int = 6
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
	var logic_grid: Array = []
	var settings_hash := generation_settings_hash()
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_chunk(chunk_coord, generator_version, settings_hash):
			cache_hit_count += 1
			logic_grid = chunk_cache.load_chunk(chunk_coord, generator_version, settings_hash)
		else:
			cache_miss_count += 1
			logic_grid = generate_chunk_generation_result(chunk_coord)["logic_grid"]
			chunk_cache.store_chunk(chunk_coord, generator_version, settings_hash, logic_grid)
	else:
		logic_grid = generate_chunk_generation_result(chunk_coord)["logic_grid"]

	var generated_chunk_data := make_generated_chunk_data(chunk_coord, logic_grid)
	loaded_chunks[_chunk_key(chunk_coord)] = {
		"coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": settings_hash,
		"generated_chunk_data": generated_chunk_data,
	}


func _ensure_cache() -> void:
	if chunk_cache != null:
		return
	var Cache := load("res://scripts/chunk_cache.gd")
	chunk_cache = Cache.new()


func generate_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	return generate_chunk_generation_result(chunk_coord)["logic_grid"]


func generate_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	var size: int = effective_chunk_size_cells()
	var grid := _generate_smoothed_grid(chunk_coord, size)
	var debug_markers: Array = []
	_carve_rooms_and_paths(chunk_coord, grid, debug_markers)

	if debug_force_chunk_border:
		_apply_forced_chunk_border(grid)

	return {
		"logic_grid": grid,
		"debug_markers": debug_markers if debug_generation_markers_enabled else [],
	}


func generate_chunk_debug_markers(chunk_coord: Vector3i) -> Array:
	return generate_chunk_generation_result(chunk_coord)["debug_markers"]


func effective_chunk_size_cells() -> int:
	return maxi(chunk_size_cells, 4)


func _generate_smoothed_grid(chunk_coord: Vector3i, size: int) -> Array:
	var margin: int = maxi(smoothing_passes, 0)
	var expanded: Array = []
	for local_y in range(-margin, size + margin):
		var row: Array = []
		for local_x in range(-margin, size + margin):
			row.append(_initial_cell_is_wall(chunk_coord, Vector2i(local_x, local_y)))
		expanded.append(row)

	for pass_index in range(margin):
		expanded = _smooth_expanded_grid(expanded)

	var grid: Array = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			row.append(expanded[y + margin][x + margin])
		grid.append(row)
	return grid


func make_generated_chunk_data(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	var formation_data := make_formation_data(chunk_coord, logic_grid)
	return {
		"product_type": "GeneratedChunkData",
		"chunk_coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": generation_settings_hash(),
		"logic_grid": logic_grid,
		"formation_grid": formation_data["formation_grid"],
		"formation_origin_cell": formation_data["formation_origin_cell"],
		"owned_visual_origin": formation_data["owned_visual_origin"],
		"owned_visual_size": formation_data["owned_visual_size"],
		"formation_mode": formation_data["formation_mode"],
		"source_chunk_coords": formation_data["source_chunk_coords"],
		"debug_markers": generate_chunk_debug_markers(chunk_coord),
		"generation_settings": generation_diagnostics(),
	}


func make_formation_data(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	var size := _logic_grid_dimension(logic_grid)
	var formation_grid: Array = []
	var source_chunks: Dictionary = {}

	for local_y in range(-1, size):
		var row: Array = []
		for local_x in range(-1, size):
			var world_cell := _world_cell_from_chunk_local(chunk_coord, Vector2i(local_x, local_y))
			var owner := world_cell_owner_chunk_coord(world_cell, chunk_coord.y)
			source_chunks[_chunk_key(owner)] = owner
			row.append(_sample_world_logic_cell_with_current_grid(
				world_cell,
				chunk_coord.y,
				chunk_coord,
				logic_grid
			))
		formation_grid.append(row)

	return {
		"formation_grid": formation_grid,
		"formation_origin_cell": Vector2i(-1, -1),
		"owned_visual_origin": Vector2i.ZERO,
		"owned_visual_size": Vector2i(size, size),
		"formation_mode": "owned_halo",
		"source_chunk_coords": _sorted_chunk_coords(source_chunks),
	}


func sample_final_logic_cell(chunk_coord: Vector3i, local_cell: Vector2i) -> int:
	var world_cell := _world_cell_from_chunk_local(chunk_coord, local_cell)
	return sample_world_logic_cell(world_cell, chunk_coord.y)


func sample_world_logic_cell(world_cell: Vector2i, chunk_y: int = 0) -> int:
	var owner := world_cell_owner_chunk_coord(world_cell, chunk_y)
	var local_cell := local_cell_for_world_cell(world_cell)
	return _logic_grid_cell(_get_generated_logic_grid_for_sampling(owner), local_cell)


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
	h = _mix(h, 1 if debug_generation_markers_enabled else 0)
	return abs(h)


func generation_diagnostics() -> Dictionary:
	return {
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


func _cell_is_wall(chunk_coord: Vector3i, cell: Vector2i, size: int) -> int:
	if (
		debug_force_chunk_border
		and (cell.x == 0 or cell.y == 0 or cell.x == size - 1 or cell.y == size - 1)
	):
		return 1

	return _initial_cell_is_wall(chunk_coord, cell)


func _initial_cell_is_wall(chunk_coord: Vector3i, cell: Vector2i) -> int:
	var size := effective_chunk_size_cells()
	var world_x: int = chunk_coord.x * size + cell.x
	var world_z: int = chunk_coord.z * size + cell.y
	var local_noise: int = _noise_world_0_99(world_x, world_z)
	return 1 if local_noise < clampi(wall_threshold_percent, 0, 100) else 0


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


func _carve_rooms_and_paths(chunk_coord: Vector3i, grid: Array, debug_markers: Array) -> void:
	var rooms := _room_rects_for_chunk(chunk_coord, grid.size())
	var centers: Array[Vector2i] = []
	for room in rooms:
		var rect: Rect2i = room
		_carve_rect(grid, rect)
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
		_carve_path(grid, centers[index - 1], centers[index])
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


func _carve_rect(grid: Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if _grid_contains(grid, x, y):
				grid[y][x] = 0


func _carve_path(grid: Array, start: Vector2i, end: Vector2i) -> void:
	var x_step := 1 if end.x >= start.x else -1
	for x in range(start.x, end.x + x_step, x_step):
		if _grid_contains(grid, x, start.y):
			grid[start.y][x] = 0
	var y_step := 1 if end.y >= start.y else -1
	for y in range(start.y, end.y + y_step, y_step):
		if _grid_contains(grid, end.x, y):
			grid[y][end.x] = 0


func _apply_forced_chunk_border(grid: Array) -> void:
	var size := grid.size()
	for i in range(size):
		grid[0][i] = 1
		grid[size - 1][i] = 1
		grid[i][0] = 1
		grid[i][size - 1] = 1


func _grid_contains(grid: Array, x: int, y: int) -> bool:
	return y >= 0 and y < grid.size() and x >= 0 and x < int(grid[y].size())


func _sample_world_logic_cell_with_current_grid(
	world_cell: Vector2i,
	chunk_y: int,
	current_chunk_coord: Vector3i,
	current_logic_grid: Array
) -> int:
	var owner := world_cell_owner_chunk_coord(world_cell, chunk_y)
	var local_cell := local_cell_for_world_cell(world_cell)
	if owner == current_chunk_coord:
		return _logic_grid_cell(current_logic_grid, local_cell)
	return _logic_grid_cell(_get_generated_logic_grid_for_sampling(owner), local_cell)


func _get_generated_logic_grid_for_sampling(chunk_coord: Vector3i) -> Array:
	var settings_hash := generation_settings_hash()
	var loaded_record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	if (
		not loaded_record.is_empty()
		and int(loaded_record.get("generator_version", -1)) == generator_version
		and int(loaded_record.get("generation_settings_hash", -1)) == settings_hash
	):
		var loaded_data: Dictionary = loaded_record.get("generated_chunk_data", {})
		if loaded_data.has("logic_grid"):
			return loaded_data["logic_grid"]

	var cache_key := "%s|%s" % [settings_hash, _chunk_key(chunk_coord)]
	if formation_sample_cache.has(cache_key):
		return formation_sample_cache[cache_key]

	var logic_grid: Array = []
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_chunk(chunk_coord, generator_version, settings_hash):
			logic_grid = chunk_cache.load_chunk(chunk_coord, generator_version, settings_hash)

	if logic_grid.is_empty():
		logic_grid = generate_chunk_generation_result(chunk_coord)["logic_grid"]

	formation_sample_cache[cache_key] = logic_grid
	return logic_grid


func _logic_grid_cell(logic_grid: Array, local_cell: Vector2i) -> int:
	if (
		local_cell.y < 0
		or local_cell.y >= logic_grid.size()
		or local_cell.x < 0
		or local_cell.x >= int(logic_grid[local_cell.y].size())
	):
		return 0
	return int(logic_grid[local_cell.y][local_cell.x])


func _logic_grid_dimension(logic_grid: Array) -> int:
	if logic_grid.is_empty():
		return effective_chunk_size_cells()
	return logic_grid.size()


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


func _mix(seed: int, value: int) -> int:
	var h := seed ^ (value * 0x45d9f3b)
	h = h ^ (h >> 16)
	h *= 0x45d9f3b
	h = h ^ (h >> 16)
	return h


func _finalize_hash(value: int) -> int:
	var h := value
	h = h ^ (h >> 15)
	h *= 0x2c1b3c6d
	h = h ^ (h >> 12)
	h *= 0x297a2d39
	h = h ^ (h >> 15)
	return h


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
