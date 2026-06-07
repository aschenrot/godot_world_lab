extends Node3D

@export var chunk_edge_meters: float = 32.0

var chunk_roots: Dictionary = {}


func bind_streaming_node(streaming_node: Node) -> void:
	if streaming_node == null:
		return

	streaming_node.chunk_resident.connect(_on_chunk_resident)
	streaming_node.chunk_unloaded.connect(_on_chunk_unloaded)


func _on_chunk_resident(x: int, y: int, z: int) -> void:
	var key := _chunk_key(x, y, z)
	if chunk_roots.has(key):
		return

	var root := Node3D.new()
	root.name = "Chunk_%s_%s_%s" % [x, y, z]
	root.position = Vector3(x * chunk_edge_meters, y * chunk_edge_meters, z * chunk_edge_meters)
	add_child(root)
	chunk_roots[key] = root


func _on_chunk_unloaded(x: int, y: int, z: int) -> void:
	var key := _chunk_key(x, y, z)
	var root: Node = chunk_roots.get(key)
	if root != null:
		root.queue_free()
	chunk_roots.erase(key)


func _chunk_key(x: int, y: int, z: int) -> String:
	return "%s:%s:%s" % [x, y, z]

