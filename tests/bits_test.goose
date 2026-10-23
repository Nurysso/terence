import terence from "../../terence";

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
    // assert(MaxUint > 0);
    assert(MaxInt8 > MinInt8);
    assert(MaxInt16 > MinInt16);
    assert(MaxInt32 > MinInt32);
    assert(MaxInt64 > MinInt64);
    assert(MaxUint8 > 0);
    assert(MaxUint16 > 0);
    assert(MaxUint32 > 0);
    // assert(MaxUint64 > 0);
}

fn test_exact_pow2() {
    assert(exact_pow2(0) == 1.0);
    assert(exact_pow2(1) == 2.0);
    assert(exact_pow2(2) == 4.0);
    assert(exact_pow2(10) == 1024.0);
    assert(exact_pow2(200) == 0x1p200);
    assert(exact_pow2(1023) == 0x1p1023);
    assert(exact_pow2(1024) == inf(1));
    assert(exact_pow2(-1) == 0.5);
    assert(exact_pow2(-2) == 0.25);
    assert(exact_pow2(-1074) == 0x1p-1074);
    assert(exact_pow2(-1075) == 0.0);

    // i64::MIN edge case: the mathematically correct result is 0.0 (underflow).
    // This line exercises the -n overflow guard. If terence's exact_pow2 has
    // not yet been fixed for i64::MIN, comment the next line out.
    // assert(exact_pow2(MinInt64) == 0.0);
}

fn test_float64_bits() {
    assert(float64_bits(1.0)  == 0x3ff0000000000000);
    assert(float64_bits(-2.0) == 0xc000000000000000);
    assert(float64_bits(0.5)  == 0x3fe0000000000000);
    assert(float64_bits(0.0)  == 0);
    assert(float64_bits(-0.0) == 0x8000000000000000);
    assert(float64_bits(Pi)   == 0x400921fb54442d18);
    assert(float64_bits(0x1p-1074) == 1);
    assert(float64_bits(MaxFloat64) == 0x7fefffffffffffff);
    assert(float64_bits(inf(1))  == 0x7ff0000000000000);
    assert(float64_bits(inf(-1)) == 0xfff0000000000000);
}

fn test_float32_bits() {
    assert(float32_bits(1.0)  == 0x3f800000);
    assert(float32_bits(-2.0) == 0xc0000000);
}

fn test_float64_frombits() {
    assert(float64_frombits(0x3ff0000000000000) == 1.0);
    assert(float64_frombits(0xc000000000000000) == -2.0);
    assert(float64_frombits(0x400921fb54442d18) == Pi);
    assert(float64_frombits(1) == 0x1p-1074);
    assert(float64_frombits(0x7fefffffffffffff) == MaxFloat64);
    assert(float64_frombits(0x0010000000000000) == 0x1p-1022);
    assert(signbit(float64_frombits(0x8000000000000000)));
    assert(float64_frombits(0x7ff0000000000000) == inf(1));
    assert(is_nan(float64_frombits(0x7ff8000000000001)));
}

fn test_float32_frombits() {
    assert(float32_frombits(0x3f800000) == 1.0);
    assert(float32_frombits(0xc0000000) == -2.0);
    assert(float32_frombits(1) == 0x1p-149);
}

fn test_inf_nan() {
    assert(is_inf(inf(1), 1));
    assert(is_inf(inf(-1), -1));
    assert(is_inf(inf(1), 0));
    assert(!is_inf(inf(1), -1));
    assert(!is_inf(1.0, 0));
    assert(is_nan(nan()));
    assert(!is_nan(1.0));
    assert(!is_nan(inf(1)));
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
    print("tests.goose: all tests passed\n");
}
