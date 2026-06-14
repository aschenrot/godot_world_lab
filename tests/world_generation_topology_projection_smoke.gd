extends SceneTree

const CountingProviderScript := preload("res://tests/world_generation_migration_gate_counting_provider.gd")
const TopologyProjectionScript := preload("res://scripts/world_generation/topology/topology_projection.gd")
const TopologyProjectionSetScript := preload("res://scripts/world_generation/topology/topology_projection_set.gd")

var failed: bool = false


func _initialize() -> void:
	test_topology_projection_from_legacy_layer_is_data_only()
	test_topology_projection_set_from_legacy_layers_is_deterministic()
	test_generated_world_chunk_carries_topology_projection_set()
	test_adapter_preserves_topology_layers_and_logic_grid_from_projection_set()
	quit(1 if failed else 0)


func test_topology_projection_from_legacy_layer_is_data_only() -> void:
	var projection: RefCounted = TopologyProjectionScript.from_legacy_topology_layer(
		"solid",
		_sample_topology_layers()["solid"],
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	_assert(projection.is_valid(), "TopologyProjection from legacy layer is valid")
	_assert(projection.projection_id == "solid", "TopologyProjection keeps projection id")
	_assert(projection.dimensions() == Vector2i(2, 2), "TopologyProjection reports grid dimensions")
	_assert(
		_variant_signature(projection.grid) == _variant_signature(_sample_topology_layers()["solid"]),
		"TopologyProjection preserves grid cells"
	)

	var runtime_metadata_projection: RefCounted = TopologyProjectionScript.from_legacy_topology_layer(
		"solid",
		_sample_topology_layers()["solid"],
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D,
		{"node": Node.new()}
	)
	_assert(not runtime_metadata_projection.is_valid(), "TopologyProjection rejects runtime object metadata")
	runtime_metadata_projection.metadata["node"].free()


func test_topology_projection_set_from_legacy_layers_is_deterministic() -> void:
	var topology_layers := _sample_topology_layers()
	var projection_set_a: RefCounted = TopologyProjectionSetScript.from_legacy_topology_layers(
		topology_layers,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)
	var reordered_layers := {
		"water": topology_layers["water"],
		"solid": topology_layers["solid"],
		"cliff": topology_layers["cliff"],
		"ground": topology_layers["ground"],
	}
	var projection_set_b: RefCounted = TopologyProjectionSetScript.from_legacy_topology_layers(
		reordered_layers,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	)

	_assert(projection_set_a.is_valid(), "TopologyProjectionSet from legacy layers is valid")
	_assert(
		projection_set_a.projection_ids() == PackedStringArray(["cliff", "ground", "solid", "water"]),
		"TopologyProjectionSet projection ids are sorted deterministically"
	)
	_assert(
		projection_set_a.signature_hash() == projection_set_b.signature_hash(),
		"TopologyProjectionSet signature is deterministic regardless of input order"
	)
	_assert(
		_variant_signature(projection_set_a.to_legacy_topology_layers())
		== _variant_signature(topology_layers),
		"TopologyProjectionSet converts back to legacy topology_layers"
	)


func test_generated_world_chunk_carries_topology_projection_set() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(1, 0, -1)
	var working_set := _run_pipeline_for_provider(provider, chunk_coord)
	var world_chunk := GeneratedWorldChunk.from_working_set(working_set)
	var projection_set: Dictionary = world_chunk.topology_projection_set
	var projections: Dictionary = projection_set.get("projections", {})

	_assert(not projection_set.is_empty(), "GeneratedWorldChunk carries TopologyProjectionSet")
	_assert(
		projection_set.get("product_type", "") == TopologyProjectionSetScript.PRODUCT_TYPE,
		"topology projection set dictionary is a TopologyProjectionSet"
	)
	_assert(world_chunk.topology_projections.has("solid"), "GeneratedWorldChunk preserves raw solid topology projection")
	for projection_id in PackedStringArray(["ground", "water", "solid", "cliff"]):
		_assert(projections.has(projection_id), "TopologyProjectionSet contains %s projection" % projection_id)
		_assert(
			_variant_signature(projections[projection_id].get("grid", []))
			== _variant_signature(world_chunk.topology_projections[projection_id]),
			"TopologyProjectionSet %s grid matches raw topology projection" % projection_id
		)
	provider.free()


func test_adapter_preserves_topology_layers_and_logic_grid_from_projection_set() -> void:
	var topology_layers := _sample_topology_layers()
	var projection_set: Dictionary = TopologyProjectionSetScript.from_legacy_topology_layers(
		topology_layers,
		_sample_bounds(),
		WorldSpace.DOMAIN_CELL_GRID_2D
	).to_dictionary()
	projection_set.erase("topology_layers")
	var fallback_topology_layers := {
		"ground": [[0, 0], [0, 0]],
		"solid": [[1, 1], [1, 1]],
		"water": [[0, 0], [0, 0]],
		"cliff": [[0, 0], [0, 0]],
	}
	var world_chunk := GeneratedWorldChunk.new().configure(
		null,
		_sample_bounds(),
		{},
		{},
		{},
		{},
		fallback_topology_layers,
		projection_set,
		{},
		{},
		[],
		PackedStringArray(),
		{}
	)

	var compatibility_result := GeneratedChunkDataAdapter.generation_result_from_world_chunk(world_chunk)
	_assert(
		_variant_signature(compatibility_result["topology_layers"]) == _variant_signature(topology_layers),
		"GeneratedChunkDataAdapter preserves topology_layers from TopologyProjectionSet"
	)
	_assert(
		_variant_signature(compatibility_result["logic_grid"]) == _variant_signature(topology_layers["solid"]),
		"GeneratedChunkDataAdapter keeps logic_grid as solid topology alias from TopologyProjectionSet"
	)
	_assert(
		_variant_signature(compatibility_result["topology_layers"]["solid"])
		!= _variant_signature(fallback_topology_layers["solid"]),
		"GeneratedChunkDataAdapter prefers TopologyProjectionSet over raw topology fallback"
	)


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
		{"topology_projection_smoke": true}
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
		push_error("world_generation_topology_projection_smoke failed: %s" % message)
