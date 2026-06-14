extends RefCounted

class_name TopologyView

const PRODUCT_TYPE := "TopologyView"
const SELF_SCRIPT_PATH := "res://scripts/world_generation/topology/topology_view.gd"

var view_id: String = ""
var domain_descriptor: String = WorldSpace.DOMAIN_CELL_GRID_2D
var projection_ids: PackedStringArray = PackedStringArray()
var coordinate_model: String = ""
var ownership_model: String = ""
var halo_model: String = ""
var sampling_model: String = ""
var continuity_model: String = ""
var projection_model: String = ""
var formation_model: String = ""
var outputs_model: String = ""
var domain_contract_signature_hash: int = 0
var metadata: Dictionary = {}


static func from_domain_contract(
	p_view_id: String,
	domain_contract: RefCounted,
	p_projection_ids: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {}
) -> RefCounted:
	if domain_contract == null:
		return load(SELF_SCRIPT_PATH).from_parts(
			p_view_id,
			"",
			p_projection_ids,
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			0,
			p_metadata
		)
	return load(SELF_SCRIPT_PATH).from_parts(
		p_view_id,
		domain_contract.descriptor_id,
		p_projection_ids,
		domain_contract.coordinate_model,
		domain_contract.ownership_model,
		domain_contract.halo_model,
		domain_contract.sampling_model,
		domain_contract.continuity_model,
		domain_contract.projection_model,
		domain_contract.formation_model,
		domain_contract.outputs_model,
		domain_contract.signature_hash(),
		p_metadata
	)


static func from_parts(
	p_view_id: String,
	p_domain_descriptor: String,
	p_projection_ids: PackedStringArray,
	p_coordinate_model: String,
	p_ownership_model: String,
	p_halo_model: String,
	p_sampling_model: String,
	p_continuity_model: String,
	p_projection_model: String,
	p_formation_model: String,
	p_outputs_model: String,
	p_domain_contract_signature_hash: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	var view: RefCounted = load(SELF_SCRIPT_PATH).new()
	return view.configure(
		p_view_id,
		p_domain_descriptor,
		p_projection_ids,
		p_coordinate_model,
		p_ownership_model,
		p_halo_model,
		p_sampling_model,
		p_continuity_model,
		p_projection_model,
		p_formation_model,
		p_outputs_model,
		p_domain_contract_signature_hash,
		p_metadata
	)


func configure(
	p_view_id: String,
	p_domain_descriptor: String,
	p_projection_ids: PackedStringArray,
	p_coordinate_model: String,
	p_ownership_model: String,
	p_halo_model: String,
	p_sampling_model: String,
	p_continuity_model: String,
	p_projection_model: String,
	p_formation_model: String,
	p_outputs_model: String,
	p_domain_contract_signature_hash: int = 0,
	p_metadata: Dictionary = {}
) -> RefCounted:
	view_id = p_view_id.strip_edges()
	domain_descriptor = p_domain_descriptor.strip_edges()
	projection_ids = _copy_string_array(p_projection_ids)
	coordinate_model = p_coordinate_model.strip_edges()
	ownership_model = p_ownership_model.strip_edges()
	halo_model = p_halo_model.strip_edges()
	sampling_model = p_sampling_model.strip_edges()
	continuity_model = p_continuity_model.strip_edges()
	projection_model = p_projection_model.strip_edges()
	formation_model = p_formation_model.strip_edges()
	outputs_model = p_outputs_model.strip_edges()
	domain_contract_signature_hash = p_domain_contract_signature_hash
	metadata = p_metadata.duplicate(true)
	return self


func duplicate_view() -> RefCounted:
	return load(SELF_SCRIPT_PATH).from_parts(
		view_id,
		domain_descriptor,
		projection_ids,
		coordinate_model,
		ownership_model,
		halo_model,
		sampling_model,
		continuity_model,
		projection_model,
		formation_model,
		outputs_model,
		domain_contract_signature_hash,
		metadata
	)


func to_dictionary() -> Dictionary:
	var data := _payload_dictionary()
	data["signature_hash"] = signature_hash()
	return data


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("TopologyView:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(_payload_dictionary()))
	return h


func is_valid() -> bool:
	return not view_id.is_empty() \
		and WorldSpace.is_supported_domain_descriptor(domain_descriptor) \
		and not coordinate_model.is_empty() \
		and not ownership_model.is_empty() \
		and not halo_model.is_empty() \
		and not sampling_model.is_empty() \
		and not continuity_model.is_empty() \
		and not projection_model.is_empty() \
		and not formation_model.is_empty() \
		and not outputs_model.is_empty() \
		and domain_contract_signature_hash != 0 \
		and not _contains_runtime_object(metadata)


func _payload_dictionary() -> Dictionary:
	return {
		"product_type": PRODUCT_TYPE,
		"view_id": view_id,
		"domain_descriptor": domain_descriptor,
		"projection_ids": projection_ids.duplicate(),
		"coordinate_model": coordinate_model,
		"ownership_model": ownership_model,
		"halo_model": halo_model,
		"sampling_model": sampling_model,
		"continuity_model": continuity_model,
		"projection_model": projection_model,
		"formation_model": formation_model,
		"outputs_model": outputs_model,
		"domain_contract_signature_hash": domain_contract_signature_hash,
		"metadata": metadata.duplicate(true),
	}


static func _copy_string_array(input_values: PackedStringArray) -> PackedStringArray:
	var values := PackedStringArray()
	for index in range(input_values.size()):
		var value := String(input_values[index]).strip_edges()
		if value.is_empty():
			continue
		values.append(value)
	values.sort()
	return values


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
