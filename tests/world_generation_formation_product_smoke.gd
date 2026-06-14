extends SceneTree

const ChunkProviderScript := preload("res://scripts/chunk_provider.gd")
const FormationProductScript := preload("res://scripts/world_generation/formation/formation_product.gd")
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")
const LegacyFormationProductStageScript := preload("res://scripts/world_generation/pipeline/stages/legacy_formation_product_stage.gd")

var failed: bool = false


func _initialize() -> void:
	test_formation_product_from_legacy_layer_is_data_only()
	test_formation_product_set_from_legacy_layers_is_deterministic()
	test_pipeline_stage_emits_formation_product_set()
	test_provider_generated_data_preserves_formation_compatibility_fields()
	test_adapter_restores_formation_compatibility_from_product_set()
	quit(1 if failed else 0)


func test_formation_product_from_legacy_layer_is_data_only() -> void:
	var product: RefCounted = FormationProductScript.from_legacy_formation_layer(
		"solid",
		_sample_formation_layer("solid"),
		_sample_bounds()
	)
	_assert(product.is_valid(), "FormationProduct from legacy formation layer is valid")
	_assert(product.product_id == "solid_formation", "FormationProduct keeps deterministic product id")
	_assert(product.layer_id == "solid", "FormationProduct keeps layer id")
	_assert(product.dimensions() == Vector2i(3, 3), "FormationProduct reports formation grid dimensions")
	_assert(
		_variant_signature(product.to_legacy_formation_layer())
		== _variant_signature(_sample_formation_layer("solid")),
		"FormationProduct preserves legacy formation fields"
	)

	var runtime_metadata_product: RefCounted = FormationProductScript.from_legacy_formation_layer(
		"solid",
		_sample_formation_layer("solid"),
		_sample_bounds(),
		FormationProductScript.DEFAULT_CONSUMER_TARGET,
		{"node": Node.new()}
	)
	_assert(not runtime_metadata_product.is_valid(), "FormationProduct rejects runtime object metadata")
	runtime_metadata_product.metadata["node"].free()


func test_formation_product_set_from_legacy_layers_is_deterministic() -> void:
	var formation_layers := _sample_formation_layers()
	var product_set_a: RefCounted = FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		_sample_bounds()
	)
	var reordered_layers := {
		"water": formation_layers["water"],
		"solid": formation_layers["solid"],
		"ground": formation_layers["ground"],
	}
	var product_set_b: RefCounted = FormationProductSetScript.from_legacy_formation_layers(
		reordered_layers,
		_sample_bounds()
	)

	_assert(product_set_a.is_valid(), "FormationProductSet from legacy formation layers is valid")
	_assert(
		product_set_a.product_ids() == PackedStringArray(["ground_formation", "solid_formation", "water_formation"]),
		"FormationProductSet product ids are sorted deterministically"
	)
	_assert(
		product_set_a.signature_hash() == product_set_b.signature_hash(),
		"FormationProductSet signature is deterministic regardless of input order"
	)
	_assert(
		_variant_signature(product_set_a.to_legacy_formation_layers())
		== _variant_signature(formation_layers),
		"FormationProductSet converts back to legacy formation_layers"
	)


func test_provider_generated_data_preserves_formation_compatibility_fields() -> void:
	var provider: Node = ChunkProviderScript.new()
	provider.use_chunk_cache = false
	var chunk_coord := Vector3i(2, 0, -4)
	var generation_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var generated_data: Dictionary = provider.make_generated_chunk_data(
		chunk_coord,
		generation_result["logic_grid"],
		generation_result
	)
	var formation_product_set: Dictionary = generated_data.get("formation_product_set", {})
	var formation_products: Dictionary = formation_product_set.get("products", {})
	var solid_product: Dictionary = formation_products.get("solid_formation", {})

	_assert(
		formation_product_set.get("product_type", "") == FormationProductSetScript.PRODUCT_TYPE,
		"GeneratedChunkData carries FormationProductSet"
	)
	_assert(generated_data.has("formation_layers"), "GeneratedChunkData keeps formation_layers compatibility field")
	_assert(generated_data["formation_layers"].has("solid"), "GeneratedChunkData keeps solid formation layer")
	_assert(not solid_product.is_empty(), "FormationProductSet contains solid formation product")
	_assert(
		_variant_signature(formation_product_set.get("formation_layers", {}))
		== _variant_signature(generated_data["formation_layers"]),
		"FormationProductSet preserves formation_layers compatibility data"
	)
	_assert(
		_variant_signature(generated_data["formation_grid"])
		== _variant_signature(solid_product.get("formation_grid", [])),
		"GeneratedChunkData top-level formation_grid aliases solid formation product"
	)
	_assert(
		generated_data["formation_origin_cell"] == solid_product.get("formation_origin_cell", Vector2i.ZERO),
		"GeneratedChunkData top-level formation_origin_cell aliases solid formation product"
	)
	provider.free()


func test_pipeline_stage_emits_formation_product_set() -> void:
	var provider: Node = ChunkProviderScript.new()
	provider.use_chunk_cache = false
	var session: RefCounted = provider._world_generation_session()
	var working_set: GenerationWorkingSet = session.run_working_set(
		Vector3i(0, 0, 0),
		{"formation_product_smoke": true}
	)
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	var formation_store: Dictionary = working_set.formation_products.get(
		GeneratedWorldChunk.FORMATION_PRODUCT_SET_KEY,
		{}
	)
	var formation_product_ids: PackedStringArray = world_chunk.formation_products.get(
		"product_ids",
		PackedStringArray()
	)
	var formation_stage_result: Dictionary = world_chunk.stage_results[1] \
		if world_chunk.stage_results.size() > 1 else {}

	_assert(not working_set.has_validation_errors(), "formation product stage run has no validation errors")
	_assert(world_chunk.stage_results.size() == 2, "GeneratedWorldChunk reports topology and formation stage results")
	_assert(
		working_set.generated_products.has(GeneratedWorldChunk.FORMATION_PRODUCT_SET_KEY),
		"formation product stage stores FormationProductSet as generated product"
	)
	_assert(
		formation_store.get("product_type", "") == FormationProductSetScript.PRODUCT_TYPE,
		"formation product stage stores FormationProductSet in formation store"
	)
	_assert(
		world_chunk.formation_products.get("product_type", "") == FormationProductSetScript.PRODUCT_TYPE,
		"GeneratedWorldChunk finalizes FormationProductSet from pipeline"
	)
	_assert(
		formation_product_ids == PackedStringArray([
			"cliff_formation",
			"ground_formation",
			"solid_formation",
			"water_formation",
		]),
		"formation product stage emits requested default formation products"
	)
	_assert(
		formation_stage_result.get("stage_id", "") == LegacyFormationProductStageScript.STAGE_ID,
		"GeneratedWorldChunk reports formation stage result"
	)
	_assert(
		formation_stage_result.get("stage_category", "") == GenerationStage.CATEGORY_FORMATION,
		"formation stage result uses formation category"
	)
	provider.free()


func test_adapter_restores_formation_compatibility_from_product_set() -> void:
	var formation_layers := _sample_formation_layers()
	var formation_product_set: Dictionary = FormationProductSetScript.from_legacy_formation_layers(
		formation_layers,
		_sample_bounds()
	).to_dictionary()
	formation_product_set.erase("formation_layers")
	var world_chunk := GeneratedWorldChunk.new().configure(
		null,
		_sample_bounds(),
		{},
		{},
		{},
		{},
		_sample_topology_layers(),
		{},
		formation_product_set,
		{},
		[],
		PackedStringArray(),
		{}
	)

	var generated_data := GeneratedChunkDataAdapter.generated_chunk_data_from_world_chunk(world_chunk)
	_assert(
		_variant_signature(generated_data["formation_layers"]) == _variant_signature(formation_layers),
		"GeneratedChunkDataAdapter restores formation_layers from FormationProductSet"
	)
	_assert(
		_variant_signature(generated_data["formation_grid"])
		== _variant_signature(formation_layers["solid"]["formation_grid"]),
		"GeneratedChunkDataAdapter restores top-level formation_grid from solid FormationProduct"
	)
	_assert(
		generated_data["formation_mode"] == formation_layers["solid"]["formation_mode"],
		"GeneratedChunkDataAdapter restores top-level formation_mode from solid FormationProduct"
	)


func _sample_formation_layers() -> Dictionary:
	return {
		"ground": _sample_formation_layer("ground"),
		"solid": _sample_formation_layer("solid"),
		"water": _sample_formation_layer("water"),
	}


func _sample_formation_layer(layer_id: String) -> Dictionary:
	return {
		"layer_id": layer_id,
		"formation_grid": [[0, 1, 0], [1, 1, 0], [0, 0, 0]],
		"formation_origin_cell": Vector2i(-1, -1),
		"owned_visual_origin": Vector2i.ZERO,
		"owned_visual_size": Vector2i(2, 2),
		"formation_mode": "owned_halo",
		"source_chunk_coords": [Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
	}


func _sample_topology_layers() -> Dictionary:
	return {
		"ground": [[1, 1], [0, 1]],
		"solid": [[0, 1], [0, 0]],
		"water": [[0, 0], [1, 0]],
		"cliff": [[0, 0], [0, 0]],
	}


func _sample_bounds() -> Dictionary:
	return {
		"chunk_coord": Vector3i(0, 0, 0),
		"domain_descriptor": WorldSpace.DOMAIN_CELL_GRID_2D,
		"owned_cell_bounds": Rect2i(Vector2i.ZERO, Vector2i(2, 2)),
		"sample_cell_bounds": Rect2i(Vector2i(-1, -1), Vector2i(4, 4)),
		"chunk_size_cells": 2,
		"halo_cells": 1,
	}


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_formation_product_smoke failed: %s" % message)
