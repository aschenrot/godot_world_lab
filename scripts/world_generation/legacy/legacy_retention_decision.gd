extends RefCounted

class_name LegacyRetentionDecision

const PRODUCT_TYPE := "LegacyRetentionDecision"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/legacy/legacy_retention_decision.gd"

const DECISION_RETAIN := "retain_legacy_generation"
const DECISION_ELIGIBLE_FOR_EXPLICIT_REMOVAL_REVIEW := "eligible_for_explicit_removal_review"

var decision_id: String = "legacy_removal_retention_gate"
var decision: String = DECISION_RETAIN
var removal_allowed: bool = false
var criteria: Dictionary = {}
var blocking_criteria_ids: PackedStringArray = PackedStringArray()
var rationale: PackedStringArray = PackedStringArray()
var deferred_scope: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func removal_criteria_ids() -> PackedStringArray:
	return PackedStringArray([
		"semantic_layer_adapter_parity_proven",
		"topology_projection_adapter_parity_proven",
		"formation_product_adapter_parity_proven",
		"host_adapter_product_consumption_proven",
		"compatibility_output_preserved",
		"replacement_generation_authority_proven",
		"legacy_stage_dependency_removed",
		"legacy_wrapper_dependency_removed",
	])


static func from_criteria(
	p_criteria: Dictionary,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var decision_product: RefCounted = load(SELF_SCRIPT_PATH).new()
	return decision_product.configure(p_criteria, p_metadata)


func configure(
	p_criteria: Dictionary,
	p_metadata: Dictionary = {}
) -> RefCounted:
	criteria = _normalized_criteria(p_criteria)
	metadata = p_metadata.duplicate(true)
	blocking_criteria_ids = _blocking_criteria(criteria)
	removal_allowed = blocking_criteria_ids.is_empty()
	decision = DECISION_ELIGIBLE_FOR_EXPLICIT_REMOVAL_REVIEW if removal_allowed else DECISION_RETAIN
	rationale = _rationale_for_decision()
	deferred_scope = _deferred_scope_for_decision()
	return self


func duplicate_decision() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_criteria(criteria, metadata)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("LegacyRetentionDecision:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not decision_id.is_empty() \
		and (decision == DECISION_RETAIN or decision == DECISION_ELIGIBLE_FOR_EXPLICIT_REMOVAL_REVIEW) \
		and not criteria.is_empty() \
		and not _contains_runtime_object(criteria) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"decision_id": decision_id,
		"decision": decision,
		"removal_allowed": removal_allowed,
		"criteria": criteria.duplicate(true),
		"blocking_criteria_ids": blocking_criteria_ids.duplicate(),
		"rationale": rationale.duplicate(),
		"deferred_scope": deferred_scope.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _normalized_criteria(input_criteria: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for criterion_id in removal_criteria_ids():
		normalized[criterion_id] = bool(input_criteria.get(criterion_id, false))
	for criterion_id in input_criteria.keys():
		var key := String(criterion_id).strip_edges()
		if key.is_empty() or normalized.has(key):
			continue
		normalized[key] = bool(input_criteria[criterion_id])
	return normalized


static func _blocking_criteria(input_criteria: Dictionary) -> PackedStringArray:
	var blocking_ids := PackedStringArray()
	for criterion_id in removal_criteria_ids():
		if not bool(input_criteria.get(criterion_id, false)):
			blocking_ids.append(criterion_id)
	return blocking_ids


func _rationale_for_decision() -> PackedStringArray:
	if removal_allowed:
		return PackedStringArray([
			"All removal criteria passed; a separate explicit removal milestone may be planned.",
		])
	var lines := PackedStringArray([
		"Legacy generation must be retained until all removal criteria pass.",
	])
	for criterion_id in blocking_criteria_ids:
		lines.append("blocking criterion: %s" % criterion_id)
	return lines


func _deferred_scope_for_decision() -> PackedStringArray:
	if removal_allowed:
		return PackedStringArray()
	return PackedStringArray([
		"replacement generation authority",
		"legacy stage replacement",
		"legacy wrapper removal",
		"legacy generation result removal",
		"legacy cache wrapper removal",
	])


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
