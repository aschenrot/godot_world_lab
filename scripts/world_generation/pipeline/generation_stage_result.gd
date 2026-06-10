extends RefCounted

class_name GenerationStageResult

const STATUS_SUCCESS := "success"
const STATUS_SKIPPED := "skipped"
const STATUS_FAILED := "failed"

var stage_id: String = ""
var stage_category: String = ""
var stage_index: int = -1
var status: String = STATUS_SUCCESS
var emitted_fact_counts: Dictionary = {}
var diagnostics: Dictionary = {}
var issues: PackedStringArray = PackedStringArray()
var notes: PackedStringArray = PackedStringArray()
var working_set_signature_before: int = 0
var working_set_signature_after: int = 0


static func success(
	p_stage_id: String,
	p_stage_category: String,
	p_stage_index: int = -1
) -> GenerationStageResult:
	return GenerationStageResult.new().configure(
		p_stage_id,
		p_stage_category,
		p_stage_index,
		STATUS_SUCCESS
	)


static func skipped(
	p_stage_id: String,
	p_stage_category: String,
	note: String,
	p_stage_index: int = -1
) -> GenerationStageResult:
	var result := GenerationStageResult.new().configure(
		p_stage_id,
		p_stage_category,
		p_stage_index,
		STATUS_SKIPPED
	)
	if not note.strip_edges().is_empty():
		result.notes.append(note.strip_edges())
	return result


static func failed(
	p_stage_id: String,
	p_stage_category: String,
	issue: String,
	p_stage_index: int = -1
) -> GenerationStageResult:
	var result := GenerationStageResult.new().configure(
		p_stage_id,
		p_stage_category,
		p_stage_index,
		STATUS_FAILED
	)
	if not issue.strip_edges().is_empty():
		result.issues.append(issue.strip_edges())
	return result


func configure(
	p_stage_id: String,
	p_stage_category: String,
	p_stage_index: int,
	p_status: String
) -> GenerationStageResult:
	stage_id = p_stage_id.strip_edges()
	stage_category = p_stage_category.strip_edges()
	stage_index = p_stage_index
	status = _normalized_status(p_status)
	emitted_fact_counts = {}
	diagnostics = {}
	issues = PackedStringArray()
	notes = PackedStringArray()
	working_set_signature_before = 0
	working_set_signature_after = 0
	return self


func duplicate_result() -> GenerationStageResult:
	var result := GenerationStageResult.new().configure(stage_id, stage_category, stage_index, status)
	result.emitted_fact_counts = emitted_fact_counts.duplicate(true)
	result.diagnostics = diagnostics.duplicate(true)
	result.issues = issues.duplicate()
	result.notes = notes.duplicate()
	result.working_set_signature_before = working_set_signature_before
	result.working_set_signature_after = working_set_signature_after
	return result


func mark_working_set_signatures(before_signature: int, after_signature: int) -> GenerationStageResult:
	working_set_signature_before = before_signature
	working_set_signature_after = after_signature
	return self


func add_issue(issue: String) -> GenerationStageResult:
	var value := issue.strip_edges()
	if not value.is_empty():
		issues.append(value)
		status = STATUS_FAILED
	return self


func add_note(note: String) -> GenerationStageResult:
	var value := note.strip_edges()
	if not value.is_empty():
		notes.append(value)
	return self


func set_diagnostic(key: String, value: Variant) -> GenerationStageResult:
	var normalized_key := key.strip_edges()
	if normalized_key.is_empty():
		return self
	diagnostics[normalized_key] = value
	return self


func increment_emitted_count(kind: String, amount: int = 1) -> GenerationStageResult:
	var normalized_kind := kind.strip_edges()
	if normalized_kind.is_empty():
		return self
	emitted_fact_counts[normalized_kind] = int(emitted_fact_counts.get(normalized_kind, 0)) + amount
	return self


func is_success() -> bool:
	return status == STATUS_SUCCESS


func is_skipped() -> bool:
	return status == STATUS_SKIPPED


func is_failed() -> bool:
	return status == STATUS_FAILED


func to_dictionary() -> Dictionary:
	return {
		"product_type": "GenerationStageResult",
		"stage_id": stage_id,
		"stage_category": stage_category,
		"stage_index": stage_index,
		"status": status,
		"emitted_fact_counts": emitted_fact_counts.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
		"issues": issues.duplicate(),
		"notes": notes.duplicate(),
		"working_set_signature_before": working_set_signature_before,
		"working_set_signature_after": working_set_signature_after,
		"signature_hash": signature_hash(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GenerationStageResult:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(stage_id))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(stage_category))
	h = GeneratedChunkIdentity.mix_hash(h, stage_index)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(status))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(emitted_fact_counts))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(diagnostics))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(issues))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(notes))
	h = GeneratedChunkIdentity.mix_hash(h, working_set_signature_before)
	h = GeneratedChunkIdentity.mix_hash(h, working_set_signature_after)
	return h


static func _normalized_status(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == STATUS_SKIPPED or normalized == STATUS_FAILED:
		return normalized
	return STATUS_SUCCESS
