extends RefCounted

const GeneratedChunkCacheKeyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_key.gd")
const GeneratedChunkCachePolicyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_policy.gd")

var records: Dictionary = {}
var cache_policy: RefCounted = GeneratedChunkCachePolicyScript.default_policy()
var record_access_order: Dictionary = {}
var access_counter: int = 0


func has_identity(identity: GeneratedChunkIdentity) -> bool:
	return _can_use_identity(identity) and records.has(_identity_cache_key(identity))


func load_generation_result_for_identity(identity: GeneratedChunkIdentity) -> Dictionary:
	if not _can_use_identity(identity):
		return {}
	var cache_key: String = _identity_cache_key(identity)
	var record: Dictionary = records.get(cache_key, {})
	if not record.is_empty():
		_touch_record(cache_key)
	return _generation_result_from_record(record)


func store_generation_result_for_identity(
	identity: GeneratedChunkIdentity,
	generation_result: Dictionary
) -> void:
	if not _can_use_identity(identity):
		return
	var cache_key: RefCounted = GeneratedChunkCacheKeyScript.from_identity(identity)
	var cache_key_string: String = cache_key.cache_key()
	records[cache_key_string] = {
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
	}
	_touch_record(cache_key_string)
	_evict_over_limit()


func has_chunk(chunk_coord: Vector3i, generator_version: int, generation_settings_hash: int) -> bool:
	return records.has(_cache_key(chunk_coord, generator_version, generation_settings_hash))


func load_chunk(chunk_coord: Vector3i, generator_version: int, generation_settings_hash: int) -> Array:
	var cache_key: String = _cache_key(chunk_coord, generator_version, generation_settings_hash)
	var record: Dictionary = records.get(cache_key, {})
	if not record.is_empty():
		_touch_record(cache_key)
	var logic_grid: Array = record.get("logic_grid", [])
	return logic_grid.duplicate(true)


func load_generation_result(
	chunk_coord: Vector3i,
	generator_version: int,
	generation_settings_hash: int
) -> Dictionary:
	var cache_key: String = _cache_key(chunk_coord, generator_version, generation_settings_hash)
	var record: Dictionary = records.get(cache_key, {})
	if not record.is_empty():
		_touch_record(cache_key)
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
	records[cache_key] = {
		"chunk_coord": chunk_coord,
		"generator_version": generator_version,
		"generation_settings_hash": generation_settings_hash,
		"legacy_cache_key": true,
		"logic_grid": generation_result.get("logic_grid", []).duplicate(true),
		"generation_result": generation_result.duplicate(true),
	}
	_touch_record(cache_key)
	_evict_over_limit()


func entry_count() -> int:
	return records.size()


func clear() -> void:
	records.clear()
	record_access_order.clear()
	access_counter = 0


func _can_use_identity(identity: GeneratedChunkIdentity) -> bool:
	return cache_policy != null and cache_policy.can_store_identity(identity)


func _identity_cache_key(identity: GeneratedChunkIdentity) -> String:
	return GeneratedChunkCacheKeyScript.from_identity(identity).cache_key()


func _generation_result_from_record(record: Dictionary) -> Dictionary:
	if record.has("generation_result"):
		return record["generation_result"].duplicate(true)
	return {
		"logic_grid": record.get("logic_grid", []).duplicate(true),
	}


func _touch_record(cache_key: String) -> void:
	if not records.has(cache_key):
		return
	access_counter += 1
	record_access_order[cache_key] = access_counter


func _evict_over_limit() -> void:
	var limit := int(cache_policy.get("max_entries")) if cache_policy != null else 0
	if limit <= 0:
		clear()
		return
	while records.size() > limit:
		var oldest_key: String = _oldest_record_key()
		if oldest_key.is_empty():
			return
		records.erase(oldest_key)
		record_access_order.erase(oldest_key)


func _oldest_record_key() -> String:
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
