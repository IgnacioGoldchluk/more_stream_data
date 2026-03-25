# MoreStreamData

Additional strategies for `StreamData`. The goal of this library is to reach feature-parity with Python's Hypothesis library as much as possible.


## Roadmap

- [ ] Strategies
  - [x] `integers`
  - [x] `floats`
    - [x] `exclude_min` and `exclude_max` options.
  - [x] `decimal`
  - [x] `from_regex`: A bit slow but works
    - [ ] `\b` word boundary
    - [x] `\v` vertica line meta character
    - [ ] Non-printable characters
    - [x] `xHH` for hex characters
    - [x] `x{HHH...}` for hex characters
    - [ ] Atomic groups
    - [ ] Lookarounds
      - [ ] Positive lookahead
      - [ ] Negative lookahead
      - [ ] Positive lookbehind
      - [ ] Negative lookbehind
    - [ ] Modifiers
      - [ ] Case insensitive `/i`
      - [ ] Extended `/x`
      - [ ] Unicode `/u`
      - [ ] Dotall `/s`
      - [ ] Multiline `/m`
      - [ ] Firstline `/f`
      - [x] Ungreedy `/U`. Not actually supported but redundant for string generation.
  - [x] `emails`
  - [x] `domains`
  - [x] `urls`
  - [x] `datetime`
  - [x] `time`
  - [x] `timezone`
  - [x] `timedeltas`
  - [x] `ip_address`
