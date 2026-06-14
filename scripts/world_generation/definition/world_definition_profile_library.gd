extends RefCounted

class_name WorldDefinitionProfileLibrary

const PROFILE_SURFACE_MATERIAL := "surface_material_chunk"
const PROFILE_NAVIGATION_SURVEY := "navigation_topology_survey"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/definition/world_definition_profile_library.gd"
const NativeFormationProductStageScript := preload("res://scripts/world_generation/pipeline/stages/native_formation_product_stage.gd")


static func default_generation_settings() -> Dictionary:
	return {
		"authority": "world_definition_profile_library",
		"world_seed": 2026,
		"generator_version": 1,
		"chunk_size_cells": 16,
		"effective_chunk_size_cells": 16,
		"wall_threshold_percent": 34,
		"debug_force_chunk_border": false,
		"smoothing_passes": 1,
		"room_attempts": 3,
		"room_min_size": 3,
		"room_max_size": 6,
		"terrain_noise_frequency": 0.065,
		"liquid_noise_frequency": 0.045,
		"solid_noise_frequency": 0.09,
		"liquid_threshold_percent": 35,
		"target_walkable_min_percent": 70,
		"target_walkable_max_percent": 80,
		"liquid_blocks_movement": true,
		"debug_generation_markers_enabled": true,
	}


static func surface_material_chunk_definition() -> WorldDefinition:
	var definition := _base_definition(PROFILE_SURFACE_MATERIAL)
	definition.layer_schema_ids = PackedStringArray([
		GeneratedWorldChunk.NATIVE_TERRAIN_CELLS_KEY,
		"semantic_native_terrain_cells",
		"surface_material",
		"liquid_flags",
	])
	definition.feature_schema_ids = PackedStringArray([
		GeneratedWorldChunk.NATIVE_DEBUG_MARKERS_KEY,
		"room_feature",
		"path_feature",
	])
	definition.continuity_policy_ids = PackedStringArray([
		"owned_cell_bounds",
		"sample_halo",
	])
	definition.requested_topology_projections = PackedStringArray([
		"ground",
		"water",
		"solid",
		"cliff",
	])
	definition.requested_formation_products = PackedStringArray([
		"ground",
		"water",
		"solid",
		"cliff",
	])
	definition.requested_product_set = PackedStringArray([
		GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK,
		"semantic_world_layer_set",
		"formation_product_set",
		"generation_diagnostics",
	])
	return definition


static func navigation_topology_survey_definition() -> WorldDefinition:
	var definition := _base_definition(PROFILE_NAVIGATION_SURVEY)
	definition.layer_schema_ids = PackedStringArray([
		"walkability_mask",
		"solid_navigation_mask",
	])
	definition.feature_schema_ids = PackedStringArray([
		"connectivity_repair_feature",
		"walkability_balance_feature",
	])
	definition.continuity_policy_ids = PackedStringArray([
		"walkable_region_connectivity",
		"neighbor_sample_halo",
		"boundary_transition_facts",
	])
	definition.requested_topology_projections = PackedStringArray([
		"solid",
	])
	definition.requested_formation_products = PackedStringArray([
		"solid",
	])
	definition.requested_product_set = PackedStringArray([
		GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK,
		"topology_projection_set",
		"continuity_fact_set",
		"placement_candidate_set",
		"generation_diagnostics",
	])
	return definition


static func proof_definitions() -> Dictionary:
	return {
		PROFILE_SURFACE_MATERIAL: surface_material_chunk_definition(),
		PROFILE_NAVIGATION_SURVEY: navigation_topology_survey_definition(),
	}


static func proof_summary() -> Dictionary:
	var surface_definition := surface_material_chunk_definition()
	var navigation_definition := navigation_topology_survey_definition()
	return {
		"product_type": "WorldDefinitionDiversityProof",
		"profile_ids": PackedStringArray([
			PROFILE_SURFACE_MATERIAL,
			PROFILE_NAVIGATION_SURVEY,
		]),
		"same_generation_settings_hash": surface_definition.generation_settings_hash() == navigation_definition.generation_settings_hash(),
		"different_contract_hash": surface_definition.contract_hash() != navigation_definition.contract_hash(),
		"different_definition_hash": surface_definition.definition_hash() != navigation_definition.definition_hash(),
		"surface_material_contract_hash": surface_definition.contract_hash(),
		"navigation_survey_contract_hash": navigation_definition.contract_hash(),
		"surface_material_definition_hash": surface_definition.definition_hash(),
		"navigation_survey_definition_hash": navigation_definition.definition_hash(),
		"surface_material_generation_settings_hash": surface_definition.generation_settings_hash(),
		"navigation_survey_generation_settings_hash": navigation_definition.generation_settings_hash(),
		"shared_pipeline_interface": "generation_pipeline",
		"shared_pipeline_stage_ids": PackedStringArray([
			NativeChunkGenerationStage.STAGE_ID,
			NativeFormationProductStageScript.STAGE_ID,
		]),
		"shared_product_model": GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK,
	}


static func _base_definition(profile_id: String) -> WorldDefinition:
	var definition := WorldDefinition.new()
	definition.world_definition_id = profile_id
	definition.world_definition_version = 1
	definition.world_seed = int(default_generation_settings().get("world_seed", 2026))
	definition.domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	definition.generation_settings = default_generation_settings()
	definition.stage_ids = PackedStringArray([
		NativeChunkGenerationStage.STAGE_ID,
		NativeFormationProductStageScript.STAGE_ID,
	])
	return definition
