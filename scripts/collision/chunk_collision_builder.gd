extends RefCounted

const DEFAULT_COLLISION_HEIGHT_METERS := 0.8


func build_chunk_collision(
	chunk_coord: Vector3i,
	visual_plan: Dictionary,
	chunk_edge_meters: float,
	cells_per_chunk: int
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ChunkCollision"
	body.set_meta("chunk_coord", chunk_coord)
	body.set_meta("source_product_type", visual_plan.get("product_type", ""))
	body.set_meta("collision_backend", "box_per_visual_tile")

	var visual_tiles: Array = visual_plan.get("visual_tiles", visual_plan.get("tiles", []))
	var cell_size_meters: float = chunk_edge_meters / float(maxi(cells_per_chunk, 1))
	var shape_size := Vector3(
		cell_size_meters,
		DEFAULT_COLLISION_HEIGHT_METERS,
		cell_size_meters
	)
	var collision_count := 0

	for tile in visual_tiles:
		var data: Dictionary = tile
		if bool(data.get("is_empty", false)):
			continue
		var shape := BoxShape3D.new()
		shape.size = shape_size
		var shape_node := CollisionShape3D.new()
		shape_node.name = "TileCollision_%s_%s" % [data["corner"].x, data["corner"].y]
		shape_node.shape = shape
		shape_node.position = _tile_collision_origin(data["corner"], cell_size_meters)
		shape_node.set_meta("visual_corner", data["corner"])
		shape_node.set_meta("asset_key", data["asset_key"])
		body.add_child(shape_node)
		collision_count += 1

	body.set_meta("collision_shape_count", collision_count)
	return body


func get_collision_diagnostics(collision_body: StaticBody3D) -> Dictionary:
	if collision_body == null:
		return {
			"has_collision": false,
			"collision_shape_count": 0,
		}
	return {
		"has_collision": true,
		"chunk_coord": collision_body.get_meta("chunk_coord", Vector3i.ZERO),
		"collision_backend": collision_body.get_meta("collision_backend", ""),
		"collision_shape_count": int(collision_body.get_meta("collision_shape_count", 0)),
	}


func _tile_collision_origin(corner: Vector2i, cell_size_meters: float) -> Vector3:
	return Vector3(
		(float(corner.x) + 0.5) * cell_size_meters,
		DEFAULT_COLLISION_HEIGHT_METERS * 0.5,
		(float(corner.y) + 0.5) * cell_size_meters
	)
