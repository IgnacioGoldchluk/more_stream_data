defmodule MoreStreamData do
  @moduledoc """
  Additional generators based on `StreamData`
  """

  import Bitwise
  import Decimal, only: [is_decimal: 1]
  import MoreStreamData.Duration, only: [normalize: 1]

  require Decimal

  alias MoreStreamData.{Domain, RegexGen}

  @doc """
  Generates IPv4 and IPv6 addresses as a string

  ## Options:

    - `:version` - (`4 | 6`) generates IP adresses only of this version. Defaults to
    generating both IPv4 and IPv6.
    - `:network` - (`t:String.t/0`) A string representing an IPv4 network or an IPv6 network, such
    as `"123.111.0.0/16"` or `"1234:3210::/16`. If specified, only IPs in the given
    range are generated.

    In case both `:version` and `:network` are specified, the version must match the network.

    In case `:network` is not set then IPs from [IPv4 Special Registry](https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml)
    and/or [IPv6 Special Registry](https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml)
    are generated alongside random IPs for better edge-case coverage.

  ## Shrinking

    Shrinks towards lower IP addresses. For example
    `ip_address(network: "255.255.255.0/8")` shrinks towards `"255.255.255.0"`
  """
  @spec ip_address(Keyword.t()) :: StreamData.t(String.t())
  def ip_address(opts \\ []) when is_list(opts) do
    case {opts[:version], opts[:network]} do
      {v, nil} when v in [4, 6] ->
        StreamData.one_of([
          ip_from_version(v),
          StreamData.member_of(special_ranges(v)) |> StreamData.bind(&ip_from_range/1)
        ])

      {nil, ip_range} when is_binary(ip_range) ->
        ip_from_range(ip_range)

      {v, ip_range} when v in [4, 6] and is_binary(ip_range) ->
        ip_from_range(ip_range, v)

      {nil, nil} ->
        StreamData.one_of([
          ip_from_version(4),
          ip_from_version(6),
          StreamData.member_of(special_ranges(4)) |> StreamData.bind(&ip_from_range/1),
          StreamData.member_of(special_ranges(6)) |> StreamData.bind(&ip_from_range/1)
        ])
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

  defp special_ranges(4) do
    # From https://www.iana.org/assignments/iana-ipv4-special-registry/
    [
      "0.0.0.0/8",
      "10.0.0.0/8",
      "100.64.0.0/10",
      "127.0.0.0/8",
      "169.254.0.0/16",
      "172.16.0.0/12",
      "192.0.0.0/24",
      "192.0.0.0/29",
      "192.0.0.8/32",
      "192.0.0.9/32",
      "192.0.0.10/32",
      "192.0.0.170/32",
      "192.0.0.171/32",
      "192.0.2.0/24",
      "192.31.196.0/24",
      "192.52.193.0/24",
      "192.88.99.0/24",
      "192.168.0.0/16",
      "192.175.48.0/24",
      "198.18.0.0/15",
      "198.51.100.0/24",
      "203.0.113.0/24",
      "240.0.0.0/4",
      "255.255.255.255/32"
    ]
  end

  defp special_ranges(6) do
    # From https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml
    [
      "::1/128",
      "::/128",
      "::ffff:0:0/96",
      "64:ff9b::/96",
      "64:ff9b:1::/48",
      "100::/64",
      "2001::/23",
      "2001::/32",
      "2001:1::1/128",
      "2001:1::2/128",
      "2001:2::/48",
      "2001:3::/32",
      "2001:4:112::/48",
      "2001:10::/28",
      "2001:20::/28",
      "2001:db8::/32",
      "2002::/16",
      "2620:4f:8000::/48",
      "fc00::/7",
      "fe80::/10"
    ]
  end

  @doc """
  Generates `t:Time.t/0` structs based on the provided `opts`.

  ## Options

    - `:min` - (`t:Time.t/0`) the minimum time to generate (inclusive)
    - `:max` - (`t:Time.t/0`) the maximum time to generate (inclusive)

  ## Shrinking

  Shrinks towards `~T[00:00:00]` or the specified `:min`.
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
  Same as `StreamData.integer/1` but also accepts a single end instead of
  a range.

  ## Options

    - `:min` - (`t:integer/0`) the minimum inclusive value
    - `:max` - (`t:integer/0`) the maximum inclusive value

  ## Shrinking

  If only one of `:min`, `:max` is specified it shrinks toward the specified limit. In any
  other case it behaves as `StreamData.integer/1`
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

  @doc """
  Same as `StreamData.integer/0`
  """
  def more_integer, do: more_integer(Keyword.new())

  @doc """
  Same as `StreamData.float/1` but also accepts exclusion options

  ## Options

    - `:exclude_min?` - (`t:boolean/0`) whether to exclude the min value if set.
    Defaults to `false`
    - `:exclude_max?` - (`t:boolean/0`) whether to exclude the max value if set.
    Defaults to `false`

  ## Shrinking

  Same as `StreamData.float/1` since the additional options don't modify the underlying
  generator
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
  Generates `t:Decimal.t/0` values based on the given `opts`.

  ## Options

    - `:min` - (`t:Decimal.t/0`) the minimum value to generate (inclusive)
    - `:max` - (`t:Decimal.t/0`) the maximum value to generate (inclusive)
    - `:precision` - (`t:pos_integer/0`) maximum number of decimal places
    - `:allow_nan?` - (`boolean() | nil`) whether to allow `"NaN"`. If `nil`, then
    `"NaN"` is allowed unless both `:min` and `:max` are specified.
    - `:allow_infinity?` - (`boolean() | nil()`) whether to allow `"±Infinity"`. If `nil`,
    `"±Infinity"` is allowed based on `:min` and `:max`. If set to `true`, `"±Infinity"` is
    generated even if `:min` and `:max` are specified.

  ## Shrinking

  Shrinks towards `Decimal.new(0)` or `:min` if specified.
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
  Generates an [IANA Timezone](https://www.iana.org/time-zones).
  """
  @spec timezone :: StreamData.t(Calendar.time_zone())
  def timezone do
    StreamData.member_of([
      "Africa/Abidjan",
      "Africa/Accra",
      "Africa/Addis_Ababa",
      "Africa/Algiers",
      "Africa/Asmara",
      "Africa/Asmera",
      "Africa/Bamako",
      "Africa/Bangui",
      "Africa/Banjul",
      "Africa/Bissau",
      "Africa/Blantyre",
      "Africa/Brazzaville",
      "Africa/Bujumbura",
      "Africa/Cairo",
      "Africa/Casablanca",
      "Africa/Ceuta",
      "Africa/Conakry",
      "Africa/Dakar",
      "Africa/Dar_es_Salaam",
      "Africa/Djibouti",
      "Africa/Douala",
      "Africa/El_Aaiun",
      "Africa/Freetown",
      "Africa/Gaborone",
      "Africa/Harare",
      "Africa/Johannesburg",
      "Africa/Juba",
      "Africa/Kampala",
      "Africa/Khartoum",
      "Africa/Kigali",
      "Africa/Kinshasa",
      "Africa/Lagos",
      "Africa/Libreville",
      "Africa/Lome",
      "Africa/Luanda",
      "Africa/Lubumbashi",
      "Africa/Lusaka",
      "Africa/Malabo",
      "Africa/Maputo",
      "Africa/Maseru",
      "Africa/Mbabane",
      "Africa/Mogadishu",
      "Africa/Monrovia",
      "Africa/Nairobi",
      "Africa/Ndjamena",
      "Africa/Niamey",
      "Africa/Nouakchott",
      "Africa/Ouagadougou",
      "Africa/Porto-Novo",
      "Africa/Sao_Tome",
      "Africa/Timbuktu",
      "Africa/Tripoli",
      "Africa/Tunis",
      "Africa/Windhoek",
      "America/Adak",
      "America/Anchorage",
      "America/Anguilla",
      "America/Antigua",
      "America/Araguaina",
      "America/Argentina/Buenos_Aires",
      "America/Argentina/Catamarca",
      "America/Argentina/ComodRivadavia",
      "America/Argentina/Cordoba",
      "America/Argentina/Jujuy",
      "America/Argentina/La_Rioja",
      "America/Argentina/Mendoza",
      "America/Argentina/Rio_Gallegos",
      "America/Argentina/Salta",
      "America/Argentina/San_Juan",
      "America/Argentina/San_Luis",
      "America/Argentina/Tucuman",
      "America/Argentina/Ushuaia",
      "America/Aruba",
      "America/Asuncion",
      "America/Atikokan",
      "America/Atka",
      "America/Bahia",
      "America/Bahia_Banderas",
      "America/Barbados",
      "America/Belem",
      "America/Belize",
      "America/Blanc-Sablon",
      "America/Boa_Vista",
      "America/Bogota",
      "America/Boise",
      "America/Buenos_Aires",
      "America/Cambridge_Bay",
      "America/Campo_Grande",
      "America/Cancun",
      "America/Caracas",
      "America/Catamarca",
      "America/Cayenne",
      "America/Cayman",
      "America/Chicago",
      "America/Chihuahua",
      "America/Ciudad_Juarez",
      "America/Coral_Harbour",
      "America/Cordoba",
      "America/Costa_Rica",
      "America/Coyhaique",
      "America/Creston",
      "America/Cuiaba",
      "America/Curacao",
      "America/Danmarkshavn",
      "America/Dawson",
      "America/Dawson_Creek",
      "America/Denver",
      "America/Detroit",
      "America/Dominica",
      "America/Edmonton",
      "America/Eirunepe",
      "America/El_Salvador",
      "America/Ensenada",
      "America/Fort_Nelson",
      "America/Fort_Wayne",
      "America/Fortaleza",
      "America/Glace_Bay",
      "America/Godthab",
      "America/Goose_Bay",
      "America/Grand_Turk",
      "America/Grenada",
      "America/Guadeloupe",
      "America/Guatemala",
      "America/Guayaquil",
      "America/Guyana",
      "America/Halifax",
      "America/Havana",
      "America/Hermosillo",
      "America/Indiana/Indianapolis",
      "America/Indiana/Knox",
      "America/Indiana/Marengo",
      "America/Indiana/Petersburg",
      "America/Indiana/Tell_City",
      "America/Indiana/Vevay",
      "America/Indiana/Vincennes",
      "America/Indiana/Winamac",
      "America/Indianapolis",
      "America/Inuvik",
      "America/Iqaluit",
      "America/Jamaica",
      "America/Jujuy",
      "America/Juneau",
      "America/Kentucky/Louisville",
      "America/Kentucky/Monticello",
      "America/Knox_IN",
      "America/Kralendijk",
      "America/La_Paz",
      "America/Lima",
      "America/Los_Angeles",
      "America/Louisville",
      "America/Lower_Princes",
      "America/Maceio",
      "America/Managua",
      "America/Manaus",
      "America/Marigot",
      "America/Martinique",
      "America/Matamoros",
      "America/Mazatlan",
      "America/Mendoza",
      "America/Menominee",
      "America/Merida",
      "America/Metlakatla",
      "America/Mexico_City",
      "America/Miquelon",
      "America/Moncton",
      "America/Monterrey",
      "America/Montevideo",
      "America/Montreal",
      "America/Montserrat",
      "America/Nassau",
      "America/New_York",
      "America/Nipigon",
      "America/Nome",
      "America/Noronha",
      "America/North_Dakota/Beulah",
      "America/North_Dakota/Center",
      "America/North_Dakota/New_Salem",
      "America/Nuuk",
      "America/Ojinaga",
      "America/Panama",
      "America/Pangnirtung",
      "America/Paramaribo",
      "America/Phoenix",
      "America/Port-au-Prince",
      "America/Port_of_Spain",
      "America/Porto_Acre",
      "America/Porto_Velho",
      "America/Puerto_Rico",
      "America/Punta_Arenas",
      "America/Rainy_River",
      "America/Rankin_Inlet",
      "America/Recife",
      "America/Regina",
      "America/Resolute",
      "America/Rio_Branco",
      "America/Rosario",
      "America/Santa_Isabel",
      "America/Santarem",
      "America/Santiago",
      "America/Santo_Domingo",
      "America/Sao_Paulo",
      "America/Scoresbysund",
      "America/Shiprock",
      "America/Sitka",
      "America/St_Barthelemy",
      "America/St_Johns",
      "America/St_Kitts",
      "America/St_Lucia",
      "America/St_Thomas",
      "America/St_Vincent",
      "America/Swift_Current",
      "America/Tegucigalpa",
      "America/Thule",
      "America/Thunder_Bay",
      "America/Tijuana",
      "America/Toronto",
      "America/Tortola",
      "America/Vancouver",
      "America/Virgin",
      "America/Whitehorse",
      "America/Winnipeg",
      "America/Yakutat",
      "America/Yellowknife",
      "Antarctica/Casey",
      "Antarctica/Davis",
      "Antarctica/DumontDUrville",
      "Antarctica/Macquarie",
      "Antarctica/Mawson",
      "Antarctica/McMurdo",
      "Antarctica/Palmer",
      "Antarctica/Rothera",
      "Antarctica/South_Pole",
      "Antarctica/Syowa",
      "Antarctica/Troll",
      "Antarctica/Vostok",
      "Arctic/Longyearbyen",
      "Asia/Aden",
      "Asia/Almaty",
      "Asia/Amman",
      "Asia/Anadyr",
      "Asia/Aqtau",
      "Asia/Aqtobe",
      "Asia/Ashgabat",
      "Asia/Ashkhabad",
      "Asia/Atyrau",
      "Asia/Baghdad",
      "Asia/Bahrain",
      "Asia/Baku",
      "Asia/Bangkok",
      "Asia/Barnaul",
      "Asia/Beirut",
      "Asia/Bishkek",
      "Asia/Brunei",
      "Asia/Calcutta",
      "Asia/Chita",
      "Asia/Choibalsan",
      "Asia/Chongqing",
      "Asia/Chungking",
      "Asia/Colombo",
      "Asia/Dacca",
      "Asia/Damascus",
      "Asia/Dhaka",
      "Asia/Dili",
      "Asia/Dubai",
      "Asia/Dushanbe",
      "Asia/Famagusta",
      "Asia/Gaza",
      "Asia/Harbin",
      "Asia/Hebron",
      "Asia/Ho_Chi_Minh",
      "Asia/Hong_Kong",
      "Asia/Hovd",
      "Asia/Irkutsk",
      "Asia/Istanbul",
      "Asia/Jakarta",
      "Asia/Jayapura",
      "Asia/Jerusalem",
      "Asia/Kabul",
      "Asia/Kamchatka",
      "Asia/Karachi",
      "Asia/Kashgar",
      "Asia/Kathmandu",
      "Asia/Katmandu",
      "Asia/Khandyga",
      "Asia/Kolkata",
      "Asia/Krasnoyarsk",
      "Asia/Kuala_Lumpur",
      "Asia/Kuching",
      "Asia/Kuwait",
      "Asia/Macao",
      "Asia/Macau",
      "Asia/Magadan",
      "Asia/Makassar",
      "Asia/Manila",
      "Asia/Muscat",
      "Asia/Nicosia",
      "Asia/Novokuznetsk",
      "Asia/Novosibirsk",
      "Asia/Omsk",
      "Asia/Oral",
      "Asia/Phnom_Penh",
      "Asia/Pontianak",
      "Asia/Pyongyang",
      "Asia/Qatar",
      "Asia/Qostanay",
      "Asia/Qyzylorda",
      "Asia/Rangoon",
      "Asia/Riyadh",
      "Asia/Saigon",
      "Asia/Sakhalin",
      "Asia/Samarkand",
      "Asia/Seoul",
      "Asia/Shanghai",
      "Asia/Singapore",
      "Asia/Srednekolymsk",
      "Asia/Taipei",
      "Asia/Tashkent",
      "Asia/Tbilisi",
      "Asia/Tehran",
      "Asia/Tel_Aviv",
      "Asia/Thimbu",
      "Asia/Thimphu",
      "Asia/Tokyo",
      "Asia/Tomsk",
      "Asia/Ujung_Pandang",
      "Asia/Ulaanbaatar",
      "Asia/Ulan_Bator",
      "Asia/Urumqi",
      "Asia/Ust-Nera",
      "Asia/Vientiane",
      "Asia/Vladivostok",
      "Asia/Yakutsk",
      "Asia/Yangon",
      "Asia/Yekaterinburg",
      "Asia/Yerevan",
      "Atlantic/Azores",
      "Atlantic/Bermuda",
      "Atlantic/Canary",
      "Atlantic/Cape_Verde",
      "Atlantic/Faeroe",
      "Atlantic/Faroe",
      "Atlantic/Jan_Mayen",
      "Atlantic/Madeira",
      "Atlantic/Reykjavik",
      "Atlantic/South_Georgia",
      "Atlantic/St_Helena",
      "Atlantic/Stanley",
      "Australia/ACT",
      "Australia/Adelaide",
      "Australia/Brisbane",
      "Australia/Broken_Hill",
      "Australia/Canberra",
      "Australia/Currie",
      "Australia/Darwin",
      "Australia/Eucla",
      "Australia/Hobart",
      "Australia/LHI",
      "Australia/Lindeman",
      "Australia/Lord_Howe",
      "Australia/Melbourne",
      "Australia/NSW",
      "Australia/North",
      "Australia/Perth",
      "Australia/Queensland",
      "Australia/South",
      "Australia/Sydney",
      "Australia/Tasmania",
      "Australia/Victoria",
      "Australia/West",
      "Australia/Yancowinna",
      "Brazil/Acre",
      "Brazil/DeNoronha",
      "Brazil/East",
      "Brazil/West",
      "CET",
      "CST6CDT",
      "Canada/Atlantic",
      "Canada/Central",
      "Canada/Eastern",
      "Canada/Mountain",
      "Canada/Newfoundland",
      "Canada/Pacific",
      "Canada/Saskatchewan",
      "Canada/Yukon",
      "Chile/Continental",
      "Chile/EasterIsland",
      "Cuba",
      "EET",
      "EST",
      "EST5EDT",
      "Egypt",
      "Eire",
      "Etc/GMT",
      "Etc/GMT+0",
      "Etc/GMT+1",
      "Etc/GMT+10",
      "Etc/GMT+11",
      "Etc/GMT+12",
      "Etc/GMT+2",
      "Etc/GMT+3",
      "Etc/GMT+4",
      "Etc/GMT+5",
      "Etc/GMT+6",
      "Etc/GMT+7",
      "Etc/GMT+8",
      "Etc/GMT+9",
      "Etc/GMT-0",
      "Etc/GMT-1",
      "Etc/GMT-10",
      "Etc/GMT-11",
      "Etc/GMT-12",
      "Etc/GMT-13",
      "Etc/GMT-14",
      "Etc/GMT-2",
      "Etc/GMT-3",
      "Etc/GMT-4",
      "Etc/GMT-5",
      "Etc/GMT-6",
      "Etc/GMT-7",
      "Etc/GMT-8",
      "Etc/GMT-9",
      "Etc/GMT0",
      "Etc/Greenwich",
      "Etc/UCT",
      "Etc/UTC",
      "Etc/Universal",
      "Etc/Zulu",
      "Europe/Amsterdam",
      "Europe/Andorra",
      "Europe/Astrakhan",
      "Europe/Athens",
      "Europe/Belfast",
      "Europe/Belgrade",
      "Europe/Berlin",
      "Europe/Bratislava",
      "Europe/Brussels",
      "Europe/Bucharest",
      "Europe/Budapest",
      "Europe/Busingen",
      "Europe/Chisinau",
      "Europe/Copenhagen",
      "Europe/Dublin",
      "Europe/Gibraltar",
      "Europe/Guernsey",
      "Europe/Helsinki",
      "Europe/Isle_of_Man",
      "Europe/Istanbul",
      "Europe/Jersey",
      "Europe/Kaliningrad",
      "Europe/Kiev",
      "Europe/Kirov",
      "Europe/Kyiv",
      "Europe/Lisbon",
      "Europe/Ljubljana",
      "Europe/London",
      "Europe/Luxembourg",
      "Europe/Madrid",
      "Europe/Malta",
      "Europe/Mariehamn",
      "Europe/Minsk",
      "Europe/Monaco",
      "Europe/Moscow",
      "Europe/Nicosia",
      "Europe/Oslo",
      "Europe/Paris",
      "Europe/Podgorica",
      "Europe/Prague",
      "Europe/Riga",
      "Europe/Rome",
      "Europe/Samara",
      "Europe/San_Marino",
      "Europe/Sarajevo",
      "Europe/Saratov",
      "Europe/Simferopol",
      "Europe/Skopje",
      "Europe/Sofia",
      "Europe/Stockholm",
      "Europe/Tallinn",
      "Europe/Tirane",
      "Europe/Tiraspol",
      "Europe/Ulyanovsk",
      "Europe/Uzhgorod",
      "Europe/Vaduz",
      "Europe/Vatican",
      "Europe/Vienna",
      "Europe/Vilnius",
      "Europe/Volgograd",
      "Europe/Warsaw",
      "Europe/Zagreb",
      "Europe/Zaporozhye",
      "Europe/Zurich",
      "GB",
      "GB-Eire",
      "GMT",
      "GMT+0",
      "GMT-0",
      "GMT0",
      "Greenwich",
      "HST",
      "Hongkong",
      "Iceland",
      "Indian/Antananarivo",
      "Indian/Chagos",
      "Indian/Christmas",
      "Indian/Cocos",
      "Indian/Comoro",
      "Indian/Kerguelen",
      "Indian/Mahe",
      "Indian/Maldives",
      "Indian/Mauritius",
      "Indian/Mayotte",
      "Indian/Reunion",
      "Iran",
      "Israel",
      "Jamaica",
      "Japan",
      "Kwajalein",
      "Libya",
      "MET",
      "MST",
      "MST7MDT",
      "Mexico/BajaNorte",
      "Mexico/BajaSur",
      "Mexico/General",
      "NZ",
      "NZ-CHAT",
      "Navajo",
      "PRC",
      "PST8PDT",
      "Pacific/Apia",
      "Pacific/Auckland",
      "Pacific/Bougainville",
      "Pacific/Chatham",
      "Pacific/Chuuk",
      "Pacific/Easter",
      "Pacific/Efate",
      "Pacific/Enderbury",
      "Pacific/Fakaofo",
      "Pacific/Fiji",
      "Pacific/Funafuti",
      "Pacific/Galapagos",
      "Pacific/Gambier",
      "Pacific/Guadalcanal",
      "Pacific/Guam",
      "Pacific/Honolulu",
      "Pacific/Johnston",
      "Pacific/Kanton",
      "Pacific/Kiritimati",
      "Pacific/Kosrae",
      "Pacific/Kwajalein",
      "Pacific/Majuro",
      "Pacific/Marquesas",
      "Pacific/Midway",
      "Pacific/Nauru",
      "Pacific/Niue",
      "Pacific/Norfolk",
      "Pacific/Noumea",
      "Pacific/Pago_Pago",
      "Pacific/Palau",
      "Pacific/Pitcairn",
      "Pacific/Pohnpei",
      "Pacific/Ponape",
      "Pacific/Port_Moresby",
      "Pacific/Rarotonga",
      "Pacific/Saipan",
      "Pacific/Samoa",
      "Pacific/Tahiti",
      "Pacific/Tarawa",
      "Pacific/Tongatapu",
      "Pacific/Truk",
      "Pacific/Wake",
      "Pacific/Wallis",
      "Pacific/Yap",
      "Poland",
      "Portugal",
      "ROC",
      "ROK",
      "Singapore",
      "Turkey",
      "UCT",
      "US/Alaska",
      "US/Aleutian",
      "US/Arizona",
      "US/Central",
      "US/East-Indiana",
      "US/Eastern",
      "US/Hawaii",
      "US/Indiana-Starke",
      "US/Michigan",
      "US/Mountain",
      "US/Pacific",
      "US/Samoa",
      "UTC",
      "Universal",
      "W-SU",
      "WET",
      "Zulu"
    ])
  end

  @doc """
  Generates a `t:Duration.t/0` struct.

  Shrinks towards all values going to 0. Keep in mind the values in
  `Duration.t()` structs can be negative. Therefore calling
  `duration(min: Duration.new!(day: 1))` can generate `Duration.new!(day: -20)`

  ## Options
    - `:min` - (`t:Duration.t/0` `|` `t:Keyword.t/0`) the minimum duration to generate.
    - `:max` - (`t:Duration.t/0` `|` `t:Keyword.t/0`) the maximum duration to generate.

  Keep in mind that units are collapsed into months, seconds and microseconds.
  Therefore passing `min: [week: 5]` can set any value between `:microsecond` and `:week`,
  but `:year` and `:month` are always set to 0. This is because there is no conversion
  from `week` to `month`.

  ## Shrinking
  Shrinks towards zero values. Keep in mind the values in `t:Duration.t/0` structs
  can be negative. Therefore calling `duration(min: Duration.new!(day: 1))`
  can generate `Duration.new!(day: -20)`
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

  defp bounded_second(%{second: min}, %{second: max}), do: second(min: min, max: max)
  defp bounded_second(_, %{second: max}), do: second(max: max)
  defp bounded_second(%{second: min}, _), do: second(min: min)
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

  defp bounded_month(%{month: min}, %{month: max}), do: month(min: min, max: max)
  defp bounded_month(_, %{month: max}), do: month(max: max)
  defp bounded_month(%{month: min}, _), do: month(min: min)
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

  @doc """
  Generates `t:DateTime.t/0` structs.

  ## Options

    - `:min` - (`t:DateTime.t/0`) if present, only datetimes after this value are generated
    - `:max` - (`t:DateTime.t/0`) if present, only datetimes before this value are generated
    - `:timezone` - (`StreamData.t(String.t())`) timezones generator. If not provided defaults
    to `timezone/0`
    - `:date` - (`StreamData.t(Date.t())`) if present, uses this strategy for the date part
    - `:time` - (`StreamData.t(Time.t())`) if present, uses this strategy for the time part

  If `:min` and/or `:max` are provided then `:date`, `:time` and `:timezone` are ignored

  ## Shrinking

  Shrinks according to the provided options:
  - `:min` and/or `:max` provided -> towards `:min`
  - `:max` provided -> towards `:max`
  - `:date` and/or `:time` provided -> towards the combination of the generators
  - No range provided: towards `DateTime.utc_now/0`
  """
  @spec datetime(Keyword.t()) :: StreamData.t(DateTime.t())
  def datetime(opts \\ []) when is_list(opts) do
    case {opts[:min], opts[:max]} do
      {%DateTime{} = min, %DateTime{} = max} ->
        seconds = DateTime.diff(max, min)

        StreamData.integer(0..seconds)
        |> StreamData.map(&DateTime.add(min, &1, :second, Tzdata.TimeZoneDatabase))

      {%DateTime{} = min, nil} ->
        StreamData.non_negative_integer()
        |> StreamData.map(&DateTime.add(min, &1, :second, Tzdata.TimeZoneDatabase))

      {nil, %DateTime{} = max} ->
        StreamData.non_negative_integer()
        |> StreamData.map(&DateTime.add(max, &1 * -1, :second, Tzdata.TimeZoneDatabase))

      {nil, nil} ->
        unbounded_datetime(opts)
    end
  end

  defp unbounded_datetime(opts) do
    tz_strategy = Keyword.get_lazy(opts, :timezone, fn -> timezone() end)

    if Enum.any?(opts, fn {k, _} -> k in [:date, :time] end) do
      date_strategy = Keyword.get_lazy(opts, :date, fn -> StreamData.date() end)
      time_strategy = Keyword.get_lazy(opts, :time, fn -> time() end)

      StreamData.tuple({date_strategy, time_strategy, tz_strategy})
      |> StreamData.map(fn {date, time, tz} ->
        DateTime.new!(date, time, tz, Tzdata.TimeZoneDatabase)
      end)
    else
      StreamData.map(StreamData.tuple({StreamData.integer(), tz_strategy}), fn {seconds, tz} ->
        DateTime.now!(tz, Tzdata.TimeZoneDatabase)
        |> DateTime.add(seconds, :second, Tzdata.TimeZoneDatabase)
      end)
    end
  end

  @doc """
  Generates valid strings from a given regex.

  The following features are currently unsupported:
  - Lookarounds
  - Atomic groups
  - Backreferences
  - `\\b`
  - [Modifiers](https://hexdocs.pm/elixir/Regex.html#module-modifiers)

  ## Shrinking
  Shrinks towards lower ASCII characters and shorter expressions. For example
  `from_regex(~r/[A-Z]+_[a-z]+/)` shrinks towards `A_a`
  """
  @spec from_regex(Regex.t() | String.t()) :: StreamData.t(String.t())
  def from_regex(regex), do: RegexGen.Strategy.from_regex(regex)

  @doc """
  Generates valid domains according to [RFC-1035](https://datatracker.ietf.org/doc/html/rfc1035)

  Top Level Domains are sampled from the [IANA List](https://data.iana.org/TLD/tlds-alpha-by-domain.txt), excluding
  punycode (`"xn--.*"`) domains

  ## Options

    - `:max_length` - (`t:pos_integer/0`) the maximum length of the entire domain.
    Must be `4 <= :max_length <= 255` as per RFC-1035. Defaults to `255`.
    - `:max_label_length` - (`t:pos_integer/0`) the maximum length of each label.
    Must be `1 <= :max_label_length <= 63` as per RFC-1035. Defaults to `63`.

  ## Shrinking

  Shrinks towards shorter and fewer labels, and to `"com"` top level domain, if allowed by
  `:max_length`
  """
  @spec domain(Keyword.t()) :: StreamData.t(String.t())
  def domain(opts \\ []) do
    opts = validate_domain_opts(opts)

    domain_gen = Domain.domain_gen(Keyword.fetch!(opts, :max_length))
    label_gen = Domain.label_gen(Keyword.fetch!(opts, :max_label_length))

    # Maximum number of subdomains is 126:
    # 1 character subdomain, 1 "." character = 252, leaving 3 characters for TLD + "."
    StreamData.tuple({StreamData.list_of(label_gen, max_length: 126), domain_gen})
    |> StreamData.bind(fn {labels, tld} ->
      StreamData.constant(take_labels(labels, opts[:max_length], tld))
    end)
  end

  defp take_labels(labels, max_length, tld) do
    Enum.reduce_while(labels, tld, fn label, acc ->
      new_acc = label <> "." <> acc
      if(String.length(new_acc) > max_length, do: {:halt, acc}, else: {:cont, new_acc})
    end)
  end

  defp validate_domain_opts(opts) do
    opts = Keyword.merge([max_length: 255, max_label_length: 63], opts)
    max_length = opts[:max_length]
    max_label_length = opts[:max_label_length]

    if max_length not in 4..255 do
      raise ArgumentError, ":max_length must be between [4, 255], got: #{max_length}"
    end

    if max_label_length not in 1..63 do
      raise ArgumentError, ":max_label_length must be between [1, 63], got: #{max_label_length}"
    end

    opts
  end

  @doc """
  Generates valid `http/https` URLs according to [RFC-3986](https://www.rfc-editor.org/rfc/rfc3986.html)

  URLs contain ASCII characters only
  """
  @spec url() :: StreamData.t(String.t())
  def url do
    scheme = StreamData.member_of(["http", "https"])
    port = StreamData.integer(1..65_535) |> StreamData.map(&":#{&1}")

    path =
      ascii_printable()
      |> StreamData.string()
      |> StreamData.map(fn path -> URI.encode(path, &URI.char_unreserved?/1) end)
      |> StreamData.list_of()
      |> StreamData.map(&Enum.join(&1, "/"))

    fragment =
      ascii_printable()
      |> StreamData.string()
      |> StreamData.map(fn fragment -> "##{URI.encode(fragment, &URI.char_unreserved?/1)}" end)

    StreamData.tuple({
      scheme,
      domain(),
      StreamData.one_of([blank(), port]),
      path,
      StreamData.one_of([blank(), fragment])
    })
    |> StreamData.map(fn {scheme, domain, port, path, fragment} ->
      "#{scheme}://#{domain}#{port}/#{path}#{fragment}"
    end)
  end

  defp ascii_printable, do: Enum.filter(0..255, fn char -> String.printable?(<<char>>) end)
  defp blank, do: StreamData.constant("")

  @doc """
  Generates valid email addresses.

  Does not follow RFC-5322. Instead, it generates emails considered valid by the most
  common internet providers. Some differences:
  - Addresses are limited to ASCII characters
  - No double quotes (`"`) allowed
  - No single domain such as `john@doe`
  - No IP address as domain

  ## Options

    - `:domains` - (`StreamData.t(String.t())`) strategy that generates domains. If not
    provided then `domain/1` is used.

  ## Shrinking
  Shrinks towards shorter local parts. The domain part follows `:domains` behaviour.
  """
  @spec email(Keyword.t()) :: StreamData.t(String.t())
  def email(opts \\ []) do
    email_chars()
    |> StreamData.string(min_length: 1, max_length: 64)
    |> StreamData.bind_filter(fn local_non_validated ->
      local = String.trim(local_non_validated, ".") |> String.replace(~r/\.{2,}/, ".")

      if local == "" do
        :skip
      else
        # Ensure there is at least one dot in the email. Although "john@com" is technically valid,
        # it is not practically valid, and we always want "john@${a}.${b}"
        gen =
          opts
          |> Keyword.get_lazy(:domains, fn -> domain(max_length: 253 - String.length(local)) end)
          |> StreamData.filter(fn domain -> String.contains?(domain, ".") end)
          |> StreamData.bind(fn domain -> StreamData.constant("#{local}@#{domain}") end)

        {:cont, gen}
      end
    end)
  end

  defp email_chars do
    ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-/=^_`{|}~."
  end
end
