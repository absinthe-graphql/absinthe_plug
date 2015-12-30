defmodule AbsinthePlug.Mixfile do
  use Mix.Project

  def project do
    [app: :absinthe_plug,
     version: "0.1.0",
     elixir: "~> 1.2-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :plug, :absinthe]]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:absinthe, git: "git@github.com:CargoSense/absinthe.git"},
      {:poison, ">= 0.0.0", only: [:dev, :test]}
    ]
  end
end
