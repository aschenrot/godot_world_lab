extends RefCounted

const DEFAULT_COLLISION_HEIGHT_METERS := 0.8
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"


func host_adapter_contract() -> Dictionary:
	return {
		"product_type": "GodotHostAdapterContract",
		"adapter_id": "chunk_collision_builder",
		"host_surface": "collision",
		"consumes": PackedStringArray([
			"GeneratedWorldChunkRecord.topology_layers.solid",
			"GeneratedWorldChunkRecord.topology_layers.water",
			"GeneratedWorldChunk.topology_projection_set",
		]),
		"produces": PackedStringArray([
			"ChunkCollisionPlan",
			"StaticBody3D collision realization",
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


func build_chunk_collision(
	chunk_coord: Vector3i,
	collision_source: Dictionary,
	chunk_edge_meters: float,
	cells_per_chunk: int,
	options: Dictionary = {}
) -> StaticBody3D:
	var cell_size_meters: float = chunk_edge_meters / float(maxi(cells_per_chunk, 1))
	var plan_options := options.duplicate(true)
	plan_options["cell_size_meters"] = cell_size_meters
	plan_options["collision_height_meters"] = float(options.get("collision_height_meters", DEFAULT_COLLISION_HEIGHT_METERS))
	var collision_plan := build_collision_plan(chunk_coord, collision_source, plan_options)
	return build_chunk_collision_from_plan(
		chunk_coord,
		collision_source,
		collision_plan,
		chunk_edge_meters,
		cells_per_chunk,
		plan_options
	)


func build_chunk_collision_from_plan(
	chunk_coord: Vector3i,
	collision_source: Dictionary,
	collision_plan: Dictionary,
	chunk_edge_meters: float,
	cells_per_chunk: int,
	options: Dictionary = {}
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ChunkCollision"
	body.set_meta("chunk_coord", chunk_coord)
	body.set_meta("source_product_type", collision_source.get("product_type", ""))
	body.set_meta("collision_backend", "merged_collision_rectangles")
	body.set_meta("host_adapter_contract", host_adapter_contract())

	var cell_size_meters: float = chunk_edge_meters / float(maxi(cells_per_chunk, 1))
	body.set_meta("collision_plan", collision_plan)

	var collision_count := 0
	var shape_records: Array[Dictionary] = []
	var debug_shape_nodes := bool(options.get("debug_collision_shape_nodes", false))

	for box in collision_plan.get("merged_boxes", []):
		var data: Dictionary = box
		var rect: Rect2i = data["rect"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(
			float(rect.size.x) * cell_size_meters,
			float(options.get("collision_height_meters", DEFAULT_COLLISION_HEIGHT_METERS)),
			float(rect.size.y) * cell_size_meters
		)
		var shape_transform: Transform3D = data.get(
			"world_space_shape_transform",
			_rect_collision_transform(
				rect,
				cell_size_meters,
				float(options.get("collision_height_meters", DEFAULT_COLLISION_HEIGHT_METERS))
			)
		)
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_set_transform(owner_id, shape_transform)
		body.shape_owner_add_shape(owner_id, shape)
		shape_records.append({
			"shape_owner_id": owner_id,
			"rect": rect,
			"reason": data.get("reason", ""),
			"source_layer": data.get("source_layer", ""),
			"cell_count": int(data.get("cell_count", rect.size.x * rect.size.y)),
		})
		if debug_shape_nodes:
			var shape_node := CollisionShape3D.new()
			shape_node.name = "MergedCollision_%s_%s_%s_%s" % [
				rect.position.x,
				rect.position.y,
				rect.size.x,
				rect.size.y,
			]
			shape_node.shape = shape
			shape_node.transform = shape_transform
			body.add_child(shape_node)
		collision_count += 1

	body.set_meta("collision_shape_count", collision_count)
	body.set_meta("collision_shape_owner_count", collision_count)
	body.set_meta("collision_shape_records", shape_records)
	body.set_meta("collision_policy", collision_plan.get("policy", {}))
	return body


func build_collision_plan(
	chunk_coord: Vector3i,
	collision_source: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var topology_layers: Dictionary = _topology_layers_from_collision_source(collision_source)
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, [])
	var water_grid: Array = topology_layers.get(LAYER_WATER, [])
	var liquid_blocks := bool(options.get("liquid_blocks_movement", true))
	var cell_size_meters := float(options.get("cell_size_meters", 1.0))
	var collision_height_meters := float(options.get("collision_height_meters", DEFAULT_COLLISION_HEIGHT_METERS))
	var source_consumed_fields := _collision_consumed_fields(collision_source)
	var uses_logic_grid_compatibility_alias := (
		not topology_layers.has(LAYER_SOLID)
		and collision_source.has("logic_grid")
	)
	var merge_payload := _native_collision_merge_payload(solid_grid, water_grid, liquid_blocks)
	if merge_payload.is_empty() or not merge_payload.has("merged_boxes"):
		merge_payload = _local_collision_merge_payload(solid_grid, water_grid, liquid_blocks)
	var merged_boxes := _boxes_with_shape_transforms(
		merge_payload.get("merged_boxes", []),
		cell_size_meters,
		collision_height_meters
	)
	var diagnostics: Dictionary = merge_payload.get("diagnostics", {})
	diagnostics["source_has_topology_layers"] = collision_source.has("topology_layers")
	diagnostics["source_has_topology_projection_set"] = collision_source.has("topology_projection_set")
	diagnostics["source_has_logic_grid_alias"] = collision_source.has("logic_grid")
	diagnostics["uses_logic_grid_compatibility_alias"] = uses_logic_grid_compatibility_alias
	diagnostics["owns_generation_truth"] = false
	diagnostics["source_consumed_fields"] = source_consumed_fields.duplicate()

	return {
		"product_type": "ChunkCollisionPlan",
		"chunk_coord": chunk_coord,
		"source_product_type": collision_source.get("product_type", ""),
		"source_consumed_fields": source_consumed_fields,
		"host_adapter_contract": host_adapter_contract(),
		"merged_boxes": merged_boxes,
		"policy": {
			"solid_blocks_movement": true,
			"liquid_blocks_movement": liquid_blocks,
			"ground_visuals_block_movement": false,
		},
		"diagnostics": diagnostics,
	}


func get_collision_diagnostics(collision_body: StaticBody3D) -> Dictionary:
	if collision_body == null:
		return {
			"has_collision": false,
			"collision_shape_count": 0,
		}
	var collision_plan: Dictionary = collision_body.get_meta("collision_plan", {})
	return {
		"has_collision": true,
		"chunk_coord": collision_body.get_meta("chunk_coord", Vector3i.ZERO),
		"collision_backend": collision_body.get_meta("collision_backend", ""),
		"collision_shape_count": int(collision_body.get_meta("collision_shape_count", 0)),
		"collision_shape_owner_count": int(collision_body.get_meta("collision_shape_owner_count", 0)),
		"collision_policy": collision_body.get_meta("collision_policy", {}),
		"collision_plan_diagnostics": collision_plan.get("diagnostics", {}),
	}


func _cell_collision_origin(cell: Vector2i, cell_size_meters: float) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size_meters,
		DEFAULT_COLLISION_HEIGHT_METERS * 0.5,
		(float(cell.y) + 0.5) * cell_size_meters
	)


func _rect_collision_transform(
	rect: Rect2i,
	cell_size_meters: float,
	collision_height_meters: float
) -> Transform3D:
	return Transform3D(
		Basis.IDENTITY,
		Vector3(
			(float(rect.position.x) + float(rect.size.x) * 0.5) * cell_size_meters,
			collision_height_meters * 0.5,
			(float(rect.position.y) + float(rect.size.y) * 0.5) * cell_size_meters
		)
	)


func _native_collision_merge_payload(
	solid_grid: Array,
	water_grid: Array,
	liquid_blocks: bool
) -> Dictionary:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		return {}
	var mapper := ClassDB.instantiate("GodotGridTopologyMapper") as Object
	if mapper == null or not mapper.has_method("merged_collision_boxes_payload"):
		return {}
	var payload: Variant = mapper.call(
		"merged_collision_boxes_payload",
		solid_grid,
		water_grid,
		{"liquid_blocks_movement": liquid_blocks}
	)
	return payload if typeof(payload) == TYPE_DICTIONARY else {}


func _local_collision_merge_payload(
	solid_grid: Array,
	water_grid: Array,
	liquid_blocks: bool
) -> Dictionary:
	var width := maxi(_grid_width(solid_grid), _grid_width(water_grid))
	var height := maxi(solid_grid.size(), water_grid.size())
	var merged_boxes: Array[Dictionary] = []
	var counts_by_reason := {}
	var counts_by_layer := {}
	var shape_counts_by_reason := {}
	var shape_counts_by_layer := {}
	var blocking_cell_seen := {}

	_append_local_merged_boxes_for_group(
		merged_boxes,
		counts_by_reason,
		counts_by_layer,
		shape_counts_by_reason,
		shape_counts_by_layer,
		blocking_cell_seen,
		solid_grid,
		width,
		height,
		"solid",
		LAYER_SOLID
	)
	if liquid_blocks:
		_append_local_merged_boxes_for_group(
			merged_boxes,
			counts_by_reason,
			counts_by_layer,
			shape_counts_by_reason,
			shape_counts_by_layer,
			blocking_cell_seen,
			water_grid,
			width,
			height,
			"liquid_policy",
			LAYER_WATER
		)

	var blocking_cell_count := blocking_cell_seen.size()
	return {
		"merged_boxes": merged_boxes,
		"diagnostics": {
			"backend": "local_greedy_rectangle_merge",
			"blocking_cell_count": blocking_cell_count,
			"merged_shape_count": merged_boxes.size(),
			"merge_ratio": 0.0 if blocking_cell_count == 0 else float(merged_boxes.size()) / float(blocking_cell_count),
			"counts_by_reason": counts_by_reason,
			"counts_by_layer": counts_by_layer,
			"shape_counts_by_reason": shape_counts_by_reason,
			"shape_counts_by_layer": shape_counts_by_layer,
		},
	}


func _append_local_merged_boxes_for_group(
	merged_boxes: Array,
	counts_by_reason: Dictionary,
	counts_by_layer: Dictionary,
	shape_counts_by_reason: Dictionary,
	shape_counts_by_layer: Dictionary,
	blocking_cell_seen: Dictionary,
	grid: Array,
	width: int,
	height: int,
	reason: String,
	source_layer: String
) -> void:
	var visited := {}
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var key := _cell_key(cell)
			if visited.has(key) or _grid_cell(grid, cell) == 0:
				continue
			var rect_width := 0
			while x + rect_width < width \
				and _grid_cell(grid, Vector2i(x + rect_width, y)) != 0 \
				and not visited.has(_cell_key(Vector2i(x + rect_width, y))):
				rect_width += 1
			var rect_height := 1
			var can_grow := true
			while can_grow and y + rect_height < height:
				for grow_x in range(x, x + rect_width):
					var grow_cell := Vector2i(grow_x, y + rect_height)
					if _grid_cell(grid, grow_cell) == 0 or visited.has(_cell_key(grow_cell)):
						can_grow = false
						break
				if can_grow:
					rect_height += 1
			for mark_y in range(y, y + rect_height):
				for mark_x in range(x, x + rect_width):
					var mark_cell := Vector2i(mark_x, mark_y)
					visited[_cell_key(mark_cell)] = true
					blocking_cell_seen[_cell_key(mark_cell)] = true
			var cell_count := rect_width * rect_height
			_increment_count(counts_by_reason, reason, cell_count)
			_increment_count(counts_by_layer, source_layer, cell_count)
			_increment_count(shape_counts_by_reason, reason, 1)
			_increment_count(shape_counts_by_layer, source_layer, 1)
			merged_boxes.append({
				"rect": Rect2i(Vector2i(x, y), Vector2i(rect_width, rect_height)),
				"reason": reason,
				"source_layer": source_layer,
				"cell_count": cell_count,
			})


func _boxes_with_shape_transforms(
	boxes: Array,
	cell_size_meters: float,
	collision_height_meters: float
) -> Array[Dictionary]:
	var enriched: Array[Dictionary] = []
	for box in boxes:
		if typeof(box) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = box
		var rect: Rect2i = data.get("rect", Rect2i())
		var next_box := data.duplicate(true)
		next_box["world_space_shape_transform"] = _rect_collision_transform(
			rect,
			cell_size_meters,
			collision_height_meters
		)
		enriched.append(next_box)
	return enriched


func _topology_layers_from_collision_source(collision_source: Dictionary) -> Dictionary:
	var direct_layers: Dictionary = collision_source.get("topology_layers", {})
	if not direct_layers.is_empty():
		return direct_layers
	var projection_set: Dictionary = collision_source.get("topology_projection_set", {})
	var projections: Variant = projection_set.get("projections", {})
	if typeof(projections) == TYPE_DICTIONARY:
		var topology_layers: Dictionary = {}
		var projection_dictionary: Dictionary = projections
		for projection_id in projection_dictionary.keys():
			var projection_data: Variant = projection_dictionary[projection_id]
			if typeof(projection_data) != TYPE_DICTIONARY:
				continue
			var grid: Variant = projection_data.get("grid", [])
			if typeof(grid) == TYPE_ARRAY:
				topology_layers[String(projection_id)] = grid
		if not topology_layers.is_empty():
			return topology_layers
	var legacy_layers: Variant = projection_set.get("topology_layers", {})
	if typeof(legacy_layers) == TYPE_DICTIONARY:
		return legacy_layers
	if collision_source.has("logic_grid"):
		return {LAYER_SOLID: collision_source.get("logic_grid", [])}
	return {}


func _collision_consumed_fields(collision_source: Dictionary) -> PackedStringArray:
	var consumed_fields := PackedStringArray()
	var topology_layers: Dictionary = _topology_layers_from_collision_source(collision_source)
	if topology_layers.has(LAYER_SOLID):
		consumed_fields.append("topology_layers.solid" if collision_source.has("topology_layers") else "topology_projection_set.solid")
	if topology_layers.has(LAYER_WATER):
		consumed_fields.append("topology_layers.water" if collision_source.has("topology_layers") else "topology_projection_set.water")
	if consumed_fields.is_empty() and collision_source.has("logic_grid"):
		consumed_fields.append("logic_grid")
	return consumed_fields


func _grid_cell(grid: Array, cell: Vector2i) -> int:
	if (
		cell.y < 0
		or cell.y >= grid.size()
		or cell.x < 0
		or cell.x >= int(grid[cell.y].size())
	):
		return 0
	return int(grid[cell.y][cell.x])


func _grid_width(grid: Array) -> int:
	var width := 0
	for row in grid:
		width = maxi(width, int(row.size()))
	return width


func _cell_key(cell: Vector2i) -> String:
	return "%s:%s" % [cell.x, cell.y]


func _increment_count(counts: Dictionary, key: String, amount: int) -> void:
	counts[key] = int(counts.get(key, 0)) + amount
