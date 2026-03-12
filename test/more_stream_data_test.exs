defmodule MoreStreamDataTest do
  use ExUnit.Case
  use ExUnitProperties

  import MoreStreamData

  describe "ip_address/1" do
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
end
