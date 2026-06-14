extends RefCounted

class_name WorldFeatureSet

const PRODUCT_TYPE := "WorldFeatureSet"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/features/world_feature_set.gd"
const WorldFeatureScript := preload("res://scripts/world_generation/features/world_feature.gd")

const INVALID_DUPLICATE_FEATURE_IDS_KEY := "invalid_duplicate_feature_ids"
const INVALID_FEATURE_IDS_KEY := "invalid_feature_ids"

var features_by_id: Dictionary = {}
var metadata: Dictionary = {}


static func from_parts(
	p_features_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var feature_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	return feature_set.configure(p_features_by_id, p_metadata)


static func from_legacy_debug_markers(
	debug_markers: Array,
	bounds: Dictionary = {}
) -> RefCounted:
	var feature_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	for marker_index in range(debug_markers.size()):
		var marker: Variant = debug_markers[marker_index]
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		feature_set.add_feature(WorldFeatureScript.from_legacy_debug_marker(
			marker_index,
			marker,
			bounds
		))
	return feature_set


func configure(
	p_features_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	features_by_id = {}
	metadata = p_metadata.duplicate(true)
	for feature_key in p_features_by_id.keys():
		var feature: Variant = p_features_by_id[feature_key]
		if _is_world_feature(feature):
			add_feature(feature, true)
	return self


func add_feature(feature: RefCounted, overwrite_existing: bool = false) -> void:
	if feature == null:
		_record_invalid_feature_id("")
		return
	var normalized_feature_id: String = feature.feature_id.strip_edges()
	if normalized_feature_id.is_empty() or not feature.is_valid():
		_record_invalid_feature_id(normalized_feature_id)
		return
	if features_by_id.has(normalized_feature_id) and not overwrite_existing:
		_record_duplicate_feature_id(normalized_feature_id)
		return
	features_by_id[normalized_feature_id] = feature.duplicate_feature()


func has_feature(feature_id: String) -> bool:
	return features_by_id.has(feature_id.strip_edges())


func get_feature(feature_id: String) -> RefCounted:
	var normalized_feature_id := feature_id.strip_edges()
	if not features_by_id.has(normalized_feature_id):
		return null
	return features_by_id[normalized_feature_id].duplicate_feature()


func feature_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for feature_id in features_by_id.keys():
		ids.append(String(feature_id))
	ids.sort()
	return ids


func features_by_kind(feature_kind: String) -> Array:
	var matches: Array = []
	var normalized_kind := feature_kind.strip_edges()
	for feature_id in feature_ids():
		var feature: RefCounted = features_by_id[feature_id]
		if feature.feature_kind == normalized_kind:
			matches.append(feature.duplicate_feature())
	return matches


func features_with_tag(tag: String) -> Array:
	var matches: Array = []
	for feature_id in feature_ids():
		var feature: RefCounted = features_by_id[feature_id]
		if feature.has_tag(tag):
			matches.append(feature.duplicate_feature())
	return matches


func feature_counts_by_kind() -> Dictionary:
	var counts: Dictionary = {}
	for feature_id in feature_ids():
		var feature: RefCounted = features_by_id[feature_id]
		counts[feature.feature_kind] = int(counts.get(feature.feature_kind, 0)) + 1
	return counts


func duplicate_set() -> RefCounted:
	var copy: RefCounted = load(SELF_SCRIPT_PATH).new()
	copy.metadata = metadata.duplicate(true)
	for feature_id in feature_ids():
		copy.features_by_id[feature_id] = features_by_id[feature_id].duplicate_feature()
	return copy


func to_legacy_debug_markers() -> Array:
	var debug_markers: Array = []
	for feature_id in feature_ids():
		var feature: RefCounted = features_by_id[feature_id]
		var marker: Dictionary = feature.to_legacy_debug_marker()
		if not marker.is_empty():
			debug_markers.append(marker)
	return debug_markers


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldFeatureSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	if _metadata_array(INVALID_DUPLICATE_FEATURE_IDS_KEY).size() > 0:
		return false
	if _metadata_array(INVALID_FEATURE_IDS_KEY).size() > 0:
		return false
	if _contains_runtime_object(metadata):
		return false
	for feature_id in feature_ids():
		var feature: RefCounted = features_by_id[feature_id]
		if feature == null or not feature.is_valid():
			return false
	return true


func _payload_dictionary() -> Dictionary:
	var features: Dictionary = {}
	for feature_id in feature_ids():
		var feature: RefCounted = features_by_id[feature_id]
		features[feature_id] = feature.to_dictionary() if feature != null else {}
	return {
		"product_type": PRODUCT_TYPE,
		"feature_ids": feature_ids(),
		"features": features,
		"legacy_debug_markers": to_legacy_debug_markers(),
		"metadata": metadata.duplicate(true),
		"feature_count": feature_ids().size(),
		"feature_counts_by_kind": feature_counts_by_kind(),
	}


func _record_duplicate_feature_id(feature_id: String) -> void:
	var duplicate_ids := _metadata_array(INVALID_DUPLICATE_FEATURE_IDS_KEY)
	duplicate_ids.append(feature_id)
	metadata[INVALID_DUPLICATE_FEATURE_IDS_KEY] = duplicate_ids


func _record_invalid_feature_id(feature_id: String) -> void:
	var invalid_ids := _metadata_array(INVALID_FEATURE_IDS_KEY)
	invalid_ids.append(feature_id)
	metadata[INVALID_FEATURE_IDS_KEY] = invalid_ids


func _metadata_array(key: String) -> Array:
	var value: Variant = metadata.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	return []


func _is_world_feature(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT \
		and value != null \
		and value.has_method("duplicate_feature") \
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
