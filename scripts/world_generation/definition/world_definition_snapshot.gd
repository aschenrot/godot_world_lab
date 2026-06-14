extends RefCounted

class_name WorldDefinitionSnapshot

var world_definition_id: String = ""
var world_definition_version: int = 0
var world_definition_hash: int = 0
var generation_settings_hash: int = 0
var world_seed: int = 0
var domain_descriptor: String = WorldSpace.DOMAIN_CELL_GRID_2D
var generation_settings: Dictionary = {}
var stage_ids: PackedStringArray = PackedStringArray()
var layer_schema_ids: PackedStringArray = PackedStringArray()
var feature_schema_ids: PackedStringArray = PackedStringArray()
var continuity_policy_ids: PackedStringArray = PackedStringArray()
var requested_topology_projections: PackedStringArray = PackedStringArray()
var requested_formation_products: PackedStringArray = PackedStringArray()
var formation_product_dependencies: Dictionary = {}
var internal_required_topology_projections: PackedStringArray = PackedStringArray()
var requested_product_set: PackedStringArray = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])


static func from_dictionary(data: Dictionary) -> WorldDefinitionSnapshot:
	var snapshot := WorldDefinitionSnapshot.new()
	return snapshot.configure(
		String(data.get("world_definition_id", "")),
		int(data.get("world_definition_version", 0)),
		int(data.get("world_definition_hash", 0)),
		int(data.get("generation_settings_hash", 0)),
		int(data.get("world_seed", 0)),
		String(data.get("domain_descriptor", WorldSpace.DOMAIN_CELL_GRID_2D)),
		data.get("generation_settings", {}),
		_to_packed_string_array(data.get("stage_ids", PackedStringArray())),
		_to_packed_string_array(data.get("layer_schema_ids", PackedStringArray())),
		_to_packed_string_array(data.get("feature_schema_ids", PackedStringArray())),
		_to_packed_string_array(data.get("continuity_policy_ids", PackedStringArray())),
		_to_packed_string_array(data.get("requested_topology_projections", PackedStringArray())),
		_to_packed_string_array(data.get("requested_formation_products", PackedStringArray())),
		_to_packed_string_array(data.get("requested_product_set", PackedStringArray()))
	)


func configure(
	p_world_definition_id: String,
	p_world_definition_version: int,
	p_world_definition_hash: int,
	p_generation_settings_hash: int,
	p_world_seed: int,
	p_domain_descriptor: String,
	p_generation_settings: Dictionary,
	p_stage_ids: PackedStringArray,
	p_layer_schema_ids: PackedStringArray,
	p_feature_schema_ids: PackedStringArray,
	p_continuity_policy_ids: PackedStringArray,
	p_requested_topology_projections: PackedStringArray,
	p_requested_formation_products: PackedStringArray,
	p_requested_product_set: PackedStringArray
) -> WorldDefinitionSnapshot:
	world_definition_id = p_world_definition_id.strip_edges()
	world_definition_version = p_world_definition_version
	world_definition_hash = p_world_definition_hash
	generation_settings_hash = p_generation_settings_hash
	world_seed = p_world_seed
	domain_descriptor = p_domain_descriptor.strip_edges()
	if not WorldSpace.is_supported_domain_descriptor(domain_descriptor):
		domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	generation_settings = p_generation_settings.duplicate(true)
	stage_ids = _copy_string_array(p_stage_ids)
	layer_schema_ids = _copy_string_array(p_layer_schema_ids)
	feature_schema_ids = _copy_string_array(p_feature_schema_ids)
	continuity_policy_ids = _copy_string_array(p_continuity_policy_ids)
	requested_topology_projections = _copy_string_array(p_requested_topology_projections)
	requested_formation_products = _copy_string_array(p_requested_formation_products)
	formation_product_dependencies = dependencies_for_formation_products(requested_formation_products)
	internal_required_topology_projections = _derive_internal_required_topology_projections(
		requested_topology_projections,
		formation_product_dependencies
	)
	requested_product_set = GeneratedChunkIdentity.normalized_requested_products(p_requested_product_set)
	if requested_product_set.is_empty():
		requested_product_set = PackedStringArray([GeneratedChunkIdentity.PRODUCT_GENERATED_WORLD_CHUNK])
	return self


func duplicate_snapshot() -> WorldDefinitionSnapshot:
	return configure_duplicate(WorldDefinitionSnapshot.new())


func configure_duplicate(target: WorldDefinitionSnapshot) -> WorldDefinitionSnapshot:
	return target.configure(
		world_definition_id,
		world_definition_version,
		world_definition_hash,
		generation_settings_hash,
		world_seed,
		domain_descriptor,
		generation_settings,
		stage_ids,
		layer_schema_ids,
		feature_schema_ids,
		continuity_policy_ids,
		requested_topology_projections,
		requested_formation_products,
		requested_product_set
	)


func identity_for_chunk(
	chunk_coord: Vector3i,
	requested_products: PackedStringArray = PackedStringArray()
) -> GeneratedChunkIdentity:
	var products := requested_products
	if products.is_empty():
		products = requested_product_set
	return GeneratedChunkIdentity.from_parts(
		world_definition_id,
		world_definition_version,
		world_definition_hash,
		generation_settings_hash,
		chunk_coord,
		products
	)


func to_dictionary() -> Dictionary:
	return {
		"product_type": "WorldDefinitionSnapshot",
		"world_definition_id": world_definition_id,
		"world_definition_version": world_definition_version,
		"world_definition_hash": world_definition_hash,
		"generation_settings_hash": generation_settings_hash,
		"world_seed": world_seed,
		"domain_descriptor": domain_descriptor,
		"generation_settings": generation_settings.duplicate(true),
		"stage_ids": stage_ids.duplicate(),
		"layer_schema_ids": layer_schema_ids.duplicate(),
		"feature_schema_ids": feature_schema_ids.duplicate(),
		"continuity_policy_ids": continuity_policy_ids.duplicate(),
		"requested_topology_projections": requested_topology_projections.duplicate(),
		"requested_formation_products": requested_formation_products.duplicate(),
		"formation_product_dependencies": formation_product_dependencies.duplicate(true),
		"internal_required_topology_projections": internal_required_topology_projections.duplicate(),
		"requested_product_set": requested_product_set.duplicate(),
	}


func signature_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldDefinitionSnapshot:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(world_definition_id))
	h = GeneratedChunkIdentity.mix_hash(h, world_definition_version)
	h = GeneratedChunkIdentity.mix_hash(h, world_definition_hash)
	h = GeneratedChunkIdentity.mix_hash(h, generation_settings_hash)
	h = GeneratedChunkIdentity.mix_hash(h, world_seed)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(domain_descriptor))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(stage_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(layer_schema_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(feature_schema_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(continuity_policy_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_topology_projections))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_formation_products))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_variant(formation_product_dependencies))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(internal_required_topology_projections))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_product_set))
	return h

static func _copy_string_array(input_values: PackedStringArray) -> PackedStringArray:
	var values := PackedStringArray()
	for index in range(input_values.size()):
		var value := String(input_values[index]).strip_edges()
		if value.is_empty():
			continue
		values.append(value)
	return values


static func dependencies_for_formation_products(requested_products: PackedStringArray) -> Dictionary:
	var dependencies: Dictionary = {}
	var legacy_dependencies := _legacy_formation_dependencies()
	for product_id in requested_products:
		var normalized_product_id := String(product_id).strip_edges()
		if normalized_product_id.is_empty():
			continue
		if legacy_dependencies.has(normalized_product_id):
			dependencies[normalized_product_id] = legacy_dependencies[normalized_product_id].duplicate()
		else:
			dependencies[normalized_product_id] = PackedStringArray()
	return dependencies


static func topology_dependencies_for_formation_product(product_id: String) -> PackedStringArray:
	var normalized_product_id := product_id.strip_edges()
	var legacy_dependencies := _legacy_formation_dependencies()
	if legacy_dependencies.has(normalized_product_id):
		return legacy_dependencies[normalized_product_id].duplicate()
	return PackedStringArray()


static func public_layer_id_for_formation_product(product_id: String) -> String:
	var normalized_product_id := product_id.strip_edges()
	var legacy_dependencies := _legacy_formation_dependencies()
	if legacy_dependencies.has(normalized_product_id):
		var dependencies: PackedStringArray = legacy_dependencies[normalized_product_id]
		return String(dependencies[0]) if dependencies.size() > 0 else ""
	if normalized_product_id.ends_with("_formation"):
		return normalized_product_id.substr(0, normalized_product_id.length() - "_formation".length())
	return normalized_product_id


static func _legacy_formation_dependencies() -> Dictionary:
	return {
		"ground": PackedStringArray(["ground"]),
		"ground_formation": PackedStringArray(["ground"]),
		"water": PackedStringArray(["water"]),
		"water_formation": PackedStringArray(["water"]),
		"solid": PackedStringArray(["solid"]),
		"solid_formation": PackedStringArray(["solid"]),
		"cliff": PackedStringArray(["cliff"]),
		"cliff_formation": PackedStringArray(["cliff"]),
	}


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


static func _derive_internal_required_topology_projections(
	public_requested_topology: PackedStringArray,
	dependencies_by_product: Dictionary
) -> PackedStringArray:
	var seen: Dictionary = {}
	for projection_id in public_requested_topology:
		var normalized_projection_id := String(projection_id).strip_edges()
		if not normalized_projection_id.is_empty():
			seen[normalized_projection_id] = true
	for product_id in dependencies_by_product.keys():
		var dependencies: PackedStringArray = dependencies_by_product[product_id]
		for dependency_id in dependencies:
			var normalized_dependency_id := String(dependency_id).strip_edges()
			if not normalized_dependency_id.is_empty():
				seen[normalized_dependency_id] = true
	var ids := PackedStringArray()
	for projection_id in seen.keys():
		ids.append(String(projection_id))
	ids.sort()
	return ids
