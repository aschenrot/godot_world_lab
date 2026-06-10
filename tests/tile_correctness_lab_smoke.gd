extends SceneTree

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

var failed := false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		quit(1)
		return

	var lab: Node3D = load("res://scenes/previews/tile_correctness_lab.tscn").instantiate()
	lab.auto_build = false
	root.add_child(lab)

	var diagnostics: Dictionary = lab.build_tile_correctness_lab()
	_assert(bool(diagnostics.get("is_valid", false)), "tile correctness lab diagnostics are valid")
	_assert(diagnostics["mask_layer_count"] == 3, "lab represents three visual layers")
	_assert(diagnostics["mask_count"] == 48, "lab represents all 16 masks for each layer")
	_assert(
		diagnostics["catalog"]["catalog_source"] == "authored_glb",
		"lab uses authored tilekit catalog"
	)
	_assert(diagnostics["missing_asset_keys"].is_empty(), "lab has no missing authored meshes")
	_assert(diagnostics["missing_material_keys"].is_empty(), "lab has no missing materials")

	var seen_masks: Dictionary = {}
	var seen_layers: Dictionary = {}
	for entry in diagnostics["mask_matrix"]:
		var layer_id: String = entry["layer_id"]
		var mask: int = entry["mask"]
		seen_masks["%s:%s" % [layer_id, mask]] = true
		seen_layers[layer_id] = true
		var expected: Dictionary = EXPECTED_DESCRIPTOR_TABLE[mask]
		_assert(entry["asset_key"] == expected["asset_key"], "asset key matches descriptor table")
		_assert(
			int(entry["rotation_degrees_cw"]) == int(expected["rotation_degrees_cw"]),
			"rotation matches descriptor table"
		)
		_assert(entry["kind"] == expected["kind"], "kind matches descriptor table")
		_assert(bool(entry["matches_expected"]), "lab marks descriptor as expected")
		if String(entry["asset_key"]).begins_with("diagonal_"):
			_assert(
				int(entry["catalog_rotation_correction_degrees_cw"]) == 90,
				"diagonal carries catalog correction"
			)
			_assert(
				int(entry["effective_rotation_degrees_cw"]) == (int(entry["rotation_degrees_cw"]) + 90) % 360,
				"diagonal effective rotation includes correction"
			)

	for layer_id in ["ground", "water", "solid"]:
		_assert(seen_layers.has(layer_id), "layer %s is present" % layer_id)
		for mask in range(16):
			_assert(seen_masks.has("%s:%s" % [layer_id, mask]), "mask %s is present for %s" % [mask, layer_id])

	var seam: Dictionary = diagnostics["cross_chunk_seam"]
	_assert(seam["chunk_count"] == 4, "seam fixture builds four chunks")
	_assert(seam["duplicate_world_corners"].is_empty(), "seam fixture has no duplicate world corners")
	_assert(seam["emitted_out_of_bounds_corners"].is_empty(), "seam fixture emits no out-of-bounds corners")
	_assert(seam["missing_asset_keys"].is_empty(), "seam fixture has no missing assets")
	_assert(seam["invalid_plan_count"] == 0, "seam fixture plans are valid")
	var generation_preview: Dictionary = diagnostics["generation_preview"]
	_assert(bool(generation_preview["is_valid"]), "generation preview is valid")
	_assert(
		int(generation_preview["diagnostics"]["open_percent"]) >= 70
		and int(generation_preview["diagnostics"]["open_percent"]) <= 80,
		"generation preview is mostly walkable"
	)

	lab.free()
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("tile_correctness_lab_smoke failed: %s" % message)
