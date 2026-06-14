extends RefCounted

class_name GeneratedChunkCachePolicy

const PRODUCT_TYPE := "GeneratedChunkCachePolicy"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/cache/generated_chunk_cache_policy.gd"
const GeneratedChunkCacheKeyScript := preload("res://scripts/world_generation/cache/generated_chunk_cache_key.gd")

var require_world_definition_identity: bool = true
var require_requested_product_set: bool = true
var allow_legacy_key_fallback: bool = true
var max_entries: int = 256
var metadata: Dictionary = {}


static func default_policy() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(true, true, true)


static func strict_policy() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(true, true, false)


static func from_parts(
	p_require_world_definition_identity: bool = true,
	p_require_requested_product_set: bool = true,
	p_allow_legacy_key_fallback: bool = true,
	p_metadata: Dictionary = {},
	p_max_entries: int = 256
) -> RefCounted:
	var policy: RefCounted = load(SELF_SCRIPT_PATH).new()
	return policy.configure(
		p_require_world_definition_identity,
		p_require_requested_product_set,
		p_allow_legacy_key_fallback,
		p_metadata,
		p_max_entries
	)


func configure(
	p_require_world_definition_identity: bool = true,
	p_require_requested_product_set: bool = true,
	p_allow_legacy_key_fallback: bool = true,
	p_metadata: Dictionary = {},
	p_max_entries: int = 256
) -> RefCounted:
	require_world_definition_identity = p_require_world_definition_identity
	require_requested_product_set = p_require_requested_product_set
	allow_legacy_key_fallback = p_allow_legacy_key_fallback
	max_entries = maxi(p_max_entries, 1)
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_policy() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		require_world_definition_identity,
		require_requested_product_set,
		allow_legacy_key_fallback,
		metadata,
		max_entries
	)


func key_from_identity(identity: GeneratedChunkIdentity) -> RefCounted:
	return GeneratedChunkCacheKeyScript.from_identity(identity)


func key_from_snapshot_and_chunk(
	snapshot: WorldDefinitionSnapshot,
	chunk_coord: Vector3i,
	requested_products: PackedStringArray = PackedStringArray()
) -> RefCounted:
	if snapshot == null:
		return GeneratedChunkCacheKeyScript.from_identity(null)
	return key_from_identity(snapshot.identity_for_chunk(chunk_coord, requested_products))


func can_store_identity(identity: GeneratedChunkIdentity) -> bool:
	if identity == null:
		return false
	var key: RefCounted = key_from_identity(identity)
	if require_world_definition_identity and not key.is_valid():
		return false
	if require_requested_product_set and key.requested_product_set.is_empty():
		return false
	return true


func to_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"require_world_definition_identity": require_world_definition_identity,
		"require_requested_product_set": require_requested_product_set,
		"allow_legacy_key_fallback": allow_legacy_key_fallback,
		"max_entries": max_entries,
		"metadata": metadata.duplicate(true),
		"signature_hash": signature_hash(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("GeneratedChunkCachePolicy:v1")
	h = GeneratedChunkIdentity.mix_hash(h, 1 if require_world_definition_identity else 0)
	h = GeneratedChunkIdentity.mix_hash(h, 1 if require_requested_product_set else 0)
	h = GeneratedChunkIdentity.mix_hash(h, 1 if allow_legacy_key_fallback else 0)
	h = GeneratedChunkIdentity.mix_hash(h, max_entries)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(metadata))
	return h


func is_valid() -> bool:
	return not _contains_runtime_object(metadata)


static func _contains_runtime_object(value: Variant) -> bool:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			for dictionary_key in dictionary_value.keys():
				if _contains_runtime_object(dictionary_key) or _contains_runtime_object(dictionary_value[dictionary_key]):
					return true
			return false
		TYPE_ARRAY:
			var array_value: Array = value
			for item in array_value:
				if _contains_runtime_object(item):
					return true
			return false
		TYPE_OBJECT:
			return value != null
		_:
			return false
