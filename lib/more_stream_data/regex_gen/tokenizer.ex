defmodule MoreStreamData.RegexGen.Tokenizer do
  @moduledoc false

  require Logger

  import MoreStreamData.RegexGen.Tokenizer.Tokens
  alias MoreStreamData.Exceptions.UnsupportedToken

  @quantifiers ~c"*+?"
  @meta_sequences ~c"wWdDsShHvV"
  @special_symbols ~c"[]{}()|.^$\\-/" ++ @quantifiers

  # Symbols that have a different value when preceded by "\"
  @escaped_symbols %{
    ?a => ?\a,
    ?0 => ?\0,
    ?t => ?\t,
    ?v => ?\v,
    ?r => ?\r,
    ?n => ?\n,
    ?f => ?\f,
    ?c => 28,
    ?e => ?\e
  }

  @type range :: {:range, {char(), char()}}
  @type literal :: {:literal, char()}
  @type meta_sequence ::
          {:meta_sequence,
           :word
           | :non_word
           | :digit
           | :non_digit
           | :space
           | :non_space
           | :blank
           | :non_blank
           | :vertical_space
           | :non_vertical_space}

  @type special_quantifier :: :star | :plus | :question
  @type range_quantifier :: {non_neg_integer(), non_neg_integer()}
  @type quantifier :: {:quantifier, special_quantifier() | range_quantifier(), :greedy | :lazy}

  @type character_class ::
          {:character_class, :negation | :positive, [range() | literal() | meta_sequence()]}

  @type token ::
          :lparen
          | :rparen
          | :union
          | :empty
          | :any_character
          | range()
          | literal()
          | meta_sequence()
          | quantifier()
          | character_class()
          | :concat
          | :string_start
          | :string_end
          | :line_start
          | :line_end
          | {:non_token, atom()}

  @type tokenized :: [token()]

  @doc """
  Tokenizes a regular expression.
  """
  @spec tokenize(String.t()) :: tokenized()
  def tokenize(pattern) when is_binary(pattern), do: tokenize(to_codepoints(pattern), [])

  # Base case, finished parsing
  defp tokenize([], acc), do: acc |> add_empty() |> Enum.reverse() |> add_concat()

  # Line and string delimiters
  defp tokenize([?\\, ?A | rest], acc), do: tokenize(rest, [:string_start | acc])
  defp tokenize([?^ | rest], acc), do: tokenize(rest, [:line_start | acc])
  defp tokenize([?$ | rest], acc), do: tokenize(rest, [:line_end | acc])
  defp tokenize([?\\, ?z | rest], acc), do: tokenize(rest, [:string_end | acc])

  # Parentheses
  # First check for unsupported cases or cases that we'll drop
  defp tokenize([?(, ??, ?= | _rest], _) do
    raise UnsupportedToken, token: <<?(, ??, ?=>>
  end

  defp tokenize([?(, ??, ?<, ?= | _rest], _) do
    raise UnsupportedToken, token: <<?(, ??, ?<, ?=>>
  end

  # Negative lookahead, ignore and pray
  defp tokenize([?(, ??, ?! | rest], acc) do
    tokenize(discard_zero_width_assertion(rest), [{:non_token, :negative_lookahead} | acc])
  end

  # Negative lookbehind, ignore and pray too
  defp tokenize([?(, ??, ?<, ?! | rest], acc) do
    tokenize(discard_zero_width_assertion(rest), [{:non_token, :negative_lookbehind} | acc])
  end

  defp tokenize([?(, ??, ?> | rest], acc) do
    Logger.warning("atomic group found, values will be generated from the first pattern option")
    tokenize(atomic_group(rest, ~c"("), acc)
  end

  # Non-capture group. Keep the paren but ignore the fact that it's non-capturing
  defp tokenize([?(, ??, ?: | rest], acc), do: tokenize(rest, [:lparen | acc])

  defp tokenize([?(, ??, ?< | rest], acc) do
    # Named capture group in the form of (?<name>...) remove everything between <>
    tokenize(discard_named_group(rest), [:lparen | acc])
  end

  # Inline comment in the form of (?# comment ). Discard it
  defp tokenize([?(, ??, ?# | rest], acc), do: tokenize(discard_comment(rest), acc)

  defp tokenize([?( | rest], acc), do: tokenize(rest, [:lparen | acc])
  defp tokenize([?) | rest], acc), do: tokenize(rest, [:rparen | acc])

  # Special characters
  defp tokenize([?. | rest], acc), do: tokenize(rest, [:any_character | acc])
  defp tokenize([?| | rest], acc), do: tokenize(rest, [:union | acc])

  # Reject \1, \2, ... \9 because it's not possible to represent via NFA.
  # It still is possible to generate a regex that repeats its capturing
  # pattern but too complex. Not going to support it for now
  defp tokenize([?\\, d | _rest], _) when d in ?1..?9 do
    raise UnsupportedToken, token: <<?\\, d>>
  end

  # Same for backreference with name
  defp tokenize([?\\, group | _rest], _) when group in [?k, ?g] do
    raise UnsupportedToken, token: <<?\\, group>>
  end

  # Quantifiers
  defp tokenize([q, ?? | rest], acc) when q in @quantifiers do
    tokenize(rest, [to_quantifier(q, quantifier_mode_lazy()) | acc])
  end

  defp tokenize([q | rest], acc) when q in @quantifiers,
    do: tokenize(rest, [to_quantifier(q) | acc])

  defp tokenize([?{ | rest] = pattern, acc) do
    case repetitions(pattern) do
      nil -> tokenize(rest, [literal(?{) | acc])
      {prefix, token} -> tokenize(pattern -- prefix, [token | acc])
    end
  end

  defp tokenize([?\\, seq | rest], acc) when seq in @meta_sequences do
    tokenize(rest, [to_meta_sequence(seq) | acc])
  end

  defp tokenize([?\\, ?x, ?{ | rest], acc) do
    # Consume until we hit a `}` and convert to binary
    {hex_digits, rest} = consume_hex([], rest)
    {value, ""} = Integer.parse(hex_digits, 16)
    tokenize(rest, [{:literal, value} | acc])
  end

  defp tokenize([?\\, ?x, d1, d2 | rest], acc) do
    {hex, ""} = Integer.parse(<<d1, d2>>, 16)
    tokenize(rest, [{:literal, hex} | acc])
  end

  defp tokenize([?\\, ?b | _rest], _acc) do
    raise UnsupportedToken, token: <<?\\, ?b>>
  end

  defp tokenize([?\\, char | rest], acc) do
    cond do
      Map.has_key?(@escaped_symbols, char) -> @escaped_symbols[char]
      char in @special_symbols -> char
      true -> nil
    end
    |> case do
      nil -> raise UnsupportedToken, token: <<?\\, char>>
      value -> tokenize(rest, [{:literal, value} | acc])
    end
  end

  defp tokenize([?[, ?^ | rest], acc) do
    {items, remaining} = character_class(rest)
    tokenize(remaining, [{:character_class, :negative, items} | acc])
  end

  defp tokenize([?[ | rest], acc) do
    {items, remaining} = character_class(rest)
    tokenize(remaining, [{:character_class, :positive, items} | acc])
  end

  # Nothing else matched, treat as literal
  defp tokenize([char | rest], acc), do: tokenize(rest, [literal(char) | acc])

  # We can have nested groups inside, keep track of how many rparens left we have to see
  # until reaching the last one
  defp discard_zero_width_assertion(str, rparens_left \\ 0)

  defp discard_zero_width_assertion([?\\, ?) | rest], rparens_left) do
    discard_zero_width_assertion(rest, rparens_left)
  end

  defp discard_zero_width_assertion([?\\, ?( | rest], rparens_left) do
    discard_zero_width_assertion(rest, rparens_left)
  end

  defp discard_zero_width_assertion([?( | rest], rparens_left) do
    discard_zero_width_assertion(rest, rparens_left + 1)
  end

  defp discard_zero_width_assertion([?) | rest], 0), do: rest

  defp discard_zero_width_assertion([?) | rest], rparens_left) when rparens_left > 0 do
    discard_zero_width_assertion(rest, rparens_left - 1)
  end

  defp discard_zero_width_assertion([_ | rest], rparens_left) do
    discard_zero_width_assertion(rest, rparens_left)
  end

  defp discard_named_group([?> | rest]), do: rest
  defp discard_named_group([_ | rest]), do: discard_named_group(rest)

  defp discard_comment([?\\, ?) | rest]), do: discard_comment(rest)
  defp discard_comment([?) | rest]), do: rest
  defp discard_comment([_ | rest]), do: discard_comment(rest)

  defp atomic_group([?| | rest], acc) do
    # Discard until we find the closing ')'. Then put the accumulated values
    # back and tokenize everything
    Enum.reverse([?) | acc]) ++ discard_rest_of_group(rest)
  end

  # Special case when there was no "|"
  defp atomic_group([?) | rest], acc), do: Enum.reverse([?) | acc]) ++ rest

  defp atomic_group([??, c | rest], acc), do: atomic_group(rest, [c, ?? | acc])
  defp atomic_group([c | rest], acc), do: atomic_group(rest, [c | acc])

  defp discard_rest_of_group([?) | rest]), do: rest
  defp discard_rest_of_group([?\\, _escaped | rest]), do: discard_rest_of_group(rest)
  defp discard_rest_of_group([_char | rest]), do: discard_rest_of_group(rest)

  # When inside character class "[]" everything is considered as literal except
  # for ranges like [a-z] and character classes like \w
  @spec character_class(binary()) :: {list(token()), binary()}
  defp character_class(pattern), do: character_class(pattern, [])
  defp character_class([?] | rest], items), do: {Enum.reverse(items), rest}

  defp character_class([?\\, ?- | rest], items) do
    character_class(rest, [{:literal, ?-} | items])
  end

  defp character_class([char1, ?-, ?] | rest], items) do
    {Enum.reverse([{:literal, ?-}, {:literal, char1} | items]), rest}
  end

  defp character_class([low, ?-, high | rest], items) when low <= high do
    character_class(rest, [{:range, {low, high}} | items])
  end

  defp character_class([low, ?-, high | _] = _pattern, _items) when low > high do
    raise UnsupportedToken, token: <<low, ?-, high>>
  end

  defp character_class([?\\, s | rest], items) when s in @meta_sequences do
    character_class(rest, [to_meta_sequence(s) | items])
  end

  defp character_class([?\\, s | rest], items) when s in @special_symbols do
    character_class(rest, [literal(s) | items])
  end

  defp character_class([?\\, s | rest], items) do
    character_class(rest, [literal(Map.get(@escaped_symbols, s, s)) | items])
  end

  defp character_class([char | rest], items) do
    character_class(rest, [literal(char) | items])
  end

  @spec to_quantifier(char(), :greedy | :lazy) :: quantifier()
  defp to_quantifier(char, mode \\ :greedy)
  defp to_quantifier(?*, mode), do: quantifier(:star, mode)
  defp to_quantifier(?+, mode), do: quantifier(:plus, mode)
  defp to_quantifier(??, mode), do: quantifier(:question, mode)

  @spec to_meta_sequence(char()) :: meta_sequence()
  defp to_meta_sequence(?w), do: {:meta_sequence, :word}
  defp to_meta_sequence(?W), do: {:meta_sequence, :non_word}
  defp to_meta_sequence(?d), do: {:meta_sequence, :digit}
  defp to_meta_sequence(?D), do: {:meta_sequence, :non_digit}
  defp to_meta_sequence(?s), do: {:meta_sequence, :space}
  defp to_meta_sequence(?S), do: {:meta_sequence, :non_space}
  defp to_meta_sequence(?h), do: {:meta_sequence, :blank}
  defp to_meta_sequence(?H), do: {:meta_sequence, :non_blank}
  defp to_meta_sequence(?v), do: {:meta_sequence, :vertical_space}
  defp to_meta_sequence(?V), do: {:meta_sequence, :non_vertical_space}

  @spec repetitions(String.t()) :: nil | {String.t(), quantifier()}
  def repetitions(quantifier) when is_list(quantifier) do
    quantifier_str = to_string(quantifier)
    regex = ~r/^{(\d*),(\d*)}(\?)?|{(\d*)}(\?)?/

    case Regex.run(regex, quantifier_str) do
      nil ->
        nil

      [s, "", "", "", exact] ->
        exact = String.to_integer(exact)
        {to_codepoints(s), quantifier(exact, exact, quantifier_mode_greedy())}

      [s, "", "", "", exact, "?"] ->
        exact = String.to_integer(exact)
        {to_codepoints(s), quantifier(exact, exact, quantifier_mode_lazy())}

      [s, "", high] ->
        {to_codepoints(s), quantifier(0, String.to_integer(high), quantifier_mode_greedy())}

      [s, "", high, "?"] ->
        {to_codepoints(s), quantifier(0, String.to_integer(high), quantifier_mode_lazy())}

      [s, low, ""] ->
        {to_codepoints(s), quantifier(String.to_integer(low), nil, quantifier_mode_greedy())}

      [s, low, "", "?"] ->
        {to_codepoints(s), quantifier(String.to_integer(low), nil, quantifier_mode_lazy())}

      [s, low, high] ->
        {to_codepoints(s),
         quantifier(String.to_integer(low), String.to_integer(high), quantifier_mode_greedy())}

      [s, low, high, "?"] ->
        {to_codepoints(s),
         quantifier(String.to_integer(low), String.to_integer(high), quantifier_mode_lazy())}
    end
  end

  defp add_empty(tokenized), do: add_empty(tokenized, [])

  defp add_empty([], acc), do: acc

  defp add_empty([:union, prec | rest], acc) when prec in [:lparen, :line_start, :string_start] do
    add_empty(rest, [prec, :empty, :union | acc])
  end

  defp add_empty([suc, :union | rest], acc) when suc in [:rparen, :line_end, :string_end] do
    add_empty(rest, [:union, :empty, suc | acc])
  end

  defp add_empty([head | rest], acc), do: add_empty(rest, [head | acc])

  defp add_concat(tokenized), do: add_concat(tokenized, [])
  defp add_concat([], acc), do: acc
  defp add_concat([elem], acc), do: [elem | acc]

  defp add_concat([head, next | rest], acc) do
    # Since the result is currently reversed we have to check backwards, meaning
    # if the `head` can start an expression and `next` can end it
    if can_end?(next) and can_start?(head) do
      add_concat([next | rest], [:concat, head | acc])
    else
      add_concat([next | rest], [head | acc])
    end
  end

  defp can_end?(:rparen), do: true
  defp can_end?({:literal, _}), do: true
  defp can_end?({:meta_sequence, _}), do: true
  defp can_end?({:character_class, _, _}), do: true
  defp can_end?(:any_character), do: true
  defp can_end?({:quantifier, _, _}), do: true
  defp can_end?(:line_start), do: true
  defp can_end?(:string_start), do: true
  defp can_end?(_), do: false

  defp can_start?(:lparen), do: true
  defp can_start?({:literal, _}), do: true
  defp can_start?({:meta_sequence, _}), do: true
  defp can_start?({:character_class, _, _}), do: true
  defp can_start?(:any_character), do: true
  defp can_start?(:line_end), do: true
  defp can_start?(:string_end), do: true
  defp can_start?({:non_token, _}), do: true
  defp can_start?(_), do: false

  defp consume_hex(acc, [?} | rest]), do: {Enum.reverse(acc) |> to_string(), rest}
  defp consume_hex(acc, [d | rest]), do: consume_hex([d | acc], rest)

  defp to_codepoints(str) when is_binary(str) do
    for <<c::utf8 <- str>>, do: c
  end
end
