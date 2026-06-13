extends RefCounted

class_name WorldLayer

const PRODUCT_TYPE := "WorldLayer"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/layers/world_layer.gd"
const WorldLayerSchemaScript := preload("res://scripts/world_generation/layers/world_layer_schema.gd")

var layer_id: String = ""
var schema: RefCounted = null
var bounds: Dictionary = {}
var cells: Array = []
var metadata: Dictionary = {}


static func from_parts(
	p_layer_id: String,
	p_schema: RefCounted,
	p_bounds: Dictionary,
	p_cells: Array,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var layer: RefCounted = load(SELF_SCRIPT_PATH).new()
	return layer.configure(p_layer_id, p_schema, p_bounds, p_cells, p_metadata)


static func from_legacy_terrain_cells(
	p_layer_id: String,
	terrain_cells: Array,
	p_bounds: Dictionary,
	p_domain_descriptor: String,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var normalized_layer_id := p_layer_id.strip_edges()
	if normalized_layer_id.is_empty():
		normalized_layer_id = "legacy_terrain_cells"
	var next_schema := WorldLayerSchemaScript.from_parts(
		"%s_schema" % normalized_layer_id,
		WorldLayerSchemaScript.KIND_TERRAIN_CELL_GRID,
		p_domain_descriptor,
		WorldLayerSchemaScript.VALUE_KIND_DICTIONARY_CELL,
		WorldLayerSchemaScript.SOURCE_LEGACY_PROVIDER
	)
	return load(SELF_SCRIPT_PATH).from_parts(
		normalized_layer_id,
		next_schema,
		p_bounds,
		terrain_cells,
		p_metadata
	)


func configure(
	p_layer_id: String,
	p_schema: RefCounted,
	p_bounds: Dictionary,
	p_cells: Array,
	p_metadata: Dictionary = {}
) -> RefCounted:
	layer_id = p_layer_id.strip_edges()
	schema = p_schema.duplicate_schema() if p_schema != null else null
	bounds = p_bounds.duplicate(true)
	cells = p_cells.duplicate(true)
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_layer() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(layer_id, schema, bounds, cells, metadata)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldLayer:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not layer_id.is_empty() \
		and schema != null \
		and schema.is_valid() \
		and not _contains_runtime_object(bounds) \
		and not _contains_runtime_object(cells) \
		and not _contains_runtime_object(metadata)


func dimensions() -> Vector2i:
	var height := cells.size()
	var width := 0
	for row in cells:
		if typeof(row) == TYPE_ARRAY:
			width = maxi(width, row.size())
	return Vector2i(width, height)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"layer_id": layer_id,
		"schema": schema.to_dictionary() if schema != null else {},
		"bounds": bounds.duplicate(true),
		"cells": cells.duplicate(true),
		"metadata": metadata.duplicate(true),
		"dimensions": dimensions(),
	}


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
