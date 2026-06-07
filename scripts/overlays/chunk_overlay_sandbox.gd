extends RefCounted

const OVERLAY_NODE_NAME := "ChunkOverlay"

var overlays_by_chunk_key: Dictionary = {}


func set_overlay_value(chunk_coord: Vector3i, key: String, value) -> void:
	var overlay := get_chunk_overlay(chunk_coord)
	overlay[key] = value
	overlays_by_chunk_key[_chunk_key(chunk_coord)] = overlay


func get_overlay_value(chunk_coord: Vector3i, key: String, default_value = null):
	return get_chunk_overlay(chunk_coord).get(key, default_value)


func get_chunk_overlay(chunk_coord: Vector3i) -> Dictionary:
	return overlays_by_chunk_key.get(_chunk_key(chunk_coord), {}).duplicate(true)


func clear_chunk_overlay(chunk_coord: Vector3i) -> void:
	overlays_by_chunk_key.erase(_chunk_key(chunk_coord))


func overlay_entry_count() -> int:
	return overlays_by_chunk_key.size()


func apply_overlay_to_chunk_root(chunk_root: Node3D, chunk_coord: Vector3i) -> Node3D:
	if chunk_root == null:
		return null

	var existing := _find_overlay_node(chunk_root)
	if existing != null:
		chunk_root.remove_child(existing)
		existing.free()

	var overlay := get_chunk_overlay(chunk_coord)
	var overlay_node := Node3D.new()
	overlay_node.name = OVERLAY_NODE_NAME
	overlay_node.set_meta("chunk_coord", chunk_coord)
	overlay_node.set_meta("overlay_data", overlay)
	overlay_node.set_meta("overlay_key_count", overlay.size())
	chunk_root.add_child(overlay_node)
	return overlay_node


func get_overlay_diagnostics(chunk_root: Node3D) -> Dictionary:
	var overlay_node := _find_overlay_node(chunk_root)
	if overlay_node == null:
		return {
			"has_overlay_node": false,
			"overlay_key_count": 0,
		}
	return {
		"has_overlay_node": true,
		"chunk_coord": overlay_node.get_meta("chunk_coord", Vector3i.ZERO),
		"overlay_key_count": int(overlay_node.get_meta("overlay_key_count", 0)),
		"overlay_data": overlay_node.get_meta("overlay_data", {}),
	}


func _find_overlay_node(chunk_root: Node3D) -> Node3D:
	for child in chunk_root.get_children():
		if child is Node3D and child.name == OVERLAY_NODE_NAME:
			return child as Node3D
	return null


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
