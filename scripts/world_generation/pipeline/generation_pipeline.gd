extends RefCounted

class_name GenerationPipeline

const DEFAULT_PIPELINE_ID := "default_generation_pipeline"
const PIPELINE_CONTRACT_VERSION := 1

var pipeline_id: String = DEFAULT_PIPELINE_ID
var pipeline_version: int = PIPELINE_CONTRACT_VERSION
var stages: Array = []
var halt_on_stage_failure: bool = true


static func from_stages(
	p_stages: Array = [],
	p_pipeline_id: String = DEFAULT_PIPELINE_ID,
	p_pipeline_version: int = PIPELINE_CONTRACT_VERSION,
	p_halt_on_stage_failure: bool = true
) -> GenerationPipeline:
	var pipeline := GenerationPipeline.new()
	return pipeline.configure(
		p_pipeline_id,
		p_pipeline_version,
		p_stages,
		p_halt_on_stage_failure
	)


static func no_op() -> GenerationPipeline:
	return GenerationPipeline.from_stages([
		GenerationStage.from_parts("noop_diagnostic_stage", GenerationStage.CATEGORY_DIAGNOSTIC)
	])


func configure(
	p_pipeline_id: String = DEFAULT_PIPELINE_ID,
	p_pipeline_version: int = PIPELINE_CONTRACT_VERSION,
	p_stages: Array = [],
	p_halt_on_stage_failure: bool = true
) -> GenerationPipeline:
	pipeline_id = p_pipeline_id.strip_edges()
	if pipeline_id.is_empty():
		pipeline_id = DEFAULT_PIPELINE_ID
	pipeline_version = maxi(p_pipeline_version, 1)
	halt_on_stage_failure = p_halt_on_stage_failure
	stages = []
	for stage in p_stages:
		add_stage(stage)
	return self


func duplicate_pipeline() -> GenerationPipeline:
	var copied_stages: Array = []
	for stage in stages:
		if stage != null and stage.has_method("duplicate_stage"):
			copied_stages.append(stage.duplicate_stage())
	return GenerationPipeline.from_stages(
		copied_stages,
		pipeline_id,
		pipeline_version,
		halt_on_stage_failure
	)


func add_stage(stage: GenerationStage) -> void:
	if stage == null:
		return
	stages.append(stage)


func clear_stages() -> void:
	stages.clear()


func stage_count() -> int:
	return stages.size()


func run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext
) -> GenerationWorkingSet:
	var working_set := GenerationWorkingSet.from_snapshot_and_context(snapshot, context)
	working_set.set_diagnostic("pipeline_id", pipeline_id)
	working_set.set_diagnostic("pipeline_version", pipeline_version)
	working_set.set_diagnostic("stage_count", stages.size())
	var validation_start_us := Time.get_ticks_usec()

	if snapshot == null:
		working_set.add_validation_issue("missing_world_definition_snapshot")
		working_set.set_diagnostic("pipeline_validation_us", Time.get_ticks_usec() - validation_start_us)
		return working_set
	if context == null:
		working_set.add_validation_issue("missing_generation_context")
		working_set.set_diagnostic("pipeline_validation_us", Time.get_ticks_usec() - validation_start_us)
		return working_set
	if context.identity == null:
		working_set.add_validation_issue("missing_generated_chunk_identity")
		working_set.set_diagnostic("pipeline_validation_us", Time.get_ticks_usec() - validation_start_us)
		return working_set
	if not _context_matches_snapshot(snapshot, context):
		working_set.add_validation_issue("generation_context_snapshot_identity_mismatch")
		working_set.set_diagnostic("pipeline_validation_us", Time.get_ticks_usec() - validation_start_us)
		return working_set
	var snapshot_validation := WorldDefinitionValidator.validate_snapshot(snapshot)
	if not bool(snapshot_validation.get("valid", false)):
		for issue in snapshot_validation.get("issues", PackedStringArray()):
			working_set.add_validation_issue(String(issue))
		working_set.set_diagnostic("pipeline_validation_us", Time.get_ticks_usec() - validation_start_us)
		return working_set
	working_set.set_diagnostic("pipeline_validation_us", Time.get_ticks_usec() - validation_start_us)

	for index in range(stages.size()):
		var stage: GenerationStage = stages[index]
		if stage == null:
			var missing_result := GenerationStageResult.failed(
				"missing_stage_%s" % index,
				GenerationStage.CATEGORY_VALIDATION,
				"missing_generation_stage",
				index
			)
			working_set.record_stage_result(missing_result)
			if halt_on_stage_failure:
				break
			continue

		var result := stage.run(snapshot, context, working_set, index)
		working_set.record_stage_result(result)
		if result.is_failed() and halt_on_stage_failure:
			break

	working_set.set_diagnostic("completed_stage_count", working_set.stage_results.size())
	working_set.set_diagnostic("pipeline_signature_hash", signature_hash())
	return working_set


func run_from_definition_and_request(
	definition: WorldDefinition,
	request: ChunkGenerationRequest
) -> GenerationWorkingSet:
	if definition == null:
		var empty_set := GenerationWorkingSet.new()
		empty_set.add_validation_issue("missing_world_definition")
		return empty_set
	var snapshot := definition.compile_snapshot()
	if request == null:
		var missing_request_set := GenerationWorkingSet.from_snapshot_and_context(snapshot, null)
		missing_request_set.add_validation_issue("missing_chunk_generation_request")
		return missing_request_set
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	return run(snapshot, context)


func stage_report() -> Array:
	var report: Array = []
	for index in range(stages.size()):
		var stage: GenerationStage = stages[index]
		if stage == null:
			report.append({
				"stage_index": index,
				"stage_id": "",
				"stage_category": "",
				"enabled": false,
				"missing": true,
			})
		elif stage.has_method("to_dictionary"):
			report.append(stage.to_dictionary())
	return report


func to_dictionary() -> Dictionary:
	return {
		"product_type": "GenerationPipeline",
		"pipeline_id": pipeline_id,
		"pipeline_version": pipeline_version,
		"halt_on_stage_failure": halt_on_stage_failure,
		"stages": stage_report(),
		"signature_hash": signature_hash(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GenerationPipeline:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(pipeline_id))
	h = GeneratedChunkIdentity.mix_hash(h, pipeline_version)
	h = GeneratedChunkIdentity.mix_hash(h, 1 if halt_on_stage_failure else 0)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(stage_report()))
	return h


func _context_matches_snapshot(snapshot: WorldDefinitionSnapshot, context: GenerationContext) -> bool:
	if snapshot == null or context == null or context.identity == null:
		return false
	return context.identity.world_definition_id == snapshot.world_definition_id \
		and context.identity.world_definition_version == snapshot.world_definition_version \
		and context.identity.world_definition_hash == snapshot.world_definition_hash \
		and context.identity.generation_settings_hash == snapshot.generation_settings_hash
