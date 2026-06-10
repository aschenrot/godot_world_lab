extends RefCounted

class_name GeneratedChunkDataAdapter

const PRODUCT_COMPAT_GENERATED_CHUNK_DATA := "generated_chunk_data"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"


static func generation_result_from_world_chunk(world_chunk: GeneratedWorldChunk) -> Dictionary:
	if world_chunk == null:
		return {}
	if not world_chunk.legacy_generation_result.is_empty():
		return normalize_generation_result(world_chunk.legacy_generation_result)

	var terrain_cells: Array = world_chunk.world_layers.get("legacy_terrain_cells", [])
	var topology_layers: Dictionary = world_chunk.topology_projections.duplicate(true)
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, [])
	var debug_markers: Array = world_chunk.world_features.get("legacy_debug_markers", [])
	var diagnostics: Dictionary = world_chunk.generation_diagnostics.duplicate(true)
	if diagnostics.is_empty():
		diagnostics = {"authority": "generated_world_chunk_adapter"}

	return normalize_generation_result({
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"logic_grid": solid_grid,
		"debug_markers": debug_markers,
		"diagnostics": diagnostics,
	})


static func logic_grid_from_world_chunk(world_chunk: GeneratedWorldChunk) -> Array:
	return generation_result_from_world_chunk(world_chunk).get("logic_grid", [])


static func normalize_generation_result(generation_result: Dictionary) -> Dictionary:
	if generation_result.is_empty():
		return {}

	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	var logic_grid: Array = generation_result.get("logic_grid", [])
	if topology_layers.is_empty() and not logic_grid.is_empty():
		topology_layers = _topology_layers_from_logic_grid(logic_grid)
	if logic_grid.is_empty() and topology_layers.has(LAYER_SOLID):
		logic_grid = topology_layers[LAYER_SOLID].duplicate(true)

	return {
		"terrain_cells": generation_result.get("terrain_cells", []),
		"topology_layers": topology_layers.duplicate(true),
		"logic_grid": logic_grid.duplicate(true),
		"debug_markers": generation_result.get("debug_markers", []),
		"diagnostics": generation_result.get("diagnostics", {}),
	}


static func generated_chunk_data_from_world_chunk(
	world_chunk: GeneratedWorldChunk,
	formation_layers: Dictionary = {},
	generation_settings: Dictionary = {}
) -> Dictionary:
	if world_chunk == null:
		return {}
	var generation_result := generation_result_from_world_chunk(world_chunk)
	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	var logic_grid: Array = generation_result.get("logic_grid", [])
	var diagnostics: Dictionary = generation_result.get("diagnostics", {})
	return {
		"product_type": "GeneratedChunkData",
		"authority": "local_lab_only",
		"chunk_coord": world_chunk.identity.chunk_coord if world_chunk.identity != null else Vector3i.ZERO,
		"generator_version": world_chunk.identity.world_definition_version if world_chunk.identity != null else 0,
		"generation_settings_hash": world_chunk.identity.generation_settings_hash if world_chunk.identity != null else 0,
		"terrain_cells": generation_result.get("terrain_cells", []),
		"topology_layers": topology_layers,
		"formation_layers": formation_layers.duplicate(true),
		"logic_grid": logic_grid,
		"debug_markers": generation_result.get("debug_markers", []),
		"generation_settings": generation_settings.duplicate(true),
		"diagnostics": diagnostics,
	}


static func _topology_layers_from_logic_grid(logic_grid: Array) -> Dictionary:
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
