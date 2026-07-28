# Architecture

Godot World Lab is the development host, integration laboratory, validation environment, and reference implementation for a family of composable procedural-world addons for Godot.

The project is deliberately narrower than a general Godot addon framework. It focuses on the contracts and workflows required to define procedural worlds, generate canonical plans and chunk data, determine residency, schedule bounded work, realize chunks through Godot, author reusable definitions, and validate independently installable addons.

## Start here

- [Platform charter](platform-charter.md) defines the platform scope, intended users, supported world families, package categories, host responsibilities, and non-goals.
- Issue #24 owns the detailed capability model, current-state audit, authority decisions, target decomposition, and migration map.
- Existing detailed architecture documents remain implementation evidence until they are consolidated under the documentation-authority work tracked by issue #4.

## Five-concept model

A developer should be able to understand the platform through five concepts:

1. **World definition** — authored resources select generation, optional planning, residency, realization, collision, placement, cache, palette, and scheduling policies.
2. **Canonical generation** — generators produce stable world, region, or chunk data independent of Godot scene nodes.
3. **Residency and work** — the runtime determines which chunks or regions are required and schedules bounded, cancellable work.
4. **Godot realization** — adapters turn canonical chunk products into visuals, collision, placement, overlays, and diagnostics.
5. **Authoring and evidence** — optional editor tools, examples, tests, and benchmarks make the contracts usable and verifiable.

## Supported world families

The target platform supports two complementary generation families:

```text
field-driven
world identity + settings + coordinate
                ↓
        canonical chunk product
```

```text
plan-driven
semantic graph or high-level intent
                ↓
spatial world / region / depth-segment plan
                ↓
        canonical chunk projection
```

Field-driven worlds are suitable for deterministic terrain, caves, cellular fields, and similar coordinate-derived spaces. Plan-driven worlds are suitable for graph-driven dungeons, buildings, mission layouts, and authored/procedural hybrids whose cross-chunk connectivity requires a higher-level authority.

The target capability model also covers:

- finite and effectively unbounded worlds, with unbounded behavior implemented through deterministic lazy chunks or finite region/segment plans;
- planar and stacked-layer domains;
- explicit vertical connections such as stairs, ladders, elevators, drops, and portals;
- semantic rooms, corridors, floors, zones, and connectors where a plan-driven implementation needs them;
- tile palettes and realizers that remain separate from semantic topology.

The current repository proves only part of this model: deterministic planar field generation, streamed residency, and Godot realization. Graph-driven planning, stacked floors, explicit vertical traversal, palette replacement as a public contract, and lazy depth-segment generation remain roadmap work.

## Authority boundary

The intended dependency direction is:

```text
world platform kernel
        ↑
backend adapters and minimal runtime services
        ↑
field generators or optional plan-driven planners/projectors
        ↑
optional dungeon, domain, palette, and realization addons
        ↑
optional authoring and debug addons
        ↑
Godot World Lab host, examples, tests, and benchmarks
```

The host may compose every addon. No reusable addon may depend on host scenes, examples, benchmarks, project-specific assets, or lab-only tooling. Field-world consumers must not inherit graph-dungeon dependencies merely because the lab proves both capability families.

## Current maturity

The repository currently contains a credible procedural-world experiment with generation, streaming, visual realization, collision, diagnostics, and native integrations. It is not yet a stable addon platform. Reproducibility, canonical plan and chunk authority, scheduling, package boundaries, authoring, graph-driven dungeon support, multi-floor traversal, palette interoperability, and independent-consumer validation remain roadmap work.

The canonical roadmap will be published by issue #8. The executable platform-charter roadmap milestone is issue #2.
