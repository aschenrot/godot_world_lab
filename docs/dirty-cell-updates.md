# Dirty-Cell Updates

Dirty updates are implemented after the full chunk visual build path is stable.

`ChunkVisualBuilder.update_dirty_cell()` accepts:

```text
chunk_root
logic_grid
cell_coord
```

It asks `godot_grid` for the four affected visual corners using core
dirty-cell topology, then updates the chunk root's stored visual-tile map by
corner key. Empty updated corners are removed from the render set; non-empty
corners replace their previous descriptor data.

The current MultiMesh backend rebuilds its buckets from that updated tile map.
This keeps the data update incremental while preserving a full-bucket rebuild
fallback until a lower-level per-instance patching backend is worth the
complexity.

The full chunk rebuild path remains available:

```text
build_visual_plan()
build_chunk_visual()
```

Validation:

```text
godot --headless --path . --script tests/dirty_update_smoke.gd
```

