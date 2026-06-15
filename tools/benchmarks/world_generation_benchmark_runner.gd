extends RefCounted

class_name WorldGenerationBenchmarkRunner

const REPORT_SCHEMA_VERSION := 1
const DEFAULT_PROFILE := "default"
const DEFAULT_SAMPLE_COUNT := 64
const DEFAULT_WARMUP_COUNT := 8
const REQUIRED_PHASES := [
	"canonical_runtime_uncached",
	"canonical_report_uncached",
	"truth_signature_hash",
	"report_signature_hash",
	"adapter_output_explicit",
	"streaming_load_cache_miss",
	"streaming_load_cache_hit",
	"halo_topology_only_sampling",
	"visual_realization",
	"dirty_cell_visual_update",
	"collision_realization",
]
const REQUIRED_SUBPHASES := [
	"pipeline_validation",
	"native_compute",
	"native_encode",
	"godot_decode",
	"topology_projection",
	"formation",
	"formation_product_conversion",
	"report_product_emit",
	"working_set_finalization",
	"dictionary_copy",
	"stage_report_build",
	"canonical_record_encode",
	"cache_store",
	"runtime_call_overhead",
	"runtime_load_overhead",
	"truth_hash",
	"report_hash",
	"adapter_conversion",
	"cache_lookup",
	"cache_record_decode",
	"visual_native_plan",
	"visual_bucket_build",
	"collision_native_plan",
	"collision_build",
]

const ProviderScript := preload("res://scripts/chunk_provider.gd")
const BuilderScript := preload("res://scripts/chunk_visual_builder.gd")
const CatalogScript := preload("res://scripts/tile_mesh_catalog.gd")
const CollisionBuilderScript := preload("res://scripts/collision/chunk_collision_builder.gd")


func run(options: Dictionary = {}) -> Dictionary:
	var profile := String(options.get("profile", DEFAULT_PROFILE))
	var sample_count := maxi(int(options.get("samples", DEFAULT_SAMPLE_COUNT)), 1)
	var warmup_count := maxi(int(options.get("warmup", DEFAULT_WARMUP_COUNT)), 0)
	var sample_coords := _coords(sample_count)
	var warmup_coords := _coords(warmup_count, 4096)
	var phases: Dictionary = {}

	var canonical_provider: Node = _configured_provider(false)
	phases["canonical_runtime_uncached"] = _time_world_chunk_phase(
		warmup_coords,
		sample_coords,
		canonical_provider,
		false
	)
	var report_provider: Node = _configured_provider(false)
	phases["canonical_report_uncached"] = _time_world_chunk_phase(
		warmup_coords,
		sample_coords,
		report_provider,
		true
	)
	var hash_chunks := _world_chunks_by_coord(_merged_coords(sample_coords, warmup_coords), false)
	phases["truth_signature_hash"] = _time_hash_phase(
		warmup_coords,
		sample_coords,
		hash_chunks,
		"truth"
	)
	phases["report_signature_hash"] = _time_hash_phase(
		warmup_coords,
		sample_coords,
		hash_chunks,
		"report"
	)
	var adapter_provider: Node = _configured_provider(false)
	phases["adapter_output_explicit"] = _time_adapter_phase(
		warmup_coords,
		sample_coords,
		adapter_provider
	)

	var load_provider: Node = _configured_provider(true)
	phases["streaming_load_cache_miss"] = _time_cache_load_phase(
		warmup_coords,
		sample_coords,
		load_provider
	)
	phases["streaming_load_cache_hit"] = _time_cache_load_phase(
		[],
		sample_coords,
		load_provider
	)

	var halo_provider: Node = _configured_provider(false)
	var halo_sampler: RefCounted = halo_provider._formation_halo_sampler()
	phases["halo_topology_only_sampling"] = _time_phase(
		warmup_coords,
		sample_coords,
		func(coord: Vector3i): halo_sampler.topology_layers_for_sampling(coord),
		func(): return {
			"sample_cache_hits": int(halo_sampler.get("sample_cache_hit_count")),
			"topology_only_fallbacks": int(halo_sampler.get("topology_only_fallback_count")),
			"full_neighbor_generations": int(halo_sampler.get("full_neighbor_generation_count")),
			"sample_cache_entries": halo_provider.formation_sample_cache_count(),
		},
		{},
		"native_compute"
	)

	var canonical_records_by_coord := _canonical_records_by_coord(_merged_coords(sample_coords, warmup_coords))
	phases["visual_realization"] = _time_visual_phase(
		warmup_coords,
		sample_coords,
		canonical_records_by_coord
	)
	phases["dirty_cell_visual_update"] = _time_dirty_phase(sample_coords, canonical_records_by_coord)
	phases["collision_realization"] = _time_collision_phase(
		warmup_coords,
		sample_coords,
		canonical_records_by_coord
	)

	canonical_provider.free()
	report_provider.free()
	adapter_provider.free()
	load_provider.free()
	halo_provider.free()

	return {
		"product_type": "WorldGenerationBenchmarkReport",
		"schema_version": REPORT_SCHEMA_VERSION,
		"profile": profile,
		"sample_count": sample_count,
		"warmup_count": warmup_count,
		"environment": _environment_metadata(),
		"phases": phases,
		"phase_order": REQUIRED_PHASES.duplicate(),
		"valid": is_report_valid({"phases": phases}),
	}


func is_report_valid(report: Dictionary) -> bool:
	var phases: Dictionary = report.get("phases", {})
	for phase_id in REQUIRED_PHASES:
		if not phases.has(phase_id):
			return false
		var phase: Dictionary = phases[phase_id]
		for key in ["sample_count", "min_us", "median_us", "p95_us", "max_us", "avg_us", "total_us"]:
			if not phase.has(key):
				return false
		var subphases: Dictionary = phase.get("subphases", {})
		for subphase_id in REQUIRED_SUBPHASES:
			if not subphases.has(subphase_id):
				return false
		var total_us := int(phase.get("total_us", 0))
		var unattributed_us := int(phase.get("unattributed_us", -1))
		if unattributed_us < 0:
			return false
		if total_us > 0 and float(unattributed_us) / float(total_us) > 0.05:
			return false
	return true


func compare_with_baseline(report: Dictionary, baseline_path: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if baseline_path.strip_edges().is_empty():
		return lines
	var normalized_path := _project_resource_path(baseline_path)
	if not FileAccess.file_exists(normalized_path):
		lines.append("baseline_missing %s" % baseline_path)
		return lines
	var file := FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		lines.append("baseline_unreadable %s" % baseline_path)
		return lines
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		lines.append("baseline_invalid_json %s" % baseline_path)
		return lines
	var baseline: Dictionary = parsed
	var phases: Dictionary = report.get("phases", {})
	var baseline_phases: Dictionary = baseline.get("phases", {})
	for phase_id in REQUIRED_PHASES:
		if not phases.has(phase_id) or not baseline_phases.has(phase_id):
			continue
		var current: Dictionary = phases[phase_id]
		var previous: Dictionary = baseline_phases[phase_id]
		var delta_avg := float(current.get("avg_us", 0.0)) - float(previous.get("avg_us", 0.0))
		var delta_p95 := float(current.get("p95_us", 0.0)) - float(previous.get("p95_us", 0.0))
		lines.append("benchmark_delta %s avg_us=%s p95_us=%s" % [phase_id, delta_avg, delta_p95])
	return lines


func write_report(report: Dictionary, output_path: String) -> Error:
	var normalized_path := _project_resource_path(output_path)
	var absolute_path := ProjectSettings.globalize_path(normalized_path)
	var directory_path := absolute_path.get_base_dir()
	if not directory_path.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(directory_path)
		if directory_error != OK:
			return directory_error
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "\t"))
	file.store_string("\n")
	return OK


func _time_phase(
	warmup_coords: Array,
	sample_coords: Array,
	callable: Callable,
	counter_callable: Callable = Callable(),
	subphase_totals: Dictionary = {},
	remainder_subphase: String = ""
) -> Dictionary:
	for coord in warmup_coords:
		_dispose_result(callable.call(coord))
	var elapsed_values: Array[int] = []
	for coord in sample_coords:
		var start := Time.get_ticks_usec()
		var result: Variant = callable.call(coord)
		_dispose_result(result)
		elapsed_values.append(Time.get_ticks_usec() - start)
	return _phase_result(elapsed_values, counter_callable, subphase_totals, remainder_subphase)


func _time_world_chunk_phase(
	warmup_coords: Array,
	sample_coords: Array,
	provider: Node,
	report_mode: bool
) -> Dictionary:
	var debug_flags := {"benchmark": true, "profiling_enabled": true, "diagnostics_enabled": true} if report_mode else {"benchmark": true}
	for coord in warmup_coords:
		provider._world_generation_session().generate_world_chunk(
			coord,
			false,
			true,
			debug_flags
		)
	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var validation_issue_count := 0
	for coord in sample_coords:
		var start := Time.get_ticks_usec()
		var world_chunk: GeneratedWorldChunk = provider._world_generation_session().generate_world_chunk(
			coord,
			false,
			true,
			debug_flags
		)
		var elapsed := Time.get_ticks_usec() - start
		elapsed_values.append(elapsed)
		var before_attributed := _subphase_total(subphase_totals)
		_accumulate_world_chunk_subphases(subphase_totals, world_chunk)
		var attributed_delta := _subphase_total(subphase_totals) - before_attributed
		subphase_totals["runtime_call_overhead"] += maxi(elapsed - attributed_delta, 0)
		validation_issue_count += world_chunk.validation_issues.size()
	return _phase_result(
		elapsed_values,
		func(): return {
			"full_generation_calls": int(provider._world_generation_session().get("full_generation_call_count")),
			"validation_issue_count": validation_issue_count,
			"report_mode": report_mode,
		},
		subphase_totals
	)


func _time_hash_phase(
	warmup_coords: Array,
	sample_coords: Array,
	world_chunks_by_coord: Dictionary,
	hash_kind: String
) -> Dictionary:
	for coord in warmup_coords:
		var warmup_chunk: GeneratedWorldChunk = world_chunks_by_coord[_coord_key(coord)]
		if hash_kind == "report":
			warmup_chunk.report_signature_hash()
		else:
			warmup_chunk.generated_truth_signature_hash()
	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var hash_total := 0
	for coord in sample_coords:
		var chunk: GeneratedWorldChunk = world_chunks_by_coord[_coord_key(coord)]
		var start := Time.get_ticks_usec()
		var hash_value := chunk.report_signature_hash() if hash_kind == "report" else chunk.generated_truth_signature_hash()
		var elapsed := Time.get_ticks_usec() - start
		hash_total = GeneratedChunkIdentity.mix_hash(hash_total, int(hash_value))
		elapsed_values.append(elapsed)
		subphase_totals["report_hash" if hash_kind == "report" else "truth_hash"] += elapsed
	return _phase_result(
		elapsed_values,
		func(): return {"hash_kind": hash_kind, "hash_accumulator": hash_total},
		subphase_totals
	)


func _time_adapter_phase(
	warmup_coords: Array,
	sample_coords: Array,
	provider: Node
) -> Dictionary:
	for coord in warmup_coords:
		_dispose_result(provider.make_generated_chunk_data(coord))
	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var formation_product_sets_present := 0
	for coord in sample_coords:
		var start := Time.get_ticks_usec()
		var result: Dictionary = provider.make_generated_chunk_data(coord)
		var elapsed := Time.get_ticks_usec() - start
		elapsed_values.append(elapsed)
		subphase_totals["adapter_conversion"] += elapsed
		if not result.get("formation_product_set", {}).is_empty():
			formation_product_sets_present += 1
		_dispose_result(result)
	return _phase_result(
		elapsed_values,
		func(): return {
			"adapter_output_count": sample_coords.size(),
			"formation_product_sets_present": formation_product_sets_present,
		},
		subphase_totals
	)


func _time_cache_load_phase(
	warmup_coords: Array,
	sample_coords: Array,
	provider: Node
) -> Dictionary:
	for coord in warmup_coords:
		provider._load_chunk_content(coord)
	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var hit_adapter_conversion_count := 0
	for coord in sample_coords:
		var start := Time.get_ticks_usec()
		provider._load_chunk_content(coord)
		var elapsed := Time.get_ticks_usec() - start
		elapsed_values.append(elapsed)
		var before_attributed := _subphase_total(subphase_totals)
		subphase_totals["cache_lookup"] += int(provider.get("last_cache_lookup_us"))
		subphase_totals["cache_record_decode"] += int(provider.get("last_cache_decode_us"))
		subphase_totals["canonical_record_encode"] += int(provider.get("last_canonical_record_encode_us"))
		subphase_totals["cache_store"] += int(provider.get("last_cache_store_us"))
		_accumulate_generation_diagnostics_subphases(
			subphase_totals,
			provider.get("last_generation_diagnostics")
		)
		var attributed_delta := _subphase_total(subphase_totals) - before_attributed
		subphase_totals["runtime_load_overhead"] += maxi(elapsed - attributed_delta, 0)
		if bool(provider.get("last_cache_hit_required_adapter_conversion")):
			hit_adapter_conversion_count += 1
	return _phase_result(
		elapsed_values,
		func(): return {
			"cache_hits": provider.cache_hit_count,
			"cache_misses": provider.cache_miss_count,
			"cache_entries": provider.cache_entry_count(),
			"hit_adapter_conversion_count": hit_adapter_conversion_count,
			"cache_diagnostics": provider.chunk_cache.diagnostics() if provider.chunk_cache != null and provider.chunk_cache.has_method("diagnostics") else {},
		},
		subphase_totals
	)


func _time_dirty_phase(sample_coords: Array, canonical_records_by_coord: Dictionary) -> Dictionary:
	var builder: RefCounted = BuilderScript.new()
	var catalog: RefCounted = CatalogScript.new()
	var roots: Dictionary = {}
	var logic_grids: Dictionary = {}
	for coord in sample_coords:
		var data: Dictionary = canonical_records_by_coord[_coord_key(coord)]
		var visual_plan: Dictionary = builder.build_visual_plan_from_canonical_source(data, catalog)
		roots[_coord_key(coord)] = builder.build_chunk_visual(
			coord,
			visual_plan,
			catalog,
			32.0,
			16
		)
		logic_grids[_coord_key(coord)] = data.get("topology_layers", {}).get("solid", []).duplicate(true)

	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var rebuilt_buckets := 0
	var dirty_corners := 0
	for coord in sample_coords:
		var key := _coord_key(coord)
		var root: Node3D = roots[key]
		var logic_grid: Array = logic_grids[key]
		var cell := Vector2i(2, 2)
		_flip_logic_cell(logic_grid, cell)
		var start := Time.get_ticks_usec()
		builder.update_dirty_cell(root, logic_grid, cell)
		var elapsed := Time.get_ticks_usec() - start
		elapsed_values.append(elapsed)
		subphase_totals["visual_bucket_build"] += elapsed
		rebuilt_buckets += int(root.get_meta("last_dirty_bucket_rebuild_count", 0))
		dirty_corners += int(root.get_meta("last_dirty_corner_count", 0))

	for key in roots.keys():
		var root: Node3D = roots[key]
		root.free()
	var phase := _phase_result(elapsed_values, Callable(), subphase_totals)
	phase["counters"] = {
		"dirty_corner_count": dirty_corners,
		"rebuilt_bucket_count": rebuilt_buckets,
	}
	return phase


func _time_visual_phase(
	warmup_coords: Array,
	sample_coords: Array,
	canonical_records_by_coord: Dictionary
) -> Dictionary:
	var builder: RefCounted = BuilderScript.new()
	var catalog: RefCounted = CatalogScript.new()
	for coord in warmup_coords:
		var warmup_data: Dictionary = canonical_records_by_coord[_coord_key(coord)]
		var warmup_plan: Dictionary = builder.build_visual_plan_from_canonical_source(warmup_data, catalog)
		var warmup_root: Node3D = builder.build_chunk_visual(
			coord,
			warmup_plan,
			catalog,
			32.0,
			16
		)
		warmup_root.free()

	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var bucket_count := 0
	var instance_count := 0
	var child_count := 0
	var skipped_empty_tiles := 0
	for coord in sample_coords:
		var data: Dictionary = canonical_records_by_coord[_coord_key(coord)]
		var start := Time.get_ticks_usec()
		var plan_start := Time.get_ticks_usec()
		var visual_plan: Dictionary = builder.build_visual_plan_from_canonical_source(data, catalog)
		var plan_elapsed := Time.get_ticks_usec() - plan_start
		var build_start := Time.get_ticks_usec()
		var root: Node3D = builder.build_chunk_visual(
			coord,
			visual_plan,
			catalog,
			32.0,
			16
		)
		var build_elapsed := Time.get_ticks_usec() - build_start
		elapsed_values.append(Time.get_ticks_usec() - start)
		subphase_totals["visual_native_plan"] += plan_elapsed
		subphase_totals["visual_bucket_build"] += build_elapsed
		bucket_count += int(root.get_meta("last_visual_bucket_count", 0))
		instance_count += int(root.get_meta("last_visual_instance_count", 0))
		child_count += int(root.get_meta("last_visual_child_count", 0))
		skipped_empty_tiles += int(root.get_meta("last_visual_skipped_empty_tile_count", 0))
		root.free()
	return _phase_result(
		elapsed_values,
		func(): return {
			"bucket_count": bucket_count,
			"instance_count": instance_count,
			"child_node_count": child_count,
			"skipped_empty_tile_count": skipped_empty_tiles,
		},
		subphase_totals
	)


func _time_collision_phase(
	warmup_coords: Array,
	sample_coords: Array,
	canonical_records_by_coord: Dictionary
) -> Dictionary:
	var collision_builder: RefCounted = CollisionBuilderScript.new()
	for coord in warmup_coords:
		var warmup_data: Dictionary = canonical_records_by_coord[_coord_key(coord)]
		var warmup_options := {
			"cell_size_meters": 32.0 / 16.0,
			"collision_height_meters": 0.8,
		}
		var warmup_plan: Dictionary = collision_builder.build_collision_plan(coord, warmup_data, warmup_options)
		var warmup_body: StaticBody3D = collision_builder.build_chunk_collision_from_plan(
			coord,
			warmup_data,
			warmup_plan,
			32.0,
			16,
			warmup_options
		)
		warmup_body.free()

	var elapsed_values: Array[int] = []
	var subphase_totals := _zero_subphase_totals()
	var blocking_cell_count := 0
	var merged_shape_count := 0
	for coord in sample_coords:
		var data: Dictionary = canonical_records_by_coord[_coord_key(coord)]
		var options := {
			"cell_size_meters": 32.0 / 16.0,
			"collision_height_meters": 0.8,
		}
		var start := Time.get_ticks_usec()
		var plan_start := Time.get_ticks_usec()
		var collision_plan: Dictionary = collision_builder.build_collision_plan(coord, data, options)
		var plan_elapsed := Time.get_ticks_usec() - plan_start
		var build_start := Time.get_ticks_usec()
		var body: StaticBody3D = collision_builder.build_chunk_collision_from_plan(
			coord,
			data,
			collision_plan,
			32.0,
			16,
			options
		)
		var build_elapsed := Time.get_ticks_usec() - build_start
		elapsed_values.append(Time.get_ticks_usec() - start)
		subphase_totals["collision_native_plan"] += plan_elapsed
		subphase_totals["collision_build"] += build_elapsed
		var diagnostics: Dictionary = collision_plan.get("diagnostics", {})
		blocking_cell_count += int(diagnostics.get("blocking_cell_count", 0))
		merged_shape_count += int(diagnostics.get("merged_shape_count", int(body.get_meta("collision_shape_count", 0))))
		body.free()
	return _phase_result(
		elapsed_values,
		func(): return {
			"blocking_cell_count": blocking_cell_count,
			"merged_shape_count": merged_shape_count,
			"merge_ratio": 0.0 if blocking_cell_count == 0 else float(merged_shape_count) / float(blocking_cell_count),
		},
		subphase_totals
	)


func _phase_result(
	elapsed_values: Array[int],
	counter_callable: Callable = Callable(),
	subphase_totals: Dictionary = {},
	remainder_subphase: String = ""
) -> Dictionary:
	var sorted_values := elapsed_values.duplicate()
	sorted_values.sort()
	var total := 0
	for value in sorted_values:
		total += int(value)
	var sample_count := sorted_values.size()
	var counters := {}
	if counter_callable.is_valid():
		var counter_value: Variant = counter_callable.call()
		if typeof(counter_value) == TYPE_DICTIONARY:
			counters = counter_value
	var attributed_total := _subphase_total(subphase_totals)
	if not remainder_subphase.is_empty() and total > attributed_total:
		subphase_totals[remainder_subphase] = int(subphase_totals.get(remainder_subphase, 0)) + (total - attributed_total)
		attributed_total = total
	var unattributed_us = maxi(total - attributed_total, 0)
	return {
		"sample_count": sample_count,
		"min_us": int(sorted_values[0]) if sample_count > 0 else 0,
		"median_us": _percentile(sorted_values, 0.5),
		"p95_us": _percentile(sorted_values, 0.95),
		"max_us": int(sorted_values[sample_count - 1]) if sample_count > 0 else 0,
		"avg_us": float(total) / float(maxi(sample_count, 1)),
		"total_us": total,
		"attributed_us": attributed_total,
		"unattributed_us": unattributed_us,
		"unattributed_ratio": 0.0 if total == 0 else float(unattributed_us) / float(total),
		"subphases": _subphase_report(subphase_totals, sample_count),
		"counters": counters,
	}


func _percentile(sorted_values: Array, percentile: float) -> int:
	if sorted_values.is_empty():
		return 0
	var index := ceili(float(sorted_values.size() - 1) * percentile)
	return int(sorted_values[clampi(index, 0, sorted_values.size() - 1)])


func _zero_subphase_totals() -> Dictionary:
	var totals := {}
	for subphase_id in REQUIRED_SUBPHASES:
		totals[subphase_id] = 0
	return totals


func _subphase_report(subphase_totals: Dictionary, sample_count: int) -> Dictionary:
	var report := {}
	for subphase_id in REQUIRED_SUBPHASES:
		var total_us := int(subphase_totals.get(subphase_id, 0))
		report[subphase_id] = {
			"total_us": total_us,
			"avg_us": float(total_us) / float(maxi(sample_count, 1)),
		}
	return report


func _subphase_total(subphase_totals: Dictionary) -> int:
	var total := 0
	for subphase_id in REQUIRED_SUBPHASES:
		total += int(subphase_totals.get(subphase_id, 0))
	return total


func _accumulate_world_chunk_subphases(subphase_totals: Dictionary, world_chunk: GeneratedWorldChunk) -> void:
	if world_chunk == null:
		return
	_accumulate_generation_diagnostics_subphases(subphase_totals, world_chunk.generation_diagnostics)
	if world_chunk.generation_diagnostics.get("stage_profile", []).is_empty():
		_accumulate_stage_result_subphases(subphase_totals, world_chunk.stage_results)


func _accumulate_generation_diagnostics_subphases(subphase_totals: Dictionary, diagnostics_value: Variant) -> void:
	if typeof(diagnostics_value) != TYPE_DICTIONARY:
		return
	var diagnostics: Dictionary = diagnostics_value
	subphase_totals["pipeline_validation"] += int(diagnostics.get("pipeline_validation_us", 0))
	var dictionary_copy_us := (
		int(diagnostics.get("generated_products_copy_us", 0))
		+ int(diagnostics.get("configure_copy_us", 0))
	)
	var stage_report_build_us := int(diagnostics.get("stage_report_build_us", 0))
	var finalization_us := int(diagnostics.get("working_set_finalization_us", 0))
	subphase_totals["dictionary_copy"] += dictionary_copy_us
	subphase_totals["stage_report_build"] += stage_report_build_us
	subphase_totals["working_set_finalization"] += maxi(
		finalization_us - dictionary_copy_us - stage_report_build_us,
		0
	)
	_accumulate_stage_profile_subphases(subphase_totals, diagnostics.get("stage_profile", []))


func _accumulate_stage_result_subphases(subphase_totals: Dictionary, stage_results: Array) -> void:
	var stage_profile: Array = []
	for stage_result in stage_results:
		if typeof(stage_result) != TYPE_DICTIONARY:
			continue
		var result: Dictionary = stage_result
		stage_profile.append({
			"stage_id": result.get("stage_id", ""),
			"elapsed_us": int(result.get("diagnostics", {}).get("elapsed_us", 0)),
			"diagnostics": result.get("diagnostics", {}),
		})
	_accumulate_stage_profile_subphases(subphase_totals, stage_profile)


func _accumulate_stage_profile_subphases(subphase_totals: Dictionary, stage_profile_value: Variant) -> void:
	if typeof(stage_profile_value) != TYPE_ARRAY:
		return
	for stage_entry in stage_profile_value:
		if typeof(stage_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = stage_entry
		var stage_id := String(entry.get("stage_id", ""))
		var diagnostics: Dictionary = entry.get("diagnostics", {})
		var elapsed_us := int(entry.get("elapsed_us", diagnostics.get("elapsed_us", 0)))
		var attributed_us := 0
		match stage_id:
			"native_chunk_generation_stage":
				var native_compute_us := int(diagnostics.get("native_compute_us", diagnostics.get("native_generation_us", 0)))
				var native_encode_us := int(diagnostics.get("native_encode_us", 0))
				var godot_decode_us := int(diagnostics.get("godot_decode_us", 0))
				var topology_projection_us := int(diagnostics.get("topology_projection_us", 0))
				var report_product_emit_us := int(diagnostics.get("optional_report_products_us", 0))
				subphase_totals["native_compute"] += native_compute_us
				subphase_totals["native_encode"] += native_encode_us
				subphase_totals["godot_decode"] += godot_decode_us
				subphase_totals["topology_projection"] += topology_projection_us
				subphase_totals["report_product_emit"] += report_product_emit_us
				attributed_us = native_compute_us + native_encode_us + godot_decode_us + topology_projection_us + report_product_emit_us
			"native_formation_product_stage":
				var formation_us := int(diagnostics.get("native_formation_us", 0))
				var formation_product_conversion_us := int(diagnostics.get("formation_product_set_build_us", 0))
				subphase_totals["formation"] += formation_us
				subphase_totals["formation_product_conversion"] += formation_product_conversion_us
				attributed_us = formation_us + formation_product_conversion_us
		subphase_totals["runtime_call_overhead"] += maxi(elapsed_us - attributed_us, 0)


func _configured_provider(use_cache: bool) -> Node:
	var provider: Node = ProviderScript.new()
	provider.use_chunk_cache = use_cache
	if use_cache:
		provider._ensure_cache()
	return provider


func _canonical_records_by_coord(coords: Array) -> Dictionary:
	var provider: Node = _configured_provider(false)
	var records_by_coord: Dictionary = {}
	for coord in coords:
		records_by_coord[_coord_key(coord)] = provider._generate_world_chunk_internal(coord).to_canonical_record(true)
	provider.free()
	return records_by_coord


func _world_chunks_by_coord(coords: Array, report_mode: bool) -> Dictionary:
	var provider: Node = _configured_provider(false)
	var chunks_by_coord: Dictionary = {}
	var debug_flags := {"benchmark": true, "diagnostics_enabled": true, "profiling_enabled": true} if report_mode else {"benchmark": true}
	for coord in coords:
		chunks_by_coord[_coord_key(coord)] = provider._world_generation_session().generate_world_chunk(
			coord,
			false,
			true,
			debug_flags
		)
	provider.free()
	return chunks_by_coord


func _dispose_result(result: Variant) -> void:
	if typeof(result) == TYPE_OBJECT and result != null and result.has_method("free"):
		result.free()


func _coords(count: int, offset: int = 0) -> Array[Vector3i]:
	var coords: Array[Vector3i] = []
	for index in range(count):
		var coord_index := index + offset
		var x := coord_index % 8
		var z := int(coord_index / 8)
		coords.append(Vector3i(x, 0, z))
	return coords


func _merged_coords(primary_coords: Array, secondary_coords: Array) -> Array:
	var merged := []
	var seen := {}
	for coord in primary_coords:
		var key := _coord_key(coord)
		if seen.has(key):
			continue
		seen[key] = true
		merged.append(coord)
	for coord in secondary_coords:
		var key := _coord_key(coord)
		if seen.has(key):
			continue
		seen[key] = true
		merged.append(coord)
	return merged


func _flip_logic_cell(logic_grid: Array, cell: Vector2i) -> void:
	if cell.y < 0 or cell.y >= logic_grid.size():
		return
	var row: Array = logic_grid[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return
	row[cell.x] = 0 if int(row[cell.x]) != 0 else 1
	logic_grid[cell.y] = row


func _coord_key(coord: Vector3i) -> String:
	return "%s:%s:%s" % [coord.x, coord.y, coord.z]


func _environment_metadata() -> Dictionary:
	return {
		"godot_version": Engine.get_version_info().get("string", ""),
		"os_name": OS.get_name(),
		"processor_count": OS.get_processor_count(),
	}


func _project_resource_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return "res://%s" % path.trim_prefix("./")
