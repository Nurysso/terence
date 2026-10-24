import terence from "../../terence";

fn test_max_min() {
    // Ordinary
    assert(max(1.0, 2.0) == 2.0);
    assert(min(1.0, 2.0) == 1.0);

    // NaN propagates
    assert(is_nan(max(nan(), 1.0)));
    assert(is_nan(min(nan(), 1.0)));

    // Signed zero: max prefers +0, min prefers -0
    assert(!signbit(max(-0.0, 0.0)));
    assert( signbit(min(-0.0, 0.0)));

    // Infinities
    assert(max(inf(1), 1.0)  == inf(1));
    assert(max(inf(-1), 1.0) == 1.0);
    assert(min(inf(1), 1.0)  == 1.0);
    assert(min(inf(-1), 1.0) == inf(-1));
}

fn test_dim() {
    assert(dim(3.0, 1.0) == 2.0);
    assert(dim(1.0, 3.0) == 0.0);
    assert(dim(3.0, 3.0) == 0.0);
    assert(is_nan(dim(inf(1), inf(1))));   // Inf - Inf = NaN
}

fn test_mod() {
    assert(mod(5.0, 2.0) == 1.0);
    assert(mod(-5.0, 2.0) == -1.0);       // sign follows dividend
    assert(mod(5.0, -2.0) == 1.0);
    assert(mod(-5.0, -2.0) == -1.0);
    assert(is_nan(mod(1.0, 0.0)));
    assert(is_nan(mod(inf(1), 2.0)));
    assert(mod(1e300, 1.0) == 0.0);       // large-mod-small
}

fn test_remainder() {
    assert(remainder(5.0, 3.0) == -1.0);   // 5 - 6 = -1 (nearest multiple of 3)
    assert(remainder(4.0, 3.0) ==  1.0);
    assert(remainder(-5.0, 3.0) == 1.0);
    assert(remainder(6.0, 3.0) == 0.0);
    // Sign of zero result follows dividend
    assert(signbit(remainder(-6.0, 3.0)));
    assert(!signbit(remainder(6.0, 3.0)));
    // Specials
    assert(is_nan(remainder(1.0, 0.0)));
    assert(remainder(inf(1), 2.0) == 0.0 || is_nan(remainder(inf(1), 2.0)));
    assert(remainder(1.0, inf(1)) == 1.0);
}

fn main(){
    test_dim();
    test_max_min();
    test_mod();
    test_remainder();

    print("basic.goose: all tests passed\n");
}
