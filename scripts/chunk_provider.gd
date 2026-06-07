extends Node

var streaming_node: Node
var pending_requests: Dictionary = {}
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
	pending_requests[request_id] = {
		"kind": "load",
		"chunk": Vector3i(x, y, z),
	}
	streaming_node.provider_started(request_id, x, y, z)
	streaming_node.provider_completed(request_id, x, y, z)
	pending_requests.erase(request_id)
	completed_load_count += 1


func _on_chunk_unload_requested(request_id: int, x: int, y: int, z: int) -> void:
	if streaming_node == null:
		return
	pending_requests[request_id] = {
		"kind": "unload",
		"chunk": Vector3i(x, y, z),
	}
	streaming_node.provider_started(request_id, x, y, z)
	streaming_node.provider_completed(request_id, x, y, z)
	pending_requests.erase(request_id)
	completed_unload_count += 1


func pending_request_count() -> int:
	return pending_requests.size()
