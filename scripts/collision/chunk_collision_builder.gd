extends RefCounted

const DEFAULT_COLLISION_HEIGHT_METERS := 0.8
const DEFAULT_FLOOR_THICKNESS_METERS := 0.2
const DEFAULT_FLOOR_TOP_Y_METERS := 0.0
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const COLLISION_KIND_BLOCKER := "blocker"
const COLLISION_KIND_FLOOR := "floor"
const FLOOR_REASON_WALKABLE_GROUND := "walkable_ground_floor"


func host_adapter_contract() -> Dictionary:
	return {
		"product_type": "GodotHostAdapterContract",
		"adapter_id": "chunk_collision_builder",
		"host_surface": "collision",
		"consumes": PackedStringArray([
			"GeneratedWorldChunkRecord.topology_layers.solid",
			"GeneratedWorldChunkRecord.topology_layers.water",
			"GeneratedWorldChunkRecord.topology_layers.ground",
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

	var planned_boxes: Array = collision_plan.get(
		"collision_boxes",
		collision_plan.get("merged_boxes", [])
	)
	for box in planned_boxes:
		var data: Dictionary = box
		var rect: Rect2i = data["rect"]
		var shape := BoxShape3D.new()
		var default_shape_size := Vector3(
			float(rect.size.x) * cell_size_meters,
			float(options.get("collision_height_meters", DEFAULT_COLLISION_HEIGHT_METERS)),
			float(rect.size.y) * cell_size_meters
		)
		var shape_size: Variant = data.get("shape_size_meters", default_shape_size)
		shape.size = shape_size if typeof(shape_size) == TYPE_VECTOR3 else default_shape_size
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
			"collision_kind": data.get("collision_kind", COLLISION_KIND_BLOCKER),
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
	var ground_floor_enabled := bool(options.get("ground_floor_collision_enabled", false))
	var cell_size_meters := float(options.get("cell_size_meters", 1.0))
	var collision_height_meters := float(options.get("collision_height_meters", DEFAULT_COLLISION_HEIGHT_METERS))
	var floor_thickness_meters := maxf(
		float(options.get("floor_thickness_meters", DEFAULT_FLOOR_THICKNESS_METERS)),
		0.01
	)
	var floor_top_y_meters := float(options.get("floor_top_y_meters", DEFAULT_FLOOR_TOP_Y_METERS))
	var source_consumed_fields := _collision_consumed_fields(collision_source, ground_floor_enabled)
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
	var floor_boxes: Array[Dictionary] = []
	var floor_payload: Dictionary = {}
	if ground_floor_enabled:
		floor_payload = _floor_merge_payload(_walkable_ground_floor_grid(topology_layers))
		floor_boxes = _floor_boxes_with_shape_transforms(
			floor_payload.get("merged_boxes", []),
			cell_size_meters,
			floor_thickness_meters,
			floor_top_y_meters
		)
	var collision_boxes: Array[Dictionary] = []
	collision_boxes.append_array(merged_boxes)
	collision_boxes.append_array(floor_boxes)

	var diagnostics: Dictionary = merge_payload.get("diagnostics", {}).duplicate(true)
	var floor_diagnostics: Dictionary = floor_payload.get("diagnostics", {})
	diagnostics["source_has_topology_layers"] = collision_source.has("topology_layers")
	diagnostics["source_has_topology_projection_set"] = collision_source.has("topology_projection_set")
	diagnostics["source_has_logic_grid_alias"] = collision_source.has("logic_grid")
	diagnostics["uses_logic_grid_compatibility_alias"] = uses_logic_grid_compatibility_alias
	diagnostics["owns_generation_truth"] = false
	diagnostics["source_consumed_fields"] = source_consumed_fields.duplicate()
	diagnostics["ground_floor_collision_enabled"] = ground_floor_enabled
	diagnostics["floor_cell_count"] = int(floor_diagnostics.get("floor_cell_count", 0))
	diagnostics["floor_shape_count"] = floor_boxes.size()
	diagnostics["floor_merge_ratio"] = float(floor_diagnostics.get("floor_merge_ratio", 0.0))
	diagnostics["floor_counts_by_reason"] = floor_diagnostics.get("floor_counts_by_reason", {})
	diagnostics["floor_counts_by_layer"] = floor_diagnostics.get("floor_counts_by_layer", {})
	diagnostics["floor_shape_counts_by_reason"] = floor_diagnostics.get("floor_shape_counts_by_reason", {})
	diagnostics["floor_shape_counts_by_layer"] = floor_diagnostics.get("floor_shape_counts_by_layer", {})
	diagnostics["total_shape_count"] = collision_boxes.size()

	return {
		"product_type": "ChunkCollisionPlan",
		"chunk_coord": chunk_coord,
		"source_product_type": collision_source.get("product_type", ""),
		"source_consumed_fields": source_consumed_fields,
		"host_adapter_contract": host_adapter_contract(),
		"merged_boxes": merged_boxes,
		"floor_boxes": floor_boxes,
		"collision_boxes": collision_boxes,
		"policy": {
			"solid_blocks_movement": true,
			"liquid_blocks_movement": liquid_blocks,
			"ground_visuals_block_movement": false,
			"ground_floor_collision_enabled": ground_floor_enabled,
			"floor_thickness_meters": floor_thickness_meters,
			"floor_top_y_meters": floor_top_y_meters,
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
		_rect_collision_center(rect, cell_size_meters, collision_height_meters * 0.5)
	)


func _rect_collision_transform_with_center_y(
	rect: Rect2i,
	cell_size_meters: float,
	center_y_meters: float
) -> Transform3D:
	return Transform3D(
		Basis.IDENTITY,
		_rect_collision_center(rect, cell_size_meters, center_y_meters)
	)


func _rect_collision_center(rect: Rect2i, cell_size_meters: float, center_y_meters: float) -> Vector3:
	return Vector3(
		(float(rect.position.x) + float(rect.size.x) * 0.5) * cell_size_meters,
		center_y_meters,
		(float(rect.position.y) + float(rect.size.y) * 0.5) * cell_size_meters
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
		next_box["shape_size_meters"] = Vector3(
			float(rect.size.x) * cell_size_meters,
			collision_height_meters,
			float(rect.size.y) * cell_size_meters
		)
		next_box["collision_kind"] = COLLISION_KIND_BLOCKER
		enriched.append(next_box)
	return enriched


func _floor_boxes_with_shape_transforms(
	boxes: Array,
	cell_size_meters: float,
	floor_thickness_meters: float,
	floor_top_y_meters: float
) -> Array[Dictionary]:
	var enriched: Array[Dictionary] = []
	var center_y_meters := floor_top_y_meters - floor_thickness_meters * 0.5
	for box in boxes:
		if typeof(box) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = box
		var rect: Rect2i = data.get("rect", Rect2i())
		var next_box := data.duplicate(true)
		next_box["world_space_shape_transform"] = _rect_collision_transform_with_center_y(
			rect,
			cell_size_meters,
			center_y_meters
		)
		next_box["shape_size_meters"] = Vector3(
			float(rect.size.x) * cell_size_meters,
			floor_thickness_meters,
			float(rect.size.y) * cell_size_meters
		)
		next_box["collision_kind"] = COLLISION_KIND_FLOOR
		enriched.append(next_box)
	return enriched


func _floor_merge_payload(floor_grid: Array) -> Dictionary:
	var floor_cell_count_expected := _grid_nonzero_count(floor_grid)
	var native_payload := _native_collision_merge_payload(floor_grid, _zero_grid_like(floor_grid), false)
	if native_payload.is_empty() or not native_payload.has("merged_boxes"):
		return _local_floor_merge_payload(floor_grid)

	var floor_boxes: Array[Dictionary] = []
	for box in native_payload.get("merged_boxes", []):
		if typeof(box) != TYPE_DICTIONARY:
			continue
		var floor_box: Dictionary = box.duplicate(true)
		floor_box["reason"] = FLOOR_REASON_WALKABLE_GROUND
		floor_box["source_layer"] = LAYER_GROUND
		floor_boxes.append(floor_box)

	var native_diagnostics: Dictionary = native_payload.get("diagnostics", {})
	var floor_cell_count := int(native_diagnostics.get("blocking_cell_count", 0))
	if floor_cell_count == 0 and floor_cell_count_expected > 0:
		return _local_floor_merge_payload(floor_grid)
	var floor_counts_by_reason := {}
	floor_counts_by_reason[FLOOR_REASON_WALKABLE_GROUND] = floor_cell_count
	var floor_counts_by_layer := {}
	floor_counts_by_layer[LAYER_GROUND] = floor_cell_count
	var floor_shape_counts_by_reason := {}
	floor_shape_counts_by_reason[FLOOR_REASON_WALKABLE_GROUND] = floor_boxes.size()
	var floor_shape_counts_by_layer := {}
	floor_shape_counts_by_layer[LAYER_GROUND] = floor_boxes.size()
	return {
		"merged_boxes": floor_boxes,
		"diagnostics": {
			"backend": "native_walkable_ground_floor_merge",
			"floor_cell_count": floor_cell_count,
			"floor_shape_count": floor_boxes.size(),
			"floor_merge_ratio": 0.0 if floor_cell_count == 0 else float(floor_boxes.size()) / float(floor_cell_count),
			"floor_counts_by_reason": floor_counts_by_reason,
			"floor_counts_by_layer": floor_counts_by_layer,
			"floor_shape_counts_by_reason": floor_shape_counts_by_reason,
			"floor_shape_counts_by_layer": floor_shape_counts_by_layer,
		},
	}


func _local_floor_merge_payload(floor_grid: Array) -> Dictionary:
	var width := _grid_width(floor_grid)
	var height := floor_grid.size()
	var merged_boxes: Array[Dictionary] = []
	var counts_by_reason := {}
	var counts_by_layer := {}
	var shape_counts_by_reason := {}
	var shape_counts_by_layer := {}
	var floor_cell_seen := {}

	_append_local_merged_boxes_for_group(
		merged_boxes,
		counts_by_reason,
		counts_by_layer,
		shape_counts_by_reason,
		shape_counts_by_layer,
		floor_cell_seen,
		floor_grid,
		width,
		height,
		FLOOR_REASON_WALKABLE_GROUND,
		LAYER_GROUND
	)

	var floor_cell_count := floor_cell_seen.size()
	return {
		"merged_boxes": merged_boxes,
		"diagnostics": {
			"backend": "local_walkable_ground_floor_merge",
			"floor_cell_count": floor_cell_count,
			"floor_shape_count": merged_boxes.size(),
			"floor_merge_ratio": 0.0 if floor_cell_count == 0 else float(merged_boxes.size()) / float(floor_cell_count),
			"floor_counts_by_reason": counts_by_reason,
			"floor_counts_by_layer": counts_by_layer,
			"floor_shape_counts_by_reason": shape_counts_by_reason,
			"floor_shape_counts_by_layer": shape_counts_by_layer,
		},
	}


func _walkable_ground_floor_grid(topology_layers: Dictionary) -> Array:
	var ground_grid: Array = topology_layers.get(LAYER_GROUND, [])
	if ground_grid.is_empty():
		return []
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, [])
	var water_grid: Array = topology_layers.get(LAYER_WATER, [])
	var width := maxi(_grid_width(ground_grid), maxi(_grid_width(solid_grid), _grid_width(water_grid)))
	var height := maxi(ground_grid.size(), maxi(solid_grid.size(), water_grid.size()))
	var floor_grid: Array = []
	for y in range(height):
		var row: Array[int] = []
		for x in range(width):
			var cell := Vector2i(x, y)
			var is_walkable_ground := (
				_grid_cell(ground_grid, cell) != 0
				and _grid_cell(solid_grid, cell) == 0
				and _grid_cell(water_grid, cell) == 0
			)
			row.append(1 if is_walkable_ground else 0)
		floor_grid.append(row)
	return floor_grid


func _zero_grid_like(grid: Array) -> Array:
	var zero_grid: Array = []
	for row in grid:
		var zero_row: Array[int] = []
		var width := int(row.size()) if typeof(row) == TYPE_ARRAY else 0
		for _x in range(width):
			zero_row.append(0)
		zero_grid.append(zero_row)
	return zero_grid


func _grid_nonzero_count(grid: Array) -> int:
	var count := 0
	for y in range(grid.size()):
		var row: Variant = grid[y]
		if typeof(row) != TYPE_ARRAY:
			continue
		for x in range(int(row.size())):
			if int(row[x]) != 0:
				count += 1
	return count


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


func _collision_consumed_fields(collision_source: Dictionary, include_ground_floor: bool = false) -> PackedStringArray:
	var consumed_fields := PackedStringArray()
	var topology_layers: Dictionary = _topology_layers_from_collision_source(collision_source)
	if include_ground_floor and topology_layers.has(LAYER_GROUND):
		consumed_fields.append("topology_layers.ground" if collision_source.has("topology_layers") else "topology_projection_set.ground")
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
