extends RefCounted

var mesh_by_key: Dictionary = {}
var material_by_key: Dictionary = {}


func _init() -> void:
	register_default_meshes()


func register_mesh(asset_key: String, mesh: Mesh) -> void:
	mesh_by_key[asset_key] = mesh


func has_mesh(asset_key: String) -> bool:
	return mesh_by_key.has(base_key_for_asset_key(asset_key))


func get_mesh(asset_key: String) -> Mesh:
	return mesh_by_key.get(base_key_for_asset_key(asset_key))


func register_material(asset_key: String, material: Material) -> void:
	material_by_key[base_key_for_asset_key(asset_key)] = material


func get_material(asset_key: String) -> Material:
	return material_by_key.get(base_key_for_asset_key(asset_key))


func base_key_for_asset_key(asset_key: String) -> String:
	if asset_key.begins_with("corner_"):
		return "corner"
	if asset_key.begins_with("edge_"):
		return "edge"
	if asset_key.begins_with("t_"):
		return "t"
	if asset_key.begins_with("diagonal_"):
		return "diagonal"
	if asset_key == "full":
		return "full"
	if asset_key == "debug":
		return "debug"
	return asset_key


func register_default_meshes() -> void:
	_register_box_mesh("corner", Vector3(0.5, 0.7, 0.5), Color(0.18, 0.62, 0.95, 1.0))
	_register_box_mesh("edge", Vector3(1.0, 0.7, 0.42), Color(0.14, 0.76, 0.68, 1.0))
	_register_box_mesh("t", Vector3(1.0, 0.7, 0.72), Color(0.74, 0.56, 0.98, 1.0))
	_register_box_mesh("diagonal", Vector3(0.9, 0.7, 0.9), Color(0.95, 0.62, 0.23, 1.0))
	_register_box_mesh("full", Vector3(1.0, 0.7, 1.0), Color(0.9, 0.92, 0.95, 1.0))
	_register_box_mesh("debug", Vector3(1.0, 0.18, 1.0), Color(1.0, 0.25, 0.35, 1.0))


func _register_box_mesh(asset_key: String, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	register_mesh(asset_key, mesh)
	register_material(asset_key, _make_material(color))


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
