defmodule MoreStreamData do
  @moduledoc """
  Additional strategies for StreamData
  """

  import Bitwise
  import Decimal, only: [is_decimal: 1]
  import MoreStreamData.Duration, only: [normalize: 1]

  require Decimal

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

    StreamData.integer(0..reserved_bits)
    |> StreamData.map(&(to_ip(fixed_part + &1, version) |> ip_to_string()))
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

  defp ip_from_version(4) do
    StreamData.map(StreamData.integer(0..(2 ** 32 - 1)), &(to_ip(&1, 4) |> ip_to_string()))
  end

  defp ip_from_version(6) do
    StreamData.map(StreamData.integer(0..(2 ** 128 - 1)), &(to_ip(&1, 6) |> ip_to_string()))
  end

  defp ip_to_string(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()

  @doc """
  Generates `Time.t` structures according to the given `options`.

  Shrinks towards `~T[00:00:00]` or the specified `:min`.

  ## Options

    - `:min` - (`Time.t()`) the minimum time to generate
    - `:max` - (`Time.t()`) the maximum time to generate
  """
  @spec time(Keyword.t()) :: StreamData.t(Time.t())
  def time(opts \\ []) when is_list(opts) do
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

  @doc """
  Same as `StreamData.integer/1` but also accepts a single end.

  ## Options

    - `:min` - (`integer()`) the minimum inclusive value
    - `:max` - (`integer()`) the maximum inclusive value
  """
  @spec more_integer(Keyword.t() | Range.t()) :: StreamData.t(integer())
  def more_integer(%Range{} = range), do: StreamData.integer(range)

  def more_integer(opts) when is_list(opts) do
    case {opts[:min], opts[:max]} do
      {nil, nil} -> StreamData.integer()
      {nil, max} -> StreamData.non_negative_integer() |> StreamData.map(&(max - &1))
      {min, nil} -> StreamData.non_negative_integer() |> StreamData.map(&(&1 + min))
      {min, max} when min <= max -> more_integer(min..max)
      {min, max} -> raise ArgumentError, "invalid range: min #{min}, max #{max}"
    end
  end

  def more_integer, do: more_integer(Keyword.new())

  @doc """
  Same as `StreamData.float/1` but also accepts exclusion options

  ## Options

    - `:exclude_min?` - (`boolean()`) whether to exclude the min value if set.
    Defaults to `false`
    - `:exclude_max?` - (`boolean()`) whether to exclude the max value if set.
    Defaults to `false`
  """
  @spec more_float(Keyword.t()) :: StreamData.t(float())
  def more_float(opts \\ []) when is_list(opts) do
    opts = Keyword.merge([exclude_min?: false, exclude_max?: false], opts)
    opts |> StreamData.float() |> maybe_exclude_min(opts) |> maybe_exclude_max(opts)
  end

  defp maybe_exclude_min(strategy, opts) do
    case {opts[:exclude_min?], opts[:min]} do
      {false, _} -> strategy
      {true, min} when is_number(min) -> StreamData.filter(strategy, &(&1 != min))
      {true, nil} -> raise ArgumentError, "exclude_min? set to true without :min specified"
    end
  end

  defp maybe_exclude_max(strategy, opts) do
    case {opts[:exclude_max?], opts[:max]} do
      {false, _} -> strategy
      {true, max} when is_number(max) -> StreamData.filter(strategy, &(&1 != max))
      {true, nil} -> raise ArgumentError, "exclude_max? set to true without :max specified"
    end
  end

  @doc """
  Generates `Decimal.t()` values based on the given `opts`.

  Shrinks towards `0` or the specified `min`

  ## Options

    - `:min` - (`Decimal.t()`) the minimum value to generate
    - `:max` - (`Decimal.t()`) the maximum value to generate
    - `:precision` - (`pos_integer()`) number of decimal places to consider
    - `:allow_nan?` - (`boolean() | nil()`) whether to allow `"NaN"`. If unspecified,
    `"NaN"` is allowed unless both `min` and `max` are specified.
    - `:allow_infinity?` - (`boolean() | nil()`) whether to allow `"±Infinity"`. If unspecified,
    `"±Infinity"` is allowed based on `min` and `max`. If set to `true`, `"±Infinity"` is
    generated even if `:min` and `:max` are specified.
  """
  @spec decimal(Keyword.t()) :: StreamData.t(Decimal.t())
  def decimal(opts \\ []) when is_list(opts) do
    [{15, decimal_gen(opts)}] |> add_nan(opts) |> add_infinity(opts) |> StreamData.frequency()
  end

  defp add_infinity(freqs, opts) do
    case {opts[:allow_infinity?], opts[:min], opts[:max]} do
      {true, _, _} -> [{1, inf()}, {1, neg_inf()} | freqs]
      {false, _, _} -> freqs
      {nil, nil, nil} -> [{1, inf()}, {1, neg_inf()} | freqs]
      {nil, min, nil} when is_decimal(min) -> [{1, inf()} | freqs]
      {nil, nil, max} when is_decimal(max) -> [{1, neg_inf()} | freqs]
      {nil, min, max} when is_decimal(min) and is_decimal(max) -> freqs
    end
  end

  defp add_nan(freqs, opts) do
    case opts[:allow_nan?] do
      true -> [{1, nan()} | freqs]
      false -> freqs
      nil -> if(is_nil(opts[:min]) and is_nil(opts[:max]), do: [{1, nan()} | freqs], else: freqs)
    end
  end

  defp nan, do: StreamData.constant(Decimal.new("NaN"))
  defp inf, do: StreamData.constant(Decimal.new("Infinity"))
  defp neg_inf, do: StreamData.constant(Decimal.new("-Infinity"))

  defp decimal_gen(opts) do
    ctx = %{
      Decimal.Context.get()
      | precision: Keyword.get(opts, :precision, Decimal.Context.get().precision)
    }

    case {opts[:min], opts[:max]} do
      {nil, nil} ->
        StreamData.tuple(
          {StreamData.member_of([1, -1]), StreamData.non_negative_integer(), StreamData.integer()}
        )
        |> StreamData.map(fn {sign, coef, exp} ->
          Decimal.Context.with(ctx, fn -> Decimal.new(sign, coef, adjust_exp(exp)) end)
        end)

      {min, nil} when is_decimal(min) ->
        StreamData.tuple({StreamData.non_negative_integer(), StreamData.integer()})
        |> StreamData.map(fn {coef, exp} ->
          Decimal.Context.with(ctx, fn ->
            Decimal.add(min, Decimal.new(1, coef, adjust_exp(exp)))
          end)
        end)

      {nil, max} when is_decimal(max) ->
        StreamData.tuple({StreamData.non_negative_integer(), StreamData.integer()})
        |> StreamData.map(fn {coef, exp} ->
          Decimal.Context.with(ctx, fn -> Decimal.sub(max, Decimal.new(1, coef, exp)) end)
        end)

      {min, max} when is_decimal(min) and is_decimal(max) ->
        if Decimal.gt?(min, max) do
          raise ArgumentError, "min > max: #{min} > #{max}"
        end

        %Decimal{coef: max_coef, exp: max_exp} = Decimal.sub(max, min)

        StreamData.tuple({StreamData.integer(0..max_coef), more_integer(max: max_exp)})
        |> StreamData.map(fn {coef, exp} ->
          Decimal.Context.with(ctx, fn -> Decimal.add(min, Decimal.new(1, coef, exp)) end)
        end)
    end
  end

  # Otherwise the generated numbers are too large for practical applications
  defp adjust_exp(exp) when exp <= 0, do: exp
  defp adjust_exp(exp), do: :math.log(exp) |> trunc()

  @doc """
  Generates an [IANA Timezone](https://www.iana.org/time-zones)
  """
  @spec timezone :: StreamData.t(Calendar.time_zone())
  def timezone do
    StreamData.member_of(Tzdata.zone_list())
  end

  @doc """
  Generates a `Duration.t()` struct.

  Shrinks towards all values going to 0. Keep in mind the values in
  `Duration.t()` structs can be negative. Therefore calling
  `duration(min: Duration.new!(day: 1))` can generate `Duration.new!(day: -20)`

  ## Options
    - `:min` - (`Duration.t() | Keyword.t()`) the minimum duration to generate.
    - `:max` - (`Duration.t() | Keyword.t()`) the maximum duration to generate.

  Keep in mind that same as `Duration.t()`, units are collapsed into months, seconds
  and microseconds. Therefore passing `min: [week: 5]` can set any value between
  `:microsecond` and `:week`, but `:year` and `:month` are always set to 0. This is
  because there is no conversion from `week` to `month`
  """
  @spec duration(Keyword.t()) :: StreamData.t(Duration.t())
  def duration(opts \\ []) when is_list(opts) do
    case {opts[:min], opts[:max]} do
      {nil, nil} -> unbounded_duration()
      {min, _} when is_list(min) -> duration(Keyword.update!(opts, :min, &Duration.new!/1))
      {_, max} when is_list(max) -> duration(Keyword.update!(opts, :min, &Duration.new!/1))
      {min, max} -> bounded_duration(normalize(min), normalize(max))
    end
  end

  defp unbounded_duration do
    StreamData.fixed_map(%{
      year: StreamData.integer(),
      month: StreamData.integer(),
      day: StreamData.integer(),
      hour: StreamData.integer(),
      minute: StreamData.integer(),
      second: StreamData.integer(),
      microsecond: StreamData.tuple({StreamData.integer(), StreamData.integer(1..6)})
    })
    |> StreamData.map(&(&1 |> Enum.to_list() |> Duration.new!()))
  end

  defp bounded_duration(min, max) do
    StreamData.tuple({bounded_us(min, max), bounded_second(min, max), bounded_month(min, max)})
    |> StreamData.map(fn {us, second, month} ->
      us |> Map.merge(second) |> Map.merge(month) |> Duration.new!()
    end)
  end

  defp bounded_us(%{microsecond: {min_val, p1}}, %{microsecond: {max_val, p2}}) do
    us([min: min_val, max: max_val], max(p1, p2))
  end

  defp bounded_us(_, %{microsecond: {max_val, precision}}), do: us([max: max_val], precision)
  defp bounded_us(%{microsecond: {min_val, precision}}, _), do: us([min: min_val], precision)
  defp bounded_us(_, _), do: StreamData.constant(Map.new())

  defp us(kw, precision) do
    StreamData.fixed_map(%{
      microsecond: StreamData.tuple({more_integer(kw), StreamData.constant(precision)})
    })
  end

  defp bounded_second(%{second: min}, %{second: max}) when min != 0 and max != 0,
    do: second(min: min, max: max)

  defp bounded_second(_, %{second: max}) when max != 0, do: second(max: max)
  defp bounded_second(%{second: min}, _) when min != 0, do: second(min: min)
  defp bounded_second(_, _), do: StreamData.constant(Map.new())

  defp second(kw) do
    StreamData.fixed_map(%{
      week: StreamData.integer(),
      day: StreamData.integer(),
      hour: StreamData.integer(),
      minute: StreamData.integer()
    })
    |> StreamData.bind(fn duration ->
      normalized = normalize(duration)
      kw = Keyword.new(kw, fn {key, value} -> {key, value - normalized[:second]} end)

      StreamData.bind(more_integer(kw), fn second ->
        StreamData.constant(Map.put(duration, :second, second))
      end)
    end)
  end

  defp bounded_month(%{month: min}, %{month: max}) when min != 0 and max != 0,
    do: month(min: min, max: max)

  defp bounded_month(_, %{month: max}) when max != 0, do: month(max: max)
  defp bounded_month(%{month: min}, _) when min != 0, do: month(min: min)
  defp bounded_month(_, _), do: StreamData.constant(Map.new())

  defp month(kw) do
    StreamData.bind(StreamData.fixed_map(%{year: StreamData.integer()}), fn duration ->
      normalized = normalize(duration)
      kw = Keyword.new(kw, fn {key, value} -> {key, value - normalized[:month]} end)

      StreamData.bind(more_integer(kw), fn month ->
        StreamData.constant(Map.put(duration, :month, month))
      end)
    end)
  end
end
