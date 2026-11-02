// =============================================================================
// Rounding primitives: floor, ceil, round, trunc, modf, and round-to-even.
//
// All of these take an f64 and return an f64. The unifying theme is that
// IEEE 754 arithmetic is exact for integer-valued results in the range
// [-2^53, 2^53], so "rounding" here means discarding fractional bits
// rather than approximating: the only rounding that occurs is when the
// result is not exactly representable, which for these functions never
// happens (the result is always an integer or ±0).
//
// Special values (NaN, ±Inf, ±0) are handled by early return in each
// function. This is not just defensive coding: IEEE 754 defines these
// results, and getting them wrong (e.g. returning NaN for floor(0))
// would silently corrupt downstream computations.
// =============================================================================

// floor returns the largest integer <= value.
//
// The sign split matters because the two directions round differently:
// for positive values, truncation (round toward zero) *is* floor; for
// negative values, truncation goes the wrong way (e.g. trunc(-3.7) = -3,
// but floor(-3.7) = -4), so we negate, round up, and negate back.
//
// This is the -ceil(-x) identity from elementary arithmetic: floor(x) =
// -ceil(-x). The implementation computes ceil(-x) as trunc(-x) plus one
// if there was a fractional part, because ceil(z) for z > 0 is just
// trunc(z) unless z is not an integer, in which case it's one more.
fn floor(value: f64) -> f64 {
    // IEEE 754: floor(±0) = ±0, floor(NaN) = NaN, floor(±Inf) = ±Inf.
    // All three are the identity, so a single early return covers them.
    if value == 0.0 || is_nan(value) || is_inf(value, 0) {
        return value;
    }
    if value < 0.0 {
        // value < 0, so -value > 0. modf(-value) gives the integer part
        // (toward zero) and fractional part of -value. Since -value > 0,
        // "toward zero" and "down" coincide for the integer part, but
        // the *original* value is negative, so we need to round the
        // integer part up (away from zero in -value, i.e. toward -Inf
        // in value) whenever there was a fractional part.
        //
        // `integer_part` is reassigned (+1), so it must be `var`.
        // `fractional_part` is only read, so `let` suffices.
        var integer_part, fractional_part = modf(-value);
        if fractional_part != 0.0 {
            integer_part = integer_part + 1;
        }
        return -integer_part;
    }
    // value > 0: floor and trunc agree, so just take the integer part.
    // The discarded fractional part is intentional (its sign is the
    // same as value's, so it's positive and doesn't affect the floor).
    let integer_part, _ = modf(value);
    return integer_part;
}

// ceil returns the smallest integer >= value.
//
// Rather than duplicating floor's logic, we use the identity
// ceil(x) = -floor(-x). This is exact for all finite values because
// negation is exact in IEEE 754 (it only flips the sign bit) and floor
// is exact by the argument above. The `-1.0 *` rather than unary minus
// is a holdover from the original: it ensures the literal is inferred
// as f64 rather than i32.
fn ceil(value: f64) -> f64 {
    return -1.0 * floor(-value);
}

// round returns the nearest integer to value, with ties going away from
// zero (the "schoolbook" rounding, not banker's rounding — see
// round_to_even below for that).
//
// The algorithm is: truncate, then check whether the discarded part was
// at least half an ulp. The comparison uses `abs(value - truncated)`
// rather than `value - truncated` so the sign of the correction is
// handled uniformly: copysign(1.0, value) gives +1 for positive values
// and -1 for negative, and adding that to `truncated` moves one step
// away from zero.
//
// Why >= 0.5 rather than > 0.5? Because 0.5 is exactly representable
// and we want .5 to round up (away from zero). If we used >, then
// round(2.5) would give 2 (truncation) instead of 3.
fn round(value: f64) -> f64 {
    let truncated = trunc(value);
    if abs(value - truncated) >= 0.5 {
        return truncated + copysign(1.0, value);
    }
    return truncated;
}

// trunc returns the integer part of value, rounded toward zero.
//
// This is the one function here that reaches into the bit representation:
// for |value| >= 1, the fractional bits are the low (52 - exponent) bits
// of the mantissa, and truncation is just clearing them. For |value| < 1,
// the answer is ±0 (sign preserved), which we handle separately because
// the bit trick would need a negative shift.
//
// Bit manipulation is preferred over arithmetic here because it is exact
// for every representable input, including subnormals — arithmetic like
// `value - modf(value).1` can lose precision when the fractional part
// is tiny relative to the integer part.
fn trunc(value: f64) -> f64 {
    // |value| < 1: no integer bits, answer is ±0. The copysign preserves
    // the sign of value (trunc(-0.5) = -0, not +0), matching IEEE 754.
    if abs(value) < 1.0 {
        return copysign(0.0, value);
    }
    // `bits` is reassigned (`bits &= ...`), so `var` not `let`.
    var bits = float64_bits(value);
    // The unbiased exponent tells us where the binary point sits. For a
    // normal value with exponent field E, the value is
    // (1.fraction) × 2^(E - 1023), so the integer part uses bits
    // 52 - (E - 1023) = 52 - exponent of the mantissa, where
    // exponent = E - 1023. For |value| >= 2^52, exponent >= 52, so there
    // are no fractional bits to clear and the bit mask would be a no-op
    // (or worse, a shift of a negative amount, which Rust treats as a
    // panic).
    let exponent = (((bits >> F64_SHIFT) & F64_MASK) as i64) - F64_BIAS;
    if exponent < 52 {
        // Number of low mantissa bits to clear. For example, for value
        // in [2^5, 2^6), exponent = 5 and there are 52 - 5 = 47
        // fractional bits.
        let fractional_bit_count = (52 - exponent) as u64;
        // Clear those bits. The mask construction is:
        //   (1 << n) - 1     →  low n bits set
        //   ~(...)           →  low n bits clear, everything else set
        //   bits & ~(...)    →  value with low n bits cleared
        // The `- 1` must be INSIDE the `~`; writing `~(1 << n) - 1`
        // would compute (~(1 << n)) - 1, which is off by one.
        bits &= ~(((1 as u64) << fractional_bit_count) - 1);
    }
    return float64_frombits(bits);
}

// modf splits value into integer and fractional parts: value = int + frac.
//
// The integer part is `trunc(value)` (round toward zero), so the
// fractional part has the same sign as value. This matters: modf(-2.5)
// returns (-2.0, -0.5), not (-2.0, +0.5). The IEEE 754 modf function
// specifies this sign convention, and C99 (which Go follows) matches it.
//
// The copysign on the fraction is technically redundant (value - trunc
// already has value's sign for all finite value), but it's explicit
// documentation of the invariant and handles the signed-zero edge case
// correctly.
fn modf(value: f64) -> f64, f64 {
    let integer = trunc(value);
    let fraction = copysign(value - integer, value);
    return integer, fraction;
}

// round_to_even returns the nearest integer to value, with ties going
// to the even integer. This is the default IEEE 754 rounding mode
// ("round to nearest, ties to even"), so it's what you get from
// ordinary floating-point arithmetic — which is why it appears in
// math libraries as a named function.
//
// The algorithm is a case analysis on the exponent field:
//
//   1. |value| < 1: the result is ±0 or ±1. The threshold is 0.5, and
//      a tie (|value| == 0.5) rounds to ±0 (the even choice).
//
//   2. 1 <= |value| < 2^52: the value has at least one fractional bit.
//      We split the mantissa into an integer part (high bits) and a
//      fractional part (low bits), and round the fractional part up if
//      it exceeds half an ulp, or if it equals half an ulp and the
//      integer part is odd.
//
//   3. |value| >= 2^52, Inf, or NaN: already an integer (or not a
//      number). Return unchanged.
fn round_to_even(value: f64) -> f64 {
    // Bit-field constants for the binary64 layout. These match the
    // layout documented at the top of the file:
    //   sign      bit 63         (0x8000_0000_0000_0000)
    //   exponent  bits 52-62     (extracted with shift + mask)
    //   mantissa  bits 0-51      (0x000F_FFFF_FFFF_FFFF)
    // `one_bits` is the bit pattern of 1.0 in this layout: exponent
    // field = BIAS (1023), mantissa = 0.
    let sign_mask:     u64 = 0x8000000000000000;   // 1 << 63
    let fraction_mask: u64 = 0x000FFFFFFFFFFFFF;   // (1 << 52) - 1
    let one_bits:      u64 = 0x3FF0000000000000;   // 1.0's bit pattern

    // `bits` is reassigned below, so it needs to be `var`.
    var bits = float64_bits(value);
    // Raw biased exponent field: 0 for subnormals, 2047 for Inf/NaN,
    // 1023 for values in [1, 2), 1022 for values in [0.5, 1), etc.
    let exponent_field = (bits >> F64_SHIFT) & F64_MASK;

    if exponent_field < (F64_BIAS as u64) {
        // |value| < 1: the only possibilities are ±0 (|value| <= 0.5)
        // and ±1 (0.5 < |value| < 1). Save whether the mantissa is
        // nonzero BEFORE clearing `bits` to the sign bit — the mantissa
        // is exactly what distinguishes |value| == 0.5 from
        // |value| > 0.5.
        let had_fractional_part = (bits & fraction_mask) != 0;
        bits &= sign_mask;
        if exponent_field == (F64_BIAS as u64) - 1 && had_fractional_part {
            // |value| is in (0.5, 1). Round to ±1.
            //
            // Why exponent_field == BIAS - 1? The exponent field for
            // [0.5, 1) is 1022 (BIAS - 1). Combined with a nonzero
            // mantissa, that's exactly the open interval (0.5, 1).
            // |value| == 0.5 has the same exponent field but a zero
            // mantissa, so `had_fractional_part` is false and we don't
            // enter this branch (0.5 rounds to 0, the even choice).
            bits |= one_bits;
        }
        // Otherwise (|value| <= 0.5): result is ±0, already in `bits`.
    } else if exponent_field < (F64_BIAS as u64) + 52 {
        // |value| is in [1, 2^52): has at least one fractional bit.
        //
        // The upper bound BIAS + 52 (i.e. exponent_field < 1075) is
        // what excludes Inf and NaN (field 2047). Values with
        // exponent_field >= 1075 (i.e. |value| >= 2^52) are already
        // integers: their mantissa's 52 bits are entirely to the left
        // of the binary point.
        //
        // For comparison: exponent_field = 1023 + e, so an unbiased
        // exponent e in [0, 51] means the value is in [2^e, 2^(e+1)),
        // and there are 52 - e fractional bits.
        let exponent = (exponent_field as i64) - F64_BIAS;   // 0 .. 51
        let fractional_bit_count = (52 - exponent) as u64;    // 1 .. 52
        // Mask covering the fractional bits.
        let fractional_mask = ((1 as u64) << fractional_bit_count) - 1;
        // Mask for the tie bit: the highest fractional bit, which
        // represents exactly half an ulp at this exponent.
        let tie_bit_mask = (1 as u64) << (fractional_bit_count - 1);

        // Split into integer and fractional parts (in bit form).
        let floor_bits      = bits & ~fractional_mask;
        let fractional_bits = bits & fractional_mask;
        // LSB of the integer part — controls tie-breaking.
        let floor_lsb = (floor_bits >> fractional_bit_count) & 1;

        // Round up (in magnitude) iff:
        //   - fractional part > half ulp, OR
        //   - fractional part == half ulp AND integer part is odd.
        // Otherwise round down. This is the "round half to even" rule:
        // on a tie, prefer the even integer. `floor_lsb == 1` means the
        // truncated integer is odd, so rounding up makes it even.
        if fractional_bits > tie_bit_mask
            || (fractional_bits == tie_bit_mask && floor_lsb == 1)
        {
            // Add 1 at the position of the lowest integer bit. This is
            // the same as incrementing the integer part, but works
            // directly on the bit pattern, avoiding any chance of
            // an intermediate rounding when the integer is near 2^52.
            bits = floor_bits + ((1 as u64) << fractional_bit_count);
        } else {
            bits = floor_bits;
        }
    }
    // else: |value| >= 2^52, Inf, or NaN — no fractional bits to round.

    return float64_frombits(bits);
}
