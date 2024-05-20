from awdy.awdy import awdy
from testing import assert_equal


# _ema
def test_ema_smoke():
    assert_equal(
        awdy._ema(100, 0.3, 1, 1, 200, 0, 0).or_else(0),
        130,
    )

def test_ema_multi():
    var smoothing = 0.75
    var init: Optional[Int] = None
    var first = awdy._ema(init, smoothing, 1, 1, 20, 0, 0)
    var second = awdy._ema(first, smoothing, 1, 2, 70, 0, 10)
    var third = awdy._ema(second, smoothing, 1, 3, 90, 0, 70)
    assert_equal(first.or_else(0), 20)
    assert_equal(second.or_else(0), 50)
    assert_equal(third.or_else(0), 27)

def test_ema_big_increment():
    var smoothing = 0.25
    var init: Optional[Int] = None
    var first = awdy._ema(init, smoothing, 5, 5, 100, 0, 0)
    var second = awdy._ema(first, smoothing, 2, 7, 300, 0, 100)
    assert_equal(first.or_else(0), 20)
    assert_equal(second.or_else(0), 55)

def test_ema_no_smooth():
    assert_equal(
        awdy._ema(100, 0, 1, 1, 300, 0, 0).or_else(0),
        300,
    )

def test_ema_full_smooth():
    assert_equal(
        awdy._ema(100, 1, 1, 1, 100, 0, 0).or_else(0),
        100,
    )


# _bar
def test_bar_smoke():
    assert_equal(awdy._meter(5, 10, 4), '##  ')

def test_bar_number_in_bar():
    assert_equal(awdy._meter(5, 8, 4), '##5 ')

def test_bar_empty():
    assert_equal(awdy._meter(0, 100, 3), '   ')

def test_bar_full():
    assert_equal(awdy._meter(50, 50, 3), '###')


# _format_time
def test_format_time_smoke():
    var ns_per_unit = 100 * 1_000_000_000
    assert_equal(awdy._format_time(ns_per_unit), '01:40')

def test_format_time_hour():
    var ns_per_unit = 90 * 60 * 1_000_000_000
    assert_equal(awdy._format_time(ns_per_unit), '01:30:00')


# _time_remaining
def test_time_remaining_smoke():
    var ns_per_unit = 2 * 1_000_000_000
    assert_equal(awdy._time_remaining(ns_per_unit, 0, 100), '03:20')

def test_time_remaining_none():
    assert_equal(awdy._time_remaining(None, 0, 100), '?')


# _rate
def test_rate_spunit():
    var ns_per_unit = 30 * 1_000_000_000
    assert_equal(awdy._rate(ns_per_unit, 'XX'), '30.00s/XX')

def test_rate_unitps():
    var ns_per_unit = 1_000_000_000 // 2
    assert_equal(awdy._rate(ns_per_unit, 'Yooy'), '2.00Yooy/s')

def test_rate_none():
    assert_equal(awdy._rate(None, 'foo'), '?foo/s')


# _format_round
def test_format_round_smoke():
    assert_equal(awdy._format_round(420.69, 1), '420.7')

def test_format_round_int():
    assert_equal(awdy._format_round(7, 3), '7.000')

def test_format_round_longer():
    assert_equal(awdy._format_round(22.456, 5), '22.45600')

def test_format_round_zeros_after_point():
    assert_equal(awdy._format_round(42.003, 3), '42.003')


# _left_pad
def test_left_pad_smoke():
    assert_equal(awdy._left_pad('hello', 8), '   hello')

def test_left_pad_neg_amount():
    assert_equal(awdy._left_pad('hello', 3), 'hello')

def test_left_pad_nonspace():
    assert_equal(awdy._left_pad(' hello', 10, 'o'), 'oooo hello')


# _n_digits
def test_n_digits_single_digit():
    assert_equal(awdy._n_digits(0), 1)

def test_n_digits_zero():
    assert_equal(awdy._n_digits(3), 1)

def test_n_digits_double_digit():
    assert_equal(awdy._n_digits(42), 2)

def test_n_digits_ten():
    assert_equal(awdy._n_digits(10), 2)

def test_n_digits_big():
    assert_equal(awdy._n_digits(573_893), 6)
