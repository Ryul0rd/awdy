from awdy.awdy import awdy
from testing import assert_equal


def test_format_time():
    var expected = String('01:01')
    var result = awdy._format_time(61 * 1_000_000_000)
    assert_equal(expected, result)
