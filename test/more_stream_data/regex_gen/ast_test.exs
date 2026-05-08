defmodule MoreStreamData.RegexGen.ASTTest do
  use ExUnit.Case

  alias MoreStreamData.RegexGen.{AST, Tokenizer}

  describe "parse" do
    test "parses multiple unions" do
      pattern = ~r/a|b|c/

      expected =
        {:union,
         {
           {:union, {{:literal, ~c"a"}, {:literal, ~c"b"}}},
           {:literal, ~c"c"}
         }}

      assert matches_ast(pattern, expected)
    end

    test "converts meta characters to AST" do
      pattern = ~r/.\d?[A-Z]/

      expected =
        {
          :concat,
          {
            {:concat,
             {:any_character, {:quantifier, :question, :greedy, {:meta_sequence, :digit}}}},
            {:character_class, :positive, [range: {65, 90}]}
          }
        }

      matches_ast(pattern, expected)
    end

    test "converts a tokenized regex to an AST" do
      pattern = ~r/a(a|b)+/

      expected =
        {:concat,
         {{:literal, ~c"a"},
          {:quantifier, :plus, :greedy, {:union, {{:literal, ~c"a"}, {:literal, ~c"b"}}}}}}

      matches_ast(pattern, expected)
    end

    test "collapses sequences of literals" do
      pattern = ~r/ab(cd)*/

      expected =
        {:concat, {{:literal, ~c"ab"}, {:quantifier, :star, :greedy, {:literal, ~c"cd"}}}}

      matches_ast(pattern, expected)
    end

    test "collapses long sequence of literals" do
      pattern = ~r/abcdefg[^ab]/

      expected =
        {:concat,
         {{:literal, ~c"abcdefg"},
          {:character_class, :negative, [{:literal, ?a}, {:literal, ?b}]}}}

      matches_ast(pattern, expected)
    end
  end

  defp matches_ast(pattern, expected) do
    assert expected == pattern |> Regex.source() |> Tokenizer.tokenize() |> AST.parse()
  end
end
