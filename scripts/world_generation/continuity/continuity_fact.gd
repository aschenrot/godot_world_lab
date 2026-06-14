extends RefCounted

class_name ContinuityFact

const PRODUCT_TYPE := "ContinuityFact"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/continuity/continuity_fact.gd"
const SOURCE_CONTEXT_BOUNDS := "generation_context_bounds"

var fact_id: String = ""
var continuity_kind: String = ""
var boundary_key: String = ""
var participating_domain: String = ""
var deterministic_value: Variant = null
var source_contract: String = ""
var priority: int = 0
var metadata: Dictionary = {}


static func from_parts(
	p_fact_id: String,
	p_continuity_kind: String,
	p_boundary_key: String,
	p_participating_domain: String,
	p_deterministic_value: Variant,
	p_source_contract: String,
	p_priority: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var fact: RefCounted = load(SELF_SCRIPT_PATH).new()
	return fact.configure(
		p_fact_id,
		p_continuity_kind,
		p_boundary_key,
		p_participating_domain,
		p_deterministic_value,
		p_source_contract,
		p_priority,
		p_metadata
	)


static func from_context_bounds_value(
	p_fact_id: String,
	p_continuity_kind: String,
	p_boundary_key: String,
	p_deterministic_value: Variant,
	p_bounds: Dictionary = {},
	p_priority: int = 0
) -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		p_fact_id,
		p_continuity_kind,
		p_boundary_key,
		String(p_bounds.get("domain_descriptor", WorldSpace.DOMAIN_CELL_GRID_2D)),
		p_deterministic_value,
		SOURCE_CONTEXT_BOUNDS,
		p_priority,
		{
			"chunk_coord": p_bounds.get("chunk_coord", Vector3i.ZERO),
			"source": SOURCE_CONTEXT_BOUNDS,
		}
	)


func configure(
	p_fact_id: String,
	p_continuity_kind: String,
	p_boundary_key: String,
	p_participating_domain: String,
	p_deterministic_value: Variant,
	p_source_contract: String,
	p_priority: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	fact_id = p_fact_id.strip_edges()
	continuity_kind = p_continuity_kind.strip_edges()
	boundary_key = p_boundary_key.strip_edges()
	participating_domain = p_participating_domain.strip_edges()
	deterministic_value = _duplicate_variant(p_deterministic_value)
	source_contract = p_source_contract.strip_edges()
	priority = p_priority
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_fact() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		fact_id,
		continuity_kind,
		boundary_key,
		participating_domain,
		_duplicate_variant(deterministic_value),
		source_contract,
		priority,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("ContinuityFact:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not fact_id.is_empty() \
		and not continuity_kind.is_empty() \
		and not boundary_key.is_empty() \
		and not participating_domain.is_empty() \
		and not source_contract.is_empty() \
		and not _contains_runtime_object(deterministic_value) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"fact_id": fact_id,
		"continuity_kind": continuity_kind,
		"boundary_key": boundary_key,
		"participating_domain": participating_domain,
		"deterministic_value": _duplicate_variant(deterministic_value),
		"source_contract": source_contract,
		"priority": priority,
		"metadata": metadata.duplicate(true),
	}


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
