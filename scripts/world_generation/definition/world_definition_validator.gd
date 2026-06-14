extends RefCounted

class_name WorldDefinitionValidator


static func validate_definition(definition: WorldDefinition) -> Dictionary:
	if definition == null:
		return _validation_result(PackedStringArray(["missing_definition"]), PackedStringArray())
	return _validate_common(
		definition.world_definition_id,
		definition.world_definition_version,
		definition.domain_descriptor,
		definition.requested_product_set,
		definition.stage_ids,
		definition.layer_schema_ids,
		definition.feature_schema_ids,
		definition.continuity_policy_ids,
		definition.requested_topology_projections,
		definition.requested_formation_products
	)


static func validate_snapshot(snapshot: WorldDefinitionSnapshot) -> Dictionary:
	if snapshot == null:
		return _validation_result(PackedStringArray(["missing_snapshot"]), PackedStringArray())
	var result := _validate_common(
		snapshot.world_definition_id,
		snapshot.world_definition_version,
		snapshot.domain_descriptor,
		snapshot.requested_product_set,
		snapshot.stage_ids,
		snapshot.layer_schema_ids,
		snapshot.feature_schema_ids,
		snapshot.continuity_policy_ids,
		snapshot.requested_topology_projections,
		snapshot.requested_formation_products
	)
	var issues: PackedStringArray = result["issues"]
	if snapshot.world_definition_hash == 0:
		issues.append("missing_world_definition_hash")
	result["valid"] = issues.is_empty()
	result["issues"] = issues
	return result


static func _validate_common(
	world_definition_id: String,
	world_definition_version: int,
	domain_descriptor: String,
	requested_product_set: PackedStringArray,
	stage_ids: PackedStringArray,
	layer_schema_ids: PackedStringArray,
	feature_schema_ids: PackedStringArray,
	continuity_policy_ids: PackedStringArray,
	requested_topology_projections: PackedStringArray,
	requested_formation_products: PackedStringArray
) -> Dictionary:
	var issues := PackedStringArray()
	var notes := PackedStringArray()
	if world_definition_id.strip_edges().is_empty():
		issues.append("missing_world_definition_id")
	if world_definition_version <= 0:
		issues.append("bad_world_definition_version")
	var normalized_domain_descriptor := domain_descriptor.strip_edges()
	if not WorldSpace.is_supported_domain_descriptor(normalized_domain_descriptor):
		issues.append("unsupported_domain_descriptor")
	else:
		var domain_contract := WorldSpace.domain_contract(normalized_domain_descriptor)
		if domain_contract == null or not domain_contract.is_valid():
			issues.append("invalid_domain_descriptor_contract")
	if requested_product_set.is_empty():
		issues.append("missing_requested_product_set")
	_add_array_findings("stage_ids", stage_ids, false, issues, notes)
	_add_array_findings("layer_schema_ids", layer_schema_ids, false, issues, notes)
	_add_array_findings("feature_schema_ids", feature_schema_ids, false, issues, notes)
	_add_array_findings("continuity_policy_ids", continuity_policy_ids, false, issues, notes)
	_add_array_findings("requested_topology_projections", requested_topology_projections, false, issues, notes)
	_add_array_findings("requested_formation_products", requested_formation_products, false, issues, notes)
	_add_array_findings("requested_product_set", requested_product_set, true, issues, notes)
	return _validation_result(issues, notes)


static func _add_array_findings(
	field_name: String,
	values: PackedStringArray,
	required: bool,
	issues: PackedStringArray,
	notes: PackedStringArray
) -> void:
	if values.is_empty():
		if required:
			issues.append("missing_%s" % field_name)
		else:
			notes.append("empty_%s" % field_name)
		return
	var seen: Dictionary = {}
	for index in range(values.size()):
		var value := String(values[index]).strip_edges()
		if value.is_empty():
			issues.append("empty_%s_%s" % [field_name, index])
		elif seen.has(value):
			issues.append("duplicate_%s_%s" % [field_name, value])
		else:
			seen[value] = true


static func _validation_result(issues: PackedStringArray, notes: PackedStringArray) -> Dictionary:
	return {
		"product_type": "WorldDefinitionValidationResult",
		"valid": issues.is_empty(),
		"issues": issues.duplicate(),
		"notes": notes.duplicate(),
	}
