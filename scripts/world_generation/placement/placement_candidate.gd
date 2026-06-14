extends RefCounted

class_name PlacementCandidate

const PRODUCT_TYPE := "PlacementCandidate"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/placement/placement_candidate.gd"
const SOURCE_LEGACY_DEBUG_MARKER := "legacy_debug_marker"
const KIND_LEGACY_DEBUG_MARKER_OPPORTUNITY := "legacy_debug_marker_opportunity"

var candidate_id: String = ""
var candidate_kind: String = ""
var world_position_or_bounds: Variant = {}
var source_feature: String = ""
var score: float = 0.0
var constraints: Dictionary = {}
var tags: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func from_parts(
	p_candidate_id: String,
	p_candidate_kind: String,
	p_world_position_or_bounds: Variant = {},
	p_source_feature: String = "",
	p_score: float = 0.0,
	p_constraints: Dictionary = {},
	p_tags: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	var candidate: RefCounted = load(SELF_SCRIPT_PATH).new()
	return candidate.configure(
		p_candidate_id,
		p_candidate_kind,
		p_world_position_or_bounds,
		p_source_feature,
		p_score,
		p_constraints,
		p_tags,
		p_metadata
	)


static func from_legacy_debug_marker(
	marker_index: int,
	marker: Dictionary,
	p_bounds: Dictionary = {}
) -> RefCounted:
	var marker_kind := String(marker.get("type", SOURCE_LEGACY_DEBUG_MARKER)).strip_edges()
	if marker_kind.is_empty():
		marker_kind = SOURCE_LEGACY_DEBUG_MARKER
	return load(SELF_SCRIPT_PATH).from_parts(
		"legacy_debug_marker_candidate_%s" % _padded_index(marker_index),
		KIND_LEGACY_DEBUG_MARKER_OPPORTUNITY,
		_position_or_bounds_from_marker(marker, p_bounds),
		"legacy_debug_marker_%s" % _padded_index(marker_index),
		1.0,
		{"generation_only": true, "gameplay_decides_result": true},
		PackedStringArray([SOURCE_LEGACY_DEBUG_MARKER, marker_kind, "generation_opportunity"]),
		{
			"source": SOURCE_LEGACY_DEBUG_MARKER,
			"source_key": "debug_markers.%s" % marker_index,
			"marker_index": marker_index,
			"legacy_debug_marker": marker.duplicate(true),
		}
	)


func configure(
	p_candidate_id: String,
	p_candidate_kind: String,
	p_world_position_or_bounds: Variant = {},
	p_source_feature: String = "",
	p_score: float = 0.0,
	p_constraints: Dictionary = {},
	p_tags: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	candidate_id = p_candidate_id.strip_edges()
	candidate_kind = p_candidate_kind.strip_edges()
	world_position_or_bounds = _duplicate_variant(p_world_position_or_bounds)
	source_feature = p_source_feature.strip_edges()
	score = p_score
	constraints = p_constraints.duplicate(true)
	tags = p_tags.duplicate()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_candidate() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		candidate_id,
		candidate_kind,
		_duplicate_variant(world_position_or_bounds),
		source_feature,
		score,
		constraints,
		tags,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("PlacementCandidate:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not candidate_id.is_empty() \
		and not candidate_kind.is_empty() \
		and not _contains_runtime_object(world_position_or_bounds) \
		and not _contains_runtime_object(constraints) \
		and not _contains_runtime_object(metadata)


func has_tag(tag: String) -> bool:
	return tags.has(tag.strip_edges())


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"candidate_id": candidate_id,
		"candidate_kind": candidate_kind,
		"world_position_or_bounds": _duplicate_variant(world_position_or_bounds),
		"source_feature": source_feature,
		"score": score,
		"constraints": constraints.duplicate(true),
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _position_or_bounds_from_marker(marker: Dictionary, fallback_bounds: Dictionary) -> Variant:
	if marker.has("center"):
		return marker["center"]
	if marker.has("rect_position") and marker.has("rect_size"):
		return Rect2i(marker["rect_position"], marker["rect_size"])
	if marker.has("from") and marker.has("to"):
		return {"from_cell": marker["from"], "to_cell": marker["to"]}
	return fallback_bounds.get("owned_cell_bounds", Rect2i())


static func _padded_index(value: int) -> String:
	var text := str(maxi(value, 0))
	while text.length() < 4:
		text = "0%s" % text
	return text


static func _duplicate_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return dictionary_value.duplicate(true)
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.duplicate(true)
		TYPE_PACKED_STRING_ARRAY:
			var strings: PackedStringArray = value
			return strings.duplicate()
		_:
			return value


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
