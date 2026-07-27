# World Generation Benchmarks

The benchmark runner is a headless Godot script committed under
`tools/benchmarks/`. It measures deterministic world-generation and realization
phases and writes JSON reports with schema version `1`.

Timing regressions are reported against a committed baseline, but wall-clock
timing is not a default test gate. The contract smoke test fails only when the
report schema, required phases, counters, or deterministic invariants are
missing, or when a phase leaves more than 5% of elapsed time unattributed.

## Default Command

```text
godot --headless --path . --script tools/benchmarks/world_generation_benchmark.gd -- --profile default --samples 64 --warmup 8 --compare benchmarks/baselines/world_generation_default.json
```

To refresh the local baseline intentionally:

```text
godot --headless --path . --script tools/benchmarks/world_generation_benchmark.gd -- --profile default --samples 64 --warmup 8 --output benchmarks/baselines/world_generation_default.json
```

## Report Contract

Reports include:

- `schema_version`
- environment metadata
- profile name
- warmup and sample counts
- ordered benchmark phases
- phase timing metrics: `min_us`, `median_us`, `p95_us`, `max_us`, `avg_us`,
  and `total_us`
- phase counters where relevant

Required phases:

```text
canonical_runtime_uncached
canonical_report_uncached
truth_signature_hash
report_signature_hash
adapter_output_explicit
streaming_load_cache_miss
streaming_load_cache_hit
halo_topology_only_sampling
visual_realization
dirty_cell_visual_update
collision_realization
```

Each phase includes versioned subphase slots for `pipeline_validation`,
`native_compute`, `native_encode`, `godot_decode`, `topology_projection`,
`formation`, `formation_product_conversion`, `report_product_emit`,
`working_set_finalization`, `dictionary_copy`, `stage_report_build`,
`canonical_record_encode`, `truth_hash`, `report_hash`, `adapter_conversion`,
`cache_lookup`, `cache_record_decode`, `cache_store`,
`runtime_call_overhead`, `runtime_load_overhead`, `visual_native_plan`,
`visual_bucket_build`, `collision_native_plan`, and `collision_build`. Unused
subphases are reported as zero for structural stability. Every phase also
reports `attributed_us`, `unattributed_us`, and `unattributed_ratio`; the
smoke test enforces `unattributed_ratio <= 0.05`.

The dirty-cell phase records `dirty_corner_count` and
`rebuilt_bucket_count`. Streaming phases record canonical cache hit, miss,
entry, lookup, decode, and adapter-conversion counters. Collision phases record
blocker metrics (`blocking_cell_count`, `merged_shape_count`, `merge_ratio`) and
floor metrics (`floor_cell_count`, `floor_shape_count`, `floor_merge_ratio`)
when walkable ground floor collision is requested.

## Current Default Baseline

Latest refreshed default baseline on macOS / Godot 4.6.2 with 64 samples and
8 warmups:

```text
canonical_runtime_uncached  avg=16144us  p95=17407us
canonical_report_uncached   avg=185562us p95=192642us
truth_signature_hash        avg=5016us   p95=6359us
report_signature_hash       avg=6485us   p95=7548us
adapter_output_explicit     avg=15424us  p95=17400us
streaming_load_cache_miss   avg=20558us  p95=22439us
streaming_load_cache_hit    avg=169us    p95=286us
halo_topology_only_sampling avg=617us    p95=1008us
visual_realization          avg=27346us  p95=35042us
dirty_cell_visual_update    avg=407us    p95=886us
collision_realization       avg=433us    p95=758us
```

Collision merged 4602 blocking cells into 1398 shapes
(`merge_ratio = 0.304`). Dirty updates rebuilt 75 visual buckets for 256 dirty
corners across the sample set. Cache-hit runtime loads reported
`hit_adapter_conversion_count = 0`.

## Validation

```text
godot --headless --path . --script tests/world_generation_benchmark_contract_smoke.gd
```

Current headless Godot runs still print shutdown warnings for `ObjectDB`
instances and six resources in use. The focused smokes and benchmark command
exit successfully; the warnings are tracked as Godot/native-addon cleanup noise,
not as benchmark schema failures.
