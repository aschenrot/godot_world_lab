extends RefCounted

class_name RuntimeAbstractionReview

const PRODUCT_TYPE := "RuntimeAbstractionReview"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/runtime_abstraction_review.gd"

const DECISION_DEFER_NEW_RUNTIME_ABSTRACTIONS := "defer_new_runtime_abstractions"
const DECISION_ELIGIBLE_FOR_RUNTIME_ABSTRACTION_DESIGN := "eligible_for_runtime_abstraction_design"

var review_id: String = "mature_runtime_abstraction_review"
var decision: String = DECISION_DEFER_NEW_RUNTIME_ABSTRACTIONS
var runtime_abstraction_allowed: bool = false
var criteria: Dictionary = {}
var blocking_criteria_ids: PackedStringArray = PackedStringArray()
var guarded_symbol_ids: PackedStringArray = PackedStringArray()
var rationale: PackedStringArray = PackedStringArray()
var deferred_scope: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func maturity_criteria_ids() -> PackedStringArray:
	return PackedStringArray([
		"data_product_contracts_stable",
		"definition_diversity_proven",
		"host_adapter_boundaries_proven",
		"legacy_retention_gate_allows_removal",
		"replacement_generation_authority_proven",
		"direct_generated_world_chunk_host_adapters_proven",
		"non_godot_consumer_need_proven",
		"runenwerk_integration_pressure_proven",
	])


static func default_guarded_symbol_ids() -> PackedStringArray:
	return PackedStringArray([
		"WorldGenerationSemantics",
		"WorldGenerationProgram",
		"WorldGenerationCompiler",
		"WorldGenerationArtifact",
		"WorldGenerationEvaluator",
	])


static func from_criteria(
	p_criteria: Dictionary,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var review: RefCounted = load(SELF_SCRIPT_PATH).new()
	return review.configure(p_criteria, p_metadata)


func configure(
	p_criteria: Dictionary,
	p_metadata: Dictionary = {}
) -> RefCounted:
	criteria = _normalized_criteria(p_criteria)
	metadata = p_metadata.duplicate(true)
	guarded_symbol_ids = default_guarded_symbol_ids()
	blocking_criteria_ids = _blocking_criteria(criteria)
	runtime_abstraction_allowed = blocking_criteria_ids.is_empty()
	decision = DECISION_ELIGIBLE_FOR_RUNTIME_ABSTRACTION_DESIGN \
		if runtime_abstraction_allowed else DECISION_DEFER_NEW_RUNTIME_ABSTRACTIONS
	rationale = _rationale_for_decision()
	deferred_scope = _deferred_scope_for_decision()
	return self


func duplicate_review() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_criteria(criteria, metadata)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("RuntimeAbstractionReview:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not review_id.is_empty() \
		and (
			decision == DECISION_DEFER_NEW_RUNTIME_ABSTRACTIONS
			or decision == DECISION_ELIGIBLE_FOR_RUNTIME_ABSTRACTION_DESIGN
		) \
		and not criteria.is_empty() \
		and not guarded_symbol_ids.is_empty() \
		and not _contains_runtime_object(criteria) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"review_id": review_id,
		"decision": decision,
		"runtime_abstraction_allowed": runtime_abstraction_allowed,
		"criteria": criteria.duplicate(true),
		"blocking_criteria_ids": blocking_criteria_ids.duplicate(),
		"guarded_symbol_ids": guarded_symbol_ids.duplicate(),
		"rationale": rationale.duplicate(),
		"deferred_scope": deferred_scope.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _normalized_criteria(input_criteria: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for criterion_id in maturity_criteria_ids():
		normalized[criterion_id] = bool(input_criteria.get(criterion_id, false))
	for criterion_id in input_criteria.keys():
		var key := String(criterion_id).strip_edges()
		if key.is_empty() or normalized.has(key):
			continue
		normalized[key] = bool(input_criteria[criterion_id])
	return normalized


static func _blocking_criteria(input_criteria: Dictionary) -> PackedStringArray:
	var blocking_ids := PackedStringArray()
	for criterion_id in maturity_criteria_ids():
		if not bool(input_criteria.get(criterion_id, false)):
			blocking_ids.append(criterion_id)
	return blocking_ids


func _rationale_for_decision() -> PackedStringArray:
	if runtime_abstraction_allowed:
		return PackedStringArray([
			"All maturity criteria passed; a separate design milestone may introduce runtime abstractions.",
		])
	var lines := PackedStringArray([
		"New runtime abstractions must be deferred until all maturity criteria pass.",
	])
	for criterion_id in blocking_criteria_ids:
		lines.append("blocking criterion: %s" % criterion_id)
	for symbol_id in guarded_symbol_ids:
		lines.append("guarded symbol: %s" % symbol_id)
	return lines


func _deferred_scope_for_decision() -> PackedStringArray:
	if runtime_abstraction_allowed:
		return PackedStringArray()
	return PackedStringArray([
		"WorldGenerationSemantics",
		"WorldGenerationProgram",
		"WorldGenerationCompiler",
		"WorldGenerationArtifact",
		"WorldGenerationEvaluator",
		"direct GeneratedWorldChunk host adapters",
		"replacement generation authority",
		"non-Godot consumer contract",
		"Runenwerk integration pressure review",
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
