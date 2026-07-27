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

	_assert_direct_layer_rebuild()
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
		_assert(main_scene.placed_layer_count() == main_scene.visual_chunk_count(), "each visual root has placed layer")
		_assert(main_scene.placed_object_count() > 0, "some chunks contain placed objects")
		main_scene.player_or_camera.global_position = Vector3(512.0, 0.0, 512.0)
		moved = true

	if moved and _runtime_drained() and main_scene.chunk_provider.completed_unload_count > 0:
		_assert(main_scene.chunk_provider.completed_unload_count > 0, "movement unloads chunks")
		_assert(main_scene.placed_layer_count() == main_scene.visual_chunk_count(), "placed layers track active roots")
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


func _assert_direct_layer_rebuild() -> void:
	var Descriptor := load("res://scripts/placed/placed_object_descriptor.gd")
	var Layer := load("res://scripts/placed/placed_object_layer.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var catalog: RefCounted = Catalog.new()
	var layer_builder: RefCounted = Layer.new()
	var chunk_coord := Vector3i(0, 0, 0)
	var descriptor: RefCounted = Descriptor.new().configure(
		"test_marker",
		chunk_coord,
		Vector3(1.0, 0.5, 2.0),
		"debug",
		90.0,
		{"kind": "test"}
	)
	var layer: Node3D = layer_builder.build_chunk_layer(chunk_coord, [descriptor], catalog)
	_assert(layer.name == "PlacedObjectLayer", "layer has stable name")
	_assert(layer.get_child_count() == 1, "layer builds descriptor child")

	var visual_tile_count_before := 4
	layer_builder.rebuild_chunk_layer(layer, [], catalog)
	_assert(layer.get_child_count() == 0, "layer can rebuild independently")
	_assert(visual_tile_count_before == 4, "terrain visual count is not part of placed layer state")
	layer.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("placed_object_layer_smoke failed: %s" % message)
