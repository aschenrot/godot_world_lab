extends RefCounted

class_name WorldLayerSchema

const PRODUCT_TYPE := "WorldLayerSchema"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/layers/world_layer_schema.gd"

const KIND_TERRAIN_CELL_GRID := "terrain_cell_grid"
const KIND_TOPOLOGY_SOURCE_GRID := "topology_source_grid"
const VALUE_KIND_DICTIONARY_CELL := "dictionary_cell"
const VALUE_KIND_INT_CELL := "int_cell"
const SOURCE_LEGACY_PROVIDER := "legacy_provider"

var schema_id: String = ""
var layer_kind: String = ""
var domain_descriptor: String = WorldSpace.DOMAIN_CELL_GRID_2D
var value_kind: String = ""
var source_kind: String = ""
var metadata: Dictionary = {}


static func from_parts(
	p_schema_id: String,
	p_layer_kind: String,
	p_domain_descriptor: String,
	p_value_kind: String,
	p_source_kind: String = "",
	p_metadata: Dictionary = {}
) -> RefCounted:
	var schema: RefCounted = load(SELF_SCRIPT_PATH).new()
	return schema.configure(
		p_schema_id,
		p_layer_kind,
		p_domain_descriptor,
		p_value_kind,
		p_source_kind,
		p_metadata
	)


func configure(
	p_schema_id: String,
	p_layer_kind: String,
	p_domain_descriptor: String,
	p_value_kind: String,
	p_source_kind: String = "",
	p_metadata: Dictionary = {}
) -> RefCounted:
	schema_id = p_schema_id.strip_edges()
	layer_kind = p_layer_kind.strip_edges()
	domain_descriptor = p_domain_descriptor.strip_edges()
	value_kind = p_value_kind.strip_edges()
	source_kind = p_source_kind.strip_edges()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_schema() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		schema_id,
		layer_kind,
		domain_descriptor,
		value_kind,
		source_kind,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldLayerSchema:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not schema_id.is_empty() \
		and not layer_kind.is_empty() \
		and not value_kind.is_empty() \
		and WorldSpace.is_supported_domain_descriptor(domain_descriptor) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"schema_id": schema_id,
		"layer_kind": layer_kind,
		"domain_descriptor": domain_descriptor,
		"value_kind": value_kind,
		"source_kind": source_kind,
		"metadata": metadata.duplicate(true),
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
