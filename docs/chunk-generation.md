# Chunk Generation

Generation is intentionally owned by Godot World Lab for now.

`scripts/chunk_provider.gd` exposes:

```text
generate_chunk_logic_grid(chunk_coord)
```

The current generator returns a chunk-local 2D array of integer cells:

```text
0 = empty
1 = wall
```

The output is deterministic for:

```text
chunk_coord
generator_version
chunk_size_cells
```

This slice deliberately avoids Runenwerk procgen graphs, SDF payloads, save
formats, ECS resources, mesh generation, and reusable generation APIs. Once a
stable reusable generation contract emerges from Godot proof work, it can be
designed separately.

Validation:

```text
godot --headless --path . --script tests/chunk_generation_smoke.gd
```

