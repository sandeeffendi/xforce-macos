# AGENTS.md

Working agreement for anyone — human or agent — writing code in `xforce`.

`xforce` is a native macOS app (SwiftUI, macOS 26.5+, Swift 6 language mode) built with
MVVM and a feature-based folder structure.

This file governs *how* code is written. What the app is for, what v1 covers and what it
deliberately leaves out is in [docs/product-requirements.md](./docs/product-requirements.md);
the layer map and the seams not yet filled are in
[docs/system-design.md](./docs/system-design.md).

## Prime directive

**Do not over-engineer.** Every abstraction must be justified by a requirement that exists
today. No protocols with one conformance, no dependency-injection container until more than
one thing needs injecting, no persistence layer before there is a model to persist. When in
doubt, write the simpler thing and let the next requirement force the change.

## Language

All written artefacts are **English**: source code, comments, documentation, commit messages,
branch names, PR titles and descriptions. Conversation may be in any language; files may not.

## Project layout

```
xforce/
├── App/          App entry point and the window/scene shell
├── Content/      Read-only bundle data (the ontology and its snippets)
├── Core/         Cross-feature code. Nothing here may import a feature.
│   ├── Navigation/    AppSection, AppRoute, Router, RouteBuilder
│   ├── DesignSystem/  Theme tokens and shared components
│   ├── Models/        Domain types shared by more than one feature
│   ├── Services/      Loading and operating on that data
│   └── ViewState.swift
├── Features/     One folder per feature, each split Models/ ViewModels/ Views/
└── Assets.xcassets
```

### Dependency rule

`Features/*` may import `Core`. `Core` may **never** reference a feature, with exactly one
sanctioned exception: `Core/Navigation/RouteBuilder.swift`, whose entire job is to map routes
to feature screens. Features must not import each other — if two features need the same thing,
it belongs in `Core`.

### Feature folders

Every feature is split the same way, even when a folder is empty:

```
Features/<Feature>/
├── Models/       Domain types owned by this feature
├── ViewModels/   <Feature>ViewModel.swift
└── Views/        <Feature>Screen.swift and any subviews
```

Empty folders carry a `.gitkeep` because git does not track empty directories. Delete the
`.gitkeep` when the first real file lands.

## Navigation

Navigation is value-driven. This is the one rule with no exceptions.

- **Never use `NavigationLink(destination:)`.** Use `router.navigate(to:)`, or a
  value-based `NavigationLink(value:)` where a link affordance is genuinely wanted.
- `AppSection` — the sidebar destinations. `AppRoute` — everything pushable onto the
  detail stack. Both are plain value types; a route must describe its destination completely
  (carry ids, not object references).
- `Router` is `@MainActor @Observable`, created once in `XforceApp` and read through
  `@Environment`. Screens never construct a `Router`.
- `RouteBuilder` is the only place an `AppRoute` becomes a `View`. There is exactly one
  `.navigationDestination(for: AppRoute.self)` in the app, in `AppRootView`.

Why it matters: because routes are values and there is one place that resolves them,
deep linking can be added later as a single new file that turns a `URL` into an `AppRoute`,
without touching a single screen.

Deep linking is **not** implemented yet. When it is needed: add `AppRoute+URL.swift`, wire
`.onOpenURL` in `XforceApp`, and register the `xforce://` scheme under target → Info →
URL Types (this cannot be expressed through `GENERATE_INFOPLIST_FILE`).

## MVVM

- **View** (`<Feature>Screen`) is passive. It renders state and forwards user intent to the
  view model. It owns its view model with `@State private var viewModel = ...`. When that
  view model needs a service, see *Getting a service into a view model* below — the
  environment is not readable at the point that `@State` is initialised.
- **ViewModel** is a `@MainActor @Observable final class`. It holds view state and exposes
  intent methods. It contains no SwiftUI types beyond what it strictly needs.
- **Model** is plain Swift. No SwiftUI, no view-model references.

View models are tested directly; views are not unit-tested.

### Getting a service into a view model

A view owns its view model with `@State`, and services are read from `@Environment` — but an
`@Environment` value is not available when a `@State` property's initial value is computed.
The resolution, settled on issue #3 and applied by every screen since, is to split the screen
in two: an outer view reads the environment, and an inner view owns a view model that is
complete the moment it exists.

```swift
struct ExplainScreen: View {
    @Environment(ContentService.self) private var content

    var body: some View {
        ExplainScreenContent(content: content)
    }
}

private struct ExplainScreenContent: View {
    @State private var viewModel: ExplainViewModel

    init(content: ContentService) {
        _viewModel = State(initialValue: ExplainViewModel(content: content))
    }
}
```

The view model's dependencies are `let` constants, so there is no optional service and no
"not configured yet" state for an intent method to defend, and a test constructs the view
model directly with a fake. The cost is one extra private view type per screen.

`State(initialValue:)` is honoured only when the view's identity is first established, so a
service instance replaced at runtime would not reach the view model. Services are created once
in `XforceApp` and never replaced, so that cannot happen today — a change to service lifetime
has to revisit this.

## Theming

The theme is adaptive by construction — light and dark both work with no branching in
view code, and no theme object in the environment.

- Prefer **system semantic colors** (`.primary`, `.secondary`, `.windowBackground`,
  `.separator`). They already adapt, are accessibility-aware, and match the platform.
- Brand colors live in `Assets.xcassets/Colors/` as color sets with explicit
  Any + Dark appearance variants.
- Access everything through `Theme` (`Theme.Color`, `Theme.Spacing`, `Theme.Radius`,
  `Theme.Font`, `Theme.Size`). **No literal `Color(red:green:blue:)` and no magic numbers for
  padding or corner radius in view code.** `Theme.Size` holds fixed dimensions that are
  neither spacing nor radius — editor heights, content widths — for the same reason.
- Prefer a text style over a point size (`Theme.Font.outcomeSymbol`, not
  `.system(size: 22)`), so type keeps tracking Dynamic Type.
- Every screen's `#Preview` must cover both `.light` and `.dark`.

## Concurrency

The app target builds in **Swift 6 language mode** with
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so types are `@MainActor` unless told otherwise.
That is the right default for UI types and the wrong one for data.

**Mark pure value types `nonisolated`** — routes, view state, domain models. A `MainActor`
enum carries a `MainActor`-isolated `Equatable`/`Hashable` conformance, which cannot be used
from a non-isolated context (including a plain test suite), and that is a hard error in
Swift 6, not a warning.

```swift
nonisolated enum AppRoute: Hashable { ... }   // data: usable from any isolation
@MainActor @Observable final class Router { ... }   // UI state: explicit, not inferred
```

`Router` and the view models are annotated `@MainActor` explicitly even though the build
setting already implies it, so the isolation survives a change to that setting.

## Testing

Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) in the `xforceTests`
target. Test-driven: write the failing test first, watch it fail, then implement.

```sh
xcodebuild -project xforce.xcodeproj -scheme xforce -derivedDataPath .build/DerivedData build
xcodebuild -project xforce.xcodeproj -scheme xforce -derivedDataPath .build/DerivedData test
```

Never report a change as working without running both.

One suite is deliberately **not** in that run: the prompt regression suite makes real calls to
the on-device model, so it needs eligible hardware, it is slow, and it is not deterministic. It
is gated behind `XFORCE_PROMPT_REGRESSION`, and the default run above passes on a Mac with no
Apple Intelligence at all. How to run it, and why a failure after an operating system update
means revisiting the prompt rather than the expectations, is in
[docs/system-design.md](./docs/system-design.md#the-prompt-regression-suite).

`-derivedDataPath` is required, not optional. Work happens in several git worktrees at once,
and without it they all contend on one shared derived data directory. `.build/` is already
gitignored, so building this way leaves the tree clean.

## Xcode project

The project uses `fileSystemSynchronizedGroups` (objectVersion 77): **files and folders
created on disk are picked up automatically.** Do not hand-edit `project.pbxproj` to add
sources. Adding or removing a *target* still requires Xcode's GUI.

Two consequences of that automatic pickup:

- Anything that is not a source file is copied into the bundle as a **resource**. Several
  `.gitkeep` files would therefore collide on one output path and fail the build, so the app
  target sets `EXCLUDED_SOURCE_FILE_NAMES = ".gitkeep"`. Add any other placeholder filename
  to that setting rather than to `.gitignore`.
- A file dropped anywhere under `xforce/` is in the build whether or not it is finished.
  There is no "not added to target yet" state to hide behind.
