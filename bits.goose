// =============================================================================
// Bit-level access and classification of floating-point values.
//
// Port of the first tier of Go's math package (unsafe.go, bits.go, abs.go,
// copysign.go, signbit.go). Everything here is IEEE 754-2019 compliant.
//
// Goose has no bitcast, so the two directions are implemented differently:
//
//   * float -> bits: pack the float into a one-element array and read its
//     bytes with bytes_of. Scalars are little-endian in memory (spec
//     Appendix C.2), so byte 0 is the least-significant byte and no host
//     endianness check is needed.
//
//   * bits -> float: assemble the value arithmetically from sign, exponent,
//     and mantissa. Every intermediate is an integer in [0, 2^53), multiplied
//     by a power of two, so no rounding ever occurs.
//
// Depends on: constants.goose (MaxFloat64).
// =============================================================================

// =============================================================================
// Internal helper
// =============================================================================

// exact_pow2 returns 2^n exactly, for -1074 <= n <= 971.
//
// The useful range is bounded by the f64 format itself:
//   n = -1074 is the smallest subnormal (2^-1074);
//   n = -1075 and below underflow to 0.0.
// The upper bound of 971 is conservative: the algorithm actually stays exact
// up to n = 1023, but the intermediate `base` overflows to +Inf on the very
// last pass for n >= 972. That overflow is harmless because the result is
// already in `r` by then (see comment below), so the bound could be raised;
// 971 is documented as the guaranteed-safe range.
//
// Algorithm: binary exponentiation (exponentiation by squaring). It walks the
// bits of |n| from least to most significant. Each set bit multiplies r by
// 2^(2^i); squaring `base` after every iteration advances it from 2^(2^i) to
// 2^(2^(i+1)). Total cost is O(log |n|) multiplications.
fn exact_pow2(n: i64) -> f64 {
    // Defensive guard: for n = i64::MIN, -n overflows and stays negative,
    // which would make the loop body never run and return 1.0 incorrectly.
    // Every such n is deep underflow territory, so 0.0 is the correct answer.
    // This also makes n < -1074 explicit rather than relying on denormal
    // rounding inside the loop.
    if n < -1074 { return 0.0; }

    var k = if n < 0 { -n } else { n };
    var base: f64 = if n < 0 { 0.5 } else { 2.0 };
    var r: f64 = 1.0;
    while k > 0 {
        if (k & 1) != 0 {
            r *= base;
        }
        // The last squaring is dead work: `base` is never read again after
        // k reaches 0. It may overflow or underflow, but the poisoned value
        // is discarded, so this is harmless and keeps the loop uniform.
        base *= base;
        k >>= 1;
    }
    r
}


// =============================================================================
// Infinity and NaN
// =============================================================================

// inf returns positive infinity if sign >= 0, else negative infinity.
//
// 0x1p1023 is the largest power of two representable as a finite f64. Doubling
// it produces 2^1024, which exceeds the f64 max finite value, so IEEE 754
// rounds it to +Inf (raising overflow if the FPU reports exceptions).
fn inf(sign: i64) -> f64 {
    let big: f64 = 0x1p1023;
    if sign >= 0 { big * 2.0 } else { -big * 2.0 }
}

// nan returns an IEEE 754 "not-a-number" value.
//
// Inf - Inf is the canonical way to synthesize a quiet NaN without a bitcast:
// IEEE 754 defines it as an invalid operation that produces a qNaN. The exact
// payload and sign bit of the result are architecture-defined, so don't rely
// on float64_bits(nan()) returning any particular pattern.
fn nan() -> f64 {
    let i = inf(1);
    i - i
}

// is_nan reports whether f is an IEEE 754 "not-a-number" value.
// NaN is the only value that compares unequal to itself, under any comparison
// operator; this is the portable, bitcast-free way to test for it.
fn is_nan(f: f64) -> bool {
    f != f
}

// is_inf reports whether f is an infinity, according to sign.
//   sign > 0: +Inf only
//   sign < 0: -Inf only
//   sign == 0: either
// The test compares against +/-MaxFloat64 rather than testing for exact
// equality with a constructed Inf, because NaN compares false to both bounds
// (which is what we want: NaN is not infinity).
fn is_inf(f: f64, sign: i64) -> bool {
    (sign >= 0 && f > MaxFloat64) || (sign <= 0 && f < -MaxFloat64)
}


// =============================================================================
// float -> bits
//
// Both functions rely on bytes_of returning bytes in little-endian order
// (Guaranteed by the language spec, Appendix C.2). No runtime endianness
// check is needed; the loop shifts each byte into its correct position.
// =============================================================================

// float64_bits returns the IEEE 754 binary representation of x as a u64.
fn float64_bits(x: f64) -> u64 {
    let a = [x];
    let b = bytes_of(a);
    var r: u64 = 0;
    for i in 0..8 {
        r |= (b[i] as u64) << (i * 8);
    }
    r
}

// float32_bits returns the IEEE 754 binary representation of x as a u32.
fn float32_bits(x: f32) -> u32 {
    let a = [x];
    let b = bytes_of(a);
    var r: u32 = 0;
    for i in 0..4 {
        r |= (b[i] as u32) << (i * 8);
    }
    r
}


// =============================================================================
// bits -> float
//
// The value is assembled arithmetically in three cases:
//
//   Normal (1 <= e <= 2046): value = (2^52 + m) * 2^(e - 1075)
//                                     = (1 + m/2^52) * 2^(e - 1023)
//     The `2^52` restores the implicit leading 1; the `-1075` combines the
//     IEEE exponent bias (1023) with the mantissa scale (52).
//
//   Subnormal (e == 0): value = m * 2^-1074
//     No implicit leading bit; the exponent is pinned to the minimum normal
//     exponent minus one (1 - 1023 = -1022), and the mantissa supplies the
//     rest. m == 0 gives +/-0.
//
//   Inf/NaN (e == 2047): handled specially. m == 0 is +/-Inf, m != 0 is NaN.
//
// Every intermediate is an integer (<= 2^53 - 1) times a power of two, so
// no rounding happens anywhere in the assembly; the function is exact for
// all 2^64 input bit patterns (modulo NaN payload, see below).
//
// NaN payload caveat: the low 51 bits of a NaN mantissa (bits 51:0 for f64,
// 22:0 for f32) are implementation-defined payload. These functions produce
// a canonical NaN (whatever nan() yields on this machine) and discard any
// incoming payload. Only inf-ness and sign are preserved, which is what all
// IEEE 754 operations require.
// =============================================================================

// float64_frombits returns the float64 with the given IEEE 754 representation.
fn float64_frombits(b: u64) -> f64 {
    let sign = b >> 63;
    let e = ((b >> 52) & 0x7ff) as i64;
    let m = b & 0xfffffffffffff;                       // 52 mantissa bits
    let v: f64 = if e == 0x7ff {
        if m == 0 { inf(1) } else { nan() }
    } else if e == 0 {
        m * 0x1p-1074                         // subnormal (or zero)
    } else {
        (m | (1 << 52)) * exact_pow2(e - 1075) // implicit leading 1
    };
    if sign != 0 { -v } else { v }
}

// float32_frombits returns the float32 with the given IEEE 754 representation.
//
// The value is assembled in f64 first (which has enough precision to hold any
// f32 value exactly), then cast down. The final `as f32` is lossless: every
// finite f32 value is exactly representable in f64, and +/-Inf, NaN, and
// subnormals survive the narrowing cast unchanged.
fn float32_frombits(b: u32) -> f32 {
    let sign = b >> 31;
    let e = ((b >> 23) & 0xff) as i64;
    let m = b & 0x7fffff;                              // 23 mantissa bits
    let v: f64 = if e == 0xff {
        if m == 0 { inf(1) } else { nan() }
    } else if e == 0 {
        m * 0x1p-149                          // subnormal (or zero)
    } else {
        (m | (1 << 23)) * exact_pow2(e - 150)
    };
    let s: f64 = if sign != 0 { -v } else { v };
    s as f32
}


// =============================================================================
// Sign helpers
//
// All three go through float64_bits rather than comparing against 0.0, because
// IEEE 754 distinguishes +0 from -0 by sign bit alone: 0.0 == -0.0, so a
// comparison cannot tell them apart. Only the raw bit pattern can.
// =============================================================================

// signbit reports whether x is negative or negative zero.
// Correctly returns true for -0.0 and for NaNs whose sign bit is set.
fn signbit(x: f64) -> bool {
    (float64_bits(x) >> 63) != 0
}

// abs returns the absolute value of x.
// Special cases:
//   abs(+/-Inf)  = +Inf
//   abs(+/-0.0)  = +0.0      (the == 0.0 arm catches -0.0)
//   abs(NaN)     = NaN       (the else arm returns the input unchanged)
fn abs(x: f64) -> f64 {
    if x < 0.0 {
        -x
    } else if x == 0.0 {
        0.0          // collapses -0.0 to +0.0; +0.0 stays +0.0
    } else {
        x            // positive, +Inf, or NaN
    }
}

// copysign returns a value with the magnitude of f and the sign of sign.
// Equivalent to the IEEE 754 copysign operation. Handles the signed-zero
// case correctly: copysign(0.0, -1.0) = -0.0.
fn copysign(f: f64, sign: f64) -> f64 {
    let a = abs(f);
    if signbit(sign) { -a } else { a }
}

// normalize returns a normal number y and exponent exp satisfying
// x == y * 2**exp. It assumes x is finite and non-zero.
//
// Subnormal inputs are scaled up by 2^52 so that y lands in the normal
// range; the compensating exponent is -52. Normal inputs are returned
// unchanged with exp = 0.
fn normalize(x: f64) -> f64, i64 {
    let SmallestNormal = 2.2250738585072014e-308; // 2^-1022
    if abs(x) < SmallestNormal {
        return x * 0x1p52, -52;
    }
    return x, 0;
}
