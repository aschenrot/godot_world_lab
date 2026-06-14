extends RefCounted

class_name TopologyProjectionSet

const PRODUCT_TYPE := "TopologyProjectionSet"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/topology/topology_projection_set.gd"
const TopologyProjectionScript := preload("res://scripts/world_generation/topology/topology_projection.gd")

const INVALID_DUPLICATE_PROJECTION_IDS_KEY := "invalid_duplicate_projection_ids"
const INVALID_PROJECTION_IDS_KEY := "invalid_projection_ids"

var projections_by_id: Dictionary = {}
var metadata: Dictionary = {}


static func from_parts(
	p_projections_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var projection_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	return projection_set.configure(p_projections_by_id, p_metadata)


static func from_legacy_topology_layers(
	topology_layers: Dictionary,
	bounds: Dictionary,
	domain_descriptor: String
) -> RefCounted:
	var projection_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	for projection_id in _ordered_projection_ids(topology_layers):
		projection_set.add_projection(TopologyProjectionScript.from_legacy_topology_layer(
			projection_id,
			topology_layers[projection_id],
			bounds,
			domain_descriptor
		))
	return projection_set


func configure(
	p_projections_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	projections_by_id = {}
	metadata = p_metadata.duplicate(true)
	for projection_key in p_projections_by_id.keys():
		var projection: Variant = p_projections_by_id[projection_key]
		if _is_topology_projection(projection):
			add_projection(projection, true)
	return self


func add_projection(projection: RefCounted, overwrite_existing: bool = false) -> void:
	if projection == null:
		_record_invalid_projection_id("")
		return
	var normalized_projection_id: String = projection.projection_id.strip_edges()
	if normalized_projection_id.is_empty() or not projection.is_valid():
		_record_invalid_projection_id(normalized_projection_id)
		return
	if projections_by_id.has(normalized_projection_id) and not overwrite_existing:
		_record_duplicate_projection_id(normalized_projection_id)
		return
	projections_by_id[normalized_projection_id] = projection.duplicate_projection()


func has_projection(projection_id: String) -> bool:
	return projections_by_id.has(projection_id.strip_edges())


func get_projection(projection_id: String) -> RefCounted:
	var normalized_projection_id := projection_id.strip_edges()
	if not projections_by_id.has(normalized_projection_id):
		return null
	return projections_by_id[normalized_projection_id].duplicate_projection()


func projection_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for projection_id in projections_by_id.keys():
		ids.append(String(projection_id))
	ids.sort()
	return ids


func duplicate_set() -> RefCounted:
	var copy: RefCounted = load(SELF_SCRIPT_PATH).new()
	copy.metadata = metadata.duplicate(true)
	for projection_id in projection_ids():
		copy.projections_by_id[projection_id] = projections_by_id[projection_id].duplicate_projection()
	return copy


func to_legacy_topology_layers() -> Dictionary:
	var topology_layers: Dictionary = {}
	for projection_id in projection_ids():
		var projection: RefCounted = projections_by_id[projection_id]
		topology_layers[projection_id] = projection.grid.duplicate(true)
	return topology_layers


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("TopologyProjectionSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	if _metadata_array(INVALID_DUPLICATE_PROJECTION_IDS_KEY).size() > 0:
		return false
	if _metadata_array(INVALID_PROJECTION_IDS_KEY).size() > 0:
		return false
	if _contains_runtime_object(metadata):
		return false
	for projection_id in projection_ids():
		var projection: RefCounted = projections_by_id[projection_id]
		if projection == null or not projection.is_valid():
			return false
	return true


func _payload_dictionary() -> Dictionary:
	var projections: Dictionary = {}
	for projection_id in projection_ids():
		var projection: RefCounted = projections_by_id[projection_id]
		projections[projection_id] = projection.to_dictionary() if projection != null else {}
	return {
		"product_type": PRODUCT_TYPE,
		"projection_ids": projection_ids(),
		"projections": projections,
		"topology_layers": to_legacy_topology_layers(),
		"metadata": metadata.duplicate(true),
	}


func _record_duplicate_projection_id(projection_id: String) -> void:
	var duplicate_ids := _metadata_array(INVALID_DUPLICATE_PROJECTION_IDS_KEY)
	duplicate_ids.append(projection_id)
	metadata[INVALID_DUPLICATE_PROJECTION_IDS_KEY] = duplicate_ids


func _record_invalid_projection_id(projection_id: String) -> void:
	var invalid_ids := _metadata_array(INVALID_PROJECTION_IDS_KEY)
	invalid_ids.append(projection_id)
	metadata[INVALID_PROJECTION_IDS_KEY] = invalid_ids


func _metadata_array(key: String) -> Array:
	var value: Variant = metadata.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	return []


func _is_topology_projection(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT \
		and value != null \
		and value.has_method("duplicate_projection") \
		and value.has_method("is_valid") \
		and value.has_method("to_dictionary")


static func _ordered_projection_ids(topology_layers: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for projection_id in topology_layers.keys():
		ids.append(String(projection_id))
	ids.sort()
	return ids


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
