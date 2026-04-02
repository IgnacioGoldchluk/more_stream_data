defmodule MoreStreamData.RegexGen.Tokenizer.MetadataTest do
  use ExUnit.Case
  alias MoreStreamData.RegexGen.Tokenizer.Metadata

  describe "new/2" do
    test "sets anchor_start? if pattern begins with '\\A' regardless of multiline option" do
      assert %Metadata{anchor_start?: true} = Metadata.new(~r/\A\d+/)
      assert %Metadata{anchor_start?: true} = Metadata.new(~r/\A\d+/m)
    end

    test "sets anchor_end? if pattern ends with '\\z' regardless of multiline option" do
      assert %Metadata{anchor_end?: true} = Metadata.new(~r/\d+\z/)
      assert %Metadata{anchor_end?: true} = Metadata.new(~r/\d+\z/m)
    end

    test "sets anchor_start? if pattern begins with '^' and is not multiline" do
      assert %Metadata{anchor_end?: false, anchor_start?: true} = Metadata.new(~r/^\d+/)
    end

    test "sets anchor_end? if pattern ends with '$' and is not multiline" do
      assert %Metadata{anchor_end?: true, anchor_start?: true} = Metadata.new(~r/^\d+$/)
    end

    test "does not set anchor_end? when pattern ends with literal '$'" do
      assert %Metadata{anchor_end?: false} = Metadata.new(~r/[a-z]+\$/)
    end

    test "does not set anchor_start? if regex is multiline" do
      assert %Metadata{anchor_start?: false, line_start?: true} = Metadata.new(~r/^[a-z]+/m)
    end

    test "does not set anchor_end? if regex is multiline" do
      assert %Metadata{anchor_end?: false, line_end?: true} = Metadata.new(~r/[a-z]+$/m)
    end

    test "sets anchor_stat? if regex contains 'firstline' modifier" do
      assert %Metadata{anchor_start?: true} = Metadata.new(~r/[a-z]+/f)
    end
  end
end
