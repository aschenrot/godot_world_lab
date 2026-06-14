extends RefCounted

class_name WorldSpace

const DOMAIN_CELL_GRID_2D := "cell_grid_2d"
const DOMAIN_SURFACE_2_5D := "surface_2_5d"
const DOMAIN_STACKED_LAYERS := "stacked_layers"
const DOMAIN_VOLUME_GRID_3D := "volume_grid_3d"
const DOMAIN_GRAPH_REGION := "graph_region"
const DOMAIN_HYBRID := "hybrid"
const DOMAIN_CONTRACT_SCRIPT_PATH := "res://scripts/world_generation/context/domain_descriptor_contract.gd"

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
		"domain_contract": domain_contract_dictionary(domain_descriptor),
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


static func domain_contract(value: String) -> RefCounted:
	var normalized_value := value.strip_edges()
	var definitions := _domain_contract_definitions()
	if not definitions.has(normalized_value):
		return null
	var definition: Dictionary = definitions[normalized_value]
	return load(DOMAIN_CONTRACT_SCRIPT_PATH).from_parts(
		normalized_value,
		String(definition.get("coordinate_model", "")),
		String(definition.get("ownership_model", "")),
		String(definition.get("halo_model", "")),
		String(definition.get("sampling_model", "")),
		String(definition.get("continuity_model", "")),
		String(definition.get("projection_model", "")),
		String(definition.get("formation_model", "")),
		String(definition.get("outputs_model", "")),
		definition.get("metadata", {})
	)


static func domain_contract_dictionary(value: String) -> Dictionary:
	var contract := domain_contract(value)
	return contract.to_dictionary() if contract != null else {}


static func domain_contracts_by_descriptor() -> Dictionary:
	var contracts: Dictionary = {}
	for descriptor in supported_domain_descriptors():
		contracts[descriptor] = domain_contract_dictionary(descriptor)
	return contracts


static func domain_descriptor_contract_hash(value: String) -> int:
	var contract := domain_contract(value)
	return contract.signature_hash() if contract != null else 0


static func _domain_contract_definitions() -> Dictionary:
	return {
		DOMAIN_CELL_GRID_2D: {
			"coordinate_model": "vector2i_cell_xz_with_chunk_y",
			"ownership_model": "chunk_owned_rect2i",
			"halo_model": "rect2i_configurable_cell_halo",
			"sampling_model": "owned_bounds_expanded_by_halo_cells",
			"continuity_model": "cardinal_neighbor_cell_boundary_facts",
			"projection_model": "named_binary_topology_grids",
			"formation_model": "owned_halo_formation_grid",
			"outputs_model": "generated_world_chunk_with_generated_chunk_data_adapter",
			"metadata": {
				"implementation_status": "active_compatibility_domain",
				"bounds_type": "Rect2i",
			},
		},
		DOMAIN_SURFACE_2_5D: {
			"coordinate_model": "vector2i_surface_cell_with_height_samples",
			"ownership_model": "chunk_owned_surface_patch",
			"halo_model": "surface_patch_neighbor_sample_halo",
			"sampling_model": "surface_samples_plus_height_neighbors",
			"continuity_model": "height_and_material_boundary_facts",
			"projection_model": "surface_topology_views",
			"formation_model": "surface_formation_products",
			"outputs_model": "generated_world_chunk_product_sets",
			"metadata": {"implementation_status": "declared_contract_only"},
		},
		DOMAIN_STACKED_LAYERS: {
			"coordinate_model": "vector2i_cell_xz_with_layer_index",
			"ownership_model": "chunk_owned_layer_stack",
			"halo_model": "per_layer_cell_halo",
			"sampling_model": "owned_layer_cells_expanded_by_halo",
			"continuity_model": "horizontal_and_vertical_layer_boundary_facts",
			"projection_model": "stacked_topology_views",
			"formation_model": "layered_formation_products",
			"outputs_model": "generated_world_chunk_product_sets",
			"metadata": {"implementation_status": "declared_contract_only"},
		},
		DOMAIN_VOLUME_GRID_3D: {
			"coordinate_model": "vector3i_voxel_cell",
			"ownership_model": "chunk_owned_aabb_voxels",
			"halo_model": "aabb_configurable_voxel_halo",
			"sampling_model": "owned_voxels_expanded_by_halo",
			"continuity_model": "six_face_voxel_boundary_facts",
			"projection_model": "volume_topology_views",
			"formation_model": "volume_formation_products",
			"outputs_model": "generated_world_chunk_product_sets",
			"metadata": {"implementation_status": "declared_contract_only"},
		},
		DOMAIN_GRAPH_REGION: {
			"coordinate_model": "region_graph_node_edge_ids",
			"ownership_model": "chunk_owned_graph_region",
			"halo_model": "adjacent_region_edge_halo",
			"sampling_model": "owned_region_plus_adjacent_edges",
			"continuity_model": "graph_adjacency_boundary_facts",
			"projection_model": "graph_topology_views",
			"formation_model": "graph_region_formation_products",
			"outputs_model": "generated_world_chunk_product_sets",
			"metadata": {"implementation_status": "declared_contract_only"},
		},
		DOMAIN_HYBRID: {
			"coordinate_model": "declared_mixed_domain_coordinates",
			"ownership_model": "declared_mixed_domain_ownership",
			"halo_model": "declared_mixed_domain_halo",
			"sampling_model": "declared_mixed_domain_sampling",
			"continuity_model": "declared_mixed_domain_continuity",
			"projection_model": "declared_mixed_domain_topology_views",
			"formation_model": "declared_mixed_domain_formation_products",
			"outputs_model": "generated_world_chunk_product_sets",
			"metadata": {"implementation_status": "declared_contract_only"},
		},
	}


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
