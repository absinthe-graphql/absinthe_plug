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
  @graphiql_version "0.7.1"
  EEx.function_from_file :defp, :graphiql_html, Path.join(__DIR__, "graphiql.html.eex"),
    [:graphiql_version, :query_string, :variables_string, :result_string]


  @behaviour Plug

  import Plug.Conn
  import Absinthe.Plug, only: [prepare: 3, validate_http_method: 2, json: 4, load_body_and_params: 1]

  defdelegate init(opts), to: Absinthe.Plug

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

  defp do_call(conn, %{json_codec: json_codec} = config) do
    {conn, body} = load_body_and_params(conn)
    IO.inspect("Conn: #{inspect(conn)}, body: #{inspect(body)}")

    with {:ok, input, opts} <- prepare(conn, body, config),
    {:ok, doc} <- Absinthe.parse(input),
    :ok <- validate_http_method(conn, doc),
    {:ok, result} <- Absinthe.run(doc, config.schema_mod, opts) do
      {:ok, result, opts.variables, input}
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

        html = graphiql_html(@graphiql_version, query, var_string, result)
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:http_error, text} ->
        conn
        |> send_resp(405, text)

      {:error, %{message: message, locations: locations}} ->
        conn
        |> json(400, %{errors: [%{message: message, locations: locations}]}, json_codec)

      {:error, error} ->
        conn
        |> json(400, %{errors: [error]}, json_codec)
    end
  end

  defp js_escape(string) do
    string
    |> String.replace(~r/\n/, "\\n")
    |> String.replace(~r/'/, "\\'")
  end
end
