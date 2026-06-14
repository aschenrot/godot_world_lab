extends RefCounted

class_name LegacyChunkGenerator

const TERRAIN_AUTHORITY := "local_lab_only"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]
const SELF_SCRIPT_PATH := "res://scripts/world_generation/legacy/legacy_chunk_generator.gd"

var settings: Dictionary = {}


static func from_settings(p_settings: Dictionary = {}) -> RefCounted:
	var generator: RefCounted = load(SELF_SCRIPT_PATH).new()
	return generator.configure(p_settings)


func configure(p_settings: Dictionary = {}) -> RefCounted:
	settings = p_settings.duplicate(true)
	return self


func duplicate_generator() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_settings(settings)


func generate_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
	var payload := generate_terrain_payload(chunk_coord)
	var terrain_cells: Array = payload.get("terrain_cells", [])
	var topology_layers: Dictionary = payload.get("topology_layers", {})
	var debug_markers: Array = payload.get("debug_markers", [])
	var diagnostics := terrain_diagnostics(terrain_cells, topology_layers)
	return {
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"logic_grid": topology_layers[LAYER_SOLID].duplicate(true),
		"debug_markers": debug_markers if bool(settings.get("debug_generation_markers_enabled", true)) else [],
		"diagnostics": diagnostics,
	}


func generate_topology_layers_only(chunk_coord: Vector3i) -> Dictionary:
	return generate_terrain_payload(chunk_coord).get("topology_layers", {})


func generate_terrain_payload(chunk_coord: Vector3i) -> Dictionary:
	var size: int = effective_chunk_size_cells()
	var solid_layer := generate_smoothed_solid_layer(chunk_coord, size)
	var terrain_cells := generate_base_terrain_cells(chunk_coord, size, solid_layer)
	var debug_markers: Array = []

	carve_rooms_and_paths(chunk_coord, terrain_cells, debug_markers)
	if should_enforce_walkable_target():
		repair_walkable_connectivity(terrain_cells, debug_markers)
		balance_walkable_percent(terrain_cells, debug_markers)

	if bool(settings.get("debug_force_chunk_border", false)):
		apply_forced_chunk_border(terrain_cells)

	return {
		"terrain_cells": terrain_cells,
		"topology_layers": derive_topology_layers(terrain_cells),
		"debug_markers": debug_markers,
	}


func generate_base_terrain_cells(chunk_coord: Vector3i, size: int, solid_layer: Array) -> Array:
	var height_noise := _make_fast_noise(_mix(_world_seed(), 0x1101), _float_setting("terrain_noise_frequency", 0.065))
	var liquid_noise := _make_fast_noise(_mix(_world_seed(), 0x2202), _float_setting("liquid_noise_frequency", 0.045))
	var terrain_cells: Array = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			var local_cell := Vector2i(x, y)
			var world_cell := world_cell_from_chunk_local(chunk_coord, local_cell)
			var height_percent := _noise_percent(height_noise, world_cell)
			var liquid_percent := _noise_percent(liquid_noise, world_cell + Vector2i(517, -911))
			var liquid := (
				height_percent < clampi(_int_setting("liquid_threshold_percent", 35), 0, 100)
				or liquid_percent < clampi(_int_setting("liquid_threshold_percent", 35) / 2, 0, 100)
			)
			var solid := int(solid_layer[y][x]) == 1 and not liquid
			row.append(make_terrain_cell(height_percent, liquid, solid))
		terrain_cells.append(row)
	return terrain_cells


func make_terrain_cell(height_percent: int, liquid: bool, solid: bool) -> Dictionary:
	var surface := "water" if liquid else "ground"
	var material := "water" if liquid else ("rock" if solid else "ground")
	return {
		"product_type": "LabTerrainCell",
		"authority": TERRAIN_AUTHORITY,
		"surface": surface,
		"walkable": _walkable_from_flags(liquid, solid),
		"solid": solid,
		"liquid": liquid,
		"height": float(height_percent) / 100.0,
		"height_percent": height_percent,
		"material": material,
		"flags": ["minable"] if solid else [],
	}


func set_cell_flags(cell: Dictionary, liquid: bool, solid: bool, height_percent: int = -1) -> Dictionary:
	var next_cell := cell.duplicate(true)
	next_cell["liquid"] = liquid
	next_cell["solid"] = solid
	next_cell["walkable"] = _walkable_from_flags(liquid, solid)
	next_cell["surface"] = "water" if liquid else "ground"
	next_cell["material"] = "water" if liquid else ("rock" if solid else "ground")
	next_cell["flags"] = ["minable"] if solid else []
	if height_percent >= 0:
		next_cell["height_percent"] = height_percent
		next_cell["height"] = float(height_percent) / 100.0
	return next_cell


func generate_smoothed_solid_layer(chunk_coord: Vector3i, size: int) -> Array:
	var margin: int = maxi(_int_setting("smoothing_passes", 1), 0)
	var solid_noise := _make_fast_noise(_mix(_world_seed(), 0x3303), _float_setting("solid_noise_frequency", 0.09))
	var expanded: Array = []
	for local_y in range(-margin, size + margin):
		var row: Array = []
		for local_x in range(-margin, size + margin):
			row.append(_initial_solid_cell(chunk_coord, Vector2i(local_x, local_y), solid_noise))
		expanded.append(row)

	for _pass_index in range(margin):
		expanded = _smooth_expanded_grid(expanded)

	var grid: Array = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			row.append(expanded[y + margin][x + margin])
		grid.append(row)
	return grid


func carve_rooms_and_paths(chunk_coord: Vector3i, terrain_cells: Array, debug_markers: Array) -> void:
	var rooms := room_rects_for_chunk(chunk_coord, terrain_cells.size())
	var centers: Array[Vector2i] = []
	for room in rooms:
		var rect: Rect2i = room
		carve_rect(terrain_cells, rect)
		var center := rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)
		centers.append(center)
		debug_markers.append({
			"type": "room",
			"chunk_coord": chunk_coord,
			"rect_position": rect.position,
			"rect_size": rect.size,
			"center": center,
		})

	for index in range(1, centers.size()):
		carve_path(terrain_cells, centers[index - 1], centers[index])
		debug_markers.append({
			"type": "path",
			"chunk_coord": chunk_coord,
			"from": centers[index - 1],
			"to": centers[index],
		})


func room_rects_for_chunk(chunk_coord: Vector3i, size: int) -> Array:
	var rects: Array[Rect2i] = []
	var clamped_min := clampi(_int_setting("room_min_size", 3), 2, size)
	var clamped_max := clampi(maxi(_int_setting("room_max_size", 6), clamped_min), clamped_min, size)
	for index in range(maxi(_int_setting("room_attempts", 3), 0)):
		var seed := _mix(_mix(_mix(_world_seed(), _generator_version()), chunk_coord.x), chunk_coord.z)
		seed = _mix(seed, index)
		var width := _range_from_hash(_mix(seed, 11), clamped_min, clamped_max)
		var height := _range_from_hash(_mix(seed, 17), clamped_min, clamped_max)
		var max_x := maxi(size - width - 1, 1)
		var max_y := maxi(size - height - 1, 1)
		var x := _range_from_hash(_mix(seed, 23), 1, max_x)
		var y := _range_from_hash(_mix(seed, 29), 1, max_y)
		rects.append(Rect2i(Vector2i(x, y), Vector2i(width, height)))
	return rects


func carve_rect(terrain_cells: Array, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if grid_contains(terrain_cells, x, y):
				terrain_cells[y][x] = set_cell_flags(terrain_cells[y][x], false, false)


func carve_path(terrain_cells: Array, start: Vector2i, end: Vector2i) -> void:
	var x_step := 1 if end.x >= start.x else -1
	for x in range(start.x, end.x + x_step, x_step):
		if grid_contains(terrain_cells, x, start.y):
			terrain_cells[start.y][x] = set_cell_flags(terrain_cells[start.y][x], false, false)
	var y_step := 1 if end.y >= start.y else -1
	for y in range(start.y, end.y + y_step, y_step):
		if grid_contains(terrain_cells, end.x, y):
			terrain_cells[y][end.x] = set_cell_flags(terrain_cells[y][end.x], false, false)


func apply_forced_chunk_border(terrain_cells: Array) -> void:
	var size := terrain_cells.size()
	for i in range(size):
		terrain_cells[0][i] = set_cell_flags(terrain_cells[0][i], false, true)
		terrain_cells[size - 1][i] = set_cell_flags(terrain_cells[size - 1][i], false, true)
		terrain_cells[i][0] = set_cell_flags(terrain_cells[i][0], false, true)
		terrain_cells[i][size - 1] = set_cell_flags(terrain_cells[i][size - 1], false, true)


func should_enforce_walkable_target() -> bool:
	return _int_setting("wall_threshold_percent", 16) > 0 \
		and _int_setting("wall_threshold_percent", 16) < 100 \
		and not bool(settings.get("debug_force_chunk_border", false))


func repair_walkable_connectivity(terrain_cells: Array, debug_markers: Array) -> void:
	var components := walkable_components(terrain_cells)
	if components.size() <= 1:
		return

	var anchor_component: Array = components[0]
	var anchor: Vector2i = anchor_component[0]
	for index in range(1, components.size()):
		var component: Array = components[index]
		if component.is_empty():
			continue
		var start: Vector2i = component[0]
		carve_walkable_path(terrain_cells, start, anchor)
		debug_markers.append({
			"type": "connectivity_repair",
			"from": start,
			"to": anchor,
			"component_size": component.size(),
		})


func balance_walkable_percent(terrain_cells: Array, debug_markers: Array) -> void:
	var target_min := clampi(_int_setting("target_walkable_min_percent", 70), 0, 100)
	var target_max := clampi(maxi(_int_setting("target_walkable_max_percent", 80), target_min), target_min, 100)
	var total := terrain_cells.size() * int(terrain_cells[0].size()) if not terrain_cells.is_empty() else 0
	if total <= 0:
		return

	var walkable_count := walkable_cell_count(terrain_cells)
	var min_count := int(ceil(float(total * target_min) / 100.0))
	var max_count := int(floor(float(total * target_max) / 100.0))

	if walkable_count < min_count:
		var candidates := sorted_cells_by_hash(terrain_cells, false)
		for cell in candidates:
			if walkable_count >= min_count:
				break
			var coord: Vector2i = cell
			terrain_cells[coord.y][coord.x] = set_cell_flags(terrain_cells[coord.y][coord.x], false, false)
			walkable_count += 1
		debug_markers.append({
			"type": "walkability_balance_open",
			"target_min_percent": target_min,
			"walkable_count": walkable_count,
		})
	elif walkable_count > max_count:
		var blockers := sorted_cells_by_hash(terrain_cells, true)
		for cell in blockers:
			if walkable_count <= max_count:
				break
			var coord: Vector2i = cell
			terrain_cells[coord.y][coord.x] = set_cell_flags(terrain_cells[coord.y][coord.x], false, true)
			walkable_count -= 1
		debug_markers.append({
			"type": "walkability_balance_block",
			"target_max_percent": target_max,
			"walkable_count": walkable_count,
		})


func sorted_cells_by_hash(terrain_cells: Array, want_walkable: bool) -> Array:
	var scored: Array[Dictionary] = []
	for y in range(terrain_cells.size()):
		for x in range(int(terrain_cells[y].size())):
			var cell: Dictionary = terrain_cells[y][x]
			if bool(cell.get("walkable", false)) != want_walkable:
				continue
			var h := _mix(_mix(_mix(_world_seed(), _generator_version()), x), y)
			scored.append({"cell": Vector2i(x, y), "score": abs(_finalize_hash(h))})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) < int(b["score"]))
	var cells: Array[Vector2i] = []
	for entry in scored:
		cells.append(entry["cell"])
	return cells


func carve_walkable_path(terrain_cells: Array, start: Vector2i, end: Vector2i) -> void:
	var x_step := 1 if end.x >= start.x else -1
	for x in range(start.x, end.x + x_step, x_step):
		if grid_contains(terrain_cells, x, start.y):
			terrain_cells[start.y][x] = set_cell_flags(terrain_cells[start.y][x], false, false)
	var y_step := 1 if end.y >= start.y else -1
	for y in range(start.y, end.y + y_step, y_step):
		if grid_contains(terrain_cells, end.x, y):
			terrain_cells[y][end.x] = set_cell_flags(terrain_cells[y][end.x], false, false)


func derive_topology_layers(terrain_cells: Array) -> Dictionary:
	var ground: Array = []
	var solid: Array = []
	var water: Array = []
	var cliff: Array = []
	for row in terrain_cells:
		var ground_row: Array = []
		var solid_row: Array = []
		var water_row: Array = []
		var cliff_row: Array = []
		for value in row:
			var cell: Dictionary = value
			var is_liquid := bool(cell.get("liquid", false))
			ground_row.append(0 if is_liquid else 1)
			solid_row.append(1 if bool(cell.get("solid", false)) else 0)
			water_row.append(1 if is_liquid else 0)
			cliff_row.append(0)
		ground.append(ground_row)
		solid.append(solid_row)
		water.append(water_row)
		cliff.append(cliff_row)
	return {
		LAYER_GROUND: ground,
		LAYER_SOLID: solid,
		LAYER_WATER: water,
		LAYER_CLIFF: cliff,
	}


func terrain_diagnostics(terrain_cells: Array, topology_layers: Dictionary) -> Dictionary:
	var total := 0
	var walkable := 0
	var solid := 0
	var liquid := 0
	for row in terrain_cells:
		for value in row:
			var cell: Dictionary = value
			total += 1
			if bool(cell.get("walkable", false)):
				walkable += 1
			if bool(cell.get("solid", false)):
				solid += 1
			if bool(cell.get("liquid", false)):
				liquid += 1

	var components := walkable_components(terrain_cells)
	var dominant := 0
	if not components.is_empty():
		dominant = int(components[0].size())
	return {
		"authority": TERRAIN_AUTHORITY,
		"layer_ids": ordered_layer_ids(topology_layers),
		"cell_count": total,
		"walkable_cell_count": walkable,
		"solid_cell_count": solid,
		"liquid_cell_count": liquid,
		"open_percent": percent(walkable, total),
		"solid_percent": percent(solid, total),
		"liquid_percent": percent(liquid, total),
		"connected_walkable_region_count": components.size(),
		"dominant_walkable_region": dominant,
		"dominant_walkable_percent": percent(dominant, total),
		"generation_settings_hash": generation_settings_hash(),
		"generator_version": _generator_version(),
		"logic_grid_alias": "topology_layers.solid",
	}


func generation_result_from_logic_grid(logic_grid: Array) -> Dictionary:
	var topology_layers := topology_layers_from_logic_grid(logic_grid)
	var terrain_cells := terrain_cells_from_logic_grid(logic_grid)
	return {
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"debug_markers": [],
		"diagnostics": terrain_diagnostics(terrain_cells, topology_layers),
	}


func topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
	var ground: Array = []
	var water: Array = []
	var cliff: Array = []
	for row in logic_grid:
		var ground_row: Array = []
		var water_row: Array = []
		var cliff_row: Array = []
		for _cell in row:
			ground_row.append(1)
			water_row.append(0)
			cliff_row.append(0)
		ground.append(ground_row)
		water.append(water_row)
		cliff.append(cliff_row)
	return {
		LAYER_GROUND: ground,
		LAYER_SOLID: logic_grid.duplicate(true),
		LAYER_WATER: water,
		LAYER_CLIFF: cliff,
	}


func terrain_cells_from_logic_grid(logic_grid: Array) -> Array:
	var terrain_cells: Array = []
	for row in logic_grid:
		var terrain_row: Array = []
		for cell in row:
			terrain_row.append(make_terrain_cell(50, false, int(cell) == 1))
		terrain_cells.append(terrain_row)
	return terrain_cells


func percent(count: int, total: int) -> int:
	if total <= 0:
		return 0
	return int(round(float(count) * 100.0 / float(total)))


func walkable_components(terrain_cells: Array) -> Array:
	var components: Array = []
	var visited: Dictionary = {}
	for y in range(terrain_cells.size()):
		for x in range(int(terrain_cells[y].size())):
			var start := Vector2i(x, y)
			if visited.has(cell_key(start)) or not terrain_cell_walkable(terrain_cells, start):
				continue
			var component := flood_walkable_component(terrain_cells, start, visited)
			components.append(component)
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return components


func flood_walkable_component(terrain_cells: Array, start: Vector2i, visited: Dictionary) -> Array:
	var component: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	visited[cell_key(start)] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		component.append(cell)
		for neighbor in [
			cell + Vector2i.LEFT,
			cell + Vector2i.RIGHT,
			cell + Vector2i.UP,
			cell + Vector2i.DOWN,
		]:
			if visited.has(cell_key(neighbor)) or not terrain_cell_walkable(terrain_cells, neighbor):
				continue
			visited[cell_key(neighbor)] = true
			queue.append(neighbor)
	return component


func terrain_cell_walkable(terrain_cells: Array, cell: Vector2i) -> bool:
	if not grid_contains(terrain_cells, cell.x, cell.y):
		return false
	return bool(terrain_cells[cell.y][cell.x].get("walkable", false))


func walkable_cell_count(terrain_cells: Array) -> int:
	var count := 0
	for row in terrain_cells:
		for value in row:
			var cell: Dictionary = value
			if bool(cell.get("walkable", false)):
				count += 1
	return count


func ordered_layer_ids(topology_layers: Dictionary) -> Array:
	var ordered: Array[String] = []
	for layer_id in TOPOLOGY_LAYER_ORDER:
		if topology_layers.has(layer_id):
			ordered.append(layer_id)
	var extra: Array = topology_layers.keys()
	extra.sort()
	for layer_id in extra:
		if not ordered.has(String(layer_id)):
			ordered.append(String(layer_id))
	return ordered


func grid_contains(grid: Array, x: int, y: int) -> bool:
	return y >= 0 and y < grid.size() and x >= 0 and x < int(grid[y].size())


func world_cell_from_chunk_local(chunk_coord: Vector3i, local_cell: Vector2i) -> Vector2i:
	var size := effective_chunk_size_cells()
	return Vector2i(chunk_coord.x * size + local_cell.x, chunk_coord.z * size + local_cell.y)


func effective_chunk_size_cells() -> int:
	return maxi(_int_setting("effective_chunk_size_cells", _int_setting("chunk_size_cells", 16)), 4)


func generation_settings_hash() -> int:
	var h: int = 0x2d2816fe
	h = _mix(h, _world_seed())
	h = _mix(h, _generator_version())
	h = _mix(h, _int_setting("chunk_size_cells", 16))
	h = _mix(h, _int_setting("wall_threshold_percent", 16))
	h = _mix(h, 1 if bool(settings.get("debug_force_chunk_border", false)) else 0)
	h = _mix(h, _int_setting("smoothing_passes", 1))
	h = _mix(h, _int_setting("room_attempts", 3))
	h = _mix(h, _int_setting("room_min_size", 3))
	h = _mix(h, _int_setting("room_max_size", 6))
	h = _mix(h, int(round(_float_setting("terrain_noise_frequency", 0.065) * 10000.0)))
	h = _mix(h, int(round(_float_setting("liquid_noise_frequency", 0.045) * 10000.0)))
	h = _mix(h, int(round(_float_setting("solid_noise_frequency", 0.09) * 10000.0)))
	h = _mix(h, _int_setting("liquid_threshold_percent", 35))
	h = _mix(h, _int_setting("target_walkable_min_percent", 70))
	h = _mix(h, _int_setting("target_walkable_max_percent", 80))
	h = _mix(h, 1 if bool(settings.get("liquid_blocks_movement", true)) else 0)
	h = _mix(h, 1 if bool(settings.get("debug_generation_markers_enabled", true)) else 0)
	return abs(h)


func cell_key(cell: Vector2i) -> String:
	return "%s:%s" % [cell.x, cell.y]


func _walkable_from_flags(liquid: bool, solid: bool) -> bool:
	return not solid and not (bool(settings.get("liquid_blocks_movement", true)) and liquid)


func _initial_solid_cell(chunk_coord: Vector3i, cell: Vector2i, solid_noise: FastNoiseLite) -> int:
	if _int_setting("wall_threshold_percent", 16) <= 0:
		return 0
	if _int_setting("wall_threshold_percent", 16) >= 100:
		return 1
	var size := effective_chunk_size_cells()
	var world_cell := Vector2i(chunk_coord.x * size + cell.x, chunk_coord.z * size + cell.y)
	var noise_percent := _noise_percent(solid_noise, world_cell + Vector2i(-193, 389))
	return 1 if noise_percent < clampi(_int_setting("wall_threshold_percent", 16), 0, 100) else 0


func _make_fast_noise(seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = maxf(frequency, 0.001)
	return noise


func _noise_percent(noise: FastNoiseLite, world_cell: Vector2i) -> int:
	var sample := float(noise.get_noise_2d(float(world_cell.x), float(world_cell.y)))
	return clampi(int(round((sample * 0.5 + 0.5) * 100.0)), 0, 100)


func _smooth_expanded_grid(grid: Array) -> Array:
	var height := grid.size()
	var width := int(grid[0].size()) if height > 0 else 0
	var next_grid := grid.duplicate(true)
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var wall_count := 0
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					if offset_x == 0 and offset_y == 0:
						continue
					wall_count += int(grid[y + offset_y][x + offset_x])
			next_grid[y][x] = 1 if wall_count >= 5 else 0
	return next_grid


func _range_from_hash(hash_value: int, min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return min_value + abs(_finalize_hash(hash_value)) % (max_value - min_value + 1)


func _world_seed() -> int:
	return _int_setting("world_seed", 1337)


func _generator_version() -> int:
	return _int_setting("generator_version", 2)


func _int_setting(key: String, default_value: int) -> int:
	return int(settings.get(key, default_value))


func _float_setting(key: String, default_value: float) -> float:
	return float(settings.get(key, default_value))


static func _mix(seed: int, value: int) -> int:
	var h := seed ^ (value * 0x45d9f3b)
	h = h ^ (h >> 16)
	h *= 0x45d9f3b
	h = h ^ (h >> 16)
	return h


static func _finalize_hash(value: int) -> int:
	var h := value
	h = h ^ (h >> 16)
	h *= 0x7feb352d
	h = h ^ (h >> 15)
	h *= 0x846ca68b
	h = h ^ (h >> 16)
	return h
