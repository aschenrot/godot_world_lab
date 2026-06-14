extends RefCounted

class_name ExtractionOwnershipReview

const PRODUCT_TYPE := "ExtractionOwnershipReview"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/extraction_ownership_review.gd"

const DECISION_DEFER_EXTRACTION_AND_INTEGRATION := "defer_extraction_and_integration"
const DECISION_ELIGIBLE_FOR_EXTRACTION_DESIGN := "eligible_for_extraction_design"

var review_id: String = "rust_runenwerk_extraction_ownership_review"
var decision: String = DECISION_DEFER_EXTRACTION_AND_INTEGRATION
var extraction_allowed: bool = false
var criteria: Dictionary = {}
var blocking_criteria_ids: PackedStringArray = PackedStringArray()
var ownership_findings: Dictionary = {}
var guarded_artifact_ids: PackedStringArray = PackedStringArray()
var rationale: PackedStringArray = PackedStringArray()
var deferred_scope: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func extraction_criteria_ids() -> PackedStringArray:
	return PackedStringArray([
		"godot_lab_product_contracts_proven",
		"legacy_removal_allowed",
		"runtime_abstraction_allowed",
		"replacement_generation_authority_proven",
		"non_godot_consumer_need_proven",
		"runenwerk_wrong_owner_proven",
		"runenwerk_integration_pressure_proven",
		"rust_api_would_be_smaller_than_godot_proof",
		"durable_external_invariants_proven",
	])


static func default_guarded_artifact_ids() -> PackedStringArray:
	return PackedStringArray([
		"Crystonix/procgen",
		"Rust procgen crate",
		"Runenwerk integration",
		"Runenwerk final procgen graph contract",
		"Runenwerk SDF payload ownership",
		"grid/spatial_streaming merge",
	])


static func default_ownership_findings() -> Dictionary:
	return {
		"godot_lab": "proof_host_and_godot_adapters",
		"runenwerk": "future_candidate_owner_for_runenwerk_specific_procgen_domain",
		"grid": "reusable_grid_and_topology_mechanics",
		"spatial_streaming": "payload_neutral_streaming_lifecycle",
		"crystonix_procgen": "no_owner_yet",
	}


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
	guarded_artifact_ids = default_guarded_artifact_ids()
	ownership_findings = default_ownership_findings()
	blocking_criteria_ids = _blocking_criteria(criteria)
	extraction_allowed = blocking_criteria_ids.is_empty()
	decision = DECISION_ELIGIBLE_FOR_EXTRACTION_DESIGN \
		if extraction_allowed else DECISION_DEFER_EXTRACTION_AND_INTEGRATION
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
	var h := GeneratedChunkIdentity.stable_hash_string("ExtractionOwnershipReview:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not review_id.is_empty() \
		and (
			decision == DECISION_DEFER_EXTRACTION_AND_INTEGRATION
			or decision == DECISION_ELIGIBLE_FOR_EXTRACTION_DESIGN
		) \
		and not criteria.is_empty() \
		and not guarded_artifact_ids.is_empty() \
		and not ownership_findings.is_empty() \
		and not _contains_runtime_object(criteria) \
		and not _contains_runtime_object(ownership_findings) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"review_id": review_id,
		"decision": decision,
		"extraction_allowed": extraction_allowed,
		"criteria": criteria.duplicate(true),
		"blocking_criteria_ids": blocking_criteria_ids.duplicate(),
		"ownership_findings": ownership_findings.duplicate(true),
		"guarded_artifact_ids": guarded_artifact_ids.duplicate(),
		"rationale": rationale.duplicate(),
		"deferred_scope": deferred_scope.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _normalized_criteria(input_criteria: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for criterion_id in extraction_criteria_ids():
		normalized[criterion_id] = bool(input_criteria.get(criterion_id, false))
	for criterion_id in input_criteria.keys():
		var key := String(criterion_id).strip_edges()
		if key.is_empty() or normalized.has(key):
			continue
		normalized[key] = bool(input_criteria[criterion_id])
	return normalized


static func _blocking_criteria(input_criteria: Dictionary) -> PackedStringArray:
	var blocking_ids := PackedStringArray()
	for criterion_id in extraction_criteria_ids():
		if not bool(input_criteria.get(criterion_id, false)):
			blocking_ids.append(criterion_id)
	return blocking_ids


func _rationale_for_decision() -> PackedStringArray:
	if extraction_allowed:
		return PackedStringArray([
			"All ownership criteria passed; a separate extraction design milestone may be planned.",
		])
	var lines := PackedStringArray([
		"Rust, Runenwerk, and extraction ownership must be deferred until all ownership criteria pass.",
	])
	for criterion_id in blocking_criteria_ids:
		lines.append("blocking criterion: %s" % criterion_id)
	for artifact_id in guarded_artifact_ids:
		lines.append("guarded artifact: %s" % artifact_id)
	return lines


func _deferred_scope_for_decision() -> PackedStringArray:
	if extraction_allowed:
		return PackedStringArray()
	return PackedStringArray([
		"Crystonix/procgen repository",
		"Rust procgen crate",
		"Runenwerk integration",
		"Runenwerk final procgen graph contract",
		"Runenwerk SDF payload ownership",
		"grid/spatial_streaming merge",
		"save/load ownership",
		"ECS or spawning ownership",
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
