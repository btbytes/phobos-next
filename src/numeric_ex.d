#!/usr/bin/env rdmd-dev-module

module numeric_ex;

import std.range: isInputRange, ElementType;
import std.traits: CommonType, isFloatingPoint;
import std.algorithm: reduce;

/* import std.numeric: sum; */

/** TODO Issue 4725: Remove when sum is standard in Phobos.
    See also: http://d.puremagic.com/issues/show_bug.cgi?id=4725
    See also: https://github.com/D-Programming-Language/phobos/pull/1205
    See also: http://forum.dlang.org/thread/bug-4725-3@http.d.puremagic.com%2Fissues%2F
 */
auto sum(Range, SumType = ElementType!Range)(Range range)
    @safe pure nothrow if (isInputRange!Range)
{
    return reduce!"a+b"(0, range);
}
unittest { assert([1, 2, 3, 4].sum == 10); }

/** TODO Remove when product is standard in Phobos. */
auto product(Range)(Range range)
    @safe pure nothrow if (isInputRange!Range)
{
    return reduce!"a*b"(1, range);
}
unittest { assert([1, 2, 3, 4].product == 24); }

// ==============================================================================================

version(none) {

/** Computes $(LUCKY Discrete Signal Entropy) of input range $(D range).
 */
    auto signalEntropy(Range, RequestedBinType = double)(in Range range)
        @safe pure if (isInputRange!Range
                       && !is(CommonType!(ElementType!Range, F, G) == void))
    {
        enum normalized = true; // we need normalized histogram
        import ngram: histogram, Kind, Storage, Symmetry;
        auto hist = range.histogram!(Kind.saturated,
                                     Storage.denseDynamic,
                                     Symmetry.ordered,
                                     RequestedBinType);
        import std.numeric: entropy;
        hist.normalize;
        return hist[].entropy;
    }

    unittest
    {
        const ubyte[] p1 = [ 0, 1, 0, 1 ];
        assert(p1.signalEntropy == 1);

        const ubyte[] p2 = [ 0, 1, 2, 3 ];
        assert(p2.signalEntropy == 2);

        const ubyte[] p3 = [ 0, 255, 0, 255];
        assert(p3.signalEntropy == 1);
    }

/** Returns: Element in $(D r ) that minimizes $(D fun).
    LaTeX: \underset{x}{\arg\min} */
    auto argmin_(alias fun, Range)(in Range r)
        @safe pure if (isInputRange!Range &&
                       is(typeof(fun(r.front) < fun(r.front)) == bool))
    {
        auto bestX = r.front;
        auto bestY = fun(bestX);
        r.popFront();
        foreach (e; r) {
            auto candY = fun(e);     // candidate
            if (candY > bestY) continue;
            bestX = e;
            bestY = candY;
        }
        return bestX;
    }
    unittest {
        assert(argmin!(x => x*x)([1, 2, 3]) == 1);
        assert(argmin!(x => x*x)([3, 2, 1]) == 1);
    }

/** Returns: Element in $(D r ) that maximizes $(D fun).
    LaTeX: \underset{x}{\arg\max} */
    auto argmax_(alias fun, Range)(in Range r)
        @safe pure if (isInputRange!Range &&
                       is(typeof(fun(r.front) > fun(r.front)) == bool))
    {
        auto bestX = r.front;
        auto bestY = fun(bestX);
        r.popFront();
        foreach (e; r) {
            auto candY = fun(e);     // candidate
            if (candY < bestY) continue;
            bestX = e;
            bestY = candY;
        }
        return bestX;
    }
    unittest {
        assert(argmax!(x => x*x)([1, 2, 3]) == 3);
        assert(argmax!(x => x*x)([3, 2, 1]) == 3);
    }

}

/** Returns: Element in $(D r ) that minimizes $(D fun).
    LaTeX: \underset{x}{\arg\min} */
auto argmin(alias fun, Range)(in Range r)
    @safe pure if (isInputRange!Range &&
                   is(typeof(fun(r.front) < fun(r.front)) == bool))
{
    import std.front: front;
    return typeof(r.front).max.reduce!((a,b) => fun(a) < fun(b) ? a : b)(r);
}
unittest {
    /* assert(argmin!(x => x*x)([1, 2, 3]) == 1); */
    /* assert(argmin!(x => x*x)([3, 2, 1]) == 1); */
}

/** Returns: Element in $(D r ) that maximizes $(D fun).
    LaTeX: \underset{x}{\arg\max} */
auto argmax(alias fun, Range)(in Range r)
    @safe pure if (isInputRange!Range &&
                   is(typeof(fun(r.front) > fun(r.front)) == bool))
{
    import std.front: front;
    return typeof(r.front).min.reduce!((a,b) => fun(a) > fun(b) ? a : b)(r);
}
unittest {
    /* assert(argmax!(x => x*x)([1, 2, 3]) == 3); */
    /* assert(argmax!(x => x*x)([3, 2, 1]) == 3); */
}

// ==============================================================================================

/// Returns: 0.0 if x < edge, otherwise it returns 1.0.
CommonType!(T1, T2) step(T1, T2)(T1 edge, T2 x)
{
    return x < edge ? 0 : 1;
}
unittest {
    assert(step(0, 1) == 1.0f);
    assert(step(0, 10) == 1.0f);
    assert(step(1, 0) == 0.0f);
    assert(step(10, 0) == 0.0f);
    assert(step(1, 1) == 1.0f);
}

// ==============================================================================================

static if (__VERSION__ < 2066) import algorithm_ex: clamp;
else import std.algorithm: clamp;

/** Smoothstep from $(D edge0) to $(D edge1) at $(D x).
    Returns: 0.0 if x <= edge0 and 1.0 if x >= edge1 and performs smooth
    hermite interpolation between 0 and 1 when edge0 < x < edge1.
    This is useful in cases where you would want a threshold function with a smooth transition.
*/
CommonType!(T1,T2,T3) smoothstep(T1, T2, T3) (T1 edge0, T2 edge1, T3 x) @safe pure nothrow
if (isFloatingPoint!(CommonType!(T1,T2,T3)))
{
    x = clamp((x - edge0) / (edge1 - edge0), 0, 1);
    return x * x * (3 - 2 * x);
}
unittest {
    //  assert(smoothstep(1, 0, 2) == 0);
    assert(smoothstep(1.0, 0.0, 2.0) == 0);
    assert(smoothstep(1.0, 0.0, 0.5) == 0.5);
    // assert(almost_equal(smoothstep(0.0, 2.0, 0.5), 0.15625, 0.00001));
}

/** Smootherstep from $(D edge0) to $(D edge1) at $(D x). */
@safe pure nothrow E smootherstep(E)(E edge0, E edge1, E x)
if (isFloatingPoint!(E))
{
    // Scale, and clamp x to 0..1 range
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    // Evaluate polynomial
    return x*x*x*(x*(x*6 - 15) + 10); // evaluate polynomial
}
unittest {
    assert(smootherstep(1.0, 0.0, 2.0) == 0);
}
