defmodule PulseKit.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :pulsekit,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PulseKit.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    "PulseKit SDK for Elixir - Error tracking and event monitoring"
  end

  defp package do
    [
      name: "pulsekit",
      licenses: ["MIT"],
      links: %{},
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
