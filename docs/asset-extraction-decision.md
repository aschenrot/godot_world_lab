# Asset Extraction Decision

This records M15: asset extraction decision.

## Decision

Choose:

```text
tilekit manifest only
```

Do not create `Crystonix/asset`. Do not add `asset_core` or
`asset_tilekit` crates yet.

The current stable asset contract is the tile-kit manifest consumed by Godot
World Lab:

```text
assets/tiles/dual_grid_tiles_manifest.json
assets/tiles/dual_grid_tiles.glb
```

## Why This Is the Long-Term Choice

The lab has proven one useful contract:

- canonical base mesh names;
- normalized GLB location;
- authored source references;
- no authored rotated variants;
- descriptor rotations remain runtime data;
- missing asset/material diagnostics.

That is not enough evidence for a general asset repository. A premature asset
crate would need to guess at Blender workflows, material variants, Runenwerk
catalogs, save formats, editor import behavior, and runtime resource ownership.

Keeping the manifest as the contract preserves a stable integration point while
keeping Godot-specific resources in `godot_world_lab`.

## Ownership Boundary

`godot_world_lab` owns:

- GLB import proof;
- `TileMeshCatalog`;
- Godot `Mesh` and `Material` resources;
- catalog previews;
- fallback debug meshes;
- future import/editor adapters.

Reusable repos do not own:

- Godot resources;
- scene nodes;
- `MeshLibrary` or `GridMap` runtime state;
- renderer resource handles;
- product asset semantics;
- save/load formats.

## Future Extraction Gate

A future minimal asset crate can be reconsidered only after:

- more than one tile kit uses the same manifest pattern;
- material and variant metadata are stable;
- Runenwerk and Godot both agree on asset identity needs;
- import tooling can validate authored and normalized sources without Godot-only
  assumptions;
- runtime adapters consume asset descriptors without owning world truth.

## Critical Review

- Extraction decision: passed. No new repo or asset crate is created.
- Runtime truth: passed. `TileMeshCatalog` remains the Godot runtime lookup
  point.
- Long-term fit: passed. The manifest is stable enough for adapter tooling but
  not broad enough for an asset platform.
