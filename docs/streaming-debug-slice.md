# Streaming Debug Slice

The first runtime proof uses only chunk lifecycle signals and debug boxes.

```text
WorldStreamingNode
  emits chunk_load_requested / chunk_unload_requested
chunk_provider.gd
  reports provider_started / provider_completed
chunk_debug_overlay.gd
  creates and removes debug chunk roots
```

`chunk_provider.gd` is deliberately payload-light in this slice. It does not
load files, generate tiles, spawn gameplay, or own streaming policy. It only
simulates host provider completion and proves request ids can be tracked without
leaking pending work.

`chunk_debug_overlay.gd` creates visible `MeshInstance3D` boxes for resident
chunks. It prevents duplicate chunk roots by keying roots with chunk
coordinates, and removes roots on `chunk_unloaded`.

Validation:

```text
godot --headless --path . --script tests/streaming_debug_smoke.gd
```

