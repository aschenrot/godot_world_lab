extends RefCounted

class_name GenerationStage

const CATEGORY_FIELD := "field"
const CATEGORY_LAYER := "layer"
const CATEGORY_FEATURE := "feature"
const CATEGORY_CONTINUITY := "continuity"
const CATEGORY_CANDIDATE := "candidate"
const CATEGORY_PROJECTION := "projection"
const CATEGORY_VALIDATION := "validation"
const CATEGORY_DIAGNOSTIC := "diagnostic"

var stage_id: String = "noop_stage"
var stage_category: String = CATEGORY_DIAGNOSTIC
var enabled: bool = true
var stage_settings: Dictionary = {}


static func from_parts(
	p_stage_id: String,
	p_stage_category: String = CATEGORY_DIAGNOSTIC,
	p_enabled: bool = true,
	p_stage_settings: Dictionary = {}
) -> GenerationStage:
	var stage := GenerationStage.new()
	return stage.configure(p_stage_id, p_stage_category, p_enabled, p_stage_settings)


func configure(
	p_stage_id: String,
	p_stage_category: String = CATEGORY_DIAGNOSTIC,
	p_enabled: bool = true,
	p_stage_settings: Dictionary = {}
) -> GenerationStage:
	stage_id = p_stage_id.strip_edges()
	if stage_id.is_empty():
		stage_id = "noop_stage"
	stage_category = _normalized_category(p_stage_category)
	enabled = p_enabled
	stage_settings = p_stage_settings.duplicate(true)
	return self


func duplicate_stage() -> GenerationStage:
	return GenerationStage.from_parts(stage_id, stage_category, enabled, stage_settings)


func can_run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet
) -> bool:
	return enabled and snapshot != null and context != null and working_set != null


func run(
	snapshot: WorldDefinitionSnapshot,
	context: GenerationContext,
	working_set: GenerationWorkingSet,
	stage_index: int = -1
) -> GenerationStageResult:
	if not can_run(snapshot, context, working_set):
		return GenerationStageResult.skipped(
			stage_id,
			stage_category,
			"stage_disabled_or_missing_generation_inputs",
			stage_index
		)

	var capture_working_set_signatures := _should_capture_working_set_signatures(context)
	var before_signature := working_set.signature_hash() if capture_working_set_signatures else 0
	var result := _run(snapshot, context, working_set)
	if result == null:
		result = GenerationStageResult.success(stage_id, stage_category, stage_index)

	if result.stage_id.strip_edges().is_empty():
		result.stage_id = stage_id
	if result.stage_category.strip_edges().is_empty():
		result.stage_category = stage_category
	result.stage_index = stage_index
	if capture_working_set_signatures:
		result.mark_working_set_signatures(before_signature, working_set.signature_hash())
	return result


func _run(
	_snapshot: WorldDefinitionSnapshot,
	_context: GenerationContext,
	_working_set: GenerationWorkingSet
) -> GenerationStageResult:
	return GenerationStageResult.success(stage_id, stage_category)


func to_dictionary() -> Dictionary:
	return {
		"product_type": "GenerationStage",
		"stage_id": stage_id,
		"stage_category": stage_category,
		"enabled": enabled,
		"stage_settings": stage_settings.duplicate(true),
		"signature_hash": signature_hash(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GenerationStage:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(stage_id))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(stage_category))
	h = GeneratedChunkIdentity.mix_hash(h, 1 if enabled else 0)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(stage_settings))
	return h


static func supported_categories() -> PackedStringArray:
	return PackedStringArray([
		CATEGORY_FIELD,
		CATEGORY_LAYER,
		CATEGORY_FEATURE,
		CATEGORY_CONTINUITY,
		CATEGORY_CANDIDATE,
		CATEGORY_PROJECTION,
		CATEGORY_VALIDATION,
		CATEGORY_DIAGNOSTIC,
	])


static func is_supported_category(value: String) -> bool:
	return supported_categories().has(value.strip_edges())


static func _normalized_category(value: String) -> String:
	var normalized := value.strip_edges()
	if is_supported_category(normalized):
		return normalized
	return CATEGORY_DIAGNOSTIC


func _should_capture_working_set_signatures(context: GenerationContext) -> bool:
	if context == null:
		return false
	return context.has_debug_flag("diagnostics_enabled") \
		or context.has_debug_flag("profiling_enabled") \
		or context.has_debug_flag("diagnostics_provenance_smoke")
