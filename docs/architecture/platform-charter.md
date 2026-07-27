# Procedural-world platform charter

## Purpose

Godot World Lab develops and validates a family of composable procedural-world addons for Godot.

The repository is the development host, integration laboratory, validation environment, and reference implementation. It proves that independently installable addons can share stable contracts for world definitions, canonical chunk products, residency, bounded runtime work, Godot realization, authoring, and diagnostics.

The repository itself is not a dependency that consumer projects must install. Reusable capabilities are expected to live in independently packageable addon roots and to work in clean consumer projects without access to lab-only paths.

## Intended users

The platform is intended for Godot developers who need one or more of the following:

- deterministic or procedural chunk generation;
- streamed world residency around one or more focus points;
- replaceable visual and collision realization;
- reusable authored world definitions and presets;
- native grid or streaming backends behind stable Godot-facing adapters;
- diagnostics and benchmark evidence for chunk-based worlds;
- a reference architecture that separates world truth from scene-tree realization.

It is not intended to hide Godot or replace ordinary Godot scenes, resources, nodes, physics, rendering, navigation, or editor workflows.

## Platform shape

The initial target contains four package categories.

### Required world-platform kernel

The kernel owns the shared language used by every addon:

- canonical world and chunk identity;
- authored world-definition schemas;
- canonical generated-chunk products;
- chunk lifecycle vocabulary;
- bounded work and cancellation contracts;
- typed extension contracts;
- validation and diagnostics result shapes;
- explicit runtime composition interfaces.

The kernel does not own a specific procedural algorithm, tile kit, editor interface, debug overlay, native backend, or example world.

### Backend adapters

Backend adapters translate external or native capabilities into kernel contracts. Initial candidates include grid/topology and spatial-residency adapters.

Adapters may depend on the kernel and their declared external dependency. The kernel may not depend on an adapter.

### Optional authoring and debug addons

Authoring addons provide editor plugins, custom inspectors, importers, previews, migrations, and validation panels. Debug addons provide chunk, queue, lifecycle, layer, and performance visualization.

Both categories remain optional. Runtime exports must function without editor code, and debug behavior must be disabled unless explicitly enabled.

### Reference and feature addons

Reference addons prove that kernel extension contracts are sufficient for independent generators, realizers, collision policies, placement systems, and other world features.

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
- a universal biome, placement, navigation, networking, or persistence model;
- public compatibility promises before package contracts are independently proven;
- immediate Asset Library publication;
- compatibility shims for obsolete internal prototypes without a named consumer and migration requirement.

## Current repository interpretation

Existing generation, streaming, scheduler, cache, visual, collision, placement, overlay, debug, and native-integration code is implementation evidence. It informs the target platform but is not automatically part of the public API.

Before reusable extraction, the roadmap must establish:

1. repository and documentation authority;
2. reproducible dependency and validation infrastructure;
3. one canonical world-data authority;
4. fair, cancellable, bounded runtime work;
5. focused runtime ownership;
6. independent addon packaging and clean-consumer tests;
7. resource-based authoring;
8. reference-addon and compatibility evidence.

## Related roadmap authority

- Issue #2 is the executable platform-charter umbrella.
- Issue #3 owns this charter.
- Issue #5 owns detailed addon dependency and package rules.
- Issue #8 owns publication of the canonical `ROADMAP.md` sequence.
