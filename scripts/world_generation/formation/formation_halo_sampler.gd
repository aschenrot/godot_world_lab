extends RefCounted

class_name FormationHaloSampler

const LAYER_SOLID := "solid"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/formation/formation_halo_sampler.gd"

var session: Object = null
var chunk_size_cells: int = 16
var loaded_chunks: Dictionary = {}
var chunk_cache: RefCounted = null
var use_chunk_cache: bool = false
var sample_cache: Variant = null
var allow_full_neighbor_generation: bool = false

var loaded_neighbor_lookup_count: int = 0
var chunk_cache_lookup_count: int = 0
var sample_cache_hit_count: int = 0
var topology_only_fallback_count: int = 0
var full_neighbor_generation_count: int = 0


static func from_context(
	p_session: Object,
	p_chunk_size_cells: int,
	p_loaded_chunks: Dictionary,
	p_chunk_cache: RefCounted,
	p_use_chunk_cache: bool,
	p_sample_cache: Variant
) -> RefCounted:
	var sampler: RefCounted = load(SELF_SCRIPT_PATH).new()
	return sampler.configure(
		p_session,
		p_chunk_size_cells,
		p_loaded_chunks,
		p_chunk_cache,
		p_use_chunk_cache,
		p_sample_cache
	)


func configure(
	p_session: Object,
	p_chunk_size_cells: int,
	p_loaded_chunks: Dictionary,
	p_chunk_cache: RefCounted,
	p_use_chunk_cache: bool,
	p_sample_cache: Variant
) -> RefCounted:
	session = p_session
	chunk_size_cells = maxi(p_chunk_size_cells, 1)
	loaded_chunks = p_loaded_chunks
	chunk_cache = p_chunk_cache
	use_chunk_cache = p_use_chunk_cache
	sample_cache = p_sample_cache
	return self


func sample_final_logic_cell(chunk_coord: Vector3i, local_cell: Vector2i) -> int:
	var world_cell := world_cell_from_chunk_local(chunk_coord, local_cell, chunk_size_cells)
	return sample_world_topology_cell(world_cell, chunk_coord.y, chunk_coord, LAYER_SOLID, [])


func sample_world_logic_cell(world_cell: Vector2i, chunk_y: int = 0) -> int:
	return sample_world_topology_cell(world_cell, chunk_y, Vector3i(2147483647, chunk_y, 2147483647), LAYER_SOLID, [])


func sample_world_topology_cell(
	world_cell: Vector2i,
	chunk_y: int,
	current_chunk_coord: Vector3i,
	layer_id: String,
	current_layer_grid: Array
) -> int:
	var owner := world_cell_owner_chunk_coord(world_cell, chunk_y, chunk_size_cells)
	var local_cell := local_cell_for_world_cell(world_cell, chunk_size_cells)
	if owner == current_chunk_coord and not current_layer_grid.is_empty():
		return grid_cell(current_layer_grid, local_cell)
	return grid_cell(topology_layer_for_sampling(owner, layer_id), local_cell)


func topology_layer_for_sampling(chunk_coord: Vector3i, layer_id: String) -> Array:
	var topology_layers := topology_layers_for_sampling(chunk_coord)
	if topology_layers.has(layer_id):
		return topology_layers[layer_id]
	if topology_layers.has(LAYER_SOLID):
		return topology_layers[LAYER_SOLID]
	return []


func topology_layers_for_sampling(chunk_coord: Vector3i) -> Dictionary:
	var identity: GeneratedChunkIdentity = session.identity_for_chunk(chunk_coord) if session != null else null
	var cache_key := identity.cache_key() if identity != null else _chunk_key(chunk_coord)
	var topology_cache_key := "topology:%s" % cache_key

	var cached_topology_layers := _load_sample_cache(topology_cache_key)
	if not cached_topology_layers.is_empty():
		sample_cache_hit_count += 1
		return cached_topology_layers

	var topology_layers := _topology_layers_from_loaded_neighbor(chunk_coord, cache_key)
	if topology_layers.is_empty():
		topology_layers = _topology_layers_from_chunk_cache(identity)
	if topology_layers.is_empty():
		topology_layers = _topology_layers_from_fallback(chunk_coord)

	_store_sample_cache(topology_cache_key, topology_layers, _chunk_key(chunk_coord))
	return topology_layers


func _topology_layers_from_loaded_neighbor(chunk_coord: Vector3i, expected_cache_key: String) -> Dictionary:
	var loaded_record: Dictionary = loaded_chunks.get(_chunk_key(chunk_coord), {})
	if loaded_record.is_empty():
		return {}
	if not expected_cache_key.is_empty() and loaded_record.get("cache_key", "") != expected_cache_key:
		return {}
	var canonical_record: Dictionary = loaded_record.get("canonical_record", {})
	var topology_layers: Dictionary = canonical_record.get("topology_layers", {})
	if topology_layers.is_empty():
		return {}
	loaded_neighbor_lookup_count += 1
	return topology_layers.duplicate(true)


func _topology_layers_from_chunk_cache(identity: GeneratedChunkIdentity) -> Dictionary:
	if not use_chunk_cache or chunk_cache == null or identity == null:
		return {}
	if not chunk_cache.has_canonical_record(identity):
		return {}
	chunk_cache_lookup_count += 1
	var topology_layers: Dictionary = chunk_cache.load_topology_layers_for_identity(identity) \
		if chunk_cache.has_method("load_topology_layers_for_identity") \
		else {}
	if not topology_layers.is_empty():
		return topology_layers
	return {}


func _topology_layers_from_fallback(chunk_coord: Vector3i) -> Dictionary:
	if session == null:
		return {}
	topology_only_fallback_count += 1
	if allow_full_neighbor_generation:
		full_neighbor_generation_count += 1
		var world_chunk: GeneratedWorldChunk = session.generate_world_chunk(chunk_coord, false, false)
		return world_chunk.to_canonical_record(true).get("topology_layers", {})
	return session.generate_topology_layers_only(chunk_coord)


func _load_sample_cache(cache_key: String) -> Dictionary:
	if sample_cache == null:
		return {}
	if typeof(sample_cache) == TYPE_OBJECT and sample_cache.has_method("load_topology_layers"):
		return sample_cache.call("load_topology_layers", cache_key)
	if typeof(sample_cache) == TYPE_DICTIONARY:
		var dictionary_cache: Dictionary = sample_cache
		if dictionary_cache.has(cache_key):
			return dictionary_cache[cache_key]
	return {}


func _store_sample_cache(cache_key: String, topology_layers: Dictionary, residency_key: String) -> void:
	if sample_cache == null:
		return
	if typeof(sample_cache) == TYPE_OBJECT and sample_cache.has_method("store_topology_layers"):
		sample_cache.call("store_topology_layers", cache_key, topology_layers, residency_key)
	elif typeof(sample_cache) == TYPE_DICTIONARY:
		var dictionary_cache: Dictionary = sample_cache
		dictionary_cache[cache_key] = topology_layers


static func world_cell_owner_chunk_coord(
	world_cell: Vector2i,
	chunk_y: int,
	p_chunk_size_cells: int
) -> Vector3i:
	return Vector3i(
		floor_div(world_cell.x, p_chunk_size_cells),
		chunk_y,
		floor_div(world_cell.y, p_chunk_size_cells)
	)


static func local_cell_for_world_cell(world_cell: Vector2i, p_chunk_size_cells: int) -> Vector2i:
	return Vector2i(
		positive_mod(world_cell.x, p_chunk_size_cells),
		positive_mod(world_cell.y, p_chunk_size_cells)
	)


static func world_cell_from_chunk_local(
	chunk_coord: Vector3i,
	local_cell: Vector2i,
	p_chunk_size_cells: int
) -> Vector2i:
	return Vector2i(
		chunk_coord.x * p_chunk_size_cells + local_cell.x,
		chunk_coord.z * p_chunk_size_cells + local_cell.y
	)


static func grid_cell(grid: Array, local_cell: Vector2i) -> int:
	if (
		local_cell.y < 0
		or local_cell.y >= grid.size()
		or local_cell.x < 0
		or local_cell.x >= int(grid[local_cell.y].size())
	):
		return 0
	return int(grid[local_cell.y][local_cell.x])


static func floor_div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	return floori(float(value) / float(divisor))


static func positive_mod(value: int, modulus: int) -> int:
	if modulus <= 0:
		return 0
	var result := value % modulus
	return result + modulus if result < 0 else result


static func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
