defmodule MoreStreamData.RegexGen.AST do
  @moduledoc false
  alias MoreStreamData.Tokenizer

  @delimiters [:line_start, :line_end, :string_start, :string_end]

  @type ast ::
          {:literal, list(non_neg_integer())}
          | Tokenizer.character_class()
          | {:concat, {ast(), ast()}}
          | {:union, {ast(), ast()}}
          | :any_character
          | :line_start
          | :line_end
          | :string_stat
          | :string_end
          | Tokenizer.meta_sequence()
          | {:quantifier, Tokenizer.special_quantifier() | Tokenizer.range_quantifier(),
             :greedy | :lazy, ast()}

  @doc """
  Converts a tokenized regex to an AST that can later be used as a seed for
  a `StreamData` stategy
  """
  @spec parse([Tokenizer.token()]) :: ast()
  def parse(tokens) do
    [result] = tokens |> build_queue_and_stack() |> reduce_all()
    collapse_literals(result)
  end

  defp build_queue_and_stack(tokens), do: Enum.reduce(tokens, {[], []}, &handle_token/2)

  defp handle_token(token, {output_queue, operator_stack}) do
    if operand?(token) do
      {[token | output_queue], operator_stack}
    else
      case token do
        {:quantifier, range, kind} ->
          [expr | rest] = output_queue
          {[{:quantifier, range, kind, expr} | rest], operator_stack}

        :lparen ->
          {output_queue, [:lparen | operator_stack]}

        :rparen ->
          reduce_until_lparen(output_queue, operator_stack)

        op when op in [:union, :concat] ->
          push_operator(op, output_queue, operator_stack)
      end
    end
  end

  defp push_operator(operator, output_queue, operator_stack) do
    {output_queue, operator_stack} = reduce_operators(output_queue, operator_stack, operator)
    {output_queue, [operator | operator_stack]}
  end

  defp reduce_operators(output_queue, [] = stack, _op), do: {output_queue, stack}
  defp reduce_operators(output_queue, [:lparen | _] = stack, _op), do: {output_queue, stack}

  defp reduce_operators(output_queue, [top | rest] = operator_stack, incoming_op) do
    if precedence(top) >= precedence(incoming_op) do
      reduce_operators(apply_operator(top, output_queue), rest, incoming_op)
    else
      {output_queue, operator_stack}
    end
  end

  # Everything that came before `:lparen` became a single expression
  defp reduce_until_lparen(output_queue, [:lparen | rest]), do: {output_queue, rest}

  defp reduce_until_lparen(output_queue, [op | rest] = _operator_stack) do
    reduce_until_lparen(apply_operator(op, output_queue), rest)
  end

  # Since they are pushed in reverse order, we have the "right" side first. For example
  # "abc" gets pushed as [a] -> [b,a] -> [c,b,a] therefore the right side is the top element
  # This is not important for :union since it's commutative, but :concat must preserve the
  # correct order
  defp apply_operator(:concat, [right, left | rest]), do: [{:concat, {left, right}} | rest]
  defp apply_operator(:union, [right, left | rest]), do: [{:union, {left, right}} | rest]

  defp reduce_all({output_queue, operator_stack}) do
    Enum.reduce(operator_stack, output_queue, &apply_operator/2)
  end

  defp collapse_literals({:concat, {left, right}}) do
    merge_concat(collapse_literals(left), collapse_literals(right))
  end

  defp collapse_literals({:literal, value}), do: {:literal, to_list(value)}

  defp collapse_literals({:union, {left, right}}) do
    {:union, {collapse_literals(left), collapse_literals(right)}}
  end

  defp collapse_literals({:quantifier, val, type, subpattern}) do
    {:quantifier, val, type, collapse_literals(subpattern)}
  end

  defp collapse_literals(other), do: other

  defp merge_concat({:literal, l}, {:literal, r}), do: {:literal, to_list(l) ++ to_list(r)}

  defp merge_concat({:literal, l}, {:concat, {{:literal, r1}, r2}}) do
    merge_concat({:literal, to_list(l) ++ to_list(r1)}, r2)
  end

  defp merge_concat({:concat, l1, {:literal, l2}}, {:literal, r}) do
    merge_concat(l1, {:literal, to_list(l2) ++ to_list(r)})
  end

  defp merge_concat(l, r), do: {:concat, {l, r}}

  defp operand?({:literal, _}), do: true
  defp operand?(:any_character), do: true
  defp operand?({:meta_sequence, _}), do: true
  defp operand?({:character_class, _, _}), do: true
  defp operand?(char) when char in @delimiters, do: true
  defp operand?(_), do: false

  defp precedence(:concat), do: 2
  defp precedence(:union), do: 1

  defp to_list(c) when is_list(c), do: c
  defp to_list(c) when is_integer(c), do: [c]
end
