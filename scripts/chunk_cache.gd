extends RefCounted

const GeneratedChunkCacheKeyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_key.gd")
const GeneratedChunkCachePolicyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_policy.gd")

var identity_records: Dictionary = {}
var legacy_records: Dictionary = {}
var cache_policy: RefCounted = GeneratedChunkCachePolicyScript.default_policy()
var identity_access_order: Dictionary = {}
var legacy_access_order: Dictionary = {}
var identity_access_counter: int = 0
var legacy_access_counter: int = 0
var canonical_hit_count: int = 0
var canonical_miss_count: int = 0
var canonical_eviction_count: int = 0
var legacy_hit_count: int = 0
var legacy_miss_count: int = 0
var legacy_eviction_count: int = 0


func has_identity(identity: GeneratedChunkIdentity) -> bool:
	return has_world_chunk(identity)


func has_world_chunk(identity: GeneratedChunkIdentity) -> bool:
	return _can_use_identity(identity) and identity_records.has(_identity_cache_key(identity))


func load_world_chunk_for_identity(identity: GeneratedChunkIdentity) -> GeneratedWorldChunk:
	if not _can_use_identity(identity):
		canonical_miss_count += 1
		return null
	var cache_key: String = _identity_cache_key(identity)
	var record: Dictionary = identity_records.get(cache_key, {})
	if record.is_empty() or not record.has("world_chunk"):
		canonical_miss_count += 1
		return null
	_touch_identity_record(cache_key)
	canonical_hit_count += 1
	return record["world_chunk"]


func store_world_chunk_for_identity(
	identity: GeneratedChunkIdentity,
	world_chunk: GeneratedWorldChunk
) -> void:
	if not _can_use_identity(identity) or world_chunk == null:
		return
	var cache_key: RefCounted = GeneratedChunkCacheKeyScript.from_identity(identity)
	var cache_key_string: String = cache_key.cache_key()
	identity_records[cache_key_string] = {
		"cache_key": cache_key.to_dictionary(),
		"identity": identity.to_dictionary(),
		"chunk_coord": identity.chunk_coord,
		"world_definition_id": identity.world_definition_id,
		"world_definition_version": identity.world_definition_version,
		"world_definition_hash": identity.world_definition_hash,
		"generation_settings_hash": identity.generation_settings_hash,
		"requested_product_set": identity.requested_product_set.duplicate(),
		"world_chunk": world_chunk,
		"truth_signature_hash": world_chunk.generated_truth_signature_hash(),
		"topology_projection_count": world_chunk.topology_projections.size(),
		"formation_product_count": _formation_product_count(world_chunk.formation_products),
	}
	_touch_identity_record(cache_key_string)
	_evict_identity_over_limit()


func load_generation_result_for_identity(identity: GeneratedChunkIdentity) -> Dictionary:
	if not _can_use_identity(identity):
		legacy_miss_count += 1
		return {}
	var cache_key: String = _legacy_identity_cache_key(identity)
	var record: Dictionary = legacy_records.get(cache_key, {})
	if not record.is_empty():
		_touch_legacy_record(cache_key)
		legacy_hit_count += 1
	else:
		legacy_miss_count += 1
	return _generation_result_from_record(record)


func store_generation_result_for_identity(
	identity: GeneratedChunkIdentity,
	generation_result: Dictionary
) -> void:
	if not _can_use_identity(identity):
		return
	var cache_key: RefCounted = GeneratedChunkCacheKeyScript.from_identity(identity)
	var cache_key_string: String = _legacy_identity_cache_key(identity)
	legacy_records[cache_key_string] = {
		"cache_key": cache_key.to_dictionary(),
		"identity": identity.to_dictionary(),
		"chunk_coord": identity.chunk_coord,
		"world_definition_id": identity.world_definition_id,
		"world_definition_version": identity.world_definition_version,
		"world_definition_hash": identity.world_definition_hash,
		"generation_settings_hash": identity.generation_settings_hash,
		"requested_product_set": identity.requested_product_set.duplicate(),
		"logic_grid": generation_result.get("logic_grid", []).duplicate(true),
		"generation_result": generation_result.duplicate(true),
		"legacy_identity_cache_key": true,
	}
	_touch_legacy_record(cache_key_string)
	_evict_legacy_over_limit()


func has_chunk(chunk_coord: Vector3i, generator_version: int, generation_settings_hash: int) -> bool:
	return legacy_records.has(_cache_key(chunk_coord, generator_version, generation_settings_hash))


func load_chunk(chunk_coord: Vector3i, generator_version: int, generation_settings_hash: int) -> Array:
	var cache_key: String = _cache_key(chunk_coord, generator_version, generation_settings_hash)
	var record: Dictionary = legacy_records.get(cache_key, {})
	if not record.is_empty():
		_touch_legacy_record(cache_key)
		legacy_hit_count += 1
	else:
		legacy_miss_count += 1
	var logic_grid: Array = record.get("logic_grid", [])
	return logic_grid.duplicate(true)


func load_generation_result(
	chunk_coord: Vector3i,
	generator_version: int,
	generation_settings_hash: int
) -> Dictionary:
	var cache_key: String = _cache_key(chunk_coord, generator_version, generation_settings_hash)
	var record: Dictionary = legacy_records.get(cache_key, {})
	if not record.is_empty():
		_touch_legacy_record(cache_key)
		legacy_hit_count += 1
	else:
		legacy_miss_count += 1
	return _generation_result_from_record(record)


func store_chunk(
	chunk_coord: Vector3i,
	generator_version: int,
	generation_settings_hash: int,
	logic_grid: Array
) -> void:
	store_generation_result(
		chunk_coord,
		generator_version,
		generation_settings_hash,
		{"logic_grid": logic_grid.duplicate(true)}
	)


func store_generation_result(
	chunk_coord: Vector3i,
	generator_version: int,
	generation_settings_hash: int,
	generation_result: Dictionary
) -> void:
	var cache_key: String = _cache_key(chunk_coord, generator_version, generation_settings_hash)
	legacy_records[cache_key] = {
		"chunk_coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": generation_settings_hash,
		"legacy_cache_key": true,
		"logic_grid": generation_result.get("logic_grid", []).duplicate(true),
		"generation_result": generation_result.duplicate(true),
	}
	_touch_legacy_record(cache_key)
	_evict_legacy_over_limit()


func entry_count() -> int:
	return identity_records.size() + legacy_records.size()


func identity_entry_count() -> int:
	return identity_records.size()


func legacy_entry_count() -> int:
	return legacy_records.size()


func clear() -> void:
	identity_records.clear()
	legacy_records.clear()
	identity_access_order.clear()
	legacy_access_order.clear()
	identity_access_counter = 0
	legacy_access_counter = 0
	canonical_hit_count = 0
	canonical_miss_count = 0
	canonical_eviction_count = 0
	legacy_hit_count = 0
	legacy_miss_count = 0
	legacy_eviction_count = 0


func diagnostics() -> Dictionary:
	return {
		"canonical_identity_records": identity_records.size(),
		"legacy_records": legacy_records.size(),
		"canonical_hit_count": canonical_hit_count,
		"canonical_miss_count": canonical_miss_count,
		"canonical_eviction_count": canonical_eviction_count,
		"legacy_hit_count": legacy_hit_count,
		"legacy_miss_count": legacy_miss_count,
		"legacy_eviction_count": legacy_eviction_count,
		"canonical_record_shape_totals": _canonical_record_shape_totals(),
	}


func _can_use_identity(identity: GeneratedChunkIdentity) -> bool:
	return cache_policy != null and cache_policy.can_store_identity(identity)


func _identity_cache_key(identity: GeneratedChunkIdentity) -> String:
	return GeneratedChunkCacheKeyScript.from_identity(identity).cache_key()


func _legacy_identity_cache_key(identity: GeneratedChunkIdentity) -> String:
	return "legacy_identity:%s" % _identity_cache_key(identity)


func _generation_result_from_record(record: Dictionary) -> Dictionary:
	if record.has("generation_result"):
		return record["generation_result"].duplicate(true)
	return {
		"logic_grid": record.get("logic_grid", []).duplicate(true),
	}


func _touch_identity_record(cache_key: String) -> void:
	if not identity_records.has(cache_key):
		return
	identity_access_counter += 1
	identity_access_order[cache_key] = identity_access_counter


func _touch_legacy_record(cache_key: String) -> void:
	if not legacy_records.has(cache_key):
		return
	legacy_access_counter += 1
	legacy_access_order[cache_key] = legacy_access_counter


func _evict_identity_over_limit() -> void:
	var limit := int(cache_policy.get("max_entries")) if cache_policy != null else 0
	if limit <= 0:
		identity_records.clear()
		identity_access_order.clear()
		return
	while identity_records.size() > limit:
		var oldest_key: String = _oldest_record_key(identity_records, identity_access_order)
		if oldest_key.is_empty():
			return
		identity_records.erase(oldest_key)
		identity_access_order.erase(oldest_key)
		canonical_eviction_count += 1


func _evict_legacy_over_limit() -> void:
	var limit := int(cache_policy.get("max_entries")) if cache_policy != null else 0
	if limit <= 0:
		legacy_records.clear()
		legacy_access_order.clear()
		return
	while legacy_records.size() > limit:
		var oldest_key: String = _oldest_record_key(legacy_records, legacy_access_order)
		if oldest_key.is_empty():
			return
		legacy_records.erase(oldest_key)
		legacy_access_order.erase(oldest_key)
		legacy_eviction_count += 1


func _oldest_record_key(records: Dictionary, record_access_order: Dictionary) -> String:
	var oldest_key: String = ""
	var oldest_order: int = 2147483647
	var keys := records.keys()
	keys.sort()
	for key in keys:
		var cache_key := String(key)
		var order := int(record_access_order.get(cache_key, 0))
		if order < oldest_order:
			oldest_order = order
			oldest_key = cache_key
	return oldest_key


func _cache_key(chunk_coord: Vector3i, generator_version: int, generation_settings_hash: int) -> String:
	return "%s:%s:%s:v%s:h%s" % [
		chunk_coord.x,
		chunk_coord.y,
		chunk_coord.z,
		generator_version,
		generation_settings_hash,
	]


func _formation_product_count(formation_products: Dictionary) -> int:
	if formation_products.has("product_ids"):
		var product_ids: PackedStringArray = formation_products.get("product_ids", PackedStringArray())
		return product_ids.size()
	if formation_products.has("products"):
		var products: Variant = formation_products.get("products", {})
		return products.size() if typeof(products) == TYPE_DICTIONARY else 0
	return formation_products.size()


func _canonical_record_shape_totals() -> Dictionary:
	var topology_projection_total := 0
	var formation_product_total := 0
	for cache_key in identity_records.keys():
		var record: Dictionary = identity_records[cache_key]
		topology_projection_total += int(record.get("topology_projection_count", 0))
		formation_product_total += int(record.get("formation_product_count", 0))
	return {
		"topology_projection_count": topology_projection_total,
		"formation_product_count": formation_product_total,
	}
