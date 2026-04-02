defmodule MoreStreamData.RegexGen.ASTTest do
  use ExUnit.Case

  alias MoreStreamData.RegexGen.{AST, Tokenizer}

  describe "parse" do
    test "parses multiple unions" do
      pattern = ~r/a|b|c/

      expected =
        {:union,
         {
           {:union, {{:literal, "a"}, {:literal, "b"}}},
           {:literal, "c"}
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
         {{:literal, "a"},
          {:quantifier, :plus, :greedy, {:union, {{:literal, "a"}, {:literal, "b"}}}}}}

      matches_ast(pattern, expected)
    end

    test "collapses sequences of literals" do
      pattern = ~r/ab(cd)*/
      expected = {:concat, {{:literal, "ab"}, {:quantifier, :star, :greedy, {:literal, "cd"}}}}
      matches_ast(pattern, expected)
    end

    test "collapses long sequence of literals" do
      pattern = ~r/abcdefg[^ab]/

      expected =
        {:concat,
         {{:literal, "abcdefg"}, {:character_class, :negative, [{:literal, ?a}, {:literal, ?b}]}}}

      matches_ast(pattern, expected)
    end
  end

  defp matches_ast(pattern, expected) do
    {:ok, tokens} = pattern |> Regex.source() |> Tokenizer.tokenize()
    assert expected == AST.parse(tokens)
  end
end
