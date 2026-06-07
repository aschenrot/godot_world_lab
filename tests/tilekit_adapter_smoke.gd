extends SceneTree

const MANIFEST_PATH := "res://assets/tiles/dual_grid_tiles_manifest.json"
const REQUIRED_BASE_MESHES: Array[String] = [
	"corner",
	"edge",
	"t",
	"diagonal",
	"full",
	"debug",
]

var failed := false


func _initialize() -> void:
	var Adapter := load("res://scripts/assets/tilekit_manifest_adapter.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")
	var adapter: RefCounted = Adapter.new()

	var validation: Dictionary = adapter.validate_manifest(MANIFEST_PATH)
	_assert(bool(validation["is_valid"]), "manifest validates")
	_assert(validation["errors"].is_empty(), "manifest validation has no errors")

	var catalog_report: Dictionary = adapter.build_catalog_entries(MANIFEST_PATH)
	_assert(bool(catalog_report["is_valid"]), "catalog entries build")
	_assert(catalog_report["errors"].is_empty(), "catalog entry report has no errors")
	_assert(catalog_report["catalog_entries"].size() == REQUIRED_BASE_MESHES.size(), "catalog entry count matches base meshes")
	for base_mesh in REQUIRED_BASE_MESHES:
		_assert(_has_catalog_entry(catalog_report, base_mesh), "catalog report has %s" % base_mesh)

	var artifact_report: Dictionary = adapter.build_mesh_library_editor_artifact(MANIFEST_PATH)
	_assert(bool(artifact_report["is_valid"]), "MeshLibrary editor artifact builds")
	_assert(not bool(artifact_report["runtime_truth"]), "MeshLibrary artifact is not runtime truth")
	var library: MeshLibrary = artifact_report["mesh_library"]
	_assert(library.get_item_list().size() == REQUIRED_BASE_MESHES.size(), "MeshLibrary item count matches base meshes")
	for base_mesh in REQUIRED_BASE_MESHES:
		_assert(artifact_report["item_ids_by_key"].has(base_mesh), "MeshLibrary has item for %s" % base_mesh)

	var catalog: RefCounted = Catalog.new()
	var diagnostics: Dictionary = catalog.get_diagnostics()
	_assert(diagnostics["catalog_source"] == "authored_glb", "runtime catalog still loads authored GLB")
	_assert(diagnostics["tilekit_adapter"]["adapter"] == "tilekit_manifest_adapter", "runtime catalog reports adapter diagnostics")
	_assert(not diagnostics["tilekit_adapter"].get("authored_rotated_variants", true), "adapter rejects authored rotations")

	quit(1 if failed else 0)


func _has_catalog_entry(catalog_report: Dictionary, base_mesh: String) -> bool:
	for entry in catalog_report["catalog_entries"]:
		var data: Dictionary = entry
		if data["base_key"] == base_mesh and data["mesh"] is ArrayMesh:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("tilekit_adapter_smoke failed: %s" % message)
