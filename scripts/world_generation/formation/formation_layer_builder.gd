extends RefCounted

class_name FormationLayerBuilder

const LAYER_GROUND := "ground"
const LAYER_SOLID := "solid"
const LAYER_WATER := "water"
const LAYER_CLIFF := "cliff"
const TOPOLOGY_LAYER_ORDER := [LAYER_GROUND, LAYER_WATER, LAYER_SOLID, LAYER_CLIFF]
const SELF_SCRIPT_PATH := "res://scripts/world_generation/formation/formation_layer_builder.gd"
const FormationHaloSamplerScript := preload("res://scripts/world_generation/formation/formation_halo_sampler.gd")

var session: Object = null
var sampler: RefCounted = null


static func from_sampler(
	p_session: Object,
	p_sampler: RefCounted
) -> RefCounted:
	var builder: RefCounted = load(SELF_SCRIPT_PATH).new()
	return builder.configure(p_session, p_sampler)


func configure(
	p_session: Object,
	p_sampler: RefCounted
) -> RefCounted:
	session = p_session
	sampler = p_sampler
	return self


func make_formation_layers(chunk_coord: Vector3i, topology_layers: Dictionary) -> Dictionary:
	var formation_layers: Dictionary = {}
	for layer_id in _ordered_layer_ids(topology_layers):
		formation_layers[layer_id] = make_formation_data_for_layer(
			chunk_coord,
			layer_id,
			topology_layers[layer_id]
		)
	return formation_layers


func make_formation_data(chunk_coord: Vector3i, logic_grid: Array) -> Dictionary:
	return make_formation_data_for_layer(chunk_coord, LAYER_SOLID, logic_grid)


func make_formation_data_for_layer(
	chunk_coord: Vector3i,
	layer_id: String,
	layer_grid: Array
) -> Dictionary:
	var size := _logic_grid_dimension(layer_grid)
	var formation_grid: Array = []
	var source_chunks: Dictionary = {}

	for local_y in range(-1, size):
		var row: Array = []
		for local_x in range(-1, size):
			var world_cell: Vector2i = FormationHaloSamplerScript.world_cell_from_chunk_local(
				chunk_coord,
				Vector2i(local_x, local_y),
				size
			)
			var owner: Vector3i = FormationHaloSamplerScript.world_cell_owner_chunk_coord(world_cell, chunk_coord.y, size)
			source_chunks[_chunk_key(owner)] = owner
			row.append(sampler.sample_world_topology_cell(
				world_cell,
				chunk_coord.y,
				chunk_coord,
				layer_id,
				layer_grid
			))
		formation_grid.append(row)

	return {
		"layer_id": layer_id,
		"formation_grid": formation_grid,
		"formation_origin_cell": Vector2i(-1, -1),
		"owned_visual_origin": Vector2i.ZERO,
		"owned_visual_size": Vector2i(size, size),
		"formation_mode": "owned_halo",
		"source_chunk_coords": _sorted_chunk_coords(source_chunks),
	}


func _ordered_layer_ids(topology_layers: Dictionary) -> Array:
	var ordered: Array[String] = []
	for layer_id in TOPOLOGY_LAYER_ORDER:
		if topology_layers.has(layer_id):
			ordered.append(layer_id)
	var extra: Array = topology_layers.keys()
	extra.sort()
	for layer_id in extra:
		if not ordered.has(String(layer_id)):
			ordered.append(String(layer_id))
	return ordered


func _logic_grid_dimension(logic_grid: Array) -> int:
	if logic_grid.is_empty():
		return session.effective_chunk_size_cells() if session != null else 16
	return logic_grid.size()


func _sorted_chunk_coords(chunks_by_key: Dictionary) -> Array:
	var keys := chunks_by_key.keys()
	keys.sort()
	var coords: Array[Vector3i] = []
	for key in keys:
		coords.append(chunks_by_key[key])
	return coords


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
