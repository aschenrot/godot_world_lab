extends SceneTree

const RuntimeAbstractionReviewScript := preload("res://scripts/world_generation/runtime_abstraction_review.gd")
const LegacyRetentionDecisionScript := preload("res://scripts/world_generation/legacy/legacy_retention_decision.gd")
const WorldDefinitionProfileLibraryScript := preload("res://scripts/world_generation/definition/world_definition_profile_library.gd")

var failed: bool = false


func _initialize() -> void:
	test_current_review_defers_new_runtime_abstractions()
	quit(1 if failed else 0)


func test_current_review_defers_new_runtime_abstractions() -> void:
	var VisualBuilder := load("res://scripts/chunk_visual_builder.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")
	var visual_builder: RefCounted = VisualBuilder.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
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
		{"authority": "runtime_abstraction_review_smoke"}
	)
	var criteria := {
		"data_product_contracts_stable": _data_product_contracts_stable(),
		"definition_diversity_proven": bool(definition_proof.get("different_contract_hash", false))
			and bool(definition_proof.get("same_generation_settings_hash", false)),
		"host_adapter_boundaries_proven": _host_adapter_boundaries_are_non_authoritative(
			visual_builder,
			collision_builder
		),
		"legacy_retention_gate_allows_removal": legacy_decision.removal_allowed,
		"replacement_generation_authority_proven": false,
		"direct_generated_world_chunk_host_adapters_proven": false,
		"non_godot_consumer_need_proven": false,
		"runenwerk_integration_pressure_proven": false,
	}
	var review: RefCounted = RuntimeAbstractionReviewScript.from_criteria(
		criteria,
		{
			"authority": "world_generation_runtime_abstraction_review_smoke",
			"legacy_decision": legacy_decision.decision,
		}
	)
	var review_data: Dictionary = review.to_dictionary()

	_assert(bool(criteria["data_product_contracts_stable"]), "data product contracts are present")
	_assert(bool(criteria["definition_diversity_proven"]), "definition diversity proof is present")
	_assert(bool(criteria["host_adapter_boundaries_proven"]), "host adapter boundaries are proven")
	_assert(not bool(criteria["legacy_retention_gate_allows_removal"]), "legacy retention gate blocks abstraction maturity")
	_assert(not bool(criteria["replacement_generation_authority_proven"]), "replacement generation authority is not proven")
	_assert(not bool(criteria["direct_generated_world_chunk_host_adapters_proven"]), "direct GeneratedWorldChunk host adapters are not proven")
	_assert(not bool(criteria["non_godot_consumer_need_proven"]), "non-Godot consumer need is not proven")
	_assert(not bool(criteria["runenwerk_integration_pressure_proven"]), "Runenwerk integration pressure is not proven")
	_assert(review.is_valid(), "runtime abstraction review is valid")
	_assert(
		review.decision == RuntimeAbstractionReviewScript.DECISION_DEFER_NEW_RUNTIME_ABSTRACTIONS,
		"runtime abstraction review defers new abstractions"
	)
	_assert(not review.runtime_abstraction_allowed, "runtime abstraction is not allowed by current review")
	_assert(
		review.blocking_criteria_ids.has("legacy_retention_gate_allows_removal"),
		"review blocks on legacy retention gate"
	)
	_assert(
		review.blocking_criteria_ids.has("replacement_generation_authority_proven"),
		"review blocks on missing replacement generation authority"
	)
	_assert(
		review.blocking_criteria_ids.has("direct_generated_world_chunk_host_adapters_proven"),
		"review blocks on direct GeneratedWorldChunk host adapters"
	)
	_assert(
		review.blocking_criteria_ids.has("non_godot_consumer_need_proven"),
		"review blocks on missing non-Godot consumer need"
	)
	for guarded_symbol_id in RuntimeAbstractionReviewScript.default_guarded_symbol_ids():
		_assert(
			review.guarded_symbol_ids.has(guarded_symbol_id),
			"review guards %s" % guarded_symbol_id
		)
		_assert(
			review.deferred_scope.has(guarded_symbol_id),
			"review defers %s" % guarded_symbol_id
		)
	_assert(
		review.signature_hash() == review.duplicate_review().signature_hash(),
		"runtime abstraction review signature is deterministic"
	)
	_assert(
		review_data.get("product_type", "") == RuntimeAbstractionReviewScript.PRODUCT_TYPE,
		"runtime abstraction review dictionary is typed"
	)


func _data_product_contracts_stable() -> bool:
	return GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK == "generated_world_chunk" \
		and WorldSpace.domain_contract(WorldSpace.DOMAIN_CELL_GRID_2D).is_valid() \
		and not RuntimeAbstractionReviewScript.maturity_criteria_ids().is_empty()


func _host_adapter_boundaries_are_non_authoritative(
	visual_builder: RefCounted,
	collision_builder: RefCounted
) -> bool:
	var visual_contract: Dictionary = visual_builder.host_adapter_contract()
	var collision_contract: Dictionary = collision_builder.host_adapter_contract()
	return not bool(visual_contract.get("owns_generation_truth", true)) \
		and not bool(collision_contract.get("owns_generation_truth", true)) \
		and _array_has(visual_contract.get("consumes", PackedStringArray()), "GeneratedChunkData.formation_layers") \
		and _array_has(collision_contract.get("consumes", PackedStringArray()), "GeneratedChunkData.topology_layers.solid")


func _array_has(values: Variant, target: String) -> bool:
	if typeof(values) == TYPE_PACKED_STRING_ARRAY:
		var packed_values: PackedStringArray = values
		return packed_values.has(target)
	if typeof(values) == TYPE_ARRAY:
		var array_values: Array = values
		return array_values.has(target)
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_runtime_abstraction_review_smoke failed: %s" % message)
