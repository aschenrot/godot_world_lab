extends SceneTree

const WorldDefinitionProfileLibraryScript := preload("res://scripts/world_generation/definition/world_definition_profile_library.gd")

var failed: bool = false


func _initialize() -> void:
	test_profile_definitions_are_valid_and_not_parameter_only_variants()
	test_profile_snapshots_produce_distinct_identities_for_same_chunk()
	test_profiles_run_through_same_pipeline_product_and_diagnostics_contracts()
	quit(1 if failed else 0)


func test_profile_definitions_are_valid_and_not_parameter_only_variants() -> void:
	var surface_definition: WorldDefinition = WorldDefinitionProfileLibraryScript.surface_material_chunk_definition()
	var navigation_definition: WorldDefinition = WorldDefinitionProfileLibraryScript.navigation_topology_survey_definition()
	var surface_validation: Dictionary = surface_definition.validate_definition()
	var navigation_validation: Dictionary = navigation_definition.validate_definition()
	var proof_summary: Dictionary = WorldDefinitionProfileLibraryScript.proof_summary()

	_assert(bool(surface_validation.get("valid", false)), "surface material profile definition validates")
	_assert(bool(navigation_validation.get("valid", false)), "navigation survey profile definition validates")
	_assert(
		surface_definition.generation_settings_hash() == navigation_definition.generation_settings_hash(),
		"profile definitions intentionally share generation settings"
	)
	_assert(
		surface_definition.contract_hash() != navigation_definition.contract_hash(),
		"profile definitions differ by contract hash"
	)
	_assert(
		surface_definition.definition_hash() != navigation_definition.definition_hash(),
		"profile definitions differ by definition hash"
	)
	_assert(
		bool(proof_summary.get("same_generation_settings_hash", false)),
		"proof summary records same generation settings hash"
	)
	_assert(
		bool(proof_summary.get("different_contract_hash", false)),
		"proof summary records different contract hash"
	)
	_assert(
		_variant_signature(surface_definition.generation_settings)
		== _variant_signature(navigation_definition.generation_settings),
		"profile generation settings dictionaries are identical"
	)
	_assert(
		_variant_signature(surface_definition.layer_schema_ids)
		!= _variant_signature(navigation_definition.layer_schema_ids),
		"profile layer contracts differ"
	)
	_assert(
		_variant_signature(surface_definition.feature_schema_ids)
		!= _variant_signature(navigation_definition.feature_schema_ids),
		"profile feature contracts differ"
	)
	_assert(
		_variant_signature(surface_definition.continuity_policy_ids)
		!= _variant_signature(navigation_definition.continuity_policy_ids),
		"profile continuity contracts differ"
	)
	_assert(
		_variant_signature(surface_definition.requested_product_set)
		!= _variant_signature(navigation_definition.requested_product_set),
		"profile requested product contracts differ"
	)


func test_profile_snapshots_produce_distinct_identities_for_same_chunk() -> void:
	var surface_snapshot := WorldDefinitionProfileLibraryScript.surface_material_chunk_definition().compile_snapshot()
	var navigation_snapshot := WorldDefinitionProfileLibraryScript.navigation_topology_survey_definition().compile_snapshot()
	var chunk_coord := Vector3i(2, 0, -2)
	var surface_identity := surface_snapshot.identity_for_chunk(chunk_coord)
	var navigation_identity := navigation_snapshot.identity_for_chunk(chunk_coord)

	_assert(
		surface_snapshot.generation_settings_hash == navigation_snapshot.generation_settings_hash,
		"profile snapshots keep identical generation settings hash"
	)
	_assert(
		surface_snapshot.world_definition_hash != navigation_snapshot.world_definition_hash,
		"profile snapshots have different world definition hashes"
	)
	_assert(
		not surface_identity.same_identity(navigation_identity),
		"profile chunk identities differ for same chunk"
	)
	_assert(
		surface_identity.cache_key() != navigation_identity.cache_key(),
		"profile chunk cache keys differ for same chunk"
	)


func test_profiles_run_through_same_pipeline_product_and_diagnostics_contracts() -> void:
	var surface_chunk := _run_definition_chunk(
		WorldDefinitionProfileLibraryScript.surface_material_chunk_definition(),
		Vector3i(1, 0, -1)
	)
	var navigation_chunk := _run_definition_chunk(
		WorldDefinitionProfileLibraryScript.navigation_topology_survey_definition(),
		Vector3i(1, 0, -1)
	)
	var surface_report: Dictionary = surface_chunk.diagnostics_report()
	var navigation_report: Dictionary = navigation_chunk.diagnostics_report()

	_assert(not surface_chunk.has_validation_errors(), "surface profile chunk has no validation errors")
	_assert(not navigation_chunk.has_validation_errors(), "navigation profile chunk has no validation errors")
	_assert(
		surface_chunk.identity.world_definition_id == WorldDefinitionProfileLibraryScript.PROFILE_SURFACE_MATERIAL,
		"surface profile chunk carries surface definition id"
	)
	_assert(
		navigation_chunk.identity.world_definition_id == WorldDefinitionProfileLibraryScript.PROFILE_NAVIGATION_SURVEY,
		"navigation profile chunk carries navigation definition id"
	)
	_assert(
		surface_chunk.stage_results[0].get("stage_id", "") == navigation_chunk.stage_results[0].get("stage_id", ""),
		"profile chunks use the same pipeline stage interface"
	)
	_assert(
		surface_chunk.to_dictionary().get("product_type", "") == navigation_chunk.to_dictionary().get("product_type", ""),
		"profile chunks use the same generated product model"
	)
	_assert(
		surface_report.get("product_type", "") == navigation_report.get("product_type", ""),
		"profile chunks use the same diagnostics model"
	)
	_assert(
		surface_chunk.identity.generation_settings_hash == navigation_chunk.identity.generation_settings_hash,
		"profile chunks keep same settings hash while differing by definition contract"
	)
	_assert(
		surface_chunk.identity.world_definition_hash != navigation_chunk.identity.world_definition_hash,
		"profile chunk identities differ by definition hash"
	)


func _run_definition_chunk(definition: WorldDefinition, chunk_coord: Vector3i) -> GeneratedWorldChunk:
	var provider := ProfileProvider.new()
	provider.definition = definition
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		16,
		1,
		snapshot.requested_product_set,
		{"definition_diversity_smoke": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var pipeline := GenerationPipeline.from_stages([
		LegacyChunkGenerationStage.from_provider(provider)
	])
	var working_set := pipeline.run(snapshot, context)
	provider.free()
	return GeneratedWorldChunk.from_working_set(working_set)


class ProfileProvider:
	extends Node

	var definition: WorldDefinition = null
	var LegacyGeneratorScript := preload("res://scripts/world_generation/legacy/legacy_chunk_generator.gd")

	func _generate_legacy_chunk_generation_result(chunk_coord: Vector3i) -> Dictionary:
		return LegacyGeneratorScript.from_settings(definition.generation_settings).generate_chunk_generation_result(chunk_coord)


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_definition_diversity_smoke failed: %s" % message)
