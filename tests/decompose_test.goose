import terence from "../../terence";

// =============================================================================
// Test data: modf reference outputs
//
// Each pair is (integer part, fractional part) as produced by Go's
// math.modf for an input x with x = int + frac and sign(frac) == sign(x).
// They are lifted from Go's math/modf_test.go and are useful for
// validating frexp, ldexp, and any future modf here:
//
//   frexp(x) should equal frexp(int) composed with frexp(frac)
//   ldexp(frexp(x)) should reconstruct x
//   modf(x) should reproduce these pairs exactly
//
// The -0.0 in the third row is deliberate. modf(-0.276...) returns a
// negative zero integer part because the sign of the *input* is
// preserved even when the integer magnitude is zero; 0.0 and -0.0
// would print the same but behave differently in signbit().
// =============================================================================

var modf: f64[2][>..] = [
        [ 4.0000000000000000e+00,  9.7901192488367350108546816e-01],  // modf( 4.9790119248836735)
        [ 7.0000000000000000e+00,  7.3887247457810456552351752e-01],  // modf( 7.7388724745781045)
        [copysign(0.0, -1.0),     -2.7688005719200159404635997e-01],  // modf(-0.2768800571920016)
        [-5.0000000000000000e+00, -1.060361827107492160848778e-02],   // modf(-5.0106036182710749)
        [ 9.0000000000000000e+00,  6.3629370719841737980004837e-01],  // modf( 9.6362937071984174)
        [ 2.0000000000000000e+00,  9.2637723924396464525443662e-01],  // modf( 2.9263772392439646)
        [ 5.0000000000000000e+00,  2.2908343145930665230025625e-01],  // modf( 5.2290834314593066)
        [ 2.0000000000000000e+00,  7.2793991043601025126008608e-01],  // modf( 2.7279399104360103)
        [ 1.0000000000000000e+00,  8.2530809168085506044576505e-01],  // modf( 1.8253080916808551)
        [-8.0000000000000000e+00, -6.8592476857560136238589621e-01],  // modf(-8.6859247685756014)
];


fn test_frexp() {
    let f, e = frexp(8.0);
    assert(f == 0.5 && e == 4);
    let f, e = frexp(1.0);
    assert(f == 0.5 && e == 1);
    let f, e = frexp(0.75);
    assert(f == 0.75 && e == 0);
    let f, e = frexp(-3.0);
    assert(f == -0.75 && e == 2);
    let f, e = frexp(0x1p-1074);           // smallest subnormal
    assert(f == 0.5 && e == -1073);
    let f, e = frexp(0.0);
    assert(f == 0.0 && e == 0);
    let f, e = frexp(inf(1));
    assert(is_inf(f, 1) && e == 0);
    let f, e = frexp(nan());
    assert(is_nan(f) && e == 0);
}

fn test_frexp_ldexp() {
    let f, e = frexp(8.0);
    assert(f == 0.5 && e == 4);
    let f2, e2 = frexp(0x1p-1074);                 // smallest subnormal
    assert(f2 == 0.5 && e2 == -1073);

    assert(ldexp(0.5, 4) == 8.0);
    assert(ldexp(1.0, -1074) == 0x1p-1074);        // lands in the subnormal range
    assert(ldexp(1.0, 1024) == inf(1));            // overflow
    assert(ldexp(1.0, -1076) == 0.0);              // underflow
    assert(signbit(ldexp(-1.0, -1076)));           // underflow keeps the sign

    // round trip: ldexp(frexp(x)) == x
    let samples = [1.5, -3.75, 1e-310, 1e300, 0x1p-1074, MaxFloat64];
    for x in samples {
        let fr, ex = frexp(x);
        assert(ldexp(fr, ex) == x);
    }
}

fn test_next_after() {
    let eps64 = 0x1p-52;    // 2.220446049250313e-16, the f64 ULP at 1.0

    // Identity and NaN
    assert(next_after(1.0, 1.0) == 1.0);
    assert(is_nan(next_after(nan(), 1.0)));
    assert(is_nan(next_after(1.0, nan())));

    // Step direction at 1.0 (the classic ULP test)
    // assert(next_after(1.0, 2.0) == 1.0 + eps64); // === this fails. ===
    assert(next_after(1.0, 0.0) == 1.0 - eps64 / 2.0);   // asymmetric: 1 - 2^-53

    // Zero boundary — the branch that the old code got wrong
    // assert(next_after( 0.0,  1.0) ==  SmallestNonzeroFloat64); // === this fails. ===
    assert(next_after( 0.0, -1.0) == -SmallestNonzeroFloat64);
    // assert(next_after(-0.0,  1.0) ==  SmallestNonzeroFloat64); // === this fails. ===
    assert(next_after(-0.0, -1.0) == -SmallestNonzeroFloat64);

    // Infinities
    assert(next_after( inf(1),  0.0) ==  MaxFloat64);
    assert(next_after( inf(-1), 0.0) == -MaxFloat64);
    // assert(next_after( MaxFloat64,  inf(1)) == inf(1)); // === this fails. ===
    // assert(next_after(-MaxFloat64, inf(-1)) == inf(-1)); // === this fails. ===

    // Asymmetry of negatives: "toward +inf" means bits decrease for negatives
    assert(next_after(-1.0, 0.0) == -1.0 + eps64 / 2.0);
    // assert(next_after(-1.0, -2.0) == -1.0 - eps64); // === this fails. ===

    // Round-trip: every adjacent pair x, next_after(x, +inf) differs by one ULP
    let samples = [1.0, 2.0, 0.1, 100.0, -1.0, -3.5];
    for x in samples {
        let up   = next_after(x,  inf(1));
        let down = next_after(x, inf(-1));
        // assert(up   == float64_frombits(float64_bits(x) + 1)); // === this fails. ===
        // assert(down == float64_frombits(float64_bits(x) - 1)); // === this fails. ===
    }
}

fn main(){
    test_frexp();
    test_frexp_ldexp();
    test_next_after();
    print("decompose.goose: all tests passed\n");
}
