# Chunk Cache and Provider

M8 adds host-owned provider delay and an optional memory cache in Godot World
Lab.

The provider still reports only lifecycle callbacks to `WorldStreamingNode`:

```text
provider_started(request_id, x, y, z)
provider_completed(request_id, x, y, z)
provider_failed(request_id, x, y, z)
```

`spatial_streaming` remains synchronous and deterministic. It does not own
threads, awaits, timers, task handles, cache records, filesystem IO, save
formats, Godot nodes, meshes, or renderer resources.

## Async Simulation

`scripts/chunk_provider.gd` can defer completion by frames:

```text
configure_async_provider(enabled, delay_frames)
```

When enabled, the provider starts requests immediately and completes them later
from `_process()`. Request ids remain host-owned until completion.

## Memory Cache

`scripts/chunk_cache.gd` stores:

```text
chunk_coord
generator_version
logic_grid
```

It explicitly does not store:

```text
WorldStreamingController internals
pending request ids
Loading / Unloading lifecycle state
Godot nodes
ChunkRoot instances
MultiMesh instances
materials
renderer resources
```

Changing `generator_version` changes the cache key and forces regeneration.

The cache is bounded by `GeneratedChunkCachePolicy.max_entries` and evicts the
least-recently loaded/stored record when a store would exceed that limit. The
default policy keeps 256 entries. `scripts/chunk_provider.gd` also bounds
`formation_sample_cache` through `formation_sample_cache_max_entries` and
prunes it after generation/load paths; settings-hash changes still clear the
sample cache immediately.

Validation:

```text
godot --headless --path . --script tests/async_cache_smoke.gd
godot --headless --path . --script tests/world_generation_cache_identity_smoke.gd
```
