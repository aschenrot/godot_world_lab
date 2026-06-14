extends RefCounted

class_name TopologyProjection

const PRODUCT_TYPE := "TopologyProjection"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/topology/topology_projection.gd"
const VALUE_KIND_BINARY_GRID := "binary_grid"
const SOURCE_LEGACY_TOPOLOGY_LAYERS := "legacy_topology_layers"

var projection_id: String = ""
var domain_descriptor: String = ""
var value_kind: String = VALUE_KIND_BINARY_GRID
var bounds: Dictionary = {}
var grid: Array = []
var metadata: Dictionary = {}


static func from_parts(
	p_projection_id: String,
	p_grid: Array,
	p_bounds: Dictionary,
	p_domain_descriptor: String,
	p_value_kind: String = VALUE_KIND_BINARY_GRID,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var projection: RefCounted = load(SELF_SCRIPT_PATH).new()
	return projection.configure(
		p_projection_id,
		p_grid,
		p_bounds,
		p_domain_descriptor,
		p_value_kind,
		p_metadata
	)


static func from_legacy_topology_layer(
	p_projection_id: String,
	layer_grid: Array,
	p_bounds: Dictionary,
	p_domain_descriptor: String,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var normalized_projection_id := p_projection_id.strip_edges()
	var next_metadata := {
		"source": SOURCE_LEGACY_TOPOLOGY_LAYERS,
		"source_key": "topology_layers.%s" % normalized_projection_id,
	}
	for key in p_metadata.keys():
		next_metadata[key] = p_metadata[key]
	return load(SELF_SCRIPT_PATH).from_parts(
		normalized_projection_id,
		layer_grid,
		p_bounds,
		p_domain_descriptor,
		VALUE_KIND_BINARY_GRID,
		next_metadata
	)


func configure(
	p_projection_id: String,
	p_grid: Array,
	p_bounds: Dictionary,
	p_domain_descriptor: String,
	p_value_kind: String = VALUE_KIND_BINARY_GRID,
	p_metadata: Dictionary = {}
) -> RefCounted:
	projection_id = p_projection_id.strip_edges()
	grid = p_grid.duplicate(true)
	bounds = p_bounds.duplicate(true)
	domain_descriptor = p_domain_descriptor.strip_edges()
	value_kind = p_value_kind.strip_edges()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_projection() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		projection_id,
		grid,
		bounds,
		domain_descriptor,
		value_kind,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("TopologyProjection:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not projection_id.is_empty() \
		and not domain_descriptor.is_empty() \
		and value_kind == VALUE_KIND_BINARY_GRID \
		and _is_grid(grid) \
		and not _contains_runtime_object(bounds) \
		and not _contains_runtime_object(grid) \
		and not _contains_runtime_object(metadata)


func dimensions() -> Vector2i:
	var height := grid.size()
	var width := 0
	for row in grid:
		if typeof(row) == TYPE_ARRAY:
			width = maxi(width, row.size())
	return Vector2i(width, height)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"projection_id": projection_id,
		"domain_descriptor": domain_descriptor,
		"value_kind": value_kind,
		"bounds": bounds.duplicate(true),
		"grid": grid.duplicate(true),
		"metadata": metadata.duplicate(true),
		"dimensions": dimensions(),
	}


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
