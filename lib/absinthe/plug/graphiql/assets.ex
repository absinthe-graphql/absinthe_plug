defmodule Absinthe.Plug.GraphiQL.Assets do
  @moduledoc """
  """

  @graphiql_workspace_version "1.0.4"
  @graphiql_version "0.9.3"

  @default_assets_config [
    url_path: "/absinthe_graphiql",
    directory: "./priv/static/absinthe_graphiql"
  ]

  @assets %{
    "fetch.js" => "//cdn.jsdelivr.net/fetch/2.0.1/fetch.min.js",
    "react.js" => "//cdn.jsdelivr.net/react/15.4.2/react.min.js",
    "react-dom.js" => "//cdn.jsdelivr.net/react/15.4.2/react-dom.min.js",
    "bootstrap.css" => "//maxcdn.bootstrapcdn.com/bootstrap/latest/css/bootstrap.min.css",
    "graphiql.css" => "//cdn.jsdelivr.net/graphiql/#{@graphiql_version}/graphiql.css",
    "graphiql.js" => "//cdn.jsdelivr.net/graphiql/#{@graphiql_version}/graphiql.min.js",
    "graphiql-workspace.css" => "//cdn.jsdelivr.net/npm/graphiql-workspace@#{@graphiql_workspace_version}/graphiql-workspace.min.css",
    "graphiql-workspace.js" => "//cdn.jsdelivr.net/npm/graphiql-workspace@#{@graphiql_workspace_version}/graphiql-workspace.min.js"
  }

  def default_assets_config, do: @default_assets_config

  def assets(opts \\ nil)
  def assets(nil), do: @assets
  def assets(opts) do
    assets_config = @default_assets_config |> Keyword.merge(opts)

    Enum.reduce(@assets, %{}, fn asset, acc -> put_asset_path(assets_config, asset, acc) end)
  end

  defp put_asset_path(assets_config, {asset_name, asset_external_url} = _asset, acc) do
    asset_path =
      assets_config[:directory]
      |> Path.join(asset_name)
      |> File.exists?()
      |> case do
        true -> assets_config[:url_path] <> "/" <> asset_name
        false -> asset_external_url
      end

    Map.put(acc, asset_name, asset_path)
  end
end
