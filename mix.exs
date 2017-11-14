defmodule Absinthe.Plug.Mixfile do
  use Mix.Project

  @version "1.4.0-rc.2"

  def project do
    [app: :absinthe_plug,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     elixirc_paths: elixirc_paths(Mix.env),
     package: package(),
     docs: [source_ref: "v#{@version}", main: "Absinthe.Plug"],
     aliases: aliases(),
     deps: deps()]
  end

  defp package do
    [description: "Plug support for Absinthe, the GraphQL toolkit for Elixir",
     files: ["lib", "mix.exs", "README*"],
     maintainers: ["Ben Wilson", "Bruce Williams"],
     licenses: ["MIT"],
     links: %{
       site: "http://absinthe-graphql.org",
       github: "https://github.com/absinthe-graphql/absinthe_plug",
      }
    ]
  end

  def application do
    [applications: [:logger, :plug, :absinthe]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:plug, "~> 1.3.2 or ~> 1.4"},
      # {:absinthe, "~> 1.4.0-rc.3 or ~> 1.4"},
      {:absinthe, git: "git://github.com/MartinKavik/absinthe", branch: "fix-result-fields-order", override: true},
      {:ord_map_encoder_poison, "~> 0.1.0"},
      {:poison, ">= 0.0.0"},
      {:ex_doc, "~> 0.14.0", only: :dev},
      {:earmark, "~> 1.1.0", only: :dev},
    ]
  end

  defp aliases do
    [
      "test.all": [&run_tests_unordered/1, &run_tests_ordered/1]
    ]
  end

  defp run_tests_unordered(_) do
    Mix.shell.cmd(
      "mix test", 
      env: [{"MIX_ENV", "test"}, {"ABSINTHE_ORDERED", "false"}]
    )
  end

  defp run_tests_ordered(_) do
    Mix.shell.cmd(
      "mix test", 
      env: [{"MIX_ENV", "test"}, {"ABSINTHE_ORDERED", "true"}]
    )
  end
end
