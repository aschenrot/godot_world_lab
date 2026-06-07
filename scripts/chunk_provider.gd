extends Node

@export var chunk_size_cells: int = 16
@export var generator_version: int = 1
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


func get_loaded_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	var record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	return record.get("logic_grid", [])


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
	if use_chunk_cache:
		_ensure_cache()
		if chunk_cache.has_chunk(chunk_coord, generator_version):
			cache_hit_count += 1
			logic_grid = chunk_cache.load_chunk(chunk_coord, generator_version)
		else:
			cache_miss_count += 1
			logic_grid = generate_chunk_logic_grid(chunk_coord)
			chunk_cache.store_chunk(chunk_coord, generator_version, logic_grid)
	else:
		logic_grid = generate_chunk_logic_grid(chunk_coord)

	loaded_chunks[_chunk_key(chunk_coord)] = {
		"coord": chunk_coord,
		"generator_version": generator_version,
		"logic_grid": logic_grid,
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


func _cell_is_wall(chunk_coord: Vector3i, cell: Vector2i, size: int) -> int:
	if cell.x == 0 or cell.y == 0 or cell.x == size - 1 or cell.y == size - 1:
		return 1

	var local_noise: int = _noise_0_99(chunk_coord, cell)
	var room_band: bool = (
		abs(cell.x - cell.y) <= 1
		and _noise_0_99(chunk_coord, Vector2i(cell.y, cell.x)) < 72
	)
	if room_band:
		return 0

	return 1 if local_noise < 34 else 0


func _noise_0_99(chunk_coord: Vector3i, cell: Vector2i) -> int:
	var h := int(generator_version) * 0x1f123bb5
	h = _mix(h, chunk_coord.x)
	h = _mix(h, chunk_coord.y)
	h = _mix(h, chunk_coord.z)
	h = _mix(h, cell.x)
	h = _mix(h, cell.y)
	return abs(h) % 100


func _mix(seed: int, value: int) -> int:
	var h := seed ^ (value * 0x45d9f3b)
	h = h ^ (h >> 16)
	h *= 0x45d9f3b
	h = h ^ (h >> 16)
	return h


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
