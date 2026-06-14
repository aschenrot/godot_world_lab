extends SceneTree

const ChunkProviderScript := preload("res://scripts/chunk_provider.gd")
const FormationProductScript := preload("res://scripts/world_generation/formation/formation_product.gd")
const FormationProductSetScript := preload("res://scripts/world_generation/formation/formation_product_set.gd")
const NativeFormationProductStageScript := preload("res://scripts/world_generation/pipeline/stages/native_formation_product_stage.gd")

var failed: bool = false


func _initialize() -> void:
	test_formation_product_from_legacy_layer_is_data_only()
	test_formation_product_set_from_legacy_layers_is_deterministic()
	test_pipeline_stage_emits_formation_product_set()
	test_formation_stage_consumes_canonical_topology_projection_set()
	test_formation_dependencies_expand_internal_topology_requests()
	test_unknown_formation_product_fails_snapshot_validation()
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
	var generated_data: Dictionary = provider.make_generated_chunk_data(chunk_coord)
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
		formation_stage_result.get("stage_id", "") == NativeFormationProductStageScript.STAGE_ID,
		"GeneratedWorldChunk reports formation stage result"
	)
	_assert(
		formation_stage_result.get("stage_category", "") == GenerationStage.CATEGORY_FORMATION,
		"formation stage result uses formation category"
	)
	provider.free()


func test_formation_stage_consumes_canonical_topology_projection_set() -> void:
	var provider: Node = ChunkProviderScript.new()
	provider.use_chunk_cache = false
	var session: RefCounted = provider._world_generation_session()
	var snapshot: WorldDefinitionSnapshot = session.snapshot()
	var context := _context_for_snapshot(snapshot, Vector3i(1, 0, 1))
	var working_set := GenerationWorkingSet.from_snapshot_and_context(snapshot, context)
	var native_stage := NativeChunkGenerationStage.from_session(session)
	var native_result := native_stage.run(snapshot, context, working_set, 0)
	working_set.record_stage_result(native_result)
	working_set.topology_projections.clear()
	var formation_stage := NativeFormationProductStageScript.from_session(session)
	var formation_result := formation_stage.run(snapshot, context, working_set, 1)

	_assert(formation_result.is_success(), "formation stage succeeds without raw topology store")
	_assert(
		working_set.generated_products.has(GeneratedWorldChunk.FORMATION_PRODUCT_SET_KEY),
		"formation stage emits product set from canonical TopologyProjectionSet"
	)
	provider.free()


func test_formation_dependencies_expand_internal_topology_requests() -> void:
	var definition := WorldDefinition.new()
	definition.world_definition_id = "formation_dependency_smoke"
	definition.world_definition_version = 1
	definition.world_seed = 42
	definition.generation_settings = _default_generation_settings()
	definition.stage_ids = PackedStringArray([
		NativeChunkGenerationStage.STAGE_ID,
		NativeFormationProductStageScript.STAGE_ID,
	])
	definition.layer_schema_ids = PackedStringArray(["ground", "solid"])
	definition.requested_topology_projections = PackedStringArray(["ground"])
	definition.requested_formation_products = PackedStringArray(["solid"])
	definition.requested_product_set = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
	var provider := DefinitionProvider.new()
	provider.definition = definition
	var snapshot := definition.compile_snapshot()
	var context := _context_for_snapshot(snapshot, Vector3i(2, 0, 2))
	var pipeline := GenerationPipeline.from_stages([
		NativeChunkGenerationStage.from_session(provider),
		NativeFormationProductStageScript.from_session(provider)
	])
	var working_set := pipeline.run(snapshot, context)
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)

	_assert(
		snapshot.internal_required_topology_projections == PackedStringArray(["ground", "solid"]),
		"snapshot expands internal topology requests from formation dependencies"
	)
	_assert(
		world_chunk.topology_projection_set.get("projection_ids", PackedStringArray()) == PackedStringArray(["ground", "solid"]),
		"canonical TopologyProjectionSet carries internal topology dependencies"
	)
	_assert(
		compatibility_result.get("topology_layers", {}).keys() == ["ground"],
		"compatibility adapter exposes only public requested topology projections"
	)
	_assert(
		world_chunk.formation_products.get("product_ids", PackedStringArray()) == PackedStringArray(["solid_formation"]),
		"formation stage emits requested formation dependency product"
	)
	provider.free()


func test_unknown_formation_product_fails_snapshot_validation() -> void:
	var definition := WorldDefinition.new()
	definition.world_definition_id = "unknown_formation_dependency_smoke"
	definition.world_definition_version = 1
	definition.requested_product_set = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
	definition.requested_formation_products = PackedStringArray(["unknown_formation"])
	var validation := definition.validate_definition()

	_assert(not bool(validation.get("valid", true)), "unknown formation product invalidates definition")
	_assert(
		validation.get("issues", PackedStringArray()).has("unknown_formation_product_dependency_unknown_formation"),
		"unknown formation product reports explicit dependency issue"
	)


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


func _context_for_snapshot(snapshot: WorldDefinitionSnapshot, chunk_coord: Vector3i) -> GenerationContext:
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		16,
		1,
		snapshot.requested_product_set,
		{"formation_product_smoke": true}
	)
	return GenerationContext.from_snapshot_and_request(snapshot, request)


func _default_generation_settings() -> Dictionary:
	return {
		"world_seed": 42,
		"generator_version": 7,
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


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_formation_product_smoke failed: %s" % message)


class DefinitionProvider:
	extends Node

	var definition: WorldDefinition = null
	var session: RefCounted = null
	var WorldGenerationSessionScript := preload("res://scripts/world_generation/runtime/world_generation_session.gd")

	func _session() -> RefCounted:
		if session == null:
			session = WorldGenerationSessionScript.from_settings(definition.generation_settings)
		return session

	func generate_native_chunk_payload(chunk_coord: Vector3i) -> Dictionary:
		return _session().generate_native_chunk_payload(chunk_coord)

	func generate_native_formation_layer(chunk_coord: Vector3i, layer_id: String, layer_grid: Array) -> Dictionary:
		return _session().generate_native_formation_layer(chunk_coord, layer_id, layer_grid)

	func identity_for_chunk(
		chunk_coord: Vector3i,
		requested_products: PackedStringArray = PackedStringArray()
	) -> GeneratedChunkIdentity:
		return definition.compile_snapshot().identity_for_chunk(chunk_coord, requested_products)

	func generate_topology_layers_only(chunk_coord: Vector3i) -> Dictionary:
		return _session().generate_topology_layers_only(chunk_coord)

	func effective_chunk_size_cells() -> int:
		return int(definition.generation_settings.get("effective_chunk_size_cells", 16))
