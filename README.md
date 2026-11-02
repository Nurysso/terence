# Terence

A hobby math library for the Goose programming language, written mostly so I'd have a reason to learn the language. 🪿

It's a port of the parts of Go's `math` package I could get my head around, rewritten in Goose. Named after Terence Tao, because I like the name.

> **Status:** early, unfinished, and very much a work in progress. Some stuff works and has tests, a lot of files are still empty placeholders. See [what's here](#whats-here) for the honest list.

---

## Why does this exist?

I like Go, I like Goose, and `math` is a nice, well-specified chunk of code to port while figuring out how a new language actually feels. That's the whole pitch. It's not trying to replace anything, it hasn't been benchmarked, and it's not battle-tested.

Things it does aim for:

- **Same behaviour as Go's `math`** for the edge cases (NaN, ±Inf, signed zero, subnormals), since that's what I'm using as the reference.
- **No heap allocation.** Everything is plain `f64` in, `f64` out. I haven't gone looking for allocations with a tool, it's just that nothing in here needs any.
- **Lots of comments.** I write down why the code does what it does, mostly so future me can follow along.

Things it does _not_ claim:

- It's not "high-performance". `cbrt` is literally a loop of Newton iterations. It's correct-ish, not fast.
- It's not 100% pure Goose. `sqrt` calls a tiny C shim (`sqrt_native.c`) to grab the hardware square-root instruction, so building needs a C compiler and libm. See `terence.build`.
- Results aren't guaranteed to be bit-identical to Go's, or the same across platforms.

---

## What's here

| Area                     | Functions                                                                  | Status                                      |
| ------------------------ | -------------------------------------------------------------------------- | ------------------------------------------- |
| Constants                | `E`, `Pi`, `Phi`, `Sqrt2`, `SqrtE`, `SqrtPi`, `SqrtPhi`, `Ln2`, `Ln10`, `Log2E`, `Log10E`, float and int limits (`MaxFloat64`, `MaxInt`, ...) | works, tested                               |
| Float bits & basics      | `float64_bits`, `float64_frombits`, `float32_bits`, `float32_frombits`, `nan`, `inf`, `is_nan`, `is_inf`, `signbit`, `abs`, `copysign`, `normalize`, `exact_pow2` | works, tested                               |
| Rounding                 | `floor`, `ceil`, `round`, `trunc`, `round_to_even`, `modf`                 | works, tested                               |
| Binary ops               | `max`, `min`, `dim`, `mod`, `remainder`, `fma`                             | works, tested. **`fma` is not a real fused multiply-add**, it's just `a*b + c` (two roundings). |
| Decomposition            | `frexp`, `ldexp`, `ilogb`, `logb`, `next_after`, `next_after32`            | works, tested                               |
| Roots                    | `sqrt`, `cbrt`, `hypot`                                                    | works on the inputs I tried, **no tests yet** |

### Not done yet

These files exist but are empty, I haven't started them:

- exp & logs: `exp`, `exp2`, `expm1`, `log`, `log2`, `log10`, `log1p` (`exp.goose`, `log.goose`)
- `pow`, `pow10` (`pow.goose`, `power.goose`)
- trig: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2` (`trig.goose`)
- hyperbolic: `sinh`, `cosh`, `tanh` and friends (`hyper.goose`)
- `gamma`, `lgamma`, `erf` family, Bessel functions (`gamma.goose`, `erf.goose`, `bessel.goose`)
- number theory extras: `gcd`, `is_prime`, etc. (`numtheory.goose`)

And a few things that are _not_ planned, even though earlier versions of this README suggested otherwise: bit-rotation / popcount helpers, `clamp`, `signum`, `to_radians` / `to_degrees`. If you need those, they're a one-liner away, or open an issue and I might get bored enough to add them.

---

## Trying it out

You need Goose installed (I'm using `goose-v2026.3`) and a C compiler for the `sqrt` shim.

```go
import terence from "path/to/terence";   // the directory, not a file

fn main() {
    print("sqrt(9)     = ", sqrt(9.0));
    print("cbrt(27)    = ", cbrt(27.0));
    print("hypot(3, 4) = ", hypot(3.0, 4.0));

    let whole, frac = modf(3.75);
    print("modf(3.75)  = ", whole, " + ", frac);
}
```

Run the tests with:

```sh
goose run tests/basic_test.goose
goose run tests/bits_test.goose
goose run tests/decompose_test.goose
goose run tests/rounding_test.goose
```

There's also `examples/sample.goose`, which just prints a bunch of stuff.

---

## Roadmap (a.k.a. things I might do on a free weekend)

- [x] Constants, float bit tricks, rounding, binary ops, decomposition
- [x] `sqrt` / `cbrt` / `hypot`
- [ ] Tests for `sqrt` / `cbrt` / `hypot`
- [ ] `exp` and `log` family
- [ ] `pow`
- [ ] Trig and hyperbolic functions
- [ ] The fancy stuff (`gamma`, `erf`, Bessel)
- [ ] A real `fma`
- [ ] Maybe get rid of the C shim

---

## Contributing

It's a learning project, so poke around, but expect things to move around. Bug reports and "you did this wrong, here's a better Goose idiom" comments are very welcome, especially the second kind, since that's the point.

---

## License & credits

Terence is licensed under the [Apache License 2.0](LICENSE).

A lot of the logic, tests and comments here are ported from Go's `math` package, which is BSD-3-Clause licensed (Copyright 2009 The Go Authors), and some of that code goes back further to FreeBSD's `msun` / Sun's fdlibm. Their licence texts are reproduced in [`NOTICE`](NOTICE). Thanks to everyone who wrote that code in the first place, any bugs in the port are mine.
