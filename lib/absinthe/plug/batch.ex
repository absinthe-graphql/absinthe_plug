defmodule Absinthe.Plug.Batch do
  @moduledoc """
  A plug for using Absinthe

  See [The Guides](http://absinthe-graphql.org/guides/plug-phoenix/) for usage details
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

    %{adapter: adapter, schema_mod: schema_mod, context: context, json_codec: json_codec,
      payload_formatter: payload_formatter, no_query_message: no_query_message,
      wrong_http_method_message: wrong_http_method_message
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
    {:ok, prepared_queries} <- prepare_queries(conn, body, config),
    {:ok, queries} <- validate_query_list(prepared_queries, config.no_query_message) do

      prepared_documents = prepare_documents(conn, config, queries)

      # Check if any of the prepared documents have errors. At this stage,
      # this could mean they have non-empty :error fields *OR* they are simply
      # an {:input_error, msg}.

      {valid_prepared_documents_with_ids, invalid_documents_with_ids} = queries
        |> Enum.map(&Keyword.get(&1.opts, :query_id, nil))
        |> Enum.zip(prepared_documents)
        |> Enum.partition(fn
          {_query_id, %{errors: errors}} -> Enum.empty?(errors) # if true, this is valid
          {_query_id, {:input_error, _}} -> false
          {_query_id, {:error, _}} -> false
        end)

      valid_prepared_documents = valid_prepared_documents_with_ids  
        |> Enum.map(fn {_, doc} -> doc end)

      resolved_documents = resolve_documents(conn, config, valid_prepared_documents)
      error_documents = format_invalid_documents(conn, config, invalid_documents_with_ids)

      {conn, {:ok, resolved_documents ++ error_documents}}
    else
      {:input_error, msg} -> {conn, {:input_error, msg}}
      {:error, msg} -> {conn, {:error, msg}}
    end
  end
  
  def prepare_documents(conn, config, queries) do
    queries
    |> Enum.map(fn q ->
      with preparation_pipeline <- setup_pipeline(conn, config, {__MODULE__, :preparation_pipeline}, q.opts),
      {:ok, prepared_document, _} <- Absinthe.Pipeline.run(q.query_string, preparation_pipeline) do
        prepared_document
      else
        {:error, msg} -> {:error, msg}
        msg -> {:input_error, msg}
      end
    end)
  end

  defp resolve_documents(conn, config, prepared_documents) do
    # Run all documents through the BatchSingleOperation phase,
    # which merges them into a single operation, resolves, and then
    # teases everything apart again (by query id) into a list of
    # resolved documents. Then pass each result through the formatter.
    with resolving_pipeline <- setup_pipeline(conn, config, {__MODULE__, :resolution_pipeline}, %{}),
    {:ok, resolved_documents, _} <- Absinthe.Pipeline.run(prepared_documents, resolving_pipeline),
    formatting_pipeline <- setup_pipeline(conn, config, {__MODULE__, :formatting_pipeline}, %{}) do

      jsonified_results = resolved_documents
        |> Enum.map(fn doc ->
          with {:ok, result, _} <- Absinthe.Pipeline.run(doc, formatting_pipeline) do
            result
          end
        end)

      query_ids = prepared_documents
        |> Enum.map(&(&1.flags.query_id))

      # Bring them into the format desired by 
      # the client
      {module, fun} = config.payload_formatter
      jsonified_results
        |> Enum.zip(query_ids)
        |> Enum.map(fn {result, query_id} ->
          apply(module, fun, [{result, query_id}])
        end)
    end
  end

  defp format_invalid_documents(_conn, config, invalid_documents) do
    {module, fun} = config.payload_formatter

    invalid_documents
    |> Enum.map(fn
      {query_id, %{errors: errors}} -> {%{error: inspect(errors)}, query_id}
      {query_id, {:input_error, msg}} -> {%{error: msg}, query_id}
      {query_id, {:error, msg}} -> {%{error: msg}, query_id}
    end)
    |> Enum.map(fn {result, query_id} ->
      apply(module, fun, [{result, query_id}])
    end)
  end

  # Takes care of parsing queries into blueprints and validating them
  def preparation_pipeline(config, opts) do
    config.schema_mod
    |> Absinthe.Pipeline.for_document(opts)
    |> Absinthe.Pipeline.upto(Absinthe.Phase.Document.Flatten)
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Document.Flatten,
      {Absinthe.Plug.Batch.PutQueryId, opts})
  end

  # Takes a list of blueprints, joins them 
  def resolution_pipeline(config, _opts) do
    resolution_opts = [
      # doesn't need operation-specific variables etc. anymore – that's behind us now
      context: config.context #Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
    ]

    [{Absinthe.Plug.Batch.BatchResolutionPhase, resolution_opts}]
  end

  # Takes results and json-ifies them
  def formatting_pipeline(_config, _opts) do
    [Phase.Document.Result]
  end

  def setup_pipeline(conn, config, pipeline, opts) do
    private = conn.private[:absinthe] || %{}
    private = Map.put(private, :http_method, conn.method)
    config = Map.put(config, :conn_private, private)

    {module, fun} = pipeline
    apply(module, fun, [config, opts])
  end

  @doc false
  defp ensure_http_post_method(%{method: "POST"}, body, _config), do: {:ok, body}
  defp ensure_http_post_method(%{method: _}, _body, config), do: {:input_error, config.wrong_http_method_message}

  @doc false
  def prepare_queries(conn, body, config) do
    raw_input = Map.get(conn.params, "query", body)

    Logger.debug("""
    GraphQL Document:
    #{inspect(raw_input)}
    """)

    raw_input
    |> case do
      nil -> {:input_error, config.no_query_message}
      "" -> {:input_error, config.no_query_message}
      q -> {:ok, Enum.map(q, &prepare(conn, &1, config))}
    end
  end

  def prepare(conn, query_input, config) do
    variables = Map.get(query_input, "variables", %{})
    query_string = Map.get(query_input, "query", "")
    query_id = Map.get(query_input, "id", nil)

    absinthe_opts = [
      variables: variables,
      context: Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
      operation_name: nil, # doesn't matter -- the first one is set to current anyway
      query_id: query_id,
      jump_phases: false,
    ]
    %{query_string: query_string, opts: absinthe_opts}
  end

  defp validate_query_list(queries, no_query_message) do
    all_queries_valid = queries
      |> Enum.all?(fn q ->
        String.valid?(q.query_string)
        and q.query_string != ""
        and not is_nil(Keyword.get(q.opts, :query_id, nil))
      end)

    if all_queries_valid, do: {:ok, queries}, else: {:input_error, no_query_message}
  end

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
