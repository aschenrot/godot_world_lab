extends SceneTree

const CountingProviderScript := preload("res://tests/world_generation_migration_gate_counting_provider.gd")
const WorldLayerSchemaScript := preload("res://scripts/world_generation/layers/world_layer_schema.gd")
const WorldLayerScript := preload("res://scripts/world_generation/layers/world_layer.gd")
const WorldLayerSetScript := preload("res://scripts/world_generation/layers/world_layer_set.gd")

var failed: bool = false


func _initialize() -> void:
	test_world_layer_schema_validates_required_fields()
	test_world_layer_from_legacy_terrain_cells_preserves_cells()
	test_world_layer_set_from_legacy_generation_result_contains_legacy_terrain_layer()
	test_world_layer_set_signature_is_deterministic()
	test_world_layer_set_duplicate_layer_ids_record_invalid_without_overwrite()
	test_generated_world_chunk_can_carry_semantic_layer_without_breaking_compatibility()
	test_existing_migration_gate_smoke_still_passes()
	quit(1 if failed else 0)


func test_world_layer_schema_validates_required_fields() -> void:
	var valid_schema: RefCounted = WorldLayerSchemaScript.from_parts(
		"legacy_terrain_cells_schema",
		WorldLayerSchemaScript.KIND_TERRAIN_CELL_GRID,
		WorldSpace.DOMAIN_CELL_GRID_2D,
		WorldLayerSchemaScript.VALUE_KIND_DICTIONARY_CELL,
		WorldLayerSchemaScript.SOURCE_LEGACY_PROVIDER
	)
	_assert(valid_schema.is_valid(), "WorldLayerSchema validates supported required fields")

	var missing_schema_id: RefCounted = valid_schema.duplicate_schema()
	missing_schema_id.schema_id = ""
	_assert(not missing_schema_id.is_valid(), "WorldLayerSchema rejects empty schema_id")

	var unsupported_domain: RefCounted = valid_schema.duplicate_schema()
	unsupported_domain.domain_descriptor = "unsupported_domain"
	_assert(not unsupported_domain.is_valid(), "WorldLayerSchema rejects unsupported domain_descriptor")

	var runtime_object_metadata: RefCounted = valid_schema.duplicate_schema()
	runtime_object_metadata.metadata = {"node": Node.new()}
	_assert(not runtime_object_metadata.is_valid(), "WorldLayerSchema rejects runtime object metadata")
	runtime_object_metadata.metadata["node"].free()


func test_world_layer_from_legacy_terrain_cells_preserves_cells() -> void:
	var terrain_cells := _sample_terrain_cells()
	var layer: RefCounted = WorldLayerScript.from_legacy_terrain_cells(
		"legacy_terrain_cells",
		terrain_cells,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D,
		{"smoke": true}
	)
	_assert(layer.is_valid(), "WorldLayer from legacy terrain cells is valid")
	_assert(layer.layer_id == "legacy_terrain_cells", "WorldLayer keeps requested legacy layer_id")
	_assert(layer.dimensions() == Vector2i(2, 2), "WorldLayer reports legacy terrain cell dimensions")
	_assert(
		_variant_signature(layer.cells) == _variant_signature(terrain_cells),
		"WorldLayer preserves legacy terrain cell dictionaries"
	)


func test_world_layer_set_from_legacy_generation_result_contains_legacy_terrain_layer() -> void:
	var generation_result := _sample_generation_result()
	var layer_set: RefCounted = WorldLayerSetScript.from_legacy_generation_result(
		generation_result,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	_assert(layer_set.is_valid(), "WorldLayerSet from legacy generation result is valid")
	_assert(layer_set.has_layer("legacy_terrain_cells"), "WorldLayerSet contains legacy terrain layer")

	var terrain_layer: RefCounted = layer_set.get_layer("legacy_terrain_cells")
	_assert(terrain_layer != null, "WorldLayerSet returns legacy terrain layer")
	_assert(
		_variant_signature(terrain_layer.cells) == _variant_signature(generation_result["terrain_cells"]),
		"WorldLayerSet legacy layer preserves terrain_cells"
	)


func test_world_layer_set_signature_is_deterministic() -> void:
	var generation_result := _sample_generation_result()
	var layer_set_a: RefCounted = WorldLayerSetScript.from_legacy_generation_result(
		generation_result,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	var layer_set_b: RefCounted = WorldLayerSetScript.new()
	layer_set_b.add_layer(WorldLayerScript.from_legacy_terrain_cells(
		"z_debug_cells",
		_sample_terrain_cells(),
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	))
	layer_set_b.add_layer(layer_set_a.get_layer("legacy_terrain_cells"))
	var layer_set_c: RefCounted = WorldLayerSetScript.new()
	layer_set_c.add_layer(layer_set_a.get_layer("legacy_terrain_cells"))
	layer_set_c.add_layer(WorldLayerScript.from_legacy_terrain_cells(
		"z_debug_cells",
		_sample_terrain_cells(),
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	))

	_assert(
		layer_set_b.layer_ids() == PackedStringArray(["legacy_terrain_cells", "z_debug_cells"]),
		"WorldLayerSet layer_ids are sorted deterministically"
	)
	_assert(
		layer_set_b.signature_hash() == layer_set_c.signature_hash(),
		"WorldLayerSet signature is deterministic regardless of add order"
	)


func test_world_layer_set_duplicate_layer_ids_record_invalid_without_overwrite() -> void:
	var layer: RefCounted = WorldLayerScript.from_legacy_terrain_cells(
		"legacy_terrain_cells",
		_sample_terrain_cells(),
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	var layer_set: RefCounted = WorldLayerSetScript.new()
	layer_set.add_layer(layer)
	layer_set.add_layer(layer)
	_assert(not layer_set.is_valid(), "WorldLayerSet records duplicate layer ids invalid by default")
	_assert(
		layer_set.metadata.get(WorldLayerSetScript.INVALID_DUPLICATE_LAYER_IDS_KEY, []).has("legacy_terrain_cells"),
		"WorldLayerSet records duplicate layer id"
	)

	var overwrite_set: RefCounted = WorldLayerSetScript.new()
	overwrite_set.add_layer(layer)
	overwrite_set.add_layer(layer, true)
	_assert(overwrite_set.is_valid(), "WorldLayerSet allows explicit duplicate overwrite")


func test_generated_world_chunk_can_carry_semantic_layer_without_breaking_compatibility() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(1, 0, -1)
	var working_set := _run_pipeline_for_provider(provider, chunk_coord)
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	var semantic_layer: Dictionary = world_chunk.world_layers.get(
		LegacyChunkGenerationStage.SEMANTIC_LEGACY_TERRAIN_LAYER_KEY,
		{}
	)

	_assert(not world_chunk.legacy_generation_result.is_empty(), "GeneratedWorldChunk keeps legacy result")
	_assert(world_chunk.world_layers.has("legacy_terrain_cells"), "GeneratedWorldChunk keeps raw legacy terrain layer")
	_assert(not semantic_layer.is_empty(), "GeneratedWorldChunk carries semantic legacy terrain layer")
	_assert(semantic_layer.get("product_type", "") == WorldLayerScript.PRODUCT_TYPE, "semantic layer dictionary is a WorldLayer")
	_assert(
		_variant_signature(compatibility_result)
		== _variant_signature(world_chunk.legacy_generation_result),
		"semantic layer does not change compatibility generation result"
	)
	provider.free()


func test_existing_migration_gate_smoke_still_passes() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(0, 0, 0)
	var legacy_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
	var pipeline_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	_assert(
		_variant_signature(pipeline_result) == _variant_signature(legacy_result),
		"migration gate compatibility path still matches legacy generation"
	)
	provider.free()


func _run_pipeline_for_provider(provider: Node, chunk_coord: Vector3i) -> GenerationWorkingSet:
	var definition: WorldDefinition = provider._world_definition_for_generation()
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		chunk_coord,
		16,
		1,
		snapshot.requested_product_set,
		{"semantic_layer_smoke": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var pipeline := GenerationPipeline.from_stages([
		LegacyChunkGenerationStage.from_provider(provider)
	])
	return pipeline.run(snapshot, context)


func _configured_provider() -> Node:
	var provider: Node = CountingProviderScript.new()
	provider.chunk_size_cells = 16
	provider.generator_version = 7
	provider.world_seed = 42
	provider.wall_threshold_percent = 34
	provider.debug_force_chunk_border = false
	provider.smoothing_passes = 1
	provider.room_attempts = 3
	provider.room_min_size = 3
	provider.room_max_size = 6
	provider.terrain_noise_frequency = 0.065
	provider.liquid_noise_frequency = 0.045
	provider.solid_noise_frequency = 0.09
	provider.liquid_threshold_percent = 35
	provider.target_walkable_min_percent = 70
	provider.target_walkable_max_percent = 80
	provider.liquid_blocks_movement = true
	provider.debug_generation_markers_enabled = true
	provider.use_chunk_cache = false
	return provider


func _sample_generation_result() -> Dictionary:
	var terrain_cells := _sample_terrain_cells()
	var topology_layers := {
		"ground": [[1, 1], [0, 1]],
		"solid": [[0, 1], [0, 0]],
		"water": [[0, 0], [1, 0]],
		"cliff": [[0, 0], [0, 0]],
	}
	return {
		"terrain_cells": terrain_cells,
		"topology_layers": topology_layers,
		"logic_grid": topology_layers["solid"].duplicate(true),
		"debug_markers": [{"type": "semantic_layer_smoke"}],
		"diagnostics": {"authority": "semantic_layer_smoke"},
	}


func _sample_terrain_cells() -> Array:
	return [
		[
			{"solid": false, "liquid": false, "walkable": true, "surface": "ground", "material": "ground"},
			{"solid": true, "liquid": false, "walkable": false, "surface": "ground", "material": "rock"},
		],
		[
			{"solid": false, "liquid": true, "walkable": false, "surface": "water", "material": "water"},
			{"solid": false, "liquid": false, "walkable": true, "surface": "ground", "material": "ground"},
		],
	]


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
		push_error("world_generation_semantic_layer_smoke failed: %s" % message)
