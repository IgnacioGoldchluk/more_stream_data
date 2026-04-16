defmodule MoreStreamData.RegexGen.StrategyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias MoreStreamData.RegexGen.Strategy

  property "single character regex" do
    pattern = ~r/[a-zA-Z0-9_-]/

    check all regex <- Strategy.from_regex(pattern, []) do
      assert Regex.match?(pattern, regex)
    end
  end

  property "generates the same string when regex pattern with literals is provided" do
    check all regex <- StreamData.string(:alphanumeric, min_length: 1),
              str <- Strategy.from_regex(regex, []) do
      assert Regex.match?(Regex.compile!(regex), str)
    end
  end

  property "generates one of the options when union is provided" do
    check all opt1 <- StreamData.string(:alphanumeric, min_length: 1),
              opt2 <- StreamData.string(:alphanumeric, min_length: 2),
              opt3 <- StreamData.string(:alphanumeric, min_length: 3),
              str <- Strategy.from_regex("^(#{opt1}|#{opt2}|#{opt3})$", []) do
      assert Enum.any?([opt1, opt2, opt3], fn opt -> opt == str end)
    end
  end

  property "range with exact length generates strings of the specified length" do
    check all len <- StreamData.positive_integer(),
              str <- Strategy.from_regex("^\\d{#{len}}$", []) do
      assert String.length(str) == len
      assert String.to_integer(str) |> is_number()
    end
  end

  property "range with unspecified max length generates strings of at least min length" do
    check all min_length <- StreamData.positive_integer(),
              str <- Strategy.from_regex("\\w{#{min_length},}", []) do
      assert String.length(str) >= min_length
    end
  end

  describe "special quantifiers" do
    property "'+' generates regex of length >= 1" do
      check all str <- Strategy.from_regex("^\\W+$", []) do
        assert String.length(str) >= 1
      end
    end

    property "'?' generates regex of length <= 1" do
      check all str <- Strategy.from_regex("^\\s?$", []) do
        assert String.length(str) <= 1
      end
    end
  end

  property "'.' generates anything except for line breaks" do
    check all str <- Strategy.from_regex("^.+$", character_set: :printable) do
      str
      |> String.graphemes()
      |> Enum.each(fn c -> refute Enum.member?(["\n", "\r"], c) end)
    end
  end

  describe "character class" do
    property "generates from literals" do
      check all literals <- StreamData.string(:alphanumeric, min_length: 1),
                str <- Strategy.from_regex("^[#{literals}]+$", []) do
        codepoints = String.codepoints(literals)

        assert String.length(str) >= 1

        str
        |> String.codepoints()
        |> Enum.each(fn codepoint -> assert codepoint in codepoints end)
      end
    end

    property "negative character class rejects elements" do
      check all str <- Strategy.from_regex("^[^a-zA-Z]$", []) do
        str
        |> to_charlist()
        |> Enum.each(fn char ->
          refute Enum.member?(?a..?z, char) or Enum.member?(?A..?Z, char)
        end)
      end
    end

    test "negative '\D' generates digits" do
      [str] = Strategy.from_regex(~r/^[^\D]{100}$/, []) |> Enum.take(1)
      assert String.length(str) == 100

      digits = Enum.to_list(?0..?9)

      str
      |> to_charlist()
      |> Enum.each(fn char -> assert Enum.member?(digits, char) end)
    end

    test "negative '\d' generates everything except digits" do
      [str] = Strategy.from_regex(~r/^[^\d]{100}$/, []) |> Enum.take(1)
      assert String.length(str) == 100

      digits = Enum.to_list(?0..?9)

      str
      |> to_charlist()
      |> Enum.each(fn char -> refute Enum.member?(digits, char) end)
    end

    test "negative literals" do
      [str] = Strategy.from_regex(~r/^[^abcdefghijklmnopqrstuvwxyz]{100}$/, []) |> Enum.take(1)
      assert String.length(str) == 100
      invalid_range = Enum.to_list(?a..?z)

      str
      |> to_charlist()
      |> Enum.each(fn char -> refute Enum.member?(invalid_range, char) end)
    end

    test "negative spaces and blank does not contains spaces" do
      [str] = Strategy.from_regex(~r/^[^\s\h]{100}$/, []) |> Enum.take(1)
      assert String.length(str) == 100

      spaces = [?\r, ?\n, ?\t, ?\f, ?\v, 32]

      str
      |> to_charlist()
      |> Enum.each(fn char -> refute Enum.member?(spaces, char) end)
    end

    test "negative non spaces and non blank only generates spaces and blank" do
      [str] = Strategy.from_regex(~r/^[^\S\H]{100}$/, []) |> Enum.take(1)

      assert String.length(str) == 100
      spaces = [?\r, ?\n, ?\t, ?\f, ?\v, 32]

      str
      |> to_charlist()
      |> Enum.each(fn char -> assert Enum.member?(spaces, char) end)
    end

    test "negative word generates non word" do
      [str] = Strategy.from_regex(~r/^[^\w]{100}$/, []) |> Enum.take(1)

      words =
        Enum.concat([Enum.to_list(?a..?z), Enum.to_list(?A..?Z), Enum.to_list(?0..?9), [?_]])

      str
      |> to_charlist()
      |> Enum.each(fn char -> refute Enum.member?(words, char) end)
    end

    test "negative non word generates  word" do
      [str] = Strategy.from_regex(~r/^[^\W]{100}$/, []) |> Enum.take(1)

      words =
        Enum.concat([Enum.to_list(?a..?z), Enum.to_list(?A..?Z), Enum.to_list(?0..?9), [?_]])

      str
      |> to_charlist()
      |> Enum.each(fn char -> assert Enum.member?(words, char) end)
    end
  end

  describe "meta sequences" do
    test ":vertical_space and :non_vertical_space generate from line breaks" do
      samples = Strategy.from_regex("^\v\V$", []) |> Enum.take(10)

      verticals = [?\n, ?\v, ?\r, ?\f]

      samples
      |> Enum.map(&to_charlist/1)
      |> Enum.each(fn [vertical, non_vertical] ->
        assert Enum.member?(verticals, vertical)
        refute Enum.member?(verticals, non_vertical)
      end)
    end

    test "blank only generates whitespace" do
      x = Strategy.from_regex("^\\h{1,20}$", []) |> Enum.take(20)

      Enum.each(x, fn str -> assert String.trim(str) |> String.length() == 0 end)
    end

    property ":non_digit does not generate digits" do
      check all str <- Strategy.from_regex("^\\D*$", character_set: :printable) do
        str
        |> String.graphemes()
        |> Enum.each(fn codepoint ->
          refute Enum.member?(String.graphemes("0123456789"), codepoint)
        end)
      end
    end

    property ":non_space does not generate spaces" do
      check all str <- Strategy.from_regex("^\\S*$", character_set: :printable) do
        str
        |> String.graphemes()
        |> Enum.each(fn codepoint ->
          refute Enum.member?(["\r", "\n", "\t", "\f", "\v", " "], codepoint)
        end)
      end
    end
  end

  property "concatenates special characters" do
    check all str <- Strategy.from_regex("^\\d[a-z]$", character_set: :printable) do
      [c1, c2] = to_charlist(str)
      assert c1 in ?0..?9
      assert c2 in ?a..?z
    end
  end

  property "only includes printable characters when character_set: :printable" do
    check all str <- Strategy.from_regex(~r/.{200}/, character_set: :printable) do
      assert String.printable?(str)
    end
  end

  describe "anchors" do
    property "$ and ^ are allowed multiple times in unions" do
      regex = ~r/^asd$|^def$/

      check all str <- Strategy.from_regex(regex, []) do
        assert Regex.match?(regex, str)
      end
    end

    property "can generate additional text after regex if '$' is not specified" do
      check all str <- Strategy.from_regex(~r/^asd/, []) do
        assert String.starts_with?(str, "asd")
        assert String.length(str) >= 3
      end
    end

    property "can generate additional text before regex if '^' is not specified" do
      check all str <- Strategy.from_regex(~r/asd$/, []) do
        assert String.ends_with?(str, "asd")
        assert String.length(str) >= 3
      end
    end
  end
end
