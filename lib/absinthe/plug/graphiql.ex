defmodule Absinthe.Plug.GraphiQL do
  @moduledoc """
  Provides a GraphiQL interface.


  ## Examples

  The examples here are shown in

  Serve the GraphiQL "advanced" interface at `/graphiql`, but only in
  development:

      if Mix.env == :dev do
        forward "/graphiql",
          to: Absinthe.Plug.GraphiQL,
          init_opts: [schema: MyAppWeb.Schema]
      end

  Use the "simple" interface (original GraphiQL) instead:

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :simple
        ]

  Finally there is also support for GraphiQL Playground
  https://github.com/graphcool/graphql-playground

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :playground
        ]


  ## Interface Selection

  The GraphiQL interface can be switched using the `:interface` option.

  - `:advanced` (default) will serve the [GraphiQL Workspace](https://github.com/OlegIlyenko/graphiql-workspace) interface from Oleg Ilyenko.
  - `:simple` will serve the original [GraphiQL](https://github.com/graphql/graphiql) interface from Facebook.
  - `:playground` will serve the [GraphQL Playground](https://github.com/graphcool/graphql-playground) interface from Graphcool.

  See `Absinthe.Plug` for the other  options.

  ## Default Headers

  You can optionally provide default headers if the advanced interface (GraphiQL Workspace) is selected.
  Note that you may have to clean up your existing workspace by clicking the trashcan icon in order to see the newly set default headers.

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          default_headers: {__MODULE__, :graphiql_headers}
        ]

      def graphiql_headers do
        %{
          "X-CSRF-Token" => Plug.CSRFProtection.get_csrf_token(),
          "X-Foo" => "Bar"
        }
      end

  You can also provide a function that takes a conn argument if you need to access connection data
  (e.g. if you need to set an Authorization header based on the currently logged-in user).

      def graphiql_headers(conn) do
        %{
          "Authorization" => "Bearer " <> conn.assigns[:token]
        }
      end

  ## Default URL

  You can also optionally set the default URL to be used for sending the queries to.
  This only applies to the advanced interface (GraphiQL Workspace) and the GraphQL Playground.

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

  You can also optionally set the default websocket URL to be used for subscriptions.
  This only applies to the advanced interface (GraphiQL Workspace) and the GraphQL Playground.

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

  EEx.function_from_file :defp, :graphiql_html, Path.join(@graphiql_template_path, "graphiql.html.eex"),
    [:query_string, :variables_string, :result_string, :socket_url, :assets]

  EEx.function_from_file :defp, :graphiql_workspace_html, Path.join(@graphiql_template_path, "graphiql_workspace.html.eex"),
    [:query_string, :variables_string, :default_headers, :default_url, :socket_url, :assets]

  EEx.function_from_file :defp, :graphiql_playground_html, Path.join(@graphiql_template_path, "graphiql_playground.html.eex"),
  [:default_url, :socket_url, :assets]

  @behaviour Plug

  import Plug.Conn

  @type opts :: [
    schema: atom,
    adapter: atom,
    path: binary,
    context: map,
    json_codec: atom | {atom, Keyword.t},
    interface: :playground | :advanced | :simple,
    default_headers: {module, atom},
    default_url: binary,
    assets: Keyword.t,
    socket: module,
    socket_url: binary,
  ]

  @doc false
  @spec init(opts :: opts) :: map
  def init(opts) do
    assets = Absinthe.Plug.GraphiQL.Assets.get_assets()

    opts
    |> Absinthe.Plug.init
    |> Map.put(:interface, Keyword.get(opts, :interface) || :advanced)
    |> Map.put(:default_headers, Keyword.get(opts, :default_headers))
    |> Map.put(:default_url, Keyword.get(opts, :default_url))
    |> Map.put(:assets, assets)
    |> Map.put(:socket, Keyword.get(opts, :socket))
    |> Map.put(:socket_url, Keyword.get(opts, :socket_url))
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
    |> List.first
    |> case do
      string when is_binary(string) ->
        String.contains?(string, "text/html")
      _ ->
        false
    end
  end

  defp do_call(conn, %{interface: interface} = config) do
    config =
      config
      |> handle_default_headers(conn)
      |> put_config_value(:default_url, conn)
      |> handle_socket_url(conn)

    with {:ok, conn, request} <- Absinthe.Plug.Request.parse(conn, config),
         {:process, request} <- select_mode(request),
         {:ok, request} <- Absinthe.Plug.ensure_processable(request, config),
         :ok <- Absinthe.Plug.Request.log(request, config.log_level) do

      conn_info = %{
        conn_private: (conn.private[:absinthe] || %{}) |> Map.put(:http_method, conn.method),
      }

      {conn, result} = Absinthe.Plug.run_request(request, conn, conn_info, config)
      case result do
        {:ok, result} ->
          query = hd(request.queries) # GraphiQL doesn't batch requests, so the first query is the only one
          {:ok, conn, result, query.variables, query.document || ""}
        {:error, {:http_method, _}, _} ->
          query = hd(request.queries)
          {:http_method_error, query.variables, query.document || ""}
        other -> other
      end
    end
    |> case do
      {:ok, conn, result, variables, query} ->
        query = query |> js_escape

        var_string = variables
        |> config.json_codec.module.encode!(pretty: true)
        |> js_escape


        result = result
        |> config.json_codec.module.encode!(pretty: true)
        |> js_escape

        config = %{
          query: query,
          var_string: var_string,
          result: result,
        } |> Map.merge(config)

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

        config = %{
          query: query,
          var_string: var_string,
        } |> Map.merge(config)

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
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Document.CurrentOperation,
      [
        Absinthe.GraphiQL.Validation.NoSubscriptionOnHTTP,
      ]
    )
  end

  @spec select_mode(request :: Absinthe.Plug.Request.t) :: :start_interface | {:process, Absinthe.Plug.Request.t}
  defp select_mode(%{queries: [%Absinthe.Plug.Request.Query{document: nil}]}), do: :start_interface
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

  @render_defaults %{query: "", var_string: "", results: ""}

  @spec render_interface(conn :: Conn.t, interface :: :advanced | :simple, opts :: Keyword.t) :: Conn.t
  defp render_interface(conn, interface, opts)
  defp render_interface(conn, :simple, opts) do
    opts = Map.merge(@render_defaults, opts)

    graphiql_html(
      opts[:query], opts[:var_string], opts[:result], opts[:socket_url], opts[:assets]
    )
    |> rendered(conn)
  end
  defp render_interface(conn, :advanced, opts) do
    opts = Map.merge(@render_defaults, opts)

    graphiql_workspace_html(
      opts[:query], opts[:var_string], opts[:default_headers],
      default_url(opts[:default_url]), opts[:socket_url], opts[:assets]
    )
    |> rendered(conn)
  end
  defp render_interface(conn, :playground, opts) do
    opts = Map.merge(@render_defaults, opts)

    graphiql_playground_html(
      default_url(opts[:default_url]), opts[:socket_url], opts[:assets]
    )
    |> rendered(conn)
  end

  defp default_url(nil), do: "window.location.origin + window.location.pathname"
  defp default_url(url), do: "'#{url}'"

  @spec rendered(String.t, Plug.Conn.t) :: Conn.t
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

  defp handle_default_headers(config, conn) do
    case get_config_val(config, :default_headers, conn) do
      nil ->
        Map.put(config, :default_headers, "[]")

      val when is_map(val) ->
        header_string =
          val
          |> Enum.map(fn {k, v} -> %{"name" => k, "value" => v} end)
          |> config.json_codec.module.encode!(pretty: true)

        Map.put(config, :default_headers, header_string)

      val ->
        raise "invalid default headers: #{inspect val}"
    end
  end

  defp function_arity(module, fun) do
    Enum.find([1, 0], nil, &function_exported?(module, fun, &1))
  end

  defp put_config_value(config, key, conn) do
    case get_config_val(config, key, conn) do
      nil ->
        config
      val when is_binary(val) ->
        Map.put(config, key, val)
      val ->
        raise "invalid #{key}: #{inspect val}"
    end
  end

  defp get_config_val(config, key, conn) do
    case Map.get(config, key) do
      {module, fun} when is_atom(fun) ->
        case function_arity(module, fun) do
          1 -> apply(module, fun, [conn])
          0 -> apply(module, fun, [])
          _ ->
            raise "function for #{key}: {#{module}, #{fun}} is not exported with arity 1 or 0"
        end
      val ->
        val
    end
  end

  defp handle_socket_url(config, conn) do
    config
    |> put_config_value(:socket_url, conn)
    |> normalize_socket_url(conn)
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

end
