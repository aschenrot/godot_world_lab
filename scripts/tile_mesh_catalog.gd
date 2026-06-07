extends RefCounted

var mesh_by_key: Dictionary = {}


func register_mesh(asset_key: String, mesh: Mesh) -> void:
	mesh_by_key[asset_key] = mesh


func has_mesh(asset_key: String) -> bool:
	return mesh_by_key.has(asset_key)


func get_mesh(asset_key: String) -> Mesh:
	return mesh_by_key.get(asset_key)

