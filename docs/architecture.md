# Architecture

Godot World Lab is a proof project for streaming and visual realization.

```text
spatial_streaming -> GodotWorldStreamingNode -> chunk_provider.gd
grid              -> GodotGridTopologyMapper -> chunk_visual_builder.gd
Godot lab         -> TileMeshCatalog + ChunkRoot realization
```

`spatial_streaming` decides when chunks should live. `grid` decides which visual
tile descriptors are needed. This Godot project decides how those descriptors
become visible using Godot resources.

Godot scene nodes, async tasks, cache files, meshes, materials, and debug UI are
local to this lab. They are not reusable topology or streaming truth.

Runenwerk feature integration is deferred until streaming, generation,
descriptor conversion, visual realization, unload/pooling, and dirty updates are
proven here.

## GridMap and MeshLibrary

`GridMap` and `MeshLibrary` may be used only as optional debug or prototype
backends. They are not the runtime source of truth. The long-term runtime path
is chunk roots with explicit visual builders.

