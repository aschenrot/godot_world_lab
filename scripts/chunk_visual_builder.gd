extends RefCounted

var topology_mapper: Object


func _init() -> void:
	if ClassDB.class_exists("GodotGridTopologyMapper"):
		topology_mapper = ClassDB.instantiate("GodotGridTopologyMapper") as Object


func build_visual_plan(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	if topology_mapper == null:
		push_error("GodotGridTopologyMapper is unavailable. Build and copy godot_grid.")
		return {
			"chunk_coord": chunk_coord,
			"tiles": [],
			"buckets": {},
		}

	var visual_resources: Array = topology_mapper.visual_tiles_for_logic_grid(logic_grid)
	var tiles: Array[Dictionary] = []
	var buckets: Dictionary = {}

	for resource in visual_resources:
		var tile_resource: Object = resource as Object
		var data: Dictionary = _resource_to_visual_tile_data(chunk_coord, tile_resource)
		if data["is_empty"]:
			continue

		tiles.append(data)
		var asset_key: String = data["asset_key"]
		if not buckets.has(asset_key):
			buckets[asset_key] = []
		buckets[asset_key].append(data)

	return {
		"chunk_coord": chunk_coord,
		"tiles": tiles,
		"buckets": buckets,
	}


func update_dirty_cell(_chunk_root: Node3D, _logic_grid: Variant, _cell_coord: Vector2i) -> void:
	pass


func update_visual_tiles(_chunk_root: Node3D, _visual_tile_data_array: Array) -> void:
	pass


func _resource_to_visual_tile_data(chunk_coord: Vector3i, tile_resource: Object) -> Dictionary:
	return {
		"chunk_coord": chunk_coord,
		"corner": tile_resource.corner,
		"asset_key": String(tile_resource.asset_key),
		"rotation_degrees_cw": int(tile_resource.rotation_degrees_cw),
		"mask": int(tile_resource.mask),
		"is_empty": bool(tile_resource.is_empty),
	}
