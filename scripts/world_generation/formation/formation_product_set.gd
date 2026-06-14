extends RefCounted

class_name FormationProductSet

const PRODUCT_TYPE := "FormationProductSet"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/formation/formation_product_set.gd"
const FormationProductScript := preload("res://scripts/world_generation/formation/formation_product.gd")

const INVALID_DUPLICATE_PRODUCT_IDS_KEY := "invalid_duplicate_product_ids"
const INVALID_PRODUCT_IDS_KEY := "invalid_product_ids"

var products_by_id: Dictionary = {}
var metadata: Dictionary = {}


static func from_parts(
	p_products_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	var product_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	return product_set.configure(p_products_by_id, p_metadata)


static func from_legacy_formation_layers(
	formation_layers: Dictionary,
	bounds: Dictionary = {},
	consumer_target: String = FormationProductScript.DEFAULT_CONSUMER_TARGET
) -> RefCounted:
	var product_set: RefCounted = load(SELF_SCRIPT_PATH).new()
	for layer_id in _ordered_layer_ids(formation_layers):
		var formation_data: Variant = formation_layers[layer_id]
		if typeof(formation_data) != TYPE_DICTIONARY:
			continue
		product_set.add_product(FormationProductScript.from_legacy_formation_layer(
			layer_id,
			formation_data,
			bounds,
			consumer_target
		))
	return product_set


func configure(
	p_products_by_id: Dictionary = {},
	p_metadata: Dictionary = {}
) -> RefCounted:
	products_by_id = {}
	metadata = p_metadata.duplicate(true)
	for product_key in p_products_by_id.keys():
		var product: Variant = p_products_by_id[product_key]
		if _is_formation_product(product):
			add_product(product, true)
	return self


func add_product(product: RefCounted, overwrite_existing: bool = false) -> void:
	if product == null:
		_record_invalid_product_id("")
		return
	var normalized_product_id: String = product.product_id.strip_edges()
	if normalized_product_id.is_empty() or not product.is_valid():
		_record_invalid_product_id(normalized_product_id)
		return
	if products_by_id.has(normalized_product_id) and not overwrite_existing:
		_record_duplicate_product_id(normalized_product_id)
		return
	products_by_id[normalized_product_id] = product.duplicate_product()


func has_product(product_id: String) -> bool:
	return products_by_id.has(product_id.strip_edges())


func get_product(product_id: String) -> RefCounted:
	var normalized_product_id := product_id.strip_edges()
	if not products_by_id.has(normalized_product_id):
		return null
	return products_by_id[normalized_product_id].duplicate_product()


func product_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for product_id in products_by_id.keys():
		ids.append(String(product_id))
	ids.sort()
	return ids


func duplicate_set() -> RefCounted:
	var copy: RefCounted = load(SELF_SCRIPT_PATH).new()
	copy.metadata = metadata.duplicate(true)
	for product_id in product_ids():
		copy.products_by_id[product_id] = products_by_id[product_id].duplicate_product()
	return copy


func to_legacy_formation_layers() -> Dictionary:
	var formation_layers: Dictionary = {}
	for product_id in product_ids():
		var product: RefCounted = products_by_id[product_id]
		formation_layers[product.layer_id] = product.to_legacy_formation_layer()
	return formation_layers


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("FormationProductSet:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	if _metadata_array(INVALID_DUPLICATE_PRODUCT_IDS_KEY).size() > 0:
		return false
	if _metadata_array(INVALID_PRODUCT_IDS_KEY).size() > 0:
		return false
	if _contains_runtime_object(metadata):
		return false
	for product_id in product_ids():
		var product: RefCounted = products_by_id[product_id]
		if product == null or not product.is_valid():
			return false
	return true


func _payload_dictionary() -> Dictionary:
	var products: Dictionary = {}
	for product_id in product_ids():
		var product: RefCounted = products_by_id[product_id]
		products[product_id] = product.to_dictionary() if product != null else {}
	return {
		"product_type": PRODUCT_TYPE,
		"product_ids": product_ids(),
		"products": products,
		"formation_layers": to_legacy_formation_layers(),
		"metadata": metadata.duplicate(true),
		"formation_product_count": product_ids().size(),
	}


func _record_duplicate_product_id(product_id: String) -> void:
	var duplicate_ids := _metadata_array(INVALID_DUPLICATE_PRODUCT_IDS_KEY)
	duplicate_ids.append(product_id)
	metadata[INVALID_DUPLICATE_PRODUCT_IDS_KEY] = duplicate_ids


func _record_invalid_product_id(product_id: String) -> void:
	var invalid_ids := _metadata_array(INVALID_PRODUCT_IDS_KEY)
	invalid_ids.append(product_id)
	metadata[INVALID_PRODUCT_IDS_KEY] = invalid_ids


func _metadata_array(key: String) -> Array:
	var value: Variant = metadata.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate()
	return []


func _is_formation_product(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT \
		and value != null \
		and value.has_method("duplicate_product") \
		and value.has_method("is_valid") \
		and value.has_method("to_dictionary")


static func _ordered_layer_ids(formation_layers: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for layer_id in formation_layers.keys():
		ids.append(String(layer_id))
	ids.sort()
	return ids


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
