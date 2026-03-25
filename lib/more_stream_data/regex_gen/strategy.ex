defmodule MoreStreamData.RegexGen.Strategy do
  @moduledoc false

  alias MoreStreamData.RegexGen.{AST, Tokenizer}

  @word Enum.concat([Enum.to_list(?a..?z), Enum.to_list(?A..?Z), Enum.to_list(?0..?9), [?_]])
  @non_word 32..255
            |> Enum.filter(fn char ->
              String.printable?(<<char>>) and not Enum.member?(@word, char)
            end)

  @doc """
  Generates values for the given regex
  """
  @spec from_regex(String.t() | Regex.t()) :: StreamData.t(String.t())
  def from_regex(regex) do
    regex |> Tokenizer.tokenize!() |> AST.parse() |> from_ast()
  end

  defp from_ast({:literal, value}), do: StreamData.constant(AST.stringify(value))
  defp from_ast({:union, {opt1, opt2}}), do: StreamData.one_of([from_ast(opt1), from_ast(opt2)])

  defp from_ast({:concat, {left, right}}) do
    StreamData.map(StreamData.tuple({from_ast(left), from_ast(right)}), fn {l, r} -> l <> r end)
  end

  # We still have to pass the modifiers to know what values to generate.
  # - /u (unicode) => insetad of :ascii everything should be :printable
  # - /i (case insensitive) => uppercase or lowercase segments of the string
  # - /s (DOTALL) => :any_character should include everything
  # - /E (export) => ignore
  # - /U (ungreedy) => switches the lazy/greedy approach. Ignore since it's unused (but test)
  # - /f (firstline) => ignore for now since we don't support multiline
  # - /x (extended) => ignore for now, never seen in prod?
  # - /m (multiline) => ^$ become "line" delimites and are replaced with \A,\z. Do not support
  # for now
  defp from_ast({:meta_sequence, :word}), do: StreamData.member_of(@word) |> to_str()
  defp from_ast({:meta_sequence, :digit}), do: StreamData.integer(?0..?9) |> to_str()
  defp from_ast({:meta_sequence, :blank}), do: StreamData.constant(32) |> to_str()
  defp from_ast({:meta_sequence, :space}), do: StreamData.member_of(spaces()) |> to_str()
  defp from_ast({:meta_sequence, :non_word}), do: StreamData.member_of(@non_word) |> to_str()

  defp from_ast({:meta_sequence, :vertical_space}) do
    StreamData.member_of(verticals()) |> to_str()
  end

  defp from_ast({:meta_sequence, :non_vertical_space}) do
    StreamData.codepoint(:ascii) |> StreamData.filter(&(&1 not in verticals())) |> to_str()
  end

  defp from_ast({:meta_sequence, :non_digit}) do
    StreamData.codepoint(:ascii) |> StreamData.filter(&(&1 not in digit())) |> to_str()
  end

  defp from_ast({:meta_sequence, :non_blank}) do
    StreamData.codepoint(:ascii) |> StreamData.filter(&(&1 != 32)) |> to_str()
  end

  defp from_ast({:meta_sequence, :non_space}) do
    StreamData.codepoint(:ascii) |> StreamData.filter(&(&1 not in spaces())) |> to_str()
  end

  defp from_ast(:any_character) do
    StreamData.codepoint(:ascii) |> StreamData.filter(&(&1 not in newlines())) |> to_str()
  end

  defp from_ast({:range, {low, high}}), do: StreamData.integer(low..high) |> to_str()

  defp from_ast({:character_class, :positive, set}) do
    set |> Enum.map(&from_ast/1) |> StreamData.one_of()
  end

  defp from_ast({:character_class, :negative, set}) do
    MapSet.difference(all_values(), all_values(set))
    |> Enum.map(fn char -> <<char>> end)
    |> Enum.filter(&String.printable?/1)
    |> StreamData.member_of()
  end

  defp from_ast({:quantifier, quantifier, _greedy_lazy, expression}) do
    StreamData.list_of(from_ast(expression), list_opts(quantifier))
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
  defp spaces, do: MapSet.new([?\r, ?\n, ?\t, ?\f, ?\v, 32])
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
  defp all_values({:meta_sequence, :blank}), do: MapSet.new([32])
  defp all_values({:meta_sequence, :non_blank}), do: not_values(MapSet.new([32]))
  defp all_values({:range, {low, high}}), do: MapSet.new(low..high)
  defp all_values({:literal, val}), do: MapSet.new([val])

  defp all_values, do: MapSet.new(32..255)

  @spec not_values(MapSet.t()) :: MapSet.t()
  defp not_values(other), do: MapSet.difference(all_values(), other)
end
