# Product Requirements — v1

Status: **locked**. This document records what v1 of `xforce` is, what it deliberately is not,
and the decisions that were reversed from the original draft along with the reasoning that
justified each reversal.

The full specification — problem statement, solution narrative, all 59 user stories, and the
implementation and testing decisions — lives in the parent spec issue:

**[sandeeffendi/xforce-macos#1 — xforce v1: Explanation Loop and Concept Graph](https://github.com/sandeeffendi/xforce-macos/issues/1)**

That issue is the authority. This document does not duplicate the user story list; it states the
scope boundary and preserves the reasoning behind the locked decisions so they are discoverable
from the code rather than only from the tracker.

## The product in one paragraph

A beginner reads a Swift concept, feels like they understand it, and moves on — and nothing tells
them the feeling is wrong. `xforce` is a native macOS app built around one loop that cannot be
skipped. The learner is shown a Swift snippet and must commit to two things before anything else
happens: what it will print, and why. The feedback panel is visibly locked while they answer.
Only after they submit does the app reveal the real output, with no AI involved — the expected
output was computed when the snippet was authored and ships as data. Then the on-device model
asks one question about their reasoning, and only after they answer or skip does the structured
feedback unlock. The session is saved as an immutable note against a concept in a fixed ontology,
and a graph colours every concept by how well it is understood.

## In scope for v1

- **The full Explanation Loop** — prompt, reveal, Socratic question, structured feedback, commit —
  as a forward-only state machine with no bypass and no skip from the prompt phase.
- **A read-only concept graph** showing the whole ontology from first launch, with every node
  coloured by mastery and untouched clearly distinguished from weak.
- **Leitner scheduling state** — five boxes, intervals of 1, 3, 7, 16 and 35 days, with due dates
  recorded even though nothing re-engages the learner yet.
- **Content assets for 8–10 concepts**, each with at least three snippets, a rubric, and a
  curated misconception list.
- **Graceful degradation** — prediction, reveal, grading, commit and graph all work with no model
  available; only the Socratic question and the feedback panel require Apple Intelligence.

The deterministic core — prediction, reveal, grading, scheduling — works on any Mac. Apple
Intelligence adds the questioning and the rubric feedback on top of it, never underneath it.

## Out of scope for v1

- **Scheduled review as a distinct mode.** The due state is recorded, but there is no review
  session flow and no sidebar review destination. Without a re-engagement mechanism the learner
  does not return on schedule, so a review flow cannot be validated in this version.
- **Follow-up questions on the feedback panel.** They turn a structured panel back into a chat,
  and each one is another call on the same session — the exact context pressure this design
  removed.
- **Markdown export to a vault.** Purely additive later: it reads from the store and writes files,
  touching nothing else.
- **Response streaming.** The panel is deliberately withheld, so streaming hidden content buys
  nothing.
- **Notifications, menu bar presence, and any other re-engagement.**
- **Drop-off instrumentation.** An abandoned session produces no note by definition, so measuring
  it needs an event log that does not exist.
- **Sparkle updates and DMG distribution.** Sparkle conflicts with the sandboxing that was kept.
- **Executing Swift at runtime**, under any circumstances.
- **Bahasa Indonesia support**, App Store distribution, iOS or iPadOS, multiple vaults, device
  sync, and monetisation.

## Decisions reversed from the original draft

Each of these replaced something the original draft specified. The reasoning is recorded because
the reasoning is what stops the decision being re-litigated later.

### 1. SwiftData is the single source of truth for user data

**Was:** note bodies written as markdown into a user-chosen vault, with an index database
alongside. **Now:** `Note` and `ConceptProgress` are `@Model` types in one container created at
app launch. There is no second store.

Notes are immutable and scheduler state was explicitly not to live in frontmatter, which means
the app would never have read those files back — they were an export artifact described as
storage. Calling it an export removes every consistency question it created: a file deleted in
another editor, a note edited outside the app, a vault not yet downloaded from iCloud. App
sandboxing stays enabled as a consequence.

### 2. One inference per session, with the feedback staged by the UI

**Was:** two model calls sharing one session — one for the Socratic question, one for the
feedback. **Now:** one call returns the question and the feedback together, and the view model
withholds the feedback until the learner answers or skips.

A language model session retains its transcript, so the second call's context would have included
the entire first call plus its output, pushing the total beyond the context window the budget was
drawn up to respect — and that failure is abrupt and mid-session. The staging the learner
experiences is a **display** concern, not an inference one: rubric coverage, missing points,
misconceptions and connected concepts are all derivable from the explanation alone, and the
outcome comes from the output comparison. The accepted consequence is that the learner's Socratic
answer is recorded as evidence of their thinking but is never an input to the system, which keeps
the recorded data uncontaminated by a feedback loop.

### 3. Missing rubric points are computed, not generated

**Was:** the model returns both the covered and the missing rubric points. **Now:** the model
returns only the numbers of the points it judged covered, against a numbered list supplied in the
prompt, and Swift computes the complement.

Asking for both lets the two lists overlap or contradict each other, so the panel could show the
same point under "what you got right" and under "what's missing". Computing the complement makes
the two sections consistent by construction, reduces output tokens, and turns prompt regression
assertions into set comparisons over integers rather than fuzzy string matching.

### 4. Concept connections come from the ontology, not from the model

**Was:** the model names the concepts the current one connects to. **Now:** the "connect this"
section is driven from the ontology's own authored `prerequisites` and `related` edges. No
embeddings, no similarity.

The ontology already has authored, correct edges, and a small on-device model choosing among a
handful of concepts adds noise rather than signal. Driving the section from data removes an
entire generated field and an entire class of label drift.

### 5. The misconception enum is hand-written and committed

**Was:** the enum generated during the build from the ontology JSON. **Now:** it is written by
hand, committed, and kept honest by a test asserting it matches the ontology JSON in both
directions.

Generating it during the build would require a script phase writing into the source tree, which
fights the project's automatic file-system-synchronised group behaviour and its rule against
hand-editing the project file. A test buys the same guarantee with no build machinery.

Misconceptions stay a constrained generated type, because detecting one is the single thing only
the model can do, and a closed set makes it physically impossible for the model to invent a label
outside the ontology. Results are additionally filtered in Swift to the misconceptions belonging
to the current concept.

### 6. The graph layout is authored and static

**Was:** node positions produced by a force-directed simulation. **Now:** each `Concept` carries
an authored `position`, and the graph is drawn from those coordinates.

The ontology is fixed and small, so a simulation would need a stepping loop, stable seeding and
overlap handling for no gain. Stable positions also make the graph memorable, which is the entire
point of showing it — a map the learner can hold in their head, not a diagram that rearranges
itself between launches.

## What this means for the codebase

Concepts, snippets, notes and progress are needed by both the practice feature and the graph
feature, so the domain types and the three services that load and operate on them live in the
core layer, as the dependency rule in [AGENTS.md](../AGENTS.md) requires. Feature-local `Models/`
folders keep only screen-specific types such as the loop phase. Three services are introduced —
content loading and validation, Leitner transitions, and feedback generation — each injected
individually through the environment in the same way `Router` already is. Only the feedback
service gets a protocol, because the tests need a second conformance.

See [system-design.md](./system-design.md) for the layer map and for what remains deliberately
absent after this milestone.

## Known limitations, recorded rather than hidden

- **The claim this version can support is narrow.** Only the encoding intervention — the forced
  self-explanation and the Socratic question — is validatable here. Spaced repetition and
  closed-book retrieval exist as infrastructure, not as demonstrated effects.
- **The app is English-only while the first learners are Indonesian.** Explaining in a second
  language consumes working memory, the same resource the encoding intervention is trying to use.
  This is a conversion penalty for the product and a confound for the research. It gets revisited
  if Apple Intelligence supports Bahasa Indonesia or if the model backend changes.
- **Content is the real cost and the real quality ceiling.** Rubrics and misconception lists are
  what stand between a small on-device model and confidently wrong feedback given to someone who
  cannot detect it. Fewer concepts with sharp rubrics beat more concepts with thin ones, which is
  why the count is 8–10 rather than the 20–25 originally planned.
- **The platform requirement chain is narrow** — Apple Silicon, a recent macOS, an eligible
  device, Apple Intelligence enabled, and a supported system language. Graceful degradation is
  what keeps that chain from deciding whether the app is usable at all.
- **If the gate feels coercive and learners quit**, the response is to improve snippet quality,
  not to soften the gate. The gate is the only thing separating this from a notes app beside a
  chat assistant.
