extends RefCounted

class_name ContinuityFactSet

const PRODUCT_TYPE := "ContinuityFactSet"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/continuity/continuity_fact_set.gd"
const ContinuityFactScript := preload("res://scripts/world_generation/continuity/continuity_fact.gd")

const INVALID_DUPLICATE_FACT_IDS_KEY := "invalid_duplicate_fact_ids"
const INVALID_FACT_IDS_KEY := "invalid_fact_ids"

var facts_by_id: Dictionary = {}
var metadata: Dictionary = {}


static func from_parts(
	p_facts_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var fact_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	return fact_set.configure(p_facts_by_id, p_metadata)


static func from_context_bounds(bounds: Dictionary = {}) -> RefCounted:
	var fact_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	fact_set.add_fact(ContinuityFactScript.from_context_bounds_value(
		"context_chunk_coord",
		"chunk_identity",
		"chunk_coord",
		bounds.get("chunk_coord", Vector3i.ZERO),
		bounds,
		100
	))
	fact_set.add_fact(ContinuityFactScript.from_context_bounds_value(
		"context_owned_cell_bounds",
		"owned_region",
		"owned_cell_bounds",
		bounds.get("owned_cell_bounds", Rect2i()),
		bounds,
		90
	))
	fact_set.add_fact(ContinuityFactScript.from_context_bounds_value(
		"context_sample_cell_bounds",
		"sample_region",
		"sample_cell_bounds",
		bounds.get("sample_cell_bounds", Rect2i()),
		bounds,
		80
	))
	fact_set.add_fact(ContinuityFactScript.from_context_bounds_value(
		"context_halo_cells",
		"sampling_halo",
		"halo_cells",
		bounds.get("halo_cells", 0),
		bounds,
		70
	))
	return fact_set


func configure(
	p_facts_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	facts_by_id = {}
	metadata = p_metadata.duplicate(true)
	for fact_key in p_facts_by_id.keys():
		var fact: Variant = p_facts_by_id[fact_key]
		if _is_continuity_fact(fact):
			add_fact(fact, true)
	return self


func add_fact(fact: RefCounted, overwrite_existing: bool = false) -> void:
	if fact == null:
		_record_invalid_fact_id("")
		return
	var normalized_fact_id: String = fact.fact_id.strip_edges()
	if normalized_fact_id.is_empty() or not fact.is_valid():
		_record_invalid_fact_id(normalized_fact_id)
		return
	if facts_by_id.has(normalized_fact_id) and not overwrite_existing:
		_record_duplicate_fact_id(normalized_fact_id)
		return
	facts_by_id[normalized_fact_id] = fact.duplicate_fact()


func has_fact(fact_id: String) -> bool:
	return facts_by_id.has(fact_id.strip_edges())


func get_fact(fact_id: String) -> RefCounted:
	var normalized_fact_id := fact_id.strip_edges()
	if not facts_by_id.has(normalized_fact_id):
		return null
	return facts_by_id[normalized_fact_id].duplicate_fact()


func fact_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for fact_id in facts_by_id.keys():
		ids.append(String(fact_id))
	ids.sort()
	return ids


func facts_by_kind(continuity_kind: String) -> Array:
	var matches: Array = []
	var normalized_kind := continuity_kind.strip_edges()
	for fact_id in fact_ids():
		var fact: RefCounted = facts_by_id[fact_id]
		if fact.continuity_kind == normalized_kind:
			matches.append(fact.duplicate_fact())
	return matches


func facts_for_boundary(boundary_key: String) -> Array:
	var matches: Array = []
	var normalized_key := boundary_key.strip_edges()
	for fact_id in fact_ids():
		var fact: RefCounted = facts_by_id[fact_id]
		if fact.boundary_key == normalized_key:
			matches.append(fact.duplicate_fact())
	return matches


func fact_counts_by_kind() -> Dictionary:
	var counts: Dictionary = {}
	for fact_id in fact_ids():
		var fact: RefCounted = facts_by_id[fact_id]
		counts[fact.continuity_kind] = int(counts.get(fact.continuity_kind, 0)) + 1
	return counts


func duplicate_set() -> RefCounted:
	var copy: RefCounted = load(SELF_SCRIPT_PATH).new()
	copy.metadata = metadata.duplicate(true)
	for fact_id in fact_ids():
		copy.facts_by_id[fact_id] = facts_by_id[fact_id].duplicate_fact()
	return copy


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("ContinuityFactSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	if _metadata_array(INVALID_DUPLICATE_FACT_IDS_KEY).size() > 0:
		return false
	if _metadata_array(INVALID_FACT_IDS_KEY).size() > 0:
		return false
	if _contains_runtime_object(metadata):
		return false
	for fact_id in fact_ids():
		var fact: RefCounted = facts_by_id[fact_id]
		if fact == null or not fact.is_valid():
			return false
	return true


func _payload_dictionary() -> Dictionary:
	var facts: Dictionary = {}
	for fact_id in fact_ids():
		var fact: RefCounted = facts_by_id[fact_id]
		facts[fact_id] = fact.to_dictionary() if fact != null else {}
	return {
		"product_type": PRODUCT_TYPE,
		"fact_ids": fact_ids(),
		"facts": facts,
		"metadata": metadata.duplicate(true),
		"fact_count": fact_ids().size(),
		"fact_counts_by_kind": fact_counts_by_kind(),
	}


func _record_duplicate_fact_id(fact_id: String) -> void:
	var duplicate_ids := _metadata_array(INVALID_DUPLICATE_FACT_IDS_KEY)
	duplicate_ids.append(fact_id)
	metadata[INVALID_DUPLICATE_FACT_IDS_KEY] = duplicate_ids


func _record_invalid_fact_id(fact_id: String) -> void:
	var invalid_ids := _metadata_array(INVALID_FACT_IDS_KEY)
	invalid_ids.append(fact_id)
	metadata[INVALID_FACT_IDS_KEY] = invalid_ids


func _metadata_array(key: String) -> Array:
	var value: Variant = metadata.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	return []


func _is_continuity_fact(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT \
		and value != null \
		and value.has_method("duplicate_fact") \
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
