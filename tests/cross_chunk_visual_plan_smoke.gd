extends SceneTree

class FakeStreamingNode:
	extends Node

	signal chunk_load_requested(request_id: int, x: int, y: int, z: int)
	signal chunk_unload_requested(request_id: int, x: int, y: int, z: int)

	var provider: Node
	var completed_saw_loaded: bool = false

	func provider_started(_request_id: int, _x: int, _y: int, _z: int) -> void:
		pass

	func provider_completed(_request_id: int, x: int, y: int, z: int) -> void:
		var generated_chunk_data: Dictionary = provider.get_loaded_chunk_data(Vector3i(x, y, z))
		completed_saw_loaded = (
			not generated_chunk_data.is_empty()
			and generated_chunk_data.has("logic_grid")
			and generated_chunk_data.has("formation_grid")
		)


var failed := false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		quit(1)
		return

	var Provider := load("res://scripts/chunk_provider.gd")
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")
	var provider: Node = Provider.new()
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()

	_configure_all_wall_provider(provider)
	_assert_negative_world_cell_mapping(provider)

	var loaded_before: int = provider.loaded_chunk_count()
	var generated_chunk_data: Dictionary = provider.make_generated_chunk_data(
		Vector3i(2, 0, 3),
		provider.generate_chunk_logic_grid(Vector3i(2, 0, 3))
	)
	_assert(
		provider.loaded_chunk_count() == loaded_before,
		"formation sampling does not mark neighbor chunks loaded"
	)
	_assert(
		generated_chunk_data["formation_grid"].size() == provider.chunk_size_cells + 1,
		"formation grid has halo row"
	)
	_assert(
		generated_chunk_data["formation_grid"][0].size() == provider.chunk_size_cells + 1,
		"formation grid has halo column"
	)

	var positive_plans: Dictionary = _assert_chunk_set(
		provider,
		builder,
		catalog,
		[
			Vector3i(0, 0, 0),
			Vector3i(1, 0, 0),
			Vector3i(0, 0, 1),
			Vector3i(1, 0, 1),
		],
		"positive"
	)
	_assert_border_mask_uses_neighbor(positive_plans[Vector3i(1, 0, 0)], Vector2i(0, 1), "right chunk left edge")
	_assert_border_mask_uses_neighbor(positive_plans[Vector3i(0, 0, 1)], Vector2i(1, 0), "bottom chunk top edge")

	var negative_plans: Dictionary = _assert_chunk_set(
		provider,
		builder,
		catalog,
		[
			Vector3i(-1, 0, -1),
			Vector3i(0, 0, -1),
			Vector3i(-1, 0, 0),
			Vector3i(0, 0, 0),
		],
		"negative"
	)
	_assert_border_mask_uses_neighbor(negative_plans[Vector3i(0, 0, 0)], Vector2i(0, 1), "origin chunk negative-left edge")

	var fake_streaming: FakeStreamingNode = FakeStreamingNode.new()
	fake_streaming.provider = provider
	root.add_child(fake_streaming)
	provider.bind_streaming_node(fake_streaming)
	fake_streaming.chunk_load_requested.emit(77, 5, 0, -2)
	_assert(
		fake_streaming.completed_saw_loaded,
		"provider stores generated data before provider_completed"
	)

	provider.free()
	fake_streaming.free()
	quit(1 if failed else 0)


func _configure_all_wall_provider(provider: Node) -> void:
	provider.chunk_size_cells = 4
	provider.world_seed = 7
	provider.wall_threshold_percent = 100
	provider.debug_force_chunk_border = false
	provider.smoothing_passes = 0
	provider.room_attempts = 0


func _assert_negative_world_cell_mapping(provider: Node) -> void:
	_assert(
		provider.world_cell_owner_chunk_coord(Vector2i(-1, -1), 0) == Vector3i(-1, 0, -1),
		"negative world cell maps to negative owner chunk"
	)
	_assert(
		provider.local_cell_for_world_cell(Vector2i(-1, -1)) == Vector2i(3, 3),
		"negative world cell maps to positive local cell"
	)


func _assert_chunk_set(
	provider: Node,
	builder: RefCounted,
	catalog: RefCounted,
	chunk_coords: Array,
	label: String
) -> Dictionary:
	var plans: Dictionary = {}
	var world_corner_owner: Dictionary = {}
	var size: int = provider.chunk_size_cells

	for chunk_coord in chunk_coords:
		var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
		var generated_chunk_data: Dictionary = provider.make_generated_chunk_data(chunk_coord, logic_grid)
		var visual_plan: Dictionary = builder.build_visual_plan_from_generated_chunk(
			generated_chunk_data,
			catalog
		)
		plans[chunk_coord] = visual_plan
		_assert(
			visual_plan.get("formation_mode", "") == "owned_halo",
			"%s plan uses owned halo formation" % label
		)
		_assert(
			visual_plan["diagnostics"]["cropped_visual_corners"] == size * size,
			"%s plan crops exactly owned visual corners" % label
		)
		_assert(
			bool(visual_plan["diagnostics"]["is_valid"]),
			"%s plan is valid" % label
		)

		for tile in visual_plan["visual_tiles"]:
			var data: Dictionary = tile
			var local_corner: Vector2i = data["corner"]
			_assert(
				local_corner.x >= 0
				and local_corner.y >= 0
				and local_corner.x < size
				and local_corner.y < size,
				"%s emits only owned local corners" % label
			)
			var expected_world_corner := Vector2i(
				chunk_coord.x * size + local_corner.x,
				chunk_coord.z * size + local_corner.y
			)
			_assert(
				data["world_corner"] == expected_world_corner,
				"%s tile world corner matches owner rule" % label
			)
			var world_key := _world_corner_key(data["world_corner"])
			_assert(
				not world_corner_owner.has(world_key),
				"%s world visual corner is owned once: %s" % [label, world_key]
			)
			world_corner_owner[world_key] = _chunk_key(chunk_coord)

	return plans


func _assert_border_mask_uses_neighbor(visual_plan: Dictionary, local_corner: Vector2i, label: String) -> void:
	var tile: Dictionary = _tile_at_corner(visual_plan, local_corner)
	_assert(not tile.is_empty(), "%s tile exists" % label)
	_assert(
		int(tile.get("mask", 0)) == 0b1111,
		"%s includes neighbor final cells in mask" % label
	)
	_assert(
		tile.get("formation_corner", Vector2i.ZERO) == local_corner + Vector2i.ONE,
		"%s records formation corner"
	)


func _tile_at_corner(visual_plan: Dictionary, corner: Vector2i) -> Dictionary:
	for tile in visual_plan["visual_tiles"]:
		var data: Dictionary = tile
		if data["corner"] == corner:
			return data
	return {}


func _world_corner_key(world_corner: Vector2i) -> String:
	return "%s:%s" % [world_corner.x, world_corner.y]


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("cross_chunk_visual_plan_smoke failed: %s" % message)
