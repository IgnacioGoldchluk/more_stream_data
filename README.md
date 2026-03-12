# MoreStreamData

Additional strategies for `StreamData`. The goal of this library is to reach feature-parity with Python's Hypothesis library.


## Roadmap and status

- [ ] Strategies
  - [x] `none`: Same as `constant(nil)`
  - [x] `just`: Equivalent to `constant/1`
  - [x] `integers`: Equivalent to `integer/1`
  - [ ] `floats`: Equivalent to `float/1` with some caveats:
    - Since Erlang does not follow IEEE754 there are no `Inf` and `NaN`. Can't be added
    - [ ] `exclude_min` and `exclude_max` options missing.
  - [x] `complex`: Complex numbers are not part of the standard library. No need to implement
  - [ ] `decimal`: Decimal numbers are not part of the standard library, but they are quite common in Elixir applications, since Decimal is one of the most downloaded packages
  - [x] `fractions`: Same as complex, there are no fractions in the standard library. No need to implement.
  - [x] `text`: Same as `string/2`
  - [x] `characters`: Same as `codepoint/1`
  - [ ] `from_regex`: No equivalent in `StreamData`. Super useful for some custom strategies, high priority
  - [x] `bytes`: Same as `list_of(byte())`. Does not support min and max value but in that case
  `byte()` can be replaced by `integer()`
  - [ ] `emails`: Missing, but copying `hypothesis` implementation is straightforward
  - [ ] `domains`: Missing, check `hypothesis` implementation
  - [ ] `urls`: Missing, check `hypothesis` implementation
  - [ ] `datetime`: Missing
  - [ ] `time`: Missing
  - [ ] `timezone`: Missing, should be a `one_of/1` with all timezones
  - [ ] `timezone_keys`: Missing, see `timezone`
  - [ ] `timedeltas`: Equivalent to `time` since Elixir has no concept of timedelta
  - [x] `deferred`: Not needed in Elixir
  - [ ] `recursive`: Equivalent to `tree/2`
  - [ ] `ip_address`: Missing. Can be created from tuples + integer. For IP ranges extract the range bits and leave the other part fixed 

- [ ] `unique_by` in lists

