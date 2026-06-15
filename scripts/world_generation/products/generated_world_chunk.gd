extends RefCounted

class_name GeneratedWorldChunk

const PRODUCT_TYPE := "GeneratedWorldChunk"
const CANONICAL_RECORD_PRODUCT_TYPE := "GeneratedWorldChunkRecord"
const SCHEMA_VERSION := 1
const LEGACY_GENERATION_RESULT_KEY := "legacy_generation_result"
const NATIVE_TERRAIN_CELLS_KEY := "native_terrain_cells"
const NATIVE_DEBUG_MARKERS_KEY := "native_debug_markers"
const WORLD_FEATURE_SET_KEY := "world_feature_set"
const CONTINUITY_FACT_SET_KEY := "continuity_fact_set"
const PLACEMENT_CANDIDATE_SET_KEY := "placement_candidate_set"
const TOPOLOGY_PROJECTION_SET_KEY := "topology_projection_set"
const FORMATION_PRODUCT_SET_KEY := "formation_product_set"
const WorldFeatureSetScript := preload("res://scripts/world_generation/features/world_feature_set.gd")
const ContinuityFactSetScript := preload("res://scripts/world_generation/continuity/continuity_fact_set.gd")
const PlacementCandidateSetScript := preload("res://scripts/world_generation/placement/placement_candidate_set.gd")
const TopologyProjectionSetScript := preload("res://scripts/world_generation/topology/topology_projection_set.gd")
const GenerationDiagnosticsScript := preload("res://scripts/world_generation/diagnostics/generation_diagnostics.gd")
const GeneratedChunkReportScript := preload("res://scripts/world_generation/diagnostics/generated_chunk_report.gd")

var identity: GeneratedChunkIdentity = null
var bounds: Dictionary = {}
var world_layers: Dictionary = {}
var world_features: Dictionary = {}
var continuity_facts: Dictionary = {}
var placement_candidates: Dictionary = {}
var topology_projections: Dictionary = {}
var topology_projection_set: Dictionary = {}
var formation_products: Dictionary = {}
var generation_diagnostics: Dictionary = {}
var stage_results: Array = []
var validation_issues: PackedStringArray = PackedStringArray()
var legacy_generation_result: Dictionary = {}
var _cached_truth_signature_hash: int = -1
var _cached_report_signature_hash: int = -1
var _cached_product_signatures: Dictionary = {}
var _signature_cache_locked: bool = false


static func from_working_set(
	working_set: GenerationWorkingSet,
	copy_inputs: bool = true,
	include_stage_results: bool = true
) -> GeneratedWorldChunk:
	var chunk := GeneratedWorldChunk.new()
	if working_set == null:
		chunk.validation_issues.append("missing_generation_working_set")
		return chunk

	var context := working_set.context
	var next_identity: GeneratedChunkIdentity = context.identity if context != null else null
	var next_bounds := {}
	if context != null:
		next_bounds = {
			"chunk_coord": context.chunk_coord,
			"domain_descriptor": context.domain_descriptor,
			"owned_cell_bounds": context.owned_cell_bounds,
			"sample_cell_bounds": context.sample_cell_bounds,
			"chunk_size_cells": context.chunk_size_cells,
			"halo_cells": context.halo_cells,
		}

	var finalization_start_us := Time.get_ticks_usec()
	var product_copy_start_us := Time.get_ticks_usec()
	var generated_products: Dictionary = _copy_dictionary(working_set.generated_products, copy_inputs)
	var generated_products_copy_us := Time.get_ticks_usec() - product_copy_start_us
	var formation_product_set: Dictionary = generated_products.get(
		FORMATION_PRODUCT_SET_KEY,
		working_set.formation_products.get(FORMATION_PRODUCT_SET_KEY, working_set.formation_products)
	)
	var stage_report_start_us := Time.get_ticks_usec()
	var final_stage_results := working_set.stage_report() if include_stage_results else []
	var stage_report_build_us := Time.get_ticks_usec() - stage_report_start_us
	var diagnostics := working_set.diagnostics.duplicate(true)
	diagnostics["stage_profile"] = _stage_profile_from_stage_results(working_set.stage_results)
	var configure_start_us := Time.get_ticks_usec()
	chunk.configure(
		next_identity,
		next_bounds,
		working_set.world_layers,
		working_set.world_features,
		working_set.continuity_facts,
		working_set.placement_candidates,
		working_set.topology_projections,
		generated_products.get(TOPOLOGY_PROJECTION_SET_KEY, {}),
		formation_product_set,
		diagnostics,
		final_stage_results,
		working_set.validation_issues,
		generated_products.get(LEGACY_GENERATION_RESULT_KEY, {}),
		copy_inputs
	)
	var configure_copy_us := Time.get_ticks_usec() - configure_start_us
	chunk.generation_diagnostics["working_set_finalization_us"] = Time.get_ticks_usec() - finalization_start_us
	chunk.generation_diagnostics["generated_products_copy_us"] = generated_products_copy_us
	chunk.generation_diagnostics["stage_report_build_us"] = stage_report_build_us
	chunk.generation_diagnostics["configure_copy_us"] = configure_copy_us
	return chunk


static func from_legacy_generation_result(
	p_identity: GeneratedChunkIdentity,
	p_bounds: Dictionary,
	generation_result: Dictionary,
	diagnostics: Dictionary = {},
	p_formation_products: Dictionary = {},
	copy_inputs: bool = true
) -> GeneratedWorldChunk:
	var internal_result := GeneratedChunkDataAdapter.generation_result_without_logic_grid_alias(
		generation_result,
		copy_inputs
	)
	var topology_layers: Dictionary = internal_result.get("topology_layers", {})
	var debug_markers: Array = internal_result.get("debug_markers", [])
	var world_feature_set: Dictionary = WorldFeatureSetScript.from_legacy_debug_markers(
		debug_markers,
		p_bounds
	).to_dictionary()
	var continuity_fact_set: Dictionary = ContinuityFactSetScript.from_context_bounds(
		p_bounds
	).to_dictionary()
	var placement_candidate_set: Dictionary = PlacementCandidateSetScript.from_legacy_debug_markers(
		debug_markers,
		p_bounds
	).to_dictionary()
	var projection_set: Dictionary = TopologyProjectionSetScript.from_legacy_topology_layers(
		topology_layers,
		p_bounds,
		p_bounds.get("domain_descriptor", WorldSpace.DOMAIN_CELL_GRID_2D)
	).to_dictionary()
	var chunk := GeneratedWorldChunk.new()
	return chunk.configure(
		p_identity,
		p_bounds,
		{"legacy_terrain_cells": internal_result.get("terrain_cells", [])},
		{
			"legacy_debug_markers": debug_markers,
			WORLD_FEATURE_SET_KEY: world_feature_set,
		},
		{CONTINUITY_FACT_SET_KEY: continuity_fact_set},
		{PLACEMENT_CANDIDATE_SET_KEY: placement_candidate_set},
		topology_layers,
		projection_set,
		p_formation_products,
		diagnostics,
		[],
		PackedStringArray(),
		internal_result,
		copy_inputs
	)


func configure(
	p_identity: GeneratedChunkIdentity,
	p_bounds: Dictionary = {},
	p_world_layers: Dictionary = {},
	p_world_features: Dictionary = {},
	p_continuity_facts: Dictionary = {},
	p_placement_candidates: Dictionary = {},
	p_topology_projections: Dictionary = {},
	p_topology_projection_set: Dictionary = {},
	p_formation_products: Dictionary = {},
	p_generation_diagnostics: Dictionary = {},
	p_stage_results: Array = [],
	p_validation_issues: PackedStringArray = PackedStringArray(),
	p_legacy_generation_result: Dictionary = {},
	copy_inputs: bool = true
) -> GeneratedWorldChunk:
	identity = p_identity.duplicate_identity() if p_identity != null and copy_inputs else p_identity
	bounds = _copy_dictionary(p_bounds, copy_inputs)
	world_layers = _copy_dictionary(p_world_layers, copy_inputs)
	world_features = _copy_dictionary(p_world_features, copy_inputs)
	continuity_facts = _copy_dictionary(p_continuity_facts, copy_inputs)
	placement_candidates = _copy_dictionary(p_placement_candidates, copy_inputs)
	topology_projections = _copy_dictionary(p_topology_projections, copy_inputs)
	topology_projection_set = _copy_dictionary(p_topology_projection_set, copy_inputs)
	formation_products = _copy_dictionary(p_formation_products, copy_inputs)
	generation_diagnostics = _copy_dictionary(p_generation_diagnostics, copy_inputs)
	stage_results = p_stage_results.duplicate(true) if copy_inputs else p_stage_results
	validation_issues = p_validation_issues.duplicate() if copy_inputs else p_validation_issues
	legacy_generation_result = _copy_dictionary(p_legacy_generation_result, copy_inputs)
	_cached_truth_signature_hash = -1
	_cached_report_signature_hash = -1
	_cached_product_signatures = {}
	_signature_cache_locked = false
	return self


func duplicate_chunk() -> GeneratedWorldChunk:
	return GeneratedWorldChunk.new().configure(
		identity,
		bounds,
		world_layers,
		world_features,
		continuity_facts,
		placement_candidates,
		topology_projections,
		topology_projection_set,
		formation_products,
		generation_diagnostics,
		stage_results,
		validation_issues,
		legacy_generation_result
	)


func has_validation_errors() -> bool:
	return not validation_issues.is_empty()


func diagnostics_report(
	include_product_signatures: bool = true,
	include_provenance: bool = true
) -> Dictionary:
	return GenerationDiagnosticsScript.from_world_chunk(
		self,
		include_product_signatures,
		include_provenance
	).to_dictionary()


func generated_chunk_report() -> Dictionary:
	return GeneratedChunkReportScript.from_world_chunk(self).to_dictionary()


func product_signature_map() -> Dictionary:
	return GenerationDiagnosticsScript.product_signature_map_from_world_chunk(self)


func to_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"schema_version": SCHEMA_VERSION,
		"identity": identity.to_dictionary() if identity != null else {},
		"bounds": bounds.duplicate(true),
		"world_layers": world_layers.duplicate(true),
		"world_features": world_features.duplicate(true),
		"continuity_facts": continuity_facts.duplicate(true),
		"placement_candidates": placement_candidates.duplicate(true),
		"topology_projections": topology_projections.duplicate(true),
		"topology_projection_set": topology_projection_set.duplicate(true),
		"formation_products": formation_products.duplicate(true),
		"generation_diagnostics": generation_diagnostics.duplicate(true),
		"stage_results": stage_results.duplicate(true),
		"validation_issues": validation_issues.duplicate(),
		"legacy_generation_result": legacy_generation_result.duplicate(true),
		"signature_hash": signature_hash(),
		"report_signature_hash": report_signature_hash(),
	}


func to_canonical_record(copy_inputs: bool = true) -> Dictionary:
	var topology_layers := _topology_layers_from_projection_set(topology_projection_set)
	var product_signatures := _canonical_product_signatures(
		topology_projection_set,
		formation_products,
		world_layers,
		world_features,
		continuity_facts,
		placement_candidates
	)
	var truth_hash := _truth_signature_from_product_signatures(
		identity,
		bounds,
		product_signatures
	)
	var record := {
		"product_type": CANONICAL_RECORD_PRODUCT_TYPE,
		"schema_version": SCHEMA_VERSION,
		"identity": identity.to_dictionary() if identity != null else {},
		"chunk_coord": identity.chunk_coord if identity != null else bounds.get("chunk_coord", Vector3i.ZERO),
		"bounds": bounds.duplicate(true) if copy_inputs else bounds,
		"topology_layers": topology_layers.duplicate(true) if copy_inputs else topology_layers,
		"topology_projection_set": topology_projection_set.duplicate(true) if copy_inputs else topology_projection_set,
		"formation_products": formation_products.duplicate(true) if copy_inputs else formation_products,
		"world_layers": world_layers.duplicate(true) if copy_inputs else world_layers,
		"world_features": world_features.duplicate(true) if copy_inputs else world_features,
		"continuity_facts": continuity_facts.duplicate(true) if copy_inputs else continuity_facts,
		"placement_candidates": placement_candidates.duplicate(true) if copy_inputs else placement_candidates,
		"truth_signature_hash": truth_hash,
		"product_signatures": product_signatures,
		"record_diagnostics": {
			"record_storage": "canonical_record_v1_precomputed_signatures",
			"truth_hash_source": "product_signatures",
			"topology_layer_count": topology_layers.size(),
			"topology_projection_count": topology_projection_set.get("projection_count", topology_layers.size()),
			"formation_product_count": _formation_product_count(formation_products),
			"has_report_payloads": (
				not world_layers.is_empty()
				or not world_features.is_empty()
				or not continuity_facts.is_empty()
				or not placement_candidates.is_empty()
			),
		},
	}
	return record


static func from_canonical_record(record: Dictionary, copy_inputs: bool = true) -> GeneratedWorldChunk:
	var identity_data: Dictionary = record.get("identity", {})
	var record_identity: GeneratedChunkIdentity = GeneratedChunkIdentity.from_dictionary(identity_data) if not identity_data.is_empty() else null
	var chunk := GeneratedWorldChunk.new().configure(
		record_identity,
		record.get("bounds", {}),
		record.get("world_layers", {}),
		record.get("world_features", {}),
		record.get("continuity_facts", {}),
		record.get("placement_candidates", {}),
		record.get("topology_layers", {}),
		record.get("topology_projection_set", {}),
		record.get("formation_products", {}),
		{},
		[],
		PackedStringArray(),
		{},
		copy_inputs
	)
	chunk._cached_truth_signature_hash = int(record.get("truth_signature_hash", -1))
	chunk._cached_report_signature_hash = int(record.get("report_signature_hash", -1))
	chunk._cached_product_signatures = record.get("product_signatures", {}).duplicate(true)
	chunk._signature_cache_locked = chunk._cached_truth_signature_hash >= 0
	return chunk


func signature_hash() -> int:
	return generated_truth_signature_hash()


func generated_truth_signature_hash() -> int:
	if _signature_cache_locked and _cached_truth_signature_hash >= 0:
		return _cached_truth_signature_hash
	var h := GeneratedChunkIdentity.stable_hash_string("GeneratedWorldChunk:v%s" % SCHEMA_VERSION)
	h = GeneratedChunkIdentity.mix_hash(h, identity.signature_hash() if identity != null else 0)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(bounds))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(world_layers))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(world_features))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(continuity_facts))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(placement_candidates))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(topology_projection_set))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(formation_products))
	return h


func report_signature_hash() -> int:
	if _signature_cache_locked and _cached_report_signature_hash >= 0:
		return _cached_report_signature_hash
	var h := generated_truth_signature_hash()
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(topology_projections))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_report_variant(generation_diagnostics))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_report_variant(stage_results))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(validation_issues))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(legacy_generation_result))
	return h


static func truth_signature_hash_from_canonical_record(record: Dictionary) -> int:
	return int(record.get("truth_signature_hash", 0))


static func _canonical_product_signatures(
	p_topology_projection_set: Dictionary,
	p_formation_products: Dictionary,
	p_world_layers: Dictionary,
	p_world_features: Dictionary,
	p_continuity_facts: Dictionary,
	p_placement_candidates: Dictionary
) -> Dictionary:
	return {
		"topology_projection_set": GeneratedChunkIdentity.stable_hash_variant(p_topology_projection_set),
		"formation_products": GeneratedChunkIdentity.stable_hash_variant(p_formation_products),
		"world_layers": GeneratedChunkIdentity.stable_hash_variant(p_world_layers),
		"world_features": GeneratedChunkIdentity.stable_hash_variant(p_world_features),
		"continuity_facts": GeneratedChunkIdentity.stable_hash_variant(p_continuity_facts),
		"placement_candidates": GeneratedChunkIdentity.stable_hash_variant(p_placement_candidates),
	}


static func _truth_signature_from_product_signatures(
	p_identity: GeneratedChunkIdentity,
	p_bounds: Dictionary,
	product_signatures: Dictionary
) -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GeneratedWorldChunk:v%s" % SCHEMA_VERSION)
	h = GeneratedChunkIdentity.mix_hash(h, p_identity.signature_hash() if p_identity != null else 0)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(p_bounds))
	h = GeneratedChunkIdentity.mix_hash(h, int(product_signatures.get("world_layers", 0)))
	h = GeneratedChunkIdentity.mix_hash(h, int(product_signatures.get("world_features", 0)))
	h = GeneratedChunkIdentity.mix_hash(h, int(product_signatures.get("continuity_facts", 0)))
	h = GeneratedChunkIdentity.mix_hash(h, int(product_signatures.get("placement_candidates", 0)))
	h = GeneratedChunkIdentity.mix_hash(h, int(product_signatures.get("topology_projection_set", 0)))
	h = GeneratedChunkIdentity.mix_hash(h, int(product_signatures.get("formation_products", 0)))
	return h


static func _stage_profile_from_stage_results(p_stage_results: Array) -> Array:
	var profile: Array = []
	for result in p_stage_results:
		if result == null or not result.has_method("to_dictionary"):
			continue
		var result_data: Dictionary = result.to_dictionary()
		var diagnostics: Dictionary = result_data.get("diagnostics", {})
		profile.append({
			"stage_id": result_data.get("stage_id", ""),
			"elapsed_us": int(diagnostics.get("elapsed_us", 0)),
			"diagnostics": diagnostics.duplicate(true),
		})
	return profile


static func _copy_dictionary(value: Dictionary, copy_inputs: bool) -> Dictionary:
	return value.duplicate(true) if copy_inputs else value


static func _topology_layers_from_projection_set(projection_set_data: Dictionary) -> Dictionary:
	var projections: Variant = projection_set_data.get("projections", {})
	if typeof(projections) == TYPE_DICTIONARY:
		var topology_layers: Dictionary = {}
		var projection_dictionary: Dictionary = projections
		for projection_id in projection_dictionary.keys():
			var projection_data: Variant = projection_dictionary[projection_id]
			if typeof(projection_data) != TYPE_DICTIONARY:
				continue
			var grid: Variant = projection_data.get("grid", [])
			if typeof(grid) == TYPE_ARRAY:
				topology_layers[String(projection_id)] = grid
		if not topology_layers.is_empty():
			return topology_layers
	var legacy_layers: Variant = projection_set_data.get("topology_layers", {})
	if typeof(legacy_layers) == TYPE_DICTIONARY:
		return legacy_layers
	return {}


static func _formation_product_count(products: Dictionary) -> int:
	if products.has("product_ids"):
		var product_ids: PackedStringArray = products.get("product_ids", PackedStringArray())
		return product_ids.size()
	if products.has("products"):
		var product_map: Variant = products.get("products", {})
		return product_map.size() if typeof(product_map) == TYPE_DICTIONARY else 0
	if products.has("formation_layers"):
		var formation_layers: Variant = products.get("formation_layers", {})
		return formation_layers.size() if typeof(formation_layers) == TYPE_DICTIONARY else 0
	return products.size()
