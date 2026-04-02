[![CI](https://github.com/IgnacioGoldchluk/more_stream_data/actions/workflows/ci.yml/badge.svg)](https://github.com/IgnacioGoldchluk/more_stream_data/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/more_stream_data
)](https://github.com/IgnacioGoldchluk/more_stream_data/blob/main/LICENSE.md)
[![Version](https://img.shields.io/hexpm/v/more_stream_data.svg)](https://hex.pm/packages/more_stream_data)
[![Docs](https://img.shields.io/badge/documentation-gray.svg)](https://hexdocs.pm/more_stream_data)

# MoreStreamData

Additional generators based on `StreamData`.

## Installation
Add `more_stream_data` to your list of dependencies in `mix.exs`
```elixir
def deps do
  [
    {:more_stream_data, "~> 0.1", only: :test}
  ]
end
```

Refer to [StreamData](https://hexdocs.pm/stream_data/StreamData.html) documentation for usage.

You can call additional generators directly in any testfile
```elixir
defmodule MyTestMoule do
  use ExUnit.Case
  use ExUnitProperties

  property "generates numbers greater than or equal to the minimum" do
    check all number <- MoreStreamData.more_integer(min: 10) do
      assert number >= 10
    end
  end
end
```

## Roadmap
The goal is to port [Python's Hypothesis](https://hypothesis.readthedocs.io/en/latest/) built-in and external strategies considered useful for Elixir ecosystem.

- [ ] Strategies
  - [x] `integers`
  - [x] `floats`
    - [x] `exclude_min` and `exclude_max` options.
  - [x] `decimal`
  - [x] `emails`
  - [x] `domains`
  - [x] `urls`
  - [x] `datetime`
  - [x] `time`
  - [x] `timedeltas`
  - [x] `ip_address`
  - [x] `from_regex`: A bit slow but works
    - [ ] `\b` word boundary
    - [x] `\v` vertical line meta character
    - [x] Non-printable characters (as long as they are specified using `\x`)
    - [x] `xHH` and `x{HHH...}` for hex characters
    - [ ] Atomic groups
    - [ ] Lookarounds
      - [ ] Positive lookahead
      - [ ] Negative lookahead
      - [ ] Positive lookbehind
      - [ ] Negative lookbehind
    - [ ] Modifiers
      - [x] Case insensitive `/i`
      - [x] Extended `/x`
      - [ ] Unicode `/u`
      - [ ] Dotall `/s`
      - [x] Multiline `/m`
      - [x] Firstline `/f`
      - [x] Ungreedy `/U`. Ignored since it does not affect string generation.
      - [x] Export `/E`. Ignored since it does not affect string generation.
