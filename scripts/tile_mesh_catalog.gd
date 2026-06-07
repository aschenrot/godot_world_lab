extends RefCounted

var mesh_by_key: Dictionary = {}
var material_by_key: Dictionary = {}
var selected_variant: String = "default"
var missing_asset_keys: Dictionary = {}


func _init() -> void:
	register_default_meshes()


func register_mesh(asset_key: String, mesh: Mesh) -> void:
	mesh_by_key[base_key_for_asset_key(asset_key)] = mesh


func register_mesh_variant(asset_key: String, variant: String, mesh: Mesh) -> void:
	mesh_by_key[_variant_catalog_key(base_key_for_asset_key(asset_key), variant)] = mesh


func has_mesh(asset_key: String) -> bool:
	return _resolve_mesh_key(asset_key) != ""


func get_mesh(asset_key: String) -> Mesh:
	var mesh_key := _resolve_mesh_key(asset_key)
	if mesh_key == "":
		_record_missing_asset_key(asset_key)
		return mesh_by_key.get("debug")
	return mesh_by_key.get(mesh_key)


func register_material(asset_key: String, material: Material) -> void:
	material_by_key[base_key_for_asset_key(asset_key)] = material


func register_material_variant(asset_key: String, variant: String, material: Material) -> void:
	material_by_key[_variant_catalog_key(base_key_for_asset_key(asset_key), variant)] = material


func get_material(asset_key: String) -> Material:
	var material_key := _resolve_material_key(asset_key)
	if material_key == "":
		return material_by_key.get("debug")
	return material_by_key.get(material_key)


func set_selected_variant(variant: String) -> void:
	selected_variant = variant


func get_selected_variant() -> String:
	return selected_variant


func validate_visual_plan(visual_plan: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	var present: Array[String] = []
	var seen: Dictionary = {}

	for tile in visual_plan.get("tiles", []):
		var data: Dictionary = tile
		var asset_key: String = data["asset_key"]
		if seen.has(asset_key):
			continue
		seen[asset_key] = true
		if has_mesh(asset_key):
			present.append(asset_key)
		else:
			missing.append(asset_key)

	present.sort()
	missing.sort()
	return {
		"is_valid": missing.is_empty(),
		"variant": selected_variant,
		"present_asset_keys": present,
		"missing_asset_keys": missing,
	}


func missing_asset_key_count() -> int:
	return missing_asset_keys.size()


func clear_missing_asset_keys() -> void:
	missing_asset_keys.clear()


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


func _resolve_mesh_key(asset_key: String) -> String:
	var base_key := base_key_for_asset_key(asset_key)
	var variant_key := _variant_catalog_key(base_key, selected_variant)
	if selected_variant != "default" and mesh_by_key.has(variant_key):
		return variant_key
	if mesh_by_key.has(base_key):
		return base_key
	return ""


func _resolve_material_key(asset_key: String) -> String:
	var base_key := base_key_for_asset_key(asset_key)
	var variant_key := _variant_catalog_key(base_key, selected_variant)
	if selected_variant != "default" and material_by_key.has(variant_key):
		return variant_key
	if material_by_key.has(base_key):
		return base_key
	return ""


func _variant_catalog_key(base_key: String, variant: String) -> String:
	if variant == "" or variant == "default":
		return base_key
	return "%s@%s" % [base_key, variant]


func _record_missing_asset_key(asset_key: String) -> void:
	missing_asset_keys[asset_key] = true
