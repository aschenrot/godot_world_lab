extends RefCounted

var records: Dictionary = {}


func has_chunk(chunk_coord: Vector3i, generator_version: int) -> bool:
	return records.has(_cache_key(chunk_coord, generator_version))


func load_chunk(chunk_coord: Vector3i, generator_version: int) -> Array:
	var record: Dictionary = records.get(_cache_key(chunk_coord, generator_version), {})
	var logic_grid: Array = record.get("logic_grid", [])
	return logic_grid.duplicate(true)


func store_chunk(chunk_coord: Vector3i, generator_version: int, logic_grid: Array) -> void:
	records[_cache_key(chunk_coord, generator_version)] = {
		"chunk_coord": chunk_coord,
		"generator_version": generator_version,
		"logic_grid": logic_grid.duplicate(true),
	}


func entry_count() -> int:
	return records.size()


func clear() -> void:
	records.clear()


func _cache_key(chunk_coord: Vector3i, generator_version: int) -> String:
	return "%s:%s:%s:v%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z, generator_version]

