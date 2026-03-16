# MoreStreamData

Additional strategies for `StreamData`. The goal of this library is to reach feature-parity with Python's Hypothesis library as much as possible.


## Roadmap

- [ ] Strategies
  - [x] `integers`
  - [x] `floats`
    - [x] `exclude_min` and `exclude_max` options.
  - [x] `decimal`
  - [ ] `from_regex`
  - [ ] `emails`: Requires `domains`
  - [ ] `domains`: Requires `from_regex`
  - [ ] `urls`: Requires `domains`
  - [x] `datetime`
  - [x] `time`
  - [x] `timezone`
  - [x] `timedeltas`: Implement using `Duration`
  - [x] `ip_address`
