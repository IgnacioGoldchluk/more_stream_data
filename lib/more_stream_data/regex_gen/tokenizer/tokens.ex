defmodule MoreStreamData.RegexGen.Tokenizer.Tokens do
  @moduledoc false

  @doc """
  Token for a literal character
  """
  def literal(value) when is_integer(value), do: {:literal, value}

  @doc """
  Token for an {m,n} quantifier
  """
  def quantifier(min, max, mode) when is_integer(min) and is_integer(max) and min <= max do
    {:quantifier, {min, max}, mode}
  end

  def quantifier(min, nil, mode) when is_integer(min), do: {:quantifier, {min, nil}, mode}

  def quantifier(special, mode) when special in [:star, :plus, :question],
    do: {:quantifier, special, mode}

  def quantifier_mode_lazy, do: :lazy
  def quantifier_mode_greedy, do: :greedy

  def delimiters, do: [:line_start, :line_end, :string_start, :string_end]
end
