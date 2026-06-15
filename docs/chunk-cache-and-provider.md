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

`scripts/chunk_cache.gd` keeps canonical generated chunk records separate from
legacy compatibility records. Identity records are keyed by the canonical
generation identity, including chunk coordinate, generator version, settings
hash, world definition hash, requested topology projections, and requested
formation products. Cache hits return duplicated `GeneratedWorldChunkRecord`
dictionaries containing identity, topology layers, the topology projection set,
formation products, product signatures, and record diagnostics. They do not
return live `GeneratedWorldChunk` object references.

Runtime chunk loads store the canonical record in `loaded_chunks`. Visual and
collision builders consume that record directly. `GeneratedChunkData` is
adapter-only for explicit preview/export/compatibility calls such as
`get_loaded_chunk_data()` and `make_generated_chunk_data()`; provider load,
cache-hit, visual, collision, and halo-sampling paths do not use it as
generation authority.

Legacy records remain available for compatibility APIs, but legacy-key traffic
cannot evict canonical identity records.

Legacy records store:

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
GeneratedChunkData adapter dictionaries for runtime loads
```

Changing `generator_version` changes the cache key and forces regeneration.

Each namespace is bounded by `GeneratedChunkCachePolicy.max_entries` and evicts
the least-recently loaded/stored record in that namespace when a store would
exceed the limit. The default policy keeps 256 identity entries and 256 legacy
entries.

## Formation Sample Cache

`scripts/world_generation/formation/formation_sample_cache.gd` is the bounded
LRU cache used by formation halo sampling. It replaces the older plain
dictionary sample cache so halo sampling has explicit residency and diagnostics.

The sample cache:

- touches entries on reads and stores
- prunes by least-recent use
- tracks `hit_count`, `miss_count`, and `eviction_count`
- removes entries when chunk residency is unloaded
- clears immediately on generation settings or world-definition hash changes

`scripts/chunk_provider.gd` exposes the cache through diagnostics under
`formation_sample_cache` and bounds it with
`formation_sample_cache_max_entries`.

Validation:

```text
godot --headless --path . --script tests/async_cache_smoke.gd
godot --headless --path . --script tests/world_generation_cache_identity_smoke.gd
```
