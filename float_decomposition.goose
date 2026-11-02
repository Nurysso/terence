// =============================================================================
// Decomposition of f64 values: split a float into mantissa and exponent
// (frexp / ldexp), and recover its base-2 exponent (ilogb / logb).
//
// Every function here is a direct port of the corresponding entry in Go's
// math package, and the algorithms assume the IEEE 754 binary64 layout:
//
//     63    62 .. 52   51 .. 0
//   [sign][exponent][   mantissa   ]
//      1      11            52        bits
//
// A normal value with exponent field E and mantissa field M represents:
//
//     (-1)^sign * 2^(E - 1023) * (1 + M / 2^52)
//
// Subnormals (E == 0) use the same formula but drop the implicit leading 1
// and fix the exponent to -1022, giving (-1)^sign * 2^-1022 * (M / 2^52).
//
// The 52/11/1 split is why all the helpers below use shift = 52 and
// mask = 0x7ff (eleven 1-bits). Those are the only constants that matter
// for binary64; getting any of them wrong produces silently-wrong results,
// not crashes.
// =============================================================================

// get_exponent returns the *unbiased* exponent of a bit pattern.
//
//     (bits >> 52) & 0x7ff   →  raw field, 0 .. 2047
//     minus 1023             →  true exponent, -1023 .. +1024
//
// The result is not meaningful for subnormals (field 0 gives -1023, but
// the true exponent of the value is -1022 and the mantissa is doing the
// work of representing the smaller magnitude) or for Inf/NaN (field 2047
// gives +1024, but the "value" has no exponent). Callers are expected to
// handle those cases *before* calling this — which is exactly what
// normalize() is for.
//
// Why subtract 1023 (the bias)? Because storing exponents as unsigned
// integers means the smallest normal exponent is stored as 0 and the
// largest as 2046. Subtracting the midpoint 1023 recovers the signed
// value. Every IEEE 754 format uses this trick: it lets the hardware
// compare floats as if they were integers (for positive values).
fn get_exponent(bits: u64) -> i64 {
    return (((bits >> F64_SHIFT) & F64_MASK) as i64) - F64_BIAS;  // almost magic
}

// set_exponent returns `bits` with its exponent field replaced by `exponent`
// (unbiased). The sign bit and mantissa are preserved.
//
// The expression has two halves joined by OR:
//
//   bits & ~(mask << shift)   clears bits 52-62 in place, leaving
//                             everything else (sign, mantissa) untouched.
//                             This is the "keep the rest" half.
//
//   (exponent + bias) << shift  writes the new biased exponent into bits
//                               52-62. This is the "install the new field"
//                               half.
//
// Combined, `bits` is rebuilt with a fresh exponent and the original
// mantissa. Because the value scales by 2^(new_exp - old_exp), callers
// use this to shift a float's binary point without touching its digits —
// frexp below relies on exactly that.
//
// No range check is done. `exponent` outside [-1023, 1024] writes a field
// that doesn't correspond to a normal value; -1023 produces a subnormal
// pattern (or zero) and 1024 produces Inf/NaN. In practice this is only
// ever called from frexp with exponent = -1, which is safely in range.
fn set_exponent(bits: u64, exponent: i64) -> u64 {
    let biased_exponent = ((exponent + F64_BIAS) as u64) << F64_SHIFT;
    return (bits & ~(F64_MASK << F64_SHIFT)) | biased_exponent;
}

// =============================================================================
// frexp — "free exponent": split x into fraction × 2^exponent
//
// Contract: value == fraction * 2^exponent with 0.5 <= |fraction| < 1, for
// finite non-zero value. Special values are returned with exponent 0 so the
// caller never has to branch on them:
//
//     frexp(0)      = ( 0, 0)
//     frexp(±Inf)   = (±Inf, 0)
//     frexp(NaN)    = (NaN, 0)
//
// The exponent 0 is not arbitrary — it is the neutral element of the
// scaling, so `ldexp(frexp(value))` reconstructs value even for Inf and NaN.
// =============================================================================

fn frexp(value: f64) -> f64, i64 {
    // Special values pass through unchanged. Doing this up front means the
    // rest of the function can assume a finite, non-zero value — in
    // particular that normalize() and get_exponent() will produce
    // meaningful answers.
    if value == 0.0 || is_inf(value, 0) || is_nan(value) {
        return value, 0;
    }

    // normalize() handles subnormals: it scales them up by 2^52 so the
    // exponent field carries real information (subnormals all have field 0,
    // which decodes to -1023 regardless of how small the value actually is).
    // For normal inputs it returns (value, 0) unchanged. The second return
    // value is the exponent we subtracted to make normalization happen.
    let normalized, rescale_exp = normalize(value);

    let normalized_bits = float64_bits(normalized);

    // get_exponent() gives E such that |normalized| is in [2^E, 2^(E+1)).
    // Multiplying by 2^rescale_exp restores value, so value is in
    // [2^(E+rescale_exp), 2^(E+rescale_exp+1)).
    //
    // frexp wants value = fraction * 2^exponent with |fraction| in [0.5, 1),
    // which means value is in [2^(exponent-1), 2^exponent). So
    // exponent - 1 = E + rescale_exp, i.e. exponent = E + rescale_exp + 1.
    // That "+1" is the whole reason for the explicit `+ 1` in the code.
    let total_exp = rescale_exp + get_exponent(normalized_bits) + 1;

    // set_exponent(bits, -1) rewrites the exponent field so that the value
    // becomes fraction = normalized * 2^-1, which lands in [0.5, 1)
    // precisely because normalized was in [1, 2). The mantissa (and
    // therefore the exact digits) are untouched: we are only moving the
    // binary point.
    let rewritten_bits = set_exponent(normalized_bits, -1);

    return float64_frombits(rewritten_bits), total_exp;
}

// =============================================================================
// ldexp — "load exponent": the inverse of frexp, computing fraction × 2^exponent
//
// Contract: the result is `fraction` scaled by 2^exponent, rounded once to
// the nearest f64. All four IEEE exceptions (overflow, underflow, subnormal,
// exact) are produced in their canonical form:
//
//     ldexp(±0,    exp) = ±0              (sign preserved)
//     ldexp(±Inf,  exp) = ±Inf            (exp ignored)
//     ldexp(NaN,   exp) = NaN             (exp ignored)
//     ldexp(x, 1024)    = ±Inf            (overflow)
//     ldexp(x, -1075)   = ±0 or 2^-1074   (underflow/rounding, see below)
// =============================================================================

fn ldexp(fraction: f64, exponent: i64) -> f64 {
    // Special values: same early-out as frexp. Returning `fraction`
    // unchanged is correct because 0 * anything = 0, Inf * anything = Inf,
    // and NaN * anything = NaN, all with the sign preserved.
    if fraction == 0.0 || is_inf(fraction, 0) || is_nan(fraction) {
        return fraction;
    }

    // Normalize so the exponent field is meaningful (subnormals otherwise
    // appear to have exponent -1023 no matter how small they are).
    let normalized, rescale_exponent = normalize(fraction);

    // total_exponent accumulates the *total* exponent of the product
    // fraction * 2^exponent:
    //   + exponent             the caller's power of two
    //   + rescale_exponent     the implicit rescale normalize() applied
    //   + E_normalized         the exponent of the normalized value itself
    // After this, the target value is exactly
    // m_normalized * 2^total_exponent, where m_normalized is the mantissa
    // of `normalized` (in [1, 2)).
    var total_exponent = exponent + rescale_exponent;

    // Extract E_normalized (the unbiased exponent of `normalized`) and add
    // it in. Written out rather than calling get_exponent() to avoid a
    // second call to float64_bits, which would be pure overhead.
    let normalized_bits = float64_bits(normalized);
    total_exponent += (((normalized_bits >> 52) & 0x7ff) as i64) - 1023;

    // Underflow: the target value is below 2^-1075, smaller than half the
    // smallest subnormal. Rounding is unambiguous — the answer is zero, and
    // the sign of the input is preserved.
    //
    // Values at total_exponent == -1075 are NOT caught here. They are
    // handled by the subnormal path below, which represents them as
    // (normal mantissa) * 2^-53; the hardware multiply at the end rounds
    // that intermediate to the correct subnormal or zero. Letting the FPU
    // do the rounding avoids having to enumerate the individual tie-breaking
    // cases here.
    if total_exponent < -1075 {
        return copysign(0.0, normalized);
    }

    // Overflow: the target value is at least 2^1024, beyond MaxFloat64.
    // Return Inf with the sign of the original input (not the normalized
    // input — they have the same sign, but referring to `normalized` keeps
    // the sign from being lost if the normalization path ever changes).
    if total_exponent > 1023 {
        if signbit(normalized) { return inf(-1); }
        return inf(1);
    }

    // Subnormal result: total_exponent is below the smallest normal
    // exponent, so the straightforward "write total_exponent + 1023 into
    // the exponent field" would produce a pattern whose implicit leading 1
    // has nowhere to go.
    //
    // The fix is to represent the target as a *normal* number times 2^-53:
    // bump total_exponent up by 53 (so the exponent field is valid), then
    // scale the whole result back down by 2^-53 using the multiplier
    // `scale`. The final multiply rounds once, landing on the nearest
    // subnormal (or zero).
    //
    // This works for every total_exponent in [-1075, -1023]; the small
    // residual rounding ambiguity at total_exponent = -1075 (rounds to
    // zero vs. to 2^-1074) is decided by the hardware in round-to-nearest-
    // even, matching IEEE 754.
    var scale: f64 = 1.0;
    if total_exponent < -1022 {
        total_exponent += 53;
        scale = 0x1p-53;
    }

    // Rebuild the float with the adjusted exponent. Clearing the field
    // first ensures the original exponent does not leak through; the
    // mantissa bits (0-51) and the sign bit (63) are untouched, so the
    // final value keeps `fraction`'s sign and digits exactly.
    var result_bits = normalized_bits;
    result_bits &= ~((0x7ff as u64) << 52);
    result_bits |= ((total_exponent + 1023) as u64) << 52;
    return scale * float64_frombits(result_bits);
}

// =============================================================================
// ilogb — "integer log base 2": exponent of x as an int
//
// For finite non-zero normal x, returns E with 2^E <= |x| < 2^(E+1).
// For subnormals the result is the exponent of the leading 1 bit in the
// *unscaled* value, i.e. the E such that |x| = m * 2^E with m in [0.5, 1),
// matching C99 and Go. Special values use the standard sentinels:
//
//     ilogb(±0)   = MinInt32   (FP_ILOGB0 in C)
//     ilogb(±Inf) = MaxInt32   (FP_ILOGBNAN/INT_MAX in C)
//     ilogb(NaN)  = MaxInt32
//
// The sentinels come from C's math.h and are part of the ilogb contract
// (they are not errors you are meant to catch — they are the return value).
// =============================================================================

fn ilogb(value: f64) -> i64 {
    // C99 sentinels, in order of decreasing specificity: NaN and Inf both
    // map to INT_MAX, but they are checked separately because Go's reference
    // implementation lists them in this order and it is worth mirroring.
    if value == 0.0 {
        return MinInt32;
    } else if is_nan(value) {
        return MaxInt32;
    } else if is_inf(value, 0) {
        return MaxInt32;
    }

    // Same trick as frexp: normalize handles subnormals, get_exponent gets
    // the exponent of the (possibly rescaled) value, and the rescale amount
    // is added back so the returned exponent matches the *unscaled* input.
    //
    // Note there is no "+1" here, unlike frexp. frexp wants fraction in
    // [0.5, 1) so it shifts the exponent by one; ilogb wants the E of the
    // leading bit in [1, 2), which is just the unbiased exponent of the
    // value.
    let normalized, rescale_exponent = normalize(value);
    let biased_exponent =
        ((float64_bits(normalized) >> F64_SHIFT) & F64_MASK) as i64;
    return biased_exponent - F64_BIAS + rescale_exponent;
}

// =============================================================================
// logb — log base 2 of |x|, as a float
//
// The values agree with ilogb(x) for finite non-zero x, but the signature
// is f64 -> f64. That forces two divergences from ilogb:
//
//   1. ilogb(0) is a sentinel (MinInt32); logb(0) is -Inf, because the
//      limit of log2(x) as x -> 0+ is -Inf and returning a "negative
//      billion" sentinel would be indistinguishable from a real answer.
//
//   2. ilogb(±Inf) is a sentinel; logb(±Inf) is +Inf, matching the limit
//      of log2(x) as x -> Inf. Go's math.Logb documents these explicitly.
//
// Everything else is ilogb, cast to f64 at the end. The cast is exact:
// every ilogb result fits comfortably in an f64 mantissa (the range is
// [-1074, 1023]).
// =============================================================================

fn logb(value: f64) -> f64 {
    // Zero: log2(0) diverges to -Inf, not to a sentinel. -0.0 and +0.0
    // both return -Inf (the limit exists from both sides).
    if value == 0.0 {
        return inf(-1);
    } else if is_inf(value, 0) {
        // Both +Inf and -Inf: log2(|±Inf|) = +Inf. Not sign-preserving,
        // because logb takes the magnitude.
        return inf(1);
    } else if is_nan(value) {
        return value;
    }

    // Finite non-zero: defer to ilogb and widen. The cast is lossless
    // because every ilogb result is small enough to represent exactly in
    // f64's 53-bit mantissa.
    return ilogb(value);
}

// =============================================================================
// next_after — the next representable float from `from_value` toward
// `to_value`.
//
// This walks the ordered enumeration of IEEE 754 values. The ordering is
// not the integer ordering of the bit patterns for negative numbers (they
// are reversed), but for positive numbers it is. The function handles both
// by comparing the direction to the sign of x.
// =============================================================================

fn next_after(from_value: f64, to_value: f64) -> f64 {
    // NaN propagates in either argument.
    if is_nan(from_value) || is_nan(to_value) {
        return nan();
    }
    // Same value: no step to take. This also catches +0 and -0 (which
    // compare equal), correctly returning the starting value.
    if from_value == to_value {
        return from_value;
    }
    // +0 and -0 need explicit handling: bit-decrement of +0 (bits == 0)
    // wraps to 0xFFFF_FFFF_FFFF_FFFF, which is a NaN pattern, not
    // -SmallestNonzero. Similarly bit-increment of -0 (bits ==
    // 0x8000_0000_0000_0000) hits the negative NaN range. IEEE 754 handles
    // this by defining the two nearest neighbors of zero as
    // ±SmallestNonzero, both signed by the direction argument.
    if from_value == 0.0 {
        return copysign(SmallestNonzeroFloat64, to_value);
    }
    let bits = float64_bits(from_value);
    // Direction: on the *positive* side, "greater value" = "greater bits";
    // on the *negative* side it's inverted (more negative = greater bits
    // because the magnitude grows with the integer). The XOR-style condition
    // `(to_value > from_value) == (from_value > 0)` captures both cases in
    // one comparison: when the two booleans agree, stepping "up" in the
    // ordered sense means incrementing the bit pattern.
    if (to_value > from_value) == (from_value > 0) {
        return float64_frombits(bits + 1);
    }
    return float64_frombits(bits - 1);
}

// =============================================================================
// next_after32 — f32 version of next_after.
//
// Same logic, narrower format. The only differences are the bit width
// (32 instead of 64), the smallest subnormal (2^-149 instead of 2^-1074),
// and the widening to f64 for the copysign call (which works in f64
// because the f32 subnormal 2^-149 is exactly representable in f64).
// =============================================================================

fn next_after32(from_value: f32, to_value: f32) -> f32 {
    // f32 widens to f64 implicitly; is_nan and friends take f64.
    if is_nan(from_value) || is_nan(to_value) {
        return nan() as f32;
    }
    if from_value == to_value {
        return from_value;
    }
    // Same zero-boundary handling as next_after, using the f32 smallest
    // subnormal. copysign works in f64; both arguments widen implicitly
    // and the result narrows back to f32 exactly (2^-149 is representable).
    if from_value == 0.0 {
        return copysign(SmallestNonzeroFloat32, to_value) as f32;
    }
    let bits = float32_bits(from_value);
    if (to_value > from_value) == (from_value > 0) {
        return float32_frombits(bits + 1);
    }
    return float32_frombits(bits - 1);
}
