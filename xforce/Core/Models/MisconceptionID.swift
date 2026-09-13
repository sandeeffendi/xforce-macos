//
//  MisconceptionID.swift
//  xforce
//

import Foundation
import FoundationModels

/// The closed set of misconceptions the model is allowed to report.
///
/// This is the one place guided generation genuinely earns its keep. Detecting a wrong belief
/// is the single thing in the feedback panel only a model can do, and constraining the output
/// to a `@Generable` enum makes it *physically impossible* for the model to invent a label
/// outside the ontology — not unlikely, impossible. Everything else the panel shows is either
/// computed in Swift or read straight from authored data.
///
/// **Hand-written and committed**, deliberately. Generating it from `content.json` during the
/// build would need a script phase writing into the source tree, which fights the project's
/// file-system-synchronised groups and its rule against hand-editing the project file. A test
/// buys the same guarantee with no build machinery: the content integrity suite asserts that
/// this enum and the ontology match **in both directions**, so an id authored with no case
/// here, or a case here the ontology no longer authors, fails the build rather than the
/// learner.
///
/// The raw value is the authored `Misconception.id` it names. That is the whole link between
/// what the model may say and what the panel can show: a reported case is looked up by raw
/// value in the current concept's own misconception list, and anything that does not belong to
/// that concept is discarded before it reaches the learner.
///
/// Adding a concept to the ontology means adding its misconceptions here. The test will say so.
@Generable
nonisolated enum MisconceptionID: String, CaseIterable, Hashable, Sendable {

    // MARK: Values and Types

    case divisionOfIntsGivesADecimal = "division-of-ints-gives-a-decimal"
    case intAndDoubleMixFreely = "int-and-double-mix-freely"
    case typeInferenceMeansDynamicTyping = "type-inference-means-dynamic-typing"
    case doublePrintsWithoutTheDecimalPoint = "double-prints-without-the-decimal-point"
    case convertingADoubleToIntRounds = "converting-a-double-to-int-rounds"

    // MARK: Strings

    case interpolationPrintsByItself = "interpolation-prints-by-itself"
    case printJoinsArgumentsWithoutASpace = "print-joins-arguments-without-a-space"
    case escapeSequencesAreTwoCharacters = "escape-sequences-are-two-characters"
    case concatenationChangesTheOriginalString = "concatenation-changes-the-original-string"
    case stringComparisonIgnoresCase = "string-comparison-ignores-case"

    // MARK: Control Flow

    case switchFallsThroughToTheNextCase = "switch-falls-through-to-the-next-case"
    case halfOpenRangeIncludesItsUpperBound = "half-open-range-includes-its-upper-bound"
    case nonBooleanValuesAreTruthy = "non-boolean-values-are-truthy"
    case overlappingSwitchCasesAllRun = "overlapping-switch-cases-all-run"
    case strideAlwaysReachesItsEndValue = "stride-always-reaches-its-end-value"

    // MARK: Collections

    case arraysAreIndexedFromOne = "arrays-are-indexed-from-one"
    case outOfRangeIndexReturnsNothing = "out-of-range-index-returns-nothing"
    case dictionariesKeepInsertionOrder = "dictionaries-keep-insertion-order"
    case countIsTheLastValidIndex = "count-is-the-last-valid-index"
    case aSliceIsReindexedFromZero = "a-slice-is-reindexed-from-zero"

    // MARK: Optionals

    case optionalIsTheSameAsTheValue = "optional-is-the-same-as-the-value"
    case printingShowsTheValue = "printing-shows-the-value"
    case nilCoalescingUnwrapsPermanently = "nil-coalescing-unwraps-permanently"
    case nilIsZeroOrEmpty = "nil-is-zero-or-empty"

    // MARK: Functions

    case argumentLabelsAreOptionalDecoration = "argument-labels-are-optional-decoration"
    case aFunctionChangesTheVariablePassedIn = "a-function-changes-the-variable-passed-in"
    case declaringAFunctionRunsIt = "declaring-a-function-runs-it"
    case parametersCanBeSkippedByPosition = "parameters-can-be-skipped-by-position"
    case aTuplePrintsAsItsValuesAlone = "a-tuple-prints-as-its-values-alone"

    // MARK: Closures

    case mapChangesTheArrayInPlace = "map-changes-the-array-in-place"
    case aClosureRunsWhereItIsWritten = "a-closure-runs-where-it-is-written"
    case aClosureCapturesASnapshotOfTheValue = "a-closure-captures-a-snapshot-of-the-value"
    case filterKeepsTheElementsThatFailTheTest = "filter-keeps-the-elements-that-fail-the-test"
    case reduceOrderDoesNotMatter = "reduce-order-does-not-matter"

    // MARK: Structs

    case assigningAStructSharesIt = "assigning-a-struct-shares-it"
    case mutatingIsOnlyForClarity = "mutating-is-only-for-clarity"
    case aLetStructCanStillBeChanged = "a-let-struct-can-still-be-changed"
    case passingAStructLetsAFunctionChangeIt = "passing-a-struct-lets-a-function-change-it"
    case storingAStructKeepsALinkToIt = "storing-a-struct-keeps-a-link-to-it"

    // MARK: Classes

    case assigningAClassCopiesIt = "assigning-a-class-copies-it"
    case aLetClassReferenceIsFullyImmutable = "a-let-class-reference-is-fully-immutable"
    case classesNeedMutatingToChangeAProperty = "classes-need-mutating-to-change-a-property"
    case identityAndEqualityAreTheSameQuestion = "identity-and-equality-are-the-same-question"
    case storingAClassInAnArrayCopiesIt = "storing-a-class-in-an-array-copies-it"
}
