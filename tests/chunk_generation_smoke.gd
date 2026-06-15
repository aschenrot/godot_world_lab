extends SceneTree

var failed: bool = false


func _initialize() -> void:
	var provider: Node = Node.new()
	provider.set_script(load("res://scripts/chunk_provider.gd"))
	provider.chunk_size_cells = 16
	provider.generator_version = 7
	provider.world_seed = 42
	provider.wall_threshold_percent = 34
	provider.debug_force_chunk_border = false

	var coord := Vector3i(4, 0, -2)
	var same_a: Array = provider.generate_chunk_logic_grid(coord)
	var same_b: Array = provider.generate_chunk_logic_grid(coord)
	var different: Array = provider.generate_chunk_logic_grid(Vector3i(5, 0, -2))
	var layered_result: Dictionary = GeneratedChunkDataAdapter.generation_result_from_world_chunk(
		provider._world_generation_session().generate_world_chunk(
			coord,
			true,
			true,
			{"diagnostics_enabled": true}
		),
		true
	)
	var settings_hash_a: int = provider.generation_settings_hash()

	_assert(_grid_signature(same_a) == _grid_signature(same_b), "same coordinate is deterministic")
	_assert(layered_result.has("terrain_cells"), "generation emits terrain cells")
	_assert(layered_result.has("topology_layers"), "generation emits topology layers")
	_assert(_grid_signature(layered_result["logic_grid"]) == _grid_signature(layered_result["topology_layers"]["solid"]), "logic grid aliases solid layer")
	_assert(_grid_signature(same_a) != _grid_signature(different), "different coordinate changes layout")
	_assert(same_a.size() == 16, "grid has expected row count")
	_assert(same_a[0].size() == 16, "grid has expected column count")
	_assert(not _outer_ring_is_wall(same_a), "outer ring is not forced by default")
	_assert(_has_empty_cell(same_a), "grid contains empty cells")
	_assert(_has_wall_cell(same_a), "grid contains wall cells")

	provider.world_seed = 43
	var different_seed: Array = provider.generate_chunk_logic_grid(coord)
	_assert(
		_grid_signature(same_a) != _grid_signature(different_seed),
		"different seed changes generated output"
	)

	provider.world_seed = 42
	provider.wall_threshold_percent = 0
	provider.debug_force_chunk_border = false
	var left_chunk: Array = provider.generate_chunk_logic_grid(Vector3i(0, 0, 0))
	var right_chunk: Array = provider.generate_chunk_logic_grid(Vector3i(1, 0, 0))
	_assert(not _outer_ring_is_wall(left_chunk), "threshold zero leaves left chunk border open")
	_assert(not _outer_ring_is_wall(right_chunk), "threshold zero leaves right chunk border open")
	_assert(not _edge_is_wall(left_chunk, "right"), "left chunk right edge is not a forced seam")
	_assert(not _edge_is_wall(right_chunk, "left"), "right chunk left edge is not a forced seam")

	provider.debug_force_chunk_border = true
	var forced_border: Array = provider.generate_chunk_logic_grid(coord)
	_assert(_outer_ring_is_wall(forced_border), "debug border forces outer ring walls")
	_assert(
		settings_hash_a != provider.generation_settings_hash(),
		"generation settings hash changes when border setting changes"
	)

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


func _edge_is_wall(grid: Array, edge: String) -> bool:
	var size := grid.size()
	if edge == "left":
		for y in range(size):
			if grid[y][0] != 1:
				return false
		return true
	if edge == "right":
		for y in range(size):
			if grid[y][size - 1] != 1:
				return false
		return true
	if edge == "top":
		for x in range(size):
			if grid[0][x] != 1:
				return false
		return true
	if edge == "bottom":
		for x in range(size):
			if grid[size - 1][x] != 1:
				return false
		return true
	return false


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
