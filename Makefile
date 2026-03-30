gen:
	protoc --elixir_out=. --elixir_opt=package_prefix=more_stream_data.protos test/support/protos/testdefinitions.proto
