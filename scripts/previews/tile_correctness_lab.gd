extends Node3D

@export var auto_build: bool = true

const EXPECTED_DESCRIPTOR_TABLE := {
	0: {"asset_key": "empty", "rotation_degrees_cw": 0, "kind": "empty"},
	1: {"asset_key": "corner_0", "rotation_degrees_cw": 0, "kind": "corner"},
	2: {"asset_key": "corner_90", "rotation_degrees_cw": 90, "kind": "corner"},
	3: {"asset_key": "edge_0", "rotation_degrees_cw": 0, "kind": "edge"},
	4: {"asset_key": "corner_270", "rotation_degrees_cw": 270, "kind": "corner"},
	5: {"asset_key": "edge_270", "rotation_degrees_cw": 270, "kind": "edge"},
	6: {"asset_key": "diagonal_90", "rotation_degrees_cw": 90, "kind": "diagonal"},
	7: {"asset_key": "t_180", "rotation_degrees_cw": 180, "kind": "t"},
	8: {"asset_key": "corner_180", "rotation_degrees_cw": 180, "kind": "corner"},
	9: {"asset_key": "diagonal_0", "rotation_degrees_cw": 0, "kind": "diagonal"},
	10: {"asset_key": "edge_90", "rotation_degrees_cw": 90, "kind": "edge"},
	11: {"asset_key": "t_270", "rotation_degrees_cw": 270, "kind": "t"},
	12: {"asset_key": "edge_180", "rotation_degrees_cw": 180, "kind": "edge"},
	13: {"asset_key": "t_90", "rotation_degrees_cw": 90, "kind": "t"},
	14: {"asset_key": "t_0", "rotation_degrees_cw": 0, "kind": "t"},
	15: {"asset_key": "full", "rotation_degrees_cw": 0, "kind": "full"},
}

var diagnostics: Dictionary = {}


func _ready() -> void:
	if auto_build:
		build_tile_correctness_lab()


func build_tile_correctness_lab(
	catalog: RefCounted = null,
	builder: RefCounted = null,
	provider: Node = null
) -> Dictionary:
	_clear_generated_children()

	if catalog == null:
		var Catalog := load("res://scripts/tile_mesh_catalog.gd")
		catalog = Catalog.new()
	if builder == null:
		var Builder := load("res://scripts/chunk_visual_builder.gd")
		builder = Builder.new()
	var created_provider := false
	if provider == null:
		var Provider := load("res://scripts/chunk_provider.gd")
		provider = Provider.new()
		created_provider = true

	var content_root := Node3D.new()
	content_root.name = "TileCorrectnessContent"
	content_root.set_meta("tile_correctness_generated", true)
	add_child(content_root)

	var mapper := _make_mapper()
	var mask_matrix: Array = []
	var seam_fixture: Dictionary = {}
	if mapper != null:
		mask_matrix = _build_mask_matrix(content_root, mapper, catalog)
		seam_fixture = _build_cross_chunk_seam_fixture(content_root, provider, builder, catalog)
	if created_provider:
		provider.free()

	var catalog_report: Dictionary = catalog.get_asset_report()
	diagnostics = {
		"preview_type": "tile_correctness_lab",
		"mask_count": mask_matrix.size(),
		"mask_matrix": mask_matrix,
		"cross_chunk_seam": seam_fixture,
		"missing_asset_keys": catalog_report.get("missing_asset_keys", []),
		"missing_material_keys": catalog_report.get("missing_material_keys", []),
		"catalog": catalog_report,
		"is_valid": (
			mapper != null
			and mask_matrix.size() == 16
			and seam_fixture.get("duplicate_world_corners", []).is_empty()
			and seam_fixture.get("emitted_out_of_bounds_corners", []).is_empty()
			and int(seam_fixture.get("invalid_plan_count", 0)) == 0
			and catalog_report.get("missing_asset_keys", []).is_empty()
			and catalog_report.get("missing_material_keys", []).is_empty()
		),
	}
	return diagnostics


func get_preview_diagnostics() -> Dictionary:
	return diagnostics


func _build_mask_matrix(content_root: Node3D, mapper: Object, catalog: RefCounted) -> Array:
	var mask_root := Node3D.new()
	mask_root.name = "MaskMatrix"
	content_root.add_child(mask_root)

	var mask_diagnostics: Array[Dictionary] = []
	for mask in range(16):
		var mask_bits := _mask_bits(mask)
		var panel := Node3D.new()
		panel.name = "Mask_%s" % mask_bits
		panel.position = Vector3(float(mask % 4) * 3.0, 0.0, float(mask / 4) * 3.0)
		mask_root.add_child(panel)

		var asset_key := String(mapper.asset_key_for_mask(mask))
		var rotation := int(mapper.rotation_degrees_for_mask(mask))
		var kind := String(mapper.kind_for_mask(mask))
		panel.set_meta("mask", mask)
		panel.set_meta("asset_key", asset_key)
		panel.set_meta("rotation_degrees_cw", rotation)
		panel.set_meta("kind", kind)

		_add_occupancy_markers(panel, mask)
		if asset_key != "empty":
			_add_catalog_mesh_preview(panel, catalog, asset_key, rotation)
		_add_label(
			panel,
			"%s\n%s\n%s deg" % [mask_bits, asset_key, rotation],
			Vector3(-1.25, 0.65, 1.25)
		)

		mask_diagnostics.append({
			"mask": mask,
			"asset_key": asset_key,
			"rotation_degrees_cw": rotation,
			"kind": kind,
			"expected": EXPECTED_DESCRIPTOR_TABLE[mask],
			"matches_expected": (
				asset_key == EXPECTED_DESCRIPTOR_TABLE[mask]["asset_key"]
				and rotation == int(EXPECTED_DESCRIPTOR_TABLE[mask]["rotation_degrees_cw"])
				and kind == EXPECTED_DESCRIPTOR_TABLE[mask]["kind"]
			),
		})

	return mask_diagnostics


func _build_cross_chunk_seam_fixture(
	content_root: Node3D,
	provider: Node,
	builder: RefCounted,
	catalog: RefCounted
) -> Dictionary:
	var seam_root := Node3D.new()
	seam_root.name = "CrossChunkSeam"
	seam_root.position = Vector3(0.0, 0.0, 15.0)
	content_root.add_child(seam_root)

	provider.chunk_size_cells = 4
	provider.world_seed = 17
	provider.wall_threshold_percent = 100
	provider.debug_force_chunk_border = false
	provider.smoothing_passes = 0
	provider.room_attempts = 0

	var chunk_edge_meters := 4.0
	var coords := [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(1, 0, 1),
	]
	var world_corner_owner: Dictionary = {}
	var duplicate_world_corners: Array[String] = []
	var emitted_out_of_bounds_corners: Array[Dictionary] = []
	var missing_asset_keys: Dictionary = {}
	var invalid_plan_count := 0
	var chunk_reports: Array[Dictionary] = []

	for chunk_coord in coords:
		var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
		var generated_chunk_data: Dictionary = provider.make_generated_chunk_data(chunk_coord, logic_grid)
		var visual_plan: Dictionary = builder.build_visual_plan_from_generated_chunk(
			generated_chunk_data,
			catalog
		)
		var instantiation_plan: Dictionary = builder.build_instantiation_plan(
			chunk_coord,
			visual_plan,
			catalog,
			"multimesh"
		)
		var chunk_root: Node3D = builder.build_chunk_visual_from_instantiation_plan(
			instantiation_plan,
			catalog,
			chunk_edge_meters,
			provider.chunk_size_cells
		)
		chunk_root.position = Vector3(
			float(chunk_coord.x) * chunk_edge_meters,
			0.0,
			float(chunk_coord.z) * chunk_edge_meters
		)
		seam_root.add_child(chunk_root)

		var diagnostics_for_plan: Dictionary = visual_plan.get("diagnostics", {})
		if not bool(diagnostics_for_plan.get("is_valid", false)):
			invalid_plan_count += 1
		for missing_asset in visual_plan.get("missing_assets", []):
			missing_asset_keys[String(missing_asset)] = true

		for tile in visual_plan.get("visual_tiles", []):
			var data: Dictionary = tile
			var local_corner: Vector2i = data["corner"]
			if (
				local_corner.x < 0
				or local_corner.y < 0
				or local_corner.x >= provider.chunk_size_cells
				or local_corner.y >= provider.chunk_size_cells
			):
				emitted_out_of_bounds_corners.append(data)

			var world_key := _world_corner_key(data["world_corner"])
			if world_corner_owner.has(world_key):
				duplicate_world_corners.append(world_key)
			else:
				world_corner_owner[world_key] = _chunk_key(chunk_coord)

			_add_label(
				seam_root,
				"%s\n%s\n%s\n%s %s" % [
					_chunk_key(chunk_coord),
					str(local_corner),
					str(data["world_corner"]),
					data["asset_key"],
					data["rotation_degrees_cw"],
				],
				chunk_root.position + Vector3(float(local_corner.x) + 0.08, 0.9, float(local_corner.y) + 0.08),
				0.045
			)

		chunk_reports.append({
			"chunk_coord": chunk_coord,
			"tile_count": visual_plan.get("visual_tiles", []).size(),
			"formation_mode": visual_plan.get("formation_mode", ""),
			"diagnostics": diagnostics_for_plan,
		})

	_add_chunk_boundary_lines(seam_root, provider.chunk_size_cells, coords.size())

	var missing_keys := missing_asset_keys.keys()
	missing_keys.sort()
	duplicate_world_corners.sort()
	return {
		"chunk_count": coords.size(),
		"chunk_reports": chunk_reports,
		"world_corner_count": world_corner_owner.size(),
		"duplicate_world_corners": duplicate_world_corners,
		"emitted_out_of_bounds_corners": emitted_out_of_bounds_corners,
		"invalid_plan_count": invalid_plan_count,
		"missing_asset_keys": missing_keys,
	}


func _add_occupancy_markers(parent: Node3D, mask: int) -> void:
	var positions := [
		Vector3(-0.42, 0.0, -0.42),
		Vector3(0.42, 0.0, -0.42),
		Vector3(-0.42, 0.0, 0.42),
		Vector3(0.42, 0.0, 0.42),
	]
	for bit in range(4):
		var marker := MeshInstance3D.new()
		marker.name = "Bit_%s" % bit
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.32, 0.05, 0.32)
		marker.mesh = mesh
		marker.position = positions[bit]
		marker.material_override = _marker_material((mask & (1 << bit)) != 0)
		marker.set_meta("mask_bit", bit)
		marker.set_meta("occupied", (mask & (1 << bit)) != 0)
		parent.add_child(marker)


func _add_catalog_mesh_preview(
	parent: Node3D,
	catalog: RefCounted,
	asset_key: String,
	rotation_degrees_cw: int
) -> void:
	var preview := MeshInstance3D.new()
	preview.name = "Mesh_%s" % asset_key
	preview.mesh = catalog.get_mesh(asset_key)
	preview.material_override = catalog.get_material(asset_key)
	preview.position = Vector3(0.0, 0.18, 0.0)
	preview.rotation_degrees = Vector3(0.0, -float(rotation_degrees_cw), 0.0)
	preview.set_meta("asset_key", asset_key)
	preview.set_meta("rotation_degrees_cw", rotation_degrees_cw)
	parent.add_child(preview)


func _add_chunk_boundary_lines(parent: Node3D, chunk_size: int, _chunk_count: int) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.25, 1.0)
	var extent := float(chunk_size * 2)
	for index in range(3):
		var x_line := MeshInstance3D.new()
		var x_mesh := BoxMesh.new()
		x_mesh.size = Vector3(0.04, 0.06, extent)
		x_line.mesh = x_mesh
		x_line.material_override = material
		x_line.position = Vector3(float(index * chunk_size), 0.08, extent * 0.5 - 0.5)
		parent.add_child(x_line)

		var z_line := MeshInstance3D.new()
		var z_mesh := BoxMesh.new()
		z_mesh.size = Vector3(extent, 0.06, 0.04)
		z_line.mesh = z_mesh
		z_line.material_override = material
		z_line.position = Vector3(extent * 0.5 - 0.5, 0.08, float(index * chunk_size))
		parent.add_child(z_line)


func _add_label(
	parent: Node3D,
	text: String,
	position: Vector3,
	pixel_size: float = 0.06
) -> void:
	var label := Label3D.new()
	label.name = "TileLabel"
	label.text = text
	label.pixel_size = pixel_size
	label.position = position
	label.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	parent.add_child(label)


func _marker_material(occupied: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.85, 0.42, 1.0) if occupied else Color(0.08, 0.1, 0.12, 1.0)
	return material


func _make_mapper() -> Object:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		push_error("GodotGridTopologyMapper is unavailable. Build and copy godot_grid.")
		return null
	return ClassDB.instantiate("GodotGridTopologyMapper") as Object


func _world_corner_key(world_corner: Vector2i) -> String:
	return "%s:%s" % [world_corner.x, world_corner.y]


func _chunk_key(chunk_coord: Vector3i) -> String:
	return "%s:%s:%s" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]


func _mask_bits(mask: int) -> String:
	var bits := ""
	for bit in range(3, -1, -1):
		bits += "1" if (mask & (1 << bit)) != 0 else "0"
	return bits


func _clear_generated_children() -> void:
	for child in get_children():
		if child.has_meta("tile_correctness_generated"):
			remove_child(child)
			child.free()
