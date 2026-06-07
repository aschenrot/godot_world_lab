extends Node

var streaming_node: Node


func bind_streaming_node(node: Node) -> void:
	streaming_node = node
	if streaming_node == null:
		return

	streaming_node.chunk_load_requested.connect(_on_chunk_load_requested)
	streaming_node.chunk_unload_requested.connect(_on_chunk_unload_requested)


func _on_chunk_load_requested(request_id: int, x: int, y: int, z: int) -> void:
	if streaming_node == null:
		return
	streaming_node.provider_started(request_id, x, y, z)
	streaming_node.provider_completed(request_id, x, y, z)


func _on_chunk_unload_requested(request_id: int, x: int, y: int, z: int) -> void:
	if streaming_node == null:
		return
	streaming_node.provider_started(request_id, x, y, z)
	streaming_node.provider_completed(request_id, x, y, z)

