extends SceneTree

const ChunkProviderScript := preload("res://scripts/chunk_provider.gd")
const GeneratedChunkCacheKeyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_key.gd")
const GeneratedChunkCachePolicyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_policy.gd")

var failed: bool = false


func _initialize() -> void:
	test_cache_key_includes_world_definition_identity()
	test_chunk_cache_identity_prevents_product_and_definition_collisions()
	test_chunk_cache_evicts_oldest_record_when_entry_limit_is_exceeded()
	test_cache_policy_rejects_incomplete_identity()
	test_provider_cache_records_generated_identity()
	test_provider_formation_sample_cache_is_bounded()
	quit(1 if failed else 0)


func test_cache_key_includes_world_definition_identity() -> void:
	var identity_a := _identity(
		"cache_world",
		7,
		101,
		202,
		Vector3i(4, 0, -2),
		PackedStringArray(["generated_world_chunk", "formation_products"])
	)
	var identity_b := _identity(
		"cache_world",
		7,
		101,
		202,
		Vector3i(4, 0, -2),
		PackedStringArray(["formation_products", "generated_world_chunk"])
	)
	var key_a: RefCounted = GeneratedChunkCacheKeyScript.from_identity(identity_a)
	var key_b: RefCounted = GeneratedChunkCacheKeyScript.from_identity(identity_b)
	var key_data: Dictionary = key_a.to_dictionary()

	_assert(key_a.is_valid(), "GeneratedChunkCacheKey from identity is valid")
	_assert(key_a.cache_key() == key_b.cache_key(), "GeneratedChunkCacheKey normalizes requested product order")
	_assert(key_a.signature_hash() == key_b.signature_hash(), "GeneratedChunkCacheKey signature normalizes requested product order")
	_assert(key_data.get("chunk_coord", Vector3i.ZERO) == identity_a.chunk_coord, "GeneratedChunkCacheKey records chunk coord")
	_assert(key_data.get("world_definition_id", "") == identity_a.world_definition_id, "GeneratedChunkCacheKey records world definition id")
	_assert(
		int(key_data.get("world_definition_version", 0)) == identity_a.world_definition_version,
		"GeneratedChunkCacheKey records world definition version"
	)
	_assert(
		int(key_data.get("world_definition_hash", 0)) == identity_a.world_definition_hash,
		"GeneratedChunkCacheKey records world definition hash"
	)
	_assert(
		int(key_data.get("generation_settings_hash", 0)) == identity_a.generation_settings_hash,
		"GeneratedChunkCacheKey records generation settings hash"
	)


func test_chunk_cache_identity_prevents_product_and_definition_collisions() -> void:
	var Cache := load("res://scripts/chunk_cache.gd")
	var cache: RefCounted = Cache.new()
	var identity_a := _identity(
		"cache_world",
		3,
		111,
		222,
		Vector3i(0, 0, 0),
		PackedStringArray(["generated_world_chunk"])
	)
	var different_definition := _identity(
		"cache_world",
		3,
		999,
		222,
		Vector3i(0, 0, 0),
		PackedStringArray(["generated_world_chunk"])
	)
	var different_products := _identity(
		"cache_world",
		3,
		111,
		222,
		Vector3i(0, 0, 0),
		PackedStringArray(["generated_world_chunk", "diagnostics"])
	)
	var different_settings := _identity(
		"cache_world",
		3,
		111,
		333,
		Vector3i(0, 0, 0),
		PackedStringArray(["generated_world_chunk"])
	)
	var generation_result := _sample_generation_result("identity_a")

	cache.store_generation_result_for_identity(identity_a, generation_result)

	_assert(cache.has_identity(identity_a), "ChunkCache finds stored generated identity")
	_assert(not cache.has_identity(different_definition), "ChunkCache misses different world definition hash")
	_assert(not cache.has_identity(different_products), "ChunkCache misses different requested product set")
	_assert(not cache.has_identity(different_settings), "ChunkCache misses different generation settings hash")
	_assert(
		_variant_signature(cache.load_generation_result_for_identity(identity_a))
		== _variant_signature(generation_result),
		"ChunkCache loads generation result for matching generated identity"
	)


func test_chunk_cache_evicts_oldest_record_when_entry_limit_is_exceeded() -> void:
	var Cache := load("res://scripts/chunk_cache.gd")
	var cache: RefCounted = Cache.new()
	cache.cache_policy = GeneratedChunkCachePolicyScript.from_parts(true, true, true, {}, 2)
	var identity_a := _identity("cache_world", 3, 111, 222, Vector3i(0, 0, 0), PackedStringArray(["generated_world_chunk"]))
	var identity_b := _identity("cache_world", 3, 111, 222, Vector3i(1, 0, 0), PackedStringArray(["generated_world_chunk"]))
	var identity_c := _identity("cache_world", 3, 111, 222, Vector3i(2, 0, 0), PackedStringArray(["generated_world_chunk"]))

	cache.store_generation_result_for_identity(identity_a, _sample_generation_result("identity_a"))
	cache.store_generation_result_for_identity(identity_b, _sample_generation_result("identity_b"))
	cache.load_generation_result_for_identity(identity_a)
	cache.store_generation_result_for_identity(identity_c, _sample_generation_result("identity_c"))

	_assert(cache.entry_count() == 2, "ChunkCache respects policy max_entries")
	_assert(cache.has_identity(identity_a), "ChunkCache keeps recently accessed identity")
	_assert(not cache.has_identity(identity_b), "ChunkCache evicts oldest identity")
	_assert(cache.has_identity(identity_c), "ChunkCache stores newest identity")


func test_cache_policy_rejects_incomplete_identity() -> void:
	var strict_policy: RefCounted = GeneratedChunkCachePolicyScript.strict_policy()
	var incomplete_identity := _identity(
		"",
		0,
		0,
		0,
		Vector3i.ZERO,
		PackedStringArray()
	)
	var complete_identity := _identity(
		"cache_world",
		3,
		111,
		222,
		Vector3i(0, 0, 0),
		PackedStringArray(["generated_world_chunk"])
	)

	_assert(strict_policy.is_valid(), "GeneratedChunkCachePolicy is valid")
	_assert(not strict_policy.can_store_identity(incomplete_identity), "GeneratedChunkCachePolicy rejects incomplete identity")
	_assert(strict_policy.can_store_identity(complete_identity), "GeneratedChunkCachePolicy accepts complete identity")


func test_provider_cache_records_generated_identity() -> void:
	var provider: Node = ChunkProviderScript.new()
	provider.use_chunk_cache = true
	provider.chunk_size_cells = 16
	provider.generator_version = 7
	provider.world_seed = 42
	provider.wall_threshold_percent = 34
	provider.debug_force_chunk_border = false
	var chunk_coord := Vector3i(2, 0, -2)
	var identity_before: GeneratedChunkIdentity = provider._generated_chunk_identity_for_chunk(chunk_coord)

	provider._load_chunk_content(chunk_coord)
	var loaded_record: Dictionary = provider.loaded_chunks.get(provider._chunk_key(chunk_coord), {})
	_assert(provider.cache_miss_count == 1, "provider first identity cache load misses")
	_assert(provider.cache_entry_count() == 1, "provider first identity cache load stores one entry")
	_assert(loaded_record.get("cache_key", "") == identity_before.cache_key(), "loaded chunk record stores generated identity cache key")
	_assert(
		int(loaded_record.get("world_definition_hash", 0)) == identity_before.world_definition_hash,
		"loaded chunk record stores world definition hash"
	)
	_assert(
		_variant_signature(loaded_record.get("requested_product_set", PackedStringArray()))
		== _variant_signature(identity_before.requested_product_set),
		"loaded chunk record stores requested product set"
	)

	provider.loaded_chunks.clear()
	provider._load_chunk_content(chunk_coord)
	_assert(provider.cache_hit_count == 1, "provider same generated identity hits cache")

	provider.world_seed = 43
	var identity_after_seed_change: GeneratedChunkIdentity = provider._generated_chunk_identity_for_chunk(chunk_coord)
	provider._load_chunk_content(chunk_coord)
	_assert(identity_after_seed_change.cache_key() != identity_before.cache_key(), "world definition change changes provider cache key")
	_assert(provider.cache_miss_count == 2, "provider world definition change misses cache")
	_assert(provider.cache_entry_count() == 2, "provider keeps distinct cache entries for distinct world identities")

	provider.free()


func test_provider_formation_sample_cache_is_bounded() -> void:
	var provider: Node = ChunkProviderScript.new()
	provider.use_chunk_cache = false
	provider.formation_sample_cache_max_entries = 2
	provider.chunk_size_cells = 16
	provider.generator_version = 7
	provider.world_seed = 42
	provider.wall_threshold_percent = 34
	provider.debug_force_chunk_border = false

	provider._load_chunk_content(Vector3i(0, 0, 0))

	_assert(
		provider.formation_sample_cache_count() <= 2,
		"provider formation sample cache respects configured max entries"
	)
	provider.free()


func _identity(
	world_definition_id: String,
	world_definition_version: int,
	world_definition_hash: int,
	generation_settings_hash: int,
	chunk_coord: Vector3i,
	requested_product_set: PackedStringArray
) -> GeneratedChunkIdentity:
	return GeneratedChunkIdentity.from_parts(
		world_definition_id,
		world_definition_version,
		world_definition_hash,
		generation_settings_hash,
		chunk_coord,
		requested_product_set
	)


func _sample_generation_result(marker_type: String) -> Dictionary:
	var topology_layers := {
		"ground": [[1, 1], [0, 1]],
		"solid": [[0, 1], [0, 0]],
		"water": [[0, 0], [1, 0]],
		"cliff": [[0, 0], [0, 0]],
	}
	return {
		"terrain_cells": [
			[{"solid": false, "walkable": true}, {"solid": true, "walkable": false}],
			[{"solid": false, "walkable": true}, {"solid": false, "walkable": true}],
		],
		"topology_layers": topology_layers,
		"logic_grid": topology_layers["solid"].duplicate(true),
		"debug_markers": [{"type": marker_type}],
		"diagnostics": {"authority": "cache_identity_smoke"},
	}


func _variant_signature(value: Variant) -> int:
	return GeneratedChunkIdentity.stable_hash_variant(value)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_cache_identity_smoke failed: %s" % message)
