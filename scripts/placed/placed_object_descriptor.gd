extends RefCounted

var object_id: String = ""
var chunk_coord: Vector3i = Vector3i.ZERO
var local_position: Vector3 = Vector3.ZERO
var asset_key: String = "debug"
var rotation_degrees_y: float = 0.0
var metadata: Dictionary = {}


func configure(
	new_object_id: String,
	new_chunk_coord: Vector3i,
	new_local_position: Vector3,
	new_asset_key: String = "debug",
	new_rotation_degrees_y: float = 0.0,
	new_metadata: Dictionary = {}
) -> RefCounted:
	object_id = new_object_id
	chunk_coord = new_chunk_coord
	local_position = new_local_position
	asset_key = new_asset_key
	rotation_degrees_y = new_rotation_degrees_y
	metadata = new_metadata.duplicate(true)
	return self


func to_dictionary() -> Dictionary:
	return {
		"object_id": object_id,
		"chunk_coord": chunk_coord,
		"local_position": local_position,
		"asset_key": asset_key,
		"rotation_degrees_y": rotation_degrees_y,
		"metadata": metadata.duplicate(true),
	}
