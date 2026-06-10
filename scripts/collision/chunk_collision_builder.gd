extends RefCounted

const DEFAULT_COLLISION_HEIGHT_METERS := 0.8
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"


func build_chunk_collision(
	chunk_coord: Vector3i,
	collision_source: Dictionary,
	chunk_edge_meters: float,
	cells_per_chunk: int,
	options: Dictionary = {}
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ChunkCollision"
	body.set_meta("chunk_coord", chunk_coord)
	body.set_meta("source_product_type", collision_source.get("product_type", ""))
	body.set_meta("collision_backend", "box_per_collision_policy_cell")

	var collision_plan := build_collision_plan(chunk_coord, collision_source, options)
	body.set_meta("collision_plan", collision_plan)

	var cell_size_meters: float = chunk_edge_meters / float(maxi(cells_per_chunk, 1))
	var shape_size := Vector3(
		cell_size_meters,
		DEFAULT_COLLISION_HEIGHT_METERS,
		cell_size_meters
	)
	var collision_count := 0

	for cell in collision_plan.get("blocking_cells", []):
		var data: Dictionary = cell
		var coord: Vector2i = data["cell"]
		var shape := BoxShape3D.new()
		shape.size = shape_size
		var shape_node := CollisionShape3D.new()
		shape_node.name = "CellCollision_%s_%s" % [coord.x, coord.y]
		shape_node.shape = shape
		shape_node.position = _cell_collision_origin(coord, cell_size_meters)
		shape_node.set_meta("cell", coord)
		shape_node.set_meta("reason", data.get("reason", ""))
		shape_node.set_meta("source_layer", data.get("source_layer", ""))
		body.add_child(shape_node)
		collision_count += 1

	body.set_meta("collision_shape_count", collision_count)
	body.set_meta("collision_policy", collision_plan.get("policy", {}))
	return body


func build_collision_plan(
	chunk_coord: Vector3i,
	collision_source: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var topology_layers: Dictionary = collision_source.get("topology_layers", {})
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, collision_source.get("logic_grid", []))
	var water_grid: Array = topology_layers.get(LAYER_WATER, [])
	var liquid_blocks := bool(options.get("liquid_blocks_movement", true))
	var blocking_cells: Array[Dictionary] = []
	var solid_count := 0
	var liquid_count := 0

	for y in range(solid_grid.size()):
		for x in range(int(solid_grid[y].size())):
			var cell := Vector2i(x, y)
			var blocks_solid := _grid_cell(solid_grid, cell) == 1
			var blocks_liquid := liquid_blocks and _grid_cell(water_grid, cell) == 1
			if blocks_solid:
				solid_count += 1
			if blocks_liquid:
				liquid_count += 1
			if blocks_solid or blocks_liquid:
				blocking_cells.append({
					"cell": cell,
					"reason": "solid" if blocks_solid else "liquid_policy",
					"source_layer": LAYER_SOLID if blocks_solid else LAYER_WATER,
				})

	return {
		"product_type": "ChunkCollisionPlan",
		"chunk_coord": chunk_coord,
		"source_product_type": collision_source.get("product_type", ""),
		"blocking_cells": blocking_cells,
		"policy": {
			"solid_blocks_movement": true,
			"liquid_blocks_movement": liquid_blocks,
			"ground_visuals_block_movement": false,
		},
		"diagnostics": {
			"blocking_cell_count": blocking_cells.size(),
			"solid_blocking_cell_count": solid_count,
			"liquid_blocking_cell_count": liquid_count,
			"source_has_topology_layers": collision_source.has("topology_layers"),
		},
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
		"collision_policy": collision_body.get_meta("collision_policy", {}),
		"collision_plan_diagnostics": collision_plan.get("diagnostics", {}),
	}


func _cell_collision_origin(cell: Vector2i, cell_size_meters: float) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size_meters,
		DEFAULT_COLLISION_HEIGHT_METERS * 0.5,
		(float(cell.y) + 0.5) * cell_size_meters
	)


func _grid_cell(grid: Array, cell: Vector2i) -> int:
	if (
		cell.y < 0
		or cell.y >= grid.size()
		or cell.x < 0
		or cell.x >= int(grid[cell.y].size())
	):
		return 0
	return int(grid[cell.y][cell.x])
