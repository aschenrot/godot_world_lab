extends RefCounted


func build_visual_plan(_chunk_coord: Vector3i, _logic_grid: Variant) -> Array:
	return []


func update_dirty_cell(_chunk_root: Node3D, _logic_grid: Variant, _cell_coord: Vector2i) -> void:
	pass


func update_visual_tiles(_chunk_root: Node3D, _visual_tile_data_array: Array) -> void:
	pass

