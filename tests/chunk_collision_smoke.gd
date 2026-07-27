extends SceneTree

var main_scene: Node
var frame := 0
var failed := false
var moved := false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		_fail("GodotWorldStreamingNode class is not registered")
		return
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		return

	_assert_direct_collision_builder()
	main_scene = load("res://scenes/main.tscn").instantiate()
	main_scene.load_radius_chunks = 1
	main_scene.unload_radius_chunks = 2
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame > 240:
		_fail("budgeted runtime did not drain")
		main_scene.clear_visual_roots_for_shutdown()
		quit(1)
		return true

	if not moved and _runtime_drained() and main_scene.visual_chunk_count() > 0:
		_assert(main_scene.visual_chunk_count() > 0, "streaming creates visual chunks")
		_assert(main_scene.collision_body_count() == main_scene.visual_chunk_count(), "each visual root has collision")
		_assert(main_scene.collision_shape_count() > 0, "collision shapes are created")
		main_scene.player_or_camera.global_position = Vector3(512.0, 0.0, 512.0)
		moved = true

	if moved and _runtime_drained() and main_scene.chunk_provider.completed_unload_count > 0:
		_assert(main_scene.chunk_provider.completed_unload_count > 0, "movement unloads chunks")
		_assert(main_scene.collision_body_count() == main_scene.visual_chunk_count(), "collision bodies track active roots")
		_assert(main_scene.visual_root_pool_size() <= main_scene.max_pooled_visual_roots, "pooled roots remain bounded")
		main_scene.clear_visual_roots_for_shutdown()
		quit(1 if failed else 0)
		return true

	return false


func _runtime_drained() -> bool:
	var frame_budget: Dictionary = main_scene.frame_budget_diagnostics()
	var queue_sizes: Dictionary = frame_budget.get("queue_sizes", {})
	return (
		main_scene.chunk_provider.pending_request_count() == 0
		and main_scene.streaming_node.pending_request_count() == 0
		and int(queue_sizes.get("realization_pending", 0)) == 0
		and int(queue_sizes.get("unload_cleanup_pending", 0)) == 0
	)


func _assert_direct_collision_builder() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")

	var provider: Node = Provider.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
	var chunk_coord := Vector3i(2, 0, -1)
	var canonical_record: Dictionary = provider._generate_world_chunk_internal(chunk_coord).to_canonical_record(true)
	var collision_body: StaticBody3D = collision_builder.build_chunk_collision(
		chunk_coord,
		canonical_record,
		32.0,
		provider.chunk_size_cells,
		{
			"liquid_blocks_movement": provider.liquid_blocks_movement,
			"ground_floor_collision_enabled": true,
		}
	)
	var collision_plan: Dictionary = collision_body.get_meta("collision_plan")

	_assert(collision_body.name == "ChunkCollision", "collision body has stable name")
	_assert(collision_body.get_meta("chunk_coord") == chunk_coord, "collision body keeps chunk coord")
	_assert(
		int(collision_body.get_meta("collision_shape_count")) == collision_plan["collision_boxes"].size(),
		"collision shape count matches realized collision boxes"
	)
	_assert(
		int(collision_body.get_meta("collision_shape_owner_count")) == collision_plan["collision_boxes"].size(),
		"collision shape owner count matches realized collision boxes"
	)
	_assert(collision_body.get_child_count() == 0, "runtime collision uses shape owners, not per-shape child nodes")
	_assert(collision_plan["policy"]["ground_visuals_block_movement"] == false, "ground visuals do not imply blockers")
	_assert(collision_plan["policy"]["ground_floor_collision_enabled"], "walkable ground floor collision is explicit policy")
	_assert(not collision_plan["floor_boxes"].is_empty(), "walkable ground emits merged floor boxes")
	_assert(int(collision_plan["diagnostics"]["floor_cell_count"]) > 0, "floor diagnostics count walkable ground cells")
	_assert(collision_plan["diagnostics"]["source_has_topology_layers"], "collision consumes topology layers")
	_assert_layer_semantics(collision_builder)

	collision_body.free()
	provider.free()


func _assert_layer_semantics(collision_builder: RefCounted) -> void:
	var ground_only := {
		"product_type": "GeneratedChunkData",
		"topology_layers": {
			"ground": [[1, 1], [1, 1]],
			"solid": [[0, 0], [0, 0]],
			"water": [[0, 0], [0, 0]],
		},
		"logic_grid": [[0, 0], [0, 0]],
	}
	var ground_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, ground_only, {"liquid_blocks_movement": true})
	_assert(ground_plan["merged_boxes"].is_empty(), "ground layer alone creates no blockers")
	var floor_plan: Dictionary = collision_builder.build_collision_plan(
		Vector3i.ZERO,
		ground_only,
		{
			"liquid_blocks_movement": true,
			"ground_floor_collision_enabled": true,
		}
	)
	_assert(floor_plan["merged_boxes"].is_empty(), "floor policy keeps ground out of blocker boxes")
	_assert(floor_plan["floor_boxes"].size() == 1, "walkable ground merges into one floor box")
	_assert(floor_plan["collision_boxes"].size() == 1, "ground-only collision realizes one floor shape")
	_assert(int(floor_plan["diagnostics"]["floor_cell_count"]) == 4, "floor policy counts walkable ground cells")
	_assert(
		floor_plan["source_consumed_fields"].has("topology_layers.ground"),
		"floor policy consumes canonical ground topology"
	)

	var solid_source := ground_only.duplicate(true)
	solid_source["topology_layers"]["solid"] = [[1, 0], [0, 0]]
	var solid_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, solid_source, {"liquid_blocks_movement": true})
	_assert(solid_plan["merged_boxes"].size() == 1, "solid layer creates blockers")

	var mergeable_source := ground_only.duplicate(true)
	mergeable_source["topology_layers"]["solid"] = [[1, 1], [1, 1]]
	var mergeable_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, mergeable_source, {"liquid_blocks_movement": true})
	_assert(int(mergeable_plan["diagnostics"]["blocking_cell_count"]) == 4, "mergeable grid reports all blocking cells")
	_assert(int(mergeable_plan["diagnostics"]["merged_shape_count"]) == 1, "mergeable grid collapses to one merged box")

	var water_source := ground_only.duplicate(true)
	water_source["topology_layers"]["water"] = [[0, 1], [0, 0]]
	var blocked_water_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, water_source, {"liquid_blocks_movement": true})
	var open_water_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, water_source, {"liquid_blocks_movement": false})
	var water_floor_plan: Dictionary = collision_builder.build_collision_plan(
		Vector3i.ZERO,
		water_source,
		{
			"liquid_blocks_movement": false,
			"ground_floor_collision_enabled": true,
		}
	)
	_assert(blocked_water_plan["merged_boxes"].size() == 1, "liquid policy can create blockers")
	_assert(open_water_plan["merged_boxes"].is_empty(), "liquid policy can allow movement")
	_assert(int(water_floor_plan["diagnostics"]["floor_cell_count"]) == 3, "water cells are excluded from walkable ground floor")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("chunk_collision_smoke failed: %s" % message)
