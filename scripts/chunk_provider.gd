extends Node

@export var chunk_size_cells: int = 16
@export var generator_version: int = 1

var streaming_node: Node
var pending_requests: Dictionary = {}
var loaded_chunks: Dictionary = {}
var completed_load_count: int = 0
var completed_unload_count: int = 0


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
	pending_requests[request_id] = {
		"kind": "load",
		"chunk": chunk_coord,
	}
	loaded_chunks[_chunk_key(chunk_coord)] = {
		"coord": chunk_coord,
		"generator_version": generator_version,
		"logic_grid": generate_chunk_logic_grid(chunk_coord),
	}
	streaming_node.provider_started(request_id, x, y, z)
	streaming_node.provider_completed(request_id, x, y, z)
	pending_requests.erase(request_id)
	completed_load_count += 1


func _on_chunk_unload_requested(request_id: int, x: int, y: int, z: int) -> void:
	if streaming_node == null:
		return
	var chunk_coord := Vector3i(x, y, z)
	pending_requests[request_id] = {
		"kind": "unload",
		"chunk": chunk_coord,
	}
	streaming_node.provider_started(request_id, x, y, z)
	loaded_chunks.erase(_chunk_key(chunk_coord))
	streaming_node.provider_completed(request_id, x, y, z)
	pending_requests.erase(request_id)
	completed_unload_count += 1


func pending_request_count() -> int:
	return pending_requests.size()


func loaded_chunk_count() -> int:
	return loaded_chunks.size()


func get_loaded_chunk_logic_grid(chunk_coord: Vector3i) -> Array:
	var record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	return record.get("logic_grid", [])


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
