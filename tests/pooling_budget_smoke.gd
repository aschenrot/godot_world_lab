extends SceneTree

var main_scene: Node
var frame: int = 0
var failed: bool = false
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
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame == 2:
		main_scene.streaming_node.set_request_budgets(1, 1)

	if frame >= 2 and frame < 74:
		var index: int = mini(floori(float(frame - 2) / 12.0), positions.size() - 1)
		main_scene.player_or_camera.global_position = positions[index]

	if frame == 96:
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
		quit(1 if failed else 0)
		return true

	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("pooling_budget_smoke failed: %s" % message)
