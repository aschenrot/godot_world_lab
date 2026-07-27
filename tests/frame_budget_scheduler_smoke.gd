extends SceneTree

var failed := false
var ran_jobs: Array[String] = []


func _initialize() -> void:
	var Scheduler := load("res://scripts/runtime/frame_budget_scheduler.gd")
	var scheduler: RefCounted = Scheduler.new()
	scheduler.configure("balanced_60", 4000, 1)
	scheduler.set_debug_phase_cost_override("provider_load", 5000)
	scheduler.set_debug_phase_cost_override("visual_plan", 1000)

	scheduler.begin_frame()
	_assert(scheduler.can_start_job(), "first job can start even if it overruns")
	_assert(
		scheduler.run_job("provider_load", Vector3i.ZERO, Callable(self, "_record_job").bind("load")),
		"first job runs under one-job minimum"
	)
	_assert(not scheduler.can_start_job(), "budget is exhausted after overrun")
	_assert(
		not scheduler.run_job("visual_plan", Vector3i.ONE, Callable(self, "_record_job").bind("visual")),
		"second job defers after budget exhaustion"
	)

	var diagnostics: Dictionary = scheduler.diagnostics({"queue_sizes": {"test": 1}})
	_assert(int(diagnostics["jobs_run"]) == 1, "diagnostics count jobs run")
	_assert(int(diagnostics["jobs_deferred"]) == 1, "diagnostics count deferred jobs")
	_assert(int(diagnostics["overrun_us"]) == 1000, "diagnostics report measured overrun")
	_assert(diagnostics["phase_totals"].has("provider_load"), "phase totals include completed phase")
	_assert(int(diagnostics["phase_totals"]["provider_load"]["total_us"]) == 5000, "phase total uses measured/override cost")
	_assert(int(diagnostics["phase_totals"]["visual_plan"]["deferred"]) == 1, "phase totals include deferred phase")
	_assert(int(diagnostics["queue_sizes"]["test"]) == 1, "diagnostics merge queue sizes")

	scheduler.begin_frame()
	_assert(
		scheduler.run_job("visual_plan", Vector3i.ONE, Callable(self, "_record_job").bind("visual")),
		"deferred work can run next frame"
	)
	_assert(ran_jobs == ["load", "visual"], "jobs run in expected order")

	quit(1 if failed else 0)


func _record_job(job_id: String) -> void:
	ran_jobs.append(job_id)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("frame_budget_scheduler_smoke failed: %s" % message)
