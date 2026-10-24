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

const E   = 2.71828182845904523536028747135266249775724709369995957496696763; // e             https://oeis.org/A001113
const Pi  = 3.14159265358979323846264338327950288419716939937510582097494459; // π             https://oeis.org/A000796
const Phi = 1.61803398874989484820458683436563811772030917980576286213544862; // golden ratio  https://oeis.org/A001622

const Sqrt2   = 1.41421356237309504880168872420969807856967187537694807317667974; // √2   https://oeis.org/A002193
const SqrtE   = 1.64872127070012814684865078781416357165377610071014801157507931; // √e   https://oeis.org/A019774
const SqrtPi  = 1.77245385090551602729816748334114518279754945612238712821380779; // √π   https://oeis.org/A002161
const SqrtPhi = 1.27201964951406896425242246173749149171560804184009624861664038; // √φ   https://oeis.org/A139339

const Ln2  = 0.693147180559945309417232121458176568075500134360255254120680009; // ln(2)   https://oeis.org/A002162
const Ln10 = 2.30258509299404568401799145468436420760110148862877297603332790; // ln(10)  https://oeis.org/A002392

// Reciprocal constants are derived, not hardcoded, so there is only one
// source of truth for each underlying value.
const Log2E  = 1 / Ln2;   // log2(e)  = 1/ln(2)
const Log10E = 1 / Ln10;  // log10(e) = 1/ln(10)


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

const MaxFloat32             = 0x1p127 * (1 + (1 - 0x1p-23));  // ≈ 3.4028234663852886e+38
const SmallestNonzeroFloat32 = 0x1p-126 * 0x1p-23;             // = 2^-149   ≈ 1.401298464324817e-45

const MaxFloat64             = 0x1p1023 * (1 + (1 - 0x1p-52)); // ≈ 1.7976931348623157e+308
const SmallestNonzeroFloat64 = 0x1p-1022 * 0x1p-52;            // = 2^-1074  ≈ 4.9406564584124654e-324


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

const intSize: i64 = 64;
const MaxInt:  i64 =  0x7fffffffffffffff;       //  9223372036854775807   (2^63 - 1)
const MinInt:  i64 = -0x7fffffffffffffff - 1;   // -9223372036854775808   (-2^63)
const MaxUint: u64 = ~0;                        // 18446744073709551615   (2^64 - 1)

// Signed 8/16/32/64-bit bounds (values are stored in i64).
const MaxInt8  = (1 << 7)  - 1;   //            127      (2^7  - 1)
const MinInt8  = (-1) << 7;       //           -128      (-2^7)
const MaxInt16 = (1 << 15) - 1;   //          32767      (2^15 - 1)
const MinInt16 = (-1) << 15;      //         -32768      (-2^15)
const MaxInt32 = (1 << 31) - 1;   //     2147483647      (2^31 - 1)
const MinInt32 = (-1) << 31;      //    -2147483648      (-2^31)
const MaxInt64 = (1 << 63) - 1;   // 9223372036854775807  (2^63 - 1)
const MinInt64 = (-1) << 63;      // -9223372036854775808 (-2^63)

// Unsigned 8/16/32/64-bit bounds. The type annotation is essential: without
// it, ~0 would be inferred as a signed type and yield -1.
const MaxUint8:  u8  = ~0;   //                   255   (2^8  - 1)
const MaxUint16: u16 = ~0;   //                 65535   (2^16 - 1)
const MaxUint32: u32 = ~0;   //            4294967295   (2^32 - 1)
const MaxUint64: u64 = ~0;   // 18446744073709551615   (2^64 - 1)


// =============================================================================
// Bit-field accessors
//
// Extracting the exponent field and re-inserting it are the only two bit
// operations every decomposition function needs. Factoring them out keeps
// the higher-level functions focused on *what* they compute rather than
// *how* they move bits around.
// =============================================================================

// F64_BIAS is added to the true (mathematically meaningful) exponent before
// it is stored in the exponent field. Biasing makes the stored exponent an
// unsigned non-negative integer, which is the trick that lets IEEE 754
// compare floats using integer comparison on their bit patterns: a larger
// float has a larger biased exponent, and same-exponent floats differ only
// in the mantissa, which sits at the low end of the integer. That property
// is why NaN and Inf can be ordered at the very top and negative numbers
// have the sign bit set — the layout is monotonic.
//
// 1023 = (2^11 / 2) - 1, i.e. half of the 2048 possible exponent values.
// Biasing by half puts normal exponents symmetrically around zero:
// stored 1 maps to -1022 (smallest normal), stored 2046 maps to +1023
// (largest finite), stored 2047 is reserved for Inf/NaN.
let F64_BIAS:  i64 = 1023;

// F64_MASK covers exactly the exponent field: 11 bits, all set. Used to
// peel the exponent out of a bit pattern after shifting it down, and to
// clear the field in place before writing a new one.
let F64_MASK:  u64 = 0x7ff; // This is just hexaDecimal value for Eleven 1-bits (11111111111).

// F64_SHIFT is the width of the mantissa (52 bits). The exponent field
// occupies bits [52, 62]; the sign bit sits at 63. Shifting right by
// F64_SHIFT moves the exponent to bit 0, ready to be masked.
let F64_SHIFT: u64 = 52;


const fracMask = 1<<F64_SHIFT - 1;
const uvone = 0x3FF0000000000000;
const signMask = 1 << 63;
