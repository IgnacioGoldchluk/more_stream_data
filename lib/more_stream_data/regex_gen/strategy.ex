defmodule MoreStreamData.RegexGen.Strategy do
  @moduledoc false

  alias MoreStreamData.RegexGen.{AST, Tokenizer}
  alias MoreStreamData.Utils

  alias MoreStreamData.RegexGen.Tokenizer.Metadata

  @word Enum.concat([Enum.to_list(?a..?z), Enum.to_list(?A..?Z), Enum.to_list(?0..?9), [?_]])
  @non_word 32..255
            |> Enum.filter(fn char ->
              String.printable?(<<char>>) and not Enum.member?(@word, char)
            end)

  @whitespace ~c"\r\n\t\v\f\s"

  @doc """
  Generates values for the given regex
  """
  @spec from_regex(String.t() | Regex.t(), Keyword.t()) :: StreamData.t(String.t())
  def from_regex(regex, opts) when is_struct(regex, Regex) do
    options = parse_opts(regex, opts)
    source = Regex.source(regex)
    pattern = if(:extended in options[:regex_opts], do: remove_extended(source), else: source)

    metadata = Metadata.new(pattern, Regex.opts(regex))

    {:ok, tokens} = Tokenizer.tokenize(pattern)

    tokens
    |> AST.parse()
    |> from_ast(options)
    |> apply_caseless(options)
    |> apply_anchors(metadata, options)
  end

  def from_regex(regex, opts) when is_binary(regex), do: from_regex(Regex.compile!(regex), opts)

  defp parse_opts(regex, opts) do
    default = [character_set: :all]
    default |> Keyword.merge(opts) |> Keyword.put(:regex_opts, Regex.opts(regex))
  end

  defp from_ast({:literal, value}, _opts), do: StreamData.constant(AST.stringify(value))

  defp from_ast({:union, {pat1, pat2}}, opts),
    do: StreamData.one_of([from_ast(pat1, opts), from_ast(pat2, opts)])

  defp from_ast({:concat, {left, right}}, opts) do
    StreamData.tuple({from_ast(left, opts), from_ast(right, opts)})
    |> StreamData.map(fn {l, r} -> l <> r end)
  end

  # We still have to pass the modifiers to know what values to generate.
  # - /u (unicode) => insetad of :ascii everything should be :printable
  defp from_ast({:meta_sequence, :word}, _), do: StreamData.member_of(@word) |> to_str()
  defp from_ast({:meta_sequence, :digit}, _), do: StreamData.integer(?0..?9) |> to_str()
  defp from_ast({:meta_sequence, :blank}, _), do: StreamData.constant(32) |> to_str()
  defp from_ast({:meta_sequence, :space}, _), do: StreamData.member_of(spaces()) |> to_str()
  defp from_ast({:meta_sequence, :non_word}, _), do: StreamData.member_of(@non_word) |> to_str()

  defp from_ast({:meta_sequence, :vertical_space}, _) do
    StreamData.member_of(verticals()) |> to_str()
  end

  defp from_ast({:meta_sequence, :non_vertical_space}, opts) do
    ascii_codepoint(opts[:character_set])
    |> StreamData.filter(&(&1 not in verticals()))
    |> to_str()
  end

  defp from_ast({:meta_sequence, :non_digit}, opts) do
    ascii_codepoint(opts[:character_set])
    |> StreamData.filter(&(&1 not in digit()))
    |> to_str()
  end

  defp from_ast({:meta_sequence, :non_blank}, opts) do
    ascii_codepoint(opts[:character_set]) |> StreamData.filter(&(&1 != 32)) |> to_str()
  end

  defp from_ast({:meta_sequence, :non_space}, opts) do
    ascii_codepoint(opts[:character_set])
    |> StreamData.filter(&(&1 not in spaces()))
    |> to_str()
  end

  defp from_ast(:any_character, opts) do
    if :dotall in opts[:regex_opts] do
      ascii_codepoint(opts[:character_set]) |> to_str()
    else
      ascii_codepoint(opts[:character_set])
      |> StreamData.filter(&(&1 not in newlines()))
      |> to_str()
    end
  end

  defp from_ast({:range, {low, high}}, _), do: StreamData.integer(low..high) |> to_str()

  defp from_ast({:character_class, :positive, set}, opts) do
    set |> Enum.map(&from_ast(&1, opts)) |> StreamData.one_of()
  end

  defp from_ast({:character_class, :negative, set}, _opts) do
    MapSet.difference(all_values(), all_values(set))
    |> Enum.map(fn char -> <<char>> end)
    |> Enum.filter(&String.printable?/1)
    |> StreamData.member_of()
  end

  defp from_ast({:quantifier, quantifier, _greedy_lazy, expression}, opts) do
    StreamData.list_of(from_ast(expression, opts), list_opts(quantifier))
    |> StreamData.map(&Enum.join/1)
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

  defp to_str(stream), do: StreamData.map(stream, fn char -> <<char>> end)

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
  defp apply_caseless(regex_gen, opts) do
    if(:caseless in opts[:regex_opts], do: Utils.recase(regex_gen), else: regex_gen)
  end

  defp apply_anchors(regex_gen, metadata, opts) do
    regex_gen
    |> prepend_str(metadata, opts)
    |> append_str(metadata, opts)
  end

  # Prepend cases
  # anchor_start?: true -> can't add anything
  # line_start?: true -> can add lines
  # both false -> can add anything
  defp prepend_str(regex_gen, %Metadata{anchor_start?: true}, _), do: regex_gen

  defp prepend_str(regex_gen, %Metadata{line_start?: true}, opts) do
    StreamData.bind(regex_gen, fn str ->
      ascii_string(opts[:character_set])
      |> StreamData.list_of()
      |> StreamData.map(fn lines -> Enum.join(lines ++ [str], "\n") end)
    end)
  end

  defp prepend_str(regex_gen, %Metadata{}, opts) do
    StreamData.bind(regex_gen, fn str ->
      ascii_string(opts[:character_set])
      |> StreamData.map(fn text -> text <> str end)
    end)
  end

  # Same case as prepend
  defp append_str(regex_gen, %Metadata{anchor_end?: true}, _), do: regex_gen

  defp append_str(regex_gen, %Metadata{line_end?: true}, opts) do
    StreamData.bind(regex_gen, fn str ->
      ascii_string(opts[:character_set])
      |> StreamData.list_of()
      |> StreamData.map(fn lines -> Enum.join([str | lines], "\n") end)
    end)
  end

  defp append_str(regex_gen, %Metadata{}, opts) do
    StreamData.bind(regex_gen, fn str ->
      ascii_string(opts[:character_set])
      |> StreamData.map(fn text -> str <> text end)
    end)
  end

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

  defp ascii_string(:all), do: StreamData.string(extended_ascii())

  defp ascii_string(:printable) do
    extended_ascii() |> Enum.filter(&printable?/1) |> StreamData.string()
  end

  defp ascii_codepoint(:all), do: StreamData.integer(0..255)

  defp ascii_codepoint(:printable),
    do: Enum.filter(0..255, &printable?/1) |> StreamData.member_of()

  defp extended_ascii, do: Enum.to_list(extended_ascii_range())

  defp extended_ascii_range, do: 0..255

  defp printable?(c) when is_integer(c), do: String.printable?(<<c>>)
end
