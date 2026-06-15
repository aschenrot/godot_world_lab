extends SceneTree

const ChunkProviderScript := preload("res://scripts/chunk_provider.gd")
var failed: bool = false


func _initialize() -> void:
	test_provider_legacy_wrapper_reports_migration_error()
	test_provider_generation_compatibility_reports_migration_error()
	test_provider_compatibility_helpers_are_removed_from_runtime()
	quit(1 if failed else 0)


func test_provider_legacy_wrapper_reports_migration_error() -> void:
	var provider: Node = _configured_provider()
	var representative_chunks: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, -1),
		Vector3i(-2, 0, 3),
	]

	for chunk_coord in representative_chunks:
		var provider_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
		_assert(
			provider_result.get("error", "") == "legacy_generation_runtime_removed",
			"provider legacy wrapper reports migration error for %s" % chunk_coord
		)

	provider.free()


func test_provider_generation_compatibility_reports_migration_error() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(2, 0, -2)
	var public_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)

	_assert(
		public_result.get("error", "") == "legacy_generation_runtime_removed",
		"public generation compatibility path reports migration error"
	)
	_assert(public_result.get("replacement", "") == "generate_world_chunk", "migration error names canonical replacement")
	provider.free()


func test_provider_compatibility_helpers_are_removed_from_runtime() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(1, 0, 1)
	var size: int = provider.effective_chunk_size_cells()
	var provider_solid: Array = provider._generate_smoothed_solid_layer(chunk_coord, size)
	var provider_terrain: Array = provider._generate_base_terrain_cells(chunk_coord, size, provider_solid)
	var provider_topology: Dictionary = provider._derive_topology_layers(provider_terrain)
	var provider_diagnostics: Dictionary = provider._terrain_diagnostics(provider_terrain, provider_topology)
	var logic_grid_result: Dictionary = provider._generation_result_from_logic_grid(provider.generate_chunk_logic_grid(chunk_coord))
	var canonical_solid: Array = provider.generate_chunk_logic_grid(chunk_coord)

	_assert(provider_solid.is_empty(), "provider solid-layer legacy helper is removed from runtime")
	_assert(provider_terrain.is_empty(), "provider terrain legacy helper is removed from runtime")
	_assert(provider_topology.is_empty(), "provider topology legacy helper is removed from runtime")
	_assert(
		provider_diagnostics.get("authority", "") == "generated_chunk_data_adapter",
		"provider diagnostics helper remains adapter-only"
	)
	_assert(logic_grid_result.has("logic_grid"), "logic-grid compatibility helper is explicit adapter output")
	_assert(not canonical_solid.is_empty(), "canonical provider solid topology remains available")
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
