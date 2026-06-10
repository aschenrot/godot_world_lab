extends RefCounted

class_name GeneratedWorldChunk

const PRODUCT_TYPE := "GeneratedWorldChunk"
const SCHEMA_VERSION := 1
const LEGACY_GENERATION_RESULT_KEY := "legacy_generation_result"

var identity: GeneratedChunkIdentity = null
var bounds: Dictionary = {}
var world_layers: Dictionary = {}
var world_features: Dictionary = {}
var continuity_facts: Dictionary = {}
var placement_candidates: Dictionary = {}
var topology_projections: Dictionary = {}
var formation_products: Dictionary = {}
var generation_diagnostics: Dictionary = {}
var stage_results: Array = []
var validation_issues: PackedStringArray = PackedStringArray()
var legacy_generation_result: Dictionary = {}


static func from_working_set(working_set: GenerationWorkingSet) -> GeneratedWorldChunk:
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

	var generated_products: Dictionary = working_set.generated_products.duplicate(true)
	return chunk.configure(
		next_identity,
		next_bounds,
		working_set.world_layers,
		working_set.world_features,
		working_set.continuity_facts,
		working_set.placement_candidates,
		working_set.topology_projections,
		working_set.formation_products,
		working_set.diagnostics,
		working_set.stage_report(),
		working_set.validation_issues,
		generated_products.get(LEGACY_GENERATION_RESULT_KEY, {})
	)


static func from_legacy_generation_result(
	p_identity: GeneratedChunkIdentity,
	p_bounds: Dictionary,
	generation_result: Dictionary,
	diagnostics: Dictionary = {}
) -> GeneratedWorldChunk:
	var topology_layers: Dictionary = generation_result.get("topology_layers", {})
	var chunk := GeneratedWorldChunk.new()
	return chunk.configure(
		p_identity,
		p_bounds,
		{"legacy_terrain_cells": generation_result.get("terrain_cells", [])},
		{"legacy_debug_markers": generation_result.get("debug_markers", [])},
		{},
		{},
		topology_layers,
		{},
		diagnostics,
		[],
		PackedStringArray(),
		generation_result
	)


func configure(
	p_identity: GeneratedChunkIdentity,
	p_bounds: Dictionary = {},
	p_world_layers: Dictionary = {},
	p_world_features: Dictionary = {},
	p_continuity_facts: Dictionary = {},
	p_placement_candidates: Dictionary = {},
	p_topology_projections: Dictionary = {},
	p_formation_products: Dictionary = {},
	p_generation_diagnostics: Dictionary = {},
	p_stage_results: Array = [],
	p_validation_issues: PackedStringArray = PackedStringArray(),
	p_legacy_generation_result: Dictionary = {}
) -> GeneratedWorldChunk:
	identity = p_identity.duplicate_identity() if p_identity != null else null
	bounds = p_bounds.duplicate(true)
	world_layers = p_world_layers.duplicate(true)
	world_features = p_world_features.duplicate(true)
	continuity_facts = p_continuity_facts.duplicate(true)
	placement_candidates = p_placement_candidates.duplicate(true)
	topology_projections = p_topology_projections.duplicate(true)
	formation_products = p_formation_products.duplicate(true)
	generation_diagnostics = p_generation_diagnostics.duplicate(true)
	stage_results = p_stage_results.duplicate(true)
	validation_issues = p_validation_issues.duplicate()
	legacy_generation_result = p_legacy_generation_result.duplicate(true)
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
		formation_products,
		generation_diagnostics,
		stage_results,
		validation_issues,
		legacy_generation_result
	)


func has_validation_errors() -> bool:
	return not validation_issues.is_empty()


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
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(formation_products))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(generation_diagnostics))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(stage_results))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(validation_issues))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(legacy_generation_result))
	return h
