import terence from "../../terence";

fn test_trunc() {
    assert(trunc( 0.0)  ==  0.0);
    assert(trunc(-0.0)  ==  0.0 && signbit(trunc(-0.0)));
    assert(trunc( 0.5)  ==  0.0);
    assert(trunc(-0.5)  ==  0.0 && signbit(trunc(-0.5)));
    assert(trunc( 1.5)  ==  1.0);
    assert(trunc(-1.5)  == -1.0);
    assert(trunc( 3.5)  ==  3.0);
    assert(trunc(-3.5)  == -3.0);
    assert(trunc( 1e100) == 1e100);              // integer already
    assert(trunc(inf(1))  == inf(1));
    assert(is_nan(trunc(nan())));
}

fn test_round_to_even() {
    // Exact halves go to even
    assert(round_to_even(0.5) == 0.0);
    assert(round_to_even(1.5) == 2.0);
    assert(round_to_even(2.5) == 2.0);
    assert(round_to_even(3.5) == 4.0);
    assert(round_to_even(-0.5) == 0.0);
    assert(round_to_even(-1.5) == -2.0);
    assert(round_to_even(-2.5) == -2.0);
    assert(round_to_even(-3.5) == -4.0);

    // Ordinary rounding
    assert(round_to_even(1.4) == 1.0);
    assert(round_to_even(1.6) == 2.0);
    assert(round_to_even(2.4) == 2.0);
    assert(round_to_even(2.6) == 3.0);

    // Integers unchanged
    assert(round_to_even(0.0) == 0.0);
    assert(round_to_even(5.0) == 5.0);
    assert(round_to_even(-5.0) == -5.0);
    assert(round_to_even(1e100) == 1e100);

    // Special values
    assert(round_to_even(inf(1))  == inf(1));
    assert(round_to_even(inf(-1)) == inf(-1));
    assert(is_nan(round_to_even(nan())));
}

fn main(){
    test_trunc();
    test_round_to_even();
    print("decompose.goose: all tests passed\n");
}
