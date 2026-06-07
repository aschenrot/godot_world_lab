extends SceneTree

var main_scene: Node
var frame := 0
var failed := false
var target_chunk := Vector3i.ZERO
var saw_unloaded := false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		_fail("GodotWorldStreamingNode class is not registered")
		return
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		return

	_assert_direct_overlay_store()
	main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)


func _process(_delta: float) -> bool:
	if failed:
		quit(1)
		return true

	frame += 1
	if frame == 4:
		_assert(main_scene.has_visual_chunk(target_chunk), "target chunk starts resident")
		main_scene.set_chunk_overlay_value(target_chunk, "note", "session-only")
		main_scene.set_chunk_overlay_value(target_chunk, "dirty_cells", [Vector2i(3, 4)])
		_assert(main_scene.overlay_chunk_count() == 1, "overlay store records one chunk")
		_assert(main_scene.overlay_node_count() > 0, "active chunk has overlay node")
		main_scene.player_or_camera.global_position = Vector3(1024.0, 0.0, 1024.0)

	if frame > 8 and not main_scene.has_visual_chunk(target_chunk):
		saw_unloaded = true

	if frame == 36:
		_assert(saw_unloaded, "target chunk unloaded after focus move")
		_assert(main_scene.overlay_chunk_count() == 1, "overlay survives unload in memory")
		main_scene.player_or_camera.global_position = Vector3.ZERO

	if frame == 72:
		_assert(main_scene.has_visual_chunk(target_chunk), "target chunk reloads")
		_assert(main_scene.overlay_chunk_count() == 1, "overlay remains stored after reload")
		_assert(main_scene.overlay_node_count() > 0, "overlay reapplies to active chunk")
		_assert(
			main_scene.get_chunk_overlay_value(target_chunk, "note", "") == "session-only",
			"overlay value survives reload"
		)
		main_scene.clear_visual_roots_for_shutdown()
		quit(1 if failed else 0)
		return true

	return false


func _assert_direct_overlay_store() -> void:
	var Overlay := load("res://scripts/overlays/chunk_overlay_sandbox.gd")
	var overlay: RefCounted = Overlay.new()
	var chunk_coord := Vector3i(2, 0, 3)
	overlay.set_overlay_value(chunk_coord, "marker", "kept")
	_assert(overlay.overlay_entry_count() == 1, "direct overlay store records entry")
	_assert(overlay.get_overlay_value(chunk_coord, "marker", "") == "kept", "direct overlay value reads back")

	var root := Node3D.new()
	overlay.apply_overlay_to_chunk_root(root, chunk_coord)
	var diagnostics: Dictionary = overlay.get_overlay_diagnostics(root)
	_assert(bool(diagnostics["has_overlay_node"]), "overlay node is attached")
	_assert(diagnostics["overlay_data"]["marker"] == "kept", "overlay node carries data")
	root.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("chunk_overlay_sandbox_smoke failed: %s" % message)
