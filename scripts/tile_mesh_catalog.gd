extends RefCounted

const DEFAULT_TILEKIT_MANIFEST_PATH := "res://assets/tiles/dual_grid_tiles_manifest.json"

var mesh_by_key: Dictionary = {}
var material_by_key: Dictionary = {}
var selected_variant: String = "default"
var missing_asset_keys: Dictionary = {}
var missing_material_keys: Dictionary = {}
var catalog_source: String = "fallback_boxes"
var loaded_tilekit_path: String = ""
var loaded_base_meshes: Array[String] = []
var tilekit_load_errors: Array[String] = []


func _init() -> void:
	register_default_meshes()
	load_authored_tilekit()


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
		_record_missing_material_key(asset_key)
		return material_by_key.get("debug")
	return material_by_key.get(material_key)


func set_selected_variant(variant: String) -> void:
	selected_variant = variant


func get_selected_variant() -> String:
	return selected_variant


func validate_visual_plan(visual_plan: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	var present: Array[String] = []
	var missing_materials: Array[String] = []
	var present_materials: Array[String] = []
	var seen: Dictionary = {}
	var tiles: Array = visual_plan.get("visual_tiles", visual_plan.get("tiles", []))

	for tile in tiles:
		var data: Dictionary = tile
		var asset_key: String = data["asset_key"]
		if seen.has(asset_key):
			continue
		seen[asset_key] = true
		if has_mesh(asset_key):
			present.append(asset_key)
		else:
			missing.append(asset_key)
		if _resolve_material_key(asset_key) != "":
			present_materials.append(asset_key)
		else:
			missing_materials.append(asset_key)

	present.sort()
	missing.sort()
	present_materials.sort()
	missing_materials.sort()
	return {
		"is_valid": missing.is_empty() and missing_materials.is_empty(),
		"variant": selected_variant,
		"present_asset_keys": present,
		"missing_asset_keys": missing,
		"present_material_keys": present_materials,
		"missing_material_keys": missing_materials,
	}


func missing_asset_key_count() -> int:
	return missing_asset_keys.size()


func missing_material_key_count() -> int:
	return missing_material_keys.size()


func get_missing_asset_keys() -> Array:
	var keys := missing_asset_keys.keys()
	keys.sort()
	return keys


func get_missing_material_keys() -> Array:
	var keys := missing_material_keys.keys()
	keys.sort()
	return keys


func get_diagnostics() -> Dictionary:
	return {
		"catalog_source": catalog_source,
		"loaded_tilekit_path": loaded_tilekit_path,
		"loaded_base_meshes": loaded_base_meshes,
		"tilekit_load_errors": tilekit_load_errors,
		"selected_variant": selected_variant,
		"mesh_count": mesh_by_key.size(),
		"material_count": material_by_key.size(),
		"missing_asset_key_count": missing_asset_key_count(),
		"missing_asset_keys": get_missing_asset_keys(),
		"missing_material_key_count": missing_material_key_count(),
		"missing_material_keys": get_missing_material_keys(),
	}


func clear_missing_asset_keys() -> void:
	missing_asset_keys.clear()
	missing_material_keys.clear()


func get_asset_report(visual_plan: Dictionary = {}) -> Dictionary:
	var report := get_diagnostics()
	if not visual_plan.is_empty():
		report["visual_plan_validation"] = validate_visual_plan(visual_plan)
	return report


func load_authored_tilekit(manifest_path: String = DEFAULT_TILEKIT_MANIFEST_PATH) -> bool:
	var manifest := _load_manifest(manifest_path)
	if manifest.is_empty():
		_record_tilekit_error("Tilekit manifest is missing or invalid: %s" % manifest_path)
		return false

	var tilekit_path: String = manifest.get("normalized_glb", "")
	var base_meshes: Array = manifest.get("base_meshes", [])
	if tilekit_path == "" or base_meshes.is_empty():
		_record_tilekit_error("Tilekit manifest lacks normalized_glb or base_meshes")
		return false

	var root := _load_gltf_scene(tilekit_path)
	if root == null:
		_record_tilekit_error("Failed to load normalized tilekit GLB: %s" % tilekit_path)
		return false

	var loaded_meshes: Array[String] = []
	for base_mesh in base_meshes:
		var base_key := String(base_mesh)
		var mesh_instance := _find_mesh_instance(root, base_key)
		if mesh_instance == null or mesh_instance.mesh == null:
			_record_tilekit_error("Missing normalized tilekit mesh: %s" % base_key)
			root.free()
			return false
		register_mesh(base_key, mesh_instance.mesh.duplicate(true))
		var material := _first_surface_material(mesh_instance.mesh)
		if material != null:
			register_material(base_key, material.duplicate(true))
		loaded_meshes.append(base_key)

	loaded_meshes.sort()
	catalog_source = "authored_glb"
	loaded_tilekit_path = tilekit_path
	loaded_base_meshes = loaded_meshes
	root.free()
	return true


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


func _record_missing_material_key(asset_key: String) -> void:
	missing_material_keys[asset_key] = true


func _load_manifest(manifest_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(manifest_path)
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
		_record_tilekit_error("GLTF append failed for %s: %s" % [path, append_error])
		return null
	return document.generate_scene(state)


func _find_mesh_instance(root: Node, mesh_name: String) -> MeshInstance3D:
	if root.name == mesh_name and root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_mesh_instance(child, mesh_name)
		if found != null:
			return found
	return null


func _first_surface_material(mesh: Mesh) -> Material:
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	return mesh.surface_get_material(0)


func _record_tilekit_error(message: String) -> void:
	tilekit_load_errors.append(message)
