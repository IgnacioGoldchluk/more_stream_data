defmodule MoreStreamData.DurationTest do
  use ExUnit.Case, async: true

  describe "normalize/1" do
    test "converts second, minute, hour, day, week to seconds" do
      assert MoreStreamData.Duration.normalize(%{second: 1}) == %{second: 1, month: 0}
      assert MoreStreamData.Duration.normalize(%{minute: 1}) == %{second: 60, month: 0}
      assert MoreStreamData.Duration.normalize(%{hour: 1}) == %{second: 3600, month: 0}
      assert MoreStreamData.Duration.normalize(%{minute: 1, hour: 1}) == %{second: 3660, month: 0}
      assert MoreStreamData.Duration.normalize(%{day: 1}) == %{second: 86_400, month: 0}
      assert MoreStreamData.Duration.normalize(%{week: 1}) == %{second: 604_800, month: 0}
    end

    test "converts year and month to month" do
      assert MoreStreamData.Duration.normalize(%{month: 1}) == %{second: 0, month: 1}
      assert MoreStreamData.Duration.normalize(%{year: 1, month: -2}) == %{second: 0, month: 10}
    end
  end
end
