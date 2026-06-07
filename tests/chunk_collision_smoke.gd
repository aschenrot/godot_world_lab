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
	var VisualBuilder := load("res://scripts/chunk_visual_builder.gd")
	var CollisionBuilder := load("res://scripts/collision/chunk_collision_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var provider: Node = Provider.new()
	var visual_builder: RefCounted = VisualBuilder.new()
	var collision_builder: RefCounted = CollisionBuilder.new()
	var catalog: RefCounted = Catalog.new()
	var chunk_coord := Vector3i(2, 0, -1)
	var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
	var visual_plan: Dictionary = visual_builder.build_visual_plan(chunk_coord, logic_grid, catalog)
	var collision_body: StaticBody3D = collision_builder.build_chunk_collision(
		chunk_coord,
		visual_plan,
		32.0,
		provider.chunk_size_cells
	)

	_assert(collision_body.name == "ChunkCollision", "collision body has stable name")
	_assert(collision_body.get_meta("chunk_coord") == chunk_coord, "collision body keeps chunk coord")
	_assert(
		int(collision_body.get_meta("collision_shape_count")) == visual_plan["visual_tiles"].size(),
		"collision shape count matches visual tiles"
	)
	_assert(_all_children_are_box_shapes(collision_body), "collision children are box shapes")

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


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("chunk_collision_smoke failed: %s" % message)
