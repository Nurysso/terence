// =============================================================================
// Binary operations on f64: max, min, dim, mod, remainder, fma.
//
// These follow the Go math package's conventions, which in turn follow
// IEEE 754. The interesting parts are the special-value handling:
//
//   - NaN: usually propagates, but the priority relative to Inf differs
//     between max and min (see comments).
//   - Signed zero: +0 and -0 compare equal, so ordering functions need
//     an explicit signbit tiebreak.
//   - Inf: interacts with NaN per the max/min priority rules, and is
//     the identity for some operations (mod(x, ±Inf) = x).
//
// Every function here is a direct port of the corresponding Go math
// function. The algorithms are the standard ones; the comments focus on
// the choices that are easy to get wrong.
// =============================================================================

fn max(left: f64, right: f64) -> f64 {
    // +Inf dominates everything, including NaN. This is a deliberate
    // choice in Go's math.Max: Max(x, +Inf) = +Inf even when x is NaN.
    // The rationale is that +Inf is the maximum possible magnitude, and
    // a caller taking the max of a set containing +Inf should get +Inf
    // regardless of whether other elements are NaN.
    if is_inf(left, 1) || is_inf(right, 1) {
        return inf(1);
    } else if is_nan(left) || is_nan(right) {
        // If neither operand is +Inf and at least one is NaN, the
        // result is NaN. (IEEE 754 maxNum would return the non-NaN
        // operand, but Go's math.Max is not maxNum — it propagates NaN
        // whenever +Inf doesn't short-circuit.)
        return nan();
    } else if left == 0.0 && left == right {
        // Both are zero, possibly with different signs. +0 > -0 for
        // the purposes of max (IEEE 754 totalOrder places +0 after -0),
        // so return the +0. If `left` is negative zero, `right` must
        // be +0 (since they're equal but we know they're both zero),
        // so return right; otherwise left is +0 and we return it.
        if signbit(left) { return right; }
        return left;
    }
    // Ordinary comparison. NaN is already excluded, so the > here is
    // well-defined.
    if left > right { return left; }
    return right;
}

fn min(left: f64, right: f64) -> f64 {
    // By symmetry with max: -Inf dominates everything, including NaN.
    // Note the sign is -1 here, unlike max's +1 — an easy bug to
    // introduce when copying.
    if is_inf(left, -1) || is_inf(right, -1) {
        return inf(-1);
    } else if is_nan(left) || is_nan(right) {
        return nan();
    } else if left == 0.0 && left == right {
        // Both are zero. -0 < +0 in IEEE 754 totalOrder, so min
        // should return -0. If `left` is -0, return it; otherwise
        // left must be +0 and right must be -0, so return right.
        if signbit(left) { return left; }
        return right;
    }
    if left < right { return left; }
    return right;
}

// dim returns max(minuend - subtrahend, 0), the "positive difference".
// Used by interval arithmetic and by anything that wants a non-negative
// distance without the sqrt.
//
// The interesting part is `difference <= 0`: it catches both the
// strictly-negative case (want 0) and the exactly-zero case (want 0).
// It does NOT catch NaN (NaN <= 0 is false), so dim(NaN, y) returns
// NaN. This matches Go's math.Dim, which documents NaN propagation.
fn dim(minuend: f64, subtrahend: f64) -> f64 {
    // The `<= 0` branch must return literal 0.0, not `difference`.
    // Returning `difference` (which is <= 0) would give dim(x, y) =
    // x - y for every x <= y, instead of the correct answer 0.
    let difference = minuend - subtrahend;
    if difference <= 0.0 { return 0.0; }
    return difference;
}

// mod returns the floating-point remainder of dividend/divisor, with
// the sign of the dividend (truncated-division convention, matching
// C's fmod and Go's math.Mod).
//
// The algorithm is repeated subtraction: at each step, subtract the
// largest multiple of |divisor| that fits in the current remainder.
// Naive repeated subtraction would be O(dividend/divisor) steps, which
// is huge; the frexp/ldexp trick lets us subtract approximately half
// the current magnitude each step, giving O(log(dividend/divisor))
// steps.
//
// Why not just use a formula like dividend - divisor*trunc(dividend/divisor)?
// Because dividend/divisor can overflow (for tiny divisor), and the result
// of the multiplication can lose precision. Repeated subtraction of
// exactly-representable multiples avoids both problems, at the cost of a
// few extra iterations.
fn mod(dividend: f64, divisor: f64) -> f64 {
    // Special cases:
    //   mod(x, 0) = NaN   (division by zero)
    //   mod(±Inf, y) = NaN (Inf reduced mod anything is undefined)
    //   mod(x, ±Inf) = x   (handled implicitly: the while loop's
    //                       condition is false when |divisor| = Inf)
    //   mod(NaN, y) = mod(x, NaN) = NaN
    //
    // The ±Inf divisor case is NOT in the early-out because it's the
    // identity, and frexp(Inf) = (Inf, 0) makes the loop body a no-op.
    if divisor == 0.0 || is_inf(dividend, 0)
        || is_nan(dividend) || is_nan(divisor) {
        return nan();
    }
    // Work with the absolute value of the divisor; the sign of the
    // result is determined solely by the dividend (see below).
    // Parameters are immutable, so `divisor = abs(divisor)` would be
    // an error; we introduce a local instead.
    let abs_divisor = abs(divisor);
    // Decompose abs_divisor into (fraction, exponent) with fraction in
    // [0.5, 1). This lets us compare the magnitude of the current
    // remainder to a scaled version of the divisor without computing
    // a division.
    let divisor_fraction, divisor_exponent = frexp(abs_divisor);

    // Start with |dividend| and subtract until we can't. `remainder_value`
    // is reassigned each iteration, so `var`.
    var remainder_value = if dividend < 0.0 { -dividend } else { dividend };

    while remainder_value >= abs_divisor {
        // Decompose the current remainder the same way.
        // `remainder_fraction` is `let` (never reassigned);
        // `remainder_exponent` may be decremented below, so `var`.
        var remainder_fraction, remainder_exponent = frexp(remainder_value);
        // Find the largest k such that k * abs_divisor <= remainder_value,
        // with k a power of 2. In frexp terms, abs_divisor = df * 2^de
        // and remainder_value = rf * 2^re. We need
        // k * df <= rf * 2^(re-de).
        //
        // If rf >= df, k = 2^(re - de) works (since df <= rf).
        // If rf < df, we need one less power of two: k = 2^(re - de - 1).
        //
        // The subtraction below uses ldexp to form the multiple exactly
        // (ldexp is exact for the values involved here), so no rounding
        // error is introduced by the multiply.
        if remainder_fraction < divisor_fraction {
            remainder_exponent = remainder_exponent - 1;
        }
        remainder_value = remainder_value
            - ldexp(abs_divisor, remainder_exponent - divisor_exponent);
    }

    // The loop computed |dividend| mod |divisor|. Restore the sign of
    // the original dividend: mod(-x, y) = -mod(x, y).
    if dividend < 0.0 { remainder_value = -remainder_value; }
    return remainder_value;
}

// remainder returns the IEEE 754 remainder of dividend/divisor:
// dividend - n*divisor, where n is the integer nearest dividend/divisor
// (ties to even).
//
// This differs from mod() in two important ways:
//   1. The sign of the result can be either sign, regardless of the
//      dividend's sign. For example, remainder(5, 3) = -1 (since
//      n = 2, the nearest integer to 5/3), while mod(5, 3) = 2.
//   2. The magnitude is at most |divisor|/2, whereas mod's is at most
//      |divisor|. This makes remainder useful for range reduction
//      (e.g. in trig argument reduction), where you want a small
//      argument regardless of the input magnitude.
fn remainder(dividend: f64, divisor: f64) -> f64 {
    // `tiny` is 2^-1021, which is the smallest normal exponent divided
    // by 2 — chosen so that `x + x` doesn't overflow to Inf for the
    // largest possible x, while `y` is still small enough that the
    // subtraction loop below needs the special-case handling.
    //
    // The literal 4.45014771701440276618e-308 is the exact decimal
    // approximation of 0x1p-1021 (the bit pattern 0x0020000000000000).
    // Writing it as a hex float (`0x1p-1021`) would also work but this
    // matches Go's source.
    let tiny: f64 = 4.45014771701440276618e-308;    // 2^-1021

    // Half of MaxFloat64. If |divisor| <= half_max, then
    // |dividend| mod |2*divisor| is well-defined without overflow,
    // which is the precondition for the Mod step below.
    let half_max = MaxFloat64 / 2.0;

    // Special cases:
    //   remainder(±Inf, y) = NaN
    //   remainder(NaN, y)  = NaN
    //   remainder(x, 0)    = NaN
    //   remainder(x, ±Inf) = x
    // The ±Inf divisor case is the identity; the rest return NaN.
    if is_nan(dividend) || is_nan(divisor)
        || is_inf(dividend, 0) || divisor == 0.0 {
        return nan();
    } else if is_inf(divisor, 0) {
        return dividend;
    }

    // Work with absolute values. `negative_dividend` records the sign
    // so it can be restored at the end. Parameters are immutable, so
    // the absolute values go into locals.
    let negative_dividend = dividend < 0.0;
    var abs_dividend = if negative_dividend { -dividend } else { dividend };
    let abs_divisor = abs(divisor);

    // Trivial case: |dividend| == |divisor|. The IEEE remainder is ±0
    // (sign of the dividend), because n = ±1 and dividend - n*divisor
    // = 0.
    if abs_dividend == abs_divisor {
        if negative_dividend { return -0.0; }
        return 0.0;
    }

    // Step 1: reduce abs_dividend mod 2*abs_divisor to get a value in
    // [0, 2*abs_divisor). The `<= half_max` guard ensures that
    // 2*abs_divisor doesn't overflow to Inf (which would break the mod).
    if abs_divisor <= half_max {
        abs_dividend = mod(abs_dividend, abs_divisor + abs_divisor);
    }

    // Step 2: now abs_dividend is in [0, 2*abs_divisor). We want to
    // find the integer n in {0, 1, 2} that minimizes
    // |abs_dividend - n*abs_divisor|, with ties going to even n.
    //
    // The branch on `abs_divisor < tiny` handles the case where the
    // subtraction would underflow; the `half_divisor` branch handles
    // the general case. Both do at most two subtractions because
    // abs_dividend < 2*abs_divisor.
    if abs_divisor < tiny {
        // Tiny divisor: use `x + x` instead of `2 * x` to avoid
        // potential overflow in the comparison. The thresholds are
        // `> y` and `>= y` (rather than `>= y/2` and `>= y/2`) for
        // the same reason — y/2 might underflow.
        if abs_dividend + abs_dividend > abs_divisor {
            abs_dividend = abs_dividend - abs_divisor;
            if abs_dividend + abs_dividend >= abs_divisor {
                abs_dividend = abs_dividend - abs_divisor;
            }
        }
    } else {
        // General case: compare to half_divisor to decide whether to
        // subtract. The specific comparison (>= rather than >)
        // determines how exact ties are broken; the effect of the two
        // subtractions together is that |abs_dividend| ends up <=
        // |abs_divisor|/2, which is the IEEE remainder magnitude bound.
        let half_divisor = 0.5 * abs_divisor;
        if abs_dividend >= half_divisor {
            abs_dividend = abs_dividend - abs_divisor;
            if abs_dividend >= half_divisor {
                abs_dividend = abs_dividend - abs_divisor;
            }
        }
    }

    // Restore the sign of the original dividend. IEEE 754 remainder is
    // odd in that the result's sign is not always the dividend's sign
    // (e.g. remainder(5, 3) = -1, which is negative even though the
    // dividend is positive). The sign is preserved here because the
    // computation tracked the magnitude and re-applied the dividend's
    // sign; if you need the true IEEE sign, use the result's own sign.
    if negative_dividend { return -abs_dividend; }
    return abs_dividend;
}

// fma returns the fused multiply-add of its three arguments:
// factor_a * factor_b + addend.
//
// "Fused" means the multiply and add are performed as a single
// operation with only one rounding. Naive `factor_a * factor_b + addend`
// rounds twice (once for the product, once for the sum), so it can
// differ from a true FMA by one ulp. A correctly-rounded FMA needs
// hardware support; the naive version below is what you get from a
// compiler that doesn't fuse, and is provided here as a fallback.
fn fma(factor_a: f64, factor_b: f64, addend: f64) -> f64 {
    // Note: this is NOT correctly rounded. The product rounds once,
    // then the sum rounds again. A true FMA would use the full product
    // (which may need 106 bits) as an intermediate, rounding only once
    // at the end.
    return factor_a * factor_b + addend;
}
