extends SceneTree

var main_scene: Node
var frame: int = 0
var failed: bool = false
var moved: bool = false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		_fail("GodotWorldStreamingNode class is not registered")
		return
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		return

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
		_assert_initial_streaming()
		main_scene.player_or_camera.global_position = Vector3(320.0, 0.0, 0.0)
		moved = true

	if moved and _runtime_drained() and main_scene.chunk_provider.completed_unload_count > 0:
		_assert_after_movement()
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


func _assert_initial_streaming() -> void:
	_assert(main_scene.streaming_node != null, "streaming node exists")
	_assert(main_scene.chunk_provider != null, "chunk provider exists")
	_assert(main_scene.debug_overlay != null, "debug overlay exists")
	_assert(main_scene.debug_overlay.debug_chunk_count() > 0, "debug chunk roots are created")
	_assert(main_scene.visual_chunk_count() > 0, "visual chunk roots are created")
	_assert(
		main_scene.debug_overlay.debug_chunk_count() == main_scene.debug_overlay.active_chunk_keys().size(),
		"debug chunk roots are unique"
	)
	_assert(
		main_scene.visual_chunk_count() == main_scene.visual_chunk_keys().size(),
		"visual chunk roots are unique"
	)
	_assert(
		main_scene.chunk_provider.pending_request_count() == 0,
		"provider drains budgeted requests"
	)
	_assert(
		main_scene.streaming_node.pending_request_count() == 0,
		"streaming controller has no pending requests after budgeted provider completion"
	)


func _assert_after_movement() -> void:
	_assert(main_scene.debug_overlay.debug_chunk_count() > 0, "debug chunks remain after movement")
	_assert(main_scene.visual_chunk_count() > 0, "visual chunks remain after movement")
	_assert(
		main_scene.chunk_provider.completed_unload_count > 0,
		"movement triggers unload completion"
	)
	_assert(
		main_scene.chunk_provider.pending_request_count() == 0,
		"provider has no orphan pending requests after movement"
	)
	_assert(
		main_scene.streaming_node.pending_request_count() == 0,
		"controller has no orphan pending requests after movement"
	)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("streaming_debug_smoke failed: %s" % message)
