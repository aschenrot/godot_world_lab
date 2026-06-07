extends SceneTree

var failed: bool = false


func _initialize() -> void:
	var provider: Node = Node.new()
	provider.set_script(load("res://scripts/chunk_provider.gd"))
	provider.chunk_size_cells = 16
	provider.generator_version = 7

	var coord := Vector3i(4, 0, -2)
	var same_a: Array = provider.generate_chunk_logic_grid(coord)
	var same_b: Array = provider.generate_chunk_logic_grid(coord)
	var different: Array = provider.generate_chunk_logic_grid(Vector3i(5, 0, -2))

	_assert(_grid_signature(same_a) == _grid_signature(same_b), "same coordinate is deterministic")
	_assert(_grid_signature(same_a) != _grid_signature(different), "different coordinate changes layout")
	_assert(same_a.size() == 16, "grid has expected row count")
	_assert(same_a[0].size() == 16, "grid has expected column count")
	_assert(_outer_ring_is_wall(same_a), "outer ring is wall")
	_assert(_has_empty_cell(same_a), "grid contains empty cells")
	_assert(_has_wall_cell(same_a), "grid contains wall cells")

	provider.free()
	quit(1 if failed else 0)


func _grid_signature(grid: Array) -> String:
	var parts: Array[String] = []
	for row in grid:
		var row_parts: Array[String] = []
		for cell in row:
			row_parts.append(str(cell))
		parts.append("".join(row_parts))
	return "|".join(parts)


func _outer_ring_is_wall(grid: Array) -> bool:
	var size := grid.size()
	for i in range(size):
		if grid[0][i] != 1:
			return false
		if grid[size - 1][i] != 1:
			return false
		if grid[i][0] != 1:
			return false
		if grid[i][size - 1] != 1:
			return false
	return true


func _has_empty_cell(grid: Array) -> bool:
	for row in grid:
		for cell in row:
			if cell == 0:
				return true
	return false


func _has_wall_cell(grid: Array) -> bool:
	for row in grid:
		for cell in row:
			if cell == 1:
				return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("chunk_generation_smoke failed: %s" % message)
