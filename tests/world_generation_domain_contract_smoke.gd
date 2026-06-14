extends SceneTree

const TopologyViewScript := preload("res://scripts/world_generation/topology/topology_view.gd")

var failed: bool = false


func _initialize() -> void:
	test_supported_domain_descriptors_have_contracts()
	test_cell_grid_contract_matches_world_space_bounds()
	test_generation_context_exposes_domain_contract()
	test_topology_view_declares_domain_contract()
	test_layer_schema_and_definition_validator_use_domain_contracts()
	quit(1 if failed else 0)


func test_supported_domain_descriptors_have_contracts() -> void:
	var expected_domains := PackedStringArray([
		WorldSpace.DOMAIN_CELL_GRID_2D,
		WorldSpace.DOMAIN_SURFACE_2_5D,
		WorldSpace.DOMAIN_STACKED_LAYERS,
		WorldSpace.DOMAIN_VOLUME_GRID_3D,
		WorldSpace.DOMAIN_GRAPH_REGION,
		WorldSpace.DOMAIN_HYBRID,
	])
	var supported_domains := WorldSpace.supported_domain_descriptors()
	var contract_map := WorldSpace.domain_contracts_by_descriptor()

	_assert(supported_domains == expected_domains, "WorldSpace exposes the expected domain descriptor list")
	_assert(contract_map.size() == expected_domains.size(), "WorldSpace exposes one contract per domain descriptor")
	for descriptor in expected_domains:
		var contract: RefCounted = WorldSpace.domain_contract(descriptor)
		_assert(contract != null, "%s domain contract exists" % descriptor)
		if contract == null:
			continue
		var contract_data: Dictionary = contract.to_dictionary()
		_assert(contract.is_valid(), "%s domain contract is valid" % descriptor)
		_assert(contract_data.get("descriptor_id", "") == descriptor, "%s contract keeps descriptor id" % descriptor)
		_assert(not String(contract_data.get("coordinate_model", "")).is_empty(), "%s declares coordinates" % descriptor)
		_assert(not String(contract_data.get("ownership_model", "")).is_empty(), "%s declares ownership" % descriptor)
		_assert(not String(contract_data.get("halo_model", "")).is_empty(), "%s declares halo" % descriptor)
		_assert(not String(contract_data.get("sampling_model", "")).is_empty(), "%s declares sampling" % descriptor)
		_assert(not String(contract_data.get("continuity_model", "")).is_empty(), "%s declares continuity" % descriptor)
		_assert(not String(contract_data.get("projection_model", "")).is_empty(), "%s declares projection" % descriptor)
		_assert(not String(contract_data.get("formation_model", "")).is_empty(), "%s declares formation" % descriptor)
		_assert(not String(contract_data.get("outputs_model", "")).is_empty(), "%s declares outputs" % descriptor)
		_assert(
			contract.signature_hash() == WorldSpace.domain_descriptor_contract_hash(descriptor),
			"%s contract hash is addressable through WorldSpace" % descriptor
		)
		_assert(
			contract.signature_hash() == contract.duplicate_contract().signature_hash(),
			"%s contract signature is deterministic" % descriptor
		)


func test_cell_grid_contract_matches_world_space_bounds() -> void:
	var world_space := WorldSpace.from_parts(16, 2, WorldSpace.DOMAIN_CELL_GRID_2D)
	var chunk_coord := Vector3i(2, 0, -3)
	var world_space_data := world_space.to_dictionary()
	var domain_contract: Dictionary = world_space_data.get("domain_contract", {})

	_assert(
		world_space.owned_cell_bounds_for_chunk(chunk_coord)
		== Rect2i(Vector2i(32, -48), Vector2i(16, 16)),
		"cell_grid_2d ownership model matches owned Rect2i bounds"
	)
	_assert(
		world_space.sample_cell_bounds_for_chunk(chunk_coord)
		== Rect2i(Vector2i(30, -50), Vector2i(20, 20)),
		"cell_grid_2d halo model expands sample Rect2i bounds"
	)
	_assert(
		domain_contract.get("ownership_model", "") == "chunk_owned_rect2i",
		"WorldSpace dictionary includes ownership contract"
	)
	_assert(
		domain_contract.get("sampling_model", "") == "owned_bounds_expanded_by_halo_cells",
		"WorldSpace dictionary includes sampling contract"
	)
	_assert(
		domain_contract.get("outputs_model", "") == "generated_world_chunk_with_generated_chunk_data_adapter",
		"cell_grid_2d contract keeps current compatibility output contract"
	)


func test_generation_context_exposes_domain_contract() -> void:
	var definition := WorldDefinition.new()
	definition.world_definition_id = "domain_contract_context_smoke"
	definition.domain_descriptor = WorldSpace.DOMAIN_CELL_GRID_2D
	var snapshot := definition.compile_snapshot()
	var request := ChunkGenerationRequest.from_provider_request(
		-1,
		ChunkGenerationRequest.KIND_LOAD,
		Vector3i(-1, 0, 1),
		8,
		1,
		snapshot.requested_product_set,
		{"domain_contract_smoke": true}
	)
	var context := GenerationContext.from_snapshot_and_request(snapshot, request)
	var context_data := context.to_dictionary()
	var domain_contract: Dictionary = context_data.get("domain_contract", {})

	_assert(
		context.owned_cell_bounds == Rect2i(Vector2i(-8, 8), Vector2i(8, 8)),
		"GenerationContext keeps existing owned bounds"
	)
	_assert(
		context.sample_cell_bounds == Rect2i(Vector2i(-9, 7), Vector2i(10, 10)),
		"GenerationContext keeps existing sample halo bounds"
	)
	_assert(
		domain_contract.get("descriptor_id", "") == WorldSpace.DOMAIN_CELL_GRID_2D,
		"GenerationContext exposes the domain descriptor contract"
	)


func test_topology_view_declares_domain_contract() -> void:
	var contract: RefCounted = WorldSpace.domain_contract(WorldSpace.DOMAIN_STACKED_LAYERS)
	var view: RefCounted = TopologyViewScript.from_domain_contract(
		"stacked_navigation_view",
		contract,
		PackedStringArray(["walkable", "solid"]),
		{"source": "domain_contract_smoke"}
	)
	var view_data: Dictionary = view.to_dictionary()

	_assert(view.is_valid(), "TopologyView built from a domain contract is valid")
	_assert(
		view.domain_descriptor == WorldSpace.DOMAIN_STACKED_LAYERS,
		"TopologyView keeps the domain descriptor"
	)
	_assert(
		view.projection_ids == PackedStringArray(["solid", "walkable"]),
		"TopologyView projection ids are normalized deterministically"
	)
	_assert(
		view.domain_contract_signature_hash == contract.signature_hash(),
		"TopologyView stores the referenced domain contract identity"
	)
	_assert(
		view_data.get("projection_model", "") == contract.projection_model,
		"TopologyView carries projection contract"
	)
	_assert(
		view.signature_hash() == view.duplicate_view().signature_hash(),
		"TopologyView signature is deterministic"
	)

	var runtime_view: RefCounted = TopologyViewScript.from_domain_contract(
		"runtime_view",
		contract,
		PackedStringArray(["solid"]),
		{"node": Node.new()}
	)
	_assert(not runtime_view.is_valid(), "TopologyView rejects runtime object metadata")
	runtime_view.metadata["node"].free()


func test_layer_schema_and_definition_validator_use_domain_contracts() -> void:
	var schema: RefCounted = WorldLayerSchema.from_parts(
		"surface_material",
		WorldLayerSchema.KIND_TERRAIN_CELL_GRID,
		WorldSpace.DOMAIN_SURFACE_2_5D,
		WorldLayerSchema.VALUE_KIND_DICTIONARY_CELL,
		"domain_contract_smoke"
	)
	var definition := WorldDefinition.new()
	definition.world_definition_id = "surface_domain_contract_smoke"
	definition.domain_descriptor = WorldSpace.DOMAIN_SURFACE_2_5D
	definition.layer_schema_ids = PackedStringArray(["surface_material"])
	var validation := definition.validate_definition()

	_assert(schema.is_valid(), "WorldLayerSchema accepts supported domain descriptor contracts")
	_assert(bool(validation.get("valid", false)), "WorldDefinitionValidator accepts declared domain contracts")
	_assert(
		not _array_has(validation.get("issues", PackedStringArray()), "invalid_domain_descriptor_contract"),
		"valid definition has no invalid domain contract issue"
	)

	var invalid_definition := WorldDefinition.new()
	invalid_definition.world_definition_id = "invalid_domain_contract_smoke"
	invalid_definition.domain_descriptor = "unknown_domain"
	var invalid_validation := invalid_definition.validate_definition()
	_assert(not bool(invalid_validation.get("valid", true)), "WorldDefinitionValidator rejects unknown domains")
	_assert(
		_array_has(invalid_validation.get("issues", PackedStringArray()), "unsupported_domain_descriptor"),
		"unknown domain reports unsupported descriptor"
	)


func _array_has(values: Variant, target: String) -> bool:
	if typeof(values) == TYPE_PACKED_STRING_ARRAY:
		var packed_values: PackedStringArray = values
		return packed_values.has(target)
	if typeof(values) == TYPE_ARRAY:
		var array_values: Array = values
		return array_values.has(target)
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_domain_contract_smoke failed: %s" % message)
