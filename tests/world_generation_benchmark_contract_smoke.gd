extends SceneTree

const BenchmarkRunnerScript := preload("res://tools/benchmarks/world_generation_benchmark_runner.gd")

var failed: bool = false


func _initialize() -> void:
	var runner: RefCounted = BenchmarkRunnerScript.new()
	var report: Dictionary = runner.run({
		"profile": "smoke",
		"samples": 2,
		"warmup": 1,
	})
	_assert(runner.is_report_valid(report), "benchmark report satisfies required schema")
	_assert(int(report.get("schema_version", 0)) == 1, "benchmark report uses schema version 1")
	_assert(report.get("profile", "") == "smoke", "benchmark report records profile")
	var phases: Dictionary = report.get("phases", {})
	for phase_id in BenchmarkRunnerScript.REQUIRED_PHASES:
		_assert(phases.has(phase_id), "benchmark report includes %s phase" % phase_id)
		var phase: Dictionary = phases.get(phase_id, {})
		_assert(int(phase.get("sample_count", 0)) == 2, "%s records sample count" % phase_id)
		_assert(float(phase.get("avg_us", -1.0)) >= 0.0, "%s records non-negative avg_us" % phase_id)
		var subphases: Dictionary = phase.get("subphases", {})
		for subphase_id in BenchmarkRunnerScript.REQUIRED_SUBPHASES:
			_assert(subphases.has(subphase_id), "%s records %s subphase" % [phase_id, subphase_id])
			_assert(float(subphases.get(subphase_id, {}).get("avg_us", -1.0)) >= 0.0, "%s/%s records non-negative avg_us" % [phase_id, subphase_id])
	var dirty_counters: Dictionary = phases.get("dirty_cell_visual_update", {}).get("counters", {})
	var collision_counters: Dictionary = phases.get("collision_realization", {}).get("counters", {})
	var canonical_counters: Dictionary = phases.get("canonical_uncached_generated_world_chunk", {}).get("counters", {})
	_assert(int(canonical_counters.get("validation_issue_count", -1)) == 0, "canonical benchmark records no validation issues")
	_assert(int(dirty_counters.get("rebuilt_bucket_count", 0)) > 0, "dirty benchmark records rebuilt bucket count")
	_assert(int(dirty_counters.get("dirty_corner_count", 0)) > 0, "dirty benchmark records dirty corner count")
	_assert(int(collision_counters.get("merged_shape_count", 0)) >= 0, "collision benchmark records merged shape count")
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("world_generation_benchmark_contract_smoke failed: %s" % message)
