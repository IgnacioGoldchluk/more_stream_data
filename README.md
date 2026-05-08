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
    {:more_stream_data, "~> 0.8", only: :test}
  ]
end
```

Refer to [StreamData](https://hexdocs.pm/stream_data/StreamData.html) documentation for usage.

You can call additional generators directly in any testfile
```elixir
defmodule MyTestMoule do
  use ExUnit.Case
  use ExUnitProperties

  property "strings matching regular expression" do
    regex = ~r/^[A-Z]_[a-z0-9]+$/

    check all string <- MoreStreamData.from_regex(regex) do
      assert Regex.match?(regex, string)
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
  - [x] `from_regex`
    - [ ] Newline setting `(*ANYCRLF)`, `(*NUL)`, etc.
    - [ ] `\b` word boundary
    - [x] `xHH` and `x{HHH...}` for hex characters
    - [x] Atomic groups: Always matches the first option
    - [ ] Lookarounds
      - [ ] Positive lookahead
      - [x] Negative lookahead
      - [ ] Positive lookbehind
      - [x] Negative lookbehind
    - [ ] Modifiers
      - [x] Case insensitive `/i`
      - [x] Extended `/x`
      - [ ] Unicode `/u`
      - [x] Dotall `/s`
      - [x] Multiline `/m`
      - [x] Firstline `/f`
      - [x] Ungreedy `/U`. Ignored since it does not affect string generation.
      - [x] Export `/E`. Ignored since it does not affect string generation.
