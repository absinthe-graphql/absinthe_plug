defmodule Mix.Tasks.Absinthe.Plug.Graphiql.Assets.Download do
  use Mix.Task

  @shortdoc "Download GraphiQL assets"

  def run(args) do
    opts = Mix.Absinthe.Plug.GraphiQL.AssetsTask.run(args)

    Application.ensure_all_started(:inets)
    Mix.Generator.create_directory(opts[:directory])

    Absinthe.Plug.GraphiQL.Assets.get_assets(:remote)
    |> Enum.map(fn asset -> download_file(opts[:directory], asset) end)
  end

  defp download_file(assets_dir_path, {asset_name, asset_url} = _asset) do
    asset_url = String.to_charlist("https:" <> asset_url) # Required by :httpc
    {:ok, response} = :httpc.request(:get, {asset_url, []}, [], [body_format: :binary])

    case response do
      {{_, http_code, _}, _, body} when http_code in [200] ->
        save_file(assets_dir_path, asset_name, body)
      _ ->
        Mix.raise """
          Something went wrong downloading #{asset_url} Please try again.
        """
    end
  end

  defp save_file(assets_dir_path, file_name, content) do
    assets_dir_path
    |> Path.join(file_name)
    |> Mix.Generator.create_file(content, [force: true])
  end
end
