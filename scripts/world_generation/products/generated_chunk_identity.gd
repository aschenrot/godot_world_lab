extends RefCounted

class_name GeneratedChunkIdentity

const SCHEMA_VERSION := 1
const PIPELINE_VERSION := 0
const PRODUCT_GENERATED_WORLD_CHUNK := "generated_world_chunk"
const HASH_SEED := 0x2d2816fe
const HASH_MASK := 0x7fffffff

var world_definition_id: String = ""
var world_definition_version: int = 0
var world_definition_hash: int = 0
var generation_settings_hash: int = 0
var chunk_coord: Vector3i = Vector3i.ZERO
var requested_product_set: PackedStringArray = PackedStringArray()
var schema_version: int = SCHEMA_VERSION
var pipeline_version: int = PIPELINE_VERSION


static func from_parts(
	p_world_definition_id: String,
	p_world_definition_version: int,
	p_world_definition_hash: int,
	p_generation_settings_hash: int,
	p_chunk_coord: Vector3i,
	p_requested_product_set: PackedStringArray
) -> GeneratedChunkIdentity:
	var identity := GeneratedChunkIdentity.new()
	return identity.configure(
		p_world_definition_id,
		p_world_definition_version,
		p_world_definition_hash,
		p_generation_settings_hash,
		p_chunk_coord,
		p_requested_product_set
	)


static func from_dictionary(data: Dictionary) -> GeneratedChunkIdentity:
	return from_parts(
		String(data.get("world_definition_id", "")),
		int(data.get("world_definition_version", 0)),
		int(data.get("world_definition_hash", 0)),
		int(data.get("generation_settings_hash", 0)),
		data.get("chunk_coord", Vector3i.ZERO),
		_to_packed_string_array(data.get("requested_product_set", PackedStringArray()))
	)


func configure(
	p_world_definition_id: String,
	p_world_definition_version: int,
	p_world_definition_hash: int,
	p_generation_settings_hash: int,
	p_chunk_coord: Vector3i,
	p_requested_product_set: PackedStringArray
) -> GeneratedChunkIdentity:
	world_definition_id = p_world_definition_id.strip_edges()
	world_definition_version = p_world_definition_version
	world_definition_hash = p_world_definition_hash
	generation_settings_hash = p_generation_settings_hash
	chunk_coord = p_chunk_coord
	requested_product_set = normalized_requested_products(p_requested_product_set)
	schema_version = SCHEMA_VERSION
	pipeline_version = PIPELINE_VERSION
	return self


func duplicate_identity() -> GeneratedChunkIdentity:
	return from_parts(
		world_definition_id,
		world_definition_version,
		world_definition_hash,
		generation_settings_hash,
		chunk_coord,
		requested_product_set
	)


func to_dictionary() -> Dictionary:
	return {
		"product_type": "GeneratedChunkIdentity",
		"schema_version": schema_version,
		"pipeline_version": pipeline_version,
		"world_definition_id": world_definition_id,
		"world_definition_version": world_definition_version,
		"world_definition_hash": world_definition_hash,
		"generation_settings_hash": generation_settings_hash,
		"chunk_coord": chunk_coord,
		"requested_product_set": requested_product_set.duplicate(),
		"product_signature": signature_hash(),
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
		_requested_products_key(requested_product_set),
	]


func signature_hash() -> int:
	var h := stable_hash_string("GeneratedChunkIdentity:v%s" % schema_version)
	h = mix_hash(h, stable_hash_string(world_definition_id))
	h = mix_hash(h, world_definition_version)
	h = mix_hash(h, world_definition_hash)
	h = mix_hash(h, generation_settings_hash)
	h = mix_hash(h, chunk_coord.x)
	h = mix_hash(h, chunk_coord.y)
	h = mix_hash(h, chunk_coord.z)
	h = mix_hash(h, stable_hash_variant(requested_product_set))
	h = mix_hash(h, pipeline_version)
	return h


func same_identity(other: GeneratedChunkIdentity) -> bool:
	if other == null:
		return false
	return signature_hash() == other.signature_hash() and cache_key() == other.cache_key()


static func normalized_requested_products(input_values: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	var values: Array[String] = []
	for index in range(input_values.size()):
		var value := String(input_values[index]).strip_edges()
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		values.append(value)
	values.sort()
	return PackedStringArray(values)


static func mix_hash(current: int, value: int) -> int:
	var mixed := current
	mixed = int((mixed ^ value) & HASH_MASK)
	mixed = int((mixed * 1664525 + 1013904223) & HASH_MASK)
	return mixed


static func stable_hash_string(value: String) -> int:
	var h := HASH_SEED
	for index in range(value.length()):
		h = mix_hash(h, value.unicode_at(index))
	return h


static func stable_hash_variant(value: Variant) -> int:
	var type_id := typeof(value)
	match type_id:
		TYPE_NIL:
			return 0
		TYPE_BOOL:
			return 1 if bool(value) else 0
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(round(float(value) * 1000000.0))
		TYPE_STRING, TYPE_STRING_NAME:
			return stable_hash_string(String(value))
		TYPE_VECTOR2I:
			var vector2i_value: Vector2i = value
			var h_vector2i := stable_hash_string("Vector2i")
			h_vector2i = mix_hash(h_vector2i, vector2i_value.x)
			h_vector2i = mix_hash(h_vector2i, vector2i_value.y)
			return h_vector2i
		TYPE_VECTOR3I:
			var vector3i_value: Vector3i = value
			var h_vector3i := stable_hash_string("Vector3i")
			h_vector3i = mix_hash(h_vector3i, vector3i_value.x)
			h_vector3i = mix_hash(h_vector3i, vector3i_value.y)
			h_vector3i = mix_hash(h_vector3i, vector3i_value.z)
			return h_vector3i
		TYPE_RECT2I:
			var rect2i_value: Rect2i = value
			var h_rect2i := stable_hash_string("Rect2i")
			h_rect2i = mix_hash(h_rect2i, stable_hash_variant(rect2i_value.position))
			h_rect2i = mix_hash(h_rect2i, stable_hash_variant(rect2i_value.size))
			return h_rect2i
		TYPE_PACKED_STRING_ARRAY:
			var string_values: PackedStringArray = value
			return stable_hash_packed_string_array(string_values)
		TYPE_ARRAY:
			var array_value: Array = value
			var h_array := stable_hash_string("Array:%s" % array_value.size())
			for item in array_value:
				h_array = mix_hash(h_array, stable_hash_variant(item))
			return h_array
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return _hash_dictionary(dictionary_value)
		_:
			return stable_hash_string(str(value))


static func stable_hash_packed_string_array(values: PackedStringArray) -> int:
	var h := stable_hash_string("PackedStringArray:%s" % values.size())
	for index in range(values.size()):
		h = mix_hash(h, stable_hash_string(String(values[index])))
	return h


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		return value
	var result := PackedStringArray()
	if typeof(value) != TYPE_ARRAY:
		return result
	var array_value: Array = value
	for item in array_value:
		result.append(String(item))
	return result


static func _hash_dictionary(dictionary_value: Dictionary) -> int:
	var values_by_key: Dictionary = {}
	var keys := PackedStringArray()
	for key in dictionary_value.keys():
		var key_string := String(key)
		keys.append(key_string)
		values_by_key[key_string] = dictionary_value[key]
	keys.sort()

	var h := stable_hash_string("Dictionary:%s" % keys.size())
	for index in range(keys.size()):
		var key_value := keys[index]
		h = mix_hash(h, stable_hash_string(key_value))
		h = mix_hash(h, stable_hash_variant(values_by_key[key_value]))
	return h


static func _requested_products_key(values: PackedStringArray) -> String:
	var normalized := normalized_requested_products(values)
	return "|".join(normalized)
