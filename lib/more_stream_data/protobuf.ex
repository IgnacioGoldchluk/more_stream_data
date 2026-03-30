defmodule MoreStreamData.Protobuf do
  @moduledoc false

  @scalars [
    :int32,
    :int64,
    :uint32,
    :uint64,
    :sint32,
    :sint64,
    :fixed32,
    :fixed64,
    :sfixed32,
    :sfixed64,
    :bool,
    :string,
    :double,
    :float,
    :bytes
  ]

  @doc """
  Generates a protobuf message for the given module
  """
  @spec from_proto(module()) :: StreamData.t(struct())
  def from_proto(protobuf_message) when is_atom(protobuf_message) do
    protobuf_message
    |> field_props()
    |> apply_oneof(oneof(protobuf_message))
    |> Map.new(fn %Protobuf.FieldProps{name_atom: name} = field -> {name, strategy(field)} end)
    |> StreamData.fixed_map()
    |> StreamData.map(&struct(protobuf_message, &1))
  end

  defp strategy(%Protobuf.FieldProps{map?: true} = field) do
    map_strategy(field)
  end

  defp strategy(%Protobuf.FieldProps{repeated?: true} = field) do
    field
    |> Map.put(:repeated?, false)
    |> Map.put(:required?, true)
    |> strategy()
    |> StreamData.list_of()
  end

  defp strategy(%Protobuf.FieldProps{enum?: true, type: {:enum, module}}) do
    StreamData.member_of(enum_values(module))
  end

  # Default case, not map, not repeated and not enum
  defp strategy(%Protobuf.FieldProps{type: t}) when t in @scalars do
    strategy(t)
  end

  defp strategy(:string), do: StreamData.string(:utf8)
  defp strategy(:bytes), do: StreamData.binary()
  defp strategy(:bool), do: StreamData.boolean()
  defp strategy(:int32), do: StreamData.integer(-2_147_483_648..2_147_483_647)
  defp strategy(:int64), do: StreamData.integer((-2 ** 63)..(2 ** 63 - 1))
  defp strategy(:uint32), do: StreamData.integer(0..(2 ** 32 - 1))
  defp strategy(:uint64), do: StreamData.integer(0..(2 ** 64 - 1))
  defp strategy(:sint32), do: strategy(:int32)
  defp strategy(:sint64), do: strategy(:int64)
  defp strategy(:fixed32), do: strategy(:uint32)
  defp strategy(:fixed64), do: strategy(:uint64)
  # Elixir doesn't even use IEEE-754 representation, let's just generate
  # floats and let the encoders/decoders handle it
  defp strategy(:double), do: StreamData.float()
  defp strategy(:float), do: strategy(:double)

  defp strategy(%Protobuf.FieldProps{type: module, required?: false}),
    do: StreamData.nullable(from_proto(module), ratio: 0.1)

  defp strategy(%Protobuf.FieldProps{type: module, required?: true}), do: from_proto(module)

  defp map_strategy(%Protobuf.FieldProps{type: map_alias_module}) do
    fields = field_props(map_alias_module)
    StreamData.map_of(strategy(get_field(fields, "key")), strategy(get_field(fields, "value")))
  end

  # Defining as separate function because this is undocumented and might change?
  @spec field_props(module()) :: list(Protobuf.FieldProps.t())
  defp field_props(module),
    do: module.__message_props__() |> Map.fetch!(:field_props) |> Map.values()

  defp get_field(fields, name), do: Enum.find(fields, fn field -> field.name == name end)

  defp enum_values(module) do
    module.__message_props__() |> Map.fetch!(:field_tags) |> Map.keys()
  end

  defp oneof(module), do: module.__message_props__() |> Map.fetch!(:oneof)

  defp apply_oneof(fields_props, oneof_kw) do
    by_oneof_idx = Enum.group_by(fields_props, fn %Protobuf.FieldProps{oneof: idx} -> idx end)
    {individuals, oneofs} = Map.pop(by_oneof_idx, nil, [])

    Enum.reduce(oneofs, individuals, fn {idx, choices}, selected_fields ->
      field = Enum.random(choices)
      [%{field | name_atom: find_oneof(oneof_kw, idx)} | selected_fields]
    end)
  end

  defp find_oneof(oneof_kw, idx) do
    Enum.find_value(oneof_kw, fn {name, i} -> if(i == idx, do: name) end)
  end
end
