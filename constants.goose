// =============================================================================
// Constants used in the terence library
//
// Values mirror Go's math package (https://pkg.go.dev/math). Bit-identical
// reproduction across architectures is not guaranteed: decimal literals are
// rounded to the nearest f64 at parse time, and reciprocal constants (Log2E,
// Log10E) are computed at module initialization rather than hardcoded.
// =============================================================================


// =============================================================================
// Mathematical constants
//
// Each literal carries more digits than an f64 can hold; the compiler rounds
// to the nearest f64, giving the best possible value for that type. OEIS
// links are provided for independent verification.
// =============================================================================

let E   = 2.71828182845904523536028747135266249775724709369995957496696763; // e             https://oeis.org/A001113
let Pi  = 3.14159265358979323846264338327950288419716939937510582097494459; // π             https://oeis.org/A000796
let Phi = 1.61803398874989484820458683436563811772030917980576286213544862; // golden ratio  https://oeis.org/A001622

let Sqrt2   = 1.41421356237309504880168872420969807856967187537694807317667974; // √2   https://oeis.org/A002193
let SqrtE   = 1.64872127070012814684865078781416357165377610071014801157507931; // √e   https://oeis.org/A019774
let SqrtPi  = 1.77245385090551602729816748334114518279754945612238712821380779; // √π   https://oeis.org/A002161
let SqrtPhi = 1.27201964951406896425242246173749149171560804184009624861664038; // √φ   https://oeis.org/A139339

let Ln2  = 0.693147180559945309417232121458176568075500134360255254120680009; // ln(2)   https://oeis.org/A002162
let Ln10 = 2.30258509299404568401799145468436420760110148862877297603332790; // ln(10)  https://oeis.org/A002392

// Reciprocal constants are derived, not hardcoded, so there is only one
// source of truth for each underlying value.
let Log2E  = 1 / Ln2;   // log2(e)  = 1/ln(2)
let Log10E = 1 / Ln10;  // log10(e) = 1/ln(10)


// =============================================================================
// Floating-point limits
//
// Max is the largest finite representable value; SmallestNonzero is the
// smallest positive subnormal (a "denormal").
//
// The Max formulas read as  (2 - 2^-(mantissa bits)) × 2^max_exp :
//   1 + (1 - 2^-23)  =  2 - 2^-23   (mantissa all ones, f32)
//   0x1p127          =  2^127       (max unbiased exponent, f32)
// The SmallestNonzero formulas read as   2^-min_normal_exp × 2^-(mantissa bits):
//   = 2^-149 for f32,   = 2^-1074 for f64.
// mantissa is just the decimal part of a logarithm.
// =============================================================================

let MaxFloat32             = 0x1p127 * (1 + (1 - 0x1p-23));  // ≈ 3.4028234663852886e+38
let SmallestNonzeroFloat32 = 0x1p-126 * 0x1p-23;             // = 2^-149   ≈ 1.401298464324817e-45

let MaxFloat64             = 0x1p1023 * (1 + (1 - 0x1p-52)); // ≈ 1.7976931348623157e+308
let SmallestNonzeroFloat64 = 0x1p-1022 * 0x1p-52;            // = 2^-1074  ≈ 4.9406564584124654e-324


// =============================================================================
// Integer limit values
//
// Goose's `int` is fixed at 64 bits regardless of host architecture, so
// `intSize` is always 64. There is no platform-sized uint.
//
// Two bit tricks are used below:
//   ~0           — bitwise NOT of zero. Under a type annotation, it becomes
//                  the all-ones pattern, i.e. that type's unsigned maximum.
//   (-1) << N    — shift of the all-ones pattern (logical or arithmetic, the
//                  result is identical): the N low bits become 0, giving the
//                  minimum signed value of an (N+1)-bit type.
//
// MinInt uses  -0x7fff... - 1  rather than the literal  -0x8000000000000000
// because 0x8000000000000000 is not representable as a positive i64 and would
// overflow before the negation. The explicit parentheses around `(-1) << N`
// pin down unary-minus vs. shift precedence regardless of parser dialect.
// =============================================================================

let intSize: i64 = 64;
let MaxInt:  i64 =  0x7fffffffffffffff;       //  9223372036854775807   (2^63 - 1)
let MinInt:  i64 = -0x7fffffffffffffff - 1;   // -9223372036854775808   (-2^63)
let MaxUint: u64 = ~0;                        // 18446744073709551615   (2^64 - 1)

// Signed 8/16/32/64-bit bounds (values are stored in i64).
let MaxInt8  = (1 << 7)  - 1;   //            127      (2^7  - 1)
let MinInt8  = (-1) << 7;       //           -128      (-2^7)
let MaxInt16 = (1 << 15) - 1;   //          32767      (2^15 - 1)
let MinInt16 = (-1) << 15;      //         -32768      (-2^15)
let MaxInt32 = (1 << 31) - 1;   //     2147483647      (2^31 - 1)
let MinInt32 = (-1) << 31;      //    -2147483648      (-2^31)
let MaxInt64 = (1 << 63) - 1;   // 9223372036854775807  (2^63 - 1)
let MinInt64 = (-1) << 63;      // -9223372036854775808 (-2^63)

// Unsigned 8/16/32/64-bit bounds. The type annotation is essential: without
// it, ~0 would be inferred as a signed type and yield -1.
let MaxUint8:  u8  = ~0;   //                   255   (2^8  - 1)
let MaxUint16: u16 = ~0;   //                 65535   (2^16 - 1)
let MaxUint32: u32 = ~0;   //            4294967295   (2^32 - 1)
let MaxUint64: u64 = ~0;   // 18446744073709551615   (2^64 - 1)
