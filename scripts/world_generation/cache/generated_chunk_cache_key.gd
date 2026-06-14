extends RefCounted

class_name GeneratedChunkCacheKey

const PRODUCT_TYPE := "GeneratedChunkCacheKey"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/cache/generated_chunk_cache_key.gd"

var chunk_coord: Vector3i = Vector3i.ZERO
var world_definition_id: String = ""
var world_definition_version: int = 0
var world_definition_hash: int = 0
var generation_settings_hash: int = 0
var requested_product_set: PackedStringArray = PackedStringArray()


static func from_identity(identity: GeneratedChunkIdentity) -> RefCounted:
	if identity == null:
		return load(SELF_SCRIPT_PATH).from_parts(
			Vector3i.ZERO,
			"",
			0,
			0,
			0,
			PackedStringArray()
		)
	return load(SELF_SCRIPT_PATH).from_parts(
		identity.chunk_coord,
		identity.world_definition_id,
		identity.world_definition_version,
		identity.world_definition_hash,
		identity.generation_settings_hash,
		identity.requested_product_set
	)


static func from_parts(
	p_chunk_coord: Vector3i,
	p_world_definition_id: String,
	p_world_definition_version: int,
	p_world_definition_hash: int,
	p_generation_settings_hash: int,
	p_requested_product_set: PackedStringArray
) -> RefCounted:
	var key: RefCounted = load(SELF_SCRIPT_PATH).new()
	return key.configure(
		p_chunk_coord,
		p_world_definition_id,
		p_world_definition_version,
		p_world_definition_hash,
		p_generation_settings_hash,
		p_requested_product_set
	)


static func from_dictionary(data: Dictionary) -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		data.get("chunk_coord", Vector3i.ZERO),
		String(data.get("world_definition_id", "")),
		int(data.get("world_definition_version", 0)),
		int(data.get("world_definition_hash", 0)),
		int(data.get("generation_settings_hash", 0)),
		_to_packed_string_array(data.get("requested_product_set", PackedStringArray()))
	)


func configure(
	p_chunk_coord: Vector3i,
	p_world_definition_id: String,
	p_world_definition_version: int,
	p_world_definition_hash: int,
	p_generation_settings_hash: int,
	p_requested_product_set: PackedStringArray
) -> RefCounted:
	chunk_coord = p_chunk_coord
	world_definition_id = p_world_definition_id.strip_edges()
	world_definition_version = p_world_definition_version
	world_definition_hash = p_world_definition_hash
	generation_settings_hash = p_generation_settings_hash
	requested_product_set = GeneratedChunkIdentity.normalized_requested_products(p_requested_product_set)
	return self


func duplicate_key() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		chunk_coord,
		world_definition_id,
		world_definition_version,
		world_definition_hash,
		generation_settings_hash,
		requested_product_set
	)


func to_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"chunk_coord": chunk_coord,
		"world_definition_id": world_definition_id,
		"world_definition_version": world_definition_version,
		"world_definition_hash": world_definition_hash,
		"generation_settings_hash": generation_settings_hash,
		"requested_product_set": requested_product_set.duplicate(),
		"cache_key": cache_key(),
		"signature_hash": signature_hash(),
	}


func cache_key() -> String:
	return "%s:v%s:dh%s:gh%s:%s:%s:%s:%s" % [
		world_definition_id,
		world_definition_version,
		world_definition_hash,
		generation_settings_hash,
		chunk_coord.x,
		chunk_coord.y,
		chunk_coord.z,
		"|".join(requested_product_set),
	]


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GeneratedChunkCacheKey:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(world_definition_id))
	h = GeneratedChunkIdentity.mix_hash(h, world_definition_version)
	h = GeneratedChunkIdentity.mix_hash(h, world_definition_hash)
	h = GeneratedChunkIdentity.mix_hash(h, generation_settings_hash)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(chunk_coord))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_product_set))
	return h


func is_valid() -> bool:
	return not world_definition_id.is_empty() \
		and world_definition_version != 0 \
		and world_definition_hash != 0 \
		and generation_settings_hash != 0 \
		and not requested_product_set.is_empty()


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	var result := PackedStringArray()
	if typeof(value) != TYPE_ARRAY:
		return result
	var array_value: Array = value
	for item in array_value:
		result.append(String(item))
	return result
