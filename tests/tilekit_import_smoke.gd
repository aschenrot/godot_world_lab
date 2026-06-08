extends SceneTree

const MANIFEST_PATH := "res://assets/tiles/dual_grid_tiles_manifest.json"
const TILEKIT_PATH := "res://assets/tiles/dual_grid_tiles.glb"
const REQUIRED_BASE_MESHES: Array[String] = [
	"corner",
	"edge",
	"t",
	"diagonal",
	"full",
	"debug",
]
const MAX_FOOTPRINTS := {
	"corner": Vector2(0.51, 0.51),
	"edge": Vector2(1.01, 0.61),
	"t": Vector2(1.01, 1.01),
	"diagonal": Vector2(1.01, 1.01),
	"full": Vector2(1.01, 1.01),
	"debug": Vector2(1.01, 1.01),
}

var failed := false


func _initialize() -> void:
	var manifest := _load_manifest()
	_assert(not manifest.is_empty(), "manifest loads")
	_assert(manifest["normalized_glb"] == TILEKIT_PATH, "manifest points at normalized GLB")
	_assert(not bool(manifest["authored_rotated_variants"]), "manifest rejects authored rotations")

	var source_blend_path: String = manifest["source_blend"]
	var source_gltf_path: String = manifest["headless_source_gltf"]
	_assert(FileAccess.file_exists(source_blend_path), "source blend exists")
	_assert(FileAccess.file_exists(source_gltf_path), "headless source GLTF exists")
	_assert(FileAccess.file_exists(TILEKIT_PATH), "normalized GLB exists")

	var root := _load_gltf_scene(TILEKIT_PATH)
	_assert(root != null, "normalized GLB imports through GLTFDocument")
	if root != null:
		var mesh_names := _collect_mesh_names(root)
		_assert(_manifest_meshes_match(manifest, mesh_names), "manifest base meshes match GLB")
		for required_name in REQUIRED_BASE_MESHES:
			_assert(mesh_names.has(required_name), "normalized GLB has %s" % required_name)
			_assert(_mesh_has_surface(root, required_name), "%s has mesh surface" % required_name)
			_assert(_mesh_footprint_is_canonical(root, required_name), "%s has canonical footprint" % required_name)
		_assert(not _has_authored_rotation_variant(mesh_names), "normalized GLB has no rotated mesh variants")
		root.free()

	quit(1 if failed else 0)


func _load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text == "":
		return {}
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


func _load_gltf_scene(path: String) -> Node:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_file(path, state)
	if append_error != OK:
		push_error("tilekit_import_smoke failed: append GLB returned %s" % append_error)
		return null
	return document.generate_scene(state)


func _collect_mesh_names(root: Node) -> Dictionary:
	var names := {}
	_collect_mesh_names_recursive(root, names)
	return names


func _collect_mesh_names_recursive(node: Node, names: Dictionary) -> void:
	if node is MeshInstance3D:
		names[node.name] = true
	for child in node.get_children():
		_collect_mesh_names_recursive(child, names)


func _mesh_has_surface(root: Node, mesh_name: String) -> bool:
	var node := _find_mesh_instance(root, mesh_name)
	return node != null and node.mesh != null and node.mesh.get_surface_count() > 0


func _mesh_footprint_is_canonical(root: Node, mesh_name: String) -> bool:
	var node := _find_mesh_instance(root, mesh_name)
	if node == null or node.mesh == null:
		return false

	var max_footprint: Vector2 = MAX_FOOTPRINTS[mesh_name]
	var aabb := node.mesh.get_aabb()
	return aabb.size.x <= max_footprint.x and aabb.size.z <= max_footprint.y


func _find_mesh_instance(root: Node, mesh_name: String) -> MeshInstance3D:
	if root.name == mesh_name and root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_mesh_instance(child, mesh_name)
		if found != null:
			return found
	return null


func _has_authored_rotation_variant(mesh_names: Dictionary) -> bool:
	for mesh_name in mesh_names.keys():
		var name := String(mesh_name)
		if name.ends_with("_0") or name.ends_with("_90") or name.ends_with("_180") or name.ends_with("_270"):
			return true
	return false


func _manifest_meshes_match(manifest: Dictionary, mesh_names: Dictionary) -> bool:
	var base_meshes: Array = manifest.get("base_meshes", [])
	for base_mesh in base_meshes:
		if not mesh_names.has(String(base_mesh)):
			return false
	for mesh_name in mesh_names.keys():
		if not base_meshes.has(String(mesh_name)):
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("tilekit_import_smoke failed: %s" % message)
