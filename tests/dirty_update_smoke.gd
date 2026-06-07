extends SceneTree

var failed: bool = false


func _initialize() -> void:
	var Provider := load("res://scripts/chunk_provider.gd")
	var Builder := load("res://scripts/chunk_visual_builder.gd")
	var Catalog := load("res://scripts/tile_mesh_catalog.gd")

	var provider: Node = Provider.new()
	var builder: RefCounted = Builder.new()
	var catalog: RefCounted = Catalog.new()
	var chunk_coord := Vector3i(0, 0, 0)
	var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
	var initial_plan: Dictionary = builder.build_visual_plan(chunk_coord, logic_grid)
	var root_node: Node3D = builder.build_chunk_visual(
		chunk_coord,
		initial_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
	)

	var cell := Vector2i(2, 2)
	_flip_logic_cell(logic_grid, cell)
	var dirty_count: int = builder.update_dirty_cell(root_node, logic_grid, cell)
	_assert(dirty_count == 4, "one logic cell reports four dirty visual corners")
	_assert(root_node.get_meta("last_dirty_corner_count") == 4, "root records four dirty corners")

	var full_plan: Dictionary = builder.build_visual_plan(chunk_coord, logic_grid)
	var full_rebuild: Node3D = builder.build_chunk_visual(
		chunk_coord,
		full_plan,
		catalog,
		32.0,
		provider.chunk_size_cells
	)
	_assert(
		_total_instance_count(root_node) == _total_instance_count(full_rebuild),
		"dirty update matches full rebuild instance count"
	)
	_assert(root_node.get_child_count() > 0, "dirty update leaves visible buckets")

	root_node.free()
	full_rebuild.free()
	provider.free()
	quit(1 if failed else 0)


func _flip_logic_cell(logic_grid: Array, cell: Vector2i) -> void:
	var row: Array = logic_grid[cell.y]
	row[cell.x] = 0 if int(row[cell.x]) != 0 else 1
	logic_grid[cell.y] = row


func _total_instance_count(root_node: Node3D) -> int:
	var total := 0
	for child in root_node.get_children():
		var instance := child as MultiMeshInstance3D
		total += instance.multimesh.instance_count
	return total


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("dirty_update_smoke failed: %s" % message)

