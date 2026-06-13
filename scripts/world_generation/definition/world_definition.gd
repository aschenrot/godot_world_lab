extends Resource

class_name WorldDefinition

@export var world_definition_id: String = "default_lab_world"
@export var world_definition_version: int = 1
@export var world_seed: int = 1337
@export var domain_descriptor: String = WorldSpace.DOMAIN_CELL_GRID_2D
@export var generation_settings: Dictionary = {}
@export var stage_ids: PackedStringArray = PackedStringArray()
@export var layer_schema_ids: PackedStringArray = PackedStringArray()
@export var feature_schema_ids: PackedStringArray = PackedStringArray()
@export var continuity_policy_ids: PackedStringArray = PackedStringArray()
@export var requested_topology_projections: PackedStringArray = PackedStringArray()
@export var requested_formation_products: PackedStringArray = PackedStringArray()
@export var requested_product_set: PackedStringArray = PackedStringArray(["generated_world_chunk"])


func compile_snapshot() -> WorldDefinitionSnapshot:
	var snapshot := WorldDefinitionSnapshot.new()
	return snapshot.configure(
		world_definition_id,
		world_definition_version,
		definition_hash(),
		generation_settings_hash(),
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


func validate_definition() -> Dictionary:
	return WorldDefinitionValidator.validate_definition(self)


func generation_settings_hash() -> int:
	return GeneratedChunkIdentity.stable_hash_variant(generation_settings)


func definition_hash() -> int:
	var h := GeneratedChunkIdentity.stable_hash_string("WorldDefinition:v1")
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(world_definition_id))
	h = GeneratedChunkIdentity.mix_hash(h, world_definition_version)
	h = GeneratedChunkIdentity.mix_hash(h, world_seed)
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_string(domain_descriptor))
	h = GeneratedChunkIdentity.mix_hash(h, generation_settings_hash())
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(stage_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(layer_schema_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(feature_schema_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_ordered_string_ids(continuity_policy_ids))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_topology_projections))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_formation_products))
	h = GeneratedChunkIdentity.mix_hash(h, GeneratedChunkIdentity.stable_hash_unordered_string_ids(requested_product_set))
	return h


func to_dictionary() -> Dictionary:
	return {
		"product_type": "WorldDefinition",
		"world_definition_id": world_definition_id,
		"world_definition_version": world_definition_version,
		"world_seed": world_seed,
		"domain_descriptor": domain_descriptor,
		"generation_settings": generation_settings.duplicate(true),
		"stage_ids": stage_ids.duplicate(),
		"layer_schema_ids": layer_schema_ids.duplicate(),
		"feature_schema_ids": feature_schema_ids.duplicate(),
		"continuity_policy_ids": continuity_policy_ids.duplicate(),
		"requested_topology_projections": requested_topology_projections.duplicate(),
		"requested_formation_products": requested_formation_products.duplicate(),
		"requested_product_set": requested_product_set.duplicate(),
		"definition_hash": definition_hash(),
		"generation_settings_hash": generation_settings_hash(),
	}
