defmodule Absinthe.Plug.GraphiQL do
  @moduledoc """
  Provides a GraphiQL interface to run queries from.


  ## Interface Selection

  The GraphiQL interface can be switched using the `:interface` option.

  - `:advanced` (default) will serve the [GraphiQL Workspace](https://github.com/OlegIlyenko/graphiql-workspace) interface from Oleg Ilyenko.
  - `:simple` will serve the original [GraphiQL](https://github.com/graphql/graphiql) interface from Facebook.
  - `:playground` (project [deprecated in Dec 2022](https://www.apollographql.com/docs/apollo-server/v2/testing/graphql-playground/)) will serve the [GraphQL Playground](https://github.com/graphcool/graphql-playground) interface from Graphcool.
  - `:apollo_explorer_sandbox` will serve the [Apollo Explorer Sandbox](https://www.apollographql.com/docs/graphos/explorer/sandbox/#embedding-sandbox) interface from Apollo.

  See `Absinthe.Plug` for the other options.


  ## Examples

  Using the GraphiQL `:advanced` interface at `/graphiql`:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [schema: MyAppWeb.Schema]

  Or, if you prever to serve the interface only for development environment:

      if Mix.env == :dev do
        forward "/graphiql",
          to: Absinthe.Plug.GraphiQL,
          init_opts: [schema: MyAppWeb.Schema]
      end

  Using the "simple" interface (original GraphiQL) instead:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :simple
        ]

  Using `:playground` interface ([deprecated in Dec 2022](https://www.apollographql.com/docs/apollo-server/v2/testing/graphql-playground/)):

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :playground
        ]

  Using [Apollo Explorer Sandbox](https://www.apollographql.com/docs/graphos/explorer/sandbox)
  (no Apollo account required):

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :apollo_expolorer_sandbox
        ]


  ## Default Headers

  Optionally defines headers commonly used to request the API, such as the
  API token if the user accessing the interface is signed-in.

  Supported by interfaces:
  - `:advanced`;
  - `:apollo_explorer_sandbox`.

  Note that you migh need to clear the current headers to get refreshed ones
  from the server. Each interface might have a different way to do so but,
  if needed, regardless of the selected interface cleaning the application's
  data from the browser's dev tools should do the trick.

  ### Examples:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :advanced,
          default_headers: {__MODULE__, :graphiql_headers}
        ]

      def graphiql_headers do
        %{
          "X-CSRF-Token" => Plug.CSRFProtection.get_csrf_token(),
          "X-Foo" => "Bar"
        }
      end

  You can also provide a function that takes a `conn` argument if you need to
  access connection data (e.g. if you need to set an Authorization header based
  on the currently logged-in user).

      def graphiql_headers(conn) do
        %{
          "Authorization" => "Bearer " <> conn.assigns[:token]
        }
      end


  ## Default URL

  Optionally set the default URL to be used for sending the queries to.

  Supported by interfaces:
  - `:advanced`;
  - `:playground`;
  - `:apollo_explorer_sandbox`;

  Examples:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          default_url: "https://api.mydomain.com/graphql"
        ]

  This option also accepts a function:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          default_url: {__MODULE__, :graphiql_default_url}
        ]

      def graphiql_default_url(conn) do
        conn.assigns[:graphql_url]
      end


  ## Socket URL

  Optionally set the default websocket URL to be used for subscriptions.

  Supported by interfaces:
  - `:advanced`;
  - `:playground`.

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          socket_url: "wss://api.mydomain.com/socket"
        ]

  This option also accepts a function:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          socket_url: {__MODULE__, :graphiql_socket_url}
        ]

      def graphiql_socket_url(conn) do
        conn.assigns[:graphql_socket_url]
      end
  """

  require EEx

  @graphiql_template_path Path.join(__DIR__, "graphiql")

  EEx.function_from_file(
    :defp,
    :graphiql_html,
    Path.join(@graphiql_template_path, "graphiql.html.eex"),
    [:query_string, :variables_string, :result_string, :socket_url, :assets]
  )

  EEx.function_from_file(
    :defp,
    :graphiql_workspace_html,
    Path.join(@graphiql_template_path, "graphiql_workspace.html.eex"),
    [:query_string, :variables_string, :default_headers, :default_url, :socket_url, :assets]
  )

  EEx.function_from_file(
    :defp,
    :graphiql_playground_html,
    Path.join(@graphiql_template_path, "graphiql_playground.html.eex"),
    [:default_url, :socket_url, :assets]
  )

  EEx.function_from_file(
    :defp,
    :graphiql_apollo_explorer_sandbox_html,
    Path.join(@graphiql_template_path, "apollo_explorer_sandbox.html.eex"),
    [:query_string, :variables_string, :default_headers, :default_url]
  )

  @behaviour Plug

  import Plug.Conn

  @type opts :: [
          schema: atom,
          adapter: atom,
          path: binary,
          context: map,
          json_codec: atom | {atom, Keyword.t()},
          interface: :apollo_explorer_sandbox | :playground | :advanced | :simple,
          default_headers: {module, atom},
          default_url: binary | {module, atom},
          assets: Keyword.t(),
          socket: module,
          socket_url: binary
        ]

  @doc false
  @spec init(opts :: opts) :: map
  def init(opts) do
    assets = Absinthe.Plug.GraphiQL.Assets.get_assets()

    opts
    |> Absinthe.Plug.init()
    |> Map.put(:interface, Keyword.get(opts, :interface) || :advanced)
    |> Map.put(:default_headers, Keyword.get(opts, :default_headers))
    |> Map.put(:default_url, Keyword.get(opts, :default_url))
    |> Map.put(:assets, assets)
    |> Map.put(:socket, Keyword.get(opts, :socket))
    |> Map.put(:socket_url, Keyword.get(opts, :socket_url))
    |> Map.put(:default_query, Keyword.get(opts, :default_query, ""))
    |> set_pipeline
  end

  @doc false
  def call(conn, config) do
    case html?(conn) do
      true -> do_call(conn, config)
      _ -> Absinthe.Plug.call(conn, config)
    end
  end

  defp html?(conn) do
    Plug.Conn.get_req_header(conn, "accept")
    |> List.first()
    |> case do
      string when is_binary(string) ->
        String.contains?(string, "text/html")

      _ ->
        false
    end
  end

  defp do_call(conn, %{interface: interface} = opts) do
    config = get_resolved_config(opts, conn)

    with {:ok, conn, request} <- Absinthe.Plug.Request.parse(conn, config),
         {:process, request} <- select_mode(request),
         {:ok, request} <- Absinthe.Plug.ensure_processable(request, config),
         :ok <- Absinthe.Plug.Request.log(request, config.log_level) do
      conn_info = %{
        conn_private: (conn.private[:absinthe] || %{}) |> Map.put(:http_method, conn.method)
      }

      {conn, result} = Absinthe.Plug.run_request(request, conn, conn_info, config)

      case result do
        {:ok, result} ->
          # GraphiQL doesn't batch requests, so the first query is the only one
          query = hd(request.queries)
          {:ok, conn, result, query.variables, query.document || ""}

        {:error, {:http_method, _}, _} ->
          query = hd(request.queries)
          {:http_method_error, query.variables, query.document || ""}

        other ->
          other
      end
    end
    |> case do
      {:ok, conn, result, variables, query} ->
        query = query |> js_escape

        var_string =
          variables
          |> config.json_codec.module.encode!(pretty: true)
          |> js_escape

        result =
          result
          |> config.json_codec.module.encode!(pretty: true)
          |> js_escape

        config =
          Map.merge(config, %{
            query: query,
            var_string: var_string,
            result: result
          })

        conn
        |> render_interface(interface, config)

      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      :start_interface ->
        conn
        |> render_interface(interface, config)

      {:http_method_error, variables, query} ->
        query = query |> js_escape

        var_string =
          variables
          |> config.json_codec.module.encode!(pretty: true)
          |> js_escape

        config =
          Map.merge(config, %{
            query: query,
            var_string: var_string
          })

        conn
        |> render_interface(interface, config)

      {:error, error, _} when is_binary(error) ->
        conn
        |> send_resp(500, error)
    end
  end

  defp set_pipeline(config) do
    config
    |> Map.put(:additional_pipeline, config.pipeline)
    |> Map.put(:pipeline, {__MODULE__, :pipeline})
  end

  @doc false
  def pipeline(config, opts) do
    {module, fun} = config.additional_pipeline

    apply(module, fun, [config, opts])
    |> Absinthe.Pipeline.insert_after(
      Absinthe.Phase.Document.CurrentOperation,
      [
        Absinthe.GraphiQL.Validation.NoSubscriptionOnHTTP
      ]
    )
  end

  @spec select_mode(request :: Absinthe.Plug.Request.t()) ::
          :start_interface | {:process, Absinthe.Plug.Request.t()}
  defp select_mode(%{queries: [%Absinthe.Plug.Request.Query{document: nil}]}),
    do: :start_interface

  defp select_mode(request), do: {:process, request}

  defp find_socket_path(conn, socket) do
    if endpoint = conn.private[:phoenix_endpoint] do
      Enum.find_value(endpoint.__sockets__, :error, fn
        # Phoenix 1.4
        {path, ^socket, _opts} -> {:ok, path}
        # Phoenix <= 1.3
        {path, ^socket} -> {:ok, path}
        _ -> false
      end)
    else
      :error
    end
  end

  @spec render_interface(Plug.Conn.t(), :advanced | :simple | :playground | :apollo_explorer_sandbox, map) ::
          Plug.Conn.t()
  defp render_interface(conn, interface, opts)

  defp render_interface(conn, :simple, opts) do
    graphiql_html(
      opts[:query],
      opts[:var_string],
      opts[:result],
      opts[:socket_url],
      opts[:assets]
    )
    |> rendered(conn)
  end

  defp render_interface(conn, :advanced, opts) do
    graphiql_workspace_html(
      opts[:query],
      opts[:var_string],
      opts[:default_headers] |> to_json_kv_list(opts.json_codec),
      opts[:default_url] |> with_fallback_default_url(),
      opts[:socket_url],
      opts[:assets]
    )
    |> rendered(conn)
  end

  defp render_interface(conn, :playground, opts) do
    graphiql_playground_html(
      opts[:default_url] |> with_fallback_default_url(),
      opts[:socket_url],
      opts[:assets]
    )
    |> rendered(conn)
  end

  defp render_interface(conn, :apollo_explorer_sandbox, opts) do
    default_url = opts[:default_url] || conn.assigns[:graphql_url]

    graphiql_apollo_explorer_sandbox_html(
      opts[:query],
      opts[:var_string],
      opts[:default_headers] |> to_url_encoded!(),
      default_url |> with_fallback_default_url()
    )
    |> rendered(conn)
  end

  @render_defaults %{var_string: "", result: ""}

  defp get_resolved_config(opts, conn) do
    @render_defaults
    |> Map.put(:query, opts[:default_query])
    |> Map.merge(opts)
    |> resolve_config_value(conn, {:default_headers, :map})
    |> resolve_config_value(conn, {:default_url, :string})
    |> resolve_config_value(conn, {:socket_url, :string})
    |> normalize_socket_url(conn)
  end

  defp with_fallback_default_url(nil), do: "window.location.origin + window.location.pathname"
  defp with_fallback_default_url(url), do: "'#{url}'"

  @spec rendered(String.t(), Plug.Conn.t()) :: Plug.Conn.t()
  defp rendered(html, conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp js_escape(string) do
    string
    |> String.replace(~r/\n/, "\\n")
    |> String.replace(~r/'/, "\\'")
  end

  defp function_arity(module, fun) do
    Enum.find([1, 0], nil, &function_exported?(module, fun, &1))
  end

  defp get_config_val(config, key, conn) do
    case Map.get(config, key) do
      {mod, fun} when is_atom(fun) ->
        case function_arity(mod, fun) do
          1 ->
            apply(mod, fun, [conn])

          0 ->
            apply(mod, fun, [])

          :error ->
            raise """
            invalid #{key}: expected `#{mod}.#{fun}/0` or `#{mod}.#{fun}/1` to have been defined

            Is the function public? Make sure it is.
            """
        end

      val ->
        val
    end
  end

  defp resolve_config_value(config, conn, {key, type})
       when type in [:atom, :string, :map] do
    value =
      case {get_config_val(config, key, conn), type} do
        {nil, :map} -> %{}
        {nil, _} -> nil
        {<<_::binary>> = val, :string} -> val
        {val, :atom} when is_atom(val) -> val
        {%_{} = val, :map} -> raise "invalid #{key}: expected nil or map, got struct `#{inspect(val)}`"
        {%{} = val, :map} when is_map(val) -> val
        val -> raise "invalid #{key}: expected nil or #{type}, got `#{inspect(val)}`"
      end

    Map.put(config, key, value)
  end

  defp normalize_socket_url(%{socket_url: nil, socket: socket} = config, conn) do
    url =
      with {:ok, socket_path} <- find_socket_path(conn, socket) do
        "`${protocol}//${window.location.host}#{socket_path}`"
      else
        _ -> "''"
      end

    %{config | socket_url: url}
  end

  defp normalize_socket_url(%{socket_url: url} = config, _) do
    %{config | socket_url: "'#{url}'"}
  end

  defp to_json(value, {mod, opts}) when is_atom(mod) and is_list(opts), do: mod.encode!(value, opts)
  defp to_json(value, mod) when is_atom(mod), do: to_json(value, {mod, pretty: true})

  defp to_json_kv_list(%{} = map, json_coded) do
    map
    |> Enum.map(fn {k, v} -> %{"name" => k, "value" => v} end)
    |> to_json(json_coded)
  end

  defp to_url_encoded!(nil), do: nil
  defp to_url_encoded!(%{} = map), do: URI.encode_query(map)
end
