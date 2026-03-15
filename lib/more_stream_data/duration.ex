defmodule MoreStreamData.Duration do
  @moduledoc """
  Utility functions for `Duration.t()` generators
  """

  @s_to_minute 60
  @s_to_hour 60 * @s_to_minute
  @s_to_day 24 * @s_to_hour
  @s_to_week 7 * @s_to_day

  @month_to_year 12

  def normalize(%Duration{} = duration), do: duration |> Map.from_struct() |> normalize()
  def normalize(nil), do: nil

  def normalize(duration) when is_map(duration) do
    Enum.reduce(duration, %{month: 0, second: 0}, fn kv, acc ->
      {unit, value} = normalize(kv)
      Map.update(acc, unit, value, &(&1 + value))
    end)
  end

  def normalize({:microsecond, _} = val), do: val
  def normalize({:year, val}), do: {:month, val * @month_to_year}
  def normalize({:month, _} = val), do: val
  def normalize({:second, _} = val), do: val
  def normalize({:minute, val}), do: {:second, val * @s_to_minute}
  def normalize({:hour, val}), do: {:second, val * @s_to_hour}
  def normalize({:day, val}), do: {:second, val * @s_to_day}
  def normalize({:week, val}), do: {:second, val * @s_to_week}
end
