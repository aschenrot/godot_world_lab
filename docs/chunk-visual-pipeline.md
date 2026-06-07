# Chunk Visual Pipeline

```text
chunk coordinate
  -> host-owned generation policy
  -> chunk-local logic grid
  -> godot_grid descriptor conversion
  -> VisualTileData values
  -> TileMeshCatalog lookup
  -> ChunkVisualBuilder
  -> Godot ChunkRoot
```

The pipeline keeps descriptor truth separate from visual realization. Missing
meshes are Godot-lab errors or debug fallbacks; they do not change core grid
classification.

