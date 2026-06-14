# World Generation Benchmarks

The benchmark runner is a headless Godot script committed under
`tools/benchmarks/`. It measures deterministic world-generation and realization
phases and writes JSON reports with schema version `1`.

Timing regressions are reported against a committed baseline, but wall-clock
timing is not a default test gate. The contract smoke test fails only when the
report schema, required phases, counters, or deterministic invariants are
missing.

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
canonical_uncached_generated_world_chunk
adapter_generated_chunk_data_output
streaming_load_cache_miss
streaming_load_cache_hit
halo_topology_only_sampling
visual_realization
dirty_cell_visual_update
collision_realization
```

Each phase includes versioned subphase slots for `pipeline_validation`,
`native_generation`, `topology_projection`, `formation`, `adapter_conversion`,
`cache_lookup`, `cache_decode`, `visual_plan`, `visual_build`,
`collision_plan`, and `collision_build`. Unused subphases are reported as zero
for structural stability.

The dirty-cell phase records `dirty_corner_count` and
`rebuilt_bucket_count`. Streaming phases record canonical cache hit, miss,
entry, lookup, decode, and adapter-conversion counters. Collision phases record
`blocking_cell_count`, `merged_shape_count`, and `merge_ratio`.

## Current Default Baseline

Latest refreshed default baseline on macOS / Godot 4.6.2 with 64 samples and
8 warmups:

```text
canonical_uncached_generated_world_chunk avg=164962us p95=169127us
adapter_generated_chunk_data_output      avg=16461us  p95=16729us
streaming_load_cache_miss                avg=29305us  p95=29660us
streaming_load_cache_hit                 avg=94us     p95=105us
halo_topology_only_sampling              avg=538us    p95=611us
visual_realization                       avg=16787us  p95=17370us
dirty_cell_visual_update                 avg=805us    p95=894us
collision_realization                    avg=351us    p95=468us
```

Collision merged 4602 blocking cells into 1398 shapes
(`merge_ratio = 0.304`). Dirty updates rebuilt 75 visual buckets for 256 dirty
corners across the sample set.

## Validation

```text
godot --headless --path . --script tests/world_generation_benchmark_contract_smoke.gd
```
