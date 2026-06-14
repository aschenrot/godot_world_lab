extends SceneTree

const CountingProviderScript := preload("res://tests/world_generation_migration_gate_counting_provider.gd")
const StageDiagnosticsScript := preload("res://scripts/world_generation/diagnostics/stage_diagnostics.gd")
const GenerationDiagnosticsScript := preload("res://scripts/world_generation/diagnostics/generation_diagnostics.gd")
const GeneratedChunkReportScript := preload("res://scripts/world_generation/diagnostics/generated_chunk_report.gd")
const LegacyFormationProductStageScript := preload("res://scripts/world_generation/pipeline/stages/legacy_formation_product_stage.gd")

var failed: bool = false


func _initialize() -> void:
	test_stage_diagnostics_from_stage_result_reports_status_counts_and_signatures()
	test_generation_diagnostics_reports_identity_counts_and_provenance()
	test_generated_chunk_report_exposes_human_readable_summary()
	test_diagnostics_signatures_are_deterministic_for_same_generated_products()
	test_generated_truth_signature_ignores_report_payloads()
	test_product_signature_changes_when_generated_product_changes()
	quit(1 if failed else 0)


func test_stage_diagnostics_from_stage_result_reports_status_counts_and_signatures() -> void:
	var provider: Node = _configured_provider()
	var world_chunk := _run_world_chunk_for_provider(provider, Vector3i(1, 0, -1))
	var stage_result: Dictionary = world_chunk.stage_results[0]
	var stage_diagnostics: RefCounted = StageDiagnosticsScript.from_stage_result(stage_result)
	var stage_diagnostics_data: Dictionary = stage_diagnostics.to_dictionary()

	_assert(stage_diagnostics.is_valid(), "StageDiagnostics from stage result is valid")
	_assert(
		stage_diagnostics_data.get("stage_id", "") == LegacyChunkGenerationStage.STAGE_ID,
		"StageDiagnostics keeps stage id"
	)
	_assert(stage_diagnostics_data.get("status", "") == GenerationStageResult.STATUS_SUCCESS, "StageDiagnostics keeps stage status")
	_assert(
		int(stage_diagnostics_data.get("emitted_counts", {}).get("world_feature", -1)) > 0,
		"StageDiagnostics reports emitted world feature count"
	)
	_assert(
		int(stage_diagnostics_data.get("input_summary", {}).get("working_set_signature", 0)) != 0,
		"StageDiagnostics reports input working-set signature"
	)
	_assert(
		int(stage_diagnostics_data.get("output_summary", {}).get("working_set_signature", 0)) != 0,
		"StageDiagnostics reports output working-set signature"
	)
	_assert(
		int(stage_diagnostics_data.get("deterministic_signature_contribution", 0))
		== int(stage_result.get("signature_hash", -1)),
		"StageDiagnostics preserves deterministic signature contribution"
	)
	provider.free()


func test_generation_diagnostics_reports_identity_counts_and_provenance() -> void:
	var provider: Node = _configured_provider()
	var world_chunk := _run_world_chunk_for_provider(provider, Vector3i(2, 0, -2))
	var generation_diagnostics: RefCounted = GenerationDiagnosticsScript.from_world_chunk(world_chunk)
	var diagnostics_data: Dictionary = generation_diagnostics.to_dictionary()
	var definition_identity: Dictionary = diagnostics_data.get("definition_identity", {})
	var emitted_counts: Dictionary = diagnostics_data.get("emitted_counts", {})
	var product_counts: Dictionary = diagnostics_data.get("product_counts", {})
	var product_signatures: Dictionary = diagnostics_data.get("product_signatures", {})
	var provenance: Dictionary = diagnostics_data.get("provenance", {})

	_assert(generation_diagnostics.is_valid(), "GenerationDiagnostics from world chunk is valid")
	_assert(
		definition_identity.get("world_definition_id", "") == world_chunk.identity.world_definition_id,
		"GenerationDiagnostics reports definition identity"
	)
	_assert(
		int(emitted_counts.get("world_layer", 0)) >= 1,
		"GenerationDiagnostics reports emitted layer count"
	)
	_assert(
		int(emitted_counts.get("world_feature", 0)) == int(product_counts.get("world_feature", -1)),
		"GenerationDiagnostics emitted feature count matches feature products"
	)
	_assert(
		int(emitted_counts.get("continuity_fact", 0)) == int(product_counts.get("continuity_fact", -1)),
		"GenerationDiagnostics emitted continuity fact count matches products"
	)
	_assert(
		int(emitted_counts.get("placement_candidate", 0)) == int(product_counts.get("placement_candidate", -1)),
		"GenerationDiagnostics emitted placement candidate count matches products"
	)
	_assert(
		int(emitted_counts.get("formation_product", 0)) == int(product_counts.get("formation_product", -1)),
		"GenerationDiagnostics emitted formation product count matches products"
	)
	_assert(
		int(product_signatures.get("generated_world_chunk", 0)) == world_chunk.signature_hash(),
		"GenerationDiagnostics reports generated world chunk signature"
	)
	_assert(
		int(product_signatures.get("identity", 0)) == world_chunk.identity.signature_hash(),
		"GenerationDiagnostics reports chunk identity signature"
	)
	_assert(
		provenance.get("pipeline_id", "") == GenerationPipeline.DEFAULT_PIPELINE_ID,
		"GenerationDiagnostics provenance reports pipeline id"
	)
	_assert(
		int(provenance.get("completed_stage_count", 0)) == world_chunk.stage_results.size(),
		"GenerationDiagnostics provenance reports completed stage count"
	)
	provider.free()


func test_generated_chunk_report_exposes_human_readable_summary() -> void:
	var provider: Node = _configured_provider()
	var world_chunk := _run_world_chunk_for_provider(provider, Vector3i(-1, 0, 1))
	var report: RefCounted = GeneratedChunkReportScript.from_world_chunk(world_chunk)
	var report_data: Dictionary = report.to_dictionary()
	var summary: Dictionary = report_data.get("summary", {})
	var human_readable: PackedStringArray = report_data.get("human_readable_diagnostics", PackedStringArray())
	var chunk_method_report: Dictionary = world_chunk.generated_chunk_report()

	_assert(report.is_valid(), "GeneratedChunkReport from world chunk is valid")
	_assert(
		summary.get("world_definition_id", "") == world_chunk.identity.world_definition_id,
		"GeneratedChunkReport summary keeps world definition id"
	)
	_assert(
		int(summary.get("product_signature", 0)) == world_chunk.signature_hash(),
		"GeneratedChunkReport summary reports product signature"
	)
	_assert(human_readable.size() >= 3, "GeneratedChunkReport exposes human-readable diagnostics")
	_assert(
		chunk_method_report.get("product_type", "") == GeneratedChunkReportScript.PRODUCT_TYPE,
		"GeneratedWorldChunk exposes generated chunk report helper"
	)
	provider.free()


func test_diagnostics_signatures_are_deterministic_for_same_generated_products() -> void:
	var provider_a: Node = _configured_provider()
	var provider_b: Node = _configured_provider()
	var chunk_coord := Vector3i(0, 0, 0)
	var world_chunk_a := _run_world_chunk_for_provider(provider_a, chunk_coord)
	var world_chunk_b := _run_world_chunk_for_provider(provider_b, chunk_coord)
	var diagnostics_a: Dictionary = world_chunk_a.diagnostics_report()
	var diagnostics_b: Dictionary = world_chunk_b.diagnostics_report()
	var report_a: Dictionary = world_chunk_a.generated_chunk_report()
	var report_b: Dictionary = world_chunk_b.generated_chunk_report()

	_assert(
		world_chunk_a.signature_hash() == world_chunk_b.signature_hash(),
		"GeneratedWorldChunk signature is deterministic for same generated products"
	)
	_assert(
		_variant_signature(diagnostics_a.get("product_signatures", {}))
		== _variant_signature(diagnostics_b.get("product_signatures", {})),
		"GenerationDiagnostics product signature map is deterministic"
	)
	_assert(
		int(diagnostics_a.get("signature_hash", 0)) == int(diagnostics_b.get("signature_hash", -1)),
		"GenerationDiagnostics signature is deterministic"
	)
	_assert(
		int(report_a.get("signature_hash", 0)) == int(report_b.get("signature_hash", -1)),
		"GeneratedChunkReport signature is deterministic"
	)
	provider_a.free()
	provider_b.free()


func test_generated_truth_signature_ignores_report_payloads() -> void:
	var provider: Node = _configured_provider()
	var session: RefCounted = provider._world_generation_session()
	var chunk_coord := Vector3i(-2, 0, 2)
	var with_stage_results: GeneratedWorldChunk = session.generate_world_chunk(
		chunk_coord,
		true,
		true,
		{"diagnostics_provenance_smoke": true}
	)
	var without_stage_results: GeneratedWorldChunk = session.generate_world_chunk(
		chunk_coord,
		true,
		false,
		{"diagnostics_provenance_smoke": true}
	)

	_assert(with_stage_results.stage_results.size() > 0, "reported chunk includes stage results")
	_assert(without_stage_results.stage_results.is_empty(), "unreported chunk omits stage results")
	_assert(
		with_stage_results.signature_hash() == without_stage_results.signature_hash(),
		"GeneratedWorldChunk generated-truth signature ignores report payloads"
	)
	_assert(
		with_stage_results.report_signature_hash() != without_stage_results.report_signature_hash(),
		"GeneratedWorldChunk report signature changes when report payloads change"
	)
	provider.free()


func test_product_signature_changes_when_generated_product_changes() -> void:
	var provider: Node = _configured_provider()
	var world_chunk := _run_world_chunk_for_provider(provider, Vector3i(3, 0, -3))
	var mutated_chunk := world_chunk.duplicate_chunk()
	var original_signatures: Dictionary = world_chunk.product_signature_map()

	var feature_set: Dictionary = mutated_chunk.world_features.get(GeneratedWorldChunk.WORLD_FEATURE_SET_KEY, {})
	var features: Dictionary = feature_set.get("features", {})
	var feature_ids: PackedStringArray = feature_set.get("feature_ids", PackedStringArray())
	if feature_ids.size() > 0:
		var first_feature_id := feature_ids[0]
		var feature: Dictionary = features.get(first_feature_id, {})
		var metadata: Dictionary = feature.get("metadata", {})
		metadata["identity_smoke_mutation"] = true
		feature["metadata"] = metadata
		features[first_feature_id] = feature
		feature_set["features"] = features
		mutated_chunk.world_features[GeneratedWorldChunk.WORLD_FEATURE_SET_KEY] = feature_set
	else:
		mutated_chunk.world_features["identity_smoke_mutation"] = true

	var mutated_signatures: Dictionary = mutated_chunk.product_signature_map()
	var mutated_diagnostics: Dictionary = mutated_chunk.diagnostics_report()

	_assert(
		int(original_signatures.get("generated_world_chunk", 0))
		!= int(mutated_signatures.get("generated_world_chunk", 0)),
		"GeneratedWorldChunk product signature changes when generated product data changes"
	)
	_assert(
		int(original_signatures.get("world_features", 0))
		!= int(mutated_signatures.get("world_features", 0)),
		"world_features product signature changes when feature product data changes"
	)
	_assert(
		int(mutated_diagnostics.get("product_signature", 0)) == mutated_chunk.signature_hash(),
		"GenerationDiagnostics reports changed product signature"
	)
	provider.free()


func _run_world_chunk_for_provider(provider: Node, chunk_coord: Vector3i) -> GeneratedWorldChunk:
	var definition: WorldDefinition = provider._world_definition_for_generation()
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		16,
		1,
		snapshot.requested_product_set,
		{"diagnostics_provenance_smoke": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var pipeline := GenerationPipeline.from_stages([
		LegacyChunkGenerationStage.from_provider(provider),
		LegacyFormationProductStageScript.from_session(provider)
	])
	var working_set := pipeline.run(snapshot, context)
	return GeneratedWorldChunk.from_working_set(working_set)


func _configured_provider() -> Node:
	var provider: Node = CountingProviderScript.new()
	provider.chunk_size_cells = 16
	provider.generator_version = 7
	provider.world_seed = 42
	provider.wall_threshold_percent = 34
	provider.debug_force_chunk_border = false
	provider.smoothing_passes = 1
	provider.room_attempts = 3
	provider.room_min_size = 3
	provider.room_max_size = 6
	provider.terrain_noise_frequency = 0.065
	provider.liquid_noise_frequency = 0.045
	provider.solid_noise_frequency = 0.09
	provider.liquid_threshold_percent = 35
	provider.target_walkable_min_percent = 70
	provider.target_walkable_max_percent = 80
	provider.liquid_blocks_movement = true
	provider.debug_generation_markers_enabled = true
	provider.use_chunk_cache = false
	return provider


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_diagnostics_provenance_smoke failed: %s" % message)
