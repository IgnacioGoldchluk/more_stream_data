defmodule MoreStreamData.DurationTest do
  use ExUnit.Case, async: true

  describe "normalize/1" do
    test "converts second, minute, hour, day, week to seconds" do
      assert MoreStreamData.Duration.normalize(%{second: 1}) == %{second: 1}
      assert MoreStreamData.Duration.normalize(%{minute: 1}) == %{second: 60}
      assert MoreStreamData.Duration.normalize(%{hour: 1}) == %{second: 3600}
      assert MoreStreamData.Duration.normalize(%{minute: 1, hour: 1}) == %{second: 3660}
      assert MoreStreamData.Duration.normalize(%{day: 1}) == %{second: 86_400}
      assert MoreStreamData.Duration.normalize(%{week: 1}) == %{second: 604_800}
    end

    test "converts year and month to month" do
      assert MoreStreamData.Duration.normalize(%{month: 1}) == %{month: 1}
      assert MoreStreamData.Duration.normalize(%{year: 1, month: -2}) == %{month: 10}
    end

    test "considers both second and month units" do
      assert MoreStreamData.Duration.normalize(%{year: 2, hour: 1}) == %{second: 3600, month: 24}
    end

    test "microseconds are included as is" do
      us = {100, 3}
      assert MoreStreamData.Duration.normalize(%{microsecond: us}) == %{microsecond: us}
    end
  end
end
