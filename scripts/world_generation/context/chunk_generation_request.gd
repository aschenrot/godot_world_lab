extends RefCounted

class_name ChunkGenerationRequest

const KIND_LOAD := "load"
const KIND_PREVIEW := "preview"

var request_id: int = -1
var request_kind: String = KIND_LOAD
var chunk_coord: Vector3i = Vector3i.ZERO
var requested_product_set: PackedStringArray = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
var debug_flags: Dictionary = {}
var chunk_size_cells: int = 16
var halo_cells: int = 1


static func from_provider_request(
	p_request_id: int,
	p_request_kind: String,
	p_chunk_coord: Vector3i,
	p_chunk_size_cells: int,
	p_halo_cells: int = 1,
	p_requested_product_set: PackedStringArray = PackedStringArray(),
	p_debug_flags: Dictionary = {}
) -> ChunkGenerationRequest:
	var request := ChunkGenerationRequest.new()
	return request.configure(
		p_request_id,
		p_request_kind,
		p_chunk_coord,
		p_chunk_size_cells,
		p_halo_cells,
		p_requested_product_set,
		p_debug_flags
	)


func configure(
	p_request_id: int,
	p_request_kind: String,
	p_chunk_coord: Vector3i,
	p_chunk_size_cells: int,
	p_halo_cells: int = 1,
	p_requested_product_set: PackedStringArray = PackedStringArray(),
	p_debug_flags: Dictionary = {}
) -> ChunkGenerationRequest:
	request_id = p_request_id
	request_kind = p_request_kind.strip_edges()
	if request_kind.is_empty():
		request_kind = KIND_LOAD
	chunk_coord = p_chunk_coord
	chunk_size_cells = maxi(p_chunk_size_cells, 1)
	halo_cells = maxi(p_halo_cells, 0)
	requested_product_set = GeneratedChunkIdentity.normalized_requested_products(p_requested_product_set)
	if requested_product_set.is_empty():
		requested_product_set = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
	debug_flags = p_debug_flags.duplicate(true)
	return self


func duplicate_request() -> ChunkGenerationRequest:
	return from_provider_request(
		request_id,
		request_kind,
		chunk_coord,
		chunk_size_cells,
		halo_cells,
		requested_product_set,
		debug_flags
	)


func to_dictionary() -> Dictionary:
	return {
		"product_type": "ChunkGenerationRequest",
		"request_id": request_id,
		"request_kind": request_kind,
		"chunk_coord": chunk_coord,
		"chunk_size_cells": chunk_size_cells,
		"halo_cells": halo_cells,
		"requested_product_set": requested_product_set.duplicate(),
		"debug_flags": debug_flags.duplicate(true),
		"generation_signature_hash": signature_hash(),
		"lifecycle_signature_hash": lifecycle_signature_hash(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("ChunkGenerationRequest:generation:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(chunk_coord))
	h = GeneratedChunkIdentity.mix_hash(h, chunk_size_cells)
	h = GeneratedChunkIdentity.mix_hash(h, halo_cells)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(requested_product_set))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(debug_flags))
	return h


func lifecycle_signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("ChunkGenerationRequest:lifecycle:v1")
	h = GeneratedChunkIdentity.mix_hash(h, request_id)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(request_kind))
	h = GeneratedChunkIdentity.mix_hash(h, signature_hash())
	return h
