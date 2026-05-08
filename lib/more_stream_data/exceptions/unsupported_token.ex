defmodule MoreStreamData.Exceptions.UnsupportedToken do
  defexception [:token]

  defp name("(?="), do: "positive lookahead"
  defp name("(?<="), do: "positive lookbehind"
  defp name("\\k"), do: "recursive reference"
  defp name("\\g"), do: "recursive reference"
  defp name(<<?\\, d>>) when d in ?1..?9, do: "recursive reference"
  defp name("\\b"), do: "word boundary"
  defp name(<<_low, ?-, _high>>), do: "character range in wrong order"
  defp name(<<?\\, _>>), do: "unknown escaped symbol"

  def message(%{token: token} = _exception) do
    "Unsupported token '#{token}' (#{name(token)})"
  end
end
