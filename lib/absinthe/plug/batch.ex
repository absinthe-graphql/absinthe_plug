defmodule Absinthe.Plug.Batch do
  @moduledoc """
  A batch plug for using Absinthe.

  See [The Guides](http://absinthe-graphql.org/guides/plug-phoenix/) for usage details.

  This batch plug implements support for React-Relay-Network-Layer's batched GraphQL requests,
  to be used with https://github.com/nodkz/react-relay-network-layer.
  Consult the README of that project for detailed usage information.

  This module is a variation on Absinthe.Plug.Batch. In this module, the operations in queries
  are joined together into one operation.

  This solves the transport side of https://github.com/facebook/relay/issues/724 in practice.

  You can integrate this into your Phoenix router in combination with a
  "vanilla" Absinthe.Plug, like so:

  ```
  scope "/graphql", Absinthe do
    pipe_through [:your_favorite_auth, :other_stuff]
    get "/batch", Plug.Batch, schema: App.Schema
    post "/batch", Plug.Batch, schema: App.Schema
    get "/", Plug, schema: App.Schema
    post "/", Plug, schema: App.Schema
  end
  ```
  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  alias Absinthe.Phase

  @type function_name :: atom

  @type opts :: [
    schema: atom,
    adapter: atom,
    path: binary,
    context: map,
    json_codec: atom | {atom, Keyword.t},
    no_query_message: binary,
  ]

  @doc """
  Sets up and validates the Absinthe schema
  """
  @spec init(opts :: opts) :: map
  def init(opts) do
    adapter = Keyword.get(opts, :adapter)
    context = Keyword.get(opts, :context, %{})

    no_query_message = Keyword.get(opts, :no_query_message, "No query document supplied")
    wrong_http_method_message = Keyword.get(opts, :wrong_http_method_message, "Can only perform batch queries from a POST request")

    json_codec = case Keyword.get(opts, :json_codec, Poison) do
      module when is_atom(module) -> %{module: module, opts: []}
      other -> other
    end

    # This function is applied to each result tuple in the shape of {%{data: ...}, "1"}
    # before sending the result down the wire. As a default, we'll use
    # the format required by react-relay-network-layer's batching mechanism
    payload_formatter = Keyword.get(opts, :payload_formatter, {__MODULE__, :default_payload_formatter})

    schema_mod = opts |> get_schema

    %{
      adapter: adapter,
      schema_mod: schema_mod,
      context: context,
      json_codec: json_codec,
      payload_formatter: payload_formatter,
      no_query_message: no_query_message,
      wrong_http_method_message: wrong_http_method_message,
    }
  end

  defp get_schema(opts) do
    default = Application.get_env(:absinthe, :schema)
    schema = Keyword.get(opts, :schema, default)
    try do
      Absinthe.Schema.types(schema)
    rescue
      UndefinedFunctionError ->
        raise ArgumentError, "The supplied schema: #{inspect schema} is not a valid Absinthe Schema"
    end
    schema
  end

  @doc """
  Parses, validates, resolves, and executes the given Graphql Document
  """
  def call(conn, %{json_codec: json_codec} = config) do
    {conn, result} = conn |> execute(config)

    case result do
      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:ok, result} ->
        conn
        |> json(200, result, json_codec)

      {:error, {:http_method, text}, _} ->
        conn
        |> send_resp(405, text)

      {:error, error, _} when is_binary(error) ->
        conn
        |> send_resp(500, error)

    end
  end

  @doc false
  def execute(conn, config) do
    {conn, body} = load_body_and_params(conn)

    with {:ok, body} <- ensure_http_post_method(conn, body, config),
    {:ok, queries} <- prepare_queries(conn, body, config),
    true <- valid_query_list?(queries, config.no_query_message) do
      prepared_documents = prepare_documents(config, queries)
      # prepared_documents is a list of blueprints that have had all phases
      # prior to resolution run upon them. They may have various validation errors.

      # Check if any of the prepared documents have errors. At this stage,
      # this could mean they have non-empty :error fields *OR* they are simply
      # an {:input_error, msg}.
      {valid_prepared_documents, invalid_documents} =
        prepared_documents
        |> Enum.partition(fn
          %{errors: []} -> true
          {:error, _} -> false
        end)

      valid_resolved = resolve_documents(config, valid_prepared_documents)

      invalid_resolved = format_invalid_documents(conn, config, invalid_documents)

      {conn, {:ok, valid_resolved ++ invalid_resolved}}
    else
      {:input_error, msg} -> {conn, {:input_error, msg}}
      {:error, msg} -> {conn, {:error, msg}}
    end
  end

  @doc false
  def prepare_queries(conn, body, config) do
    queries_list = Map.get(conn.params, "query", body)

    Logger.debug("""
    GraphQL Documents:
    #{inspect(queries_list)}
    """)

    case queries_list do
      [] -> {:input_error, config.no_query_message}
      nil -> {:input_error, config.no_query_message}
      "" -> {:input_error, config.no_query_message}
      queries -> {:ok, Enum.map(queries, &prepare(conn, &1, config))}
    end
  end

  def prepare(conn, query_input, config) do
    variables = Map.get(query_input, "variables", %{})
    query_string = Map.get(query_input, "query")
    query_id = Map.get(query_input, "id")

    absinthe_opts = [
      variables: variables,
      context: Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
      operation_name: nil, # doesn't matter -- the first one is set to current anyway
      query_id: query_id,
      jump_phases: false,
    ]
    %{query_string: query_string, opts: absinthe_opts}
  end

  defp valid_query_list?(queries, no_query_message) do
    Enum.all?(queries, fn query ->
      query.query_string && query.opts[:query_id]
    end) || {:input_error, no_query_message}
  end

  defp prepare_documents(config, queries) do
    Enum.map(queries, fn query ->
      preparation_pipeline = preparation_pipeline(config, query.opts)

      with {:ok, prepared_document, _} <- Absinthe.Pipeline.run(query.query_string, preparation_pipeline) do
        prepared_document
      end
    end)
  end

  defp preparation_pipeline(config, opts) do
    config.schema_mod
    |> Absinthe.Pipeline.for_document(opts)
    |> Absinthe.Pipeline.upto(Absinthe.Phase.Document.Flatten)
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Document.Flatten,
      {Absinthe.Plug.Batch.QueryLabelPhase, opts})
  end

  defp resolve_documents(config, prepared_documents) do
    # Run all documents through the BatchSingleOperation phase,
    # which merges them into a single operation, resolves, and then
    # teases everything apart again (by query id) into a list of
    # resolved documents. Then pass each result through the formatter.
    {module, fun} = config.payload_formatter

    prepared_documents
    # TODO: clean this up
    |> Absinthe.Plug.Batch.Runner.run(context: config.context, schema: config.schema_mod)
    |> Enum.map(fn doc ->
      {:ok, result, _} = Absinthe.Pipeline.run(doc, formatting_pipeline())
      {query_id, _} = doc.flags.query_id

      apply(module, fun, [{result, query_id}])
    end)
  end

  defp format_invalid_documents(_conn, config, invalid_documents) do
    {module, fun} = config.payload_formatter

    invalid_documents
    |> Enum.map(fn blueprint ->
      {:ok, result, _} = Absinthe.Pipeline.run(blueprint, formatting_pipeline())
      {query_id, _} = blueprint.flags.query_id
      apply(module, fun, [{result, query_id}])
    end)
  end

  def formatting_pipeline() do
    [Phase.Document.Result]
  end

  @doc false
  defp ensure_http_post_method(%{method: "POST"}, body, _config), do: {:ok, body}
  defp ensure_http_post_method(%{method: _}, _body, config), do: {:input_error, config.wrong_http_method_message}

  def default_payload_formatter({result, query_id}) do
    %{payload: result, id: query_id}
  end

  def load_body_and_params(conn) do
    case get_req_header(conn, "content-type") do
      ["application/json"] ->
        {conn, conn.params["_json"]}
      _ ->
        {conn, ""}
    end
  end

  @doc false
  def json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end
end
