# Procedural-world platform charter

## Purpose

Godot World Lab develops and validates a family of composable procedural-world addons for Godot.

The repository is the development host, integration laboratory, validation environment, and reference implementation. It proves that independently installable addons can share stable contracts for world definitions, canonical plans and chunk products, residency, bounded runtime work, Godot realization, authoring, and diagnostics.

The repository itself is not a dependency that consumer projects must install. Reusable capabilities are expected to live in independently packageable addon roots and to work in clean consumer projects without access to lab-only paths.

## Intended users

The platform is intended for Godot developers who need one or more of the following:

- deterministic or procedural chunk generation;
- streamed world residency around one or more focus points;
- graph-driven or otherwise plan-driven procedural spaces;
- replaceable visual and collision realization;
- reusable authored world definitions and presets;
- multi-floor worlds with explicit vertical connections;
- interchangeable semantic tile palettes;
- native grid or streaming backends behind stable Godot-facing adapters;
- diagnostics and benchmark evidence for chunk-based worlds;
- a reference architecture that separates world truth from scene-tree realization.

It is not intended to hide Godot or replace ordinary Godot scenes, resources, nodes, physics, rendering, navigation, or editor workflows.

## Supported world families

The platform supports two complementary generation families.

### Field-driven worlds

Field-driven generators produce canonical chunk products deterministically from world identity, generation settings, and coordinates. They are appropriate for terrain, caves, cellular fields, and other spaces that can preserve continuity without a precomputed semantic layout.

The current repository is evidence for this family: it generates a planar cell-grid world with deterministic chunk identity and streamed Godot realization.

### Plan-driven worlds

Plan-driven generators compile semantic graphs or other high-level intent into spatial world, region, or depth-segment plans before projecting them into canonical chunks. They are appropriate for dungeons, buildings, mission layouts, castles, and authored/procedural hybrids where rooms or connections may cross chunk boundaries.

A plan-driven implementation preserves authority in this order:

```text
semantic graph or high-level intent
                ↓
spatial world / region / segment plan
                ↓
canonical chunk projection
                ↓
Godot realization
```

Individual chunks may not silently redefine room, corridor, floor, connector, or region truth owned by the higher-level plan.

The platform does not require every world to have a graph, rooms, floors, or tile sets. Field-driven and plan-driven implementations converge only where interoperability requires shared canonical products and lifecycle contracts.

## Finite and effectively unbounded worlds

The platform may support finite worlds and effectively unbounded worlds.

Effectively unbounded support means deterministic lazy generation of chunks or finite world regions/depth segments as they are needed. It does not mean eagerly constructing or retaining one literally infinite graph or scene tree.

For graph-driven dungeons, the preferred proof sequence is:

1. one finite deterministic multi-floor dungeon;
2. a deterministic lazy sequence of finite depth segments with explicit entry and exit contracts;
3. broader unbounded layouts only after bounded generation, persistence, streaming, and revisit semantics are proven.

## Domains, floors, and vertical connections

The platform distinguishes world-domain semantics rather than treating every `Vector3i` chunk coordinate as equivalent.

Initial relevant domains are:

- planar cell grids;
- stacked layers composed of multiple 2D floor plans;
- later volumetric domains only where a concrete implementation requires them.

Stacked floors use explicit vertical connections such as stairs, ladders, elevators, drops, or portals. A vertical connection has stable identity, source and destination endpoints, footprint or clearance requirements, realization semantics, and residency implications. Unrelated chunks at different Y coordinates are not connected automatically.

## Semantic topology and tile palettes

Semantic world truth is independent of meshes and materials.

A plan or chunk may identify roles such as floor, wall, doorway, stair, railing, water, or cliff. A tile palette maps those roles to compatible Godot assets and materials. Changing a compatible palette should not require changing a dungeon graph, room layout, corridor routing, or canonical topology.

Palette support must eventually define:

- semantic role coverage;
- cell, wall, door, and floor-height metrics;
- supported orientation and transform rules;
- assignment scope and override precedence;
- compatibility and transition validation between palettes.

The current repository contains an authored tile-kit manifest and a limited tile catalog, but it does not yet expose the complete palette contract described here.

## Platform shape

The initial target contains several package categories while keeping the required kernel small.

### Required world-platform kernel

The kernel owns the shared language used by every addon:

- canonical world, plan, region, segment, and chunk identity where interoperability requires them;
- authored world-definition schemas;
- canonical generated-chunk products;
- accepted domain and vertical-connection vocabulary;
- chunk lifecycle vocabulary;
- bounded work and cancellation contracts;
- typed extension contracts;
- validation and diagnostics result shapes;
- explicit runtime composition interfaces.

The kernel does not own a specific procedural algorithm, dungeon grammar, room library, tile kit, editor interface, debug overlay, native backend, or example world.

### Backend adapters

Backend adapters translate external or native capabilities into kernel contracts. Initial candidates include grid/topology and spatial-residency adapters.

Adapters may depend on the kernel and their declared external dependency. The kernel may not depend on an adapter.

### Generation and feature addons

Field generators, plan-driven planners/projectors, dungeon features, room and connection libraries, domain support, palettes, realizers, collision policies, and placement systems remain optional packages unless a capability is proven necessary for minimal interoperability.

A field-world consumer must not inherit graph-dungeon dependencies merely because both are demonstrated in the lab.

### Optional authoring and debug addons

Authoring addons provide editor plugins, custom inspectors, importers, previews, migrations, and validation panels. Debug addons provide chunk, queue, lifecycle, plan, graph, layer, connector, and performance visualization.

Both categories remain optional. Runtime exports must function without editor code, and debug behavior must be disabled unless explicitly enabled.

### Reference addons

Reference addons prove that kernel extension contracts are sufficient for independent field generators, plan-driven dungeon generators, realizers, collision policies, placement systems, palettes, and other world features.

A feature belongs in the kernel only when it is necessary for interoperability. Convenience for one implementation is not sufficient justification.

## Host-only responsibilities

The Godot World Lab host owns integration and evidence rather than reusable contracts. Host-only material includes:

- reference and stress-test scenes;
- benchmark runners and qualified baselines;
- experimental player controls;
- showcase environment settings;
- comparative implementations;
- migration probes;
- project-specific assets;
- development tooling that is not part of an addon package.

Reusable addons must not reference host-only paths.

## Public extension-point rule

A public extension point is admitted only when:

1. a concrete platform responsibility requires replacement or composition;
2. at least one real implementation exists;
3. the contract is exercised by tests;
4. an independently packaged consumer can use it without lab internals;
5. the contract does not expose accidental details of the current implementation.

This rule prevents speculative interfaces, generic service locators, hidden global registries, and premature framework abstraction.

## Non-goals

The first platform generation does not attempt to provide:

- a generic framework for arbitrary Godot addons;
- a game engine or complete game framework;
- Runenwerk ECS, rendering, SDF, save-format, or gameplay authority;
- a plugin marketplace or package manager;
- mandatory autoload singletons or string-based service discovery;
- every procedural generation algorithm;
- a requirement that every world use graphs, rooms, floors, palettes, or chunks in the same way;
- a universal biome, placement, navigation, networking, or persistence model;
- one eagerly materialized infinite graph or scene tree;
- public compatibility promises before package contracts are independently proven;
- immediate Asset Library publication;
- compatibility shims for obsolete internal prototypes without a named consumer and migration requirement.

## Current repository interpretation

Existing generation, streaming, scheduler, cache, visual, collision, placement, overlay, debug, and native-integration code is implementation evidence. It informs the target platform but is not automatically part of the public API.

The current implementation proves deterministic planar field generation and streamed Godot realization. It does not yet prove graph-driven dungeon planning, procedural room and corridor compilation from a supplied graph, stacked-floor topology, working stair traversal, a public interchangeable-palette contract, or lazy deterministic depth-segment generation.

Before reusable extraction, the roadmap must establish:

1. repository and documentation authority;
2. a source-grounded capability and architecture model;
3. reproducible dependency and validation infrastructure;
4. one canonical world-plan and chunk-data authority where applicable;
5. fair, cancellable, bounded runtime work;
6. focused runtime and generation ownership;
7. independent addon packaging and clean-consumer tests;
8. resource-based field and plan-driven authoring;
9. reference-addon and compatibility evidence.

## Related roadmap authority

- Issue #2 is the executable platform-charter umbrella.
- Issue #3 owns this charter and high-level capability scope.
- Issue #24 owns the detailed capability model, current-state audit, authority decisions, target decomposition, and migration map.
- Issue #5 owns detailed addon dependency and package rules.
- Issue #8 owns publication of the canonical `ROADMAP.md` sequence.
