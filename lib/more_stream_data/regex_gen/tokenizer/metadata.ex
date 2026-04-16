defmodule MoreStreamData.RegexGen.Tokenizer.Metadata do
  @moduledoc false
  defstruct anchor_start?: false, anchor_end?: false, line_start?: false, line_end?: false

  @type t :: %__MODULE__{
          anchor_end?: boolean(),
          anchor_end?: boolean(),
          line_end?: boolean(),
          line_start?: boolean()
        }

  def new(delimiters, options) when is_list(delimiters) and is_list(options) do
    %__MODULE__{
      anchor_start?: anchor_start?(delimiters, options),
      anchor_end?: anchor_end?(delimiters, options),
      line_start?: line_start?(delimiters, options),
      line_end?: line_end?(delimiters, options)
    }
  end

  defp anchor_end?(delimiters, options) do
    :string_end in delimiters or
      (:line_end in delimiters and not Enum.member?(options, :multiline))
  end

  defp line_end?(delimiters, options), do: :line_end in delimiters and :multiline in options

  defp line_start?(delimiters, options), do: :line_start in delimiters and :multiline in options

  defp anchor_start?(delimiters, options) do
    :firstline in options or :string_start in delimiters or
      (:line_start in delimiters and not Enum.member?(options, :multiline))
  end
end
