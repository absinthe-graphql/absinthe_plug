defmodule AbsinthePlug.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def project do
    [app: :absinthe_plug,
     version: @version,
     elixir: "~> 1.2-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     docs: [source_ref: "v#{@version}", main: "AbsinthePlug"],
     deps: deps]
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

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:absinthe, "~> 0.4.0"},
      {:poison, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.11.0", only: :dev},
      {:earmark, "~> 0.1.19", only: :dev},
    ]
  end
end
