extends SceneTree

const CountingProviderScript := preload("res://tests/world_generation_migration_gate_counting_provider.gd")

const PRE_SPLIT_FULL_GENERATION_CALLS_FOR_UNCACHED_HALO := 4
const POST_SPLIT_FULL_GENERATION_CALLS_FOR_UNCACHED_HALO := 1

var failed: bool = false


func _initialize() -> void:
	test_formation_halo_sampling_does_not_full_generate_neighbors()
	test_public_compatibility_output_fails_with_migration_error()
	test_halo_sampler_uses_loaded_neighbor_chunk_cache_and_sample_cache()
	test_settings_hash_reuses_and_invalidates_session_state()
	quit(1 if failed else 0)


func test_formation_halo_sampling_does_not_full_generate_neighbors() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(0, 0, 0)

	provider._load_chunk_content(chunk_coord)
	var session: Object = provider._world_generation_session()
	var loaded_record: Dictionary = provider.loaded_chunks.get(provider._chunk_key(chunk_coord), {})
	var canonical_record: Dictionary = loaded_record.get("canonical_record", {})

	_assert(
		provider.private_legacy_call_count == 0,
		"runtime load does not call legacy generation"
	)
	_assert(
		int(session.get("full_generation_call_count")) == 1,
		"runtime load performs one canonical chunk generation"
	)
	_assert(not canonical_record.is_empty(), "runtime load stores canonical record")
	_assert(canonical_record.has("topology_layers"), "canonical record carries topology layers")
	_assert(canonical_record.has("formation_products"), "canonical record carries formation products")
	_assert(not loaded_record.has("generated_chunk_data"), "runtime load does not store GeneratedChunkData")
	_assert(
		PRE_SPLIT_FULL_GENERATION_CALLS_FOR_UNCACHED_HALO
		> POST_SPLIT_FULL_GENERATION_CALLS_FOR_UNCACHED_HALO,
		"smoke records before/after full generation call count expectation"
	)
	provider.free()


func test_public_compatibility_output_fails_with_migration_error() -> void:
	var provider: Node = _configured_provider()
	var chunk_coord := Vector3i(2, 0, -2)
	var legacy_result: Dictionary = provider._generate_legacy_chunk_generation_result(chunk_coord)
	var public_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)

	_assert(
		legacy_result.get("error", "") == "legacy_generation_runtime_removed",
		"private legacy generation wrapper reports migration error"
	)
	_assert(
		public_result.get("error", "") == "legacy_generation_runtime_removed",
		"public legacy generation wrapper reports migration error"
	)
	_assert(public_result.get("replacement", "") == "generate_world_chunk", "migration error names canonical replacement")
	provider.free()


func test_halo_sampler_uses_loaded_neighbor_chunk_cache_and_sample_cache() -> void:
	var provider: Node = _configured_provider()
	provider.use_chunk_cache = true
	provider._ensure_cache()

	var loaded_neighbor := Vector3i(-1, 0, 0)
	provider._load_chunk_content(loaded_neighbor)
	provider.formation_sample_cache.clear()
	var loaded_sampler: Object = provider._formation_halo_sampler()
	var loaded_topology: Dictionary = loaded_sampler.call("topology_layers_for_sampling", loaded_neighbor)
	_assert(not loaded_topology.is_empty(), "halo sampler reads loaded neighbor topology")
	_assert(int(loaded_sampler.get("loaded_neighbor_lookup_count")) == 1, "halo sampler records loaded neighbor lookup")

	var cached_neighbor := Vector3i(0, 0, -1)
	var cached_identity: GeneratedChunkIdentity = provider._generated_chunk_identity_for_chunk(cached_neighbor)
	var cached_record: Dictionary = provider._generate_world_chunk_internal(cached_neighbor).to_canonical_record(true)
	provider.chunk_cache.store_canonical_record_for_identity(cached_identity, cached_record)
	provider.formation_sample_cache.clear()
	var cache_sampler: Object = provider._formation_halo_sampler()
	var cached_topology: Dictionary = cache_sampler.call("topology_layers_for_sampling", cached_neighbor)
	var cached_topology_again: Dictionary = cache_sampler.call("topology_layers_for_sampling", cached_neighbor)

	_assert(not cached_topology.is_empty(), "halo sampler reads chunk cache topology")
	_assert(
		_variant_signature(cached_topology) == _variant_signature(cached_topology_again),
		"halo sampler sample cache returns stable topology"
	)
	_assert(int(cache_sampler.get("chunk_cache_lookup_count")) == 1, "halo sampler records chunk cache lookup")
	_assert(int(cache_sampler.get("sample_cache_hit_count")) == 1, "halo sampler records sample cache hit")
	_assert(int(cache_sampler.get("full_neighbor_generation_count")) == 0, "halo sampler does not full-generate cached neighbor")
	provider.free()


func test_settings_hash_reuses_and_invalidates_session_state() -> void:
	var provider: Node = _configured_provider()
	var session_a: Object = provider._world_generation_session()
	var snapshot_a: Object = session_a.call("snapshot")
	var session_b: Object = provider._world_generation_session()
	var snapshot_b: Object = session_b.call("snapshot")

	_assert(session_a.get_instance_id() == session_b.get_instance_id(), "provider reuses session while settings are unchanged")
	_assert(snapshot_a.get_instance_id() == snapshot_b.get_instance_id(), "session reuses snapshot while settings are unchanged")

	provider.formation_sample_cache.store_topology_layers("topology:sentinel", {"solid": [[1]]}, "sentinel")
	provider.world_seed += 1
	var session_c: Object = provider._world_generation_session()
	var snapshot_c: Object = session_c.call("snapshot")

	_assert(session_c.get_instance_id() != session_a.get_instance_id(), "settings hash change invalidates session")
	_assert(snapshot_c.get_instance_id() != snapshot_a.get_instance_id(), "settings hash change invalidates snapshot")
	_assert(provider.formation_sample_cache_count() == 0, "settings hash change clears formation sample cache")
	provider.free()


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


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_provider_boundary_performance_smoke failed: %s" % message)
