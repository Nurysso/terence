import terence from "../../terence";

// =============================================================================
// Helpers
// =============================================================================

// Checks both components of the tuple and the defining invariant
// x == y * 2^exp. Use when the expected y is exactly representable as a
// literal.
fn assert_normalize_exact(x: f64, wantY: f64, wantE: i64) {
    let y, e = normalize(x);
    assert(e == wantE);
    assert(y == wantY);
    assert(y * exact_pow2(e) == x);
}

// Checks exp and invariant, but not an exact y — use when the expected y
// is not worth writing out. Also asserts that y landed in the normal range,
// which is the whole point of the function.
fn assert_normalize_props(x: f64, wantE: i64) {
    let y, e = normalize(x);
    assert(e == wantE);
    assert(y * exact_pow2(e) == x);
    assert(abs(y) >= 2.2250738585072014e-308);   // SmallestNormal
}


// =============================================================================
// Tests
// =============================================================================

fn test_math_constants() {
    assert(E > 2.7);
    assert(E < 2.8);
    assert(Pi > 3.14);
    assert(Pi < 3.15);
    assert(Phi > 1.6);
    assert(Phi < 1.7);
    assert(Sqrt2 > 1.41);
    assert(Sqrt2 < 1.42);
    assert(SqrtE > 1.64);
    assert(SqrtE < 1.65);
    assert(SqrtPi > 1.77);
    assert(SqrtPi < 1.78);
    assert(SqrtPhi > 1.27);
    assert(SqrtPhi < 1.28);
    assert(Ln2 > 0.69);
    assert(Ln2 < 0.70);
    assert(Log2E > 1.44);
    assert(Log2E < 1.45);
    assert(Ln10 > 2.30);
    assert(Ln10 < 2.31);
    assert(Log10E > 0.43);
    assert(Log10E < 0.44);
}

fn test_float_limits() {
    assert(MaxFloat32 > 0.0);
    assert(SmallestNonzeroFloat32 > 0.0);
    assert(SmallestNonzeroFloat32 < MaxFloat32);
    assert(MaxFloat64 > 0.0);
    assert(SmallestNonzeroFloat64 > 0.0);
    assert(SmallestNonzeroFloat64 < MaxFloat64);
}

fn test_int_limits() {
    assert(MaxInt > MinInt);
    assert(MaxInt8 > MinInt8);
    assert(MaxInt16 > MinInt16);
    assert(MaxInt32 > MinInt32);
    assert(MaxInt64 > MinInt64);
    assert(MaxUint8 > 0);
    assert(MaxUint16 > 0);
    assert(MaxUint32 > 0);

    // MaxUint and MaxUint64 have the high bit set. A bare `> 0` promotes
    // the comparison to i64, where the value reads as -1 — so the original
    // `assert(MaxUint > 0)` fails. Test nonzero-ness instead.
    assert(MaxUint   != 0);
    assert(MaxUint64 != 0);
    assert((MaxUint   as i64) < 0);
    assert((MaxUint64 as i64) < 0);
}

fn test_exact_pow2() {
    // ---- Spot checks (readability when something breaks) ----
    assert(exact_pow2(0)    == 1.0);
    assert(exact_pow2(1)    == 2.0);
    assert(exact_pow2(2)    == 4.0);
    assert(exact_pow2(10)   == 1024.0);
    assert(exact_pow2(-1)   == 0.5);
    assert(exact_pow2(-2)   == 0.25);
    assert(exact_pow2(200)  == 0x1p200);
    assert(exact_pow2(1023) == 0x1p1023);
    assert(exact_pow2(-1074) == 0x1p-1074);

    // ---- Overflow and underflow ----
    assert(exact_pow2(1024) == inf(1));
    assert(exact_pow2(2000) == inf(1));
    assert(exact_pow2(MaxInt64) == inf(1));

    assert(exact_pow2(-1075) == 0.0);
    assert(exact_pow2(-5000) == 0.0);
    assert(!signbit(exact_pow2(-1075)));   // +0, not -0

    // ---- i64::MIN overflow guard ----
    // These three would all return 1.0 without the `if n < -1074` guard,
    // because -n overflows back to a negative value and the loop never runs.
    assert(exact_pow2(MinInt64)     == 0.0);
    assert(exact_pow2(MinInt64 + 1) == 0.0);
    assert(exact_pow2(MinInt64 / 2) == 0.0);

    // ---- Exhaustive over the normal range ----
    // 2^n for -1022 <= n <= 1023 has bit pattern ((n + 1023) << 52).
    // Catches any off-by-one in the bias, and proves zero rounding.
    for n in -1022..1023 {
        let want: u64 = ((n + 1023) as u64) << 52;
        assert(float64_bits(exact_pow2(n)) == want);
    }

    // ---- Exhaustive over the subnormal range ----
    // 2^n for -1074 <= n <= -1023 has bit pattern (1 << (n + 1074)).
    // Proves the subnormal arm works all the way down to the smallest
    // representable power of two.
    for n in -1074..-1023 {
        let want: u64 = (1 as u64) << (n + 1074);
        assert(float64_bits(exact_pow2(n)) == want);
    }
}

fn test_float64_bits() {
    // ---- Simple patterns ----
    assert(float64_bits(1.0)  == 0x3ff0000000000000);
    assert(float64_bits(-1.0) == 0xbff0000000000000);
    assert(float64_bits(2.0)  == 0x4000000000000000);
    assert(float64_bits(-2.0) == 0xc000000000000000);
    assert(float64_bits(0.5)  == 0x3fe0000000000000);

    // ---- Signed zero ----
    assert(float64_bits(0.0)  == 0x0000000000000000);
    assert(float64_bits(-0.0) == 0x8000000000000000);

    // ---- Non-palindromic pattern catches big-endian bugs ----
    // π's bits are 0x400921fb54442d18; a byte-swapped read would give
    // 0x182d4454fb210940, so this single test rules out endianness errors.
    assert(float64_bits(Pi) == 0x400921fb54442d18);

    // ---- Subnormal / boundary patterns ----
    assert(float64_bits(SmallestNonzeroFloat64) == 1);            // 2^-1074
    assert(float64_bits(0x1p-1022) == 0x0010000000000000);        // smallest normal
    assert(float64_bits(MaxFloat64) == 0x7fefffffffffffff);

    // ---- Infinities ----
    assert(float64_bits(inf(1))  == 0x7ff0000000000000);
    assert(float64_bits(inf(-1)) == 0xfff0000000000000);

    // ---- NaN: only assert that the produced pattern IS a NaN pattern,
    //      not a specific payload. A NaN bit pattern has exponent = 0x7ff
    //      and a nonzero mantissa; the sign bit is implementation-defined.
    let nanBits = float64_bits(nan());
    assert((nanBits >> 52) & 0x7ff == 0x7ff);
    assert(nanBits & 0x000fffffffffffff != 0);
}

fn test_float32_bits() {
    // ---- Simple patterns ----
    assert(float32_bits(1.0)  == 0x3f800000);
    assert(float32_bits(-1.0) == 0xbf800000);
    assert(float32_bits(2.0)  == 0x40000000);
    assert(float32_bits(-2.0) == 0xc0000000);
    assert(float32_bits(0.5)  == 0x3f000000);

    // ---- Signed zero ----
    assert(float32_bits(0.0)  == 0x00000000);
    assert(float32_bits(-0.0) == 0x80000000);

    // ---- Non-palindromic pattern: π rounded to f32 ----
    // 0x40490fdb byte-reversed is 0xdb0f4940; if this assertion passes,
    // byte order in float32_bits is correct.
    assert(float32_bits(Pi) == 0x40490fdb);

    // ---- Boundaries ----
    assert(float32_bits(SmallestNonzeroFloat32) == 1);           // 2^-149
    assert(float32_bits(MaxFloat32) == 0x7f7fffff);

    // ---- Infinities ----
    assert(float32_bits(inf(1) as f32)  == 0x7f800000);
    assert(float32_bits(inf(-1) as f32) == 0xff800000);
}

fn test_float64_frombits() {
    // ---- Well-known constants ----
    assert(float64_frombits(0x3ff0000000000000) == 1.0);
    assert(float64_frombits(0xbff0000000000000) == -1.0);
    assert(float64_frombits(0xc000000000000000) == -2.0);
    assert(float64_frombits(0x3fe0000000000000) == 0.5);
    assert(float64_frombits(0x400921fb54442d18) == Pi);

    // ---- Signed zero: must come back as ±0 with the right sign ----
    assert(float64_frombits(0)                  == 0.0);
    assert(!signbit(float64_frombits(0)));
    assert(float64_frombits(0x8000000000000000) == 0.0);
    assert(signbit(float64_frombits(0x8000000000000000)));

    // ---- Subnormal / normal boundary ----
    assert(float64_frombits(1)                    == 0x1p-1074);  // smallest subnormal
    assert(float64_frombits(0x000fffffffffffff)   == 0x1.ffffffffffffep-1023); // this failed
    assert(float64_frombits(0x0010000000000000)   == 0x1p-1022);  // smallest normal
    assert(float64_frombits(0x0010000000000001)   == 0x1.0000000000001p-1022);

    // ---- Max finite value ----
    assert(float64_frombits(0x7fefffffffffffff) == MaxFloat64);

    // ---- Infinities ----
    assert(float64_frombits(0x7ff0000000000000) == inf(1));
    assert(float64_frombits(0xfff0000000000000) == inf(-1));

    // ---- NaN: multiple patterns must all be NaN, payload ignored ----
    assert(is_nan(float64_frombits(0x7ff0000000000001)));   // smallest positive NaN
    assert(is_nan(float64_frombits(0x7ff8000000000000)));   // canonical qNaN
    assert(is_nan(float64_frombits(0x7fffffffffffffff)));   // all mantissa bits set
    assert(is_nan(float64_frombits(0xfff0000000000001)));   // negative NaN
    assert(is_nan(float64_frombits(0xfff8000000000000)));

    // ---- Negative subnormal ----
    assert(float64_frombits(0x8000000000000001) == -0x1p-1074);
}

fn test_float32_frombits() {
    // ---- Well-known constants ----
    assert(float32_frombits(0x3f800000) == 1.0);
    assert(float32_frombits(0xbf800000) == -1.0);
    assert(float32_frombits(0xc0000000) == -2.0);
    assert(float32_frombits(0x3f000000) == 0.5);
    assert(float32_frombits(0x40490fdb) == Pi);

    // ---- Signed zero ----
    assert(float32_frombits(0)          == 0.0);
    assert(!signbit(float32_frombits(0)));
    assert(float32_frombits(0x80000000) == 0.0);
    assert(signbit(float32_frombits(0x80000000) ));

    // ---- Subnormal / normal boundary (for f32) ----
    assert(float32_frombits(1)          == 0x1p-149);   // smallest subnormal
    assert(float32_frombits(0x007fffff) == 0x1.fffffcp-127); // this failed
    assert(float32_frombits(0x00800000) == 0x1p-126);   // smallest normal
    assert(float32_frombits(0x00800001) == 0x1.000002p-126);

    // ---- Max finite ----
    assert(float32_frombits(0x7f7fffff) == MaxFloat32);

    // ---- Infinities ----
    assert(float32_frombits(0x7f800000) == inf(1));
    assert(float32_frombits(0xff800000) == inf(-1));

    // ---- NaN: multiple patterns ----
    assert(is_nan(float32_frombits(0x7f800001)));
    assert(is_nan(float32_frombits(0x7fc00000)));
    assert(is_nan(float32_frombits(0x7fffffff)));
    assert(is_nan(float32_frombits(0xffc00000)));

    // ---- Negative subnormal ----
    assert(float32_frombits(0x80000001) == -0x1p-149);
}

fn test_inf_nan() {
    // ---- inf: bit patterns must match IEEE 754 exactly ----
    assert(float64_bits(inf(1))  == 0x7ff0000000000000);
    assert(float64_bits(inf(-1)) == 0xfff0000000000000);
    // sign == 0 takes the positive branch (sign >= 0)
    assert(float64_bits(inf(0))  == 0x7ff0000000000000);
    assert(inf(0) == inf(1));

    // ---- is_inf: all sign/finite/inf combinations ----
    assert(is_inf(inf(1),  1));
    assert(is_inf(inf(-1), -1));
    assert(is_inf(inf(1),  0));
    assert(is_inf(inf(-1),  0));
    assert(!is_inf(inf(1),  -1));      // +Inf is not -Inf
    assert(!is_inf(inf(-1),  1));      // -Inf is not +Inf
    assert(!is_inf(1.0,     0));       // finite is never Inf
    assert(!is_inf(0.0,     0));
    assert(!is_inf(MaxFloat64,  0));   // just below +Inf
    assert(!is_inf(-MaxFloat64, 0));

    // ---- nan / is_nan ----
    assert(is_nan(nan()));
    assert(!is_nan(1.0));
    assert(!is_nan(0.0));
    assert(!is_nan(inf(1)));
    assert(!is_nan(inf(-1)));
    // NaN is the only value that fails x == x
    assert(nan() != nan());

    // ---- is_inf must reject NaN (a NaN compares false to both bounds) ----
    assert(!is_inf(nan(),  0));
    assert(!is_inf(nan(),  1));
    assert(!is_inf(nan(), -1));

    // ---- Arithmetic identities from IEEE 754 ----
    // Inf - Inf = NaN, Inf + Inf = Inf, Inf * 0 = NaN
    assert(is_nan(inf(1) - inf(1)));
    assert(inf(1) + inf(1) == inf(1));
    assert(is_nan(inf(1) * 0.0));
    // Inf + finite = Inf
    assert(inf(1) + 1.0 == inf(1));
    // signbit of a NaN constructed from Inf - Inf may be either 0 or 1
    // depending on the platform; don't test it.
}

fn test_signbit_abs_copysign() {
    assert(signbit(-1.0));
    assert(signbit(-0.0));
    assert(!signbit(0.0));
    assert(!signbit(5.0));
    assert(abs(-3.5) == 3.5);
    assert(abs(3.5) == 3.5);
    assert(!signbit(abs(-0.0)));
    assert(abs(inf(-1)) == inf(1));
    assert(is_nan(abs(nan())));
    assert(copysign(3.0, -1.0) == -3.0);
    assert(copysign(-3.0, 1.0) == 3.0);
    assert(signbit(copysign(0.0, -1.0)));
}

fn test_roundtrip_bits() {
    let samples = [1.5, -3.75, 1e-300, 1e300, 123456.789, 0x1p-1060, 0x1p1000];
    for x in samples {
        assert(float64_frombits(float64_bits(x)) == x);
    }
}

fn test_normalize() {
    let SmallestNormal = 2.2250738585072014e-308;   // 2^-1022

    // -------------------------------------------------------------------------
    // Normal inputs — returned unchanged, exp = 0
    // -------------------------------------------------------------------------
    assert_normalize_exact(1.0,  1.0,  0);
    assert_normalize_exact(2.0,  2.0,  0);
    assert_normalize_exact(0.5,  0.5,  0);
    assert_normalize_exact(10.0, 10.0, 0);
    assert_normalize_exact(-1.0, -1.0, 0);
    assert_normalize_exact(-2.5, -2.5, 0);
    assert_normalize_exact(Pi, Pi, 0);
    assert_normalize_exact(3.1415926535897932, 3.141592653589793, 0);
    assert_normalize_exact(MaxFloat64, MaxFloat64, 0);

    // -------------------------------------------------------------------------
    // Boundary: exactly SmallestNormal — must NOT be normalized
    //
    // The condition is `abs(x) < SmallestNormal`, strictly less. Equality
    // must take the trivial branch. This is the last "normal" input and the
    // first input where a <= would silently corrupt the answer.
    // -------------------------------------------------------------------------
    assert_normalize_exact(SmallestNormal, SmallestNormal, 0);

    // -------------------------------------------------------------------------
    // Subnormal inputs — scaled up by exactly 2^52, exp = -52
    // -------------------------------------------------------------------------

    // Smallest subnormal (2^-1074). Scaling gives exactly SmallestNormal.
    // This is the strongest "known-value" check for the subnormal branch:
    // both x and y have closed-form bit patterns, so any wrong multiplier
    // (2^51, 2^53, 2^60) is caught immediately.
    assert_normalize_exact(SmallestNonzeroFloat64, SmallestNormal, -52);

    // Largest subnormal: bit pattern 0x000FFFFFFFFFFFFF, value
    // (2^52 - 1) * 2^-1074 ≈ 2^-1022. Scaling by 2^52 gives
    // (2^52 - 1) * 2^-1022, which is normal. Exact y is awkward to write;
    // the invariant + normal-range check is the right test.
    let largestSubnormal = float64_frombits(0x000FFFFFFFFFFFFF);
    assert_normalize_props(largestSubnormal, -52);

    // A generic subnormal in the middle of the range (≈ 2^-1030).
    // Checks the multiplier is exactly 2^52, not something near it.
    assert_normalize_exact(1e-310, 1e-310 * 0x1p52, -52);

    // Negative subnormal — sign must be preserved, not dropped.
    assert_normalize_exact(-1e-310,             -1e-310 * 0x1p52, -52);
    assert_normalize_exact(-SmallestNonzeroFloat64, -SmallestNormal, -52);

    // Subnormal just below the boundary — smallest step from SmallestNormal.
    // Value: (2^52 - 1) * 2^-1074. Using the bit pattern guarantees we're
    // exactly one ULP below SmallestNormal, not a decimal approximation.
    let justBelowBoundary = float64_frombits(0x000FFFFFFFFFFFFF);
    assert_normalize_props(justBelowBoundary, -52);

    // -------------------------------------------------------------------------
    // Round-trip invariant, tested on a sweep of inputs at every scale
    //
    // For every finite non-zero x, y * 2^e must reproduce x exactly.
    // Sweep a log-spaced selection so we cross normal, boundary, and
    // subnormal regions.
    // -------------------------------------------------------------------------
    let sweep = [
        1e-320, 1e-315, 1e-310, 1e-308,   // subnormal band
        2.3e-308,                          // straddles SmallestNormal
        1e-307, 1e-300, 1e-100,            // normal, low
        1.0, Pi, 1e100, 1e300, MaxFloat64, // normal, mid + high
        -1e-320, -1e-310, -1e-308,         // negative subnormal
        -1.0, -Pi, -1e300, -MaxFloat64,    // negative normal
    ];
    for x in sweep {
        let y, e = normalize(x);
        assert(y * exact_pow2(e) == x);
    }

    print("test_normalize: all tests passed\n");
}

fn main() {
    test_math_constants();
    test_float_limits();
    test_int_limits();
    test_exact_pow2();
    test_float64_bits();
    test_float32_bits();
    test_float64_frombits();
    test_float32_frombits();
    test_inf_nan();
    test_signbit_abs_copysign();
    test_roundtrip_bits();
    test_normalize();
    print("tests.goose: all tests passed\n");
}
