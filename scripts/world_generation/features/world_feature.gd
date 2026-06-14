extends RefCounted

class_name WorldFeature

const PRODUCT_TYPE := "WorldFeature"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/features/world_feature.gd"
const SOURCE_LEGACY_DEBUG_MARKER := "legacy_debug_marker"
const SOURCE_LEGACY_STAGE := "legacy_chunk_generation_stage"

var feature_id: String = ""
var feature_kind: String = ""
var bounds: Dictionary = {}
var influence: float = 1.0
var priority: int = 0
var source_stage: String = ""
var constraints: Dictionary = {}
var tags: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func from_parts(
	p_feature_id: String,
	p_feature_kind: String,
	p_bounds: Dictionary = {},
	p_influence: float = 1.0,
	p_priority: int = 0,
	p_source_stage: String = "",
	p_constraints: Dictionary = {},
	p_tags: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	var feature: RefCounted = load(SELF_SCRIPT_PATH).new()
	return feature.configure(
		p_feature_id,
		p_feature_kind,
		p_bounds,
		p_influence,
		p_priority,
		p_source_stage,
		p_constraints,
		p_tags,
		p_metadata
	)


static func from_legacy_debug_marker(
	marker_index: int,
	marker: Dictionary,
	p_bounds: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var marker_kind := String(marker.get("type", SOURCE_LEGACY_DEBUG_MARKER)).strip_edges()
	if marker_kind.is_empty():
		marker_kind = SOURCE_LEGACY_DEBUG_MARKER
	var next_metadata := {
		"source": SOURCE_LEGACY_DEBUG_MARKER,
		"source_key": "debug_markers.%s" % marker_index,
		"marker_index": marker_index,
		"legacy_debug_marker": marker.duplicate(true),
	}
	for key in p_metadata.keys():
		next_metadata[key] = p_metadata[key]
	return load(SELF_SCRIPT_PATH).from_parts(
		"legacy_debug_marker_%s" % _padded_index(marker_index),
		marker_kind,
		_bounds_from_legacy_debug_marker(marker, p_bounds),
		1.0,
		0,
		SOURCE_LEGACY_STAGE,
		{},
		PackedStringArray([SOURCE_LEGACY_DEBUG_MARKER, marker_kind]),
		next_metadata
	)


func configure(
	p_feature_id: String,
	p_feature_kind: String,
	p_bounds: Dictionary = {},
	p_influence: float = 1.0,
	p_priority: int = 0,
	p_source_stage: String = "",
	p_constraints: Dictionary = {},
	p_tags: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	feature_id = p_feature_id.strip_edges()
	feature_kind = p_feature_kind.strip_edges()
	bounds = p_bounds.duplicate(true)
	influence = p_influence
	priority = p_priority
	source_stage = p_source_stage.strip_edges()
	constraints = p_constraints.duplicate(true)
	tags = p_tags.duplicate()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_feature() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		feature_id,
		feature_kind,
		bounds,
		influence,
		priority,
		source_stage,
		constraints,
		tags,
		metadata
	)


func to_legacy_debug_marker() -> Dictionary:
	var marker: Variant = metadata.get("legacy_debug_marker", {})
	if typeof(marker) == TYPE_DICTIONARY:
		return marker.duplicate(true)
	return {}


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldFeature:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not feature_id.is_empty() \
		and not feature_kind.is_empty() \
		and not source_stage.is_empty() \
		and not _contains_runtime_object(bounds) \
		and not _contains_runtime_object(constraints) \
		and not _contains_runtime_object(metadata)


func has_tag(tag: String) -> bool:
	return tags.has(tag.strip_edges())


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"feature_id": feature_id,
		"feature_kind": feature_kind,
		"bounds": bounds.duplicate(true),
		"influence": influence,
		"priority": priority,
		"source_stage": source_stage,
		"constraints": constraints.duplicate(true),
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _bounds_from_legacy_debug_marker(marker: Dictionary, fallback_bounds: Dictionary) -> Dictionary:
	var next_bounds := {
		"chunk_coord": fallback_bounds.get("chunk_coord", Vector3i.ZERO),
		"domain_descriptor": fallback_bounds.get("domain_descriptor", WorldSpace.DOMAIN_CELL_GRID_2D),
	}
	if marker.has("rect_position") and marker.has("rect_size"):
		next_bounds["cell_bounds"] = Rect2i(marker["rect_position"], marker["rect_size"])
	if marker.has("center"):
		next_bounds["center_cell"] = marker["center"]
	if marker.has("from"):
		next_bounds["from_cell"] = marker["from"]
	if marker.has("to"):
		next_bounds["to_cell"] = marker["to"]
	if not next_bounds.has("cell_bounds") and fallback_bounds.has("owned_cell_bounds"):
		next_bounds["cell_bounds"] = fallback_bounds["owned_cell_bounds"]
	return next_bounds


static func _padded_index(value: int) -> String:
	var text := str(maxi(value, 0))
	while text.length() < 4:
		text = "0%s" % text
	return text


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
		TYPE_PACKED_STRING_ARRAY:
			return false
		TYPE_OBJECT:
			return value != null
		_:
			return false
