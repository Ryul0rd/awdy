from collections.optional import Optional
from time import now, sleep


alias ASCII_PARTIAL_FULL_CHARS = String(' 123456789')

var current_bars = List[String]()
var bar_closed = List[Bool]()


# TODO: think about removing close
# TODO: rename current_bars and bar_closed etc to indicate that they're private
# TODO: fix redraw
# TODO: handle finalizing rate on close
# TODO: handle unit_scale
# TODO: handle ascii
# TODO: add docstrings


@value
struct awdy:
    var desc: Optional[String]
    var current: Int
    var total: Optional[Int]
    var leave: Bool
    var ncols: Int
    var mininterval: Float64
    var ascii: Bool
    var unit: String
    var smoothing: Float64
    var _current_ema: Optional[Int]
    #var unit_scale: complicated
    #var unit_divisor: Float
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
        ascii: Bool=False,
        unit: String = 'it',
        smoothing: Float64 = 0.3,
    ):
        self.desc = desc
        self.current = 0
        self.total = total
        self.leave = leave
        self.ncols = ncols
        self.mininterval = mininterval
        self.ascii = ascii
        self.unit = unit
        self.smoothing = smoothing
        self._position = len(current_bars)
        self._current_ema = None
        self._start_time = now()
        self._last_update_time = self._start_time
        self._last_draw_time = self._start_time

        if len(current_bars):
            print()
        current_bars.append('')
        bar_closed.append(False)
        self.draw()

    fn update(inout self, increment: Int=1):
        self.current += increment
        var current_time = now()

        # update _current_ema
        if increment != 0 and self.current != 0:
            if self.smoothing == 1:
                self._current_ema = (current_time - self._start_time) // self.current
            elif self._current_ema:
                var current_ema = self._current_ema.or_else(0)
                var time_since_last_update = current_time - self._last_update_time
                var time_per_increment_unit = time_since_last_update // increment
                for _ in range(increment):
                    current_ema = (current_ema * self.smoothing + time_per_increment_unit * (1 - self.smoothing)).to_int()
                self._current_ema = current_ema
            else:
                var time_since_last_update = current_time - self._last_update_time
                var time_per_increment_unit = time_since_last_update // increment
                self._current_ema = time_per_increment_unit
        
        # redraw if appropriate
        var time_since_last_draw_sec = (current_time - self._last_draw_time) / 1_000_000_000
        if time_since_last_draw_sec > self.mininterval:
            self._last_draw_time = current_time
            self.redraw()

        self._last_update_time = current_time

    fn close(self):
        self._move_cursor_to_line_start()
        self._clear_line()
        for _ in range(len(current_bars)-1):
            self._move_cursor_up()
            self._clear_line()
        if self.leave:
            self.draw()
            print()
        
        bar_closed[self._position] = True
        while len(bar_closed) and bar_closed[-1]:
            _ = bar_closed.pop_back()
            _ = current_bars.pop_back()
        
        for i in range(len(current_bars)):
            if not bar_closed[i]:
                print(current_bars[i], end='\n' if i+1 != len(current_bars) else '')

    fn draw(self):
        var bar = String()
        if not self.total:
            bar = self._bar(full=False)
        elif self.current > self.total.or_else(0):
            bar = self._bar(full=False)
        else:
            bar = self._bar(full=True)

        current_bars[self._position] = bar
        print(current_bars[self._position], end='')

    fn _bar(self, full: Bool) -> String:
        var l_bar = String()
        var m_bar = String()
        var r_bar = String()

        if full:
            var total = self.total.or_else(0)
            l_bar = self._left_pad(self.current * 100 // total, 3) + '%'
            r_bar = (
                String(' ') + self._left_pad(self.current, self._n_digits(total)) + '/' + total + ' '
                + '[' + self._format_time(self._last_update_time - self._start_time)
                + '<' + self._format_estimated_time_remaining()
                + ', ' + self._format_rate() + ']'
            )
            var m_bar_size_budget = self.ncols - len(l_bar) - len(r_bar) - 2
            if m_bar_size_budget > 0:
                var full_cells = self.current / total * m_bar_size_budget
                var n_full_cells = full_cells.to_int()
                var n_empty_cells = (m_bar_size_budget - full_cells).to_int()
                var partial_full_cell = (
                    ASCII_PARTIAL_FULL_CHARS[(full_cells % 1 * 10).to_int()]
                    if n_full_cells + n_empty_cells != m_bar_size_budget
                    else String()
                )
                m_bar = String('|') + String('#') * n_full_cells + partial_full_cell + String(' ') * n_empty_cells + '|'
        else:
            l_bar = String(self.current) + self.unit + ' '
            r_bar = String('[') + self._format_time(self._last_update_time - self._start_time) + ', ' + self._format_rate() + ']'

        return l_bar + m_bar + r_bar

    fn redraw(self):
        self._clear_line()
        self._move_cursor_to_line_start()
        self.draw()

    @staticmethod
    fn write(message: String):
        Self._move_cursor_to_line_start()
        Self._clear_line()
        for _ in range(len(current_bars)-1):
            Self._move_cursor_up()
            Self._clear_line()
        print(message)
        for i in range(len(current_bars)):
            if not bar_closed[i]:
                print(current_bars[i], end='\n' if i+1 != len(current_bars) else '')

    fn __enter__(owned self) -> Self:
        return self^

    fn __del__(owned self):
        self.close()

    fn _format_time(self, time: Int) -> String:
        var dt_s = time // 1_000_000_000
        var dt_m = dt_s // 60
        var dt_h = dt_m // 60
        var s_remainder = dt_s % 60
        var m_remainder = dt_m % 60

        var s = String() if dt_h == 0 else self._left_pad(dt_h, 2, '0') + ':'
        s += self._left_pad(m_remainder, 2, '0') + ':' + self._left_pad(s_remainder, 2, '0')
        return s

    fn _format_rate(self) -> String:
        if not self._current_ema:
            return String('?') + self.unit + '/s'
        var units_per_s = 1 / self._current_ema.or_else(0) * 1_000_000_000
        var formatted_rate = String()
        if units_per_s >= 1:
            formatted_rate = self._format_round(units_per_s, 2) + self.unit + '/s'
        else:
            var s_per_unit = 1 / units_per_s
            formatted_rate = self._format_round(s_per_unit, 2) + 's/' + self.unit
        return formatted_rate

    fn _format_estimated_time_remaining(self) -> String:
        if not self._current_ema:
            return String('?')
        var total = self.total.or_else(0)
        var remaining = total - self.current
        var elapsed_time_ns = self._last_update_time - self._start_time
        var unit_per_ns = 1 / self._current_ema.or_else(0)
        var etr = remaining / unit_per_ns
        return self._format_time(etr.to_int())

    fn _format_round(self, number: Float64, owned ndigits: Int) -> String:
        var n_left_of_point = self._n_digits(number.to_int())
        var chars_wanted = n_left_of_point+1+ndigits
        var num_s = String(number)
        if chars_wanted >= len(num_s):
            return num_s
        else:
            return String(number)[:chars_wanted]

    @staticmethod
    @always_inline
    fn _move_cursor_up():
        print('\x1b[1A', end='')

    @staticmethod
    @always_inline
    fn _clear_line():
        print('\x1b[2K', end='')

    @staticmethod
    @always_inline
    fn _move_cursor_to_line_start():
        print('\r', end='')

    @staticmethod
    fn _left_pad(s: String, pad_to: Int, pad_value: String=' ') -> String:
        var padding_needed = pad_to - len(s)
        return pad_value * padding_needed + s 

    @staticmethod
    fn _n_digits(owned int: Int) -> Int:
        var n = 1
        while int >= 10:
            n += 1
            int //= 10
        return n
