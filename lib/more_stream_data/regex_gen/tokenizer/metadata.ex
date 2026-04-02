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
      anchor_end?: anchor_end?(pattern, options)
    }
  end

  defp anchor_end?(pattern, options) do
    String.ends_with?(pattern, "\\z") or
      (String.ends_with?(pattern, "$") and not String.ends_with?(pattern, "\\$") and
         not Enum.member?(options, :multiline))
  end

  defp anchor_start?(pattern, options) do
    String.starts_with?(pattern, "\\A") or
      (String.starts_with?(pattern, "^") and not Enum.member?(options, :multiline))
  end
end
