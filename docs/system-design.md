# System Design

Status: **scaffolding, with v1 requirements locked**. This document describes the skeleton
that exists today and, just as importantly, what is deliberately missing. What v1 adds and why
is recorded in [product-requirements.md](./product-requirements.md).

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│  App/                                                        │
│  XforceApp  ──creates──▶  Router  ──injected via Environment │
│      │                                                       │
│      ├── WindowGroup ──▶ AppRootView                         │
│      └── Settings scene (⌘,) ──▶ SettingsScreen              │
└──────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────────┐
│  Core/                                                       │
│                                                              │
│  Navigation:  AppSection ── sidebar selection                │
│               AppRoute   ── pushable destination (a value)   │
│               Router     ── owns section + path, all intents │
│               RouteBuilder ── AppRoute ──▶ View  (only map)  │
│                                                              │
│  DesignSystem: Theme tokens, shared components               │
│  ViewState:    idle | loading | loaded | failed              │
│                                                              │
│  Models:       Concept, Snippet, Note, ConceptProgress       │
│  Services:     content, scheduling, feedback                 │
└─────────────────────────────┬────────────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────────┐
│  Features/<Feature>/                                         │
│    Views/      Screen — passive, renders state               │
│       │  intent                        ▲ state               │
│       ▼                                │                     │
│    ViewModels/ @MainActor @Observable                        │
│       │                                ▲                     │
│       ▼                                │                     │
│    Models/     screen-specific types (e.g. loop phase)       │
└──────────────────────────────────────────────────────────────┘
```

`Core` never imports a feature. The single exception is `RouteBuilder`, whose only purpose
is to resolve routes into feature screens.

## Navigation flow

The app shell is a `NavigationSplitView`:

- The **sidebar** is a `List(selection:)` bound to `router.section` (`AppSection`).
- The **detail column** is a `NavigationStack(path: $router.path)` whose root comes from
  the selected section, with one `.navigationDestination(for: AppRoute.self)` delegating
  to `RouteBuilder`.
- **Settings** is a separate `Settings` scene, opened with ⌘, — the macOS convention — not
  a sidebar item.

Switching sections clears `router.path`. A single shared path is enough for now; per-section
path stacks can be added later if a requirement calls for it.

Because every destination is a value and there is exactly one place that turns a value into
a view, navigation can later be driven from outside the UI — deep links, restoration,
menu commands — without changing any screen.

## Theming

There is no theme object and no theme switching. Adaptation is delegated to the system:
view code uses semantic colors and asset-catalog color sets that declare Any and Dark
appearance variants, so light and dark are correct by construction.

`Theme` is a namespace of static tokens (colors, spacing, radius, fonts), not runtime state.
It exists so spacing and radius are consistent and greppable, not to enable customisation.

## Deliberately absent

Each row below named a missing layer and the trigger that would introduce it. Three of those
triggers have now fired: v1's requirements are locked, so domain models, persistence and services
arrive with this milestone. They are listed first, naming what replaces them.

### No longer absent — arriving in v1

| Was not here | What replaces it |
| --- | --- |
| Domain models | `Concept`, `Rubric`, `Misconception` and `Snippet` decoded from read-only bundle JSON, plus the `Note` and `ConceptProgress` records. They live in the **core** layer, not `Features/<Feature>/Models/`, because both the practice feature and the graph feature need them and features may not import each other. Feature-local `Models/` keeps only screen-specific types such as the loop phase. |
| Persistence (SwiftData) | `Note` and `ConceptProgress` as `@Model` types in one container created in `XforceApp` and injected with `.modelContainer(_:)`. It is the single source of truth for user data — there is no second store, and the ontology and snippets stay read-only bundle data that is never written at runtime. |
| Services / repositories | `Core/Services/`, holding three services: one that loads and validates the bundled content, one that computes Leitner transitions, and one that produces feedback. Each is injected individually through `@Environment`, the way `Router` already is. Only the feedback service gets a protocol, because the tests need a second conformance; the rule against protocols with one conformance rules the other two out. |

### Still deliberately absent

| Not here | Add it when |
| --- | --- |
| Dependency-injection container | Injecting services individually stops scaling. Three environment-injected services is not that point — `@Environment` is still enough. |
| Deep linking (`AppRoute ⟷ URL`) | Something outside the app needs to drive navigation. See `AGENTS.md`. |
| Executing Swift at runtime | Never. Ground truth comes from `expectedOutput` computed at authoring time and shipped as data. |

Removing these is the point: each has a clear seam and a clear trigger, so adding one later
is additive rather than a refactor. The three rows that moved up are the proof — each arrives
where its seam always said it would.
