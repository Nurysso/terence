// goose_sqrtsd: computes sqrt(x) using the hardware square-root
// instruction where available.
//
// Two code paths:
//   - x86/x86-64: inline asm `sqrtsd` (SSE2 scalar double-precision
//     square root). Using inline asm rather than calling libm's sqrt()
//     guarantees the instruction is emitted even at -O0 and even if the
//     compiler would otherwise synthesize a call to the libm routine.
//   - everything else: defer to math.h's sqrt(), which the compiler
//     lowers to the target's native sqrt instruction (FSQRT on ARM,
//     FSQRT.D on RISC-V, etc.).

#include <math.h>

double goose_sqrtsd(double x) {
#if defined(__x86_64__) || defined(__i386__)
  // `sqrtsd` is a two-operand SSE2 instruction: dst <- sqrt(src).
  // The "x" constraint tells the compiler to use an SSE register for
  // both operands, which is what sqrtsd requires (general-purpose
  // registers are not valid). The "=x" output and "x" input can share
  // a register — there is no separate "early-clobber" constraint —
  // because sqrtsd reads its source before writing its destination.
  double r;
  __asm__("sqrtsd %1, %0" : "=x"(r) : "x"(x));
  return r;
#else
  // Portable fallback. On targets with a hardware sqrt (ARM, RISC-V,
  // MIPS, ...), sqrt() compiles to a single instruction; on targets
  // without one, libm provides a correctly-rounded software routine.
  return sqrt(x);
#endif
}
