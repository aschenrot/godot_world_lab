# Godot World Lab

Godot World Lab is the development host, integration laboratory, validation environment, and reference implementation for a planned family of composable procedural-world addons for Godot.

The project currently proves important parts of that direction: deterministic planar chunk generation, streamed residency, grid-to-tile conversion, visual realization, collision construction, caching, diagnostics, and native Godot integration. It is still an experimental lab rather than a stable addon platform.

## What the project is building

The target platform separates five concerns:

1. **World definitions** select generation, planning, residency, realization, collision, placement, cache, palette, and scheduling policies.
2. **Canonical generation** produces stable plans and chunk data independently of Godot scene nodes.
3. **Residency and work scheduling** determine which chunks or regions are required and process bounded, cancellable work.
4. **Godot realization** turns canonical chunk products into visuals, collision, placement, overlays, and diagnostics.
5. **Authoring and evidence** provide optional editor tools, examples, tests, and qualified benchmarks.

The repository is the host that develops and composes these capabilities. Consumer projects should eventually install independently packaged addons rather than depend on the lab project itself.

## Target world families

The platform is intended to support two generation families without forcing either model on every project:

- **Field-driven worlds** generate deterministic chunk products directly from world identity, settings, and coordinates. The current planar terrain prototype belongs to this family.
- **Plan-driven worlds** compile semantic graphs or other high-level intent into spatial world, region, or depth-segment plans before projecting them into streamable chunks. Graph-driven dungeons, buildings, and authored/procedural hybrids belong to this family.

Target support also includes:

- effectively unbounded worlds through deterministic lazy chunk or finite-region generation rather than one eagerly materialized infinite structure;
- stacked floors with explicit vertical connections such as stairs, ladders, elevators, drops, and portals;
- procedural rooms and routed horizontal connections derived from a semantic dungeon graph;
- interchangeable semantic tile palettes that change realization without owning graph or topology truth.

These are target capabilities, not claims about the current implementation. Detailed authority and decomposition are tracked by issue #24; canonical contracts, runtime support, authoring, and reference proof belong to R2, R3, R5, and R6.

Read the [architecture entry point](docs/architecture/index.md) and [platform charter](docs/architecture/platform-charter.md) for the accepted scope and non-goals.

## Intended addon shape

The initial target is deliberately small:

- a required world-platform kernel containing canonical schemas and extension contracts;
- backend adapters for capabilities such as grid topology and streamed residency;
- optional field generators and plan-driven planner/projector addons;
- optional dungeon, domain, palette, realization, authoring, and debug addons;
- independently packaged reference addons that prove the contracts.

Existing runtime classes are implementation evidence, not automatically stable public APIs. Physical addon extraction begins only after reproducibility, canonical data authority, runtime scheduling, and ownership boundaries are corrected.

## Lab-owned material

The host project owns integration and evidence, including:

- reference and stress-test scenes;
- benchmark runners and baselines;
- experimental controls and showcase settings;
- project-specific assets;
- comparative and migration experiments;
- development tooling that is not part of a reusable addon.

Reusable addons must not depend on those host-only paths.

## External capabilities

The current experiment consumes external native capabilities for:

- local grid math, storage, dual-grid topology, descriptor classification, and dirty-cell invalidation;
- world coordinates, desired chunk residency, request/event lifecycle control, and Godot streaming integration.

The current README previously named former `Crystonix` repository coordinates. Canonical dependency ownership and exact revisions are being verified under issue #7 and will be pinned under issue #10 rather than guessed here.

## Current native setup

A reproducible bootstrap command does not exist yet. The current development setup requires separately built native libraries in:

```text
addons/godot_grid/bin/
addons/godot_world_streaming/bin/
```

On macOS, copied GDExtension libraries require ad-hoc signing. The existing helper is:

```sh
tools/sync_native_addons.sh
```

This manual process is transitional. The reproducible clean-checkout replacement is tracked by roadmap umbrella issue #9.

## Roadmap authority

- Issue #2 is the active platform-charter umbrella.
- Issue #3 owns the platform scope implemented by this documentation change.
- Issue #24 owns the detailed capability, authority, and decomposition review.
- Issue #9 owns the reproducible workspace that must precede runtime extraction.
- `ROADMAP.md` will become the canonical durable sequence under issue #8.

No GitHub milestone objects are used. Roadmap umbrella issues coordinate linked implementation issues, and each implementation issue normally maps to one draft pull request and one squash merge.

## Non-goals

Godot World Lab is not intended to become:

- a generic framework for arbitrary Godot addons;
- a complete game engine or gameplay framework;
- the authority for Runenwerk ECS, rendering, SDF, or save formats;
- a mandatory global registry or autoload architecture;
- a plugin marketplace;
- a compatibility layer for every superseded prototype;
- a requirement that every world use graphs, rooms, floors, or tile sets;
- a public stable platform before independent package and consumer validation exists.
