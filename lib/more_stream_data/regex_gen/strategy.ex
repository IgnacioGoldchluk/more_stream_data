defmodule MoreStreamData.RegexGen.Strategy do
  @moduledoc false

  alias MoreStreamData.RegexGen.{AST, Tokenizer}
  alias MoreStreamData.Utils

  alias MoreStreamData.RegexGen.Tokenizer.{Metadata, Tokens}

  @word Enum.concat([Enum.to_list(?a..?z), Enum.to_list(?A..?Z), Enum.to_list(?0..?9), [?_]])
  @non_word 32..255
            |> Enum.filter(fn char ->
              String.printable?(<<char>>) and not Enum.member?(@word, char)
            end)

  @extended_ascii Enum.to_list(0..255)
  @extended_ascii_printable Enum.filter(@extended_ascii, &String.printable?(<<&1>>))

  @whitespace ~c"\r\n\t\v\f\s"

  @doc """
  Generates values for the given regex
  """
  @spec from_regex(String.t() | Regex.t(), Keyword.t()) :: StreamData.t(String.t())
  def from_regex(regex, opts) when is_struct(regex, Regex) do
    options = parse_opts(regex, opts)
    source = Regex.source(regex)
    pattern = if(:extended in options[:regex_opts], do: remove_extended(source), else: source)

    {:ok, tokens} = Tokenizer.tokenize(pattern)
    {non_tokens, tokens} = split_tokens(tokens)

    tokens
    |> AST.parse()
    |> from_ast(options)
    |> StreamData.map(&to_string_and_metadata(&1, options))
    |> apply_caseless(options)
    |> filter_if_zero_width_assertions(non_tokens, regex)
    |> apply_anchors(options)
  end

  def from_regex(regex, opts) when is_binary(regex), do: from_regex(Regex.compile!(regex), opts)

  defp parse_opts(regex, opts) do
    default = [character_set: :all]
    default |> Keyword.merge(opts) |> Keyword.put(:regex_opts, Regex.opts(regex))
  end

  defp from_ast(:empty, _), do: StreamData.constant([])
  defp from_ast({:literal, value}, _opts), do: StreamData.constant(value)

  defp from_ast({:union, {pat1, pat2}}, opts),
    do: StreamData.one_of([from_ast(pat1, opts), from_ast(pat2, opts)])

  defp from_ast({:concat, {left, right}}, opts) do
    StreamData.tuple({from_ast(left, opts), from_ast(right, opts)})
    |> StreamData.map(fn {l, r} -> to_list(l) ++ to_list(r) end)
  end

  # We still have to pass the modifiers to know what values to generate.
  # '/u' -> use :printable from StreamData instead of ascii
  defp from_ast({:meta_sequence, :word}, _), do: StreamData.member_of(@word)
  defp from_ast({:meta_sequence, :digit}, _), do: StreamData.integer(?0..?9)
  defp from_ast({:meta_sequence, :blank}, _), do: StreamData.constant(32)
  defp from_ast({:meta_sequence, :space}, _), do: StreamData.member_of(spaces())
  defp from_ast({:meta_sequence, :non_word}, _), do: StreamData.member_of(@non_word)
  defp from_ast({:meta_sequence, :vertical_space}, _), do: StreamData.member_of(verticals())

  defp from_ast({:meta_sequence, :non_vertical_space}, opts) do
    ascii_codepoint(opts[:character_set])
    |> StreamData.filter(&(&1 not in verticals()))
  end

  defp from_ast({:meta_sequence, :non_digit}, opts) do
    ascii_codepoint(opts[:character_set])
    |> StreamData.filter(&(&1 not in digit()))
  end

  defp from_ast({:meta_sequence, :non_blank}, opts) do
    ascii_codepoint(opts[:character_set]) |> StreamData.filter(&(&1 != 32))
  end

  defp from_ast({:meta_sequence, :non_space}, opts) do
    ascii_codepoint(opts[:character_set]) |> StreamData.filter(&(&1 not in spaces()))
  end

  defp from_ast(:any_character, opts) do
    if :dotall in opts[:regex_opts] do
      ascii_codepoint(opts[:character_set])
    else
      ascii_codepoint(opts[:character_set])
      |> StreamData.filter(&(&1 not in newlines()))
    end
  end

  defp from_ast({:range, {low, high}}, _), do: StreamData.integer(low..high)

  defp from_ast({:character_class, :positive, set}, opts) do
    set |> Enum.map(&from_ast(&1, opts)) |> StreamData.one_of()
  end

  defp from_ast({:character_class, :negative, set}, _opts) do
    MapSet.difference(all_values(), all_values(set))
    |> Enum.filter(&String.printable?(<<&1>>))
    |> StreamData.member_of()
  end

  defp from_ast({:quantifier, quantifier, _greedy_lazy, expression}, opts) do
    StreamData.list_of(from_ast(expression, opts), list_opts(quantifier))
  end

  # Workaround for line/string delimiters
  defp from_ast(delimiter, _)
       when delimiter in [:line_start, :line_end, :string_start, :string_end] do
    StreamData.constant(delimiter)
  end

  defp list_opts(:star), do: []
  defp list_opts(:plus), do: [min_length: 1]
  defp list_opts(:question), do: [max_length: 1]
  defp list_opts({m, m}), do: [length: m]

  defp list_opts({m, n}) do
    Keyword.reject([min_length: m, max_length: n], fn {_k, v} -> is_nil(v) end)
  end

  defp newlines, do: MapSet.new([?\n, ?\r])
  defp spaces, do: MapSet.new(@whitespace)
  defp verticals, do: MapSet.new([?\n, ?\v, ?\r, ?\f])
  defp digit, do: MapSet.new(?0..?9)

  defp all_values(classes) when is_list(classes) do
    classes |> Enum.map(&all_values/1) |> Enum.reduce(&MapSet.union/2)
  end

  defp all_values({:meta_sequence, :digit}), do: digit()
  defp all_values({:meta_sequence, :non_digit}), do: not_values(digit())
  defp all_values({:meta_sequence, :space}), do: spaces()
  defp all_values({:meta_sequence, :non_space}), do: not_values(spaces())
  defp all_values({:meta_sequence, :word}), do: MapSet.new(@word)
  defp all_values({:meta_sequence, :non_word}), do: MapSet.new(@non_word)
  defp all_values({:meta_sequence, :blank}), do: MapSet.new([?\s])
  defp all_values({:meta_sequence, :non_blank}), do: not_values(MapSet.new([?\s]))
  defp all_values({:range, {low, high}}), do: MapSet.new(low..high)
  defp all_values({:literal, val}), do: MapSet.new([val])

  defp all_values, do: MapSet.new(32..255)

  @spec not_values(MapSet.t()) :: MapSet.t()
  defp not_values(other), do: MapSet.difference(all_values(), other)

  # Modifiers and metadata
  defp apply_caseless(regex_metadata_gen, opts) do
    if :caseless in opts[:regex_opts] do
      StreamData.bind(regex_metadata_gen, fn {regex_val, metadata} ->
        StreamData.tuple({Utils.recase(regex_val), StreamData.constant(metadata)})
      end)
    else
      regex_metadata_gen
    end
  end

  defp apply_anchors(regex_metadata_gen, opts) do
    StreamData.bind(regex_metadata_gen, fn {regex_gen, metadata} ->
      StreamData.tuple({to_prepend(metadata, opts), to_append(metadata, opts)})
      |> StreamData.map(fn {prefix, suffix} -> Enum.join([prefix, regex_gen, suffix]) end)
    end)
  end

  # Prepend cases
  # anchor_start?: true -> can't add anything
  # line_start?: true -> can add lines
  # both false -> can add anything
  defp to_prepend(%Metadata{anchor_start?: true}, _), do: StreamData.constant("")

  defp to_prepend(%Metadata{line_start?: true}, opts) do
    StreamData.list_of(ascii_string(opts[:character_set]))
    |> StreamData.map(fn
      [] -> ""
      lines -> Enum.join(lines, "\n") <> "\n"
    end)
  end

  defp to_prepend(%Metadata{}, opts), do: ascii_string(opts[:character_set])

  # Same case as prepend
  defp to_append(%Metadata{anchor_end?: true}, _), do: StreamData.constant("")

  defp to_append(%Metadata{line_end?: true}, opts) do
    StreamData.list_of(ascii_string(opts[:character_set]))
    |> StreamData.map(fn
      [] -> ""
      lines -> "\n" <> Enum.join(lines, "\n")
    end)
  end

  defp to_append(%Metadata{}, opts), do: ascii_string(opts[:character_set])

  def remove_extended(pattern) when is_binary(pattern) do
    strip_ext(pattern, nil, <<>>)
  end

  defp strip_ext(<<>>, _state, acc), do: acc

  # Newline found
  defp strip_ext(<<?\n, rest::binary>>, state, acc) do
    next_state = if(state == :class, do: :class, else: nil)
    strip_ext(rest, next_state, acc)
  end

  # Literals "[" and "#" add them again
  defp strip_ext(<<?\\, ?[, rest::binary>>, nil, acc), do: strip_ext(rest, nil, acc <> "\\[")
  # '#' we can add directly since it does not have a special meaning in regular regex
  defp strip_ext(<<?\\, ?#, rest::binary>>, nil, acc), do: strip_ext(rest, nil, acc <> "#")

  # Special case for (?#), will be deleted later by the tokenizer
  defp strip_ext("(?#" <> rest, nil, acc), do: strip_ext(rest, nil, acc <> "(?#")

  # Enter and exit class
  defp strip_ext(<<?[, rest::binary>>, nil, acc), do: strip_ext(rest, :class, acc <> "[")
  defp strip_ext(<<?], rest::binary>>, :class, acc), do: strip_ext(rest, nil, acc <> "]")

  # Comment, ignore until newline
  defp strip_ext(<<?#, rest::binary>>, state, acc) do
    # We either enter a comment inside a class, a comment or we were already
    # inside a comment and we continue
    next_state = if(is_nil(state), do: :comment, else: state)
    strip_ext(rest, next_state, acc)
  end

  # Anything inside comment, delete
  defp strip_ext(<<_, rest::binary>>, :comment, acc) do
    strip_ext(rest, :comment, acc)
  end

  # Whitespace outisde of class, delete too
  defp strip_ext(<<char, rest::binary>>, nil, acc) when char in @whitespace do
    strip_ext(rest, nil, acc)
  end

  # Anything else is kept
  defp strip_ext(<<chr, rest::binary>>, nil, acc), do: strip_ext(rest, nil, acc <> <<chr>>)

  # Inside class we have to keep everything
  defp strip_ext(<<chr, rest::binary>>, :class, acc), do: strip_ext(rest, :class, acc <> <<chr>>)

  defp ascii_string(:all), do: StreamData.string(@extended_ascii)
  defp ascii_string(:printable), do: StreamData.string(@extended_ascii_printable)

  defp ascii_codepoint(:all), do: StreamData.integer(0..255)
  defp ascii_codepoint(:printable), do: StreamData.member_of(@extended_ascii_printable)

  defp to_list(c) when is_list(c), do: c
  defp to_list(c) when is_integer(c) or is_atom(c), do: [c]

  defp to_string_and_metadata(delimiters_and_codepoints, options)
       when is_list(delimiters_and_codepoints) do
    # Extract all delimiters from the beginning and end of string
    {starts, no_start} = Enum.split_while(delimiters_and_codepoints, &(&1 in Tokens.delimiters()))
    {ends, no_end} = Enum.reverse(no_start) |> Enum.split_with(&(&1 in Tokens.delimiters()))
    codepoints = Enum.reverse(no_end)

    {to_string(codepoints), Metadata.new(starts ++ ends, options[:regex_opts])}
  end

  defp to_string_and_metadata(single_char, options) when is_integer(single_char) do
    to_string_and_metadata([single_char], options)
  end

  defp split_tokens(tokens) when is_list(tokens) do
    {non_tokens, tokens} =
      Enum.split_with(tokens, fn
        {:non_token, _} -> true
        _ -> false
      end)

    {Enum.map(non_tokens, fn {:non_token, val} -> val end), tokens}
  end

  defp filter_if_zero_width_assertions(gen, non_tokens, regex) do
    # We cannot generate from here based on zero width assertions because
    # the algorithm generates per token, it cannot look ahead or behind and
    # perform a conditional filtering. So instead what we do is, if the regex
    # contains a lookaround, we generate the regex normally, and then do a
    # match filter, because it is expected that the supported zero width assertions
    # are very unlikely to throw non-matching regexes
    supported_zwa = [:negative_lookahead, :negaive_lookbehind]

    if Enum.any?(supported_zwa, &(&1 in non_tokens)) do
      StreamData.filter(gen, fn {str, _metadata} -> Regex.match?(regex, str) end)
    else
      gen
    end
  end
end
