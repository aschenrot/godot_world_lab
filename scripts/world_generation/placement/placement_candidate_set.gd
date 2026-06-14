extends RefCounted

class_name PlacementCandidateSet

const PRODUCT_TYPE := "PlacementCandidateSet"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/placement/placement_candidate_set.gd"
const PlacementCandidateScript := preload("res://scripts/world_generation/placement/placement_candidate.gd")

const INVALID_DUPLICATE_CANDIDATE_IDS_KEY := "invalid_duplicate_candidate_ids"
const INVALID_CANDIDATE_IDS_KEY := "invalid_candidate_ids"

var candidates_by_id: Dictionary = {}
var metadata: Dictionary = {}


static func from_parts(
	p_candidates_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var candidate_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	return candidate_set.configure(p_candidates_by_id, p_metadata)


static func from_legacy_debug_markers(
	debug_markers: Array,
	bounds: Dictionary = {}
) -> RefCounted:
	var candidate_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	for marker_index in range(debug_markers.size()):
		var marker: Variant = debug_markers[marker_index]
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		candidate_set.add_candidate(PlacementCandidateScript.from_legacy_debug_marker(
			marker_index,
			marker,
			bounds
		))
	return candidate_set


func configure(
	p_candidates_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	candidates_by_id = {}
	metadata = p_metadata.duplicate(true)
	for candidate_key in p_candidates_by_id.keys():
		var candidate: Variant = p_candidates_by_id[candidate_key]
		if _is_placement_candidate(candidate):
			add_candidate(candidate, true)
	return self


func add_candidate(candidate: RefCounted, overwrite_existing: bool = false) -> void:
	if candidate == null:
		_record_invalid_candidate_id("")
		return
	var normalized_candidate_id: String = candidate.candidate_id.strip_edges()
	if normalized_candidate_id.is_empty() or not candidate.is_valid():
		_record_invalid_candidate_id(normalized_candidate_id)
		return
	if candidates_by_id.has(normalized_candidate_id) and not overwrite_existing:
		_record_duplicate_candidate_id(normalized_candidate_id)
		return
	candidates_by_id[normalized_candidate_id] = candidate.duplicate_candidate()


func has_candidate(candidate_id: String) -> bool:
	return candidates_by_id.has(candidate_id.strip_edges())


func get_candidate(candidate_id: String) -> RefCounted:
	var normalized_candidate_id := candidate_id.strip_edges()
	if not candidates_by_id.has(normalized_candidate_id):
		return null
	return candidates_by_id[normalized_candidate_id].duplicate_candidate()


func candidate_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for candidate_id in candidates_by_id.keys():
		ids.append(String(candidate_id))
	ids.sort()
	return ids


func candidates_by_kind(candidate_kind: String) -> Array:
	var matches: Array = []
	var normalized_kind := candidate_kind.strip_edges()
	for candidate_id in candidate_ids():
		var candidate: RefCounted = candidates_by_id[candidate_id]
		if candidate.candidate_kind == normalized_kind:
			matches.append(candidate.duplicate_candidate())
	return matches


func candidates_with_tag(tag: String) -> Array:
	var matches: Array = []
	for candidate_id in candidate_ids():
		var candidate: RefCounted = candidates_by_id[candidate_id]
		if candidate.has_tag(tag):
			matches.append(candidate.duplicate_candidate())
	return matches


func candidate_counts_by_kind() -> Dictionary:
	var counts: Dictionary = {}
	for candidate_id in candidate_ids():
		var candidate: RefCounted = candidates_by_id[candidate_id]
		counts[candidate.candidate_kind] = int(counts.get(candidate.candidate_kind, 0)) + 1
	return counts


func duplicate_set() -> RefCounted:
	var copy: RefCounted = load(SELF_SCRIPT_PATH).new()
	copy.metadata = metadata.duplicate(true)
	for candidate_id in candidate_ids():
		copy.candidates_by_id[candidate_id] = candidates_by_id[candidate_id].duplicate_candidate()
	return copy


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("PlacementCandidateSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	if _metadata_array(INVALID_DUPLICATE_CANDIDATE_IDS_KEY).size() > 0:
		return false
	if _metadata_array(INVALID_CANDIDATE_IDS_KEY).size() > 0:
		return false
	if _contains_runtime_object(metadata):
		return false
	for candidate_id in candidate_ids():
		var candidate: RefCounted = candidates_by_id[candidate_id]
		if candidate == null or not candidate.is_valid():
			return false
	return true


func _payload_dictionary() -> Dictionary:
	var candidates: Dictionary = {}
	for candidate_id in candidate_ids():
		var candidate: RefCounted = candidates_by_id[candidate_id]
		candidates[candidate_id] = candidate.to_dictionary() if candidate != null else {}
	return {
		"product_type": PRODUCT_TYPE,
		"candidate_ids": candidate_ids(),
		"candidates": candidates,
		"metadata": metadata.duplicate(true),
		"candidate_count": candidate_ids().size(),
		"candidate_counts_by_kind": candidate_counts_by_kind(),
	}


func _record_duplicate_candidate_id(candidate_id: String) -> void:
	var duplicate_ids := _metadata_array(INVALID_DUPLICATE_CANDIDATE_IDS_KEY)
	duplicate_ids.append(candidate_id)
	metadata[INVALID_DUPLICATE_CANDIDATE_IDS_KEY] = duplicate_ids


func _record_invalid_candidate_id(candidate_id: String) -> void:
	var invalid_ids := _metadata_array(INVALID_CANDIDATE_IDS_KEY)
	invalid_ids.append(candidate_id)
	metadata[INVALID_CANDIDATE_IDS_KEY] = invalid_ids


func _metadata_array(key: String) -> Array:
	var value: Variant = metadata.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	return []


func _is_placement_candidate(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT \
		and value != null \
		and value.has_method("duplicate_candidate") \
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
