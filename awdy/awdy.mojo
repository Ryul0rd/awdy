from collections.optional import Optional
from time import now, sleep
from math import abs, round


alias ASCII_PARTIAL_FULL_CHARS: String = ' 123456789'

var _current_bars = List[String]()
var _bar_closed = List[Bool]()


# TODO: handle finalizing rate on close
# TODO: handle unit_scale
# TODO: handle ascii


@value
struct awdy:
    var desc: Optional[String]
    var n: Int
    var total: Optional[Int]
    var leave: Bool
    var ncols: Int
    var mininterval: Float64
    var unit: String
    var smoothing: Float64
    var _ns_per_unit: Optional[Int]
    var _position: Int
    var _start_time: Int
    var _last_update_time: Int
    var _last_draw_time: Int

    fn __init__(
        inout self,
        desc: Optional[String] = None,
        total: Optional[Int] = None,
        leave: Bool = True,
        ncols: Int = 120,
        mininterval: Float64 = 0.1,
        unit: String = 'it',
        smoothing: Float64 = 0.3,
    ):
        """Constructs an updatable progress bar.
        
        Args:
            desc: The description that will prefix the bar.
            total: Total number of units before completion.
            leave: If False, clear the bar from the terminal when it gets deleted.
            ncols: Width of the full bar.
            mininterval: The minimal amount of time that must pass before the bar is redrawn on udpate.
            unit: What unit progress is measured in.
            smoothing: Smoothing factor between 0 and 1 for time estimates. Higher values mean less smoothing.
        """
        self.desc = desc
        self.n = 0
        self.total = total
        self.leave = leave
        self.ncols = ncols
        self.mininterval = mininterval
        self.unit = unit
        self.smoothing = smoothing
        self._position = len(_current_bars)
        self._ns_per_unit = None
        self._start_time = now()
        self._last_update_time = self._start_time
        self._last_draw_time = self._start_time

        if len(_current_bars):
            print()
        _current_bars.append('')
        _bar_closed.append(False)
        _current_bars[self._position] = self._progress_bar()
        print(_current_bars[self._position], end='')

    fn __enter__(owned self) -> Self:
        return self^

    fn __del__(owned self):
        """Mark progress bar as closed and and print updated bar order."""
        self._clear_bars(_current_bars)
        if self.leave:
            _current_bars[self._position] = self._progress_bar()
            print(_current_bars[self._position])
        _bar_closed[self._position] = True
        while len(_bar_closed) and _bar_closed[-1]:
            _ = _bar_closed.pop()
            _ = _current_bars.pop()
        for i in range(len(_current_bars)):
            if not _bar_closed[i]:
                var not_final_bar = i+1 != len(_current_bars)
                print(_current_bars[i], end='\n' if not_final_bar else '')

    fn update(inout self, increment: Int=1):
        """Increment current progress, update time estimates, and redraw bar if necessary."""
        self.n += increment
        var current_time = now()

        # update _ns_per_unit estimate
        if increment != 0 and self.n != 0:
            if self.smoothing == 0 or not self._ns_per_unit:
                self._ns_per_unit = (current_time - self._start_time) // self.n
            else:
                var time_per_increment_unit = (current_time - self._last_update_time) // increment
                for _ in range(increment):
                    self._ns_per_unit = int(self._ns_per_unit.or_else(0) * self.smoothing + time_per_increment_unit * (1 - self.smoothing))

        # redraw if appropriate
        var time_since_last_draw_sec = (current_time - self._last_draw_time) / 1_000_000_000
        if time_since_last_draw_sec > self.mininterval:
            self._last_draw_time = current_time
            _current_bars[self._position] = self._progress_bar()
            Self._clear_bars(_current_bars)
            for i in range(len(_current_bars)):
                if not _bar_closed[i]:
                    var not_final_bar = i+1 != len(_current_bars)
                    print(_current_bars[i], end='\n' if not_final_bar else '')

        self._last_update_time = current_time

    @staticmethod
    fn write(message: String):
        """Print a custom message to the screen. Use this instead of the builtin print function while there are any unclosed bars.
        
        Args:
            message: The message to print.
        """
        Self._clear_bars(_current_bars)
        print(message)
        for i in range(len(_current_bars)):
            if not _bar_closed[i]:
                var not_final_bar = i+1 != len(_current_bars)
                print(_current_bars[i], end='\n' if not_final_bar else '')

    @staticmethod
    fn _clear_bars(current_bars: List[String]):
        """Clears all currently displayed bars from the terminal.
        
        Args:
            current_bars: The list of last Strings printed by each bar awdy is maintaining.
        """
        Self._move_cursor_to_line_start()
        Self._clear_line()
        for _ in range(len(current_bars)-1):
            Self._move_cursor_up()
            Self._clear_line()

    fn _progress_bar(self) -> String:
        """Creates the full progress bar string to be displayed."""
        var template: String = (
            '{desc}{percentage}|{bar}| {n}/{total} [{elapsed}<{remaining}, {rate}]'
            if self.total and self.n <= self.total.or_else(0) else
            '{desc}{n}{unit} [{elapsed}, {rate}]'
        )
        var total = self.total.or_else(0)
        var bar = (
            template
            .replace('{percentage}', Self._left_pad(self.n * 100 // total, 3) + '%')
            .replace('{n}', Self._left_pad(self.n, Self._n_digits(total)))
            .replace('{total}', total)
            .replace('{unit}', self.unit)
            .replace('{elapsed}', Self._format_time(self._last_update_time - self._start_time))
            .replace('{remaining}', Self._time_remaining(self._ns_per_unit, self.n, total))
            .replace('{rate}', Self._rate(self._ns_per_unit, self.unit))
        )
        bar = bar.replace('{desc}', self.desc.or_else('') + ': ' if self.desc else '')
        var bar_size = self.ncols - len(bar)
        bar = bar.replace('{bar}', Self._meter(self.n, total, bar_size))
        return bar

    @staticmethod
    fn _meter(current: Int, total: Int, size: Int) -> String:
        """Creates the visual meter to be used to display progress.

        Args:
            current: Units completed so far.
            total: Total units needed to complete.
            size: Width of the meter in characters.
        """
        if size <= 0:
            return ''
        var full_cells = current / total * size
        var n_full_cells = int(full_cells)
        var n_empty_cells = int(size - full_cells)
        var partial_full_cell = (
            ASCII_PARTIAL_FULL_CHARS[int(full_cells % 1 * 10)]
            if n_full_cells + n_empty_cells != size
            else ''
        )
        var bar = String('#') * n_full_cells + partial_full_cell + String(' ') * n_empty_cells
        return bar

    @staticmethod
    fn _format_time(time: Int) -> String:
        """Formats a time in nanoseconds as a String in in the format mm:ss or, if at least 1 hour, hh:mm:ss.
        
        Args:
            time: Time to format in nanoseconds.
        """
        var dt_s = time // 1_000_000_000
        var dt_m = dt_s // 60
        var dt_h = dt_m // 60
        var s_remainder = dt_s % 60
        var m_remainder = dt_m % 60

        var template: String = (
            '{hh}:{mm}:{ss}'
            if dt_h > 0 else
            '{mm}:{ss}'
        )
        var formatted_time = (
            template
            .replace('{hh}', Self._left_pad(dt_h, 2, '0'))
            .replace('{mm}', Self._left_pad(m_remainder, 2, '0'))
            .replace('{ss}', Self._left_pad(s_remainder, 2, '0'))
        )
        return formatted_time

    @staticmethod
    fn _time_remaining(ns_per_unit: Optional[Int], current: Int, total: Int) -> String:
        """Calculates the estimated time remaining based on current period and units remaining.

        Args:
            ns_per_unit: Nanoseconds taken to complete 1 unit of progress.
            current: Units completed so far.
            total: Total units needed to complete.
        """
        if not ns_per_unit:
            return '?'
        var remaining = total - current
        var estimated_time_remaining = remaining * ns_per_unit.or_else(0)
        return Self._format_time(estimated_time_remaining)

    @staticmethod
    fn _rate(ns_per_unit: Optional[Int], unit: String) -> String:
        """Formats a period in nanoseconds as a rate in seconds.

        Args:
            ns_per_unit: Nanoseconds taken to complete 1 unit of progress.
            unit: Label for the unit used.
        """
        if not ns_per_unit:
            return String('?') + unit + '/s'
        var s_per_unit = ns_per_unit.or_else(0) / 1_000_000_000
        var formatted_rate = String()
        if s_per_unit <= 1:
            var unit_per_s = 1 / s_per_unit
            formatted_rate = Self._format_round(unit_per_s, 2) + unit + '/s'
        else:
            formatted_rate = Self._format_round(s_per_unit, 2) + 's/' + unit
        return formatted_rate

    @staticmethod
    fn _format_round(number: Float64, ndigits: Int) -> String:
        """Rounds a number to the desired number of decimal places.

        Args:
            number: The number to round.
            ndigits: The number of digits after the decimal place to round to.
        """
        var rounded_no_decimal = int(round(number * 10**ndigits))
        var before_decimal = rounded_no_decimal // 10**ndigits
        var after_decimal = rounded_no_decimal - int(number) * 10**ndigits
        var rounded_with_decimal = String(before_decimal) + '.' + Self._left_pad(after_decimal, ndigits, '0')
        return rounded_with_decimal

    @always_inline
    @staticmethod
    fn _left_pad(s: String, pad_to: Int, pad_value: String=' ') -> String:
        """Pads the left side of a String to the desired length with the desired character.
        
        Args:
            s: The String to pad.
            pad_to: The length to pad to.
            pad_value: The character to pad with.
        """
        var padding_needed = pad_to - len(s)
        return pad_value * padding_needed + s

    @staticmethod
    fn _n_digits(owned int: Int) -> Int:
        """Counts the number of digits in an integer.
        
        Args:
            int: The integer to count the digits of.
        """
        int = abs(int)
        var n = 1
        while int >= 10:
            n += 1
            int //= 10
        return n

    @staticmethod
    @always_inline
    fn _move_cursor_up():
        print('\x1b[1A', end='')

    @staticmethod
    @always_inline
    fn _move_cursor_down():
        print('\x1b[1B', end='')

    @staticmethod
    @always_inline
    fn _clear_line():
        print('\x1b[2K', end='')

    @staticmethod
    @always_inline
    fn _move_cursor_to_line_start():
        print('\r', end='')
