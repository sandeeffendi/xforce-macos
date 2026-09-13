//
//  PromptRegressionFixtures.swift
//  xforceTests
//

import Foundation
import Testing
@testable import xforce

/// One learner explanation paired with the feedback a human says the model should produce
/// for it.
///
/// A fixture is a **judgement**, not a recording. The expectations below were written by
/// reading the rubric against the explanation and deciding what a correct reading of that
/// explanation would find — they were not copied from whatever the model happened to answer.
/// That direction matters: a fixture derived from current output can only ever agree with the
/// model, so it would detect nothing.
///
/// Both expectations are sets rather than strings, which is what makes them assertable at all.
/// The model contributes exactly two judged fields — the numbers of the rubric points it read
/// as covered, and the misconception cases it detected — because the missing points are
/// computed in Swift and the connected concepts are read from the ontology. Comparing sets of
/// integers and sets of enum cases is a real assertion; comparing generated prose would not be.
///
/// The Socratic question is deliberately not asserted on. It is prose, it is meant to vary,
/// and any assertion over it would be the string matching this suite exists to avoid.
nonisolated struct PromptRegressionFixture: Sendable, CustomTestStringConvertible {

    /// Names the fixture in test output, so a failure says which learner drifted.
    let id: String

    /// The authored concept this explanation is given against, by id.
    let conceptID: String

    /// The authored snippet the learner was looking at, by id.
    let snippetID: String

    /// What the learner wrote. Prose, in a learner's own voice, with the hedging and the
    /// half-finished thoughts that come with not yet knowing — not a textbook summary. An
    /// explanation that reads like documentation tests the model against a register no learner
    /// ever writes in.
    let explanation: String

    /// The rubric point numbers a correct reading of this explanation finds covered.
    let expectedCoveredRubricPoints: Set<Int>

    /// The misconceptions this explanation actually shows. Empty for an explanation that
    /// carries none — asserting the empty set is what catches a model that has started
    /// inventing wrong beliefs for learners who do not hold them.
    let expectedMisconceptions: Set<MisconceptionID>

    var testDescription: String { id }
}

extension PromptRegressionFixture {

    /// The authored fixture set: six learner explanations across six concepts.
    ///
    /// The set spans the three cases the suite has to distinguish, and the integrity suite
    /// derives which is which from the expectations themselves rather than trusting a label:
    ///
    /// - **Complete** — `optionals-complete`, whose expectations cover the whole rubric.
    /// - **Partial but correct** — `control-flow-ranges-partial`,
    ///   `values-and-types-integer-division-partial` and `structs-copy-partial`, each covering
    ///   part of its rubric and carrying no misconception.
    /// - **Carrying a known misconception** — `collections-dictionary-order-misconception` and
    ///   `functions-copies-misconception`.
    static let all: [PromptRegressionFixture] = [
        optionalsComplete,
        controlFlowRangesPartial,
        collectionsDictionaryOrderMisconception,
        functionsCopiesMisconception,
        valuesAndTypesIntegerDivisionPartial,
        structsCopyPartial,
    ]

    /// **Complete.** Everything the optionals rubric asks for, in a learner's own words: the
    /// type distinction, the printed wrapper, the three ways to unwrap, what `??` produces,
    /// and what force unwrapping does to a nil. Nothing here is wrong, so the misconception
    /// set is empty — this fixture is the one that catches a model inventing a wrong belief
    /// out of an explanation that has none.
    static let optionalsComplete = PromptRegressionFixture(
        id: "optionals-complete",
        conceptID: "optionals",
        snippetID: "optionals-print-wrapped",
        explanation: """
            ok so age is written as Int? and I'm fairly sure that means it isn't a normal Int, \
            it's the optional version of it, so it either has a number inside or it has nil, \
            and those two are not the same type even though they look nearly the same when you \
            write them. here it does have 5 inside it. the thing is when you print it straight \
            like that you don't get 5 on its own, you get the whole Optional(5) with the \
            wrapper still around it, which threw me the first time I saw it. to actually get at \
            the 5 you have to unwrap it first — if let is the careful way, or ?? where you give \
            it something to use instead if it turns out to be nil and then what comes out the \
            other side isn't optional any more, or ! if you're certain there's something in \
            there, except ! is the one that kills the whole program if it's nil so I try not to \
            reach for it.
            """,
        expectedCoveredRubricPoints: [1, 2, 3, 4, 5],
        expectedMisconceptions: []
    )

    /// **Partial but correct.** Ranges are the only part of control flow this snippet touches,
    /// and the learner gets all three forms right and says nothing about branches, conditions,
    /// stride or `switch`. The expectation is therefore one point out of six: a model that
    /// starts crediting the rest is reading generosity into an explanation that is not there.
    static let controlFlowRangesPartial = PromptRegressionFixture(
        id: "control-flow-ranges-partial",
        conceptID: "control-flow",
        snippetID: "control-flow-range-boundaries",
        explanation: """
            the first loop is 1...3 with the three dots and that one goes over 1, 2 and 3, the \
            last number included. the second one has the ..< instead and that stops before the \
            number you wrote, so it only does 1 and 2, which is why there's no half-open 3 \
            anywhere in the output. the third one is 0..<0 and there is nothing at all between \
            0 and 0, so the body never runs, not even once, and then done prints at the end \
            because that line is outside all of the loops. I can't really picture when you'd \
            write 0..<0 on purpose but I suppose it happens when the numbers come from \
            somewhere else.
            """,
        expectedCoveredRubricPoints: [3],
        expectedMisconceptions: []
    )

    /// **Carrying a known misconception.** The lookup half is right — an absent key is what
    /// `default:` is for — and the last sentence states, plainly and confidently, that a
    /// dictionary keeps the order keys were added in. The snippet's output does not contradict
    /// them, which is exactly why this belief survives so long, and why the model has to catch
    /// it from the reasoning rather than from a wrong prediction.
    ///
    /// Rubric point 4 is deliberately absent from the expectation even though they mention
    /// looking up by key: the second half of that point is that a dictionary has no order you
    /// can depend on, and they assert the opposite.
    static let collectionsDictionaryOrderMisconception = PromptRegressionFixture(
        id: "collections-dictionary-order-misconception",
        conceptID: "collections",
        snippetID: "collections-dictionary-lookup",
        explanation: """
            scores starts off with swift at 9, then rust gets put in after it, then swift gets \
            set again to 10 and that just writes over the old 9 rather than adding a second \
            swift entry. so when it looks swift up with the default it finds the 10. go was \
            never put in there at all, so there's nothing to find and you get the 0 from the \
            default instead — the default only gets used when the key isn't there. and count is \
            2 because there are two keys sitting in it, swift and rust, in that order, since \
            that's the order I added them in and a dictionary keeps them the way you put them in.
            """,
        expectedCoveredRubricPoints: [5],
        expectedMisconceptions: [.dictionariesKeepInsertionOrder]
    )

    /// **Carrying a known misconception.** The learner believes the function changed the
    /// caller's variable and, faced with output that says otherwise, invents a reason for the
    /// output rather than giving the belief up. That is what the misconception looks like in
    /// the wild, and detecting it from the reasoning is the one thing in the panel only the
    /// model can do.
    ///
    /// Rubric point 1 is expected covered because they say the call runs the body and hands
    /// back a value, which is exactly what that point asks for. Point 5 — arguments are passed
    /// by value — is expected absent, because they argue against it.
    static let functionsCopiesMisconception = PromptRegressionFixture(
        id: "functions-copies-misconception",
        conceptID: "functions",
        snippetID: "functions-arguments-are-copies",
        explanation: """
            calling doubled(value) runs the lines inside the function and hands back 10, that \
            part I'm happy with. then I expected the next line to print 10 as well, because \
            doubled set n to n * 2 and n is value, so value ought to be 10 by then — but it \
            printed 5, so maybe print got to it before the change landed, or the new value only \
            sticks while you're still inside the braces. the last line is 20 because the inner \
            call turns 5 into 10 and then the outer one doubles that again.
            """,
        expectedCoveredRubricPoints: [1],
        expectedMisconceptions: [.aFunctionChangesTheVariablePassedIn]
    )

    /// **Partial but correct.** Integer division and the explicit conversion, said properly and
    /// with no hedging that undoes it. Nothing is said about `let` and `var`, about inference,
    /// or about how a `Double` prints, so three of the five points stay out of the expectation.
    static let valuesAndTypesIntegerDivisionPartial = PromptRegressionFixture(
        id: "values-and-types-integer-division-partial",
        conceptID: "values-and-types",
        snippetID: "values-and-types-integer-division",
        explanation: """
            total and people are both Ints, and when you divide an Int by another Int what you \
            get back is an Int as well — it throws the .5 away instead of rounding it up, so \
            7 / 2 lands on 3 rather than 3.5 or 4. the % is how you get hold of the part that \
            got thrown away, which is the 1 on the second line. the last line puts both of them \
            inside Double() first, and once they're Doubles the division hangs on to the \
            fraction, so that one comes out 3.5. you have to ask for that conversion yourself \
            though, swift won't quietly turn the Int into a Double for you.
            """,
        expectedCoveredRubricPoints: [3, 4],
        expectedMisconceptions: []
    )

    /// **Partial but correct.** Two of the five struct points — the synthesised memberwise
    /// initialiser and copy-on-assignment — with nothing said about `mutating`, about a struct
    /// held in a `let`, or about computed properties.
    static let structsCopyPartial = PromptRegressionFixture(
        id: "structs-copy-partial",
        conceptID: "structs",
        snippetID: "structs-assignment-copies",
        explanation: """
            I never wrote an init for Point but I can still call Point(x: 1, y: 2), because \
            swift hands you one made out of the properties in the order they're declared. then \
            b = a is the line that actually matters here: a struct gets copied when you assign \
            it, so from that point on b is its own separate Point and not just another name for \
            a. that's why putting 99 into b.x only turns up in the second print and a is still \
            sitting there as 1 2.
            """,
        expectedCoveredRubricPoints: [1, 2],
        expectedMisconceptions: []
    )
}
