extends RefCounted

class_name GeneratedChunkReport

const PRODUCT_TYPE := "GeneratedChunkReport"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/diagnostics/generated_chunk_report.gd"
const GenerationDiagnosticsScript := preload("res://scripts/world_generation/diagnostics/generation_diagnostics.gd")

var generation_diagnostics: Dictionary = {}
var summary: Dictionary = {}
var human_readable_diagnostics: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func from_parts(
	p_generation_diagnostics: Dictionary = {},
	p_summary: Dictionary = {},
	p_human_readable_diagnostics: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	var report: RefCounted = load(SELF_SCRIPT_PATH).new()
	return report.configure(
		p_generation_diagnostics,
		p_summary,
		p_human_readable_diagnostics,
		p_metadata
	)


static func from_world_chunk(world_chunk: Variant) -> RefCounted:
	var next_generation_diagnostics: Dictionary = GenerationDiagnosticsScript.from_world_chunk(
		world_chunk
	).to_dictionary()
	return load(SELF_SCRIPT_PATH).from_parts(
		next_generation_diagnostics,
		_summary_from_diagnostics(next_generation_diagnostics),
		_human_readable_from_diagnostics(next_generation_diagnostics),
		{"source_product_type": world_chunk.PRODUCT_TYPE if world_chunk != null else ""}
	)


func configure(
	p_generation_diagnostics: Dictionary = {},
	p_summary: Dictionary = {},
	p_human_readable_diagnostics: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	generation_diagnostics = p_generation_diagnostics.duplicate(true)
	summary = p_summary.duplicate(true)
	human_readable_diagnostics = p_human_readable_diagnostics.duplicate()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_report() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		generation_diagnostics,
		summary,
		human_readable_diagnostics,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GeneratedChunkReport:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_report_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return generation_diagnostics.get("product_type", "") == GenerationDiagnosticsScript.PRODUCT_TYPE \
		and not _contains_runtime_object(generation_diagnostics) \
		and not _contains_runtime_object(summary) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"generation_diagnostics": generation_diagnostics.duplicate(true),
		"summary": summary.duplicate(true),
		"human_readable_diagnostics": human_readable_diagnostics.duplicate(),
		"metadata": metadata.duplicate(true),
	}


static func _summary_from_diagnostics(diagnostics_data: Dictionary) -> Dictionary:
	var definition_identity: Dictionary = diagnostics_data.get("definition_identity", {})
	var emitted_counts: Dictionary = diagnostics_data.get("emitted_counts", {})
	var product_counts: Dictionary = diagnostics_data.get("product_counts", {})
	return {
		"world_definition_id": definition_identity.get("world_definition_id", ""),
		"world_definition_version": definition_identity.get("world_definition_version", 0),
		"chunk_coord": definition_identity.get("chunk_coord", Vector3i.ZERO),
		"stage_count": diagnostics_data.get("stage_diagnostics", []).size(),
		"validation_error_count": diagnostics_data.get("validation_errors", PackedStringArray()).size(),
		"warning_count": diagnostics_data.get("warnings", PackedStringArray()).size(),
		"product_signature": diagnostics_data.get("product_signature", 0),
		"emitted_counts": emitted_counts.duplicate(true),
		"product_counts": product_counts.duplicate(true),
	}


static func _human_readable_from_diagnostics(diagnostics_data: Dictionary) -> PackedStringArray:
	var summary_lines := PackedStringArray()
	var summary_data := _summary_from_diagnostics(diagnostics_data)
	summary_lines.append("world=%s v%s chunk=%s" % [
		summary_data.get("world_definition_id", ""),
		summary_data.get("world_definition_version", 0),
		summary_data.get("chunk_coord", Vector3i.ZERO),
	])
	summary_lines.append("stages=%s validation_errors=%s warnings=%s" % [
		summary_data.get("stage_count", 0),
		summary_data.get("validation_error_count", 0),
		summary_data.get("warning_count", 0),
	])
	summary_lines.append("product_signature=%s" % summary_data.get("product_signature", 0))
	return summary_lines


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
