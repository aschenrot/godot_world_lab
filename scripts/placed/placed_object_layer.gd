extends RefCounted

const LAYER_NODE_NAME := "PlacedObjectLayer"

var descriptors_by_chunk_key: Dictionary = {}


func set_chunk_descriptors(chunk_coord: Vector3i, descriptors: Array) -> void:
	descriptors_by_chunk_key[_chunk_key(chunk_coord)] = _duplicate_descriptors(descriptors)


func get_chunk_descriptors(chunk_coord: Vector3i) -> Array:
	return _duplicate_descriptors(descriptors_by_chunk_key.get(_chunk_key(chunk_coord), []))


func generate_lab_descriptors_for_chunk(chunk_coord: Vector3i, chunk_edge_meters: float) -> Array:
	var Descriptor := load("res://scripts/placed/placed_object_descriptor.gd")
	var descriptors: Array = []
	var parity: int = abs(chunk_coord.x * 31 + chunk_coord.z * 17) % 3
	if parity != 0:
		return descriptors

	var descriptor: RefCounted = Descriptor.new().configure(
		"marker_%s_%s_%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z],
		chunk_coord,
		Vector3(chunk_edge_meters * 0.5, 0.9, chunk_edge_meters * 0.5),
		"debug",
		float((chunk_coord.x - chunk_coord.z) * 45),
		{"source": "lab_deterministic_marker"}
	)
	descriptors.append(descriptor)
	return descriptors


func build_chunk_layer(chunk_coord: Vector3i, descriptors: Array, catalog: RefCounted) -> Node3D:
	var layer := Node3D.new()
	layer.name = LAYER_NODE_NAME
	layer.set_meta("chunk_coord", chunk_coord)
	layer.set_meta("descriptor_count", descriptors.size())
	layer.set_meta("layer_kind", "placed_objects")
	rebuild_chunk_layer(layer, descriptors, catalog)
	return layer


func rebuild_chunk_layer(layer: Node3D, descriptors: Array, catalog: RefCounted) -> void:
	_clear_children(layer)
	for descriptor in descriptors:
		var data := _descriptor_to_dictionary(descriptor)
		var object := MeshInstance3D.new()
		object.name = "Placed_%s" % data["object_id"]
		object.mesh = catalog.get_mesh(data["asset_key"])
		object.material_override = catalog.get_material(data["asset_key"])
		object.position = data["local_position"]
		object.rotation = Vector3(0.0, deg_to_rad(float(data["rotation_degrees_y"])), 0.0)
		object.set_meta("placed_object_descriptor", data)
		layer.add_child(object)
	layer.set_meta("descriptor_count", descriptors.size())


func get_layer_diagnostics(layer: Node3D) -> Dictionary:
	if layer == null:
		return {
			"has_layer": false,
			"placed_object_count": 0,
		}
	return {
		"has_layer": true,
		"chunk_coord": layer.get_meta("chunk_coord", Vector3i.ZERO),
		"placed_object_count": layer.get_child_count(),
		"descriptor_count": int(layer.get_meta("descriptor_count", 0)),
	}


func _descriptor_to_dictionary(descriptor) -> Dictionary:
	if descriptor is Dictionary:
		return (descriptor as Dictionary).duplicate(true)
	if descriptor != null and descriptor.has_method("to_dictionary"):
		return descriptor.to_dictionary()
	return {}


func _duplicate_descriptors(descriptors: Array) -> Array:
	var copy: Array = []
	for descriptor in descriptors:
		if descriptor is Dictionary:
			copy.append((descriptor as Dictionary).duplicate(true))
		else:
			copy.append(descriptor)
	return copy


func _clear_children(layer: Node3D) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.free()


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
