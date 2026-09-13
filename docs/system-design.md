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

## The prompt regression suite

The on-device model is the one dependency in the app that changes without the app changing.
An operating system update replaces it, some learners install one within days of release, and
prompt behaviour can shift with no error and no failing build — the first thing that notices is
otherwise a learner being told they missed a rubric point they covered.

`xforceTests/PromptRegressionTests.swift` is the early warning. Six authored learner
explanations are run through the real model, and the assertions are set comparisons over the
rubric point numbers it reports as covered and the misconception ids it reports as detected.
Those comparisons are writable only because the generated type is small: the missing rubric
points are computed in Swift and the connected concepts come from the ontology, so the two
judged fields are a set of integers and a set of enum cases rather than prose. The Socratic
question's wording is never asserted on — only that one came back at all.

### Running it

The suite is **excluded from the default run** and gated behind `XFORCE_PROMPT_REGRESSION`.
It needs a Mac eligible for Apple Intelligence with the model downloaded, it spends real
inference time per fixture, and the model is not deterministic — putting it in the default run
would mean the rule about never reporting a change as working without a green suite could not
be honoured on the hardware most people have.

```sh
# default run: the gated suite is skipped, everything else runs
xcodebuild -project xforce.xcodeproj -scheme xforce -derivedDataPath .build/DerivedData test

# real inference, this suite only
TEST_RUNNER_XFORCE_PROMPT_REGRESSION=1 \
  xcodebuild -project xforce.xcodeproj -scheme xforce \
  -derivedDataPath .build/DerivedData -parallel-testing-enabled NO \
  test -only-testing:xforceTests/PromptRegressionTests
```

The `TEST_RUNNER_` prefix is required from the command line: the test host does not inherit the
shell's environment, and `xcodebuild` forwards only variables named that way, stripping the
prefix so the suite sees plain `XFORCE_PROMPT_REGRESSION`. From Xcode, add
`XFORCE_PROMPT_REGRESSION` to the test action's environment variables instead.

What *can* run everywhere runs in the default suite: `PromptRegressionFixtureTests` checks that
every fixture names content that still ships, expects rubric numbers its concept actually has,
and expects misconceptions that concept authors — so a fixture cannot rot against the ontology
while nobody has eligible hardware to hand.

### When it fails after an operating system update

**Re-examine the prompt. Do not loosen the assertions.** The expectations are a human judgement
about what correct feedback on a learner's words looks like, written from the rubric rather than
from model output; editing one to match new output converts a signal into silence and leaves the
learner as the next thing that detects the drift.

1. Re-read the failing explanation and decide, as a person, what it really covers. If the
   expectation was wrong about the *text*, correct it and say so — that is fixing an authoring
   mistake, not loosening an assertion.
2. Otherwise the prompt is what moved. The instructions live in `OnDeviceFeedbackService`; the
   rubric and misconception catalogue it is handed come from `content.json`.
3. Re-run before concluding anything. One run is evidence; two agreeing runs are a result.

Fixtures encode a judgement, so a change to one is reviewed by a person the same way the
authored content is.

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
