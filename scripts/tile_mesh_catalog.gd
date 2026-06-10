extends RefCounted

const DEFAULT_TILEKIT_MANIFEST_PATH := "res://assets/tiles/dual_grid_tiles_manifest.json"
const TILEKIT_MANIFEST_ADAPTER_SCRIPT := "res://scripts/assets/tilekit_manifest_adapter.gd"

var mesh_by_key: Dictionary = {}
var material_by_key: Dictionary = {}
var selected_variant: String = "default"
var missing_asset_keys: Dictionary = {}
var missing_material_keys: Dictionary = {}
var transform_contract_by_base_key: Dictionary = {}
var catalog_source: String = "fallback_boxes"
var loaded_tilekit_path: String = ""
var loaded_base_meshes: Array[String] = []
var tilekit_load_errors: Array[String] = []
var tilekit_adapter_diagnostics: Dictionary = {}


func _init() -> void:
	register_default_meshes()
	register_default_transform_contracts()
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


func get_material_for_tile(tile_data: Dictionary) -> Material:
	var asset_key := String(tile_data.get("asset_key", "debug"))
	var material_variant := String(tile_data.get("material_variant", ""))
	if material_variant != "":
		var base_key := base_key_for_asset_key(asset_key)
		var variant_key := _variant_catalog_key(base_key, material_variant)
		if material_by_key.has(variant_key):
			return material_by_key[variant_key]
	return get_material(asset_key)


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
		"tilekit_adapter": tilekit_adapter_diagnostics,
		"selected_variant": selected_variant,
		"mesh_count": mesh_by_key.size(),
		"material_count": material_by_key.size(),
		"missing_asset_key_count": missing_asset_key_count(),
		"missing_asset_keys": get_missing_asset_keys(),
		"missing_material_key_count": missing_material_key_count(),
		"missing_material_keys": get_missing_material_keys(),
		"transform_contracts": transform_contract_by_base_key,
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
	var adapter := _make_tilekit_adapter()
	var catalog_report: Dictionary = adapter.build_catalog_entries(manifest_path)
	tilekit_adapter_diagnostics = catalog_report.get("diagnostics", {})
	if not bool(catalog_report.get("is_valid", false)):
		for error in catalog_report.get("errors", []):
			_record_tilekit_error(String(error))
		return false

	var loaded_meshes: Array[String] = []
	for entry_value in catalog_report.get("catalog_entries", []):
		var entry: Dictionary = entry_value
		var base_key := String(entry["base_key"])
		register_mesh(base_key, entry["mesh"])
		var material: Material = entry.get("material", null)
		if material != null:
			register_material(base_key, material)
		var transform_contract: Dictionary = entry.get("transform_contract", {})
		if not transform_contract.is_empty():
			transform_contract_by_base_key[base_key] = _normalized_transform_contract(transform_contract)
		loaded_meshes.append(base_key)

	loaded_meshes.sort()
	catalog_source = "authored_glb"
	loaded_tilekit_path = String(catalog_report.get("normalized_glb", ""))
	loaded_base_meshes = loaded_meshes
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


func transform_contract_for_asset_key(asset_key: String) -> Dictionary:
	var base_key := base_key_for_asset_key(asset_key)
	if transform_contract_by_base_key.has(base_key):
		return transform_contract_by_base_key[base_key]
	return _default_transform_contract()


func effective_rotation_degrees_cw(asset_key: String, descriptor_rotation_degrees_cw: int) -> int:
	var contract := transform_contract_for_asset_key(asset_key)
	return _positive_degrees(
		descriptor_rotation_degrees_cw + int(contract.get("rotation_correction_degrees_cw", 0))
	)


func describe_tile_transform(asset_key: String, descriptor_rotation_degrees_cw: int) -> Dictionary:
	var contract := transform_contract_for_asset_key(asset_key)
	return {
		"asset_key": asset_key,
		"base_key": base_key_for_asset_key(asset_key),
		"descriptor_rotation_degrees_cw": _positive_degrees(descriptor_rotation_degrees_cw),
		"catalog_rotation_correction_degrees_cw": int(contract.get("rotation_correction_degrees_cw", 0)),
		"effective_rotation_degrees_cw": effective_rotation_degrees_cw(asset_key, descriptor_rotation_degrees_cw),
		"canonical_rotation_degrees_cw": int(contract.get("canonical_rotation_degrees_cw", 0)),
		"flip_x": bool(contract.get("flip_x", false)),
		"flip_z": bool(contract.get("flip_z", false)),
	}


func register_default_meshes() -> void:
	_register_box_mesh("corner", Vector3(0.5, 0.7, 0.5), Color(0.18, 0.62, 0.95, 1.0))
	_register_box_mesh("edge", Vector3(1.0, 0.7, 0.42), Color(0.14, 0.76, 0.68, 1.0))
	_register_box_mesh("t", Vector3(1.0, 0.7, 0.72), Color(0.74, 0.56, 0.98, 1.0))
	_register_box_mesh("diagonal", Vector3(0.9, 0.7, 0.9), Color(0.95, 0.62, 0.23, 1.0))
	_register_box_mesh("full", Vector3(1.0, 0.7, 1.0), Color(0.9, 0.92, 0.95, 1.0))
	_register_box_mesh("debug", Vector3(1.0, 0.18, 1.0), Color(1.0, 0.25, 0.35, 1.0))
	_register_layer_material_variants()


func register_default_transform_contracts() -> void:
	for base_key in ["corner", "edge", "t", "full", "debug"]:
		transform_contract_by_base_key[base_key] = _default_transform_contract()
	transform_contract_by_base_key["diagonal"] = _normalized_transform_contract({
		"canonical_rotation_degrees_cw": 0,
		"rotation_correction_degrees_cw": 90,
		"flip_x": false,
		"flip_z": false,
	})


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


func _register_layer_material_variants() -> void:
	for base_key in ["corner", "edge", "t", "diagonal", "full", "debug"]:
		register_material_variant(base_key, "ground", _make_material(Color(0.35, 0.62, 0.28, 1.0)))
		register_material_variant(base_key, "water", _make_material(Color(0.12, 0.42, 0.9, 0.82)))
		register_material_variant(base_key, "solid", _make_material(Color(0.52, 0.48, 0.42, 1.0)))
		register_material_variant(base_key, "cliff", _make_material(Color(0.46, 0.4, 0.34, 1.0)))


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


func _make_tilekit_adapter() -> RefCounted:
	var Adapter := load(TILEKIT_MANIFEST_ADAPTER_SCRIPT)
	return Adapter.new()


func _record_tilekit_error(message: String) -> void:
	tilekit_load_errors.append(message)


func _default_transform_contract() -> Dictionary:
	return {
		"canonical_rotation_degrees_cw": 0,
		"rotation_correction_degrees_cw": 0,
		"flip_x": false,
		"flip_z": false,
	}


func _normalized_transform_contract(contract: Dictionary) -> Dictionary:
	return {
		"canonical_rotation_degrees_cw": _positive_degrees(int(contract.get("canonical_rotation_degrees_cw", 0))),
		"rotation_correction_degrees_cw": _positive_degrees(int(contract.get("rotation_correction_degrees_cw", 0))),
		"flip_x": bool(contract.get("flip_x", false)),
		"flip_z": bool(contract.get("flip_z", false)),
	}


func _positive_degrees(degrees: int) -> int:
	var value := degrees % 360
	return value + 360 if value < 0 else value
