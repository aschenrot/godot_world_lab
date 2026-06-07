extends SceneTree

var playground: Node
var controller: Node
var player_rig: Node3D
var frame: int = 0
var failed: bool = false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		_fail("GodotWorldStreamingNode class is not registered")
		return
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		return

	playground = load("res://scenes/playground/world_playground.tscn").instantiate()
	root.add_child(playground)
	controller = playground.get_node("WorldController")
	player_rig = playground.get_node("PlayerRig")


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame == 4:
		_assert(controller.streaming_node != null, "playground installs streaming node")
		_assert(controller.chunk_provider != null, "playground installs provider")
		_assert(controller.visual_chunk_count() > 0, "playground creates visual chunks")
		player_rig.global_position = Vector3(512.0, 36.0, 0.0)

	if frame == 18:
		player_rig.global_position = Vector3(512.0, 36.0, 512.0)

	if frame == 36:
		_assert(controller.chunk_provider.completed_unload_count > 0, "movement streams chunks out")
		_assert(controller.visual_chunk_count() == controller.visual_chunk_keys().size(), "no duplicate roots")
		_assert(controller.visual_roots_have_matching_metadata(), "no orphan root metadata")
		_assert(controller.visual_root_pool_size() <= controller.max_pooled_visual_roots, "pool is bounded")
		_assert(controller.chunk_provider.pending_request_count() == 0, "provider pending requests drain")
		_assert(controller.streaming_node.pending_request_count() == 0, "streaming pending requests drain")
		_assert(_generated_chunks_are_not_forced_seams(), "generated chunks are seamless by default")
		controller.clear_visual_roots_for_shutdown()
		quit(1 if failed else 0)
		return true

	return false


func _generated_chunks_are_not_forced_seams() -> bool:
	var provider: Node = controller.chunk_provider
	provider.wall_threshold_percent = 0
	provider.debug_force_chunk_border = false
	var left_chunk: Array = provider.generate_chunk_logic_grid(Vector3i(0, 0, 0))
	var right_chunk: Array = provider.generate_chunk_logic_grid(Vector3i(1, 0, 0))
	return not _edge_is_wall(left_chunk, "right") and not _edge_is_wall(right_chunk, "left")


func _edge_is_wall(grid: Array, edge: String) -> bool:
	var size := grid.size()
	if edge == "left":
		for y in range(size):
			if grid[y][0] != 1:
				return false
		return true
	if edge == "right":
		for y in range(size):
			if grid[y][size - 1] != 1:
				return false
		return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("playground_smoke failed: %s" % message)
