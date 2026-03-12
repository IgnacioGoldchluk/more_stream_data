defmodule MoreStreamData do
  @moduledoc """
  Additional strategies for StreamData
  """

  import Bitwise

  @doc """
  Generates an IPv4 or IPv6 address as a string

  ## Options:

    - `:version`. Either `4` or `6`. If unspecified it generates both values.
    - `:network`. A string representing an IPv4 network or an IPv6 network, such
    as `"123.111.0.0/16"` or `"1234:3210::/16`. If specified, only IPs in the given
    range are generated.

    In case both `:version` and `:network` are specified, the version must match the network
  """
  @spec ip_address(Keyword.t()) :: String.t()
  def ip_address(opts \\ []) when is_list(opts) do
    case {opts[:version], opts[:network]} do
      {v, nil} when v in [4, 6] -> ip_from_version(v)
      {nil, ip_range} when is_binary(ip_range) -> ip_from_range(ip_range)
      {v, ip_range} when v in [4, 6] and is_binary(ip_range) -> ip_from_range(ip_range, v)
      {nil, nil} -> StreamData.one_of([ip_from_version(4), ip_from_version(6)])
    end
  end

  defp ip_from_range(ip_range, version \\ nil) do
    with [prefix, size] <- String.split(ip_range, "/"),
         {:ok, base_ip} <- :inet.parse_address(to_charlist(prefix)),
         {size, ""} <- Integer.parse(size) do
      if not is_nil(version) and version != version(base_ip) do
        raise ArgumentError, "IP version and network don't match: #{version} vs #{ip_range}"
      end

      gen_ip_from_range(base_ip, size)
    else
      _ -> raise ArgumentError, "invalid IP range received: #{ip_range}"
    end
  end

  defp gen_ip_from_range(ip, fixed_size) do
    version = version(ip)
    freedom = bits(version) - fixed_size
    fixed_part = to_number(ip, version)

    reserved_bits = 2 ** freedom - 1

    if (fixed_part &&& reserved_bits) != 0 do
      raise ArgumentError, "network contains bits set in mask: #{inspect(ip)}/#{fixed_size}"
    end

    StreamData.map(
      StreamData.integer(0..reserved_bits),
      &ip_to_string(to_ip(fixed_part + &1, version))
    )
  end

  defp to_number(ip, version) do
    shift_step = part_size(version)
    parts = parts(version)

    ip
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {val, idx}, acc -> acc + (val <<< (shift_step * (parts - 1 - idx))) end)
  end

  defp to_ip(num, version) when is_number(num) do
    part_size = part_size(version)
    mask = 2 ** part_size - 1

    {ip, 0} =
      Enum.reduce(1..parts(version), {[], num}, fn _, {acc, leftover} ->
        {[leftover &&& mask | acc], leftover >>> part_size}
      end)

    List.to_tuple(ip)
  end

  defp version(ip) when tuple_size(ip) == 4, do: 4
  defp version(ip) when tuple_size(ip) == 8, do: 6

  defp parts(4), do: 4
  defp parts(6), do: 8

  defp part_size(4), do: 8
  defp part_size(6), do: 16

  defp bits(4), do: 32
  defp bits(6), do: 128

  # A bit repetitive but whatever
  defp ip_from_version(4) do
    StreamData.tuple({
      StreamData.integer(0..255),
      StreamData.integer(0..255),
      StreamData.integer(0..255),
      StreamData.integer(0..255)
    })
    |> StreamData.map(&ip_to_string/1)
  end

  defp ip_from_version(6) do
    StreamData.tuple({
      StreamData.integer(0..65535),
      StreamData.integer(0..65535),
      StreamData.integer(0..65535),
      StreamData.integer(0..65535),
      StreamData.integer(0..65535),
      StreamData.integer(0..65535),
      StreamData.integer(0..65535),
      StreamData.integer(0..65535)
    })
    |> StreamData.map(&ip_to_string/1)
  end

  defp ip_to_string(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()

  @doc """
  Generates `Time.t/0` structures according to the given `options` or `time_range`.

  Shrinks towards `~T[00:00:00]` the specified `:min`.

  ## Options

    - `:min` - (`Time.t/0`) the minimum time to generate
    - `:max` - (`Time.t/0`) the maximum time to generate
  """
  @spec time(Keyword.t()) :: StreamData.t(Time.t())
  def time(opts \\ []) do
    min = Keyword.get_lazy(opts, :min, &min_time/0)
    max = Keyword.get_lazy(opts, :max, &max_time/0)

    if Time.after?(min, max) do
      raise ArgumentError, "min time > max time: #{min} > #{max}"
    end

    0..Time.diff(max, min, :microsecond)
    |> StreamData.integer()
    |> StreamData.map(&Time.add(min, &1, :microsecond))
  end

  defp max_time, do: Time.new!(23, 59, 59, 999_999)
  defp min_time, do: Time.new!(0, 0, 0, 0)
end
