# Terence

> _A high-performance, pure-Goose mathematical library inspired by Go’s standard `math` package. Named in honor of Terence Tao, one of the greatest mathematicians of our time._

---

## About

**Terence** is a zero-allocation, heapless mathematical library built from the ground up for **Goose**. Because Goose brings low-level systems performance with strict compile-time safety and zero garbage collection, Terence aims to provide a reliable, idiomatic math foundation without hidden runtime overhead or FFI penalties.

Having Go as a primary background, this library is designed as a close conceptual port of Go's robust `math` package, adapted to leverage Goose's clean C code generation and fast scalar/bitwise primitives.

---

## Features

- **Zero Allocations:** Fully stack-allocated and stateless, allowing the compiler to perform aggressive inlining and auto-vectorization.
- **Comprehensive API:** Covers everything from basic floating-point manipulation to trigonometry, logarithms, and hyperbolic functions.
- **Low-Level Bitwise Utilities:** Includes specialized bit rotations (`rotl`, `rotr`) and integer operations designed to support high-throughput hashing algorithms like **XXH3**.
- **Idiomatic Goose Integration:** Designed seamlessly for Goose types with explicit casting and zero external runtime dependencies.

---

## Quick Start

```go
import terence from "./terrence";

fn main() {
    let x: f64 = 9.0;
    let result = sqrt(x);
    let clamped = clamp(result, 0.0, 5.0);
    print("clamped value = ", clamped);
}

```

---

## API Reference

### 1. Constants

- `PI` ($\pi$)
- `E` ($e$)
- `TAU` ($2\pi$)
- `SQRT2` ($\sqrt{2}$)
- `LOG2_E`, `LOG10_E`, `LN_2`, `LN_10`

### 2. Basic Utilities & Floating-Point Checks

- `abs(x)` — Absolute value
- `min(a, b)` / `max(a, b)` — Extrema
- `clamp(val, min, max)` — Value clamping
- `signum(x)` — Sign indicator (`-1.0`, `0.0`, `1.0`)
- `floor(x)`, `ceil(x)`, `round(x)`, `trunc(x)` — Rounding operations
- `is_nan(x)`, `is_infinite(x)`, `is_finite(x)` — State checks

### 3. Exponentials & Logarithms

- `sqrt(x)` — Square root
- `cbrt(x)` — Cube root
- `hypot(x, y)` — Hypotenuse ($\sqrt{x^2 + y^2}$)
- `pow(base, exp)` — Power function
- `exp(x)`, `exp2(x)` — Exponentials
- `ln(x)`, `log2(x)`, `log10(x)` — Logarithms

### 4. Trigonometry & Hyperbolic Functions

- `sin(x)`, `cos(x)`, `tan(x)` — Standard trig
- `asin(x)`, `acos(x)`, `atan(x)`, `atan2(y, x)` — Inverse trig
- `sinh(x)`, `cosh(x)`, `tanh(x)` — Hyperbolic functions
- `to_radians(deg)`, `to_degrees(rad)` — Unit conversions

### 5. Bitwise & Integer Math (XXH3 Primitives)

- `rotl32(v, r)` / `rotl64(v, r)` — Bitwise left rotation
- `rotr32(v, r)` / `rotr64(v, r)` — Bitwise right rotation
- `clz(x)` / `ctz(x)` — Count leading/trailing zeros
- `popcount(x)` — Population count

---

## Roadmap

- [x] Core numeric primitives and rounding utilities
- [ ] Floating-point exponential and logarithmic approximations
- [ ] Trigonometric and hyperbolic function suites
- [ ] Bitwise rotation and wide multiplication helpers _(preparing for XXH3 port)_
- [ ] Upstream RFC and integration into the standard Goose ecosystem

---

## Contributing

Contributions, bug reports, and performance optimizations are welcome! Since Terence is built for a heapless environment, keeping algorithms pure, stateless, and allocation-free is our core design rule.

---

## License

Distributed under the Apache-2.0 License. See `LICENSE` for more information.
