import terence from "../../terence";

fn main() {
    print("--- Mathematical constants ---\n");
    print("E       = ", E);
    print("Pi      = ", Pi);
    print("Phi     = ", Phi);
    print("Sqrt2   = ", Sqrt2);
    print("SqrtE   = ", SqrtE);
    print("SqrtPi  = ", SqrtPi);
    print("SqrtPhi = ", SqrtPhi);
    print("Ln2     = ", Ln2);
    print("Log2E   = ", Log2E);
    print("Ln10    = ", Ln10);
    print("Log10E  = ", Log10E);

    print("\n--- Floating-point limits ---\n");
    print("MaxFloat32             = ", MaxFloat32);
    print("SmallestNonzeroFloat32 = ", SmallestNonzeroFloat32);
    print("MaxFloat64             = ", MaxFloat64);
    print("SmallestNonzeroFloat64 = ", SmallestNonzeroFloat64);

    print("\n--- Integer limits ---\n");
    print("intSize   = ", intSize);
    print("MaxInt    = ", MaxInt);
    print("MinInt    = ", MinInt);
    print("MaxUint   = ", MaxUint);

    print("MaxInt8   = ", MaxInt8);
    print("MinInt8   = ", MinInt8);
    print("MaxInt16  = ", MaxInt16);
    print("MinInt16  = ", MinInt16);
    print("MaxInt32  = ", MaxInt32);
    print("MinInt32  = ", MinInt32);
    print("MaxInt64  = ", MaxInt64);
    print("MinInt64  = ", MinInt64);

    print("MaxUint8  = ", MaxUint8);
    print("MaxUint16 = ", MaxUint16);
    print("MaxUint32 = ", MaxUint32);
    print("MaxUint64 = ", MaxUint64);

    print("\n--- exact_pow2 ---\n");
    print("exact_pow2(0)     = ", exact_pow2(0));
    print("exact_pow2(1)     = ", exact_pow2(1));
    print("exact_pow2(10)    = ", exact_pow2(10));
    print("exact_pow2(200)   = ", exact_pow2(200));
    print("exact_pow2(1023)  = ", exact_pow2(1023));
    print("exact_pow2(1024)  = ", exact_pow2(1024));
    print("exact_pow2(-1)    = ", exact_pow2(-1));
    print("exact_pow2(-1074) = ", exact_pow2(-1074));
    print("exact_pow2(-1075) = ", exact_pow2(-1075));

    print("\n--- float64_bits ---\n");
    print("float64_bits(1.0)       = ", float64_bits(1.0));
    print("float64_bits(-2.0)      = ", float64_bits(-2.0));
    print("float64_bits(0.5)       = ", float64_bits(0.5));
    print("float64_bits(0.0)       = ", float64_bits(0.0));
    print("float64_bits(-0.0)      = ", float64_bits(-0.0));
    print("float64_bits(Pi)        = ", float64_bits(Pi));
    print("float64_bits(0x1p-1074) = ", float64_bits(0x1p-1074));
    print("float64_bits(MaxFloat64)= ", float64_bits(MaxFloat64));
    print("float64_bits(inf(1))    = ", float64_bits(inf(1)));
    print("float64_bits(inf(-1))   = ", float64_bits(inf(-1)));

    print("\n--- float32_bits ---\n");
    print("float32_bits(1.0)  = ", float32_bits(1.0));
    print("float32_bits(-2.0) = ", float32_bits(-2.0));

    print("\n--- float64_frombits ---\n");
    print("float64_frombits(0x3ff0000000000000) = ", float64_frombits(0x3ff0000000000000));
    print("float64_frombits(0xc000000000000000) = ", float64_frombits(0xc000000000000000));
    print("float64_frombits(0x400921fb54442d18) = ", float64_frombits(0x400921fb54442d18));
    print("float64_frombits(1)                  = ", float64_frombits(1));
    print("float64_frombits(0x7fefffffffffffff) = ", float64_frombits(0x7fefffffffffffff));
    print("float64_frombits(0x0010000000000000) = ", float64_frombits(0x0010000000000000));

    print("\n--- float32_frombits ---\n");
    print("float32_frombits(0x3f800000) = ", float32_frombits(0x3f800000));
    print("float32_frombits(0xc0000000) = ", float32_frombits(0xc0000000));
    print("float32_frombits(1)          = ", float32_frombits(1));

    print("\n--- inf / nan ---\n");
    print("inf(1)              = ", inf(1));
    print("inf(-1)             = ", inf(-1));
    print("nan()               = ", nan());
    print("is_inf(inf(1), 1)   = ", is_inf(inf(1), 1));
    print("is_inf(inf(-1), -1) = ", is_inf(inf(-1), -1));
    print("is_inf(inf(1), 0)   = ", is_inf(inf(1), 0));
    print("is_inf(1.0, 0)      = ", is_inf(1.0, 0));
    print("is_nan(nan())       = ", is_nan(nan()));
    print("is_nan(1.0)         = ", is_nan(1.0));
    print("is_nan(inf(1))      = ", is_nan(inf(1)));

    print("\n--- signbit / abs / copysign ---\n");
    print("signbit(-1.0)                = ", signbit(-1.0));
    print("signbit(-0.0)                = ", signbit(-0.0));
    print("signbit(0.0)                 = ", signbit(0.0));
    print("signbit(5.0)                 = ", signbit(5.0));
    print("abs(-3.5)                    = ", abs(-3.5));
    print("abs(3.5)                     = ", abs(3.5));
    print("abs(-0.0)                    = ", abs(-0.0));
    print("abs(inf(-1))                 = ", abs(inf(-1)));
    print("abs(nan())                   = ", abs(nan()));
    print("copysign(3.0, -1.0)          = ", copysign(3.0, -1.0));
    print("copysign(-3.0, 1.0)          = ", copysign(-3.0, 1.0));
    print("copysign(0.0, -1.0)          = ", copysign(0.0, -1.0));
    print("signbit(copysign(0.0, -1.0)) = ", signbit(copysign(0.0, -1.0)));

    print("\nmain.goose: done\n");
}
