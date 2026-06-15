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
	test_world_layer_set_get_layer_returns_mutation_safe_copy()
	test_generated_world_chunk_can_carry_semantic_layer_without_breaking_compatibility()
	test_generated_world_chunk_carries_semantic_world_layer_set()
	test_adapter_prefers_semantic_world_layer_set_without_legacy_result()
	test_adapter_reconstructs_terrain_cells_from_semantic_layer_without_legacy_result()
	test_adapter_falls_back_to_raw_legacy_terrain_layer_without_semantic_layer()
	test_legacy_runtime_wrappers_report_migration_errors()
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


func test_world_layer_set_get_layer_returns_mutation_safe_copy() -> void:
	var layer_set: RefCounted = WorldLayerSetScript.from_legacy_generation_result(
		_sample_generation_result(),
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	var retrieved_layer: RefCounted = layer_set.get_layer("legacy_terrain_cells")
	var original_signature: int = layer_set.signature_hash()
	retrieved_layer.layer_id = "mutated_layer_id"
	retrieved_layer.cells[0][0]["material"] = "mutated_material"

	var stored_layer: RefCounted = layer_set.get_layer("legacy_terrain_cells")
	_assert(layer_set.has_layer("legacy_terrain_cells"), "WorldLayerSet keeps original layer id after retrieved copy mutation")
	_assert(layer_set.signature_hash() == original_signature, "WorldLayerSet signature is stable after retrieved copy mutation")
	_assert(stored_layer.layer_id == "legacy_terrain_cells", "WorldLayerSet stored layer id is mutation-safe")
	_assert(
		stored_layer.cells[0][0]["material"] == "ground",
		"WorldLayerSet stored layer cells are mutation-safe"
	)


func test_generated_world_chunk_can_carry_semantic_layer_without_breaking_compatibility() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(1, 0, -1)
	var world_chunk: GeneratedWorldChunk = provider._world_generation_session().generate_world_chunk(
		chunk_coord,
		true,
		true,
		{"diagnostics_enabled": true}
	)
	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	var semantic_layer: Dictionary = world_chunk.world_layers.get(
		NativeChunkGenerationStage.SEMANTIC_NATIVE_TERRAIN_LAYER_KEY,
		{}
	)

	_assert(world_chunk.legacy_generation_result.is_empty(), "GeneratedWorldChunk omits legacy result")
	_assert(world_chunk.world_layers.has(GeneratedWorldChunk.NATIVE_TERRAIN_CELLS_KEY), "GeneratedWorldChunk keeps raw native terrain layer")
	_assert(not semantic_layer.is_empty(), "GeneratedWorldChunk carries semantic native terrain layer")
	_assert(semantic_layer.get("product_type", "") == WorldLayerScript.PRODUCT_TYPE, "semantic layer dictionary is a WorldLayer")
	_assert(
		_variant_signature(compatibility_result["terrain_cells"])
		== _variant_signature(world_chunk.world_layers[GeneratedWorldChunk.NATIVE_TERRAIN_CELLS_KEY]),
		"semantic layer does not change adapter terrain output"
	)
	provider.free()


func test_generated_world_chunk_carries_semantic_world_layer_set() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(1, 0, -1)
	var world_chunk: GeneratedWorldChunk = provider._world_generation_session().generate_world_chunk(
		chunk_coord,
		true,
		true,
		{"diagnostics_enabled": true}
	)
	var semantic_layer_set: Dictionary = world_chunk.world_layers.get(
		NativeChunkGenerationStage.SEMANTIC_WORLD_LAYER_SET_KEY,
		{}
	)
	var semantic_layers: Dictionary = semantic_layer_set.get("layers", {})
	var terrain_layer: Dictionary = semantic_layers.get("legacy_terrain_cells", {})

	_assert(not semantic_layer_set.is_empty(), "GeneratedWorldChunk carries semantic WorldLayerSet")
	_assert(
		semantic_layer_set.get("product_type", "") == WorldLayerSetScript.PRODUCT_TYPE,
		"semantic layer set dictionary is a WorldLayerSet"
	)
	_assert(semantic_layers.has("legacy_terrain_cells"), "semantic WorldLayerSet contains legacy terrain layer")
	_assert(
		_variant_signature(terrain_layer.get("cells", []))
		== _variant_signature(world_chunk.world_layers.get(GeneratedWorldChunk.NATIVE_TERRAIN_CELLS_KEY, [])),
		"semantic WorldLayerSet preserves native terrain cells"
	)
	provider.free()


func test_adapter_prefers_semantic_world_layer_set_without_legacy_result() -> void:
	var semantic_terrain_cells := _sample_terrain_cells()
	var fallback_terrain_cells := _fallback_terrain_cells()
	var semantic_generation_result := _sample_generation_result()
	semantic_generation_result["terrain_cells"] = semantic_terrain_cells
	var semantic_layer_set: Dictionary = WorldLayerSetScript.from_legacy_generation_result(
		semantic_generation_result,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	).to_dictionary()
	var fallback_layer: Dictionary = WorldLayerScript.from_legacy_terrain_cells(
		"legacy_terrain_cells",
		fallback_terrain_cells,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	).to_dictionary()
	var world_chunk := GeneratedWorldChunk.new().configure(
		null,
		_sample_bounds(),
		{
			LegacyChunkGenerationStage.SEMANTIC_WORLD_LAYER_SET_KEY: semantic_layer_set,
			LegacyChunkGenerationStage.SEMANTIC_LEGACY_TERRAIN_LAYER_KEY: fallback_layer,
			"legacy_terrain_cells": fallback_terrain_cells,
		},
		{},
		{},
		{},
		semantic_generation_result["topology_layers"],
		{},
		{},
		{},
		[],
		PackedStringArray(),
		{}
	)

	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	_assert(
		_variant_signature(compatibility_result["terrain_cells"]) == _variant_signature(semantic_terrain_cells),
		"GeneratedChunkDataAdapter prefers semantic WorldLayerSet without legacy result"
	)
	_assert(
		_variant_signature(compatibility_result["terrain_cells"]) != _variant_signature(fallback_terrain_cells),
		"GeneratedChunkDataAdapter reads WorldLayerSet before individual legacy terrain fallbacks"
	)


func test_adapter_reconstructs_terrain_cells_from_semantic_layer_without_legacy_result() -> void:
	var semantic_terrain_cells := _sample_terrain_cells()
	var fallback_terrain_cells := _fallback_terrain_cells()
	var semantic_layer: Dictionary = WorldLayerScript.from_legacy_terrain_cells(
		"legacy_terrain_cells",
		semantic_terrain_cells,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	).to_dictionary()
	var generation_result := _sample_generation_result()
	var world_chunk := GeneratedWorldChunk.new().configure(
		null,
		_sample_bounds(),
		{
			LegacyChunkGenerationStage.SEMANTIC_LEGACY_TERRAIN_LAYER_KEY: semantic_layer,
			"legacy_terrain_cells": fallback_terrain_cells,
		},
		{"legacy_debug_markers": [{"type": "semantic_no_legacy_result"}]},
		{},
		{},
		generation_result["topology_layers"],
		{},
		{},
		{"authority": "semantic_no_legacy_result"},
		[],
		PackedStringArray(),
		{}
	)

	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	_assert(
		_variant_signature(compatibility_result["terrain_cells"]) == _variant_signature(semantic_terrain_cells),
		"GeneratedChunkDataAdapter reconstructs terrain_cells from semantic legacy terrain layer without legacy result"
	)
	_assert(
		_variant_signature(compatibility_result["terrain_cells"]) != _variant_signature(fallback_terrain_cells),
		"GeneratedChunkDataAdapter prefers semantic legacy terrain layer over raw legacy layer"
	)
	_assert(
		_variant_signature(compatibility_result["logic_grid"])
		== _variant_signature(generation_result["topology_layers"]["solid"]),
		"GeneratedChunkDataAdapter still derives logic_grid compatibility alias without legacy result"
	)


func test_adapter_falls_back_to_raw_legacy_terrain_layer_without_semantic_layer() -> void:
	var fallback_terrain_cells := _fallback_terrain_cells()
	var generation_result := _sample_generation_result()
	var world_chunk := GeneratedWorldChunk.new().configure(
		null,
		_sample_bounds(),
		{"legacy_terrain_cells": fallback_terrain_cells},
		{},
		{},
		{},
		generation_result["topology_layers"],
		{},
		{},
		{},
		[],
		PackedStringArray(),
		{}
	)

	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	_assert(
		_variant_signature(compatibility_result["terrain_cells"]) == _variant_signature(fallback_terrain_cells),
		"GeneratedChunkDataAdapter falls back to raw legacy terrain layer without semantic layer"
	)


func test_legacy_runtime_wrappers_report_migration_errors() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(0, 0, 0)
	var legacy_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
	var pipeline_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	_assert(
		legacy_result.get("error", "") == "legacy_generation_runtime_removed",
		"private legacy runtime wrapper reports migration error"
	)
	_assert(
		pipeline_result.get("error", "") == "legacy_generation_runtime_removed",
		"public legacy runtime wrapper reports migration error"
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


func _fallback_terrain_cells() -> Array:
	return [
		[
			{"solid": true, "liquid": false, "walkable": false, "surface": "ground", "material": "fallback_rock"},
			{"solid": true, "liquid": false, "walkable": false, "surface": "ground", "material": "fallback_rock"},
		],
		[
			{"solid": true, "liquid": false, "walkable": false, "surface": "ground", "material": "fallback_rock"},
			{"solid": true, "liquid": false, "walkable": false, "surface": "ground", "material": "fallback_rock"},
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
