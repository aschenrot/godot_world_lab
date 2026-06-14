extends SceneTree

var failed: bool = false


func _initialize() -> void:
	if not ClassDB.class_exists("GodotGridTopologyMapper"):
		_fail("GodotGridTopologyMapper class is not registered")
		quit(1)
		return

	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var builder: RefCounted = Builder.new()

	var manual_grid: Array = [[1]]
	var manual_plan: Dictionary = builder.build_visual_plan(Vector3i.ZERO, manual_grid)
	_assert(manual_plan["tiles"].size() == 4, "one wall creates four visual corners")
	_assert(manual_plan["buckets"].has("solid"), "manual grid includes solid layer bucket")
	_assert(manual_plan["buckets"]["solid"].has("corner_180"), "manual grid includes stable corner_180 key")
	_assert(_all_tiles_are_non_empty(manual_plan["tiles"]), "empty tiles are skipped")
	_assert(_contains_rotation(manual_plan["tiles"], 180), "rotation data is preserved")

	var provider: Node = Node.new()
	provider.set_script(load("res://scripts/chunk_provider.gd"))
	var generated_data: Dictionary = provider.make_generated_chunk_data(Vector3i(2, 0, -3))
	var generated_plan: Dictionary = builder.build_visual_plan_from_generated_chunk(generated_data)
	_assert(generated_plan["tiles"].size() > 0, "generated chunk produces visual descriptors")
	_assert(generated_plan["visual_layers"].size() >= 3, "generated descriptors are grouped by visual layer")
	_assert(generated_plan["buckets"].keys().size() > 0, "generated descriptors are grouped by layer and asset key")

	provider.free()
	quit(1 if failed else 0)


func _all_tiles_are_non_empty(tiles: Array) -> bool:
	for tile in tiles:
		var data: Dictionary = tile
		if data["is_empty"]:
			return false
	return true


func _contains_rotation(tiles: Array, rotation_degrees_cw: int) -> bool:
	for tile in tiles:
		var data: Dictionary = tile
		if data["rotation_degrees_cw"] == rotation_degrees_cw:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("visual_plan_smoke failed: %s" % message)
