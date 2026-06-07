# Asset Contract Findings

This records M12 asset findings before any extraction decision.

## Stable Contract

The lab has a useful tile-kit contract:

- Authored source is archived separately from normalized runtime assets.
- The normalized runtime product is a GLB plus a manifest.
- Canonical base mesh keys are:
  `corner`, `edge`, `t`, `diagonal`, `full`, and `debug`.
- Rotations are descriptor data from `grid`, not authored mesh variants.
- Runtime lookup happens through `TileMeshCatalog`.
- Missing mesh and material keys are observable diagnostics.

This is enough to keep authored assets from becoming runtime topology truth.

## Lab-Specific Implementation

These pieces remain Godot World Lab implementation details:

- `TileMeshCatalog` owns Godot `Mesh` and `Material` resources.
- The normalized GLB path and fallback box meshes are lab-owned.
- `tools/tilekit/normalize_dual_grid_tilekit.gd` is a Godot-side proof tool.
- Catalog previews are observation surfaces, not reusable asset APIs.

The asset path currently serves one dual-grid tile kit and one runtime backend.
It is not yet a general asset system.

## Extraction Blockers

Do not create `Crystonix/asset` yet.

The blockers are:

- There is only one proven tile-kit family.
- There is no stable cross-engine asset manifest beyond the current GLB
  manifest.
- Material variants and authoring metadata are still minimal.
- Blender is not available in the headless validation path, so the source GLTF
  snapshot is still part of the proof workflow.
- No Runenwerk asset catalog integration has been proven.

## M15 Direction

The M15 decision is:

```text
Use tilekit manifest only.
Do not create Crystonix/asset.
Add adapter tools only where they consume the manifest without owning runtime
world truth.
```

This preserves the option for a future minimal asset crate without creating one
before the contract is proven across more than one kit and one host.

## Critical Review

- Ownership: passed. Asset ownership stays in `godot_world_lab`.
- Runtime truth: passed. `GridMap` and `MeshLibrary` are still not runtime
  truth.
- Extraction readiness: blocked. The manifest is useful, but a general asset
  repo would be premature.
