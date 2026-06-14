extends SceneTree

const ExtractionOwnershipReviewScript := preload("res://scripts/world_generation/extraction_ownership_review.gd")
const RuntimeAbstractionReviewScript := preload("res://scripts/world_generation/runtime_abstraction_review.gd")
const LegacyRetentionDecisionScript := preload("res://scripts/world_generation/legacy/legacy_retention_decision.gd")
const WorldDefinitionProfileLibraryScript := preload("res://scripts/world_generation/definition/world_definition_profile_library.gd")

var failed: bool = false


func _initialize() -> void:
	test_current_review_defers_rust_runenwerk_and_extraction()
	quit(1 if failed else 0)


func test_current_review_defers_rust_runenwerk_and_extraction() -> void:
	var definition_proof: Dictionary = WorldDefinitionProfileLibraryScript.proof_summary()
	var legacy_decision: RefCounted = LegacyRetentionDecisionScript.from_criteria(
		{
			"semantic_layer_adapter_parity_proven": true,
			"topology_projection_adapter_parity_proven": true,
			"formation_product_adapter_parity_proven": true,
			"host_adapter_product_consumption_proven": true,
			"compatibility_output_preserved": true,
			"replacement_generation_authority_proven": false,
			"legacy_stage_dependency_removed": false,
			"legacy_wrapper_dependency_removed": false,
		},
		{"authority": "extraction_ownership_review_smoke"}
	)
	var runtime_review: RefCounted = RuntimeAbstractionReviewScript.from_criteria(
		{
			"data_product_contracts_stable": true,
			"definition_diversity_proven": bool(definition_proof.get("different_contract_hash", false)),
			"host_adapter_boundaries_proven": true,
			"legacy_retention_gate_allows_removal": legacy_decision.removal_allowed,
			"replacement_generation_authority_proven": false,
			"direct_generated_world_chunk_host_adapters_proven": false,
			"non_godot_consumer_need_proven": false,
			"runenwerk_integration_pressure_proven": false,
		},
		{"authority": "extraction_ownership_review_smoke"}
	)
	var criteria := {
		"godot_lab_product_contracts_proven": bool(definition_proof.get("different_contract_hash", false))
			and bool(definition_proof.get("same_generation_settings_hash", false)),
		"legacy_removal_allowed": legacy_decision.removal_allowed,
		"runtime_abstraction_allowed": runtime_review.runtime_abstraction_allowed,
		"replacement_generation_authority_proven": false,
		"non_godot_consumer_need_proven": false,
		"runenwerk_wrong_owner_proven": false,
		"runenwerk_integration_pressure_proven": false,
		"rust_api_would_be_smaller_than_godot_proof": false,
		"durable_external_invariants_proven": false,
	}
	var review: RefCounted = ExtractionOwnershipReviewScript.from_criteria(
		criteria,
		{
			"authority": "world_generation_extraction_ownership_review_smoke",
			"legacy_decision": legacy_decision.decision,
			"runtime_decision": runtime_review.decision,
		}
	)
	var review_data: Dictionary = review.to_dictionary()
	var guarded_paths: PackedStringArray = _guarded_implementation_paths()

	_assert(bool(criteria["godot_lab_product_contracts_proven"]), "Godot Lab product contracts are proven enough to review")
	_assert(not bool(criteria["legacy_removal_allowed"]), "legacy removal is not allowed")
	_assert(not bool(criteria["runtime_abstraction_allowed"]), "runtime abstraction is not allowed")
	_assert(not bool(criteria["replacement_generation_authority_proven"]), "replacement generation authority is not proven")
	_assert(not bool(criteria["non_godot_consumer_need_proven"]), "non-Godot consumer need is not proven")
	_assert(not bool(criteria["runenwerk_wrong_owner_proven"]), "Runenwerk is not proven the wrong owner")
	_assert(not bool(criteria["runenwerk_integration_pressure_proven"]), "Runenwerk integration pressure is not proven")
	_assert(not bool(criteria["rust_api_would_be_smaller_than_godot_proof"]), "smaller Rust API is not proven")
	_assert(not bool(criteria["durable_external_invariants_proven"]), "external durable invariants are not proven")
	_assert(review.is_valid(), "extraction ownership review is valid")
	_assert(
		review.decision == ExtractionOwnershipReviewScript.DECISION_DEFER_EXTRACTION_AND_INTEGRATION,
		"extraction ownership review defers extraction and integration"
	)
	_assert(not review.extraction_allowed, "extraction is not allowed by current review")
	for blocker_id in PackedStringArray([
		"legacy_removal_allowed",
		"runtime_abstraction_allowed",
		"replacement_generation_authority_proven",
		"non_godot_consumer_need_proven",
		"runenwerk_wrong_owner_proven",
		"runenwerk_integration_pressure_proven",
	]):
		_assert(review.blocking_criteria_ids.has(blocker_id), "review blocks on %s" % blocker_id)
	for guarded_artifact_id in ExtractionOwnershipReviewScript.default_guarded_artifact_ids():
		_assert(review.guarded_artifact_ids.has(guarded_artifact_id), "review guards %s" % guarded_artifact_id)
	_assert(
		review.ownership_findings.get("crystonix_procgen", "") == "no_owner_yet",
		"Crystonix/procgen has no ownership yet"
	)
	_assert(
		review.ownership_findings.get("grid", "") == "reusable_grid_and_topology_mechanics",
		"grid ownership remains topology mechanics"
	)
	_assert(
		review.ownership_findings.get("spatial_streaming", "") == "payload_neutral_streaming_lifecycle",
		"spatial_streaming ownership remains lifecycle"
	)
	_assert(guarded_paths.is_empty(), "no guarded Rust/procgen implementation paths exist")
	_assert(
		review.signature_hash() == review.duplicate_review().signature_hash(),
		"extraction ownership review signature is deterministic"
	)
	_assert(
		review_data.get("product_type", "") == ExtractionOwnershipReviewScript.PRODUCT_TYPE,
		"extraction ownership review dictionary is typed"
	)


func _guarded_implementation_paths() -> PackedStringArray:
	var matches := PackedStringArray()
	_scan_guarded_paths("res://", matches)
	matches.sort()
	return matches


func _scan_guarded_paths(path: String, matches: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name == "." or entry_name == "..":
			entry_name = directory.get_next()
			continue
		var entry_path := path.path_join(entry_name)
		if directory.current_is_dir():
			if _should_skip_directory(entry_name):
				entry_name = directory.get_next()
				continue
			if entry_name.to_lower() == "procgen":
				matches.append(entry_path)
			_scan_guarded_paths(entry_path, matches)
		elif entry_name == "Cargo.toml" or entry_name.get_extension() == "rs":
			matches.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _should_skip_directory(directory_name: String) -> bool:
	return directory_name in PackedStringArray([
		".git",
		".godot",
		".import",
		"addons",
	])


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_extraction_ownership_review_smoke failed: %s" % message)
