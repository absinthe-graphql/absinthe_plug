defmodule AbsinthePlug.Mixfile do
  use Mix.Project

  def project do
    [app: :absinthe_plug,
     version: "0.1.1",
     elixir: "~> 1.2-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     docs: [extras: ["README.md", "CONTRIBUTING.md"], main: "README"],
     deps: deps]
  end

  defp package do
    [description: "A plug for Absinthe, a GraphQL implementation in Elixir",
     files: ["lib", "mix.exs", "README*"],
     maintainers: ["Ben Wilson", "Bruce Williams"],
     licenses: ["Apache2"],
     links: %{github: "https://github.com/CargoSense/absinthe_plug"}]
  end

  def application do
    [applications: [:logger, :plug, :absinthe]]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:absinthe, "~> 0.2.1"},
      {:poison, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.11.0", only: :dev},
      {:earmark, "~> 0.1.19", only: :dev},
    ]
  end
end
