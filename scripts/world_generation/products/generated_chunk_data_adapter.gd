extends RefCounted

class_name GeneratedChunkDataAdapter

const PRODUCT_COMPAT_GENERATED_CHUNK_DATA := "generated_chunk_data"
const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const LEGACY_TERRAIN_LAYER_KEY := "legacy_terrain_cells"
const NATIVE_TERRAIN_LAYER_KEY := "native_terrain_cells"
const SEMANTIC_WORLD_LAYER_SET_KEY := "semantic_world_layer_set"
const SEMANTIC_LEGACY_TERRAIN_LAYER_KEY := "semantic_legacy_terrain_cells"
const SEMANTIC_NATIVE_TERRAIN_LAYER_KEY := "semantic_native_terrain_cells"
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")


static func generation_result_from_world_chunk(
	world_chunk: GeneratedWorldChunk,
	copy_output: bool = true
) -> Dictionary:
	if world_chunk == null:
		return {}

	var legacy_result := normalize_generation_result(world_chunk.legacy_generation_result, copy_output) \
		if not world_chunk.legacy_generation_result.is_empty() else {}
	var terrain_cells: Array = _terrain_cells_from_world_layers(world_chunk.world_layers, copy_output)
	if terrain_cells.is_empty():
		terrain_cells = legacy_result.get("terrain_cells", [])
	var topology_layers: Dictionary = _topology_layers_from_world_chunk(world_chunk, copy_output)
	if topology_layers.is_empty():
		topology_layers = legacy_result.get("topology_layers", {})
	var solid_grid: Array = topology_layers.get(LAYER_SOLID, [])
	if solid_grid.is_empty():
		solid_grid = legacy_result.get("logic_grid", [])
	var debug_markers: Array = world_chunk.world_features.get(GeneratedWorldChunk.NATIVE_DEBUG_MARKERS_KEY, [])
	if debug_markers.is_empty():
		debug_markers = world_chunk.world_features.get("legacy_debug_markers", [])
	if debug_markers.is_empty():
		debug_markers = legacy_result.get("debug_markers", [])
	var diagnostics: Dictionary = _copy_dictionary(legacy_result.get("diagnostics", {}), copy_output)
	if diagnostics.is_empty():
		diagnostics = _copy_dictionary(world_chunk.generation_diagnostics, copy_output)
	if diagnostics.is_empty():
		diagnostics = {"authority": "generated_world_chunk_adapter"}

	return normalize_generation_result({
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"logic_grid": solid_grid,
		"debug_markers": debug_markers,
		"diagnostics": diagnostics,
	}, copy_output)


static func logic_grid_from_world_chunk(world_chunk: GeneratedWorldChunk) -> Array:
	return generation_result_from_world_chunk(world_chunk).get("logic_grid", [])


static func logic_grid_from_generation_result(
	generation_result: Dictionary,
	copy_output: bool = true
) -> Array:
	return normalize_generation_result(generation_result, copy_output).get("logic_grid", [])


static func generation_result_without_logic_grid_alias(
	generation_result: Dictionary,
	copy_output: bool = true
) -> Dictionary:
	var normalized_result := normalize_generation_result(generation_result, copy_output)
	normalized_result.erase("logic_grid")
	return normalized_result


static func normalize_generation_result(
	generation_result: Dictionary,
	copy_output: bool = true
) -> Dictionary:
	if generation_result.is_empty():
		return {}

	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	var logic_grid: Array = generation_result.get("logic_grid", [])
	if topology_layers.is_empty() and not logic_grid.is_empty():
		topology_layers = _topology_layers_from_logic_grid(logic_grid)
	if logic_grid.is_empty() and topology_layers.has(LAYER_SOLID):
		logic_grid = topology_layers[LAYER_SOLID].duplicate(true) if copy_output else topology_layers[LAYER_SOLID]

	return {
		"terrain_cells": _copy_array(generation_result.get("terrain_cells", []), copy_output),
		"topology_layers": _copy_dictionary(topology_layers, copy_output),
		"logic_grid": _copy_array(logic_grid, copy_output),
		"debug_markers": _copy_array(generation_result.get("debug_markers", []), copy_output),
		"diagnostics": _copy_dictionary(generation_result.get("diagnostics", {}), copy_output),
	}


static func generated_chunk_data_from_world_chunk(
	world_chunk: GeneratedWorldChunk,
	formation_layers: Dictionary = {},
	generation_settings: Dictionary = {},
	copy_output: bool = true
) -> Dictionary:
	if world_chunk == null:
		return {}
	var generation_result := generation_result_from_world_chunk(world_chunk, copy_output)
	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	var logic_grid: Array = generation_result.get("logic_grid", [])
	var diagnostics: Dictionary = generation_result.get("diagnostics", {})
	var formation_product_set := _formation_product_set_from_world_chunk_or_layers(
		world_chunk,
		formation_layers,
		copy_output
	)
	var compatibility_formation_layers := _formation_layers_from_product_set(
		formation_product_set,
		formation_layers,
		copy_output
	)
	var solid_formation: Dictionary = compatibility_formation_layers.get(LAYER_SOLID, {})
	return {
		"product_type": "GeneratedChunkData",
		"authority": "godot_grid_native",
		"chunk_coord": world_chunk.identity.chunk_coord if world_chunk.identity != null else Vector3i.ZERO,
		"generator_version": world_chunk.identity.world_definition_version if world_chunk.identity != null else 0,
		"generation_settings_hash": world_chunk.identity.generation_settings_hash if world_chunk.identity != null else 0,
		"terrain_cells": generation_result.get("terrain_cells", []),
		"topology_layers": topology_layers,
		"formation_layers": compatibility_formation_layers,
		"formation_product_set": formation_product_set,
		"logic_grid": logic_grid,
		"formation_grid": solid_formation.get("formation_grid", []),
		"formation_origin_cell": solid_formation.get("formation_origin_cell", Vector2i(-1, -1)),
		"owned_visual_origin": solid_formation.get("owned_visual_origin", Vector2i.ZERO),
		"owned_visual_size": solid_formation.get("owned_visual_size", _grid_dimension_vec(logic_grid)),
		"formation_mode": solid_formation.get("formation_mode", "owned_halo"),
		"source_chunk_coords": solid_formation.get("source_chunk_coords", []),
		"debug_markers": generation_result.get("debug_markers", []),
		"generation_settings": _copy_dictionary(generation_settings, copy_output),
		"diagnostics": diagnostics,
	}


static func formation_product_set_from_formation_layers(
	formation_layers: Dictionary,
	bounds: Dictionary = {}
) -> Dictionary:
	if formation_layers.is_empty():
		return {}
	return FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		bounds
	).to_dictionary()


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


static func _topology_layers_from_world_chunk(
	world_chunk: GeneratedWorldChunk,
	copy_output: bool = true
) -> Dictionary:
	var topology_layers := _topology_layers_from_projection_set(
		world_chunk.topology_projection_set,
		copy_output
	)
	if not topology_layers.is_empty():
		return _filter_public_requested_topology_layers(
			topology_layers,
			world_chunk.topology_projection_set,
			copy_output
		)
	return _copy_dictionary(world_chunk.topology_projections, copy_output)


static func _topology_layers_from_projection_set(
	projection_set_data: Variant,
	copy_output: bool = true
) -> Dictionary:
	if typeof(projection_set_data) != TYPE_DICTIONARY:
		return {}

	var projection_set_dictionary: Dictionary = projection_set_data
	var projections: Variant = projection_set_dictionary.get("projections", {})
	if typeof(projections) == TYPE_DICTIONARY:
		var topology_layers: Dictionary = {}
		var projections_dictionary: Dictionary = projections
		for projection_id in projections_dictionary.keys():
			var projection_data: Variant = projections_dictionary[projection_id]
			if typeof(projection_data) != TYPE_DICTIONARY:
				continue
			var projection_dictionary: Dictionary = projection_data
			var grid: Variant = projection_dictionary.get("grid", [])
			if typeof(grid) == TYPE_ARRAY:
				var grid_array: Array = grid
				topology_layers[String(projection_id)] = _copy_array(grid_array, copy_output)
		if not topology_layers.is_empty():
			return topology_layers

	var legacy_layers: Variant = projection_set_dictionary.get("topology_layers", {})
	if typeof(legacy_layers) == TYPE_DICTIONARY:
		return _copy_dictionary(legacy_layers, copy_output)
	return {}


static func _filter_public_requested_topology_layers(
	topology_layers: Dictionary,
	projection_set_data: Variant,
	copy_output: bool = true
) -> Dictionary:
	if typeof(projection_set_data) != TYPE_DICTIONARY:
		return _copy_dictionary(topology_layers, copy_output)
	var projection_set_dictionary: Dictionary = projection_set_data
	var metadata: Variant = projection_set_dictionary.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY:
		return _copy_dictionary(topology_layers, copy_output)
	var metadata_dictionary: Dictionary = metadata
	var requested_ids: PackedStringArray = _to_packed_string_array(
		metadata_dictionary.get("requested_topology_projections", PackedStringArray())
	)
	if requested_ids.is_empty():
		return _copy_dictionary(topology_layers, copy_output)
	var filtered: Dictionary = {}
	for projection_id in requested_ids:
		var layer_id := String(projection_id)
		if topology_layers.has(layer_id):
			filtered[layer_id] = _copy_array(topology_layers[layer_id], copy_output)
	return filtered


static func _formation_product_set_from_world_chunk_or_layers(
	world_chunk: GeneratedWorldChunk,
	formation_layers: Dictionary,
	copy_output: bool = true
) -> Dictionary:
	if world_chunk != null and _is_formation_product_set(world_chunk.formation_products):
		return _copy_dictionary(world_chunk.formation_products, copy_output)
	if world_chunk != null and not world_chunk.formation_products.is_empty():
		var from_formation_products := formation_product_set_from_formation_layers(
			world_chunk.formation_products,
			world_chunk.bounds
		)
		if not from_formation_products.is_empty():
			return from_formation_products
	if not formation_layers.is_empty():
		return formation_product_set_from_formation_layers(
			formation_layers,
			world_chunk.bounds if world_chunk != null else {}
		)
	return {}


static func _formation_layers_from_product_set(
	formation_product_set: Dictionary,
	fallback_formation_layers: Dictionary,
	copy_output: bool = true
) -> Dictionary:
	if _is_formation_product_set(formation_product_set):
		var product_layers := _formation_layers_from_products(
			formation_product_set.get("products", {}),
			copy_output
		)
		if not product_layers.is_empty():
			return product_layers
		var formation_layers: Variant = formation_product_set.get("formation_layers", {})
		if typeof(formation_layers) == TYPE_DICTIONARY:
			return _copy_dictionary(formation_layers, copy_output)
	return _copy_dictionary(fallback_formation_layers, copy_output)


static func _formation_layers_from_products(
	products_data: Variant,
	copy_output: bool = true
) -> Dictionary:
	if typeof(products_data) != TYPE_DICTIONARY:
		return {}
	var products: Dictionary = products_data
	var formation_layers: Dictionary = {}
	var product_ids := products.keys()
	product_ids.sort()
	for product_id in product_ids:
		var product_data: Variant = products[product_id]
		if typeof(product_data) != TYPE_DICTIONARY:
			continue
		var product: Dictionary = product_data
		var layer_id := String(product.get("layer_id", "")).strip_edges()
		if layer_id.is_empty():
			continue
		var formation_grid: Array = product.get("formation_grid", [])
		var source_chunk_coords: Array = product.get("source_chunk_coords", [])
		formation_layers[layer_id] = {
			"layer_id": layer_id,
			"formation_grid": _copy_array(formation_grid, copy_output),
			"formation_origin_cell": product.get("formation_origin_cell", Vector2i(-1, -1)),
			"owned_visual_origin": product.get("owned_visual_origin", Vector2i.ZERO),
			"owned_visual_size": product.get("owned_visual_size", _grid_dimension_vec(formation_grid)),
			"formation_mode": product.get("formation_mode", "owned_halo"),
			"source_chunk_coords": _copy_array(source_chunk_coords, copy_output),
		}
	return formation_layers


static func _is_formation_product_set(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var dictionary_value: Dictionary = value
	return dictionary_value.get("product_type", "") == FormationProductSetScript.PRODUCT_TYPE


static func _terrain_cells_from_world_layers(
	world_layers: Dictionary,
	copy_output: bool = true
) -> Array:
	var layer_set_terrain_cells := _terrain_cells_from_layer_set(
		world_layers.get(SEMANTIC_WORLD_LAYER_SET_KEY, {}),
		NATIVE_TERRAIN_LAYER_KEY,
		copy_output
	)
	if not layer_set_terrain_cells.is_empty():
		return layer_set_terrain_cells
	var legacy_layer_set_terrain_cells := _terrain_cells_from_layer_set(
		world_layers.get(SEMANTIC_WORLD_LAYER_SET_KEY, {}),
		LEGACY_TERRAIN_LAYER_KEY,
		copy_output
	)
	if not legacy_layer_set_terrain_cells.is_empty():
		return legacy_layer_set_terrain_cells

	var native_terrain_cells: Variant = world_layers.get(NATIVE_TERRAIN_LAYER_KEY, [])
	if typeof(native_terrain_cells) == TYPE_ARRAY:
		var native_terrain_array: Array = native_terrain_cells
		if not native_terrain_array.is_empty():
			return _copy_array(native_terrain_array, copy_output)

	var semantic_native_terrain_cells := _terrain_cells_from_semantic_layer(
		world_layers.get(SEMANTIC_NATIVE_TERRAIN_LAYER_KEY, {}),
		copy_output
	)
	if not semantic_native_terrain_cells.is_empty():
		return semantic_native_terrain_cells

	var semantic_terrain_cells := _terrain_cells_from_semantic_layer(
		world_layers.get(SEMANTIC_LEGACY_TERRAIN_LAYER_KEY, {}),
		copy_output
	)
	if not semantic_terrain_cells.is_empty():
		return semantic_terrain_cells

	var legacy_terrain_cells: Variant = world_layers.get(LEGACY_TERRAIN_LAYER_KEY, [])
	if typeof(legacy_terrain_cells) == TYPE_ARRAY:
		var legacy_terrain_array: Array = legacy_terrain_cells
		return _copy_array(legacy_terrain_array, copy_output)
	return []


static func _terrain_cells_from_layer_set(
	layer_set_data: Variant,
	layer_id: String,
	copy_output: bool = true
) -> Array:
	if typeof(layer_set_data) != TYPE_DICTIONARY:
		return []

	var layer_set_dictionary: Dictionary = layer_set_data
	var layers: Variant = layer_set_dictionary.get("layers", {})
	if typeof(layers) != TYPE_DICTIONARY:
		return []

	var layers_dictionary: Dictionary = layers
	return _terrain_cells_from_semantic_layer(layers_dictionary.get(layer_id, {}), copy_output)


static func _terrain_cells_from_semantic_layer(
	layer_data: Variant,
	copy_output: bool = true
) -> Array:
	if typeof(layer_data) != TYPE_DICTIONARY:
		return []

	var layer_dictionary: Dictionary = layer_data
	var cells: Variant = layer_dictionary.get("cells", [])
	if typeof(cells) != TYPE_ARRAY:
		return []
	var cell_array: Array = cells
	return _copy_array(cell_array, copy_output)


static func _grid_dimension_vec(grid: Array) -> Vector2i:
	var height := grid.size()
	var width := 0
	for row in grid:
		width = maxi(width, int(row.size()))
	return Vector2i(width, height)


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	var result := PackedStringArray()
	if typeof(value) != TYPE_ARRAY:
		return result
	var array_value: Array = value
	for item in array_value:
		result.append(String(item))
	return result


static func _copy_dictionary(value: Dictionary, copy_output: bool) -> Dictionary:
	return value.duplicate(true) if copy_output else value


static func _copy_array(value: Array, copy_output: bool) -> Array:
	return value.duplicate(true) if copy_output else value
