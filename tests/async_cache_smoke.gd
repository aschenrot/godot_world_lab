extends SceneTree

var main_scene: Node
var frame: int = 0
var failed: bool = false
var configured: bool = false


func _initialize() -> void:
	main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame == 1 and not configured:
		_configure_scene()

	if frame == 2:
		main_scene.player_or_camera.global_position = Vector3.ZERO

	if frame == 4:
		_assert(main_scene.chunk_provider.pending_request_count() > 0, "async provider defers completion")
		_assert(main_scene.streaming_node.pending_request_count() > 0, "controller tracks active provider requests")

	if frame == 28:
		_assert(main_scene.chunk_provider.pending_request_count() == 0, "first position async work drains")
		_assert(main_scene.chunk_provider.cache_miss_count > 0, "first loads populate cache")
		_assert(main_scene.chunk_provider.cache_entry_count() > 0, "cache stores chunk content")
		main_scene.player_or_camera.global_position = Vector3(256.0, 0.0, 0.0)

	if frame == 56:
		_assert(main_scene.chunk_provider.pending_request_count() == 0, "movement async work drains")
		main_scene.player_or_camera.global_position = Vector3.ZERO

	if frame == 88:
		_assert(main_scene.chunk_provider.pending_request_count() == 0, "return async work drains")
		_assert(main_scene.chunk_provider.cache_hit_count > 0, "returning to prior chunks hits cache")
		_assert(main_scene.visual_chunk_count() > 0, "visual roots rebuild after cached load")
		_assert(main_scene.visual_roots_have_matching_metadata(), "cached reload roots have fresh metadata")
		_cleanup_scene()
		quit(1 if failed else 0)
		return true

	return false


func _configure_scene() -> void:
	_assert(main_scene.streaming_node != null, "streaming node is installed")
	_assert(main_scene.chunk_provider != null, "chunk provider is installed")
	if failed:
		return
	main_scene.streaming_node.set_load_radii(1, 2, 0, 1)
	main_scene.streaming_node.set_request_budgets(2, 2)
	main_scene.chunk_provider.configure_async_provider(true, 2)
	main_scene.chunk_provider.configure_chunk_cache(true)
	configured = true


func _cleanup_scene() -> void:
	if main_scene == null:
		return
	main_scene.clear_visual_roots_for_shutdown()
	root.remove_child(main_scene)
	main_scene.free()
	main_scene = null


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("async_cache_smoke failed: %s" % message)
