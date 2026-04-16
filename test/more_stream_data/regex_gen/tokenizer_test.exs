defmodule MoreStreamData.RegexGen.TokenizerTest do
  use ExUnit.Case

  alias MoreStreamData.RegexGen.Tokenizer

  test "parses empty string" do
    assert matches_tokens(~r//, [])
  end

  describe "special quantifiers" do
    test "tokenizes special quantifiers" do
      pattern = ~r/abc*d+e?f*?g+?h??/

      expected = [
        {:literal, ?a},
        :concat,
        {:literal, ?b},
        :concat,
        {:literal, ?c},
        {:quantifier, :star, :greedy},
        :concat,
        {:literal, ?d},
        {:quantifier, :plus, :greedy},
        :concat,
        {:literal, ?e},
        {:quantifier, :question, :greedy},
        :concat,
        {:literal, ?f},
        {:quantifier, :star, :lazy},
        :concat,
        {:literal, ?g},
        {:quantifier, :plus, :lazy},
        :concat,
        {:literal, ?h},
        {:quantifier, :question, :lazy}
      ]

      assert matches_tokens(pattern, expected)
    end
  end

  describe "concrete repetition ranges" do
    test "ignores when '{' is a literal character" do
      pattern = ~r/ab{cd/

      expected = [
        {:literal, ?a},
        :concat,
        {:literal, ?b},
        :concat,
        {:literal, ?{},
        :concat,
        {:literal, ?c},
        :concat,
        {:literal, ?d}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "tokenizes ranges as range tuple with min and max" do
      pattern = ~r/a{1,}b{,2}c{6}d{10,11}e{15,20}?ff{8}?gh{,50}?i{1,}?/

      expected = [
        {:literal, ?a},
        {:quantifier, {1, nil}, :greedy},
        :concat,
        {:literal, ?b},
        {:quantifier, {0, 2}, :greedy},
        :concat,
        {:literal, ?c},
        {:quantifier, {6, 6}, :greedy},
        :concat,
        {:literal, ?d},
        {:quantifier, {10, 11}, :greedy},
        :concat,
        {:literal, ?e},
        {:quantifier, {15, 20}, :lazy},
        :concat,
        {:literal, ?f},
        :concat,
        {:literal, ?f},
        {:quantifier, {8, 8}, :lazy},
        :concat,
        {:literal, ?g},
        :concat,
        {:literal, ?h},
        {:quantifier, {0, 50}, :lazy},
        :concat,
        {:literal, ?i},
        {:quantifier, {1, nil}, :lazy}
      ]

      assert matches_tokens(pattern, expected)
    end
  end

  describe "metadata" do
    test "includes '^' at the beginning of the pattern" do
      pattern = ~r/^[A-Z]+_[a-z]+/ |> Regex.source()

      expected = [
        :line_start,
        :concat,
        {:character_class, :positive, [{:range, {65, 90}}]},
        {:quantifier, :plus, :greedy},
        :concat,
        {:literal, 95},
        :concat,
        {:character_class, :positive, [{:range, {97, 122}}]},
        {:quantifier, :plus, :greedy}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "includes '$' at the end of the pattern" do
      pattern = ~r/[A-Z]+_[a-z]+$/ |> Regex.source()

      expected = [
        {:character_class, :positive, [range: {?A, ?Z}]},
        {:quantifier, :plus, :greedy},
        :concat,
        {:literal, ?_},
        :concat,
        {:character_class, :positive, [range: {?a, ?z}]},
        {:quantifier, :plus, :greedy},
        :concat,
        :line_end
      ]

      assert matches_tokens(pattern, expected)
    end

    test "line delimiters in unions" do
      pattern = ~r/^a$|^b$/

      expected =
        [
          :line_start,
          :concat,
          {:literal, ?a},
          :concat,
          :line_end,
          :union,
          :line_start,
          :concat,
          {:literal, ?b},
          :concat,
          :line_end
        ]

      assert matches_tokens(pattern, expected)
    end

    test "treats '^' and '$' as literal characters when escaped" do
      pattern = ~r/^ab\^cd\$ef$/

      expected = [
        :line_start,
        :concat,
        {:literal, ?a},
        :concat,
        {:literal, ?b},
        :concat,
        {:literal, ?^},
        :concat,
        {:literal, ?c},
        :concat,
        {:literal, ?d},
        :concat,
        {:literal, ?$},
        :concat,
        {:literal, ?e},
        :concat,
        {:literal, ?f},
        :concat,
        :line_end
      ]

      assert matches_tokens(pattern, expected)
    end

    test "^ and $ in character class don't need to be escaped" do
      pattern = ~r/ab[c^$]+/

      expected = [
        {:literal, ?a},
        :concat,
        {:literal, ?b},
        :concat,
        {:character_class, :positive, [{:literal, ?c}, {:literal, ?^}, {:literal, ?$}]},
        {:quantifier, :plus, :greedy}
      ]

      assert matches_tokens(pattern, expected)
    end
  end

  describe "meta sequences" do
    test "are recognized inside and outside character classes" do
      pattern = ~r/(\w+)\s*[\d\w]+/

      expected = [
        :lparen,
        {:meta_sequence, :word},
        {:quantifier, :plus, :greedy},
        :rparen,
        :concat,
        {:meta_sequence, :space},
        {:quantifier, :star, :greedy},
        :concat,
        {:character_class, :positive, [{:meta_sequence, :digit}, {:meta_sequence, :word}]},
        {:quantifier, :plus, :greedy}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "negative meta sequences are considered" do
      pattern = ~r/\w\W[^\S\D]/

      expected = [
        {:meta_sequence, :word},
        :concat,
        {:meta_sequence, :non_word},
        :concat,
        {:character_class, :negative,
         [{:meta_sequence, :non_space}, {:meta_sequence, :non_digit}]}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "new blank special sequence are considered" do
      pattern = ~r/\h\H[\Ha]/

      expected = [
        {:meta_sequence, :blank},
        :concat,
        {:meta_sequence, :non_blank},
        :concat,
        {:character_class, :positive, [{:meta_sequence, :non_blank}, {:literal, ?a}]}
      ]

      assert matches_tokens(pattern, expected)
    end
  end

  describe "special characters" do
    test "\\x is parsed as literal hex" do
      pattern = ~r/ab\x123\x{F}\x{Fa}/

      expected = [
        {:literal, ?a},
        :concat,
        {:literal, ?b},
        :concat,
        {:literal, 0x12},
        :concat,
        {:literal, ?3},
        :concat,
        {:literal, 0xF},
        :concat,
        {:literal, 0xFA}
      ]

      assert matches_tokens(pattern, expected)
    end

    test ". and | are parsed as special characters" do
      pattern = ~r/a.|.b/

      expected = [
        {:literal, ?a},
        :concat,
        :any_character,
        :union,
        :any_character,
        :concat,
        {:literal, ?b}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "escaping \\ does not consider the next character special" do
      pattern = ~r/\\./
      expected = [{:literal, ?\\}, :concat, :any_character]
      assert matches_tokens(pattern, expected)
    end

    test "escaping [ and ] does not create a character_class" do
      pattern = ~r/a\[a-z\]/

      expected = [
        {:literal, ?a},
        :concat,
        {:literal, ?[},
        :concat,
        {:literal, ?a},
        :concat,
        {:literal, ?-},
        :concat,
        {:literal, ?z},
        :concat,
        {:literal, ?]}
      ]

      assert matches_tokens(pattern, expected)
    end

    test ". and | are escaped in character classes" do
      pattern = ~r/[.|a]*/
      pattern2 = ~r/[\.\|a]*/

      expected = [
        {:character_class, :positive, [{:literal, ?.}, {:literal, ?|}, {:literal, ?a}]},
        {:quantifier, :star, :greedy}
      ]

      assert matches_tokens(pattern, expected)
      assert matches_tokens(pattern2, expected)
    end

    test "negative character class with reversed range returns error" do
      pattern = "[^9-0]"
      assert {:error, "Character range is out of order", _} = Tokenizer.tokenize(pattern)
    end

    test "escaped '-' in character class is parsed as literal" do
      regex = ~r/[\-]/
      assert matches_tokens(regex, [{:character_class, :positive, [{:literal, ?-}]}])
    end

    test "'-' at the end of the character class is parsed as literal" do
      pattern = ~r/[\s.-]/

      assert matches_tokens(pattern, [
               {:character_class, :positive,
                [{:meta_sequence, :space}, {:literal, ?.}, {:literal, ?-}]}
             ])
    end
  end

  describe "character ranges" do
    test "are not parsed outside of character class" do
      pattern = ~r/a-z/
      expected = [{:literal, ?a}, :concat, {:literal, ?-}, :concat, {:literal, ?z}]
      assert matches_tokens(pattern, expected)
    end

    test "are converted to range inside character class" do
      pattern = ~r/0x[\dA-Fa-f]+/

      expected = [
        {:literal, ?0},
        :concat,
        {:literal, ?x},
        :concat,
        {:character_class, :positive,
         [{:meta_sequence, :digit}, {:range, {?A, ?F}}, {:range, {?a, ?f}}]},
        {:quantifier, :plus, :greedy}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "returns error when range is out of order" do
      assert {:error, "Character range is out of order", _} = Tokenizer.tokenize("[z-a]")
    end
  end

  describe "non-printable characters" do
    test "useless escaping a character returns an error" do
      pattern = "\\m"
      assert {:error, "unsupported escaped symbol: 109", _} = Tokenizer.tokenize(pattern)
    end

    test "are tokenized as literals with their ASCII value" do
      pattern = ~r/\v\V\t\a[\0\r\n\f\c\e]/

      expected = [
        {:meta_sequence, :vertical_space},
        :concat,
        {:meta_sequence, :non_vertical_space},
        :concat,
        {:literal, ?\t},
        :concat,
        {:literal, ?\a},
        :concat,
        {:character_class, :positive,
         [
           {:literal, ?\0},
           {:literal, ?\r},
           {:literal, ?\n},
           {:literal, ?\f},
           {:literal, 28},
           {:literal, ?\e}
         ]}
      ]

      assert matches_tokens(pattern, expected)
    end
  end

  describe "groups" do
    test "discard comments" do
      pattern = ~r/\d(?# this is a digit )[a-z]+(?# and these are spaces)e/

      expected = [
        {:meta_sequence, :digit},
        :concat,
        {:character_class, :positive, [range: {?a, ?z}]},
        {:quantifier, :plus, :greedy},
        :concat,
        {:literal, ?e}
      ]

      assert matches_tokens(pattern, expected)
    end

    test "discard non-capturing and named group information" do
      pattern = ~r/ab(?:c)(?<de>fg)/

      expected = [
        {:literal, ?a},
        :concat,
        {:literal, ?b},
        :concat,
        :lparen,
        {:literal, ?c},
        :rparen,
        :concat,
        :lparen,
        {:literal, ?f},
        :concat,
        {:literal, ?g},
        :rparen
      ]

      assert matches_tokens(pattern, expected)
    end
  end

  describe "unsupported options" do
    test "positive lookahead returns error" do
      pattern = ~r/a(?=b)c/ |> Regex.source()
      assert {:error, "positive lookahead unsupported", _} = Tokenizer.tokenize(pattern)
    end

    test "negative lookahead returns error" do
      pattern = ~r/a(?!b)c/ |> Regex.source()
      assert {:error, "negative lookahead unsupported", _} = Tokenizer.tokenize(pattern)
    end

    test "positive lookbehind returns error" do
      pattern = ~r/a(?<=b)c/ |> Regex.source()
      assert {:error, "positive lookbehind unsupported", _} = Tokenizer.tokenize(pattern)
    end

    test "negative lookbehind returns error" do
      pattern = ~r/a(?<!b)c/ |> Regex.source()
      assert {:error, "negative lookbehind unsupported", _} = Tokenizer.tokenize(pattern)
    end

    test "recursive references return error" do
      for pat <- [~r/(\d+)\1/, ~r/(\d+)\g1/, ~r/(?<a>\d+)\k<a>/, ~r/(?<a>\d+)\k{a}/] do
        assert {:error, "recursive reference" <> _, _} = Tokenizer.tokenize(Regex.source(pat))
      end
    end
  end

  describe "atomic group" do
    test "single atomic group" do
      pattern = ~r/a(?>b)c/ |> Regex.source()

      expected = [
        {:literal, ?a},
        :concat,
        :lparen,
        {:literal, ?b},
        :rparen,
        :concat,
        {:literal, ?c}
      ]

      matches_tokens(pattern, expected)
    end

    test "keeps only first matching case" do
      pattern = ~r/a(?>a[a-z]+|b|cdefg)h/

      expected = [
        {:literal, ?a},
        :concat,
        :lparen,
        {:literal, ?a},
        :concat,
        {:character_class, :positive, [range: {?a, ?z}]},
        {:quantifier, :plus, :greedy},
        :rparen,
        :concat,
        {:literal, ?h}
      ]

      matches_tokens(pattern, expected)
    end
  end

  defp matches_tokens(pattern, expected) when is_struct(pattern, Regex) do
    matches_tokens(Regex.source(pattern), expected)
  end

  defp matches_tokens(pattern, expected) when is_binary(pattern) do
    assert {:ok, tokenized} = Tokenizer.tokenize(pattern)
    assert expected == tokenized
  end
end
