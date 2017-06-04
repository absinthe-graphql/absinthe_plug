defmodule Mix.Absinthe.Plug.GraphiQL.AssetsTask do
  alias Absinthe.Plug.GraphiQL.Assets

  @switches [directory: :string]

  def run(args) do
    if Mix.Project.umbrella?(),
      do: Mix.raise "mix absinthe.plug.graphiql.workspace.download can only be run inside an application directory"

    parse_args(args)
  end

  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args, strict: @switches)

    Assets.default_assets_config() |> Keyword.merge(opts)
  end
end
