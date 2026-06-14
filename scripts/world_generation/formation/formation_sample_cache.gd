extends RefCounted

class_name FormationSampleCache

const PRODUCT_TYPE := "FormationSampleCache"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/formation/formation_sample_cache.gd"

var max_entries: int = 64
var records: Dictionary = {}
var access_order: Dictionary = {}
var access_counter: int = 0
var hit_count: int = 0
var miss_count: int = 0
var eviction_count: int = 0


static func from_max_entries(p_max_entries: int = 64) -> RefCounted:
	var cache: RefCounted = load(SELF_SCRIPT_PATH).new()
	return cache.configure(p_max_entries)


func configure(p_max_entries: int = 64) -> RefCounted:
	max_entries = maxi(p_max_entries, 0)
	clear()
	return self


func set_max_entries(p_max_entries: int) -> void:
	max_entries = maxi(p_max_entries, 0)
	_prune_over_limit()


func has_topology_layers(cache_key: String) -> bool:
	return records.has(cache_key.strip_edges())


func load_topology_layers(cache_key: String) -> Dictionary:
	var normalized_key := cache_key.strip_edges()
	if normalized_key.is_empty() or not records.has(normalized_key):
		miss_count += 1
		return {}
	hit_count += 1
	_touch(normalized_key)
	var record: Dictionary = records[normalized_key]
	return record.get("topology_layers", {}).duplicate(true)


func store_topology_layers(
	cache_key: String,
	topology_layers: Dictionary,
	residency_key: String = ""
) -> void:
	var normalized_key := cache_key.strip_edges()
	if normalized_key.is_empty():
		return
	if max_entries <= 0:
		clear()
		return
	records[normalized_key] = {
		"topology_layers": topology_layers.duplicate(true),
		"residency_key": residency_key.strip_edges(),
	}
	_touch(normalized_key)
	_prune_over_limit()


func erase_residency(residency_key: String) -> void:
	var normalized_residency_key := residency_key.strip_edges()
	if normalized_residency_key.is_empty():
		return
	var keys := records.keys()
	for key in keys:
		var cache_key := String(key)
		var record: Dictionary = records.get(cache_key, {})
		if String(record.get("residency_key", "")) == normalized_residency_key:
			records.erase(cache_key)
			access_order.erase(cache_key)


func size() -> int:
	return records.size()


func clear() -> void:
	records.clear()
	access_order.clear()
	access_counter = 0


func reset_counters() -> void:
	hit_count = 0
	miss_count = 0
	eviction_count = 0


func to_diagnostics() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"max_entries": max_entries,
		"entries": records.size(),
		"hit_count": hit_count,
		"miss_count": miss_count,
		"eviction_count": eviction_count,
	}


func _touch(cache_key: String) -> void:
	access_counter += 1
	access_order[cache_key] = access_counter


func _prune_over_limit() -> void:
	if max_entries <= 0:
		clear()
		return
	while records.size() > max_entries:
		var oldest_key := _oldest_key()
		if oldest_key.is_empty():
			return
		records.erase(oldest_key)
		access_order.erase(oldest_key)
		eviction_count += 1


func _oldest_key() -> String:
	var oldest_key := ""
	var oldest_order := 9223372036854775807
	var keys := records.keys()
	keys.sort()
	for key in keys:
		var cache_key := String(key)
		var order := int(access_order.get(cache_key, 0))
		if order < oldest_order:
			oldest_order = order
			oldest_key = cache_key
	return oldest_key
