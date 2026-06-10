extends RefCounted

class_name WorldSpace

const DOMAIN_CELL_GRID_2D := "cell_grid_2d"
const DOMAIN_SURFACE_2_5D := "surface_2_5d"
const DOMAIN_STACKED_LAYERS := "stacked_layers"
const DOMAIN_VOLUME_GRID_3D := "volume_grid_3d"
const DOMAIN_GRAPH_REGION := "graph_region"
const DOMAIN_HYBRID := "hybrid"

var chunk_size_cells: int = 16
var halo_cells: int = 1
var domain_descriptor: String = DOMAIN_CELL_GRID_2D


static func from_parts(
	p_chunk_size_cells: int,
	p_halo_cells: int = 1,
	p_domain_descriptor: String = DOMAIN_CELL_GRID_2D
) -> WorldSpace:
	var world_space := WorldSpace.new()
	return world_space.configure(p_chunk_size_cells, p_halo_cells, p_domain_descriptor)


func configure(
	p_chunk_size_cells: int,
	p_halo_cells: int = 1,
	p_domain_descriptor: String = DOMAIN_CELL_GRID_2D
) -> WorldSpace:
	chunk_size_cells = maxi(p_chunk_size_cells, 1)
	halo_cells = maxi(p_halo_cells, 0)
	domain_descriptor = p_domain_descriptor.strip_edges()
	if not is_supported_domain_descriptor(domain_descriptor):
		domain_descriptor = DOMAIN_CELL_GRID_2D
	return self


func effective_chunk_size_cells() -> int:
	return maxi(chunk_size_cells, 1)


func owned_cell_bounds_for_chunk(chunk_coord: Vector3i) -> Rect2i:
	var size := effective_chunk_size_cells()
	return Rect2i(
		Vector2i(chunk_coord.x * size, chunk_coord.z * size),
		Vector2i(size, size)
	)


func sample_cell_bounds_for_chunk(chunk_coord: Vector3i) -> Rect2i:
	var owned_bounds := owned_cell_bounds_for_chunk(chunk_coord)
	return Rect2i(
		owned_bounds.position - Vector2i(halo_cells, halo_cells),
		owned_bounds.size + Vector2i(halo_cells * 2, halo_cells * 2)
	)


func world_cell_from_chunk_local(chunk_coord: Vector3i, local_cell: Vector2i) -> Vector2i:
	var size := effective_chunk_size_cells()
	return Vector2i(chunk_coord.x * size + local_cell.x, chunk_coord.z * size + local_cell.y)


func local_cell_from_world_cell(world_cell: Vector2i) -> Vector2i:
	var size := effective_chunk_size_cells()
	return Vector2i(_positive_mod(world_cell.x, size), _positive_mod(world_cell.y, size))


func owner_chunk_coord_for_world_cell(world_cell: Vector2i, chunk_y: int = 0) -> Vector3i:
	var size := effective_chunk_size_cells()
	return Vector3i(_floor_div(world_cell.x, size), chunk_y, _floor_div(world_cell.y, size))


func local_cell_is_owned(local_cell: Vector2i) -> bool:
	var size := effective_chunk_size_cells()
	return local_cell.x >= 0 and local_cell.y >= 0 and local_cell.x < size and local_cell.y < size


func world_cell_is_owned_by_chunk(world_cell: Vector2i, chunk_coord: Vector3i) -> bool:
	return owned_cell_bounds_for_chunk(chunk_coord).has_point(world_cell)


func to_dictionary() -> Dictionary:
	return {
		"product_type": "WorldSpace",
		"chunk_size_cells": chunk_size_cells,
		"halo_cells": halo_cells,
		"domain_descriptor": domain_descriptor,
	}


static func supported_domain_descriptors() -> PackedStringArray:
	return PackedStringArray([
		DOMAIN_CELL_GRID_2D,
		DOMAIN_SURFACE_2_5D,
		DOMAIN_STACKED_LAYERS,
		DOMAIN_VOLUME_GRID_3D,
		DOMAIN_GRAPH_REGION,
		DOMAIN_HYBRID,
	])


static func is_supported_domain_descriptor(value: String) -> bool:
	return supported_domain_descriptors().has(value.strip_edges())


static func _floor_div(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	if value >= 0:
		return value / divisor
	return -int((-value + divisor - 1) / divisor)


static func _positive_mod(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0
	var result := value % divisor
	if result < 0:
		result += divisor
	return result
