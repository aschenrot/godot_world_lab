extends RefCounted

const DEFAULT_PRESET := "balanced_60"
const DEFAULT_BUDGET_US := 4000
const DEFAULT_MINIMUM_JOBS_PER_FRAME := 1

var preset: String = DEFAULT_PRESET
var frame_budget_us: int = DEFAULT_BUDGET_US
var minimum_jobs_per_frame: int = DEFAULT_MINIMUM_JOBS_PER_FRAME

var frame_index: int = 0
var consumed_us: int = 0
var overrun_us: int = 0
var jobs_run: int = 0
var jobs_deferred: int = 0
var phase_totals: Dictionary = {}
var rolling_phase_totals: Dictionary = {}
var debug_phase_cost_overrides_us: Dictionary = {}


func configure(next_preset: String, next_budget_us: int, next_minimum_jobs_per_frame: int) -> void:
	preset = next_preset
	frame_budget_us = maxi(next_budget_us, 0)
	minimum_jobs_per_frame = maxi(next_minimum_jobs_per_frame, 0)


func begin_frame() -> void:
	frame_index += 1
	consumed_us = 0
	overrun_us = 0
	jobs_run = 0
	jobs_deferred = 0
	phase_totals = {}


func can_start_job() -> bool:
	if jobs_run < minimum_jobs_per_frame:
		return true
	return consumed_us < frame_budget_us


func run_job(phase: String, chunk_coord: Vector3i, job: Callable) -> bool:
	if not can_start_job():
		defer_job(phase, chunk_coord)
		return false

	var started_us := Time.get_ticks_usec()
	job.call()
	var measured_us := Time.get_ticks_usec() - started_us
	var elapsed_us := int(debug_phase_cost_overrides_us.get(phase, measured_us))
	_record_job(phase, elapsed_us)
	return true


func defer_job(phase: String, _chunk_coord: Vector3i = Vector3i.ZERO) -> void:
	jobs_deferred += 1
	var phase_record := _phase_record(phase, phase_totals)
	phase_record["deferred"] = int(phase_record.get("deferred", 0)) + 1
	phase_totals[phase] = phase_record


func diagnostics(extra: Dictionary = {}) -> Dictionary:
	var output := {
		"product_type": "FrameBudgetDiagnostics",
		"preset": preset,
		"frame_index": frame_index,
		"budget_us": frame_budget_us,
		"consumed_us": consumed_us,
		"overrun_us": overrun_us,
		"jobs_run": jobs_run,
		"jobs_deferred": jobs_deferred,
		"minimum_jobs_per_frame": minimum_jobs_per_frame,
		"phase_totals": phase_totals.duplicate(true),
		"rolling_phase_totals": rolling_phase_totals.duplicate(true),
	}
	for key in extra.keys():
		output[key] = extra[key]
	return output


func set_debug_phase_cost_override(phase: String, cost_us: int) -> void:
	debug_phase_cost_overrides_us[phase] = maxi(cost_us, 0)


func clear_debug_phase_cost_overrides() -> void:
	debug_phase_cost_overrides_us.clear()


func _record_job(phase: String, elapsed_us: int) -> void:
	consumed_us += elapsed_us
	overrun_us = maxi(consumed_us - frame_budget_us, 0)
	jobs_run += 1

	var phase_record := _phase_record(phase, phase_totals)
	phase_record["jobs"] = int(phase_record.get("jobs", 0)) + 1
	phase_record["total_us"] = int(phase_record.get("total_us", 0)) + elapsed_us
	phase_record["max_us"] = maxi(int(phase_record.get("max_us", 0)), elapsed_us)
	phase_totals[phase] = phase_record

	var rolling_record := _phase_record(phase, rolling_phase_totals)
	rolling_record["jobs"] = int(rolling_record.get("jobs", 0)) + 1
	rolling_record["total_us"] = int(rolling_record.get("total_us", 0)) + elapsed_us
	rolling_record["max_us"] = maxi(int(rolling_record.get("max_us", 0)), elapsed_us)
	rolling_phase_totals[phase] = rolling_record


func _phase_record(phase: String, records: Dictionary) -> Dictionary:
	return records.get(phase, {
		"jobs": 0,
		"total_us": 0,
		"max_us": 0,
		"deferred": 0,
	}).duplicate(true)
