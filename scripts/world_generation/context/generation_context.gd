extends RefCounted

class_name GenerationContext

var identity: GeneratedChunkIdentity = null
var world_seed: int = 0
var chunk_coord: Vector3i = Vector3i.ZERO
var chunk_size_cells: int = 16
var halo_cells: int = 1
var domain_descriptor: String = WorldSpace.DOMAIN_CELL_GRID_2D
var owned_cell_bounds: Rect2i = Rect2i()
var sample_cell_bounds: Rect2i = Rect2i()
var requested_product_set: PackedStringArray = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
var debug_flags: Dictionary = {}


static func from_snapshot_and_request(
	snapshot: WorldDefinitionSnapshot,
	request: ChunkGenerationRequest
) -> GenerationContext:
	if snapshot == null or request == null:
		return GenerationContext.new()
	var requested_products := request.requested_product_set
	if requested_products.is_empty():
		requested_products = snapshot.requested_product_set
	var next_identity := snapshot.identity_for_chunk(request.chunk_coord, requested_products)
	return from_parts(
		next_identity,
		snapshot.world_seed,
		request.chunk_size_cells,
		request.halo_cells,
		snapshot.domain_descriptor,
		request.debug_flags
	)


static func from_parts(
	p_identity: GeneratedChunkIdentity,
	p_world_seed: int,
	p_chunk_size_cells: int,
	p_halo_cells: int,
	p_domain_descriptor: String,
	p_debug_flags: Dictionary = {}
) -> GenerationContext:
	var context := GenerationContext.new()
	return context.configure(
		p_identity,
		p_world_seed,
		p_chunk_size_cells,
		p_halo_cells,
		p_domain_descriptor,
		p_debug_flags
	)


func configure(
	p_identity: GeneratedChunkIdentity,
	p_world_seed: int,
	p_chunk_size_cells: int,
	p_halo_cells: int,
	p_domain_descriptor: String,
	p_debug_flags: Dictionary = {}
) -> GenerationContext:
	identity = p_identity.duplicate_identity() if p_identity != null else null
	world_seed = p_world_seed
	chunk_coord = identity.chunk_coord if identity != null else Vector3i.ZERO
	chunk_size_cells = maxi(p_chunk_size_cells, 1)
	halo_cells = maxi(p_halo_cells, 0)
	domain_descriptor = p_domain_descriptor.strip_edges()
	if not WorldSpace.is_supported_domain_descriptor(domain_descriptor):
		domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	requested_product_set = identity.requested_product_set.duplicate() if identity != null else PackedStringArray()
	if requested_product_set.is_empty():
		requested_product_set = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
	debug_flags = p_debug_flags.duplicate(true)
	var world_space := WorldSpace.from_parts(chunk_size_cells, halo_cells, domain_descriptor)
	owned_cell_bounds = world_space.owned_cell_bounds_for_chunk(chunk_coord)
	sample_cell_bounds = world_space.sample_cell_bounds_for_chunk(chunk_coord)
	return self


func duplicate_context() -> GenerationContext:
	return from_parts(
		identity,
		world_seed,
		chunk_size_cells,
		halo_cells,
		domain_descriptor,
		debug_flags
	)


func world_space() -> WorldSpace:
	return WorldSpace.from_parts(chunk_size_cells, halo_cells, domain_descriptor)


func to_dictionary() -> Dictionary:
	return {
		"product_type": "GenerationContext",
		"identity": identity.to_dictionary() if identity != null else {},
		"world_seed": world_seed,
		"chunk_coord": chunk_coord,
		"chunk_size_cells": chunk_size_cells,
		"halo_cells": halo_cells,
		"domain_descriptor": domain_descriptor,
		"domain_contract": WorldSpace.domain_contract_dictionary(domain_descriptor),
		"owned_cell_bounds": owned_cell_bounds,
		"sample_cell_bounds": sample_cell_bounds,
		"requested_product_set": requested_product_set.duplicate(),
		"debug_flags": debug_flags.duplicate(true),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GenerationContext:v1")
	h = GeneratedChunkIdentity.mix_hash(h, identity.signature_hash() if identity != null else 0)
	h = GeneratedChunkIdentity.mix_hash(h, world_seed)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(chunk_coord))
	h = GeneratedChunkIdentity.mix_hash(h, chunk_size_cells)
	h = GeneratedChunkIdentity.mix_hash(h, halo_cells)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(domain_descriptor))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(owned_cell_bounds))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(sample_cell_bounds))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(requested_product_set))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(debug_flags))
	return h


func has_debug_flag(flag_id: String) -> bool:
	return bool(debug_flags.get(flag_id, false))


func requires_product(product_id: String) -> bool:
	var normalized := product_id.strip_edges()
	if normalized.is_empty():
		return false
	return requested_product_set.has(normalized)


func wants_report_products() -> bool:
	return requires_product("generation_diagnostics") \
		or has_debug_flag("diagnostics_enabled") \
		or has_debug_flag("profiling_enabled") \
		or has_debug_flag("diagnostics_provenance_smoke")
