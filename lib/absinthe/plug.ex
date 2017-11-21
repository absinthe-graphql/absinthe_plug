defmodule Absinthe.Plug do
  @moduledoc """
  A plug for using [Absinthe](https://hex.pm/packages/absinthe) (GraphQL).

  ## Usage

  In your router:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Poison

      plug Absinthe.Plug,
        schema: MyAppWeb.Schema

  If you want only `Absinthe.Plug` to serve a particular route, configure your
  router like:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Poison

      forward "/api",
        to: Absinthe.Plug,
        init_opts: [schema: MyAppWeb.Schema]

  See the documentation on `Absinthe.Plug.init/1` and the `Absinthe.Plug.opts`
  type for information on the available options.

  To add support for a GraphiQL interface, add a configuration for
  `Absinthe.Plug.GraphiQL`:

    forward "/graphiql",
      to: Absinthe.Plug.GraphiQL,
      init_opts: [schema: MyAppWeb.Schema]

  For more information, see the API documentation for `Absinthe.Plug`.

  ### Phoenix.Router

  If you are using [Phoenix.Router](https://hexdocs.pm/phoenix/Phoenix.Router.html), `forward` expects different arguments:

  #### Plug.Router

      forward "/graphiql",
        to: Absinthe.Plug.GraphiQL,
        init_opts: [
          schema: MyAppWeb.Schema,
          interface: :simple
        ]

  #### Phoenix.Router

      forward "/graphiql",
        Absinthe.Plug.GraphiQL,
         schema: MyAppWeb.Schema,
         interface: :simple

  For more information see [Phoenix.Router.forward/4](https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4).

  ## Included GraphQL Types

  This package includes additional types for use in Absinthe GraphQL schema and
  type modules.

  See the documentation on `Absinthe.Plug.Types` for more information.

  ## More Information

  For more on configuring `Absinthe.Plug` and how GraphQL requests are made,
  see [the guide](http://absinthe-graphql.org/guides/plug-phoenix/) at
  <http://absinthe-graphql.org>.

  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  alias __MODULE__.Request

  @raw_options [:analyze_complexity, :max_complexity]

  @type function_name :: atom

  @typedoc """
  - `:adapter` -- (Optional) Absinthe adapter to use (default: `Absinthe.Adapter.LanguageConventions`).
  - `:context` -- (Optional) Initial value for the Absinthe context, available to resolvers. (default: `%{}`).
  - `:no_query_message` -- (Optional) Message to return to the client if no query is provided (default: "No query document supplied").
  - `:json_codec` -- (Optional) A `module` or `{module, Keyword.t}` dictating which JSON codec should be used (default: `Poison`). The codec module should implement `encode!/2` (e.g., `module.encode!(body, opts)`).
  - `:pipeline` -- (Optional) `{module, atom}` reference to a 2-arity function that will be called to generate the processing pipeline. (default: `{Absinthe.Plug, :default_pipeline}`).
  - `:document_providers` -- (Optional) A `{module, atom}` reference to a 1-arity function that will be called to determine the document providers that will be used to process the request. (default: `{Absinthe.Plug, :default_document_providers}`, which configures `Absinthe.Plug.DocumentProvider.Default` as the lone document provider). A simple list of document providers can also be given. See `Absinthe.Plug.DocumentProvider` for more information about document providers, their role in procesing requests, and how you can define and configure your own.
  - `:schema` -- (Required, if not handled by Mix.Config) The Absinthe schema to use. If a module name is not provided, `Application.get_env(:absinthe, :schema)` will be attempt to find one.
  - `:serializer` -- (Optional) Similar to `:json_codec` but allows the use of serialization formats other than JSON, like MessagePack or Erlang Term Format. Defaults to whatever is set in `:json_codec`.
  - `content_type` -- (Optional) The content type of the response. Should probably be set if `:serializer` option is used. Defaults to `"application/json"`.
  """
  @type opts :: [
    schema: module,
    adapter: module,
    context: map,
    json_codec: module | {module, Keyword.t},
    pipeline: {module, atom},
    no_query_message: String.t,
    document_providers: [Absinthe.Plug.DocumentProvider.t, ...] | Absinthe.Plug.DocumentProvider.t | {module, atom},
    analyze_complexity: boolean,
    max_complexity: non_neg_integer | :infinity,
    serializer: module | {module, Keyword.t},
    content_type: String.t,
  ]

  @doc """
  Serve an Absinthe GraphQL schema with the specified options.

  ## Options

  See the documentation for the `Absinthe.Plug.opts` type for details on the available options.
  """
  @spec init(opts :: opts) :: map
  def init(opts) do
    adapter = Keyword.get(opts, :adapter, Absinthe.Adapter.LanguageConventions)
    context = Keyword.get(opts, :context, %{})

    no_query_message = Keyword.get(opts, :no_query_message, "No query document supplied")

    pipeline = Keyword.get(opts, :pipeline, {__MODULE__, :default_pipeline})
    document_providers = Keyword.get(opts, :document_providers, {__MODULE__, :default_document_providers})

    json_codec = case Keyword.get(opts, :json_codec, Poison) do
      module when is_atom(module) -> %{module: module, opts: []}
      other -> other
    end

    serializer = case Keyword.get(opts, :serializer, json_codec) do
      module when is_atom(module) -> %{module: module, opts: []}
      {mod, opts} -> %{module: mod, opts: opts}
      other -> other
    end

    content_type = Keyword.get(opts, :content_type, "application/json")

    schema_mod = opts |> get_schema

    raw_options = Keyword.take(opts, @raw_options)
    log_level = Keyword.get(opts, :log_level, :debug)

    pubsub = Keyword.get(opts, :pubsub, nil)

    %{
      adapter: adapter,
      context: context,
      document_providers: document_providers,
      json_codec: json_codec,
      no_query_message: no_query_message,
      pipeline: pipeline,
      raw_options: raw_options,
      schema_mod: schema_mod,
      serializer: serializer,
      content_type: content_type,
      log_level: log_level,
      pubsub: pubsub,
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
  @spec call(Plug.Conn.t, map) :: Plug.Conn.t | no_return
  def call(conn, config) do
    config = update_config(conn, config)
    {conn, result} = conn |> execute(config)

    case result do
      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:ok, %{"subscribed" => topic}} ->
        conn
        |> subscribe(topic, config)

      {:ok, %{data: _} = result} ->
        conn
        |> encode(200, result, config)

      {:ok, %{errors: _} = result} ->
        conn
        |> encode(400, result, config)

      {:ok, result} when is_list(result) ->
        conn
        |> encode(200, result, config)

      {:error, {:http_method, text}, _} ->
        conn
        |> send_resp(405, text)

      {:error, error, _} when is_binary(error) ->
        conn
        |> send_resp(500, error)

    end
  end

  defp update_config(conn, config) do
    pubsub = config[:pubsub] || config.context[:pubsub] || conn.private[:phoenix_endpoint]
    if pubsub do
      put_in(config, [:context, :pubsub], pubsub)
    else
      config
    end
  end

  def subscribe(conn, topic, %{context: %{pubsub: pubsub}} = config) do
    pubsub.subscribe(topic)
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> send_chunked(200)
    |> subscribe_loop(topic, config)
  end

  def subscribe_loop(conn, topic, config) do
    receive do
      %{event: "subscription:data", payload: %{result: result}} ->
        case chunk(conn, "#{encode_json!(result, config)}\n\n") do
          {:ok, conn} ->
            subscribe_loop(conn, topic, config)
          {:error, :closed} ->
            Absinthe.Subscription.unsubscribe(config.context.pubsub, topic)
            conn
        end
      :close ->
        Absinthe.Subscription.unsubscribe(config.context.pubsub, topic)
        conn
    after
      30_000 ->
        case chunk(conn, ":ping\n\n") do
          {:ok, conn} ->
            subscribe_loop(conn, topic, config)
          {:error, :closed} ->
            Absinthe.Subscription.unsubscribe(config.context.pubsub, topic)
            conn
        end
    end
  end

  @doc """
  Sets the options for a given GraphQL document execution.

  ## Examples

      iex> Absinthe.Plug.put_options(conn, context: %{current_user: user})
      %Plug.Conn{}
  """
  @spec put_options(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def put_options(%Plug.Conn{private: %{absinthe: absinthe}} = conn, opts) do
    opts = Map.merge(absinthe, Enum.into(opts, %{}))
    Plug.Conn.put_private(conn, :absinthe, opts)
  end
  def put_options(conn, opts) do
    Plug.Conn.put_private(conn, :absinthe, Enum.into(opts, %{}))
  end

  @doc false
  @spec execute(Plug.Conn.t, map) :: {Plug.Conn.t, any}
  def execute(conn, config) do
    conn_info = %{
      conn_private: (conn.private[:absinthe] || %{}) |> Map.put(:http_method, conn.method),
    }

    with {:ok, conn, request} <- Request.parse(conn, config),
         {:ok, request} <- ensure_processable(request, config) do
      {conn, run_request(request, conn_info, config)}
    else
      result ->
        {conn, result}
    end
  end

  @doc false
  @spec ensure_processable(Request.t, map) :: {:ok, Request.t} | {:input_error, String.t}
  def ensure_processable(request, config) do
    with {:ok, request} <- ensure_documents(request, config) do
      ensure_document_provider(request)
    end
  end

  @spec ensure_documents(Request.t, map) :: {:ok, Request.t} | {:input_error, String.t}
  defp ensure_documents(%{queries: []}, config) do
    {:input_error, config.no_query_message}
  end
  defp ensure_documents(%{queries: queries} = request, config) do
    Enum.reduce_while(queries, {:ok, request}, fn query, _acc ->
      query_status = case query do
        {:input_error, error_msg} -> {:input_error, error_msg}
        query -> ensure_document(query, config)
      end

      case query_status do
        {:ok, _query} -> {:cont, {:ok, request}}
        {:input_error, error_msg} -> {:halt, {:input_error, error_msg}}
      end
    end)
  end

  @spec ensure_document(Request.t, map) :: {:ok, Request.t} | {:input_error, String.t}
  defp ensure_document(%{document: nil}, config) do
    {:input_error, config.no_query_message}
  end
  defp ensure_document(%{document: _} = query, _) do
    {:ok, query}
  end

  @spec ensure_document_provider(Request.t) :: {:ok, Request.t} | {:input_error, String.t}
  defp ensure_document_provider(%{queries: queries} = request) do
    if Enum.all?(queries, &Map.has_key?(&1, :document_provider)) do
      {:ok, request}
    else
      {:input_error, "No document provider found to handle this request"}
    end
  end

  def run_request(%{batch: true, queries: queries} = request, conn, config) do
    Request.log(request, config.log_level)
    results =
      queries
      |> Absinthe.Plug.Batch.Runner.run(conn, config)
      |> Enum.zip(request.extra_keys)
      |> Enum.map(fn {result, extra_keys} ->
        Map.merge(extra_keys, %{
          payload: result
        })
      end)

    {:ok, results}
  end
  def run_request(%{batch: false, queries: [query]} = request, conn_info, config) do
    Request.log(request, config.log_level)
    run_query(query, conn_info, config)
  end

  def run_query(query, conn_info, config) do
    %{document: document, pipeline: pipeline} = Request.Query.add_pipeline(query, conn_info, config)

    with {:ok, %{result: result}, _} <- Absinthe.Pipeline.run(document, pipeline) do
      {:ok, result}
    end
  end

  #
  # PIPELINE
  #

  @doc """
  The default pipeline used to process GraphQL documents.

  This consists of Absinthe's default pipeline (as returned by `Absinthe.Pipeline.for_document/1`),
  with the `Absinthe.Plug.Validation.HTTPMethod` phase inserted to ensure that the correct
  HTTP verb is being used for the GraphQL operation type.
  """
  @spec default_pipeline(map, Keyword.t) :: Absinthe.Pipeline.t
  def default_pipeline(config, pipeline_opts) do
    config.schema_mod
    |> Absinthe.Pipeline.for_document(pipeline_opts)
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Document.CurrentOperation,
      [
        {Absinthe.Plug.Validation.HTTPMethod, method: config.conn_private.http_method},
      ]
    )
  end

  #
  # DOCUMENT PROVIDERS
  #


  @doc """
  The default list of document providers that are enabled.

  This consists of a single document provider, `Absinthe.Plug.DocumentProvider.Default`, which
  supports ad hoc GraphQL documents provided directly within the request.

  For more information about document providers, see `Absinthe.Plug.DocumentProvider`.
  """
  @spec default_document_providers(map) :: [Absinthe.Plug.DocumentProvider.t]
  def default_document_providers(_) do
    [Absinthe.Plug.DocumentProvider.Default]
  end

  #
  # SERIALIZATION
  #

  @doc false
  @spec encode(Plug.Conn.t, 200 | 400 | 405 | 500, String.t, map) :: Plug.Conn.t | no_return
  def encode(conn, status, body, %{serializer: %{module: mod, opts: opts}, content_type: content_type}) do
    conn
    |> put_resp_content_type(content_type)
    |> send_resp(status, mod.encode!(body, opts))
  end

  def encode_json!(value, %{json_codec: json_codec}) do
    json_codec.module.encode!(value, json_codec.opts)
  end

end
