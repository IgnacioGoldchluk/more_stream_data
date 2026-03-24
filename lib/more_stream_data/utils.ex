defmodule MoreStreamData.Utils do
  @moduledoc false

  @doc """
  Randomly uppercases and downcases characters from the generated string
  """
  @spec recase(StreamData.t(String.t())) :: StreamData.t(String.t())
  def recase(str_gen) do
    str_gen
    |> StreamData.bind(fn str ->
      StreamData.bind(
        StreamData.list_of(StreamData.boolean(), length: String.length(str)),
        fn booleans ->
          Enum.zip(String.graphemes(str), booleans)
          |> Enum.map_join("", fn
            {char, true} -> String.upcase(char)
            {char, false} -> String.downcase(char)
          end)
          |> StreamData.constant()
        end
      )
    end)
  end
end
