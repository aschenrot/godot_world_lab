extends SceneTree

var failed := false


func _initialize() -> void:
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()
	_assert(catalog.get_diagnostics()["catalog_source"] == "authored_glb", "alignment smoke uses authored GLB catalog")

	_assert(_clockwise_rotation_maps_grid_space(builder), "clockwise descriptor rotation maps to Godot X/Z space")

	var visual_plan := _single_wall_visual_plan()
	var expected_origins := _tile_transform_origin_report(builder, visual_plan["visual_tiles"])
	_assert(expected_origins.size() == 4, "single-wall fixture has four direct tile transforms")
	_assert(_has_asset_key(visual_plan["visual_tiles"], "corner_180"), "single-wall top-left corner uses corrected rotation key")
	_assert(_has_asset_key(visual_plan["visual_tiles"], "corner_270"), "single-wall top-right corner uses corrected rotation key")
	_assert(_has_asset_key(visual_plan["visual_tiles"], "corner_90"), "single-wall bottom-left corner uses corrected rotation key")
	_assert(_has_asset_key(visual_plan["visual_tiles"], "corner_0"), "single-wall bottom-right corner uses corrected rotation key")

	var root: Node3D = builder.build_chunk_visual(Vector3i.ZERO, visual_plan, catalog, 1.0, 1)
	_assert(_total_instance_count(root) == 4, "single-wall visual creates four corner instances")
	var footprint := _direct_tile_xz_bounds(builder, catalog, visual_plan["visual_tiles"])
	_assert(footprint["valid"], "single-wall visual has transformed bounds")
	_assert(footprint["min"].x >= -0.01, "single-wall visual does not extend left of logic cell: %s direct=%s" % [footprint, expected_origins])
	_assert(footprint["min"].y >= -0.01, "single-wall visual does not extend above logic cell: %s direct=%s" % [footprint, expected_origins])
	_assert(footprint["max"].x <= 1.01, "single-wall visual does not extend right of logic cell: %s direct=%s" % [footprint, expected_origins])
	_assert(footprint["max"].y <= 1.01, "single-wall visual does not extend below logic cell: %s direct=%s" % [footprint, expected_origins])

	root.free()
	quit(1 if failed else 0)


func _single_wall_visual_plan() -> Dictionary:
	var visual_tiles := [
		_visual_tile(Vector2i(0, 0), "corner_180", 180, 0b1000),
		_visual_tile(Vector2i(1, 0), "corner_270", 270, 0b0100),
		_visual_tile(Vector2i(0, 1), "corner_90", 90, 0b0010),
		_visual_tile(Vector2i(1, 1), "corner_0", 0, 0b0001),
	]
	return {
		"product_type": "ChunkVisualPlan",
		"chunk_coord": Vector3i.ZERO,
		"visual_tiles": visual_tiles,
		"tiles": visual_tiles,
		"asset_keys": ["corner_0", "corner_90", "corner_180", "corner_270"],
		"missing_assets": [],
		"bounds": {
			"has_tiles": true,
			"min_corner": Vector2i(0, 0),
			"max_corner": Vector2i(1, 1),
		},
		"diagnostics": {
			"is_valid": true,
			"fixture": "single_wall_corrected_rotation_contract",
		},
	}


func _visual_tile(corner: Vector2i, asset_key: String, rotation_degrees_cw: int, mask: int) -> Dictionary:
	return {
		"chunk_coord": Vector3i.ZERO,
		"corner": corner,
		"asset_key": asset_key,
		"rotation_degrees_cw": rotation_degrees_cw,
		"mask": mask,
		"is_empty": false,
	}


func _clockwise_rotation_maps_grid_space(builder: RefCounted) -> bool:
	var transform: Transform3D = builder._tile_transform({
		"corner": Vector2i.ZERO,
		"rotation_degrees_cw": 90,
	}, 1.0)
	var rotated := transform.basis * Vector3(-0.25, 0.0, -0.25)
	return rotated.x > 0.24 and rotated.z < -0.24


func _has_asset_key(tiles: Array, asset_key: String) -> bool:
	for tile in tiles:
		var data: Dictionary = tile
		if data["asset_key"] == asset_key:
			return true
	return false


func _direct_tile_xz_bounds(builder: RefCounted, catalog: RefCounted, visual_tiles: Array) -> Dictionary:
	var min_corner := Vector2(1.0e20, 1.0e20)
	var max_corner := Vector2(-1.0e20, -1.0e20)
	var valid := false

	for tile in visual_tiles:
		var data: Dictionary = tile
		var mesh: Mesh = catalog.get_mesh(data["asset_key"])
		if mesh == null:
			continue

		var transform: Transform3D = builder._tile_transform(data, 1.0)
		for local_point in _aabb_corners(mesh.get_aabb()):
			var point: Vector3 = transform * local_point
			min_corner.x = minf(min_corner.x, point.x)
			min_corner.y = minf(min_corner.y, point.z)
			max_corner.x = maxf(max_corner.x, point.x)
			max_corner.y = maxf(max_corner.y, point.z)
			valid = true

	return {
		"valid": valid,
		"min": min_corner,
		"max": max_corner,
	}


func _total_instance_count(root: Node3D) -> int:
	var total := 0
	for child in root.get_children():
		var bucket := child as MultiMeshInstance3D
		if bucket != null and bucket.multimesh != null:
			total += bucket.multimesh.instance_count
	return total


func _tile_transform_origin_report(builder: RefCounted, visual_tiles: Array) -> Array[Vector3]:
	var origins: Array[Vector3] = []
	for tile in visual_tiles:
		var data: Dictionary = tile
		origins.append(builder._tile_transform(data, 1.0).origin)
	return origins


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var min_point := aabb.position
	var max_point := aabb.position + aabb.size
	return [
		Vector3(min_point.x, min_point.y, min_point.z),
		Vector3(max_point.x, min_point.y, min_point.z),
		Vector3(min_point.x, max_point.y, min_point.z),
		Vector3(max_point.x, max_point.y, min_point.z),
		Vector3(min_point.x, min_point.y, max_point.z),
		Vector3(max_point.x, min_point.y, max_point.z),
		Vector3(min_point.x, max_point.y, max_point.z),
		Vector3(max_point.x, max_point.y, max_point.z),
	]


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("chunk_visual_alignment_smoke failed: %s" % message)
