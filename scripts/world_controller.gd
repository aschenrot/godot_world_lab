extends Node3D

@export var chunk_edge_meters: float = 32.0
@export var load_radius_chunks: int = 4
@export var unload_radius_chunks: int = 6
@export var max_pooled_visual_roots: int = 64
@export var focus_target_path: NodePath
@export var chunk_root_container_path: NodePath
@export var enable_collision_prototype: bool = true

var player_or_camera: Node3D
var chunk_root_container: Node3D
var streaming_node: Node
var chunk_provider: Node
var debug_overlay: Node
var chunk_visual_builder: RefCounted
var chunk_collision_builder: RefCounted
var tile_mesh_catalog: RefCounted
var visual_chunk_roots: Dictionary = {}
var visual_root_pool: Array[Node3D] = []
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
	if (
		streaming_node != null
		and player_or_camera != null
		and streaming_node.has_method("update_focus_from_vector3")
	):
		streaming_node.update_focus_from_vector3(player_or_camera.global_position)


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
	streaming_node.set_load_radii(load_radius_chunks, unload_radius_chunks, 1, 2)
	streaming_node.set_planar_xz_mode()


func _install_support_nodes() -> void:
	var provider_script := load("res://scripts/chunk_provider.gd")
	var overlay_script := load("res://scripts/chunk_debug_overlay.gd")

	chunk_provider = Node.new()
	chunk_provider.name = "ChunkProvider"
	chunk_provider.set_script(provider_script)
	add_child(chunk_provider)

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
	var catalog_script := load("res://scripts/tile_mesh_catalog.gd")
	chunk_visual_builder = builder_script.new()
	chunk_collision_builder = collision_builder_script.new()
	tile_mesh_catalog = catalog_script.new()


func _on_chunk_resident(x: int, y: int, z: int) -> void:
	var chunk_coord := Vector3i(x, y, z)
	var key := _chunk_key(chunk_coord)
	if visual_chunk_roots.has(key):
		return
	if chunk_provider == null or chunk_visual_builder == null or tile_mesh_catalog == null:
		return

	var generated_chunk_data: Dictionary = chunk_provider.call("get_loaded_chunk_data", chunk_coord)
	if generated_chunk_data.is_empty():
		return

	var visual_plan: Dictionary = chunk_visual_builder.build_visual_plan_from_generated_chunk(
		generated_chunk_data,
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
	_add_collision_if_enabled(visual_root, chunk_coord, visual_plan)
	visual_root.position = Vector3(
		float(x) * chunk_edge_meters,
		float(y) * chunk_edge_meters,
		float(z) * chunk_edge_meters
	)
	chunk_root_container.add_child(visual_root)
	visual_chunk_roots[key] = visual_root


func _on_chunk_unloaded(x: int, y: int, z: int) -> void:
	var key := _chunk_key(Vector3i(x, y, z))
	var root: Node3D = visual_chunk_roots.get(key)
	if root != null:
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		var pool_size_before := visual_root_pool.size()
		chunk_visual_builder.destroy_or_pool(root, visual_root_pool, max_pooled_visual_roots)
		if visual_root_pool.size() > pool_size_before:
			pooled_visual_root_total += 1
	visual_chunk_roots.erase(key)


func visual_chunk_count() -> int:
	return visual_chunk_roots.size()


func visual_chunk_keys() -> Array:
	var keys := visual_chunk_roots.keys()
	keys.sort()
	return keys


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
		"pooled_roots": visual_root_pool_size(),
		"reused_roots": reused_visual_root_count(),
		"cache_hits": provider_diagnostics.get("cache_hits", 0),
		"cache_misses": provider_diagnostics.get("cache_misses", 0),
		"missing_asset_keys": catalog_diagnostics.get("missing_asset_keys", []),
		"missing_asset_key_count": catalog_diagnostics.get("missing_asset_key_count", 0),
		"invalid_visual_plans": invalid_visual_plan_count,
		"generation_settings_hash": provider_diagnostics.get("generation", {}).get(
			"generation_settings_hash",
			0
		),
		"provider": provider_diagnostics,
		"catalog": catalog_diagnostics,
		"last_visual_plan": last_visual_plan_diagnostics,
		"last_instantiation_plan": last_instantiation_plan_diagnostics,
		"visual_roots_have_matching_metadata": visual_roots_have_matching_metadata(),
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
	visual_plan: Dictionary
) -> void:
	if not enable_collision_prototype or chunk_collision_builder == null:
		return
	var collision_body: StaticBody3D = chunk_collision_builder.build_chunk_collision(
		chunk_coord,
		visual_plan,
		chunk_edge_meters,
		chunk_provider.chunk_size_cells
	)
	visual_root.add_child(collision_body)


func _find_collision_body(root: Node3D) -> StaticBody3D:
	if root == null:
		return null
	for child in root.get_children():
		if child is StaticBody3D and child.name == "ChunkCollision":
			return child as StaticBody3D
	return null


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


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
