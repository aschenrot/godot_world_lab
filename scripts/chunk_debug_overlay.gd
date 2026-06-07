extends Node3D

@export var chunk_edge_meters: float = 32.0
@export var debug_box_height: float = 1.0

var chunk_roots: Dictionary = {}
var debug_material: StandardMaterial3D


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
	root.set_meta("chunk_coord", Vector3i(x, y, z))
	root.add_child(_create_debug_box())
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


func debug_chunk_count() -> int:
	return chunk_roots.size()


func has_chunk_root(x: int, y: int, z: int) -> bool:
	return chunk_roots.has(_chunk_key(x, y, z))


func active_chunk_keys() -> Array:
	var keys := chunk_roots.keys()
	keys.sort()
	return keys


func _create_debug_box() -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(chunk_edge_meters, debug_box_height, chunk_edge_meters)

	var instance := MeshInstance3D.new()
	instance.name = "DebugBox"
	instance.mesh = mesh
	instance.position = Vector3(chunk_edge_meters * 0.5, debug_box_height * 0.5, chunk_edge_meters * 0.5)
	instance.material_override = _get_debug_material()
	return instance


func _get_debug_material() -> StandardMaterial3D:
	if debug_material == null:
		debug_material = StandardMaterial3D.new()
		debug_material.albedo_color = Color(0.2, 0.7, 1.0, 0.24)
		debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return debug_material
