defmodule Absinthe.Plug.Batch do
  @moduledoc """
  Support for React-Relay-Network-Layer's batched GraphQL requests,
  to be used with https://github.com/nodkz/react-relay-network-layer.

  This (mostly) solves https://github.com/facebook/relay/issues/724 in practice.

  Consult the README of that project for detailed usage information.

  You can integrate this into your Phoenix router in combination with a
  "vanilla" Absinthe.Plug, like so:

  ```
  scope "/graphql", Absinthe do
    pipe_through [:your_favorite_auth, :other_stuff]
    get "/batch", Relay.BatchPlug, schema: App.Schema
    post "/batch", Relay.BatchPlug, schema: App.Schema
    get "/", Plug, schema: App.Schema
    post "/", Plug, schema: App.Schema
  end
  ```
  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  @type opts :: [
    schema: atom,
    adapter: atom,
    path: binary,
    context: map,
    json_codec: atom | {atom, Keyword.t}
  ]

  @doc """
  Sets up and validates the Absinthe schema
  """
  @spec init(opts :: opts) :: map
  defdelegate init(opts), to: Absinthe.Plug

  @doc """
  Parses, validates, resolves, and executes the given Graphql Document
  """
  def call(conn, config) do
    conn
    |> execute(config)
    |> Absinthe.Plug.handle_result(config)
  end

  @doc false
  def execute(conn, config) do

    result_list = with {:ok, prepared_queries} <- prepare(conn, config),
      parsed_prepared_queries <- parse_prepared_queries(prepared_queries) do

      query_results = parsed_prepared_queries
        |> Enum.map(fn {id, doc, absinthe_opts} ->
          case Absinthe.run(doc, config.schema_mod, absinthe_opts) do
            {:ok, result} -> %{id: id, payload: result}
            {:error, msg} -> %{id: id, payload: %{error: msg}}
          end
        end)

      {:ok, query_results}
    end

    {conn, result_list}
  end

  @doc false
  def prepare(conn, config) do
    with queries <- conn.body_params["_json"] do

      Logger.debug("""
      Batched GraphQL Documents:
      #{inspect(queries)}
      """)

      prepared_queries = queries
        |> Enum.map(&prepare_query(conn, config, &1))

      prepared_queries
      |> Enum.filter_map(fn
        {:ok, _, _, _} -> false
        {_, _msg} -> true
      end, fn {_, msg} -> msg end)
      |> case do
        [] -> {:ok, prepared_queries}
        msgs -> {:input_error, Enum.join(msgs, "; ")}
      end
    end
  end

  defp prepare_query(conn, config, %{"query" => query, "variables" => variables, "id" => id}) do
    with {:ok, operation_name} <- get_operation_name(query),
    {:ok, doc} <- validate_input(query),
    :ok <- validate_http_method(conn, doc) do

      absinthe_opts = %{
        variables: variables,
        adapter: config.adapter,
        context: Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
        operation_name: operation_name
      }

      {:ok, id, query, absinthe_opts}
    end
  end

  def parse_prepared_queries(prepared_queries) do
    prepared_queries
    |> Enum.map(fn {:ok, id, query, absinthe_opts} ->
      with {:ok, doc} <- Absinthe.parse(query) do
        {id, doc, absinthe_opts}
      end
    end)
  end

  defp validate_input(nil), do: {:input_error, "No query document supplied"}
  defp validate_input(""), do: {:input_error, "No query document supplied"}
  defp validate_input(doc), do: {:ok, doc}

  defp get_operation_name(query) do
    ~r"(query|subscription|mutation)\s+(\w+)\s*(\(|\{)"
    |> Regex.scan(query, capture: :all_but_first)
    |> hd
    |> case do
      [_, operation_name, _] -> {:ok, operation_name}
      _ -> {:input_error, "Invalid operation name"}
    end
  end

  @doc false
  def json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end

  @doc false
  def validate_http_method(%{method: "GET"}, %{definitions: [%{operation: operation}]})
    when operation in ~w(mutation subscription)a do

    {:http_error, "Can only perform a #{operation} from a POST request"}
  end
  def validate_http_method(_, _), do: :ok

end
