extends RefCounted

class_name FormationProduct

const PRODUCT_TYPE := "FormationProduct"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/formation/formation_product.gd"
const SOURCE_LEGACY_FORMATION_LAYER := "legacy_formation_layer"
const DEFAULT_CONSUMER_TARGET := "legacy_generated_chunk_data"
const DEFAULT_FORMATION_MODE := "owned_halo"

var product_id: String = ""
var layer_id: String = ""
var consumer_target: String = DEFAULT_CONSUMER_TARGET
var bounds: Dictionary = {}
var formation_grid: Array = []
var formation_origin_cell: Vector2i = Vector2i(-1, -1)
var owned_visual_origin: Vector2i = Vector2i.ZERO
var owned_visual_size: Vector2i = Vector2i.ZERO
var formation_mode: String = DEFAULT_FORMATION_MODE
var source_chunk_coords: Array = []
var metadata: Dictionary = {}


static func from_parts(
	p_product_id: String,
	p_layer_id: String,
	p_formation_grid: Array,
	p_formation_origin_cell: Vector2i,
	p_owned_visual_origin: Vector2i,
	p_owned_visual_size: Vector2i,
	p_formation_mode: String = DEFAULT_FORMATION_MODE,
	p_source_chunk_coords: Array = [],
	p_bounds: Dictionary = {},
	p_consumer_target: String = DEFAULT_CONSUMER_TARGET,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var product: RefCounted = load(SELF_SCRIPT_PATH).new()
	return product.configure(
		p_product_id,
		p_layer_id,
		p_formation_grid,
		p_formation_origin_cell,
		p_owned_visual_origin,
		p_owned_visual_size,
		p_formation_mode,
		p_source_chunk_coords,
		p_bounds,
		p_consumer_target,
		p_metadata
	)


static func from_legacy_formation_layer(
	p_layer_id: String,
	formation_data: Dictionary,
	p_bounds: Dictionary = {},
	p_consumer_target: String = DEFAULT_CONSUMER_TARGET,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var normalized_layer_id := p_layer_id.strip_edges()
	var next_metadata := {
		"source": SOURCE_LEGACY_FORMATION_LAYER,
		"source_key": "formation_layers.%s" % normalized_layer_id,
	}
	for key in p_metadata.keys():
		next_metadata[key] = p_metadata[key]
	return load(SELF_SCRIPT_PATH).from_parts(
		"%s_formation" % normalized_layer_id,
		normalized_layer_id,
		formation_data.get("formation_grid", []),
		formation_data.get("formation_origin_cell", Vector2i(-1, -1)),
		formation_data.get("owned_visual_origin", Vector2i.ZERO),
		formation_data.get("owned_visual_size", _grid_dimension_vec(formation_data.get("formation_grid", []))),
		formation_data.get("formation_mode", DEFAULT_FORMATION_MODE),
		formation_data.get("source_chunk_coords", []),
		p_bounds,
		p_consumer_target,
		next_metadata
	)


func configure(
	p_product_id: String,
	p_layer_id: String,
	p_formation_grid: Array,
	p_formation_origin_cell: Vector2i,
	p_owned_visual_origin: Vector2i,
	p_owned_visual_size: Vector2i,
	p_formation_mode: String = DEFAULT_FORMATION_MODE,
	p_source_chunk_coords: Array = [],
	p_bounds: Dictionary = {},
	p_consumer_target: String = DEFAULT_CONSUMER_TARGET,
	p_metadata: Dictionary = {}
) -> RefCounted:
	product_id = p_product_id.strip_edges()
	layer_id = p_layer_id.strip_edges()
	formation_grid = p_formation_grid.duplicate(true)
	formation_origin_cell = p_formation_origin_cell
	owned_visual_origin = p_owned_visual_origin
	owned_visual_size = p_owned_visual_size
	formation_mode = p_formation_mode.strip_edges()
	source_chunk_coords = p_source_chunk_coords.duplicate(true)
	bounds = p_bounds.duplicate(true)
	consumer_target = p_consumer_target.strip_edges()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_product() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		product_id,
		layer_id,
		formation_grid,
		formation_origin_cell,
		owned_visual_origin,
		owned_visual_size,
		formation_mode,
		source_chunk_coords,
		bounds,
		consumer_target,
		metadata
	)


func to_legacy_formation_layer() -> Dictionary:
	return {
		"layer_id": layer_id,
		"formation_grid": formation_grid.duplicate(true),
		"formation_origin_cell": formation_origin_cell,
		"owned_visual_origin": owned_visual_origin,
		"owned_visual_size": owned_visual_size,
		"formation_mode": formation_mode,
		"source_chunk_coords": source_chunk_coords.duplicate(true),
	}


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("FormationProduct:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not product_id.is_empty() \
		and not layer_id.is_empty() \
		and not consumer_target.is_empty() \
		and not formation_mode.is_empty() \
		and _is_grid(formation_grid) \
		and not _contains_runtime_object(bounds) \
		and not _contains_runtime_object(formation_grid) \
		and not _contains_runtime_object(source_chunk_coords) \
		and not _contains_runtime_object(metadata)


func dimensions() -> Vector2i:
	return _grid_dimension_vec(formation_grid)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"product_id": product_id,
		"layer_id": layer_id,
		"consumer_target": consumer_target,
		"bounds": bounds.duplicate(true),
		"formation_grid": formation_grid.duplicate(true),
		"formation_origin_cell": formation_origin_cell,
		"owned_visual_origin": owned_visual_origin,
		"owned_visual_size": owned_visual_size,
		"formation_mode": formation_mode,
		"source_chunk_coords": source_chunk_coords.duplicate(true),
		"metadata": metadata.duplicate(true),
		"dimensions": dimensions(),
	}


static func _grid_dimension_vec(grid: Array) -> Vector2i:
	var height := grid.size()
	var width := 0
	for row in grid:
		if typeof(row) == TYPE_ARRAY:
			width = maxi(width, row.size())
	return Vector2i(width, height)


static func _is_grid(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var rows: Array = value
	for row in rows:
		if typeof(row) != TYPE_ARRAY:
			return false
	return true


static func _contains_runtime_object(value: Variant) -> bool:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			for dictionary_key in dictionary_value.keys():
				if _contains_runtime_object(dictionary_key) or _contains_runtime_object(dictionary_value[dictionary_key]):
					return true
			return false
		TYPE_ARRAY:
			var array_value: Array = value
			for item in array_value:
				if _contains_runtime_object(item):
					return true
			return false
		TYPE_OBJECT:
			return value != null
		_:
			return false
