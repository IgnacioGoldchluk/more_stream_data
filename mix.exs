defmodule MoreStreamData.MixProject do
  use Mix.Project

  @source_url "https://github.com/IgnacioGoldchluk/more_stream_data"
  @version "0.5.0"

  def project do
    [
      app: :more_stream_data,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      # Docs
      name: "MoreStreamData",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:stream_data, "~> 1.0"},
      {:decimal, "~> 2.3"},
      {:protobuf, "~> 0.14"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp docs do
    [
      main: "MoreStreamData",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp description do
    "Additional generators for StreamData"
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Ignacio Goldchluk"],
      source_ref: "v#{@version}",
      links: %{"GitHub" => @source_url}
    ]
  end
end
