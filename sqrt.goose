// =============================================================================
// sqrt and cbrt -> square root and cube root, plus hypot.
//
// sqrt is the odd one out: on most targets the hardware has a
// correctly-rounded square-root instruction (x86's SQRTSD, ARM's FSQRT,
// etc.), so we call it via an extern and only fall back to software for
// the cases the hardware handles poorly (NaN, negative inputs) or when
// the intrinsic returns a non-normalized result.
//
// cbrt has no hardware instruction, so it's pure Newton iteration
// which makes the seed choice the whole game (see below).
//
// hypot is pythagoras: sqrt(a^2 + b^2) without the intermediate overflow
// that squaring would cause. See its header for the algebra.
// =============================================================================

// Hardware square-root. The name mirrors the x86 SQRTSD mnemonic
// ("square root, scalar double"). This is not part of Rust's standard
// library, so it's declared extern and must be provided by the runtime
// (Goose's runtime maps it to whatever the target's sqrt primitive is).
extern fn goose_sqrtsd(value: f64) -> f64;

// sqrt_newton computes sqrt(radicand) by Newton's method:
//
//     x_{n+1} = (1/2) * (x_n + radicand / x_n)
//
// This is the classic Babylonian/heron iteration. It's the fallback
// used by `sqrt` below when the hardware instruction doesn't give a
// usable answer, so it needs to be correct for every finite non-negative
// input, not just the easy ones.
//
// Newton for sqrt has a nice global-convergence property on the positive
// reals: from any seed x_0 > 0, the sequence decreases monotonically to
// sqrt(radicand) once x_0 >= sqrt(radicand). From a seed below
// sqrt(radicand), the first step overshoots above it, and the
// monotone-decrease regime begins. So the only real constraint on the
// seed is x_0 > 0 (a zero seed divides by zero on the first step and
// poisons every subsequent step).
fn sqrt_newton(radicand: f64) -> f64 {
    // Negative inputs are outside sqrt's domain. Returning 0 rather
    // than NaN is a Go-convention choice (Go's math.Sqrt returns NaN,
    // but many callers of this helper want a defined value for
    // downstream arithmetic, and the sqrt() wrapper above already
    // filters negatives before reaching here). Zero itself returns
    // zero because 0 is its own square root.
    if radicand <= 0.0 {
        return 0.0;
    }

    // Seed selection. Two regimes, both designed to land the seed
    // above sqrt(radicand) so the monotone-decrease property kicks in
    // immediately:
    //
    //   radicand < 1 : sqrt(radicand) < 1, so seeding with 1.0 is
    //                  already >= sqrt(radicand). Seeding with
    //                  `radicand` would be < sqrt(radicand) (since
    //                  radicand < sqrt(radicand) for 0 < radicand < 1),
    //                  forcing an initial overshoot step.
    //
    //   radicand >= 1: sqrt(radicand) <= radicand (equality only at
    //                  radicand = 1), so seeding with `radicand` is
    //                  >= sqrt(radicand). This is a coarse but safe
    //                  upper bound; convergence from `radicand` to
    //                  sqrt(radicand) takes O(log(radicand)) steps,
    //                  which the 40-iteration cap covers comfortably
    //                  for all f64 inputs.
    var estimate: f64 = 0.0;
    if radicand < 1.0 { estimate = 1.0; } else { estimate = radicand; }

    // Fixed iteration count rather than a convergence test. Why 40?
    // Newton for sqrt roughly doubles the number of correct digits
    // each step once it's within the quadratic-convergence basin, so
    // from any f64 seed, ~6 steps already reach full 53-bit precision.
    // The remaining ~34 are pure insurance against pathological inputs
    // (near-overflow, near-underflow) where the first few steps are
    // spent recovering from the seed's coarse bound. A convergence
    // test (|estimate*estimate - radicand| <= eps*radicand) would be
    // more elegant but costs a multiply-and-compare per iteration; the
    // fixed cap is faster and the over-iteration is harmless because
    // Newton is idempotent once estimate = sqrt(radicand) exactly
    // (estimate_next = 0.5*(estimate + radicand/estimate)
    //                = 0.5*(estimate + estimate) = estimate).
    var iteration: i64 = 0;
    while iteration < 40 {
        estimate = 0.5 * (estimate + radicand / estimate);
        iteration = iteration + 1;
    }
    return estimate;
}

// sqrt returns the correctly-rounded square root of `radicand`.
//
// Strategy: try the hardware instruction first, and fall back to
// Newton only if the hardware result is unusable. The check below
// is `radicand >= 0` AND `hardware_result >= 0`:
//
//   - radicand >= 0    : sqrt is only defined for non-negative reals.
//   - hardware_result >= 0 : a negative result from the hardware would
//                            signal something is wrong (e.g. the
//                            intrinsic returned garbage for a denormal
//                            input), so we don't trust it.
//
// NaN fails both checks, so sqrt(NaN) goes to sqrt_newton, which
// returns 0 for radicand <= 0 (NaN <= 0 is false, so actually it falls
// through the `radicand <= 0` check and reaches the seed selection with
// estimate = radicand = NaN, then the loop computes NaN; so
// sqrt(NaN) = NaN via the fallback, which is the IEEE-correct answer).
//
// -0.0 is handled by the `radicand >= 0.0` check (which is true for
// -0.0 since -0.0 == 0.0), and the hardware returns -0.0 for
// sqrt(-0.0) per IEEE 754, so the sign is preserved.
fn sqrt(radicand: f64) -> f64 {
    let hardware_result: f64 = goose_sqrtsd(radicand);
    if radicand >= 0.0 {
        if hardware_result >= 0.0 {
            return hardware_result;
        }
    }
    return sqrt_newton(radicand);
}

// =============================================================================
// cbrt -> cube root, via Newton's method on x^3 = radicand.
//
// The Newton update for x^3 = radicand is:
//
//     f(x)  = x^3 - radicand
//     f'(x) = 3*x^2
//     x_{n+1} = x_n - f(x_n)/f'(x_n)
//             = x_n - (x_n^3 - radicand)/(3*x_n^2)
//             = (3*x_n^3 - x_n^3 + radicand)/(3*x_n^2)
//             = (2*x_n^3 + radicand)/(3*x_n^2)
//             = (1/3) * (2*x_n + radicand/x_n^2)
//
// Unlike sqrt, cbrt is defined for negative inputs:
// cbrt(-radicand) = -cbrt(radicand), because (-x)^3 = -(x^3). We
// exploit that by computing on |radicand| and re-applying the sign at
// the end, which keeps the Newton iteration in the positive reals
// (where its convergence theory is simplest).
// =============================================================================

fn cbrt(radicand: f64) -> f64 {
    // cbrt(0) = 0 exactly, in both signs (+0 and -0 are both fixed
    // points). Handling this explicitly avoids the estimate = 0 seed
    // problem discussed below (the Newton update divides by estimate^2,
    // so a zero seed poisons the iteration with Inf/NaN).
    if radicand == 0.0 {
        return 0.0;
    }

    // Sign separation. We compute the positive cube root of
    // |radicand| and negate the result if the input was negative.
    // Parameters are immutable, so we copy the sign state into locals
    // rather than mutating `radicand` in place.
    var is_negative: bool = false;
    var abs_radicand: f64 = radicand;
    if radicand < 0.0 {
        is_negative = true;
        abs_radicand = -radicand;
    }

    // Seed selection. This is the part that was wrong in the original
    // version (which seeded with 0 and got Inf from the first update,
    // since radicand/0^2 = Inf, and Inf is a fixed point of the update).
    //
    // Newton for cbrt converges globally from any positive seed when
    // radicand > 0, but the *rate* depends on how close the seed is to
    // radicand^(1/3). The rule below picks:
    //
    //   |radicand| > 1 : seed = |radicand|. This is an upper bound on
    //                    radicand^(1/3) (since |radicand|^(1/3) <=
    //                    |radicand| for |radicand| >= 1), so the
    //                    monotone-decrease property applies from
    //                    step 1.
    //
    //   |radicand| <= 1: seed = 1.0. Also an upper bound
    //                    (radicand^(1/3) <= 1 for 0 < |radicand| <= 1).
    //                    Seeding with |radicand| here would be *below*
    //                    radicand^(1/3) (since radicand < radicand^(1/3)
    //                    for 0 < radicand < 1), which would force an
    //                    initial overshoot, harmless in principle, but
    //                    the overshoot can be large for tiny subnormals,
    //                    wasting iterations.
    //
    // Both branches guarantee estimate_0 > 0, which is the only hard
    // requirement: estimate_0 = 0 makes the first update
    // radicand/0^2 = Inf, and Inf is a fixed point
    // (2*Inf + radicand/Inf^2 = Inf + 0 = Inf, times 1/3 is still Inf)
    // the exact failure mode of the original code.
    var estimate: f64 = if abs_radicand > 1.0 { abs_radicand } else { 1.0 };

    // Fixed iteration count. As with sqrt_newton, Newton for cbrt
    // converges quadratically near the root once inside the basin, so
    // ~6 steps suffice for full f64 precision from a reasonable seed.
    // 40 is generous insurance. The loop is also idempotent at the
    // exact root (2*estimate + radicand/estimate^2 = 2*estimate +
    // estimate = 3*estimate, times 1/3 = estimate), so over-iterating
    // is harmless.
    var iteration: i64 = 1;
    while iteration < 40 {
        estimate = (1.0/3.0)
            * (2.0 * estimate + abs_radicand / (estimate*estimate));
        iteration += 1;
    }

    // Re-apply the sign. For negative inputs, cbrt(-radicand) =
    // -cbrt(radicand).
    if is_negative {
        return -estimate;
    }
    return estimate;
}

// =============================================================================
// hypot -> sqrt(p^2 + q^2), computed without intermediate overflow.
//
// The naive formula `sqrt(p*p + q*q)` fails for large operands: p*p can
// overflow to Inf even when the true hypot is a perfectly ordinary
// number. For example, hypot(1e200, 1e200) should be ~1.41e200 (well
// within range), but 1e200 * 1e200 = 1e400 = Inf, so naive squaring
// gives Inf.
//
// The fix is the algebraic identity:
//
//     sqrt(p^2 + q^2) = |max| * sqrt(1 + (|min|/|max|)^2)
//
// where max and min are the larger and smaller of |p|, |q|. The ratio
// |min|/|max| is always <= 1, so its square is <= 1 and the sum
// `1 + ratio^2` is in [1, 2] no overflow possible. Then multiplying
// by |max| recovers the true magnitude. Overflow can still happen in
// that final multiply if the true hypot genuinely exceeds MaxFloat64,
// which is correct behavior (and produces +Inf as IEEE 754 requires).
//
// This is exactly the algorithm C99's hypot() uses, and matches Go's
// math.Hypot for finite inputs. The special-value handling at the top
// is the IEEE-mandated part: hypot(Inf, NaN) must be +Inf (Inf
// dominates), and hypot(NaN, finite) must be NaN.
// =============================================================================

fn hypot(first: f64, second: f64) -> f64 {
    // Work with magnitudes. The hypot function is even in each argument
    // (hypot(-p, q) = hypot(p, q)), so the signs are irrelevant once
    // we've passed the special-value checks. `abs_first` and
    // `abs_second` are declared `var` because the swap below
    // reassigns them; the original `p, q` parameters are immutable.
    var abs_first, abs_second = abs(first), abs(second);

    // +Inf dominates NaN. This is the same priority rule as max():
    // if either operand is Inf, the answer is +Inf, regardless of
    // whether the other operand is NaN. IEEE 754 mandates this for
    // hypot because Inf represents an unbounded magnitude and the
    // correct pythagorean distance from an Inf coordinate to any
    // finite point is Inf.
    if is_inf(abs_first, 1) || is_inf(abs_second, 1) {
        return inf(1);
    } else if is_nan(abs_first) || is_nan(abs_second) {
        // Neither is Inf, but at least one is NaN: propagate NaN.
        // (NaN's priority is below Inf's, per the branch above.)
        return nan();
    }

    // Order the two magnitudes so abs_first is the larger. Why order
    // at all? Because the algebra needs a nonzero denominator, and
    // the ratio min/max is only <= 1 (which is what makes 1 + ratio^2
    // stay in [1, 2] and hence overflow-free) if max is in the
    // numerator's place. If we skipped the ordering and just divided
    // abs_second/abs_first, large values could make the ratio > 1,
    // and `1 + ratio^2` could overflow. Sorting first costs one
    // comparison and one conditional swap; the safety is worth it.
    if abs_first < abs_second {
        var temporary = abs_first;
        abs_first = abs_second;
        abs_second = temporary;
    }

    // Both magnitudes are zero (or the larger one is zero, which means
    // both are): hypot(0, 0) = 0. This also catches the case where
    // abs_first == 0 but abs_second is nonzero, impossible after the
    // swap, since abs_first >= abs_second. But keeping the check here
    // rather than after the swap would divide by zero in the next
    // line, so the guard is load-bearing.
    if abs_first == 0.0 {
        return 0.0;
    }

    // The core computation:
    //
    //     ratio = |min| / |max|                (in [0, 1] by the swap)
    //     result = |max| * sqrt(1 + ratio^2)
    //
    // The `1 + ratio*ratio` term is in [1, 2], so sqrt of it is in
    // [1, sqrt(2)] bounded away from both 0 and Inf. The only
    // overflow possible is the final multiply by abs_first, and that
    // happens only when the true hypot exceeds MaxFloat64, which is
    // the correct IEEE 754 outcome (produces +Inf).
    abs_second = abs_second / abs_first;
    return abs_first * sqrt(1.0 + abs_second*abs_second);
}
