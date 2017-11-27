defmodule Absinthe.Plug.GraphiQL.Assets do
  @moduledoc """
  """

  @config Application.get_env(:absinthe_plug, Absinthe.Plug.GraphiQL)
  @default_config [
    source: :smart,
    local_url_path: "/absinthe_graphiql",
    local_directory: "priv/static/absinthe_graphiql",
    local_source: ":package/:alias",
    remote_source: "https://cdn.jsdelivr.net/npm/:package@:version/:file",
  ]

  @react_version "15.6.1"

  @assets [
    {"whatwg-fetch", "2.0.3", [
      {"fetch.min.js", "fetch.js"},
    ]},
    {"react", @react_version, [
      {"dist/react.min.js", "react.js"},
    ]},
    {"react-dom", @react_version, [
      {"dist/react-dom.min.js", "react-dom.js"},
    ]},
    {"bootstrap", "3.3.7", [
      {"dist/fonts/glyphicons-halflings-regular.eot", "fonts/glyphicons-halflings-regular.eot"},
      {"dist/fonts/glyphicons-halflings-regular.ttf", "fonts/glyphicons-halflings-regular.ttf"},
      {"dist/fonts/glyphicons-halflings-regular.woff2", "fonts/glyphicons-halflings-regular.woff2"},
      {"dist/fonts/glyphicons-halflings-regular.svg", "fonts/glyphicons-halflings-regular.svg"},
      {"dist/css/bootstrap.min.css", "css/bootstrap.css"},
    ]},
    {"graphiql", "0.11.10", [
      "graphiql.css",
      {"graphiql.min.js", "graphiql.js"},
    ]},
    {"graphiql-workspace", "1.1.4", [
      "graphiql-workspace.css",
      {"graphiql-workspace.min.js", "graphiql-workspace.js"}
    ]},
    # Used by graphql-playground
    {"typeface-source-code-pro", "0.0.44", [
      {"index.css", "index.css"},
      {"files/source-code-pro-latin-400.woff2", "files/source-code-pro-latin-400.woff2"},
      {"files/source-code-pro-latin-700.woff2", "files/source-code-pro-latin-700.woff2"},
    ]},
    # Used by graphql-playground
    {"typeface-open-sans", "0.0.44", [
      {"index.css", "index.css"},
      {"files/open-sans-latin-300.woff2", "files/open-sans-latin-300.woff2"},
      {"files/open-sans-latin-400.woff2", "files/open-sans-latin-400.woff2"},
      {"files/open-sans-latin-600.woff2", "files/open-sans-latin-600.woff2"},
      {"files/open-sans-latin-700.woff2", "files/open-sans-latin-700.woff2"},
    ]},
    {"@absinthe/graphql-playground", "1.2.0", [
      {"build/static/css/middleware.css", "playground.css"},
      {"build/static/js/middleware.js", "playground.js"}
    ]},
    {"@absinthe/socket-graphiql", "0.1.1", [
      {"compat/umd/index.js", "socket-graphiql.js"},
    ]},
  ]

  def assets_config do
    case @config do
      nil ->
        @default_config
      config ->
        Keyword.merge(@default_config, Keyword.get(config, :assets, []))
    end
  end

  def get_assets do
    reduce_assets(
      %{},
      &Map.put(
        &2,
        build_asset_path(:local_source, &1),
        asset_source_url(assets_config()[:source], &1)
      )
    )
  end

  def get_remote_asset_mappings do
    reduce_assets(
      [],
      &(&2 ++ [{
        local_asset_path(&1),
        asset_source_url(:remote, &1)
      }])
    )
  end

  defp reduce_assets(initial, reducer) do
    Enum.reduce(@assets, initial, fn {package, version, files}, acc ->
      Enum.reduce(files, acc, &reducer.({package, version, &1}, &2))
    end)
  end

  defp local_asset_path(asset) do
    Path.join(assets_config()[:local_directory], build_asset_path(:local_source, asset))
  end

  defp asset_source_url(:smart, asset) do
    if File.exists?(local_asset_path(asset)) do
      asset_source_url(:local, asset)
    else
      asset_source_url(:remote, asset)
    end
  end
  defp asset_source_url(:local, asset) do
    Path.join(assets_config()[:local_url_path], build_asset_path(:local_source, asset))
  end
  defp asset_source_url(:remote, asset) do
    build_asset_path(:remote_source, asset)
  end

  defp build_asset_path(source, {package, version, {real_path, aliased_path}}) do
    assets_config()[source]
    |> String.replace(":package", package)
    |> String.replace(":version", version)
    |> String.replace(":file", real_path)
    |> String.replace(":alias", aliased_path)
  end
  defp build_asset_path(source, {package, version, path}) do
    build_asset_path(source, {package, version, {path, path}})
  end
end
