extends RefCounted

const DEFAULT_TILEKIT_MANIFEST_PATH := "res://assets/tiles/dual_grid_tiles_manifest.json"
const TILEKIT_SCHEMA := "crystonix.godot_world_lab.tilekit.v1"


func load_manifest(manifest_path: String = DEFAULT_TILEKIT_MANIFEST_PATH) -> Dictionary:
	var text := FileAccess.get_file_as_string(manifest_path)
	if text == "":
		return {}
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


func validate_manifest(manifest_path: String = DEFAULT_TILEKIT_MANIFEST_PATH) -> Dictionary:
	var manifest := load_manifest(manifest_path)
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("manifest is missing or invalid: %s" % manifest_path)
		return _manifest_report(manifest_path, manifest, errors)

	if String(manifest.get("schema", "")) != TILEKIT_SCHEMA:
		errors.append("unsupported tilekit schema: %s" % manifest.get("schema", ""))

	var normalized_glb := String(manifest.get("normalized_glb", ""))
	if normalized_glb == "":
		errors.append("manifest lacks normalized_glb")
	elif not FileAccess.file_exists(normalized_glb):
		errors.append("normalized_glb is missing: %s" % normalized_glb)

	var base_meshes: Array = manifest.get("base_meshes", [])
	if base_meshes.is_empty():
		errors.append("manifest lacks base_meshes")
	for base_mesh in base_meshes:
		var base_key := String(base_mesh)
		if _is_authored_rotation_variant(base_key):
			errors.append("base_meshes contains authored rotated variant: %s" % base_key)

	if bool(manifest.get("authored_rotated_variants", false)):
		errors.append("authored_rotated_variants must stay false")

	var source_blend := String(manifest.get("source_blend", ""))
	if source_blend != "" and not FileAccess.file_exists(source_blend):
		errors.append("source_blend is missing: %s" % source_blend)

	var source_gltf := String(manifest.get("headless_source_gltf", ""))
	if source_gltf != "" and not FileAccess.file_exists(source_gltf):
		errors.append("headless_source_gltf is missing: %s" % source_gltf)

	return _manifest_report(manifest_path, manifest, errors)


func build_catalog_entries(manifest_path: String = DEFAULT_TILEKIT_MANIFEST_PATH) -> Dictionary:
	var validation := validate_manifest(manifest_path)
	var errors: Array[String] = _string_array(validation["errors"])
	var manifest: Dictionary = validation["manifest"]
	var entries: Array[Dictionary] = []
	var loaded_base_meshes: Array[String] = []
	var normalized_glb := String(manifest.get("normalized_glb", ""))

	if errors.is_empty():
		var root := _load_gltf_scene(normalized_glb, errors)
		if root != null:
			for base_mesh in manifest.get("base_meshes", []):
				var base_key := String(base_mesh)
				var mesh_instance := _find_mesh_instance(root, base_key)
				if mesh_instance == null or mesh_instance.mesh == null:
					errors.append("normalized GLB is missing mesh: %s" % base_key)
					continue
				var material := _first_surface_material(mesh_instance.mesh)
				entries.append({
					"base_key": base_key,
					"mesh": mesh_instance.mesh.duplicate(true),
					"material": material.duplicate(true) if material != null else null,
					"source_path": normalized_glb,
				})
				loaded_base_meshes.append(base_key)
			root.free()

	loaded_base_meshes.sort()
	return {
		"is_valid": errors.is_empty(),
		"manifest_path": manifest_path,
		"manifest": manifest,
		"normalized_glb": normalized_glb,
		"base_meshes": manifest.get("base_meshes", []),
		"catalog_entries": entries,
		"errors": errors,
		"diagnostics": {
			"adapter": "tilekit_manifest_adapter",
			"schema": manifest.get("schema", ""),
			"manifest_path": manifest_path,
			"normalized_glb": normalized_glb,
			"source_blend": manifest.get("source_blend", ""),
			"headless_source_gltf": manifest.get("headless_source_gltf", ""),
			"authored_rotated_variants": manifest.get("authored_rotated_variants", false),
			"loaded_base_meshes": loaded_base_meshes,
			"catalog_entry_count": entries.size(),
			"errors": errors,
		},
	}


func build_mesh_library_editor_artifact(manifest_path: String = DEFAULT_TILEKIT_MANIFEST_PATH) -> Dictionary:
	var catalog_report := build_catalog_entries(manifest_path)
	var errors: Array[String] = _string_array(catalog_report["errors"])
	var library := MeshLibrary.new()
	var item_ids_by_key: Dictionary = {}

	if errors.is_empty():
		var entries: Array = catalog_report["catalog_entries"]
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			var item_id := index + 1
			library.create_item(item_id)
			library.set_item_name(item_id, entry["base_key"])
			library.set_item_mesh(item_id, entry["mesh"])
			item_ids_by_key[entry["base_key"]] = item_id

	return {
		"is_valid": errors.is_empty(),
		"runtime_truth": false,
		"artifact_kind": "MeshLibrary",
		"mesh_library": library,
		"item_ids_by_key": item_ids_by_key,
		"errors": errors,
		"diagnostics": {
			"adapter": "tilekit_manifest_adapter",
			"artifact_kind": "MeshLibrary",
			"runtime_truth": false,
			"item_count": item_ids_by_key.size(),
			"item_ids_by_key": item_ids_by_key,
			"errors": errors,
		},
	}


func _manifest_report(manifest_path: String, manifest: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"is_valid": errors.is_empty(),
		"manifest_path": manifest_path,
		"manifest": manifest,
		"errors": errors,
		"diagnostics": {
			"adapter": "tilekit_manifest_adapter",
			"schema": manifest.get("schema", ""),
			"manifest_path": manifest_path,
			"normalized_glb": manifest.get("normalized_glb", ""),
			"base_meshes": manifest.get("base_meshes", []),
			"authored_rotated_variants": manifest.get("authored_rotated_variants", false),
			"errors": errors,
		},
	}


func _load_gltf_scene(path: String, errors: Array[String]) -> Node:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_file(path, state)
	if append_error != OK:
		errors.append("GLTF append failed for %s: %s" % [path, append_error])
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


func _is_authored_rotation_variant(mesh_name: String) -> bool:
	return (
		mesh_name.ends_with("_0")
		or mesh_name.ends_with("_90")
		or mesh_name.ends_with("_180")
		or mesh_name.ends_with("_270")
	)


func _string_array(values: Array) -> Array[String]:
	var strings: Array[String] = []
	for value in values:
		strings.append(String(value))
	return strings
