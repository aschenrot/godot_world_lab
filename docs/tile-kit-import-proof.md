# Tile-Kit Import Proof

This records M5 of the current roadmap: tile-kit authoring/import proof.

## Authored Source

```text
assets/source/tiles/dual_grid_tiles.blend
```

The source blend is archived as authored input. The runtime must not depend on
its raw node names.

Because Blender is not installed in the current headless environment, the lab
also tracks a source GLTF snapshot:

```text
assets/source/tiles/dual_grid_tiles_source.gltf
assets/source/tiles/dual_grid_tiles_source.bin
```

This snapshot keeps validation deterministic. It must be regenerated from the
blend whenever the authored kit changes.

## Normalized Product

```text
assets/tiles/dual_grid_tiles.glb
assets/tiles/dual_grid_tiles_manifest.json
```

The normalized GLB contains exactly these base mesh names:

```text
corner
edge
t
diagonal
full
debug
```

No rotated mesh variants are authored. Descriptor rotations remain runtime data
from `grid` through `godot_grid`.

## Critical Review

- Ownership: passed. Assets and normalization live in `godot_world_lab`; no
  changes were made to `grid`, `spatial_streaming`, or Runenwerk.
- Runtime truth: passed. `GridMap` and `MeshLibrary` are not introduced as
  runtime truth.
- Import proof: passed. `tests/tilekit_import_smoke.gd` validates the manifest,
  source archive, headless source snapshot, normalized GLB, canonical base mesh
  names, mesh surfaces, and absence of authored rotated variants.
- Known constraint: Blender is not available headlessly here. The checked-in
  source GLTF snapshot is the reproducible import proof path until Blender is
  available for direct `.blend` re-export.

## Validation

```sh
godot --headless --path . --script tools/tilekit/normalize_dual_grid_tilekit.gd
godot --headless --path . --script tests/tilekit_import_smoke.gd
```
