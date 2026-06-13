extends RefCounted

class_name WorldLayerSet

const SELF_SCRIPT_PATH := "res://scripts/world_generation/layers/world_layer_set.gd"
const WorldLayerScript := preload("res://scripts/world_generation/layers/world_layer.gd")

const PRODUCT_TYPE := "WorldLayerSet"
const LEGACY_TERRAIN_LAYER_ID := "legacy_terrain_cells"
const INVALID_DUPLICATE_LAYER_IDS_KEY := "invalid_duplicate_layer_ids"
const INVALID_LAYER_IDS_KEY := "invalid_layer_ids"

var layers_by_id: Dictionary = {}
var metadata: Dictionary = {}


static func from_parts(
	p_layers_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var layer_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	return layer_set.configure(p_layers_by_id, p_metadata)


static func from_legacy_generation_result(
	generation_result: Dictionary,
	bounds: Dictionary,
	domain_descriptor: String
) -> RefCounted:
	var layer_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	var terrain_cells: Array = generation_result.get("terrain_cells", [])
	layer_set.add_layer(WorldLayerScript.from_legacy_terrain_cells(
		LEGACY_TERRAIN_LAYER_ID,
		terrain_cells,
		bounds,
		domain_descriptor,
		{"source_key": "terrain_cells"}
	))
	return layer_set


func configure(
	p_layers_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	layers_by_id = {}
	metadata = p_metadata.duplicate(true)
	for layer_key in p_layers_by_id.keys():
		var layer: Variant = p_layers_by_id[layer_key]
		if _is_world_layer(layer):
			add_layer(layer, true)
	return self


func add_layer(layer: RefCounted, overwrite_existing: bool = false) -> void:
	if layer == null:
		_record_invalid_layer_id("")
		return
	var normalized_layer_id: String = layer.layer_id.strip_edges()
	if normalized_layer_id.is_empty() or not layer.is_valid():
		_record_invalid_layer_id(normalized_layer_id)
		return
	if layers_by_id.has(normalized_layer_id) and not overwrite_existing:
		_record_duplicate_layer_id(normalized_layer_id)
		return
	layers_by_id[normalized_layer_id] = layer.duplicate_layer()


func has_layer(layer_id: String) -> bool:
	return layers_by_id.has(layer_id.strip_edges())


func get_layer(layer_id: String) -> RefCounted:
	var normalized_layer_id := layer_id.strip_edges()
	if not layers_by_id.has(normalized_layer_id):
		return null
	return layers_by_id[normalized_layer_id].duplicate_layer()


func layer_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for layer_id in layers_by_id.keys():
		ids.append(String(layer_id))
	ids.sort()
	return ids


func duplicate_set() -> RefCounted:
	var copy: RefCounted = load(SELF_SCRIPT_PATH).new()
	copy.metadata = metadata.duplicate(true)
	for layer_id in layer_ids():
		copy.layers_by_id[layer_id] = layers_by_id[layer_id].duplicate_layer()
	return copy


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldLayerSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	if _metadata_array(INVALID_DUPLICATE_LAYER_IDS_KEY).size() > 0:
		return false
	if _metadata_array(INVALID_LAYER_IDS_KEY).size() > 0:
		return false
	if _contains_runtime_object(metadata):
		return false
	for layer_id in layer_ids():
		var layer: RefCounted = layers_by_id[layer_id]
		if layer == null or not layer.is_valid():
			return false
	return true


func _payload_dictionary() -> Dictionary:
	var layers: Dictionary = {}
	for layer_id in layer_ids():
		var layer: RefCounted = layers_by_id[layer_id]
		layers[layer_id] = layer.to_dictionary() if layer != null else {}
	return {
		"product_type": PRODUCT_TYPE,
		"layer_ids": layer_ids(),
		"layers": layers,
		"metadata": metadata.duplicate(true),
	}


func _record_duplicate_layer_id(layer_id: String) -> void:
	var duplicate_ids := _metadata_array(INVALID_DUPLICATE_LAYER_IDS_KEY)
	duplicate_ids.append(layer_id)
	metadata[INVALID_DUPLICATE_LAYER_IDS_KEY] = duplicate_ids


func _record_invalid_layer_id(layer_id: String) -> void:
	var invalid_ids := _metadata_array(INVALID_LAYER_IDS_KEY)
	invalid_ids.append(layer_id)
	metadata[INVALID_LAYER_IDS_KEY] = invalid_ids


func _metadata_array(key: String) -> Array:
	var value: Variant = metadata.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	return []


func _is_world_layer(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT \
		and value != null \
		and value.has_method("duplicate_layer") \
		and value.has_method("is_valid") \
		and value.has_method("to_dictionary")


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
