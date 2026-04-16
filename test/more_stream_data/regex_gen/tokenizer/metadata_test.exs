defmodule MoreStreamData.RegexGen.Tokenizer.MetadataTest do
  use ExUnit.Case
  alias MoreStreamData.RegexGen.Tokenizer.Metadata

  describe "new/2" do
    test "sets anchor_start? if pattern begins with '\\A' regardless of multiline option" do
      assert %Metadata{anchor_start?: true} = Metadata.new([:string_start], [])
      assert %Metadata{anchor_start?: true} = Metadata.new([:string_start], [:multiline])
    end

    test "sets anchor_end? if pattern ends with '\\z' regardless of multiline option" do
      assert %Metadata{anchor_end?: true} = Metadata.new([:string_end], [])
      assert %Metadata{anchor_end?: true} = Metadata.new([:string_end], [:multiline])
    end

    test "sets anchor_start? if pattern begins with '^' and is not multiline" do
      assert %Metadata{anchor_end?: false, anchor_start?: true} = Metadata.new([:line_start], [])
    end

    test "sets anchor_end? if pattern ends with '$' and is not multiline" do
      assert %Metadata{anchor_end?: true, anchor_start?: true} =
               Metadata.new([:line_start, :line_end], [])
    end

    test "does not set anchor_start? if regex is multiline" do
      assert %Metadata{anchor_start?: false, line_start?: true} =
               Metadata.new([:line_start], [:multiline])
    end

    test "does not set anchor_end? if regex is multiline" do
      assert %Metadata{anchor_end?: false, line_end?: true} =
               Metadata.new([:line_end], [:multiline])
    end

    test "sets anchor_stat? if regex contains 'firstline' modifier" do
      assert %Metadata{anchor_start?: true} = Metadata.new([], [:firstline])
    end
  end
end
