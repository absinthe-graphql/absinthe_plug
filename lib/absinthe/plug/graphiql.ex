defmodule Absinthe.Plug.GraphiQL do
  @moduledoc """
  Enables GraphiQL

  # Usage

  ```elixir
  if Absinthe.Plug.GraphiQL.serve? do
    plug Absinthe.Plug.GraphiQL
  end
  ```
  """

  require EEx
  @graphiql_version "0.7.8"
  EEx.function_from_file :defp, :graphiql_html, Path.join(__DIR__, "graphiql.html.eex"),
    [:graphiql_version, :query_string, :variables_string, :result_string]

  @graphql_toolbox_version "1.0.1"
  EEx.function_from_file :defp, :graphql_toolbox_html, Path.join(__DIR__, "graphql_toolbox.html.eex"),
    [:graphql_toolbox_version, :query_string, :variables_string]

  @behaviour Plug

  import Plug.Conn
  import Absinthe.Plug, only: [prepare: 3, setup_pipeline: 3, load_body_and_params: 1]

  @type opts :: [
    schema: atom,
    adapter: atom,
    path: binary,
    context: map,
    json_codec: atom | {atom, Keyword.t},
    interface: atom
  ]

  @doc """
  Sets up and validates the Absinthe schema
  """
  @spec init(opts :: opts) :: map
  def init(opts) do
    opts
    |> Absinthe.Plug.init
    |> Map.put(:interface, Keyword.get(opts, :interface, :advanced))
  end

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
      string when is_binary(string) -> String.contains?(string, "text/html")
      _ -> false
    end
  end

  defp do_call(conn, %{json_codec: _, interface: interface} = config) do
    {conn, body} = load_body_and_params(conn)

    with {:ok, input, opts} <- prepare(conn, body, config),
    pipeline <- setup_pipeline(conn, config, opts),
    {:ok, result, _} <- Absinthe.Pipeline.run(input, pipeline) do
      {:ok, result, opts[:variables], input}
    end
    |> case do
      {:ok, result, variables, query} ->
        query = query |> js_escape

        var_string = variables
        |> Poison.encode!(pretty: true)
        |> js_escape

        result = result
        |> Poison.encode!(pretty: true)
        |> js_escape

        html = case interface do
          :advanced -> graphql_toolbox_html(@graphql_toolbox_version, query, var_string)
          :simple -> graphiql_html(@graphiql_version, query, var_string, result)
        end

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:error, {:http_method, text}, _} ->
        conn
        |> send_resp(405, text)

      {:error, error, _} when is_binary(error) ->
        conn
        |> send_resp(500, error)

    end
  end

  defp js_escape(string) do
    string
    |> String.replace(~r/\n/, "\\n")
    |> String.replace(~r/'/, "\\'")
  end
end
