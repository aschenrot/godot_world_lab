extends RefCounted

const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"

var topology_mapper: Object


func _init() -> void:
	if ClassDB.class_exists("GodotGridTopologyMapper"):
		topology_mapper = ClassDB.instantiate("GodotGridTopologyMapper") as Object


func host_adapter_contract() -> Dictionary:
	return {
		"product_type": "GodotHostAdapterContract",
		"adapter_id": "chunk_visual_builder",
		"host_surface": "visual",
		"consumes": PackedStringArray([
			"GeneratedChunkData.formation_layers",
			"GeneratedChunkData.formation_grid",
			"GeneratedChunkData.topology_layers.solid",
			"GeneratedChunkData.logic_grid_compatibility_alias",
		]),
		"produces": PackedStringArray([
			"ChunkVisualPlan",
			"ChunkInstantiationPlan",
			"Node3D visual realization",
		]),
		"owns_generation_truth": false,
		"non_ownership": PackedStringArray([
			"world definition",
			"semantic layers",
			"topology projections",
			"formation products",
			"diagnostics provenance",
			"chunk cache identity",
			"save records",
			"spawning",
			"ECS",
		]),
	}


func build_visual_plan(chunk_coord: Vector3i, logic_grid: Array, catalog: RefCounted = null) -> Dictionary:
	if topology_mapper == null:
		return _unavailable_mapper_plan(chunk_coord)

	var visual_resources: Array = topology_mapper.visual_tiles_for_logic_grid(logic_grid)
	var layer_plan := _build_layer_plan_from_visual_resources(
		chunk_coord,
		visual_resources,
		catalog,
		_solid_layer_spec(),
		{
			"formation_mode": "local_no_halo",
			"formation_origin_cell": Vector2i.ZERO,
			"owned_visual_origin": Vector2i.ZERO,
			"owned_visual_size": _visual_grid_size_for_logic_grid(logic_grid),
		}
	)
	return _chunk_plan_from_layers(chunk_coord, [layer_plan], catalog)


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
	var layer_plan := _build_layer_plan_from_visual_resources(
		chunk_coord,
		visual_resources,
		catalog,
		_solid_layer_spec(),
		{
			"formation_mode": "owned_halo",
			"formation_origin_cell": formation_origin_cell,
			"owned_visual_origin": owned_visual_origin,
			"owned_visual_size": owned_visual_size,
			"crop_min": crop_min,
			"crop_max_exclusive": crop_max_exclusive,
		}
	)
	return _chunk_plan_from_layers(chunk_coord, [layer_plan], catalog)


func build_visual_plan_from_generated_chunk(
	generated_chunk_data: Dictionary,
	catalog: RefCounted = null
) -> Dictionary:
	if generated_chunk_data.has("formation_layers"):
		return _attach_generated_chunk_source_metadata(
			_build_layered_visual_plan_from_generated_chunk(generated_chunk_data, catalog),
			generated_chunk_data,
			PackedStringArray(["formation_layers"])
		)

	if generated_chunk_data.has("formation_grid"):
		return _attach_generated_chunk_source_metadata(
			build_owned_visual_plan(
				generated_chunk_data["chunk_coord"],
				generated_chunk_data["formation_grid"],
				generated_chunk_data.get("formation_origin_cell", Vector2i(-1, -1)),
				generated_chunk_data.get("owned_visual_origin", Vector2i.ZERO),
				generated_chunk_data.get(
					"owned_visual_size",
					_visual_grid_size_for_logic_grid(generated_chunk_data.get("formation_grid", []))
				),
				catalog
			),
			generated_chunk_data,
			PackedStringArray([
				"formation_grid",
				"formation_origin_cell",
				"owned_visual_origin",
				"owned_visual_size",
			])
		)

	var topology_layers: Dictionary = generated_chunk_data.get("topology_layers", {})
	if topology_layers.has(LAYER_SOLID):
		return _attach_generated_chunk_source_metadata(
			build_visual_plan(
				generated_chunk_data["chunk_coord"],
				topology_layers[LAYER_SOLID],
				catalog
			),
			generated_chunk_data,
			PackedStringArray(["topology_layers.solid"])
		)

	return _attach_generated_chunk_source_metadata(
		build_visual_plan(
			generated_chunk_data["chunk_coord"],
			generated_chunk_data["logic_grid"],
			catalog
		),
		generated_chunk_data,
		PackedStringArray(["logic_grid"])
	)


func build_instantiation_plan(
	chunk_coord: Vector3i,
	visual_plan: Dictionary,
	catalog: RefCounted,
	visual_backend: String = "multimesh"
) -> Dictionary:
	var visual_tiles: Array = visual_plan.get("visual_tiles", visual_plan.get("tiles", []))
	var multimesh_buckets: Dictionary = {}
	var bucket_count := 0
	for tile in visual_tiles:
		var data: Dictionary = tile
		var layer_id := String(data.get("layer_id", LAYER_SOLID))
		var asset_key: String = data["asset_key"]
		var base_key: String = catalog.base_key_for_asset_key(asset_key)
		var material_variant := String(data.get("material_variant", layer_id))
		if not multimesh_buckets.has(layer_id):
			multimesh_buckets[layer_id] = {}
		if not multimesh_buckets[layer_id].has(base_key):
			multimesh_buckets[layer_id][base_key] = {
				"layer_id": layer_id,
				"base_key": base_key,
				"source_asset_key": asset_key,
				"material_variant": material_variant,
				"instance_count": 0,
			}
			bucket_count += 1
		multimesh_buckets[layer_id][base_key]["instance_count"] += 1

	return {
		"product_type": "ChunkInstantiationPlan",
		"chunk_coord": chunk_coord,
		"visual_backend": visual_backend,
		"multimesh_buckets": multimesh_buckets,
		"root_metadata": {
			"chunk_coord": chunk_coord,
			"visual_backend": visual_backend,
			"visual_tile_count": visual_tiles.size(),
			"visual_layer_count": visual_plan.get("visual_layers", []).size(),
			"missing_assets": visual_plan.get("missing_assets", []),
		},
		"diagnostics": {
			"visual_tile_count": visual_tiles.size(),
			"visual_layer_count": visual_plan.get("visual_layers", []).size(),
			"bucket_count": bucket_count,
			"visual_plan_valid": visual_plan.get("diagnostics", {}).get("is_valid", true),
			"effective_rotation_count": _effective_rotation_count(visual_tiles),
		},
		"visual_tiles": visual_tiles,
		"visual_layers": visual_plan.get("visual_layers", []),
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
	root.set_meta("visual_layer_count", int(instantiation_plan.get("visual_layers", []).size()))
	root.set_meta("visual_backend", instantiation_plan["visual_backend"])
	root.set_meta("chunk_instantiation_plan", instantiation_plan)
	root.set_meta("last_dirty_corner_count", 0)
	root.set_meta("last_dirty_bucket_rebuild_count", 0)
	root.set_meta("last_visual_plan_time_us", int(instantiation_plan.get("diagnostics", {}).get("visual_plan_time_us", 0)))
	root.set_meta("last_visual_bucket_build_time_us", 0)
	root.set_meta("last_visual_node_attach_time_us", 0)
	root.set_meta("last_visual_bucket_count", 0)
	root.set_meta("last_visual_instance_count", 0)
	root.set_meta("last_visual_child_count", 0)
	root.set_meta("last_visual_skipped_empty_tile_count", 0)
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
	root.set_meta("visual_layer_count", int(visual_plan.get("visual_layers", []).size()))
	root.set_meta("visual_backend", "array_mesh")
	root.set_meta("last_dirty_corner_count", 0)
	root.set_meta("last_dirty_bucket_rebuild_count", 0)
	root.set_meta("last_visual_plan_time_us", 0)
	root.set_meta("last_visual_bucket_build_time_us", 0)
	root.set_meta("last_visual_node_attach_time_us", 0)
	root.set_meta("last_visual_bucket_count", 1)
	root.set_meta("last_visual_instance_count", 0)
	root.set_meta("last_visual_child_count", 1)
	root.set_meta("last_visual_skipped_empty_tile_count", 0)

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
	_remove_meta_if_present(chunk_root, "visual_layer_count")
	_remove_meta_if_present(chunk_root, "visual_backend")
	_remove_meta_if_present(chunk_root, "chunk_instantiation_plan")
	_remove_meta_if_present(chunk_root, "last_dirty_corner_count")
	_remove_meta_if_present(chunk_root, "last_dirty_bucket_rebuild_count")
	_remove_meta_if_present(chunk_root, "last_visual_plan_time_us")
	_remove_meta_if_present(chunk_root, "last_visual_bucket_build_time_us")
	_remove_meta_if_present(chunk_root, "last_visual_node_attach_time_us")
	_remove_meta_if_present(chunk_root, "last_visual_bucket_count")
	_remove_meta_if_present(chunk_root, "last_visual_instance_count")
	_remove_meta_if_present(chunk_root, "last_visual_child_count")
	_remove_meta_if_present(chunk_root, "last_visual_skipped_empty_tile_count")

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
	var catalog: RefCounted = chunk_root.get_meta("catalog", null)
	for resource in visual_resources:
		var tile_resource: Object = resource as Object
		visual_tiles.append(_resource_to_visual_tile_data(chunk_coord, tile_resource, catalog, _solid_layer_spec()))

	return update_visual_tiles(chunk_root, visual_tiles)


func update_visual_tiles(chunk_root: Node3D, visual_tile_data_array: Array) -> int:
	if chunk_root == null or not chunk_root.has_meta("visual_tiles_by_corner"):
		return 0

	var tiles_by_corner: Dictionary = chunk_root.get_meta("visual_tiles_by_corner")
	var affected_bucket_keys: Dictionary = {}
	var catalog: RefCounted = chunk_root.get_meta("catalog", null)
	for tile in visual_tile_data_array:
		var data: Dictionary = tile
		var key := _tile_storage_key(data)
		if tiles_by_corner.has(key):
			affected_bucket_keys[_bucket_key_for_tile(tiles_by_corner[key], catalog)] = true
		if data["is_empty"]:
			tiles_by_corner.erase(key)
		else:
			tiles_by_corner[key] = data
			affected_bucket_keys[_bucket_key_for_tile(data, catalog)] = true

	chunk_root.set_meta("visual_tiles_by_corner", tiles_by_corner)
	chunk_root.set_meta("last_dirty_corner_count", visual_tile_data_array.size())
	var rebuilt_bucket_count := _rebuild_multimesh_buckets(chunk_root, affected_bucket_keys)
	chunk_root.set_meta("last_dirty_bucket_rebuild_count", rebuilt_bucket_count)
	return visual_tile_data_array.size()


func _build_layered_visual_plan_from_generated_chunk(
	generated_chunk_data: Dictionary,
	catalog: RefCounted
) -> Dictionary:
	if topology_mapper == null:
		return _unavailable_mapper_plan(generated_chunk_data.get("chunk_coord", Vector3i.ZERO))

	var chunk_coord: Vector3i = generated_chunk_data["chunk_coord"]
	var formation_layers: Dictionary = generated_chunk_data.get("formation_layers", {})
	var layer_plans: Array[Dictionary] = []
	for spec in _visual_layer_specs():
		var layer_id := String(spec["layer_id"])
		if not formation_layers.has(layer_id):
			continue
		var formation: Dictionary = formation_layers[layer_id]
		var formation_grid: Array = formation.get("formation_grid", [])
		var visual_resources: Array = topology_mapper.visual_tiles_for_logic_grid(formation_grid)
		var formation_origin_cell: Vector2i = formation.get("formation_origin_cell", Vector2i(-1, -1))
		var owned_visual_origin: Vector2i = formation.get("owned_visual_origin", Vector2i.ZERO)
		var owned_visual_size: Vector2i = formation.get("owned_visual_size", Vector2i.ZERO)
		var crop_min := owned_visual_origin - formation_origin_cell
		var crop_max_exclusive := crop_min + owned_visual_size
		layer_plans.append(_build_layer_plan_from_visual_resources(
			chunk_coord,
			visual_resources,
			catalog,
			spec,
			{
				"formation_mode": formation.get("formation_mode", "owned_halo"),
				"formation_origin_cell": formation_origin_cell,
				"owned_visual_origin": owned_visual_origin,
				"owned_visual_size": owned_visual_size,
				"crop_min": crop_min,
				"crop_max_exclusive": crop_max_exclusive,
			}
		))

	var plan := _chunk_plan_from_layers(chunk_coord, layer_plans, catalog)
	plan["source_generated_product_type"] = generated_chunk_data.get("product_type", "")
	plan["source_authority"] = generated_chunk_data.get("authority", "")
	plan["generation_diagnostics"] = generated_chunk_data.get("diagnostics", {})
	return plan


func _attach_generated_chunk_source_metadata(
	visual_plan: Dictionary,
	generated_chunk_data: Dictionary,
	source_consumed_fields: PackedStringArray
) -> Dictionary:
	var next_plan := visual_plan.duplicate(true)
	next_plan["source_generated_product_type"] = generated_chunk_data.get("product_type", "")
	next_plan["source_authority"] = generated_chunk_data.get("authority", "")
	next_plan["source_consumed_fields"] = source_consumed_fields.duplicate()
	next_plan["host_adapter_contract"] = host_adapter_contract()
	var diagnostics: Dictionary = next_plan.get("diagnostics", {}).duplicate(true)
	diagnostics["host_adapter"] = {
		"adapter_id": "chunk_visual_builder",
		"owns_generation_truth": false,
		"source_consumed_fields": source_consumed_fields.duplicate(),
	}
	next_plan["diagnostics"] = diagnostics
	return next_plan


func _unavailable_mapper_plan(chunk_coord: Vector3i) -> Dictionary:
	push_error("GodotGridTopologyMapper is unavailable. Build and copy godot_grid.")
	return {
		"product_type": "ChunkVisualPlan",
		"chunk_coord": chunk_coord,
		"visual_layers": [],
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


func _build_layer_plan_from_visual_resources(
	chunk_coord: Vector3i,
	visual_resources: Array,
	catalog: RefCounted,
	layer_spec: Dictionary,
	options: Dictionary
) -> Dictionary:
	var layer_id := String(layer_spec.get("layer_id", LAYER_SOLID))
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
		var data: Dictionary = _resource_to_visual_tile_data(chunk_coord, tile_resource, catalog, layer_spec)
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
		"layer_id": layer_id,
		"source_topology_layer": layer_spec.get("source_topology_layer", layer_id),
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
		"diagonal_transform_diagnostics": _diagonal_transform_diagnostics(tiles),
	}
	var missing_assets: Array = []
	if catalog != null:
		var validation: Dictionary = catalog.validate_visual_plan({"visual_tiles": tiles})
		missing_assets = validation["missing_asset_keys"]
		diagnostics["is_valid"] = bool(diagnostics["is_valid"]) and bool(validation["is_valid"])
		diagnostics["catalog_validation"] = validation

	return {
		"layer_id": layer_id,
		"source_topology_layer": layer_spec.get("source_topology_layer", layer_id),
		"asset_namespace": layer_spec.get("asset_namespace", layer_id),
		"material_variant": layer_spec.get("material_variant", layer_id),
		"height_offset": float(layer_spec.get("height_offset", 0.0)),
		"formation_mode": formation_mode,
		"formation_origin_cell": formation_origin_cell,
		"owned_visual_origin": owned_visual_origin,
		"owned_visual_size": owned_visual_size,
		"visual_tiles": tiles,
		"asset_keys": asset_keys,
		"missing_assets": missing_assets,
		"bounds": bounds,
		"diagnostics": diagnostics,
		"buckets": buckets,
	}


func _chunk_plan_from_layers(chunk_coord: Vector3i, visual_layers: Array, catalog: RefCounted) -> Dictionary:
	var visual_tiles: Array[Dictionary] = []
	var asset_keys_seen: Dictionary = {}
	var missing_seen: Dictionary = {}
	var layer_buckets: Dictionary = {}
	var bounds := _empty_bounds()
	var invalid_layer_count := 0
	var duplicate_world_corners_by_layer := _duplicate_world_corners_by_layer(visual_layers)

	for layer in visual_layers:
		var layer_plan: Dictionary = layer
		if not bool(layer_plan.get("diagnostics", {}).get("is_valid", false)):
			invalid_layer_count += 1
		layer_buckets[layer_plan["layer_id"]] = layer_plan.get("buckets", {})
		for missing_asset in layer_plan.get("missing_assets", []):
			missing_seen[String(missing_asset)] = true
		for asset_key in layer_plan.get("asset_keys", []):
			asset_keys_seen[String(asset_key)] = true
		for tile in layer_plan.get("visual_tiles", []):
			var data: Dictionary = tile
			visual_tiles.append(data)
			_expand_bounds(bounds, data["corner"])

	var asset_keys := asset_keys_seen.keys()
	asset_keys.sort()
	var missing_assets := missing_seen.keys()
	missing_assets.sort()
	var diagnostics := {
		"is_valid": (
			invalid_layer_count == 0
			and missing_assets.is_empty()
			and duplicate_world_corners_by_layer.is_empty()
		),
		"formation_mode": "layered",
		"visual_layer_count": visual_layers.size(),
		"visual_tile_count": visual_tiles.size(),
		"invalid_layer_count": invalid_layer_count,
		"missing_asset_count": missing_assets.size(),
		"duplicate_world_corners_by_layer": duplicate_world_corners_by_layer,
		"diagonal_transform_diagnostics": _diagonal_transform_diagnostics(visual_tiles),
	}
	if catalog != null:
		diagnostics["catalog"] = catalog.get_asset_report({"visual_tiles": visual_tiles})

	return {
		"product_type": "ChunkVisualPlan",
		"chunk_coord": chunk_coord,
		"formation_mode": "layered",
		"visual_layers": visual_layers,
		"visual_tiles": visual_tiles,
		"tiles": visual_tiles,
		"asset_keys": asset_keys,
		"missing_assets": missing_assets,
		"bounds": bounds,
		"diagnostics": diagnostics,
		"buckets": layer_buckets,
	}


func _resource_to_visual_tile_data(
	chunk_coord: Vector3i,
	tile_resource: Object,
	catalog: RefCounted,
	layer_spec: Dictionary
) -> Dictionary:
	var asset_key := String(tile_resource.asset_key)
	var descriptor_rotation := int(tile_resource.rotation_degrees_cw)
	var transform_info := _tile_transform_info(catalog, asset_key, descriptor_rotation)
	return {
		"chunk_coord": chunk_coord,
		"layer_id": String(layer_spec.get("layer_id", LAYER_SOLID)),
		"source_topology_layer": String(layer_spec.get("source_topology_layer", layer_spec.get("layer_id", LAYER_SOLID))),
		"asset_namespace": String(layer_spec.get("asset_namespace", layer_spec.get("layer_id", LAYER_SOLID))),
		"material_variant": String(layer_spec.get("material_variant", layer_spec.get("layer_id", LAYER_SOLID))),
		"height_offset": float(layer_spec.get("height_offset", 0.0)),
		"corner": tile_resource.corner,
		"asset_key": asset_key,
		"rotation_degrees_cw": descriptor_rotation,
		"descriptor_rotation_degrees_cw": transform_info["descriptor_rotation_degrees_cw"],
		"catalog_rotation_correction_degrees_cw": transform_info["catalog_rotation_correction_degrees_cw"],
		"effective_rotation_degrees_cw": transform_info["effective_rotation_degrees_cw"],
		"canonical_rotation_degrees_cw": transform_info["canonical_rotation_degrees_cw"],
		"catalog_flip_x": transform_info["flip_x"],
		"catalog_flip_z": transform_info["flip_z"],
		"mask": int(tile_resource.mask),
		"is_empty": bool(tile_resource.is_empty),
	}


func _tile_transform(tile_data: Dictionary, cell_size_meters: float) -> Transform3D:
	var corner: Vector2i = tile_data["corner"]
	var effective_rotation_degrees_cw: int = int(tile_data.get(
		"effective_rotation_degrees_cw",
		tile_data.get("rotation_degrees_cw", 0)
	))
	var origin := Vector3(
		float(corner.x) * cell_size_meters,
		float(tile_data.get("height_offset", 0.0)),
		float(corner.y) * cell_size_meters
	)
	var basis := Basis(Vector3.UP, deg_to_rad(float(-effective_rotation_degrees_cw)))
	var scale := Vector3(
		-1.0 if bool(tile_data.get("catalog_flip_x", false)) else 1.0,
		1.0,
		-1.0 if bool(tile_data.get("catalog_flip_z", false)) else 1.0
	)
	basis = basis.scaled(scale * Vector3(cell_size_meters, 1.0, cell_size_meters))
	return Transform3D(basis, origin)


func _tiles_by_corner(tiles: Array) -> Dictionary:
	var by_corner: Dictionary = {}
	for tile in tiles:
		var data: Dictionary = tile
		if data["is_empty"]:
			continue
		by_corner[_tile_storage_key(data)] = data
	return by_corner


func _tile_storage_key(tile_data: Dictionary) -> String:
	return "%s|%s" % [
		String(tile_data.get("layer_id", LAYER_SOLID)),
		_corner_key(tile_data["corner"]),
	]


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


func _rebuild_multimesh_buckets(root: Node3D, bucket_filter: Dictionary = {}) -> int:
	var build_start_us := Time.get_ticks_usec()
	if bucket_filter.is_empty():
		_clear_children(root)
	if not root.has_meta("catalog") or not root.has_meta("visual_tiles_by_corner"):
		return 0

	var catalog: RefCounted = root.get_meta("catalog")
	var cell_size_meters: float = root.get_meta("cell_size_meters")
	var visual_tiles_by_corner: Dictionary = root.get_meta("visual_tiles_by_corner")
	var transforms_by_bucket: Dictionary = {}
	var sample_tile_by_bucket: Dictionary = {}
	var instance_total := 0

	for storage_key in visual_tiles_by_corner:
		var data: Dictionary = visual_tiles_by_corner[storage_key]
		var bucket_key := _bucket_key_for_tile(data, catalog)
		if not bucket_filter.is_empty() and not bucket_filter.has(bucket_key):
			continue
		if not transforms_by_bucket.has(bucket_key):
			transforms_by_bucket[bucket_key] = []
			sample_tile_by_bucket[bucket_key] = data
		transforms_by_bucket[bucket_key].append(_tile_transform(data, cell_size_meters))

	var bucket_keys: Array = transforms_by_bucket.keys()
	bucket_keys.sort()
	var rebuilt_bucket_count := 0
	var attach_time_us := 0
	for bucket_key in bucket_keys:
		var sample_tile: Dictionary = sample_tile_by_bucket[bucket_key]
		var source_asset_key: String = sample_tile["asset_key"]
		var mesh: Mesh = catalog.get_mesh(source_asset_key)
		if mesh == null:
			continue

		var transforms: Array = transforms_by_bucket[bucket_key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])

		var attach_start_us := Time.get_ticks_usec()
		_upsert_bucket_instance(root, String(bucket_key), multimesh, sample_tile, source_asset_key, catalog)
		attach_time_us += Time.get_ticks_usec() - attach_start_us
		instance_total += transforms.size()
		rebuilt_bucket_count += 1

	if not bucket_filter.is_empty():
		for filtered_bucket_key in bucket_filter.keys():
			if not transforms_by_bucket.has(filtered_bucket_key):
				_remove_bucket_instance(root, String(filtered_bucket_key))
				rebuilt_bucket_count += 1

	root.set_meta("last_visual_bucket_build_time_us", Time.get_ticks_usec() - build_start_us)
	root.set_meta("last_visual_node_attach_time_us", attach_time_us)
	root.set_meta("last_visual_bucket_count", _bucket_child_count(root))
	root.set_meta("last_visual_instance_count", _multimesh_instance_total(root))
	root.set_meta("last_visual_child_count", root.get_child_count())
	root.set_meta("last_visual_skipped_empty_tile_count", maxi(int(root.get_meta("visual_tile_count", 0)) - visual_tiles_by_corner.size(), 0))
	return rebuilt_bucket_count


func _bucket_key_for_tile(tile_data: Dictionary, catalog: RefCounted) -> String:
	var asset_key: String = tile_data["asset_key"]
	var base_key: String = catalog.base_key_for_asset_key(asset_key) if catalog != null else asset_key
	var layer_id := String(tile_data.get("layer_id", LAYER_SOLID))
	var material_variant := String(tile_data.get("material_variant", layer_id))
	return "%s|%s|%s" % [layer_id, base_key, material_variant]


func _bucket_node_name(bucket_key: String) -> String:
	return "%s_bucket" % bucket_key.replace("|", "_")


func _remove_bucket_instance(root: Node3D, bucket_key: String) -> void:
	for child in root.get_children():
		var node := child as Node
		if node != null and String(node.get_meta("bucket_key", "")) == bucket_key:
			root.remove_child(node)
			node.free()


func _upsert_bucket_instance(
	root: Node3D,
	bucket_key: String,
	multimesh: MultiMesh,
	sample_tile: Dictionary,
	source_asset_key: String,
	catalog: RefCounted
) -> void:
	var instance := _bucket_instance(root, bucket_key)
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.name = _bucket_node_name(bucket_key)
		instance.set_meta("bucket_key", bucket_key)
		root.add_child(instance)
	instance.multimesh = multimesh
	if catalog != null and catalog.has_method("get_material_for_tile"):
		instance.material_override = catalog.get_material_for_tile(sample_tile)
	elif catalog != null:
		instance.material_override = catalog.get_material(source_asset_key)


func _bucket_instance(root: Node3D, bucket_key: String) -> MultiMeshInstance3D:
	for child in root.get_children():
		var instance := child as MultiMeshInstance3D
		if instance != null and String(instance.get_meta("bucket_key", "")) == bucket_key:
			return instance
	return null


func _bucket_child_count(root: Node3D) -> int:
	var count := 0
	for child in root.get_children():
		var instance := child as MultiMeshInstance3D
		if instance != null and instance.has_meta("bucket_key"):
			count += 1
	return count


func _multimesh_instance_total(root: Node3D) -> int:
	var count := 0
	for child in root.get_children():
		var instance := child as MultiMeshInstance3D
		if instance != null and instance.multimesh != null:
			count += instance.multimesh.instance_count
	return count


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


func _visual_layer_specs() -> Array[Dictionary]:
	return [
		{
			"layer_id": LAYER_GROUND,
			"source_topology_layer": LAYER_GROUND,
			"asset_namespace": "ground",
			"material_variant": "ground",
			"height_offset": 0.0,
		},
		{
			"layer_id": LAYER_WATER,
			"source_topology_layer": LAYER_WATER,
			"asset_namespace": "water",
			"material_variant": "water",
			"height_offset": -0.04,
		},
		_solid_layer_spec(),
	]


func _solid_layer_spec() -> Dictionary:
	return {
		"layer_id": LAYER_SOLID,
		"source_topology_layer": LAYER_SOLID,
		"asset_namespace": "solid",
		"material_variant": "solid",
		"height_offset": 0.14,
	}


func _tile_transform_info(catalog: RefCounted, asset_key: String, descriptor_rotation: int) -> Dictionary:
	if catalog != null and catalog.has_method("describe_tile_transform"):
		return catalog.describe_tile_transform(asset_key, descriptor_rotation)
	return {
		"asset_key": asset_key,
		"base_key": asset_key,
		"descriptor_rotation_degrees_cw": _positive_degrees(descriptor_rotation),
		"catalog_rotation_correction_degrees_cw": 0,
		"effective_rotation_degrees_cw": _positive_degrees(descriptor_rotation),
		"canonical_rotation_degrees_cw": 0,
		"flip_x": false,
		"flip_z": false,
	}


func _diagonal_transform_diagnostics(tiles: Array) -> Array:
	var diagnostics: Array[Dictionary] = []
	for tile in tiles:
		var data: Dictionary = tile
		if not String(data.get("asset_key", "")).begins_with("diagonal_"):
			continue
		diagnostics.append({
			"layer_id": data.get("layer_id", LAYER_SOLID),
			"mask": data.get("mask", 0),
			"asset_key": data.get("asset_key", ""),
			"descriptor_rotation_degrees_cw": data.get("descriptor_rotation_degrees_cw", 0),
			"catalog_rotation_correction_degrees_cw": data.get("catalog_rotation_correction_degrees_cw", 0),
			"effective_rotation_degrees_cw": data.get("effective_rotation_degrees_cw", 0),
		})
	return diagnostics


func _duplicate_world_corners_by_layer(visual_layers: Array) -> Array:
	var duplicates: Array[String] = []
	for layer in visual_layers:
		var layer_plan: Dictionary = layer
		var owner: Dictionary = {}
		for tile in layer_plan.get("visual_tiles", []):
			var data: Dictionary = tile
			var world_corner: Vector2i = data.get("world_corner", Vector2i.ZERO)
			var key := "%s|%s:%s" % [layer_plan["layer_id"], world_corner.x, world_corner.y]
			if owner.has(key):
				duplicates.append(key)
			else:
				owner[key] = true
	duplicates.sort()
	return duplicates


func _effective_rotation_count(visual_tiles: Array) -> int:
	var count := 0
	for tile in visual_tiles:
		var data: Dictionary = tile
		if data.has("effective_rotation_degrees_cw"):
			count += 1
	return count


func _positive_degrees(degrees: int) -> int:
	var value := degrees % 360
	return value + 360 if value < 0 else value


func _corner_key(corner: Vector2i) -> String:
	return "%s:%s" % [corner.x, corner.y]


func _clear_children(root: Node3D) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()


func _remove_meta_if_present(root: Node3D, name: StringName) -> void:
	if root.has_meta(name):
		root.remove_meta(name)
