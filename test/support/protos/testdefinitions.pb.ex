defmodule MoreStreamData.Protos.Person do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "Person",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:ALICE, 0)
  field(:BOB, 1)
end

defmodule MoreStreamData.Protos.ScalarMessage do
  @moduledoc false

  use Protobuf, full_name: "ScalarMessage", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:basic_uint32, 1, type: :uint32, json_name: "basicUint32")
  field(:basic_uint64, 2, type: :uint64, json_name: "basicUint64")
  field(:basic_int32, 3, type: :int32, json_name: "basicInt32")
  field(:basic_int64, 4, type: :int64, json_name: "basicInt64")
  field(:basic_string, 5, type: :string, json_name: "basicString")
  field(:basic_sint32, 6, type: :sint32, json_name: "basicSint32")
  field(:basic_sint64, 7, type: :sint64, json_name: "basicSint64")
  field(:basic_fixed32, 8, type: :fixed32, json_name: "basicFixed32")
  field(:basic_fixed64, 9, type: :fixed64, json_name: "basicFixed64")
  field(:basic_double, 10, type: :double, json_name: "basicDouble")
  field(:basic_float, 11, type: :float, json_name: "basicFloat")
  field(:basic_bytes, 12, type: :bytes, json_name: "basicBytes")
  field(:basic_boolean, 13, type: :bool, json_name: "basicBoolean")
end

defmodule MoreStreamData.Protos.User do
  @moduledoc false

  use Protobuf, full_name: "User", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:username, 1, type: :string)
  field(:user_id, 2, type: :int32, json_name: "userId")
end

defmodule MoreStreamData.Protos.Repeateds.AliasesEntry do
  @moduledoc false

  use Protobuf,
    full_name: "Repeateds.AliasesEntry",
    map: true,
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: MoreStreamData.Protos.Person, enum: true)
end

defmodule MoreStreamData.Protos.Repeateds do
  @moduledoc false

  use Protobuf, full_name: "Repeateds", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:people, 1, repeated: true, type: MoreStreamData.Protos.Person, enum: true)

  field(:aliases, 2,
    repeated: true,
    type: MoreStreamData.Protos.Repeateds.AliasesEntry,
    map: true
  )

  field(:users, 3, repeated: true, type: MoreStreamData.Protos.User)
end

defmodule MoreStreamData.Protos.LevelZero do
  @moduledoc false

  use Protobuf, full_name: "LevelZero", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:msg, 1, type: :string)
end

defmodule MoreStreamData.Protos.LevelOne do
  @moduledoc false

  use Protobuf, full_name: "LevelOne", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:nested1, 1, type: MoreStreamData.Protos.LevelZero)
end

defmodule MoreStreamData.Protos.LevelTwo do
  @moduledoc false

  use Protobuf, full_name: "LevelTwo", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:nested2, 1, type: MoreStreamData.Protos.LevelOne)
end

defmodule MoreStreamData.Protos.MessageWithOneOf do
  @moduledoc false

  use Protobuf,
    full_name: "MessageWithOneOf",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:case_one, 0)

  oneof(:case_two, 1)

  field(:msg_id, 1, type: :uint32, json_name: "msgId")
  field(:name, 2, type: :string, oneof: 0)
  field(:name2, 3, type: :string, oneof: 0)
  field(:msg_one, 4, type: :uint32, json_name: "msgOne", oneof: 1)
  field(:msg_two, 5, type: :string, json_name: "msgTwo", oneof: 1)
end
