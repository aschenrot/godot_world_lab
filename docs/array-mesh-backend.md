# ArrayMesh Backend

M11 adds an optional ArrayMesh backend. MultiMesh remains the primary runtime
backend.

Both backends consume the same visual plan:

```text
build_visual_plan()
```

Backends:

```text
build_chunk_visual()
  MultiMeshInstance3D buckets by base mesh key

build_chunk_visual_array_mesh()
  one MeshInstance3D with an ArrayMesh surface
```

The ArrayMesh backend is a lab-owned optimization path. It does not change
streaming lifecycle, grid descriptor truth, generation, provider behavior,
catalog validation, or Runenwerk integration boundaries.

Dirty updates currently target the MultiMesh backend. ArrayMesh dirty updates
may fall back to a full backend rebuild until profiling justifies lower-level
surface patching.

Validation:

```text
godot --headless --path . --script tests/array_mesh_backend_smoke.gd
```
