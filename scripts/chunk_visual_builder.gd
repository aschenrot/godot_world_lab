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


func build_chunk_visual(
	chunk_coord: Vector3i,
	visual_plan: Dictionary,
	catalog: RefCounted,
	chunk_edge_meters: float,
	cells_per_chunk: int,
	pooled_root: Node3D = null
) -> Node3D:
	var root: Node3D = pooled_root
	if root == null:
		root = Node3D.new()
	else:
		_clear_children(root)

	root.name = "ChunkVisual_%s_%s_%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
	root.set_meta("chunk_coord", chunk_coord)

	var cell_size_meters: float = chunk_edge_meters / float(maxi(cells_per_chunk, 1))
	root.set_meta("catalog", catalog)
	root.set_meta("cell_size_meters", cell_size_meters)
	root.set_meta("visual_tiles_by_corner", _tiles_by_corner(visual_plan.get("tiles", [])))
	root.set_meta("last_dirty_corner_count", 0)
	_rebuild_multimesh_buckets(root)

	return root


func destroy_or_pool(chunk_root: Node3D, pool: Array[Node3D], max_pool_size: int) -> void:
	if chunk_root == null:
		return

	_clear_children(chunk_root)
	chunk_root.name = "PooledChunkVisual"
	chunk_root.position = Vector3.ZERO
	chunk_root.rotation = Vector3.ZERO
	chunk_root.scale = Vector3.ONE
	_remove_meta_if_present(chunk_root, "chunk_coord")
	_remove_meta_if_present(chunk_root, "catalog")
	_remove_meta_if_present(chunk_root, "cell_size_meters")
	_remove_meta_if_present(chunk_root, "visual_tiles_by_corner")
	_remove_meta_if_present(chunk_root, "last_dirty_corner_count")

	if pool.size() < max_pool_size:
		pool.append(chunk_root)
	else:
		chunk_root.free()


func update_dirty_cell(chunk_root: Node3D, logic_grid: Array, cell_coord: Vector2i) -> int:
	if topology_mapper == null:
		push_error("GodotGridTopologyMapper is unavailable. Build and copy godot_grid.")
		return 0
	if chunk_root == null or not chunk_root.has_meta("chunk_coord"):
		return 0

	var chunk_coord: Vector3i = chunk_root.get_meta("chunk_coord")
	var visual_resources: Array = topology_mapper.visual_tiles_for_dirty_logic_cell(logic_grid, cell_coord)
	var visual_tiles: Array[Dictionary] = []
	for resource in visual_resources:
		var tile_resource: Object = resource as Object
		visual_tiles.append(_resource_to_visual_tile_data(chunk_coord, tile_resource))

	return update_visual_tiles(chunk_root, visual_tiles)


func update_visual_tiles(chunk_root: Node3D, visual_tile_data_array: Array) -> int:
	if chunk_root == null or not chunk_root.has_meta("visual_tiles_by_corner"):
		return 0

	var tiles_by_corner: Dictionary = chunk_root.get_meta("visual_tiles_by_corner")
	for tile in visual_tile_data_array:
		var data: Dictionary = tile
		var key := _corner_key(data["corner"])
		if data["is_empty"]:
			tiles_by_corner.erase(key)
		else:
			tiles_by_corner[key] = data

	chunk_root.set_meta("visual_tiles_by_corner", tiles_by_corner)
	chunk_root.set_meta("last_dirty_corner_count", visual_tile_data_array.size())
	_rebuild_multimesh_buckets(chunk_root)
	return visual_tile_data_array.size()


func _resource_to_visual_tile_data(chunk_coord: Vector3i, tile_resource: Object) -> Dictionary:
	return {
		"chunk_coord": chunk_coord,
		"corner": tile_resource.corner,
		"asset_key": String(tile_resource.asset_key),
		"rotation_degrees_cw": int(tile_resource.rotation_degrees_cw),
		"mask": int(tile_resource.mask),
		"is_empty": bool(tile_resource.is_empty),
	}


func _tile_transform(tile_data: Dictionary, cell_size_meters: float) -> Transform3D:
	var corner: Vector2i = tile_data["corner"]
	var rotation_degrees_cw: int = tile_data["rotation_degrees_cw"]
	var origin := Vector3(
		float(corner.x) * cell_size_meters,
		0.0,
		float(corner.y) * cell_size_meters
	)
	var basis := Basis(Vector3.UP, deg_to_rad(float(rotation_degrees_cw)))
	basis = basis.scaled(Vector3(cell_size_meters, 1.0, cell_size_meters))
	return Transform3D(basis, origin)


func _tiles_by_corner(tiles: Array) -> Dictionary:
	var by_corner: Dictionary = {}
	for tile in tiles:
		var data: Dictionary = tile
		if data["is_empty"]:
			continue
		by_corner[_corner_key(data["corner"])] = data
	return by_corner


func _rebuild_multimesh_buckets(root: Node3D) -> void:
	_clear_children(root)
	if not root.has_meta("catalog") or not root.has_meta("visual_tiles_by_corner"):
		return

	var catalog: RefCounted = root.get_meta("catalog")
	var cell_size_meters: float = root.get_meta("cell_size_meters")
	var visual_tiles_by_corner: Dictionary = root.get_meta("visual_tiles_by_corner")
	var transforms_by_base_key: Dictionary = {}
	var asset_key_by_base_key: Dictionary = {}

	for corner_key in visual_tiles_by_corner:
		var data: Dictionary = visual_tiles_by_corner[corner_key]
		var asset_key: String = data["asset_key"]
		var base_key: String = catalog.base_key_for_asset_key(asset_key)
		if not transforms_by_base_key.has(base_key):
			transforms_by_base_key[base_key] = []
			asset_key_by_base_key[base_key] = asset_key
		transforms_by_base_key[base_key].append(_tile_transform(data, cell_size_meters))

	var base_keys: Array = transforms_by_base_key.keys()
	base_keys.sort()
	for base_key in base_keys:
		var source_asset_key: String = asset_key_by_base_key[base_key]
		var mesh: Mesh = catalog.get_mesh(source_asset_key)
		if mesh == null:
			continue

		var transforms: Array = transforms_by_base_key[base_key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])

		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_bucket" % base_key
		instance.multimesh = multimesh
		instance.material_override = catalog.get_material(source_asset_key)
		root.add_child(instance)


func _corner_key(corner: Vector2i) -> String:
	return "%s:%s" % [corner.x, corner.y]


func _clear_children(root: Node3D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()


func _remove_meta_if_present(root: Node3D, name: StringName) -> void:
	if root.has_meta(name):
		root.remove_meta(name)
