extends SceneTree

var main_scene: Node
var frame: int = 0
var failed: bool = false
var configured: bool = false
var movement_started: bool = false
var movement_start_frame: int = 0
var positions: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(384.0, 0.0, 0.0),
	Vector3(384.0, 0.0, 384.0),
	Vector3(-384.0, 0.0, 384.0),
	Vector3(-384.0, 0.0, -384.0),
	Vector3(0.0, 0.0, 0.0),
]


func _initialize() -> void:
	main_scene = load("res://scenes/main.tscn").instantiate()
	main_scene.load_radius_chunks = 1
	main_scene.unload_radius_chunks = 2
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame > 360:
		_assert(false, "budgeted pooling work drains before timeout")
		main_scene.clear_visual_roots_for_shutdown()
		quit(1)
		return true

	if not configured and frame >= 2:
		main_scene.streaming_node.set_request_budgets(1, 1)
		configured = true

	if configured and not movement_started and _runtime_drained() and main_scene.visual_chunk_count() > 0:
		movement_started = true
		movement_start_frame = frame

	if movement_started and frame < movement_start_frame + 72:
		var index: int = mini(floori(float(frame - movement_start_frame) / 12.0), positions.size() - 1)
		main_scene.player_or_camera.global_position = positions[index]

	if movement_started and frame >= movement_start_frame + 72 and _runtime_drained():
		_assert(main_scene.chunk_provider.completed_unload_count > 0, "movement completes unloads")
		_assert(main_scene.pooled_visual_root_count() > 0, "visual roots are pooled after unload")
		_assert(main_scene.reused_visual_root_count() > 0, "visual roots are reused after pooling")
		_assert(
			main_scene.visual_root_pool_size() <= main_scene.max_pooled_visual_roots,
			"visual root pool stays bounded"
		)
		_assert(
			main_scene.visual_chunk_count() == main_scene.visual_chunk_keys().size(),
			"visual roots remain unique"
		)
		_assert(main_scene.visual_roots_have_matching_metadata(), "visual root metadata matches keys")
		_assert(main_scene.chunk_provider.pending_request_count() == 0, "provider pending work is drained")
		_assert(main_scene.streaming_node.pending_request_count() == 0, "controller pending work is drained")
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


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("pooling_budget_smoke failed: %s" % message)
