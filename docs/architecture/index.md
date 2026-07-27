# Architecture

Godot World Lab is the development host, integration laboratory, validation environment, and reference implementation for a family of composable procedural-world addons for Godot.

The project is deliberately narrower than a general Godot addon framework. It focuses on the contracts and workflows required to define procedural worlds, generate canonical chunk data, determine residency, schedule bounded work, realize chunks through Godot, author reusable definitions, and validate independently installable addons.

## Start here

- [Platform charter](platform-charter.md) defines the platform scope, intended users, package categories, host responsibilities, and non-goals.
- Existing detailed architecture documents remain implementation evidence until they are consolidated under the documentation-authority work tracked by issue #4.

## Five-concept model

A developer should be able to understand the platform through five concepts:

1. **World definition** — authored resources select generation, residency, realization, collision, placement, cache, and scheduling policies.
2. **Canonical generation** — generators produce stable world data independent of Godot scene nodes.
3. **Residency and work** — the runtime determines which chunks are required and schedules bounded, cancellable work.
4. **Godot realization** — adapters turn canonical chunk products into visuals, collision, placement, overlays, and diagnostics.
5. **Authoring and evidence** — optional editor tools, examples, tests, and benchmarks make the contracts usable and verifiable.

## Authority boundary

The intended dependency direction is:

```text
world platform kernel
        ↑
backend and feature addons
        ↑
optional authoring and debug addons
        ↑
Godot World Lab host, examples, tests, and benchmarks
```

The host may compose every addon. No reusable addon may depend on host scenes, examples, benchmarks, project-specific assets, or lab-only tooling.

## Current maturity

The repository currently contains a credible procedural-world experiment with generation, streaming, visual realization, collision, diagnostics, and native integrations. It is not yet a stable addon platform. Reproducibility, canonical authority, scheduling, package boundaries, authoring, and independent-consumer validation remain roadmap work.

The canonical roadmap will be published by issue #8. The executable platform-charter roadmap milestone is issue #2.