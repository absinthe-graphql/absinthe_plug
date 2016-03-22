defmodule Absinthe.Plug.GraphIQL do
  @moduledoc """
  Enables GraphIQL

  # Usage

  ```elixir
  if Absinthe.Plug.GraphIQL.serve? do
    plug Absinthe.Plug.GraphIQL
  end
  ```
  """

  def serve? do
    Application.get_env(:absinthe_plug, :serve_graphiql)
  end

  require EEx
  @graphql_version "0.6.0"
  EEx.function_from_file :defp, :graphiql_html, Path.join(__DIR__, "graphiql.html.eex"),
    [:graphiql_version, :query_string, :variables_string, :result_string]


  @behaviour Plug

  import Plug.Conn
  import Absinthe.Plug, only: [prepare: 2, validate_http_method: 2, json: 4]

  defdelegate init(opts), to: Absinthe.Plug

  def call(conn, %{json_codec: json_codec} = config) do
    with {:ok, input, opts} <- prepare(conn, config),
    {:ok, doc} <- Absinthe.parse(input),
    :ok <- validate_http_method(conn, doc),
    {:ok, result} <- Absinthe.run(doc, config.schema_mod, opts) do
      {:ok, result, opts.variables, input}
    end
    |> case do
      {:ok, result, variables, query} ->
        var_string = variables
        |> Poison.encode!

        result = result
        |> Poison.encode!

        html = graphiql_html(@graphql_version, query, var_string, result)
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
end
