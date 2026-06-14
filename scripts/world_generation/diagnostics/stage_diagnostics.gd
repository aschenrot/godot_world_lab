extends RefCounted

class_name StageDiagnostics

const PRODUCT_TYPE := "StageDiagnostics"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/diagnostics/stage_diagnostics.gd"

var stage_id: String = ""
var stage_category: String = ""
var stage_index: int = -1
var status: String = ""
var input_summary: Dictionary = {}
var output_summary: Dictionary = {}
var emitted_counts: Dictionary = {}
var diagnostics: Dictionary = {}
var warnings: PackedStringArray = PackedStringArray()
var validation_errors: PackedStringArray = PackedStringArray()
var deterministic_signature_contribution: int = 0
var metadata: Dictionary = {}


static func from_parts(
	p_stage_id: String,
	p_stage_category: String,
	p_stage_index: int,
	p_status: String,
	p_input_summary: Dictionary = {},
	p_output_summary: Dictionary = {},
	p_emitted_counts: Dictionary = {},
	p_diagnostics: Dictionary = {},
	p_warnings: PackedStringArray = PackedStringArray(),
	p_validation_errors: PackedStringArray = PackedStringArray(),
	p_deterministic_signature_contribution: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var stage_diagnostics: RefCounted = load(SELF_SCRIPT_PATH).new()
	return stage_diagnostics.configure(
		p_stage_id,
		p_stage_category,
		p_stage_index,
		p_status,
		p_input_summary,
		p_output_summary,
		p_emitted_counts,
		p_diagnostics,
		p_warnings,
		p_validation_errors,
		p_deterministic_signature_contribution,
		p_metadata
	)


static func from_stage_result(stage_result: Dictionary) -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		String(stage_result.get("stage_id", "")),
		String(stage_result.get("stage_category", "")),
		int(stage_result.get("stage_index", -1)),
		String(stage_result.get("status", "")),
		{"working_set_signature": int(stage_result.get("working_set_signature_before", 0))},
		{"working_set_signature": int(stage_result.get("working_set_signature_after", 0))},
		stage_result.get("emitted_fact_counts", {}),
		stage_result.get("diagnostics", {}),
		_to_packed_string_array(stage_result.get("notes", PackedStringArray())),
		_to_packed_string_array(stage_result.get("issues", PackedStringArray())),
		int(stage_result.get("signature_hash", 0)),
		{"source_product_type": stage_result.get("product_type", "GenerationStageResult")}
	)


func configure(
	p_stage_id: String,
	p_stage_category: String,
	p_stage_index: int,
	p_status: String,
	p_input_summary: Dictionary = {},
	p_output_summary: Dictionary = {},
	p_emitted_counts: Dictionary = {},
	p_diagnostics: Dictionary = {},
	p_warnings: PackedStringArray = PackedStringArray(),
	p_validation_errors: PackedStringArray = PackedStringArray(),
	p_deterministic_signature_contribution: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	stage_id = p_stage_id.strip_edges()
	stage_category = p_stage_category.strip_edges()
	stage_index = p_stage_index
	status = p_status.strip_edges()
	input_summary = p_input_summary.duplicate(true)
	output_summary = p_output_summary.duplicate(true)
	emitted_counts = p_emitted_counts.duplicate(true)
	diagnostics = p_diagnostics.duplicate(true)
	warnings = p_warnings.duplicate()
	validation_errors = p_validation_errors.duplicate()
	deterministic_signature_contribution = p_deterministic_signature_contribution
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_diagnostics() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		stage_id,
		stage_category,
		stage_index,
		status,
		input_summary,
		output_summary,
		emitted_counts,
		diagnostics,
		warnings,
		validation_errors,
		deterministic_signature_contribution,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("StageDiagnostics:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_report_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not stage_id.is_empty() \
		and not stage_category.is_empty() \
		and not status.is_empty() \
		and not _contains_runtime_object(input_summary) \
		and not _contains_runtime_object(output_summary) \
		and not _contains_runtime_object(emitted_counts) \
		and not _contains_runtime_object(diagnostics) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"stage_id": stage_id,
		"stage_category": stage_category,
		"stage_index": stage_index,
		"status": status,
		"input_summary": input_summary.duplicate(true),
		"output_summary": output_summary.duplicate(true),
		"emitted_counts": emitted_counts.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
		"warnings": warnings.duplicate(),
		"validation_errors": validation_errors.duplicate(),
		"deterministic_signature_contribution": deterministic_signature_contribution,
		"metadata": metadata.duplicate(true),
	}


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	var result := PackedStringArray()
	if typeof(value) != TYPE_ARRAY:
		return result
	var array_value: Array = value
	for item in array_value:
		result.append(String(item))
	return result


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
