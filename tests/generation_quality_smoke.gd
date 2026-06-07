extends SceneTree

var failed := false


func _initialize() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var provider: Node = Provider.new()
	provider.world_seed = 99
	provider.generator_version = 11
	provider.wall_threshold_percent = 44
	provider.smoothing_passes = 2
	provider.room_attempts = 4
	provider.room_min_size = 3
	provider.room_max_size = 7

	var chunk_coord := Vector3i(3, 0, -2)
	var result_a: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var result_b: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	_assert(_grid_signature(result_a["logic_grid"]) == _grid_signature(result_b["logic_grid"]), "quality generator is deterministic")
	_assert(result_a["debug_markers"].size() > 0, "debug markers are emitted")
	_assert(_has_marker_type(result_a["debug_markers"], "room"), "room markers are emitted")
	_assert(_has_marker_type(result_a["debug_markers"], "path"), "path markers are emitted")

	var generated_data: Dictionary = provider.make_generated_chunk_data(chunk_coord, result_a["logic_grid"])
	_assert(generated_data.has("generation_settings"), "generated data carries generation settings")
	_assert(generated_data["debug_markers"].size() > 0, "generated data carries debug markers")

	var initial_hash: int = provider.generation_settings_hash()
	provider.smoothing_passes += 1
	_assert(initial_hash != provider.generation_settings_hash(), "settings hash changes with smoothing")
	provider.smoothing_passes -= 1
	provider.generator_version += 1
	_assert(initial_hash != provider.generation_settings_hash(), "settings hash changes with generator version")

	provider.generator_version = 11
	provider.configure_chunk_cache(true)
	provider._load_chunk_content(chunk_coord)
	_assert(provider.cache_miss_count == 1, "first cached load misses")
	provider.loaded_chunks.clear()
	provider._load_chunk_content(chunk_coord)
	_assert(provider.cache_hit_count == 1, "same settings hit cache")
	provider.generator_version = 12
	provider._load_chunk_content(chunk_coord)
	_assert(provider.cache_miss_count == 2, "version change misses cache")

	provider.wall_threshold_percent = 0
	provider.room_attempts = 0
	provider.smoothing_passes = 2
	provider.debug_force_chunk_border = false
	var left: Array = provider.generate_chunk_logic_grid(Vector3i(0, 0, 0))
	var right: Array = provider.generate_chunk_logic_grid(Vector3i(1, 0, 0))
	_assert(not _edge_is_wall(left, "right"), "left edge remains seamless without forced border")
	_assert(not _edge_is_wall(right, "left"), "right edge remains seamless without forced border")

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


func _has_marker_type(markers: Array, marker_type: String) -> bool:
	for marker in markers:
		var data: Dictionary = marker
		if data.get("type", "") == marker_type:
			return true
	return false


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
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("generation_quality_smoke failed: %s" % message)
