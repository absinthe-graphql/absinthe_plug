defmodule Absinthe.Plug.GraphiQL.Assets do
  @moduledoc """
  """

  @config Application.get_env(:absinthe_plug, Absinthe.Plug.GraphiQL)
  @default_config [
    url_path: "/absinthe_graphiql",
    directory: "priv/static/absinthe_graphiql"
  ]

  @graphiql_workspace_version "1.1.3"
  @graphiql_version "0.9.3"

  @assets %{
    "fetch.js" => "//cdn.jsdelivr.net/fetch/2.0.1/fetch.min.js",
    "react.js" => "//cdn.jsdelivr.net/react/15.4.2/react.min.js",
    "react-dom.js" => "//cdn.jsdelivr.net/react/15.4.2/react-dom.min.js",
    "bootstrap.css" => "//maxcdn.bootstrapcdn.com/bootstrap/latest/css/bootstrap.min.css",
    "graphiql.css" => "//cdn.jsdelivr.net/graphiql/#{@graphiql_version}/graphiql.css",
    "graphiql.js" => "//cdn.jsdelivr.net/graphiql/#{@graphiql_version}/graphiql.min.js",
    "graphiql-workspace.css" => "//cdn.jsdelivr.net/npm/graphiql-workspace@#{@graphiql_workspace_version}/graphiql-workspace.min.css",
    "graphiql-workspace.js" => "//cdn.jsdelivr.net/npm/graphiql-workspace@#{@graphiql_workspace_version}/graphiql-workspace.min.js",
    "graphiql-subscriptions-fetcher/browser/client.js" => "//unpkg.com/graphiql-subscriptions-fetcher@0.0.2/browser/client.js",
    "phoenix.js" => "//unpkg.com/phoenix@1.2.1/priv/static/phoenix.js",
    "absinthe-phoenix.js" => "//unpkg.com/absinthe-phoenix@0.1.0",
  }

  def assets_config do
    config =
      case @config do
        nil -> []
        config -> Keyword.get(config, :local_assets, [])
      end

    Keyword.merge(@default_config, config)
  end

  def get_assets(:remote), do: @assets
  def get_assets(:local) do
    Enum.reduce @assets, %{}, fn asset, acc ->
      assets_config() |> put_asset_path(asset, acc)
    end
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
