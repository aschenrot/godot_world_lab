# Catalog Variants

M10 adds mesh/material catalog variants in the Godot lab.

`grid` descriptor truth remains unchanged:

```text
corner_270
edge_180
t_0
diagonal_90
full
debug
```

`TileMeshCatalog` maps those descriptor keys to Godot-owned meshes and
materials. A selected variant may override a base mesh/material:

```text
register_mesh_variant(asset_key, variant, mesh)
register_material_variant(asset_key, variant, material)
set_selected_variant(variant)
```

If a variant is missing, the catalog falls back to the base mapping. If the base
mapping is also missing, `get_mesh()` returns the debug fallback and records the
missing descriptor key for validation.

Validation reports are data-only:

```text
validate_visual_plan(plan)
  is_valid
  variant
  present_asset_keys
  missing_asset_keys
```

Variants affect realization only. They must not change the visual descriptors
emitted by `godot_grid`.

Validation:

```text
godot --headless --path . --script tests/catalog_variant_smoke.gd
```

