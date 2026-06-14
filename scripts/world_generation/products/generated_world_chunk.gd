extends RefCounted

class_name GeneratedWorldChunk

const PRODUCT_TYPE := "GeneratedWorldChunk"
const SCHEMA_VERSION := 1
const LEGACY_GENERATION_RESULT_KEY := "legacy_generation_result"
const WORLD_FEATURE_SET_KEY := "world_feature_set"
const CONTINUITY_FACT_SET_KEY := "continuity_fact_set"
const PLACEMENT_CANDIDATE_SET_KEY := "placement_candidate_set"
const TOPOLOGY_PROJECTION_SET_KEY := "topology_projection_set"
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

	var generated_products: Dictionary = _copy_dictionary(working_set.generated_products, copy_inputs)
	return chunk.configure(
		next_identity,
		next_bounds,
		working_set.world_layers,
		working_set.world_features,
		working_set.continuity_facts,
		working_set.placement_candidates,
		working_set.topology_projections,
		generated_products.get(TOPOLOGY_PROJECTION_SET_KEY, {}),
		working_set.formation_products,
		working_set.diagnostics,
		working_set.stage_report() if include_stage_results else [],
		working_set.validation_issues,
		generated_products.get(LEGACY_GENERATION_RESULT_KEY, {}),
		copy_inputs
	)


static func from_legacy_generation_result(
	p_identity: GeneratedChunkIdentity,
	p_bounds: Dictionary,
	generation_result: Dictionary,
	diagnostics: Dictionary = {},
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
		{},
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
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GeneratedWorldChunk:v%s" % SCHEMA_VERSION)
	h = GeneratedChunkIdentity.mix_hash(h, identity.signature_hash() if identity != null else 0)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(bounds))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(world_layers))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(world_features))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(continuity_facts))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(placement_candidates))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(topology_projections))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(topology_projection_set))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(formation_products))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(generation_diagnostics))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(stage_results))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(validation_issues))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(legacy_generation_result))
	return h


static func _copy_dictionary(value: Dictionary, copy_inputs: bool) -> Dictionary:
	return value.duplicate(true) if copy_inputs else value
