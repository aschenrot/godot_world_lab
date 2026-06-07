extends Node3D

var diagnostics: Dictionary = {}
var generated_chunk_data: Dictionary = {}
var chunk_visual_plan: Dictionary = {}
var chunk_instantiation_plan: Dictionary = {}


func build_generated_chunk_preview(
	chunk_coord: Vector3i = Vector3i.ZERO,
	provider: Node = null,
	builder: RefCounted = null,
	catalog: RefCounted = null,
	chunk_edge_meters: float = 32.0
) -> Dictionary:
	_clear_children()

	var created_provider := false
	if provider == null:
		var Provider := load("res://scripts/chunk_provider.gd")
		provider = Provider.new()
		created_provider = true
	if builder == null:
		var Builder := load("res://scripts/chunk_visual_builder.gd")
		builder = Builder.new()
	if catalog == null:
		var Catalog := load("res://scripts/tile_mesh_catalog.gd")
		catalog = Catalog.new()

	var logic_grid: Array = provider.generate_chunk_logic_grid(chunk_coord)
	generated_chunk_data = provider.make_generated_chunk_data(chunk_coord, logic_grid)
	chunk_visual_plan = builder.build_visual_plan_from_generated_chunk(generated_chunk_data, catalog)
	chunk_instantiation_plan = builder.build_instantiation_plan(
		chunk_coord,
		chunk_visual_plan,
		catalog,
		"multimesh"
	)

	var chunk_root: Node3D = builder.build_chunk_visual_from_instantiation_plan(
		chunk_instantiation_plan,
		catalog,
		chunk_edge_meters,
		provider.chunk_size_cells
	)
	add_child(chunk_root)

	diagnostics = {
		"preview_type": "generated_chunk",
		"generated_chunk_data": _generated_chunk_summary(generated_chunk_data),
		"visual_plan": chunk_visual_plan.get("diagnostics", {}),
		"instantiation_plan": chunk_instantiation_plan.get("diagnostics", {}),
		"catalog": catalog.get_asset_report(chunk_visual_plan),
		"preview_node_count": get_child_count(),
	}
	if created_provider:
		provider.free()
	return diagnostics


func get_preview_diagnostics() -> Dictionary:
	return diagnostics


func _generated_chunk_summary(data: Dictionary) -> Dictionary:
	return {
		"product_type": data.get("product_type", ""),
		"chunk_coord": data.get("chunk_coord", Vector3i.ZERO),
		"generator_version": data.get("generator_version", 0),
		"generation_settings_hash": data.get("generation_settings_hash", 0),
		"row_count": data.get("logic_grid", []).size(),
	}


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
