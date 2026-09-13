# AGENTS.md

Working agreement for anyone — human or agent — writing code in `xforce`.

`xforce` is a native macOS app (SwiftUI, macOS 26.5+, Swift 6 language mode) built with
MVVM and a feature-based folder structure.

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
├── Core/         Cross-feature code. Nothing here may import a feature.
│   ├── Navigation/    AppSection, AppRoute, Router, RouteBuilder
│   ├── DesignSystem/  Theme tokens and shared components
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
  view model. It owns its view model with `@State private var viewModel = ...`.
- **ViewModel** is a `@MainActor @Observable final class`. It holds view state and exposes
  intent methods. It contains no SwiftUI types beyond what it strictly needs.
- **Model** is plain Swift. No SwiftUI, no view-model references.

View models are tested directly; views are not unit-tested.

## Theming

The theme is adaptive by construction — light and dark both work with no branching in
view code, and no theme object in the environment.

- Prefer **system semantic colors** (`.primary`, `.secondary`, `.windowBackground`,
  `.separator`). They already adapt, are accessibility-aware, and match the platform.
- Brand colors live in `Assets.xcassets/Colors/` as color sets with explicit
  Any + Dark appearance variants.
- Access everything through `Theme` (`Theme.Color`, `Theme.Spacing`, `Theme.Radius`,
  `Theme.Font`). **No literal `Color(red:green:blue:)` and no magic numbers for padding
  or corner radius in view code.**
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
xcodebuild -project xforce.xcodeproj -scheme xforce build
xcodebuild -project xforce.xcodeproj -scheme xforce test
```

Never report a change as working without running both.

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
