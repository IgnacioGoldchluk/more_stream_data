defmodule MoreStreamData.RegexGen.Tokenizer.Metadata do
  @moduledoc false
  defstruct anchor_start?: false, anchor_end?: false, line_start?: false, line_end?: false

  @type t :: %__MODULE__{
          anchor_end?: boolean(),
          anchor_end?: boolean(),
          line_end?: boolean(),
          line_start?: boolean()
        }

  def new(pattern, options) when is_binary(pattern) and is_list(options) do
    %__MODULE__{
      anchor_start?: anchor_start?(pattern, options),
      anchor_end?: anchor_end?(pattern, options),
      line_start?: line_start?(pattern, options),
      line_end?: line_end?(pattern, options)
    }
  end

  def new(regex) when is_struct(regex, Regex), do: new(Regex.source(regex), Regex.opts(regex))

  # Both `anchor_end?` and `line_end?` have bugs because the string
  # might end with the literal backslash + z as ~r/\\z/ which matches "\z",
  # same as ~r/\\$/ which matches "\$". Highly unlikely but in case we hit this in prod
  # we have to build the metadata AFTER tokenizing the regex
  defp anchor_end?(pattern, options) do
    String.ends_with?(pattern, "\\z") or
      (ends_with_dollar?(pattern) and
         not Enum.member?(options, :multiline))
  end

  defp line_end?(pattern, options) do
    ends_with_dollar?(pattern) and Enum.member?(options, :multiline)
  end

  defp line_start?(pattern, options) do
    String.starts_with?(pattern, "^") and Enum.member?(options, :multiline)
  end

  defp anchor_start?(pattern, options) do
    String.starts_with?(pattern, "\\A") or
      (String.starts_with?(pattern, "^") and not Enum.member?(options, :multiline))
  end

  defp ends_with_dollar?(pattern) do
    String.ends_with?(pattern, "$") and not String.ends_with?(pattern, "\\$")
  end
end
