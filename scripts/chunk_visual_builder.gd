extends RefCounted

var topology_mapper: Object


func _init() -> void:
	if ClassDB.class_exists("GodotGridTopologyMapper"):
		topology_mapper = ClassDB.instantiate("GodotGridTopologyMapper") as Object


func build_visual_plan(chunk_coord: Vector3i, logic_grid: Array, catalog: RefCounted = null) -> Dictionary:
	if topology_mapper == null:
		return _unavailable_mapper_plan(chunk_coord)

	var visual_resources: Array = topology_mapper.visual_tiles_for_logic_grid(logic_grid)
	return _build_plan_from_visual_resources(
		chunk_coord,
		visual_resources,
		catalog,
		{
			"formation_mode": "local_no_halo",
			"formation_origin_cell": Vector2i.ZERO,
			"owned_visual_origin": Vector2i.ZERO,
			"owned_visual_size": _visual_grid_size_for_logic_grid(logic_grid),
		}
	)


func build_owned_visual_plan(
	chunk_coord: Vector3i,
	formation_grid: Array,
	formation_origin_cell: Vector2i,
	owned_visual_origin: Vector2i,
	owned_visual_size: Vector2i,
	catalog: RefCounted = null
) -> Dictionary:
	if topology_mapper == null:
		return _unavailable_mapper_plan(chunk_coord)

	var visual_resources: Array = topology_mapper.visual_tiles_for_logic_grid(formation_grid)
	var crop_min := owned_visual_origin - formation_origin_cell
	var crop_max_exclusive := crop_min + owned_visual_size
	return _build_plan_from_visual_resources(
		chunk_coord,
		visual_resources,
		catalog,
		{
			"formation_mode": "owned_halo",
			"formation_origin_cell": formation_origin_cell,
			"owned_visual_origin": owned_visual_origin,
			"owned_visual_size": owned_visual_size,
			"crop_min": crop_min,
			"crop_max_exclusive": crop_max_exclusive,
		}
	)


func build_visual_plan_from_generated_chunk(
	generated_chunk_data: Dictionary,
	catalog: RefCounted = null
) -> Dictionary:
	if generated_chunk_data.has("formation_grid"):
		return build_owned_visual_plan(
			generated_chunk_data["chunk_coord"],
			generated_chunk_data["formation_grid"],
			generated_chunk_data.get("formation_origin_cell", Vector2i(-1, -1)),
			generated_chunk_data.get("owned_visual_origin", Vector2i.ZERO),
			generated_chunk_data.get("owned_visual_size", _visual_grid_size_for_logic_grid(
				generated_chunk_data["logic_grid"]
			)),
			catalog
		)

	return build_visual_plan(
		generated_chunk_data["chunk_coord"],
		generated_chunk_data["logic_grid"],
		catalog
	)


func build_instantiation_plan(
	chunk_coord: Vector3i,
	visual_plan: Dictionary,
	catalog: RefCounted,
	visual_backend: String = "multimesh"
) -> Dictionary:
	var visual_tiles: Array = visual_plan.get("visual_tiles", visual_plan.get("tiles", []))
	var multimesh_buckets: Dictionary = {}
	for tile in visual_tiles:
		var data: Dictionary = tile
		var asset_key: String = data["asset_key"]
		var base_key: String = catalog.base_key_for_asset_key(asset_key)
		if not multimesh_buckets.has(base_key):
			multimesh_buckets[base_key] = {
				"base_key": base_key,
				"source_asset_key": asset_key,
				"instance_count": 0,
			}
		multimesh_buckets[base_key]["instance_count"] += 1

	return {
		"product_type": "ChunkInstantiationPlan",
		"chunk_coord": chunk_coord,
		"visual_backend": visual_backend,
		"multimesh_buckets": multimesh_buckets,
		"root_metadata": {
			"chunk_coord": chunk_coord,
			"visual_backend": visual_backend,
			"visual_tile_count": visual_tiles.size(),
		},
		"diagnostics": {
			"visual_tile_count": visual_tiles.size(),
			"bucket_count": multimesh_buckets.size(),
			"visual_plan_valid": visual_plan.get("diagnostics", {}).get("is_valid", true),
		},
		"visual_tiles": visual_tiles,
		"chunk_visual_plan": visual_plan,
	}


func build_chunk_visual(
	chunk_coord: Vector3i,
	visual_plan: Dictionary,
	catalog: RefCounted,
	chunk_edge_meters: float,
	cells_per_chunk: int,
	pooled_root: Node3D = null
) -> Node3D:
	var instantiation_plan := build_instantiation_plan(chunk_coord, visual_plan, catalog, "multimesh")
	return build_chunk_visual_from_instantiation_plan(
		instantiation_plan,
		catalog,
		chunk_edge_meters,
		cells_per_chunk,
		pooled_root
	)


func build_chunk_visual_from_instantiation_plan(
	instantiation_plan: Dictionary,
	catalog: RefCounted,
	chunk_edge_meters: float,
	cells_per_chunk: int,
	pooled_root: Node3D = null
) -> Node3D:
	var chunk_coord: Vector3i = instantiation_plan["chunk_coord"]
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
	root.set_meta("visual_tiles_by_corner", _tiles_by_corner(instantiation_plan.get("visual_tiles", [])))
	root.set_meta("visual_tile_count", int(instantiation_plan.get("visual_tiles", []).size()))
	root.set_meta("visual_backend", instantiation_plan["visual_backend"])
	root.set_meta("chunk_instantiation_plan", instantiation_plan)
	root.set_meta("last_dirty_corner_count", 0)
	_rebuild_multimesh_buckets(root)

	return root


func build_chunk_visual_array_mesh(
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

	root.name = "ChunkArrayVisual_%s_%s_%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
	root.set_meta("chunk_coord", chunk_coord)
	root.set_meta("catalog", catalog)
	var cell_size_meters: float = chunk_edge_meters / float(maxi(cells_per_chunk, 1))
	root.set_meta("cell_size_meters", cell_size_meters)
	root.set_meta("visual_tiles_by_corner", _tiles_by_corner(visual_plan.get("visual_tiles", visual_plan.get("tiles", []))))
	root.set_meta("visual_tile_count", int(visual_plan.get("visual_tiles", visual_plan.get("tiles", [])).size()))
	root.set_meta("visual_backend", "array_mesh")
	root.set_meta("last_dirty_corner_count", 0)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "array_mesh_bucket"
	mesh_instance.mesh = _build_array_mesh(visual_plan.get("visual_tiles", visual_plan.get("tiles", [])), cell_size_meters)
	mesh_instance.material_override = catalog.get_material("debug")
	root.add_child(mesh_instance)
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
	_remove_meta_if_present(chunk_root, "visual_tile_count")
	_remove_meta_if_present(chunk_root, "visual_backend")
	_remove_meta_if_present(chunk_root, "chunk_instantiation_plan")
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


func _unavailable_mapper_plan(chunk_coord: Vector3i) -> Dictionary:
	push_error("GodotGridTopologyMapper is unavailable. Build and copy godot_grid.")
	return {
		"product_type": "ChunkVisualPlan",
		"chunk_coord": chunk_coord,
		"visual_tiles": [],
		"tiles": [],
		"asset_keys": [],
		"missing_assets": [],
		"bounds": {},
		"diagnostics": {
			"is_valid": false,
			"error": "GodotGridTopologyMapper unavailable",
		},
		"buckets": {},
	}


func _build_plan_from_visual_resources(
	chunk_coord: Vector3i,
	visual_resources: Array,
	catalog: RefCounted,
	options: Dictionary
) -> Dictionary:
	var formation_mode: String = options.get("formation_mode", "local_no_halo")
	var formation_origin_cell: Vector2i = options.get("formation_origin_cell", Vector2i.ZERO)
	var owned_visual_origin: Vector2i = options.get("owned_visual_origin", Vector2i.ZERO)
	var owned_visual_size: Vector2i = options.get("owned_visual_size", Vector2i.ZERO)
	var crop_enabled := options.has("crop_min") and options.has("crop_max_exclusive")
	var crop_min: Vector2i = options.get("crop_min", Vector2i.ZERO)
	var crop_max_exclusive: Vector2i = options.get("crop_max_exclusive", Vector2i.ZERO)

	var tiles: Array[Dictionary] = []
	var buckets: Dictionary = {}
	var asset_keys_seen: Dictionary = {}
	var skipped_empty_count := 0
	var cropped_corner_count := 0
	var emitted_out_of_bounds_count := 0
	var bounds := _empty_bounds()

	for resource in visual_resources:
		var tile_resource: Object = resource as Object
		var formation_corner: Vector2i = tile_resource.corner
		if crop_enabled and not _corner_inside_rect(formation_corner, crop_min, crop_max_exclusive):
			continue

		cropped_corner_count += 1
		var local_corner := formation_corner + formation_origin_cell
		var data: Dictionary = _resource_to_visual_tile_data(chunk_coord, tile_resource)
		data["formation_mode"] = formation_mode
		data["formation_corner"] = formation_corner
		data["corner"] = local_corner
		data["world_corner"] = _world_corner_for_local_corner(
			chunk_coord,
			local_corner,
			owned_visual_size
		)

		if not _corner_inside_owned_rect(local_corner, owned_visual_origin, owned_visual_size):
			emitted_out_of_bounds_count += 1

		if data["is_empty"]:
			skipped_empty_count += 1
			continue

		tiles.append(data)
		_expand_bounds(bounds, data["corner"])
		var asset_key: String = data["asset_key"]
		asset_keys_seen[asset_key] = true
		if not buckets.has(asset_key):
			buckets[asset_key] = []
		buckets[asset_key].append(data)

	var asset_keys := asset_keys_seen.keys()
	asset_keys.sort()
	var diagnostics := {
		"is_valid": emitted_out_of_bounds_count == 0,
		"formation_mode": formation_mode,
		"formation_origin_cell": formation_origin_cell,
		"owned_visual_origin": owned_visual_origin,
		"owned_visual_size": owned_visual_size,
		"total_visual_corners": visual_resources.size(),
		"cropped_visual_corners": cropped_corner_count,
		"non_empty_visual_tiles": tiles.size(),
		"skipped_empty_visual_tiles": skipped_empty_count,
		"emitted_out_of_bounds_corners": emitted_out_of_bounds_count,
		"asset_key_count": asset_keys.size(),
	}
	var missing_assets: Array = []
	if catalog != null:
		var validation: Dictionary = catalog.validate_visual_plan({"visual_tiles": tiles})
		missing_assets = validation["missing_asset_keys"]
		diagnostics["is_valid"] = bool(diagnostics["is_valid"]) and bool(validation["is_valid"])
		diagnostics["catalog_validation"] = validation

	return {
		"product_type": "ChunkVisualPlan",
		"chunk_coord": chunk_coord,
		"formation_mode": formation_mode,
		"formation_origin_cell": formation_origin_cell,
		"owned_visual_origin": owned_visual_origin,
		"owned_visual_size": owned_visual_size,
		"visual_tiles": tiles,
		"tiles": tiles,
		"asset_keys": asset_keys,
		"missing_assets": missing_assets,
		"bounds": bounds,
		"diagnostics": diagnostics,
		"buckets": buckets,
	}


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
	# Grid rotations are clockwise in X/Y-down space; Godot yaw is opposite once Y maps to +Z.
	var basis := Basis(Vector3.UP, deg_to_rad(float(-rotation_degrees_cw)))
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


func _empty_bounds() -> Dictionary:
	return {
		"has_tiles": false,
		"min_corner": Vector2i.ZERO,
		"max_corner": Vector2i.ZERO,
	}


func _expand_bounds(bounds: Dictionary, corner: Vector2i) -> void:
	if not bounds["has_tiles"]:
		bounds["has_tiles"] = true
		bounds["min_corner"] = corner
		bounds["max_corner"] = corner
		return

	var min_corner: Vector2i = bounds["min_corner"]
	var max_corner: Vector2i = bounds["max_corner"]
	bounds["min_corner"] = Vector2i(mini(min_corner.x, corner.x), mini(min_corner.y, corner.y))
	bounds["max_corner"] = Vector2i(maxi(max_corner.x, corner.x), maxi(max_corner.y, corner.y))


func _corner_inside_rect(corner: Vector2i, min_corner: Vector2i, max_exclusive: Vector2i) -> bool:
	return (
		corner.x >= min_corner.x
		and corner.y >= min_corner.y
		and corner.x < max_exclusive.x
		and corner.y < max_exclusive.y
	)


func _corner_inside_owned_rect(
	corner: Vector2i,
	owned_visual_origin: Vector2i,
	owned_visual_size: Vector2i
) -> bool:
	return _corner_inside_rect(corner, owned_visual_origin, owned_visual_origin + owned_visual_size)


func _world_corner_for_local_corner(
	chunk_coord: Vector3i,
	local_corner: Vector2i,
	owned_visual_size: Vector2i
) -> Vector2i:
	return Vector2i(
		chunk_coord.x * owned_visual_size.x + local_corner.x,
		chunk_coord.z * owned_visual_size.y + local_corner.y
	)


func _visual_grid_size_for_logic_grid(logic_grid: Array) -> Vector2i:
	var height := logic_grid.size()
	var width := 0
	for row in logic_grid:
		width = maxi(width, int(row.size()))
	return Vector2i(width + 1, height + 1)


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


func _build_array_mesh(tiles: Array, cell_size_meters: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for tile in tiles:
		var data: Dictionary = tile
		if data["is_empty"]:
			continue
		_append_tile_quad(vertices, normals, indices, data, cell_size_meters)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_tile_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	tile_data: Dictionary,
	cell_size_meters: float
) -> void:
	var index_start := vertices.size()
	var half_size := cell_size_meters * 0.45
	var transform := _tile_transform(tile_data, cell_size_meters)
	var local_vertices := [
		Vector3(-half_size, 0.04, -half_size),
		Vector3(half_size, 0.04, -half_size),
		Vector3(half_size, 0.04, half_size),
		Vector3(-half_size, 0.04, half_size),
	]

	for local_vertex in local_vertices:
		vertices.append(transform * local_vertex)
		normals.append(Vector3.UP)

	indices.append(index_start)
	indices.append(index_start + 1)
	indices.append(index_start + 2)
	indices.append(index_start)
	indices.append(index_start + 2)
	indices.append(index_start + 3)


func _corner_key(corner: Vector2i) -> String:
	return "%s:%s" % [corner.x, corner.y]


func _clear_children(root: Node3D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()


func _remove_meta_if_present(root: Node3D, name: StringName) -> void:
	if root.has_meta(name):
		root.remove_meta(name)
