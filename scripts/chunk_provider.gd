extends Node

@export var chunk_size_cells: int = 16
@export var generator_version: int = 1
@export var world_seed: int = 1337
@export_range(0, 100, 1) var wall_threshold_percent: int = 34
@export var debug_force_chunk_border: bool = false
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
			logic_grid = generate_chunk_logic_grid(chunk_coord)
			chunk_cache.store_chunk(chunk_coord, generator_version, settings_hash, logic_grid)
	else:
		logic_grid = generate_chunk_logic_grid(chunk_coord)

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
	var grid: Array = []
	var size: int = maxi(chunk_size_cells, 4)

	for y in range(size):
		var row: Array = []
		for x in range(size):
			var cell := Vector2i(x, y)
			row.append(_cell_is_wall(chunk_coord, cell, size))
		grid.append(row)

	return grid


func make_generated_chunk_data(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	return {
		"product_type": "GeneratedChunkData",
		"chunk_coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": generation_settings_hash(),
		"logic_grid": logic_grid,
	}


func generation_settings_hash() -> int:
	var h: int = 0x2d2816fe
	h = _mix(h, world_seed)
	h = _mix(h, generator_version)
	h = _mix(h, chunk_size_cells)
	h = _mix(h, wall_threshold_percent)
	h = _mix(h, 1 if debug_force_chunk_border else 0)
	return abs(h)


func generation_diagnostics() -> Dictionary:
	return {
		"world_seed": world_seed,
		"generator_version": generator_version,
		"chunk_size_cells": chunk_size_cells,
		"wall_threshold_percent": wall_threshold_percent,
		"debug_force_chunk_border": debug_force_chunk_border,
		"generation_settings_hash": generation_settings_hash(),
	}


func get_diagnostics() -> Dictionary:
	return {
		"pending_requests": pending_request_count(),
		"loaded_chunks": loaded_chunk_count(),
		"cache_entries": cache_entry_count(),
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

	var local_noise: int = _noise_0_99(chunk_coord, cell)
	return 1 if local_noise < clampi(wall_threshold_percent, 0, 100) else 0


func _noise_0_99(chunk_coord: Vector3i, cell: Vector2i) -> int:
	var world_x: int = chunk_coord.x * chunk_size_cells + cell.x
	var world_z: int = chunk_coord.z * chunk_size_cells + cell.y
	var h: int = int(world_seed) * 0x1f123bb5
	h = _mix(h, generator_version)
	h = _mix(h, chunk_coord.x)
	h = _mix(h, chunk_coord.y)
	h = _mix(h, chunk_coord.z)
	h = _mix(h, world_x)
	h = _mix(h, world_z)
	return abs(h) % 100


func _mix(seed: int, value: int) -> int:
	var h := seed ^ (value * 0x45d9f3b)
	h = h ^ (h >> 16)
	h *= 0x45d9f3b
	h = h ^ (h >> 16)
	return h


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
