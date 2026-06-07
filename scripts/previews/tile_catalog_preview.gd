extends Node3D

const DEFAULT_BASE_MESHES: Array[String] = [
	"corner",
	"edge",
	"t",
	"diagonal",
	"full",
	"debug",
]

var diagnostics: Dictionary = {}


func build_catalog_preview(catalog: RefCounted = null, spacing_meters: float = 2.0) -> Dictionary:
	_clear_children()
	if catalog == null:
		var Catalog := load("res://scripts/tile_mesh_catalog.gd")
		catalog = Catalog.new()

	var base_meshes := _base_meshes_for_catalog(catalog)
	for index in range(base_meshes.size()):
		var base_key := base_meshes[index]
		var preview := MeshInstance3D.new()
		preview.name = "Preview_%s" % base_key
		preview.mesh = catalog.get_mesh(base_key)
		preview.material_override = catalog.get_material(base_key)
		preview.position = Vector3(float(index) * spacing_meters, 0.0, 0.0)
		preview.set_meta("base_mesh_key", base_key)
		add_child(preview)

	diagnostics = {
		"preview_type": "tile_catalog",
		"base_meshes": base_meshes,
		"preview_node_count": get_child_count(),
		"catalog": catalog.get_asset_report(),
	}
	return diagnostics


func get_preview_diagnostics() -> Dictionary:
	return diagnostics


func _base_meshes_for_catalog(catalog: RefCounted) -> Array[String]:
	var catalog_diagnostics: Dictionary = catalog.get_diagnostics()
	var loaded: Array = catalog_diagnostics.get("loaded_base_meshes", [])
	var base_meshes: Array[String] = []
	for key in loaded:
		base_meshes.append(String(key))
	if base_meshes.is_empty():
		base_meshes = DEFAULT_BASE_MESHES.duplicate()
	base_meshes.sort()
	return base_meshes


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
