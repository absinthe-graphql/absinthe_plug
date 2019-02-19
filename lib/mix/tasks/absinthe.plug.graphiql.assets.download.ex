defmodule Mix.Tasks.Absinthe.Plug.Graphiql.Assets.Download do
  use Mix.Task

  @shortdoc "Download GraphiQL assets"

  def run(args) do
    Mix.Absinthe.Plug.GraphiQL.AssetsTask.run(args)

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    Absinthe.Plug.GraphiQL.Assets.get_remote_asset_mappings()
    |> Enum.map(&download_file/1)
  end

  defp download_file({destination, asset_url}) do
    {:ok, response} = http_get(asset_url)

    case response do
      {{_, http_code, _}, _, body} when http_code in [200] ->
        Mix.Generator.create_file(destination, body, [force: true])
      _ ->
        Mix.raise """
          Something went wrong downloading #{asset_url} Please try again.
        """
    end
  end

  defp http_get(url), do: :httpc.request(:get, {String.to_charlist(url), []}, [], [body_format: :binary])
end
