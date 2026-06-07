extends Node3D

@export var chunk_edge_meters: float = 32.0
@export var load_radius_chunks: int = 4
@export var unload_radius_chunks: int = 6

@onready var player_or_camera: Node3D = $PlayerOrCamera
@onready var chunk_root_container: Node3D = $ChunkRootContainer

var streaming_node: Node
var chunk_provider: Node
var debug_overlay: Node


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

