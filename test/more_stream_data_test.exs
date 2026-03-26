defmodule MoreStreamDataTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  require Decimal

  import MoreStreamData

  describe "ip_address/1" do
    test "mismatched version and network range raises" do
      assert_raise ArgumentError, fn ->
        Enum.take(ip_address(version: 6, network: "255.255.255.0/24"), 1)
      end

      assert_raise ArgumentError, fn ->
        Enum.take(ip_address(version: 4, network: "2001:db8::/32"), 1)
      end
    end

    test "raises for invalid IP range" do
      assert_raise ArgumentError, fn ->
        Enum.take(ip_address(version: 4, network: "1234/24"), 1)
      end

      assert_raise ArgumentError, fn ->
        Enum.take(ip_address(network: "255.0.0.0/"), 1)
      end

      assert_raise ArgumentError, fn ->
        Enum.take(ip_address(network: "255.255.128.0/16"), 1)
      end
    end

    property "unspecified generates either IPv4 or IPv6 randomly" do
      check all ip <- ip_address() do
        assert {:ok, _} = :inet.parse_address(to_charlist(ip))
      end
    end

    property "specified version generates only IPs of that format" do
      check all ip <- ip_address(version: 6) do
        assert {:ok, parsed_ip} = :inet.parse_address(to_charlist(ip))
        assert :inet.is_ipv6_address(parsed_ip)
      end

      check all ip <- ip_address(version: 4) do
        assert {:ok, parsed_ip} = :inet.parse_address(to_charlist(ip))
        assert :inet.is_ipv4_address(parsed_ip)
      end
    end

    property "specified network generates IPs in the given range" do
      check all ip <- ip_address(network: "191.142.0.0/16") do
        assert {:ok, {191, 142, _, _}} = :inet.parse_address(to_charlist(ip))
      end

      check all ip <- ip_address(network: "2001:db8::/32") do
        assert {:ok, {0x2001, 0xDB8, _, _, _, _, _, _}} = :inet.parse_address(to_charlist(ip))
      end
    end

    property "version matching network is ignored" do
      check all ip <- ip_address(version: 4, network: "255.255.255.0/24") do
        assert {:ok, {255, 255, 255, _}} = :inet.parse_address(to_charlist(ip))
      end

      check all ip <- ip_address(version: 6, network: "2001:db8::/32") do
        assert {:ok, {0x2001, 0xDB8, _, _, _, _, _, _}} = :inet.parse_address(to_charlist(ip))
      end
    end
  end

  describe "time/1" do
    test "raises if :min is after :max" do
      assert_raise ArgumentError, fn ->
        Enum.take(time(min: ~T[08:02:03], max: ~T[03:04:05]), 1)
      end
    end

    property "generates free values when min and max are not specified" do
      check all time <- time() do
        assert %Time{} = time
      end
    end

    property "does not generate values greater than max" do
      max = Time.utc_now()

      check all time <- time(max: max) do
        assert Time.after?(max, time)
      end
    end

    property "does not generate values below min" do
      min = Time.utc_now()

      check all time <- time(min: min) do
        assert Time.after?(time, min)
      end
    end

    property "generates values between min and max when both are specified" do
      min = ~T[01:02:03.4567]
      max = ~T[09:08:07.6543]

      check all time <- time(min: min, max: max) do
        assert Time.after?(max, time)
        assert Time.after?(time, min)
      end
    end
  end

  describe "decimal/1" do
    test "raises if :min > :max" do
      assert_raise ArgumentError, fn ->
        Enum.take(decimal(min: Decimal.new(10), max: Decimal.new(0)), 1)
      end
    end

    property "generates unbounded values when no options are specified" do
      check all dec <- decimal() do
        assert Decimal.is_decimal(dec)
      end
    end

    property "generates values above the minimum" do
      check all dec1 <- decimal(allow_nan?: false), dec2 <- decimal(min: dec1) do
        assert Decimal.gte?(dec2, dec1)
      end
    end

    property "generates values below the maximum" do
      check all dec1 <- decimal(allow_nan?: false), dec2 <- decimal(max: dec1) do
        assert Decimal.lte?(dec2, dec1)
      end
    end

    property "generates values within the given range" do
      check all low <- decimal(allow_nan?: false, allow_infinity?: false),
                high <- decimal(min: low, allow_nan?: false, allow_infinity?: false),
                dec <- decimal(min: low, max: high) do
        assert Decimal.gte?(high, dec)
        assert Decimal.gte?(dec, low)
      end
    end

    test "eventually draws 'NaN' when allow_nan?: true" do
      Enum.take_while(decimal(allow_nan?: true), &Decimal.nan?/1)
    end

    test "eventually draws Infinity when allow_infinity?: true" do
      Enum.take_while(decimal(allow_infinity?: true), &Decimal.inf?/1)
    end
  end

  describe "more_integer/1" do
    property "range behaves as StreamData.integer/1" do
      check all value <- more_integer(-100..100) do
        assert value in -100..100
      end
    end

    property "more_integer/0 behaves as StreamData.integer/0" do
      check all value <- more_integer() do
        assert is_integer(value)
      end
    end

    property "generates integers greater than :min" do
      check all lower <- more_integer(),
                value <- more_integer(min: lower) do
        assert value >= lower
      end
    end

    property "generates integers lower than :max" do
      check all upper <- more_integer(),
                value <- more_integer(max: upper) do
        assert value <= upper
      end
    end

    test ":min > :max raises" do
      assert_raise ArgumentError, fn ->
        Enum.take(more_integer(min: 100, max: 10), 1)
      end
    end

    property "passing :min and :max generates ranges" do
      check all value <- more_integer(min: -100, max: 100) do
        assert value in -100..100
      end
    end
  end

  describe "more_float/1" do
    property "float/0 behaves same as StreamData.float/0" do
      check all value <- more_float() do
        assert is_float(value)
      end
    end

    property "exclude_min?: true does not generate the min value" do
      check all value <- more_float(min: 0.0, exclude_min?: true) do
        refute value == 0.0
      end
    end

    test "exclude_min?: true without min raises" do
      assert_raise ArgumentError, fn ->
        Enum.take(more_float(exclude_min?: true, max: 10.0), 1)
      end
    end

    property "exclude_max?: true does not generate the min value" do
      check all value <- more_float(max: 0.0, exclude_max?: true) do
        refute value == 0.0
      end
    end

    test "exclude_max?: true without max raises" do
      assert_raise ArgumentError, fn ->
        Enum.take(more_float(exclude_max?: true, min: 10.0), 1)
      end
    end
  end

  describe "timezone/0" do
    property "returns a valid timezone" do
      check all timezone <- timezone() do
        assert Tzdata.zone_exists?(timezone)
        DateTime.shift_zone!(DateTime.utc_now(), timezone, Tzdata.TimeZoneDatabase)
      end
    end
  end

  describe "duration/1" do
    property "unspecified min/max generates unbounded durations" do
      check all duration <- duration() do
        DateTime.utc_now() |> DateTime.shift(duration)
      end
    end

    property "generates durations >= min" do
      check all min <- duration(), duration <- duration(min: min) do
        now = DateTime.utc_now()
        refute DateTime.shift(now, min) |> DateTime.after?(DateTime.shift(now, duration))
      end
    end

    property "generates durations <= max" do
      check all max <- duration(), duration <- duration(max: max) do
        now = DateTime.utc_now()
        refute DateTime.shift(now, max) |> DateTime.before?(DateTime.shift(now, duration))
      end
    end

    property "generates durations bounded between min and max args" do
      check all min <- duration(),
                max <- duration(min: min),
                duration <- duration(min: min, max: max) do
        now = DateTime.utc_now()
        refute DateTime.shift(now, min) |> DateTime.after?(DateTime.shift(now, duration))
        refute DateTime.shift(now, max) |> DateTime.before?(DateTime.shift(now, duration))
      end
    end
  end

  describe "datetime/1" do
    test "generates datetimes with unspecified ranges" do
      datetime() |> Enum.take(10) |> Enum.all?(fn %DateTime{} = _dt -> true end)
    end

    property "generates datetimes greater than or equal to :min" do
      check all min <- datetime(), dt <- datetime(min: min) do
        refute DateTime.before?(dt, min)
      end
    end

    property "generates datetimes lower than or equal to :max" do
      check all max <- datetime(), dt <- datetime(max: max) do
        refute DateTime.after?(dt, max)
      end
    end

    property "generates datetimes between :min and :max" do
      check all min <- datetime(), max <- datetime(min: min), dt <- datetime(min: min, max: max) do
        refute DateTime.before?(dt, min)
        refute DateTime.after?(dt, max)
      end
    end

    property "generates datetimes based on :date and :time strategy" do
      min_date = Date.utc_today()

      check all dt <- datetime(date: date(min: min_date)) do
        refute Date.before?(DateTime.to_date(dt), min_date)
      end

      min_time = ~T[12:00:00]

      check all dt <- datetime(time: time(min: min_time)) do
        refute Time.before?(DateTime.to_time(dt), min_time)
      end
    end

    property "generates datetimes in the specified timezones" do
      tz = "America/Cuiaba"

      check all dt <- datetime(timezone: StreamData.constant(tz)) do
        assert dt.time_zone == tz
      end
    end
  end

  describe "domain/1" do
    property "unbounded domain generates labels and domains according to RFC-1035" do
      check all dom <- domain() do
        assert String.length(dom) <= 255
        [_tld | labels] = String.split(dom, ".") |> Enum.reverse()

        Enum.each(labels, fn l ->
          assert String.length(l) <= 63
          refute String.starts_with?(l, "-")
          refute String.ends_with?(l, "-")
        end)
      end
    end

    property "does not generate domains longer than :max_length" do
      check all max_length <- StreamData.integer(4..255), dom <- domain(max_length: max_length) do
        assert String.length(dom) <= max_length
      end
    end

    property "does not generate labels longer than :max_label_length" do
      check all max_label_length <- StreamData.integer(1..63),
                dom <- domain(max_label_length: max_label_length) do
        [_tld | labels] = String.split(dom, ".") |> Enum.reverse()
        Enum.each(labels, fn label -> assert String.length(label) <= max_label_length end)
      end
    end

    test "raises if max_length is not between 4.255" do
      assert_raise ArgumentError, ":max_length must be between [4, 255], got: 3", fn ->
        domain(max_length: 3) |> Enum.take(1)
      end

      assert_raise ArgumentError, ":max_length must be between [4, 255], got: 512", fn ->
        domain(max_length: 512) |> Enum.take(1)
      end
    end

    test "raises if :max_label_length is not between 1..63" do
      assert_raise ArgumentError, ":max_label_length must be between [1, 63], got: 0", fn ->
        domain(max_label_length: 0) |> Enum.take(1)
      end

      assert_raise ArgumentError, ":max_label_length must be between [1, 63], got: 64", fn ->
        domain(max_label_length: 64) |> Enum.take(1)
      end
    end
  end

  describe "url/0" do
    property "generates valid URLs" do
      check all url <- url() do
        URI.new!(url)
      end
    end
  end

  describe "email/0" do
    property "generates valid emails" do
      check all email <- email() do
        assert String.length(email) <= 254
        assert [local, domain] = String.split(email, "@")
        assert String.length(local) <= 64
        refute String.starts_with?(local, ".")
        refute String.ends_with?(local, ".")
        refute Regex.match?(~r/\.{2,}/, local)
        assert String.contains?(domain, ".")
      end
    end

    property "generates with specified domains" do
      domains = ["outlook.com", "gmail.com"]

      check all email <- email(domains: StreamData.member_of(domains)) do
        [_local, domain] = String.split(email, "@")
        assert Enum.member?(domains, domain)
      end
    end
  end

  describe "from_regex/1" do
    property "caseless option geneates case insensitive regex" do
      check all str <- from_regex(~r/^qwertyasd$/i) do
        assert String.downcase(str) == "qwertyasd"
      end
    end

    common_regexes = [
      # Decimal numbers
      ~r/^-?\d*(\.\d+)?$/,
      # Decimal + integer + fration
      ~r/^[-]?[0-9]+[,.]?[0-9]*([\/][0-9]+[,.]?[0-9]*)*$/,
      # Simplified and wrong email
      ~r/^[A-Za-z0-9]+([._%+-]?[A-Za-z0-9]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/,
      # Phone numbers. Not correct because you can have mismatched parentheses
      ~r/^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$/,
      # US Postal Code
      ~r/^\d{5}([\-]?\d{4})?$/,
      # Hex color
      ~r/^#([A-Fa-f0-9]{3}|[A-Fa-f0-9]{6})$/,
      # Username
      ~r/^[a-z0-9_-]{3,16}$/,
      # IPv4
      ~r/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/,
      # URL, not entirely correct since it's missing a \b
      ~r/^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._+~#=]{2,256}\.[a-z]{2,6}([-a-zA-Z0-9@:%_+.~#?&\/=]*)$/,
      # Time format
      ~r/^(?:[01]\d|2[0123]):(?:[012345]\d):(?:[012345]\d)$/,
      # Another time format
      ~r/^(1[0-2]|0[1-9])(:[0-5]\d){2} (A|P)M$/,
      # Slug
      ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/
    ]

    for regex <- common_regexes do
      property "generates valid cases for #{regex.source}" do
        regex = unquote(Macro.escape(regex))

        check all str <- from_regex(regex) do
          assert Regex.match?(regex, str)
        end
      end
    end
  end
end
