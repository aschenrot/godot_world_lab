extends Node3D

@export var chunk_edge_meters: float = 32.0
@export var load_radius_chunks: int = 4
@export var unload_radius_chunks: int = 6
@export var max_pooled_visual_roots: int = 64

@onready var player_or_camera: Node3D = $PlayerOrCamera
@onready var chunk_root_container: Node3D = $ChunkRootContainer

var streaming_node: Node
var chunk_provider: Node
var debug_overlay: Node
var chunk_visual_builder: RefCounted
var tile_mesh_catalog: RefCounted
var visual_chunk_roots: Dictionary = {}
var visual_root_pool: Array[Node3D] = []
var pooled_visual_root_total: int = 0
var reused_visual_root_total: int = 0


func _ready() -> void:
	_install_streaming_node()
	_install_support_nodes()


func _process(_delta: float) -> void:
	if streaming_node != null and streaming_node.has_method("update_focus_from_vector3"):
		streaming_node.update_focus_from_vector3(player_or_camera.global_position)


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
	var catalog_script := load("res://scripts/tile_mesh_catalog.gd")
	chunk_visual_builder = builder_script.new()
	tile_mesh_catalog = catalog_script.new()


func _on_chunk_resident(x: int, y: int, z: int) -> void:
	var chunk_coord := Vector3i(x, y, z)
	var key := _chunk_key(chunk_coord)
	if visual_chunk_roots.has(key):
		return
	if chunk_provider == null or chunk_visual_builder == null or tile_mesh_catalog == null:
		return

	var logic_grid: Array = chunk_provider.call("get_loaded_chunk_logic_grid", chunk_coord)
	if logic_grid.is_empty():
		return

	var visual_plan: Dictionary = chunk_visual_builder.build_visual_plan(chunk_coord, logic_grid)
	var visual_root: Node3D = chunk_visual_builder.build_chunk_visual(
		chunk_coord,
		visual_plan,
		tile_mesh_catalog,
		chunk_edge_meters,
		chunk_provider.chunk_size_cells,
		_take_pooled_visual_root()
	)
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


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
