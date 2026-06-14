extends RefCounted

class_name DomainDescriptorContract

const PRODUCT_TYPE := "DomainDescriptorContract"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/context/domain_descriptor_contract.gd"

var descriptor_id: String = ""
var coordinate_model: String = ""
var ownership_model: String = ""
var halo_model: String = ""
var sampling_model: String = ""
var continuity_model: String = ""
var projection_model: String = ""
var formation_model: String = ""
var outputs_model: String = ""
var metadata: Dictionary = {}


static func from_parts(
	p_descriptor_id: String,
	p_coordinate_model: String,
	p_ownership_model: String,
	p_halo_model: String,
	p_sampling_model: String,
	p_continuity_model: String,
	p_projection_model: String,
	p_formation_model: String,
	p_outputs_model: String,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var contract: RefCounted = load(SELF_SCRIPT_PATH).new()
	return contract.configure(
		p_descriptor_id,
		p_coordinate_model,
		p_ownership_model,
		p_halo_model,
		p_sampling_model,
		p_continuity_model,
		p_projection_model,
		p_formation_model,
		p_outputs_model,
		p_metadata
	)


func configure(
	p_descriptor_id: String,
	p_coordinate_model: String,
	p_ownership_model: String,
	p_halo_model: String,
	p_sampling_model: String,
	p_continuity_model: String,
	p_projection_model: String,
	p_formation_model: String,
	p_outputs_model: String,
	p_metadata: Dictionary = {}
) -> RefCounted:
	descriptor_id = p_descriptor_id.strip_edges()
	coordinate_model = p_coordinate_model.strip_edges()
	ownership_model = p_ownership_model.strip_edges()
	halo_model = p_halo_model.strip_edges()
	sampling_model = p_sampling_model.strip_edges()
	continuity_model = p_continuity_model.strip_edges()
	projection_model = p_projection_model.strip_edges()
	formation_model = p_formation_model.strip_edges()
	outputs_model = p_outputs_model.strip_edges()
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_contract() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		descriptor_id,
		coordinate_model,
		ownership_model,
		halo_model,
		sampling_model,
		continuity_model,
		projection_model,
		formation_model,
		outputs_model,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("DomainDescriptorContract:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not descriptor_id.is_empty() \
		and WorldSpace.is_supported_domain_descriptor(descriptor_id) \
		and not coordinate_model.is_empty() \
		and not ownership_model.is_empty() \
		and not halo_model.is_empty() \
		and not sampling_model.is_empty() \
		and not continuity_model.is_empty() \
		and not projection_model.is_empty() \
		and not formation_model.is_empty() \
		and not outputs_model.is_empty() \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"descriptor_id": descriptor_id,
		"coordinate_model": coordinate_model,
		"ownership_model": ownership_model,
		"halo_model": halo_model,
		"sampling_model": sampling_model,
		"continuity_model": continuity_model,
		"projection_model": projection_model,
		"formation_model": formation_model,
		"outputs_model": outputs_model,
		"metadata": metadata.duplicate(true),
	}


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
