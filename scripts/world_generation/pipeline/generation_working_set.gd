extends RefCounted

class_name GenerationWorkingSet

const STORE_FIELDS := "fields"
const STORE_LAYERS := "layers"
const STORE_FEATURES := "features"
const STORE_CONTINUITY := "continuity"
const STORE_PLACEMENT := "placement"
const STORE_TOPOLOGY := "topology"
const STORE_FORMATION := "formation"
const STORE_PRODUCTS := "products"
const STORE_DIAGNOSTICS := "diagnostics"

var snapshot: WorldDefinitionSnapshot = null
var context: GenerationContext = null
var field_values: Dictionary = {}
var world_layers: Dictionary = {}
var world_features: Dictionary = {}
var continuity_facts: Dictionary = {}
var placement_candidates: Dictionary = {}
var topology_projections: Dictionary = {}
var formation_products: Dictionary = {}
var generated_products: Dictionary = {}
var diagnostics: Dictionary = {}
var validation_issues: PackedStringArray = PackedStringArray()
var stage_results: Array = []


static func from_snapshot_and_context(
	p_snapshot: WorldDefinitionSnapshot,
	p_context: GenerationContext
) -> GenerationWorkingSet:
	var working_set := GenerationWorkingSet.new()
	return working_set.configure(p_snapshot, p_context)


func configure(
	p_snapshot: WorldDefinitionSnapshot,
	p_context: GenerationContext
) -> GenerationWorkingSet:
	snapshot = p_snapshot.duplicate_snapshot() if p_snapshot != null else null
	context = p_context.duplicate_context() if p_context != null else null
	field_values = {}
	world_layers = {}
	world_features = {}
	continuity_facts = {}
	placement_candidates = {}
	topology_projections = {}
	formation_products = {}
	generated_products = {}
	diagnostics = {}
	validation_issues = PackedStringArray()
	stage_results = []
	return self


func duplicate_working_set() -> GenerationWorkingSet:
	var copy := GenerationWorkingSet.from_snapshot_and_context(snapshot, context)
	copy.field_values = field_values.duplicate(true)
	copy.world_layers = world_layers.duplicate(true)
	copy.world_features = world_features.duplicate(true)
	copy.continuity_facts = continuity_facts.duplicate(true)
	copy.placement_candidates = placement_candidates.duplicate(true)
	copy.topology_projections = topology_projections.duplicate(true)
	copy.formation_products = formation_products.duplicate(true)
	copy.generated_products = generated_products.duplicate(true)
	copy.diagnostics = diagnostics.duplicate(true)
	copy.validation_issues = validation_issues.duplicate()
	for result in stage_results:
		if result != null and result.has_method("duplicate_result"):
			copy.stage_results.append(result.duplicate_result())
	return copy


func set_store_value(store_id: String, key: String, value: Variant) -> void:
	var store: Variant = _store_for_id(store_id)
	var normalized_key := key.strip_edges()
	if store == null or normalized_key.is_empty():
		return
	store[normalized_key] = value


func get_store_value(store_id: String, key: String, default_value: Variant = null) -> Variant:
	var store: Variant = _store_for_id(store_id)
	if store == null:
		return default_value
	return store.get(key.strip_edges(), default_value)


func has_store_value(store_id: String, key: String) -> bool:
	var store: Variant = _store_for_id(store_id)
	return store != null and store.has(key.strip_edges())


func erase_store_value(store_id: String, key: String) -> void:
	var store: Variant = _store_for_id(store_id)
	if store == null:
		return
	store.erase(key.strip_edges())


func record_stage_result(result: GenerationStageResult) -> void:
	if result == null:
		return
	stage_results.append(result.duplicate_result())
	if result.is_failed():
		for issue in result.issues:
			add_validation_issue("%s:%s" % [result.stage_id, issue])


func add_validation_issue(issue: String) -> void:
	var value := issue.strip_edges()
	if value.is_empty():
		return
	validation_issues.append(value)


func set_diagnostic(key: String, value: Variant) -> void:
	var normalized_key := key.strip_edges()
	if normalized_key.is_empty():
		return
	diagnostics[normalized_key] = value


func has_validation_errors() -> bool:
	return not validation_issues.is_empty()


func stage_report() -> Array:
	var report: Array = []
	for result in stage_results:
		if result != null and result.has_method("to_dictionary"):
			report.append(result.to_dictionary())
	return report


func to_dictionary() -> Dictionary:
	return {
		"product_type": "GenerationWorkingSet",
		"snapshot": snapshot.to_dictionary() if snapshot != null else {},
		"context": context.to_dictionary() if context != null else {},
		"field_values": field_values.duplicate(true),
		"world_layers": world_layers.duplicate(true),
		"world_features": world_features.duplicate(true),
		"continuity_facts": continuity_facts.duplicate(true),
		"placement_candidates": placement_candidates.duplicate(true),
		"topology_projections": topology_projections.duplicate(true),
		"formation_products": formation_products.duplicate(true),
		"generated_products": generated_products.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
		"validation_issues": validation_issues.duplicate(),
		"stage_results": stage_report(),
		"signature_hash": signature_hash(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GenerationWorkingSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, snapshot.signature_hash() if snapshot != null else 0)
	h = GeneratedChunkIdentity.mix_hash(h, context.signature_hash() if context != null else 0)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(field_values))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(world_layers))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(world_features))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(continuity_facts))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(placement_candidates))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(topology_projections))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(formation_products))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(generated_products))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_report_variant(diagnostics))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(validation_issues))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_report_variant(stage_report()))
	return h


func _store_for_id(store_id: String) -> Variant:
	match store_id.strip_edges():
		STORE_FIELDS:
			return field_values
		STORE_LAYERS:
			return world_layers
		STORE_FEATURES:
			return world_features
		STORE_CONTINUITY:
			return continuity_facts
		STORE_PLACEMENT:
			return placement_candidates
		STORE_TOPOLOGY:
			return topology_projections
		STORE_FORMATION:
			return formation_products
		STORE_PRODUCTS:
			return generated_products
		STORE_DIAGNOSTICS:
			return diagnostics
		_:
			return null
