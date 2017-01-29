defmodule Absinthe.Plug.Mixfile do
  use Mix.Project

  @version "1.2.2"

  def project do
    [app: :absinthe_plug,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     elixirc_paths: elixirc_paths(Mix.env),
     package: package(),
     docs: [source_ref: "v#{@version}", main: "Absinthe.Plug"],
     deps: deps()]
  end

  defp package do
    [description: "A plug for Absinthe, an experimental GraphQL toolkit",
     files: ["lib", "mix.exs", "README*"],
     maintainers: ["Ben Wilson", "Bruce Williams"],
     licenses: ["BSD"],
     links: %{github: "https://github.com/CargoSense/absinthe_plug"}]
  end

  def application do
    [applications: [:logger, :plug, :absinthe]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.2"},
      {:absinthe, "~> 1.2.5"},
      {:poison, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.14.0", only: :dev},
      {:earmark, "~> 1.1.0", only: :dev},
    ]
  end
end
