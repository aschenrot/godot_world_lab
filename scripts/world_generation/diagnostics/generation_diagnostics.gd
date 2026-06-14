extends RefCounted

class_name GenerationDiagnostics

const PRODUCT_TYPE := "GenerationDiagnostics"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/diagnostics/generation_diagnostics.gd"
const StageDiagnosticsScript := preload("res://scripts/world_generation/diagnostics/stage_diagnostics.gd")

const EXPECTED_EMITTED_COUNT_KEYS := [
	"world_layer",
	"world_feature",
	"continuity_fact",
	"placement_candidate",
	"topology_projection",
	"formation_product",
]

var definition_identity: Dictionary = {}
var stage_diagnostics: Array = []
var emitted_counts: Dictionary = {}
var product_counts: Dictionary = {}
var validation_errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()
var product_signatures: Dictionary = {}
var provenance: Dictionary = {}
var source_diagnostics: Dictionary = {}
var product_signature: int = 0
var metadata: Dictionary = {}


static func from_parts(
	p_definition_identity: Dictionary = {},
	p_stage_diagnostics: Array = [],
	p_emitted_counts: Dictionary = {},
	p_product_counts: Dictionary = {},
	p_validation_errors: PackedStringArray = PackedStringArray(),
	p_warnings: PackedStringArray = PackedStringArray(),
	p_product_signatures: Dictionary = {},
	p_provenance: Dictionary = {},
	p_source_diagnostics: Dictionary = {},
	p_product_signature: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var generation_diagnostics: RefCounted = load(SELF_SCRIPT_PATH).new()
	return generation_diagnostics.configure(
		p_definition_identity,
		p_stage_diagnostics,
		p_emitted_counts,
		p_product_counts,
		p_validation_errors,
		p_warnings,
		p_product_signatures,
		p_provenance,
		p_source_diagnostics,
		p_product_signature,
		p_metadata
	)


static func from_world_chunk(
	world_chunk: Variant,
	include_product_signatures: bool = true,
	include_provenance: bool = true
) -> RefCounted:
	if world_chunk == null:
		return load(SELF_SCRIPT_PATH).from_parts(
			{},
			[],
			_default_emitted_counts(),
			_default_product_counts(),
			PackedStringArray(["missing_generated_world_chunk"]),
			PackedStringArray(),
			{},
			{},
			{},
			0
		)

	var stage_entries := _stage_diagnostics_from_world_chunk(world_chunk)
	var aggregate_emitted_counts := _aggregate_emitted_counts(stage_entries)
	var chunk_validation_errors := _validation_errors_from_world_chunk(world_chunk, stage_entries)
	var chunk_warnings := _warnings_from_stage_entries(stage_entries)
	var next_product_signatures := product_signature_map_from_world_chunk(world_chunk) \
		if include_product_signatures else {}
	var next_provenance := _provenance_from_world_chunk(world_chunk, stage_entries, next_product_signatures) \
		if include_provenance else {}
	return load(SELF_SCRIPT_PATH).from_parts(
		world_chunk.identity.to_dictionary() if world_chunk.identity != null else {},
		stage_entries,
		aggregate_emitted_counts,
		product_counts_from_world_chunk(world_chunk),
		chunk_validation_errors,
		chunk_warnings,
		next_product_signatures,
		next_provenance,
		world_chunk.generation_diagnostics,
		world_chunk.signature_hash() if include_product_signatures else 0,
		{"source_product_type": world_chunk.PRODUCT_TYPE}
	)


static func product_signature_map_from_world_chunk(world_chunk: Variant) -> Dictionary:
	if world_chunk == null:
		return {}
	return {
		"generated_world_chunk": world_chunk.signature_hash(),
		"identity": world_chunk.identity.signature_hash() if world_chunk.identity != null else 0,
		"bounds": GeneratedChunkIdentity.stable_hash_variant(world_chunk.bounds),
		"world_layers": GeneratedChunkIdentity.stable_hash_variant(world_chunk.world_layers),
		"world_features": GeneratedChunkIdentity.stable_hash_variant(world_chunk.world_features),
		"continuity_facts": GeneratedChunkIdentity.stable_hash_variant(world_chunk.continuity_facts),
		"placement_candidates": GeneratedChunkIdentity.stable_hash_variant(world_chunk.placement_candidates),
		"topology_projections": GeneratedChunkIdentity.stable_hash_variant(world_chunk.topology_projections),
		"topology_projection_set": _dictionary_product_signature(world_chunk.topology_projection_set),
		"formation_products": _dictionary_product_signature(world_chunk.formation_products),
		"generation_diagnostics": GeneratedChunkIdentity.stable_hash_variant(world_chunk.generation_diagnostics),
		"stage_results": GeneratedChunkIdentity.stable_hash_variant(world_chunk.stage_results),
		"validation_issues": GeneratedChunkIdentity.stable_hash_variant(world_chunk.validation_issues),
		"legacy_generation_result": GeneratedChunkIdentity.stable_hash_variant(world_chunk.legacy_generation_result),
	}


static func product_counts_from_world_chunk(world_chunk: Variant) -> Dictionary:
	if world_chunk == null:
		return _default_product_counts()
	return {
		"world_layer": _world_layer_count(world_chunk.world_layers),
		"world_feature": _world_feature_count(world_chunk.world_features),
		"continuity_fact": _continuity_fact_count(world_chunk.continuity_facts),
		"placement_candidate": _placement_candidate_count(world_chunk.placement_candidates),
		"topology_projection": _topology_projection_count(world_chunk),
		"formation_product": _formation_product_count(world_chunk.formation_products),
	}


func configure(
	p_definition_identity: Dictionary = {},
	p_stage_diagnostics: Array = [],
	p_emitted_counts: Dictionary = {},
	p_product_counts: Dictionary = {},
	p_validation_errors: PackedStringArray = PackedStringArray(),
	p_warnings: PackedStringArray = PackedStringArray(),
	p_product_signatures: Dictionary = {},
	p_provenance: Dictionary = {},
	p_source_diagnostics: Dictionary = {},
	p_product_signature: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	definition_identity = p_definition_identity.duplicate(true)
	stage_diagnostics = p_stage_diagnostics.duplicate(true)
	emitted_counts = p_emitted_counts.duplicate(true)
	product_counts = p_product_counts.duplicate(true)
	validation_errors = p_validation_errors.duplicate()
	warnings = p_warnings.duplicate()
	product_signatures = p_product_signatures.duplicate(true)
	provenance = p_provenance.duplicate(true)
	source_diagnostics = p_source_diagnostics.duplicate(true)
	product_signature = p_product_signature
	metadata = p_metadata.duplicate(true)
	_ensure_expected_count_keys()
	return self


func duplicate_diagnostics() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		definition_identity,
		stage_diagnostics,
		emitted_counts,
		product_counts,
		validation_errors,
		warnings,
		product_signatures,
		provenance,
		source_diagnostics,
		product_signature,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GenerationDiagnostics:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not definition_identity.is_empty() \
		and product_signatures.has("generated_world_chunk") \
		and not _contains_runtime_object(definition_identity) \
		and not _contains_runtime_object(stage_diagnostics) \
		and not _contains_runtime_object(emitted_counts) \
		and not _contains_runtime_object(product_counts) \
		and not _contains_runtime_object(product_signatures) \
		and not _contains_runtime_object(provenance) \
		and not _contains_runtime_object(source_diagnostics) \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"definition_identity": definition_identity.duplicate(true),
		"stage_diagnostics": stage_diagnostics.duplicate(true),
		"stage_statuses": stage_statuses(),
		"emitted_counts": emitted_counts.duplicate(true),
		"product_counts": product_counts.duplicate(true),
		"validation_errors": validation_errors.duplicate(),
		"warnings": warnings.duplicate(),
		"product_signatures": product_signatures.duplicate(true),
		"provenance": provenance.duplicate(true),
		"source_diagnostics": source_diagnostics.duplicate(true),
		"product_signature": product_signature,
		"metadata": metadata.duplicate(true),
	}


func stage_statuses() -> Dictionary:
	var statuses: Dictionary = {}
	for stage_entry in stage_diagnostics:
		if typeof(stage_entry) != TYPE_DICTIONARY:
			continue
		var stage_dictionary: Dictionary = stage_entry
		var stage_key := String(stage_dictionary.get("stage_id", "")).strip_edges()
		if stage_key.is_empty():
			stage_key = "stage_%s" % stage_dictionary.get("stage_index", -1)
		statuses[stage_key] = stage_dictionary.get("status", "")
	return statuses


func _ensure_expected_count_keys() -> void:
	for key in EXPECTED_EMITTED_COUNT_KEYS:
		emitted_counts[String(key)] = int(emitted_counts.get(String(key), 0))
		product_counts[String(key)] = int(product_counts.get(String(key), 0))


static func _stage_diagnostics_from_world_chunk(world_chunk: Variant) -> Array:
	var entries: Array = []
	for stage_result in world_chunk.stage_results:
		if typeof(stage_result) != TYPE_DICTIONARY:
			continue
		var stage_result_dictionary: Dictionary = stage_result
		entries.append(StageDiagnosticsScript.from_stage_result(stage_result_dictionary).to_dictionary())
	return entries


static func _aggregate_emitted_counts(stage_entries: Array) -> Dictionary:
	var counts := _default_emitted_counts()
	for stage_entry in stage_entries:
		if typeof(stage_entry) != TYPE_DICTIONARY:
			continue
		var stage_dictionary: Dictionary = stage_entry
		var emitted: Variant = stage_dictionary.get("emitted_counts", {})
		if typeof(emitted) != TYPE_DICTIONARY:
			continue
		var emitted_dictionary: Dictionary = emitted
		for key in emitted_dictionary.keys():
			counts[String(key)] = int(counts.get(String(key), 0)) + int(emitted_dictionary[key])
	return counts


static func _validation_errors_from_world_chunk(world_chunk: Variant, stage_entries: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	for issue in world_chunk.validation_issues:
		errors.append(String(issue))
	for stage_entry in stage_entries:
		if typeof(stage_entry) != TYPE_DICTIONARY:
			continue
		var stage_dictionary: Dictionary = stage_entry
		var stage_errors: Variant = stage_dictionary.get("validation_errors", PackedStringArray())
		for error in _to_packed_string_array(stage_errors):
			errors.append(String(error))
	return errors


static func _warnings_from_stage_entries(stage_entries: Array) -> PackedStringArray:
	var next_warnings := PackedStringArray()
	for stage_entry in stage_entries:
		if typeof(stage_entry) != TYPE_DICTIONARY:
			continue
		var stage_dictionary: Dictionary = stage_entry
		for warning in _to_packed_string_array(stage_dictionary.get("warnings", PackedStringArray())):
			next_warnings.append(String(warning))
	return next_warnings


static func _provenance_from_world_chunk(
	world_chunk: Variant,
	stage_entries: Array,
	next_product_signatures: Dictionary
) -> Dictionary:
	var stage_signatures := PackedStringArray()
	for stage_entry in stage_entries:
		if typeof(stage_entry) != TYPE_DICTIONARY:
			continue
		var stage_dictionary: Dictionary = stage_entry
		stage_signatures.append("%s:%s" % [
			stage_dictionary.get("stage_id", ""),
			stage_dictionary.get("deterministic_signature_contribution", 0),
		])
	stage_signatures.sort()
	return {
		"product_type": "GenerationProvenance",
		"identity": world_chunk.identity.to_dictionary() if world_chunk.identity != null else {},
		"pipeline_id": world_chunk.generation_diagnostics.get("pipeline_id", ""),
		"pipeline_version": world_chunk.generation_diagnostics.get("pipeline_version", 0),
		"stage_count": stage_entries.size(),
		"completed_stage_count": world_chunk.generation_diagnostics.get("completed_stage_count", stage_entries.size()),
		"stage_signatures": stage_signatures,
		"product_signatures": next_product_signatures.duplicate(true),
	}


static func _world_layer_count(world_layers: Dictionary) -> int:
	var layer_set: Variant = world_layers.get("semantic_world_layer_set", {})
	if typeof(layer_set) == TYPE_DICTIONARY:
		var layer_set_dictionary: Dictionary = layer_set
		var layer_ids: Variant = layer_set_dictionary.get("layer_ids", PackedStringArray())
		return _count_id_collection(layer_ids)
	return 0


static func _world_feature_count(world_features: Dictionary) -> int:
	return _count_product_set_items(
		world_features.get("world_feature_set", {}),
		"feature_count",
		"feature_ids",
		"legacy_debug_markers"
	)


static func _continuity_fact_count(continuity_facts: Dictionary) -> int:
	return _count_product_set_items(
		continuity_facts.get("continuity_fact_set", {}),
		"fact_count",
		"fact_ids"
	)


static func _placement_candidate_count(placement_candidates: Dictionary) -> int:
	return _count_product_set_items(
		placement_candidates.get("placement_candidate_set", {}),
		"candidate_count",
		"candidate_ids"
	)


static func _topology_projection_count(world_chunk: Variant) -> int:
	var projection_count := _count_product_set_items(
		world_chunk.topology_projection_set,
		"projection_count",
		"projection_ids"
	)
	if projection_count > 0:
		return projection_count
	return world_chunk.topology_projections.size()


static func _formation_product_count(formation_products: Dictionary) -> int:
	return _count_product_set_items(
		formation_products,
		"formation_product_count",
		"product_ids"
	)


static func _count_product_set_items(
	product_set_data: Variant,
	count_key: String,
	ids_key: String,
	fallback_array_key: String = ""
) -> int:
	if typeof(product_set_data) != TYPE_DICTIONARY:
		return 0
	var product_set_dictionary: Dictionary = product_set_data
	if product_set_dictionary.has(count_key):
		return int(product_set_dictionary[count_key])
	var ids_value: Variant = product_set_dictionary.get(ids_key, PackedStringArray())
	var id_count := _count_id_collection(ids_value)
	if id_count > 0:
		return id_count
	if not fallback_array_key.is_empty():
		var fallback_value: Variant = product_set_dictionary.get(fallback_array_key, [])
		if typeof(fallback_value) == TYPE_ARRAY:
			var fallback_array: Array = fallback_value
			return fallback_array.size()
	return 0


static func _count_id_collection(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_STRING_ARRAY:
			var packed_value: PackedStringArray = value
			return packed_value.size()
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.size()
		_:
			return 0


static func _dictionary_product_signature(value: Variant) -> int:
	if typeof(value) != TYPE_DICTIONARY:
		return 0
	var dictionary_value: Dictionary = value
	if dictionary_value.has("signature_hash"):
		return int(dictionary_value["signature_hash"])
	return GeneratedChunkIdentity.stable_hash_variant(dictionary_value)


static func _default_emitted_counts() -> Dictionary:
	var counts: Dictionary = {}
	for key in EXPECTED_EMITTED_COUNT_KEYS:
		counts[String(key)] = 0
	return counts


static func _default_product_counts() -> Dictionary:
	return _default_emitted_counts()


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
