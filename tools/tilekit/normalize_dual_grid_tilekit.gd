extends SceneTree

const SOURCE_BLEND := "res://assets/source/tiles/dual_grid_tiles.blend"
const SOURCE_GLTF := "res://assets/source/tiles/dual_grid_tiles_source.gltf"
const OUTPUT_GLB := "res://assets/tiles/dual_grid_tiles.glb"
const SOURCE_TO_NORMALIZED := {
	"corner": "corner",
	"edge": "edge",
	"T": "t",
	"diagonal_corner": "diagonal",
	"full": "full",
}


func _initialize() -> void:
	quit(_normalize())


func _normalize() -> int:
	var source_root := _load_source_root()
	if source_root == null:
		push_error("Expected %s or %s to provide a source scene" % [SOURCE_BLEND, SOURCE_GLTF])
		return 1

	var export_root := Node3D.new()
	export_root.name = "dual_grid_tiles"

	var source_names := SOURCE_TO_NORMALIZED.keys()
	source_names.sort()
	for source_name in source_names:
		var source_mesh := _find_authored_mesh_instance(source_root, source_name)
		if source_mesh == null:
			push_error("Missing authored mesh node: %s" % source_name)
			source_root.free()
			export_root.free()
			return 1

		var normalized := MeshInstance3D.new()
		normalized.name = SOURCE_TO_NORMALIZED[source_name]
		normalized.mesh = source_mesh.mesh.duplicate(true)
		normalized.transform = Transform3D.IDENTITY
		export_root.add_child(normalized)

	export_root.add_child(_make_debug_mesh())

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_scene(export_root, state)
	if append_error != OK:
		push_error("Failed to append normalized tilekit scene to GLTF: %s" % append_error)
		source_root.free()
		export_root.free()
		return 1

	var write_error := document.write_to_filesystem(state, OUTPUT_GLB)
	source_root.free()
	export_root.free()
	if write_error != OK:
		push_error("Failed to write %s: %s" % [OUTPUT_GLB, write_error])
		return 1

	print("Wrote normalized tile kit: %s" % OUTPUT_GLB)
	return 0


func _load_source_root() -> Node:
	if FileAccess.file_exists("%s.import" % SOURCE_BLEND):
		var source_scene := load(SOURCE_BLEND)
		if source_scene is PackedScene:
			return (source_scene as PackedScene).instantiate()

	if not FileAccess.file_exists(SOURCE_GLTF):
		return null

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_file(SOURCE_GLTF, state)
	if append_error != OK:
		push_error("Failed to append source GLTF %s: %s" % [SOURCE_GLTF, append_error])
		return null
	return document.generate_scene(state)


func _find_authored_mesh_instance(root: Node, source_name: String) -> MeshInstance3D:
	var exact := _find_mesh_instance(root, source_name)
	if exact != null:
		return exact
	return _find_mesh_instance(root, "%s_col" % source_name)


func _find_mesh_instance(root: Node, node_name: String) -> MeshInstance3D:
	if root.name == node_name and root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_mesh_instance(child, node_name)
		if found != null:
			return found
	return null


func _make_debug_mesh() -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.18, 1.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.35, 1.0)
	material.roughness = 0.85
	mesh.material = material

	var node := MeshInstance3D.new()
	node.name = "debug"
	node.mesh = mesh
	return node
