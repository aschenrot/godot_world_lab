extends Node3D

const FrameBudgetSchedulerScript := preload("res://scripts/runtime/frame_budget_scheduler.gd")

@export var chunk_edge_meters: float = 32.0
@export var load_radius_chunks: int = 4
@export var unload_radius_chunks: int = 6
@export var vertical_load_radius_chunks: int = 0
@export var vertical_unload_radius_chunks: int = 1
@export_enum("fixed_y", "focus_y") var streaming_focus_y_policy: String = "fixed_y"
@export var streaming_focus_fixed_y_meters: float = 0.0
@export var enable_frame_budget_scheduler: bool = true
@export_enum("balanced_60") var frame_budget_preset: String = "balanced_60"
@export var frame_chunk_budget_us: int = 4000
@export var minimum_frame_budget_jobs: int = 1
@export var max_pooled_visual_roots: int = 64
@export var focus_target_path: NodePath
@export var chunk_root_container_path: NodePath
@export var enable_collision_prototype: bool = true
@export var ground_floor_collision_enabled: bool = true
@export var ground_floor_thickness_meters: float = 0.2
@export var ground_floor_top_y_meters: float = 0.0
@export var enable_placed_asset_prototype: bool = true

var player_or_camera: Node3D
var chunk_root_container: Node3D
var streaming_node: Node
var chunk_provider: Node
var debug_overlay: Node
var frame_budget_scheduler: RefCounted
var chunk_visual_builder: RefCounted
var chunk_collision_builder: RefCounted
var placed_object_layer: RefCounted
var chunk_overlay_sandbox: RefCounted
var tile_mesh_catalog: RefCounted
var visual_chunk_roots: Dictionary = {}
var visual_root_pool: Array[Node3D] = []
var pending_unload_roots: Dictionary = {}
var realization_jobs: Dictionary = {}
var pooled_visual_root_total: int = 0
var reused_visual_root_total: int = 0
var invalid_visual_plan_count: int = 0
var last_visual_plan_diagnostics: Dictionary = {}
var last_instantiation_plan_diagnostics: Dictionary = {}


func _ready() -> void:
	_resolve_scene_references()
	_install_streaming_node()
	_install_support_nodes()


func _process(_delta: float) -> void:
	if enable_frame_budget_scheduler and frame_budget_scheduler != null:
		_configure_frame_budget_scheduler()
		frame_budget_scheduler.begin_frame()
	elif chunk_provider != null and chunk_provider.has_method("configure_frame_budget_scheduler"):
		chunk_provider.configure_frame_budget_scheduler(false)

	_update_streaming_focus()

	if enable_frame_budget_scheduler and frame_budget_scheduler != null:
		_drain_budgeted_runtime()


func _resolve_scene_references() -> void:
	player_or_camera = _resolve_node3d_path(focus_target_path, "PlayerOrCamera")
	chunk_root_container = _resolve_node3d_path(chunk_root_container_path, "ChunkRootContainer")
	if chunk_root_container == null:
		chunk_root_container = Node3D.new()
		chunk_root_container.name = "ChunkRootContainer"
		add_child(chunk_root_container)


func _install_streaming_node() -> void:
	if not ClassDB.class_exists("GodotWorldStreamingNode"):
		push_warning("GodotWorldStreamingNode is unavailable. Build and copy godot_world_streaming.")
		return

	streaming_node = ClassDB.instantiate("GodotWorldStreamingNode")
	streaming_node.name = "WorldStreamingNode"
	add_child(streaming_node)
	streaming_node.set_chunk_edge_meters(chunk_edge_meters)
	streaming_node.set_load_radii(
		load_radius_chunks,
		unload_radius_chunks,
		vertical_load_radius_chunks,
		vertical_unload_radius_chunks
	)
	streaming_node.set_planar_xz_mode()


func _install_support_nodes() -> void:
	var provider_script := load("res://scripts/chunk_provider.gd")
	var overlay_script := load("res://scripts/chunk_debug_overlay.gd")

	chunk_provider = Node.new()
	chunk_provider.name = "ChunkProvider"
	chunk_provider.set_script(provider_script)
	add_child(chunk_provider)
	if chunk_provider.has_method("configure_frame_budget_scheduler"):
		chunk_provider.configure_frame_budget_scheduler(enable_frame_budget_scheduler)

	debug_overlay = Node3D.new()
	debug_overlay.name = "ChunkDebugOverlay"
	debug_overlay.set_script(overlay_script)
	chunk_root_container.add_child(debug_overlay)

	if streaming_node != null:
		chunk_provider.call("bind_streaming_node", streaming_node)
		debug_overlay.call("bind_streaming_node", streaming_node)
		streaming_node.chunk_resident.connect(_on_chunk_resident)
		streaming_node.chunk_unloaded.connect(_on_chunk_unloaded)

	var builder_script := load("res://scripts/chunk_visual_builder.gd")
	var collision_builder_script := load("res://scripts/collision/chunk_collision_builder.gd")
	var placed_layer_script := load("res://scripts/placed/placed_object_layer.gd")
	var overlay_sandbox_script := load("res://scripts/overlays/chunk_overlay_sandbox.gd")
	var catalog_script := load("res://scripts/tile_mesh_catalog.gd")
	frame_budget_scheduler = FrameBudgetSchedulerScript.new()
	_configure_frame_budget_scheduler()
	chunk_visual_builder = builder_script.new()
	chunk_collision_builder = collision_builder_script.new()
	placed_object_layer = placed_layer_script.new()
	chunk_overlay_sandbox = overlay_sandbox_script.new()
	tile_mesh_catalog = catalog_script.new()


func _on_chunk_resident(x: int, y: int, z: int) -> void:
	var chunk_coord := Vector3i(x, y, z)
	var key := _chunk_key(chunk_coord)
	if visual_chunk_roots.has(key):
		return
	if chunk_provider == null or chunk_visual_builder == null or tile_mesh_catalog == null:
		return
	if enable_frame_budget_scheduler:
		_enqueue_realization_job(chunk_coord)
		return

	_realize_chunk_immediately(chunk_coord)


func _realize_chunk_immediately(chunk_coord: Vector3i) -> void:
	var key := _chunk_key(chunk_coord)
	var canonical_record: Dictionary = chunk_provider.call("get_loaded_chunk_record", chunk_coord)
	if canonical_record.is_empty():
		return

	var visual_plan: Dictionary = chunk_visual_builder.build_visual_plan_from_canonical_source(
		canonical_record,
		tile_mesh_catalog
	)
	last_visual_plan_diagnostics = visual_plan.get("diagnostics", {})
	if not bool(last_visual_plan_diagnostics.get("is_valid", true)):
		invalid_visual_plan_count += 1

	var instantiation_plan: Dictionary = chunk_visual_builder.build_instantiation_plan(
		chunk_coord,
		visual_plan,
		tile_mesh_catalog,
		"multimesh"
	)
	last_instantiation_plan_diagnostics = instantiation_plan.get("diagnostics", {})
	var visual_root: Node3D = chunk_visual_builder.build_chunk_visual_from_instantiation_plan(
		instantiation_plan,
		tile_mesh_catalog,
		chunk_edge_meters,
		chunk_provider.chunk_size_cells,
		_take_pooled_visual_root()
	)
	_add_collision_if_enabled(visual_root, chunk_coord, canonical_record)
	_add_placed_objects_if_enabled(visual_root, chunk_coord)
	_apply_overlay(visual_root, chunk_coord)
	visual_root.position = Vector3(
		float(chunk_coord.x) * chunk_edge_meters,
		float(chunk_coord.y) * chunk_edge_meters,
		float(chunk_coord.z) * chunk_edge_meters
	)
	chunk_root_container.add_child(visual_root)
	visual_chunk_roots[key] = visual_root


func _on_chunk_unloaded(x: int, y: int, z: int) -> void:
	var key := _chunk_key(Vector3i(x, y, z))
	if enable_frame_budget_scheduler:
		_enqueue_unload_cleanup(key)
		return

	_unload_visual_root_immediately(key)


func _unload_visual_root_immediately(key: String) -> void:
	var root: Node3D = visual_chunk_roots.get(key)
	if root != null:
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		var pool_size_before := visual_root_pool.size()
		chunk_visual_builder.destroy_or_pool(root, visual_root_pool, max_pooled_visual_roots)
		if visual_root_pool.size() > pool_size_before:
			pooled_visual_root_total += 1
	visual_chunk_roots.erase(key)


func _enqueue_unload_cleanup(key: String) -> void:
	_cancel_realization_job(key)
	var root: Node3D = visual_chunk_roots.get(key)
	if root == null:
		return
	if root.get_parent() != null:
		root.get_parent().remove_child(root)
	visual_chunk_roots.erase(key)
	pending_unload_roots[key] = root


func _enqueue_realization_job(chunk_coord: Vector3i) -> void:
	var key := _chunk_key(chunk_coord)
	if realization_jobs.has(key) or visual_chunk_roots.has(key):
		return
	realization_jobs[key] = {
		"chunk_coord": chunk_coord,
		"stage": "visual_plan",
		"canonical_record": {},
		"visual_plan": {},
		"instantiation_plan": {},
		"visual_root": null,
	}


func _drain_budgeted_runtime() -> void:
	_drain_unload_cleanup_queue()
	if chunk_provider != null and chunk_provider.has_method("drain_budgeted_requests"):
		chunk_provider.drain_budgeted_requests(frame_budget_scheduler, streaming_focus_position())
	_drain_realization_queue()


func _drain_unload_cleanup_queue() -> void:
	for key in pending_unload_roots.keys():
		if not pending_unload_roots.has(key):
			continue
		var root: Node3D = pending_unload_roots[key]
		var chunk_coord := _chunk_coord_from_key(key)
		if not frame_budget_scheduler.can_start_job():
			frame_budget_scheduler.defer_job("unload_cleanup", chunk_coord)
			break
		frame_budget_scheduler.run_job(
			"unload_cleanup",
			chunk_coord,
			Callable(self, "_complete_unload_cleanup").bind(key, root)
		)


func _complete_unload_cleanup(key: String, root: Node3D) -> void:
	if root != null:
		var pool_size_before := visual_root_pool.size()
		chunk_visual_builder.destroy_or_pool(root, visual_root_pool, max_pooled_visual_roots)
		if visual_root_pool.size() > pool_size_before:
			pooled_visual_root_total += 1
	pending_unload_roots.erase(key)


func _drain_realization_queue() -> void:
	for entry in _sorted_realization_entries():
		var key: String = entry["key"]
		if not realization_jobs.has(key):
			continue
		var chunk_coord: Vector3i = realization_jobs[key]["chunk_coord"]
		var phase := _phase_for_realization_stage(String(realization_jobs[key]["stage"]))
		if not frame_budget_scheduler.can_start_job():
			frame_budget_scheduler.defer_job(phase, chunk_coord)
			break
		frame_budget_scheduler.run_job(
			phase,
			chunk_coord,
			Callable(self, "_run_realization_stage").bind(key)
		)


func _run_realization_stage(key: String) -> void:
	if not realization_jobs.has(key):
		return
	var job: Dictionary = realization_jobs[key]
	var chunk_coord: Vector3i = job["chunk_coord"]
	var stage := String(job["stage"])

	if stage == "visual_plan":
		var canonical_record: Dictionary = chunk_provider.call("get_loaded_chunk_record", chunk_coord)
		if canonical_record.is_empty():
			return
		var visual_plan: Dictionary = chunk_visual_builder.build_visual_plan_from_canonical_source(
			canonical_record,
			tile_mesh_catalog
		)
		last_visual_plan_diagnostics = visual_plan.get("diagnostics", {})
		if not bool(last_visual_plan_diagnostics.get("is_valid", true)):
			invalid_visual_plan_count += 1
		job["canonical_record"] = canonical_record
		job["visual_plan"] = visual_plan
		job["stage"] = "visual_bucket_build"
	elif stage == "visual_bucket_build":
		var instantiation_plan: Dictionary = chunk_visual_builder.build_instantiation_plan(
			chunk_coord,
			job["visual_plan"],
			tile_mesh_catalog,
			"multimesh"
		)
		last_instantiation_plan_diagnostics = instantiation_plan.get("diagnostics", {})
		job["instantiation_plan"] = instantiation_plan
		job["visual_root"] = chunk_visual_builder.build_chunk_visual_from_instantiation_plan(
			instantiation_plan,
			tile_mesh_catalog,
			chunk_edge_meters,
			chunk_provider.chunk_size_cells,
			_take_pooled_visual_root()
		)
		job["stage"] = "collision_build"
	elif stage == "collision_build":
		_add_collision_if_enabled(job["visual_root"], chunk_coord, job["canonical_record"])
		job["stage"] = "placement_build"
	elif stage == "placement_build":
		_add_placed_objects_if_enabled(job["visual_root"], chunk_coord)
		job["stage"] = "overlay_apply"
	elif stage == "overlay_apply":
		_apply_overlay(job["visual_root"], chunk_coord)
		job["stage"] = "scene_attach"
	elif stage == "scene_attach":
		_attach_realized_chunk(key, job)
		return

	realization_jobs[key] = job


func _attach_realized_chunk(key: String, job: Dictionary) -> void:
	if visual_chunk_roots.has(key):
		_cancel_realization_job(key)
		return
	var visual_root: Node3D = job["visual_root"]
	if visual_root == null:
		realization_jobs.erase(key)
		return
	var chunk_coord: Vector3i = job["chunk_coord"]
	visual_root.position = Vector3(
		float(chunk_coord.x) * chunk_edge_meters,
		float(chunk_coord.y) * chunk_edge_meters,
		float(chunk_coord.z) * chunk_edge_meters
	)
	chunk_root_container.add_child(visual_root)
	visual_chunk_roots[key] = visual_root
	realization_jobs.erase(key)


func _cancel_realization_job(key: String) -> void:
	if not realization_jobs.has(key):
		return
	var job: Dictionary = realization_jobs[key]
	var visual_root: Node3D = job.get("visual_root", null)
	if visual_root != null:
		visual_root.free()
	realization_jobs.erase(key)


func _sorted_realization_entries() -> Array:
	var entries: Array[Dictionary] = []
	var focus_position := streaming_focus_position()
	for key in realization_jobs.keys():
		var job: Dictionary = realization_jobs[key]
		var chunk_coord: Vector3i = job["chunk_coord"]
		entries.append({
			"key": key,
			"priority": 0 if String(job["stage"]) != "visual_plan" else 1,
			"distance": _chunk_distance_squared(chunk_coord, focus_position),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		if float(a["distance"]) != float(b["distance"]):
			return float(a["distance"]) < float(b["distance"])
		return String(a["key"]) < String(b["key"])
	)
	return entries


func _phase_for_realization_stage(stage: String) -> String:
	match stage:
		"visual_plan":
			return "visual_plan"
		"visual_bucket_build":
			return "visual_bucket_build"
		"collision_build":
			return "collision_build"
		"placement_build":
			return "placement_build"
		"overlay_apply":
			return "overlay_apply"
		"scene_attach":
			return "scene_attach"
	return "realization"


func visual_chunk_count() -> int:
	return visual_chunk_roots.size()


func visual_chunk_keys() -> Array:
	var keys := visual_chunk_roots.keys()
	keys.sort()
	return keys


func visual_chunk_y_layers() -> PackedInt32Array:
	var seen_layers: Dictionary = {}
	for key in visual_chunk_roots.keys():
		var parts := String(key).split(":")
		if parts.size() >= 3:
			seen_layers[int(parts[1])] = true
	var layers := PackedInt32Array()
	for layer in seen_layers.keys():
		layers.append(int(layer))
	layers.sort()
	return layers


func expected_desired_chunk_count() -> int:
	var config := streaming_config()
	var horizontal_radius := load_radius_chunks
	var vertical_radius := vertical_load_radius_chunks
	if not config.is_empty():
		horizontal_radius = int(config.get("load_radius_chunks", horizontal_radius))
		vertical_radius = int(config.get("vertical_load_radius_chunks", vertical_radius))
	return (
		(2 * maxi(horizontal_radius, 0) + 1)
		* (2 * maxi(horizontal_radius, 0) + 1)
		* (2 * maxi(vertical_radius, 0) + 1)
	)


func streaming_config() -> Dictionary:
	if streaming_node != null and streaming_node.has_method("describe_config"):
		var config: Variant = streaming_node.call("describe_config")
		if typeof(config) == TYPE_DICTIONARY:
			return config
	return {}


func _configure_frame_budget_scheduler() -> void:
	if frame_budget_scheduler == null:
		return
	frame_budget_scheduler.configure(
		frame_budget_preset,
		frame_chunk_budget_us,
		minimum_frame_budget_jobs
	)
	if chunk_provider != null and chunk_provider.has_method("configure_frame_budget_scheduler"):
		chunk_provider.configure_frame_budget_scheduler(enable_frame_budget_scheduler)


func _update_streaming_focus() -> void:
	if (
		streaming_node != null
		and player_or_camera != null
		and streaming_node.has_method("update_focus_from_vector3")
	):
		streaming_node.update_focus_from_vector3(streaming_focus_position())


func streaming_focus_position() -> Vector3:
	if player_or_camera == null:
		return Vector3(0.0, streaming_focus_fixed_y_meters, 0.0)
	var focus_position := player_or_camera.global_position
	if streaming_focus_y_policy != "focus_y":
		focus_position.y = streaming_focus_fixed_y_meters
	return focus_position


func frame_budget_diagnostics() -> Dictionary:
	var queue_sizes := {
		"provider_pending": chunk_provider.pending_request_count() if chunk_provider != null and chunk_provider.has_method("pending_request_count") else 0,
		"realization_pending": realization_jobs.size(),
		"unload_cleanup_pending": pending_unload_roots.size(),
	}
	if frame_budget_scheduler == null:
		return {
			"product_type": "FrameBudgetDiagnostics",
			"enabled": false,
			"queue_sizes": queue_sizes,
		}
	return frame_budget_scheduler.diagnostics({
		"enabled": enable_frame_budget_scheduler,
		"queue_sizes": queue_sizes,
	})


func visual_root_pool_size() -> int:
	return visual_root_pool.size()


func pooled_visual_root_count() -> int:
	return pooled_visual_root_total


func reused_visual_root_count() -> int:
	return reused_visual_root_total


func invalid_visual_plan_total() -> int:
	return invalid_visual_plan_count


func get_runtime_diagnostics() -> Dictionary:
	var provider_diagnostics: Dictionary = {}
	if chunk_provider != null and chunk_provider.has_method("get_diagnostics"):
		provider_diagnostics = chunk_provider.get_diagnostics()

	var catalog_diagnostics: Dictionary = {}
	if tile_mesh_catalog != null and tile_mesh_catalog.has_method("get_diagnostics"):
		catalog_diagnostics = tile_mesh_catalog.get_diagnostics()

	return {
		"resident_chunks": (
			streaming_node.resident_chunk_count()
			if streaming_node != null and streaming_node.has_method("resident_chunk_count")
			else 0
		),
		"pending_requests": (
			streaming_node.pending_request_count()
			if streaming_node != null and streaming_node.has_method("pending_request_count")
			else 0
		),
		"loaded_chunks": provider_diagnostics.get("loaded_chunks", 0),
		"visual_roots": visual_chunk_count(),
		"collision_bodies": collision_body_count(),
			"collision_shapes": collision_shape_count(),
			"placed_layers": placed_layer_count(),
			"placed_objects": placed_object_count(),
			"overlay_chunks": overlay_chunk_count(),
			"overlay_nodes": overlay_node_count(),
			"pooled_roots": visual_root_pool_size(),
			"reused_roots": reused_visual_root_count(),
			"cache_hits": provider_diagnostics.get("cache_hits", 0),
			"cache_misses": provider_diagnostics.get("cache_misses", 0),
			"missing_asset_keys": catalog_diagnostics.get("missing_asset_keys", []),
			"missing_asset_key_count": catalog_diagnostics.get("missing_asset_key_count", 0),
			"invalid_visual_plans": invalid_visual_plan_count,
			"streaming_focus_y_policy": streaming_focus_y_policy,
			"streaming_focus_fixed_y_meters": streaming_focus_fixed_y_meters,
			"streaming_focus_position": streaming_focus_position(),
			"generation_settings_hash": provider_diagnostics.get("generation", {}).get(
				"generation_settings_hash",
				0
			),
			"provider": provider_diagnostics,
			"catalog": catalog_diagnostics,
			"last_visual_plan": last_visual_plan_diagnostics,
			"last_instantiation_plan": last_instantiation_plan_diagnostics,
			"frame_budget": frame_budget_diagnostics(),
			"runtime_budgets": runtime_budget_contract(),
			"visual_roots_have_matching_metadata": visual_roots_have_matching_metadata(),
	}


func runtime_budget_contract() -> Dictionary:
	var cells_per_chunk := 16
	if chunk_provider != null:
		cells_per_chunk = maxi(int(chunk_provider.get("chunk_size_cells")), 1)
	return {
		"product_type": "RuntimeRealizationBudget",
		"visual_backend": "multimesh",
		"residency_root_pooling": true,
		"max_pooled_visual_roots": max_pooled_visual_roots,
		"load_radius_chunks": load_radius_chunks,
		"unload_radius_chunks": unload_radius_chunks,
		"vertical_load_radius_chunks": vertical_load_radius_chunks,
			"vertical_unload_radius_chunks": vertical_unload_radius_chunks,
			"streaming_focus_y_policy": streaming_focus_y_policy,
			"streaming_focus_fixed_y_meters": streaming_focus_fixed_y_meters,
			"frame_budget_scheduler_enabled": enable_frame_budget_scheduler,
			"frame_budget_preset": frame_budget_preset,
			"frame_chunk_budget_us": frame_chunk_budget_us,
			"minimum_frame_budget_jobs": minimum_frame_budget_jobs,
			"frame_budget_policy": "measured_shared_defer_with_one_job_minimum",
			"expected_desired_chunks": expected_desired_chunk_count(),
		"dirty_update_scope": "cell_visual_corners",
		"dirty_cell_max_visual_corners": 4,
		"dirty_realization_scope": "affected_multimesh_buckets",
		"dirty_cell_max_bucket_rebuilds": 8,
		"full_visual_rebuild_scope": "chunk_residency_or_backend_change",
		"collision_backend": "merged_collision_rectangles",
		"collision_shape_policy": "shape_owner_per_merged_blocker_or_floor_rectangle",
		"ground_floor_collision_enabled": ground_floor_collision_enabled,
		"ground_floor_thickness_meters": ground_floor_thickness_meters,
		"ground_floor_top_y_meters": ground_floor_top_y_meters,
		"max_blocker_collision_shapes_per_chunk": cells_per_chunk * cells_per_chunk,
		"max_collision_shapes_per_chunk": cells_per_chunk * cells_per_chunk * 2,
		"provider_cache_entries": (
			chunk_provider.cache_entry_count()
			if chunk_provider != null and chunk_provider.has_method("cache_entry_count")
			else 0
		),
		"formation_sample_cache_entries": (
			chunk_provider.formation_sample_cache_count()
			if chunk_provider != null and chunk_provider.has_method("formation_sample_cache_count")
			else 0
		),
	}


func collision_body_count() -> int:
	var total := 0
	for key in visual_chunk_roots:
		var root: Node3D = visual_chunk_roots[key]
		if _find_collision_body(root) != null:
			total += 1
	return total


func collision_shape_count() -> int:
	var total := 0
	for key in visual_chunk_roots:
		var body := _find_collision_body(visual_chunk_roots[key])
		if body != null:
			total += int(body.get_meta("collision_shape_count", 0))
	return total


func placed_layer_count() -> int:
	var total := 0
	for key in visual_chunk_roots:
		var root: Node3D = visual_chunk_roots[key]
		if _find_placed_layer(root) != null:
			total += 1
	return total


func placed_object_count() -> int:
	var total := 0
	for key in visual_chunk_roots:
		var layer := _find_placed_layer(visual_chunk_roots[key])
		if layer != null:
			total += layer.get_child_count()
	return total


func set_chunk_overlay_value(chunk_coord: Vector3i, key: String, value) -> void:
	if chunk_overlay_sandbox == null:
		return
	chunk_overlay_sandbox.set_overlay_value(chunk_coord, key, value)
	var root := get_visual_chunk_root(chunk_coord)
	if root != null:
		_apply_overlay(root, chunk_coord)


func get_chunk_overlay_value(chunk_coord: Vector3i, key: String, default_value = null):
	if chunk_overlay_sandbox == null:
		return default_value
	return chunk_overlay_sandbox.get_overlay_value(chunk_coord, key, default_value)


func overlay_chunk_count() -> int:
	if chunk_overlay_sandbox == null:
		return 0
	return chunk_overlay_sandbox.overlay_entry_count()


func overlay_node_count() -> int:
	var total := 0
	for key in visual_chunk_roots:
		var root: Node3D = visual_chunk_roots[key]
		if _find_child_node(root, "ChunkOverlay") != null:
			total += 1
	return total


func has_visual_chunk(chunk_coord: Vector3i) -> bool:
	return visual_chunk_roots.has(_chunk_key(chunk_coord))


func get_visual_chunk_root(chunk_coord: Vector3i) -> Node3D:
	return visual_chunk_roots.get(_chunk_key(chunk_coord))


func visual_roots_have_matching_metadata() -> bool:
	for key in visual_chunk_roots:
		var root: Node3D = visual_chunk_roots[key]
		if root == null:
			return false
		if not root.has_meta("chunk_coord"):
			return false
		if _chunk_key(root.get_meta("chunk_coord")) != key:
			return false
	return true


func clear_visual_roots_for_shutdown() -> void:
	for key in realization_jobs.keys():
		_cancel_realization_job(key)
	realization_jobs.clear()

	for key in pending_unload_roots.keys():
		var pending_root: Node3D = pending_unload_roots[key]
		if pending_root != null:
			pending_root.free()
	pending_unload_roots.clear()

	for key in visual_chunk_roots.keys():
		var active_root: Node3D = visual_chunk_roots[key]
		if active_root == null:
			continue
		if active_root.get_parent() != null:
			active_root.get_parent().remove_child(active_root)
		active_root.free()
	visual_chunk_roots.clear()

	for pooled_root in visual_root_pool:
		if pooled_root != null:
			pooled_root.free()
	visual_root_pool.clear()


func _take_pooled_visual_root() -> Node3D:
	if visual_root_pool.is_empty():
		return null
	reused_visual_root_total += 1
	return visual_root_pool.pop_back()


func _add_collision_if_enabled(
	visual_root: Node3D,
	chunk_coord: Vector3i,
	canonical_record: Dictionary
) -> void:
	if not enable_collision_prototype or chunk_collision_builder == null:
		return
	var liquid_blocks := true
	if chunk_provider != null and chunk_provider.has_method("generation_diagnostics"):
		liquid_blocks = bool(chunk_provider.generation_diagnostics().get("liquid_blocks_movement", true))
	var collision_body: StaticBody3D = chunk_collision_builder.build_chunk_collision(
		chunk_coord,
		canonical_record,
		chunk_edge_meters,
		chunk_provider.chunk_size_cells,
		{
			"liquid_blocks_movement": liquid_blocks,
			"ground_floor_collision_enabled": ground_floor_collision_enabled,
			"floor_thickness_meters": ground_floor_thickness_meters,
			"floor_top_y_meters": ground_floor_top_y_meters,
		}
	)
	visual_root.add_child(collision_body)


func _add_placed_objects_if_enabled(visual_root: Node3D, chunk_coord: Vector3i) -> void:
	if not enable_placed_asset_prototype or placed_object_layer == null:
		return
	var descriptors: Array = placed_object_layer.generate_lab_descriptors_for_chunk(
		chunk_coord,
		chunk_edge_meters
	)
	var layer: Node3D = placed_object_layer.build_chunk_layer(
		chunk_coord,
		descriptors,
		tile_mesh_catalog
	)
	visual_root.add_child(layer)


func _apply_overlay(visual_root: Node3D, chunk_coord: Vector3i) -> void:
	if chunk_overlay_sandbox == null:
		return
	chunk_overlay_sandbox.apply_overlay_to_chunk_root(visual_root, chunk_coord)


func _find_collision_body(root: Node3D) -> StaticBody3D:
	if root == null:
		return null
	for child in root.get_children():
		if child is StaticBody3D and child.name == "ChunkCollision":
			return child as StaticBody3D
	return null


func _find_placed_layer(root: Node3D) -> Node3D:
	if root == null:
		return null
	for child in root.get_children():
		if child is Node3D and child.name == "PlacedObjectLayer":
			return child as Node3D
	return null


func _find_child_node(root: Node3D, child_name: String) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.name == child_name:
			return child
	return null


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


func _chunk_coord_from_key(key: String) -> Vector3i:
	var parts := key.split(":")
	if parts.size() < 3:
		return Vector3i.ZERO
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))


func _chunk_distance_squared(chunk_coord: Vector3i, focus_position: Vector3) -> float:
	var center := Vector3(
		(float(chunk_coord.x) + 0.5) * chunk_edge_meters,
		(float(chunk_coord.y) + 0.5) * chunk_edge_meters,
		(float(chunk_coord.z) + 0.5) * chunk_edge_meters
	)
	return center.distance_squared_to(focus_position)


func _resolve_node3d_path(path: NodePath, fallback_name: String) -> Node3D:
	if not path.is_empty() and has_node(path):
		var node := get_node(path)
		if node is Node3D:
			return node
	if has_node(fallback_name):
		var fallback := get_node(fallback_name)
		if fallback is Node3D:
			return fallback
	return null
