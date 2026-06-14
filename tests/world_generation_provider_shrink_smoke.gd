extends SceneTree

const ChunkProviderScript := preload("res://scripts/chunk_provider.gd")
const LegacyChunkGeneratorScript := preload("res://scripts/world_generation/legacy/legacy_chunk_generator.gd")

var failed: bool = false


func _initialize() -> void:
	test_provider_legacy_wrapper_matches_extracted_generator()
	test_provider_generation_compatibility_still_routes_through_pipeline()
	test_provider_compatibility_helpers_delegate_to_legacy_generator()
	quit(1 if failed else 0)


func test_provider_legacy_wrapper_matches_extracted_generator() -> void:
	var provider: Node = _configured_provider()
	var legacy_generator: RefCounted = LegacyChunkGeneratorScript.from_settings(provider._world_generation_settings_dictionary())
	var representative_chunks: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, -1),
		Vector3i(-2, 0, 3),
	]

	for chunk_coord in representative_chunks:
		var provider_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
		var generator_result: Dictionary = legacy_generator.generate_chunk_generation_result(chunk_coord)
		_assert(
			_variant_signature(provider_result) == _variant_signature(generator_result),
			"provider legacy wrapper matches extracted generator for %s" % chunk_coord
		)

	provider.free()


func test_provider_generation_compatibility_still_routes_through_pipeline() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(2, 0, -2)
	var legacy_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
	var public_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)

	_assert(
		_variant_signature(public_result) == _variant_signature(legacy_result),
		"public generation compatibility path still matches legacy wrapper"
	)
	_assert(public_result.has("terrain_cells"), "public generation still emits terrain cells")
	_assert(public_result.has("topology_layers"), "public generation still emits topology layers")
	_assert(public_result.has("logic_grid"), "public generation still restores logic_grid compatibility alias")
	provider.free()


func test_provider_compatibility_helpers_delegate_to_legacy_generator() -> void:
	var provider: Node = _configured_provider()
	var legacy_generator: RefCounted = LegacyChunkGeneratorScript.from_settings(provider._world_generation_settings_dictionary())
	var chunk_coord := Vector3i(1, 0, 1)
	var size: int = provider.effective_chunk_size_cells()
	var provider_solid: Array = provider._generate_smoothed_solid_layer(chunk_coord, size)
	var generator_solid: Array = legacy_generator.generate_smoothed_solid_layer(chunk_coord, size)
	var provider_terrain: Array = provider._generate_base_terrain_cells(chunk_coord, size, provider_solid)
	var generator_terrain: Array = legacy_generator.generate_base_terrain_cells(chunk_coord, size, generator_solid)
	var provider_topology: Dictionary = provider._derive_topology_layers(provider_terrain)
	var generator_topology: Dictionary = legacy_generator.derive_topology_layers(generator_terrain)
	var provider_diagnostics: Dictionary = provider._terrain_diagnostics(provider_terrain, provider_topology)
	var generator_diagnostics: Dictionary = legacy_generator.terrain_diagnostics(generator_terrain, generator_topology)
	var logic_grid_result: Dictionary = provider._generation_result_from_logic_grid(provider_topology["solid"])
	var generator_logic_grid_result: Dictionary = legacy_generator.generation_result_from_logic_grid(generator_topology["solid"])

	_assert(
		_variant_signature(provider_solid) == _variant_signature(generator_solid),
		"provider solid-layer helper delegates to extracted generator"
	)
	_assert(
		_variant_signature(provider_terrain) == _variant_signature(generator_terrain),
		"provider terrain helper delegates to extracted generator"
	)
	_assert(
		_variant_signature(provider_topology) == _variant_signature(generator_topology),
		"provider topology helper delegates to extracted generator"
	)
	_assert(
		_variant_signature(provider_diagnostics) == _variant_signature(generator_diagnostics),
		"provider terrain diagnostics helper delegates to extracted generator"
	)
	_assert(
		_variant_signature(logic_grid_result) == _variant_signature(generator_logic_grid_result),
		"provider logic-grid compatibility helper delegates to extracted generator"
	)
	provider.free()


func _configured_provider() -> Node:
	var provider: Node = ChunkProviderScript.new()
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


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_provider_shrink_smoke failed: %s" % message)
