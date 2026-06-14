extends SceneTree

const BenchmarkRunnerScript := preload("res://tools/benchmarks/world_generation_benchmark_runner.gd")


func _initialize() -> void:
	var options := _parse_user_args(OS.get_cmdline_user_args())
	var runner: RefCounted = BenchmarkRunnerScript.new()
	var report: Dictionary = runner.run(options)
	print("WORLD_GENERATION_BENCHMARK " + JSON.stringify(report))
	var output_path := String(options.get("output", ""))
	if not output_path.strip_edges().is_empty():
		var error: int = int(runner.write_report(report, output_path))
		if error != OK:
			push_error("failed to write benchmark report to %s: %s" % [output_path, error])
	for line in runner.compare_with_baseline(report, String(options.get("compare", ""))):
		print(line)
	quit(0 if runner.is_report_valid(report) else 1)


func _parse_user_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"profile": BenchmarkRunnerScript.DEFAULT_PROFILE,
		"samples": BenchmarkRunnerScript.DEFAULT_SAMPLE_COUNT,
		"warmup": BenchmarkRunnerScript.DEFAULT_WARMUP_COUNT,
		"compare": "",
		"output": "",
	}
	var index := 0
	while index < args.size():
		var arg := String(args[index])
		match arg:
			"--profile":
				if index + 1 < args.size():
					options["profile"] = String(args[index + 1])
					index += 1
			"--samples":
				if index + 1 < args.size():
					options["samples"] = int(args[index + 1])
					index += 1
			"--warmup":
				if index + 1 < args.size():
					options["warmup"] = int(args[index + 1])
					index += 1
			"--compare":
				if index + 1 < args.size():
					options["compare"] = String(args[index + 1])
					index += 1
			"--output":
				if index + 1 < args.size():
					options["output"] = String(args[index + 1])
					index += 1
		index += 1
	return options
