defmodule Absinthe.Plug.Mixfile do
  use Mix.Project

  @version "1.5.8"

  def project do
    [
      app: :absinthe_plug,
      version: @version,
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      source_url: "https://github.com/absinthe-graphql/absinthe_plug",
      docs: [source_ref: "v#{@version}", main: "Absinthe.Plug"],
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :apps_direct,
        plt_file: {:no_warn, "priv/plts/project.plt"}
      ]
    ]
  end

  defp package do
    [
      description: "Plug support for Absinthe, the GraphQL toolkit for Elixir",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Ben Wilson", "Bruce Williams"],
      licenses: ["MIT"],
      links: %{
        Website: "https://absinthe-graphql.org",
        Changelog: "https://github.com/absinthe-graphql/absinthe_plug/blob/master/CHANGELOG.md",
        GitHub: "https://github.com/absinthe-graphql/absinthe_plug"
      }
    ]
  end

  def application do
    [extra_applications: [:logger, :inets]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:plug, "~> 1.4"},
      {:jason, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.20", only: :dev},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
