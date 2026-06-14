extends SceneTree

var main_scene: Node
var frame: int = 0
var failed: bool = false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		_fail("GodotWorldStreamingNode class is not registered")
		return
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		return

	main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame == 4:
		_assert_diagnostics("initial")
		main_scene.player_or_camera.global_position = Vector3(640.0, 0.0, 640.0)

	if frame == 24:
		_assert_diagnostics("after fast focus move")
		_assert(main_scene.visual_chunk_count() == main_scene.visual_chunk_keys().size(), "visual roots are unique")
		_assert(main_scene.visual_roots_have_matching_metadata(), "visual roots have matching metadata")
		_assert(main_scene.chunk_provider.pending_request_count() == 0, "provider pending requests drain")
		_assert(main_scene.streaming_node.pending_request_count() == 0, "streaming pending requests drain")
		main_scene.clear_visual_roots_for_shutdown()
		quit(1 if failed else 0)
		return true

	return false


func _assert_diagnostics(label: String) -> void:
	var diagnostics: Dictionary = main_scene.get_runtime_diagnostics()
	var required_keys: Array[String] = [
		"resident_chunks",
		"pending_requests",
		"loaded_chunks",
		"visual_roots",
		"pooled_roots",
		"reused_roots",
		"cache_hits",
		"cache_misses",
		"missing_asset_keys",
		"missing_asset_key_count",
		"invalid_visual_plans",
		"generation_settings_hash",
		"provider",
		"catalog",
		"last_visual_plan",
		"last_instantiation_plan",
		"runtime_budgets",
		"visual_roots_have_matching_metadata",
	]
	for key in required_keys:
		_assert(diagnostics.has(key), "%s diagnostics include %s" % [label, key])

	_assert(int(diagnostics["resident_chunks"]) > 0, "%s has resident chunks" % label)
	_assert(int(diagnostics["loaded_chunks"]) > 0, "%s has loaded chunks" % label)
	_assert(int(diagnostics["visual_roots"]) > 0, "%s has visual roots" % label)
	_assert(int(diagnostics["pending_requests"]) == 0, "%s pending requests are bounded/drained" % label)
	_assert(int(diagnostics["generation_settings_hash"]) != 0, "%s has generation settings hash" % label)
	_assert(bool(diagnostics["visual_roots_have_matching_metadata"]), "%s metadata matches roots" % label)

	var runtime_budgets: Dictionary = diagnostics["runtime_budgets"]
	_assert(runtime_budgets.get("product_type", "") == "RuntimeRealizationBudget", "%s reports runtime budget contract" % label)
	_assert(runtime_budgets.get("visual_backend", "") == "multimesh", "%s budget records visual backend" % label)
	_assert(int(runtime_budgets.get("dirty_cell_max_visual_corners", 0)) == 4, "%s budget records dirty-cell scope" % label)
	_assert(
		runtime_budgets.get("dirty_realization_scope", "") == "affected_multimesh_buckets",
		"%s budget records dirty bucket realization scope" % label
	)
	_assert(
		int(runtime_budgets.get("max_collision_shapes_per_chunk", 0)) * int(diagnostics["visual_roots"])
		>= int(diagnostics["collision_shapes"]),
		"%s collision shapes stay within per-chunk budget ceiling" % label
	)
	_assert(
		int(runtime_budgets.get("max_pooled_visual_roots", -1)) >= int(diagnostics["pooled_roots"]),
		"%s pooled roots stay within configured budget" % label
	)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("runtime_diagnostics_smoke failed: %s" % message)
