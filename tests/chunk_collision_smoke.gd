extends SceneTree

var main_scene: Node
var frame := 0
var failed := false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		_fail("GodotWorldStreamingNode class is not registered")
		return
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		return

	_assert_direct_collision_builder()
	main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame == 4:
		_assert(main_scene.visual_chunk_count() > 0, "streaming creates visual chunks")
		_assert(main_scene.collision_body_count() == main_scene.visual_chunk_count(), "each visual root has collision")
		_assert(main_scene.collision_shape_count() > 0, "collision shapes are created")
		main_scene.player_or_camera.global_position = Vector3(512.0, 0.0, 512.0)

	if frame == 24:
		_assert(main_scene.chunk_provider.completed_unload_count > 0, "movement unloads chunks")
		_assert(main_scene.collision_body_count() == main_scene.visual_chunk_count(), "collision bodies track active roots")
		_assert(main_scene.visual_root_pool_size() <= main_scene.max_pooled_visual_roots, "pooled roots remain bounded")
		main_scene.clear_visual_roots_for_shutdown()
		quit(1 if failed else 0)
		return true

	return false


func _assert_direct_collision_builder() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")

	var provider: Node = Provider.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
	var chunk_coord := Vector3i(2, 0, -1)
	var generation_result: Dictionary = provider.generate_chunk_generation_result(chunk_coord)
	var generated_data: Dictionary = provider.make_generated_chunk_data(
		chunk_coord,
		generation_result["logic_grid"],
		generation_result
	)
	var collision_body: StaticBody3D = collision_builder.build_chunk_collision(
		chunk_coord,
		generated_data,
		32.0,
		provider.chunk_size_cells,
		{"liquid_blocks_movement": provider.liquid_blocks_movement}
	)
	var collision_plan: Dictionary = collision_body.get_meta("collision_plan")

	_assert(collision_body.name == "ChunkCollision", "collision body has stable name")
	_assert(collision_body.get_meta("chunk_coord") == chunk_coord, "collision body keeps chunk coord")
	_assert(
		int(collision_body.get_meta("collision_shape_count")) == collision_plan["blocking_cells"].size(),
		"collision shape count matches blocking policy cells"
	)
	_assert(collision_plan["policy"]["ground_visuals_block_movement"] == false, "ground visuals do not imply blockers")
	_assert(collision_plan["diagnostics"]["source_has_topology_layers"], "collision consumes topology layers")
	_assert(_all_children_are_box_shapes(collision_body), "collision children are box shapes")
	_assert_layer_semantics(collision_builder)

	collision_body.free()
	provider.free()


func _all_children_are_box_shapes(body: StaticBody3D) -> bool:
	for child in body.get_children():
		if not child is CollisionShape3D:
			return false
		var shape_node := child as CollisionShape3D
		if not shape_node.shape is BoxShape3D:
			return false
	return true


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
	_assert(ground_plan["blocking_cells"].is_empty(), "ground layer alone creates no blockers")

	var solid_source := ground_only.duplicate(true)
	solid_source["topology_layers"]["solid"] = [[1, 0], [0, 0]]
	var solid_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, solid_source, {"liquid_blocks_movement": true})
	_assert(solid_plan["blocking_cells"].size() == 1, "solid layer creates blockers")

	var water_source := ground_only.duplicate(true)
	water_source["topology_layers"]["water"] = [[0, 1], [0, 0]]
	var blocked_water_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, water_source, {"liquid_blocks_movement": true})
	var open_water_plan: Dictionary = collision_builder.build_collision_plan(Vector3i.ZERO, water_source, {"liquid_blocks_movement": false})
	_assert(blocked_water_plan["blocking_cells"].size() == 1, "liquid policy can create blockers")
	_assert(open_water_plan["blocking_cells"].is_empty(), "liquid policy can allow movement")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("chunk_collision_smoke failed: %s" % message)
