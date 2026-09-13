# System Design

Status: **scaffolding**. Product requirements are not defined yet. This document describes
the skeleton that exists today and, just as importantly, what is deliberately missing.

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
│    Models/     plain Swift domain types                      │
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

| Not here | Add it when |
| --- | --- |
| Domain models | Product requirements exist. They go in `Features/<Feature>/Models/`. |
| Persistence (SwiftData) | There is a model worth storing. Container is created in `XforceApp` and injected with `.modelContainer(_:)`. |
| Services / repositories | A view model needs data it cannot own. Then `Core/Services/` and environment injection. |
| Dependency-injection container | More than one service exists. Until then `@Environment` is enough. |
| Deep linking (`AppRoute ⟷ URL`) | Something outside the app needs to drive navigation. See `AGENTS.md`. |

Removing these is the point: each has a clear seam and a clear trigger, so adding one later
is additive rather than a refactor.
