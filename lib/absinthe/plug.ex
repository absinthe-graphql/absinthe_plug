defmodule Absinthe.Plug do
  @moduledoc """
  A plug for using [Absinthe](https://hex.pm/packages/absinthe) (GraphQL).

  ## Usage

  In your router:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Jason

      plug Absinthe.Plug,
        schema: MyAppWeb.Schema

  If you want only `Absinthe.Plug` to serve a particular route, configure your
  router like:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Jason

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

  ## Before Send

  If you need to set a value (like a cookie) on the connection after resolution
  but before values are sent to the client, use the `:before_send` option:

  ```
  plug Absinthe.Plug,
    schema: MyApp.Schema,
    before_send: {__MODULE__, :absinthe_before_send}

  def absinthe_before_send(conn, %Absinthe.Blueprint{} = blueprint) do
    if auth_token = blueprint.execution.context[:auth_token] do
      put_session(conn, :auth_token, auth_token)
    else
      conn
    end
  end
  def absinthe_before_send(conn, _) do
    conn
  end
  ```

  The `auth_token` can be placed in the context by using middleware after your
  mutation resolve:

  ```
  # mutation resolver
  resolve fn args, _ ->
    case authenticate(args) do
      {:ok, token} -> {:ok, %{token: token}}
      error -> error
    end
  end
  # middleware afterward
  middleware fn resolution, _ ->
    with %{value: %{token: token}} <- resolution do
      Map.update!(resolution, :context, fn ctx ->
        Map.put(ctx, :auth_token, token)
      end)
    end
  end
  ```

  ## Included GraphQL Types

  This package includes additional types for use in Absinthe GraphQL schema and
  type modules.

  See the documentation on `Absinthe.Plug.Types` for more information.

  ## More Information

  For more on configuring `Absinthe.Plug` and how GraphQL requests are made,
  see [the guide](https://hexdocs.pm/absinthe/plug-phoenix.html) at
  <http://absinthe-graphql.org>.

  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  alias __MODULE__.Request

  @init_options [
    :adapter,
    :context,
    :no_query_message,
    :json_codec,
    :pipeline,
    :document_providers,
    :schema,
    :serializer,
    :content_type,
    :before_send,
    :log_level,
    :pubsub,
    :analyze_complexity,
    :max_complexity,
    :token_limit,
    :transport_batch_payload_key,
    :standard_sse
  ]
  @raw_options [
    :analyze_complexity,
    :max_complexity,
    :token_limit
  ]

  @type function_name :: atom

  @typedoc """
  - `:adapter` -- (Optional) Absinthe adapter to use (default: `Absinthe.Adapter.LanguageConventions`).
  - `:context` -- (Optional) Initial value for the Absinthe context, available to resolvers. (default: `%{}`).
  - `:no_query_message` -- (Optional) Message to return to the client if no query is provided (default: "No query document supplied").
  - `:json_codec` -- (Optional) A `module` or `{module, Keyword.t}` dictating which JSON codec should be used (default: `Jason`). The codec module should implement `encode!/2` (e.g., `module.encode!(body, opts)`).
  - `:pipeline` -- (Optional) `{module, atom}` reference to a 2-arity function that will be called to generate the processing pipeline. (default: `{Absinthe.Plug, :default_pipeline}`).
  - `:document_providers` -- (Optional) A `{module, atom}` reference to a 1-arity function that will be called to determine the document providers that will be used to process the request. (default: `{Absinthe.Plug, :default_document_providers}`, which configures `Absinthe.Plug.DocumentProvider.Default` as the lone document provider). A simple list of document providers can also be given. See `Absinthe.Plug.DocumentProvider` for more information about document providers, their role in processing requests, and how you can define and configure your own.
  - `:schema` -- (Required, if not handled by Mix.Config) The Absinthe schema to use. If a module name is not provided, `Application.get_env(:absinthe, :schema)` will be attempt to find one.
  - `:serializer` -- (Optional) Similar to `:json_codec` but allows the use of serialization formats other than JSON, like MessagePack or Erlang Term Format. Defaults to whatever is set in `:json_codec`.
  - `:content_type` -- (Optional) The content type of the response. Should probably be set if `:serializer` option is used. Defaults to `"application/json"`.
  - `:before_send` -- (Optional) Set a value(s) on the connection after resolution but before values are sent to the client.
  - `:log_level` -- (Optional) Set the logger level for Absinthe Logger. Defaults to `:debug`.
  - `:pubsub` -- (Optional) Pub Sub module for Subscriptions.
  - `:analyze_complexity` -- (Optional) Set whether to calculate the complexity of incoming GraphQL queries.
  - `:max_complexity` -- (Optional) Set the maximum allowed complexity of the GraphQL query. If a document’s calculated complexity exceeds the maximum, resolution will be skipped and an error will be returned in the result detailing the calculated and maximum complexities.
  - `:token_limit` -- (Optional) Set a limit on the number of allowed parseable tokens in the GraphQL query. Queries with exceedingly high token counts can be expensive to parse. If a query's token count exceeds the set limit, an error will be returned during Absinthe parsing (default: `:infinity`).
  - `:transport_batch_payload_key` -- (Optional) Set whether or not to nest Transport Batch request results in a `payload` key. Older clients expected this key to be present, but newer clients have dropped this pattern. (default: `true`)
  - `:standard_sse` -- (Optional) Set whether or not to adopt SSE standard. Older clients don't support this key. (default: `false`)

  """
  @type opts :: [
          schema: module,
          adapter: module,
          context: map,
          json_codec: module | {module, Keyword.t()},
          pipeline: {module, atom},
          no_query_message: String.t(),
          document_providers:
            [Absinthe.Plug.DocumentProvider.t(), ...]
            | Absinthe.Plug.DocumentProvider.t()
            | {module, atom},
          analyze_complexity: boolean,
          max_complexity: non_neg_integer | :infinity,
          token_limit: non_neg_integer | :infinity,
          serializer: module | {module, Keyword.t()},
          content_type: String.t(),
          before_send: {module, atom},
          log_level: Logger.level(),
          pubsub: module | nil,
          transport_batch_payload_key: boolean,
          standard_sse: boolean
        ]

  @doc """
  Serve an Absinthe GraphQL schema with the specified options.

  ## Options

  See the documentation for the `Absinthe.Plug.opts` type for details on the available options.
  """
  @spec init(opts :: opts) :: Plug.opts()
  def init(opts) do
    adapter = Keyword.get(opts, :adapter, Absinthe.Adapter.LanguageConventions)
    context = Keyword.get(opts, :context, %{})

    no_query_message = Keyword.get(opts, :no_query_message, "No query document supplied")

    pipeline = Keyword.get(opts, :pipeline, {__MODULE__, :default_pipeline})

    document_providers =
      Keyword.get(opts, :document_providers, {__MODULE__, :default_document_providers})

    json_codec =
      case Keyword.get(opts, :json_codec, Jason) do
        module when is_atom(module) -> %{module: module, opts: []}
        other -> other
      end

    serializer =
      case Keyword.get(opts, :serializer, json_codec) do
        module when is_atom(module) -> %{module: module, opts: []}
        {mod, opts} -> %{module: mod, opts: opts}
        other -> other
      end

    content_type = Keyword.get(opts, :content_type, "application/json")

    schema_mod = opts |> get_schema

    raw_options = Keyword.take(opts, @raw_options)
    log_level = Keyword.get(opts, :log_level, :debug)

    pubsub = Keyword.get(opts, :pubsub, nil)

    before_send = Keyword.get(opts, :before_send)

    transport_batch_payload_key = Keyword.get(opts, :transport_batch_payload_key, true)
    standard_sse = Keyword.get(opts, :standard_sse, false)

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
      before_send: before_send,
      transport_batch_payload_key: transport_batch_payload_key,
      standard_sse: standard_sse
    }
  end

  defp get_schema(opts) do
    default = Application.get_env(:absinthe, :schema)
    schema = Keyword.get(opts, :schema, default)

    valid_schema_module?(schema) ||
      raise ArgumentError, "#{inspect(schema)} is not a valid `Absinthe.Schema`"

    schema
  end

  defp valid_schema_module?(module) do
    with true <- is_atom(module),
         {:module, _} <- Code.ensure_compiled(module),
         true <- Absinthe.Schema in Keyword.get(module.__info__(:attributes), :behaviour, []) do
      true
    else
      _ -> false
    end
  end

  @doc false
  def apply_before_send(conn, bps, %{before_send: {mod, fun}}) do
    Enum.reduce(bps, conn, fn bp, conn ->
      apply(mod, fun, [conn, bp])
    end)
  end

  def apply_before_send(conn, _, _) do
    conn
  end

  @doc """
  Parses, validates, resolves, and executes the given Graphql Document
  """
  @spec call(Plug.Conn.t(), map) :: Plug.Conn.t() | no_return
  def call(conn, config) do
    config = update_config(conn, config)
    {conn, result} = conn |> execute(config)

    case result do
      {:input_error, msg} ->
        conn
        |> encode(400, error_result(msg), config)

      {:ok, %{"subscribed" => topic}} ->
        conn
        |> subscribe(topic, config)

      {:ok, %{data: _} = result} ->
        conn
        |> encode(200, result, config)

      {:ok, %{errors: _} = result} ->
        conn
        |> encode(200, result, config)

      {:ok, result} when is_list(result) ->
        conn
        |> encode(200, result, config)

      {:error, {:http_method, text}, _} ->
        conn
        |> encode(405, error_result(text), config)

      {:error, error, _} when is_binary(error) ->
        conn
        |> encode(500, error_result(error), config)
    end
  end

  @doc false
  def update_config(conn, config) do
    config
    |> update_config(:raw_options, conn)
    |> update_config(:init_options, conn)
    |> update_config(:pubsub, conn)
    |> update_config(:context, conn)
  end

  defp update_config(config, :pubsub, conn) do
    pubsub = config[:pubsub] || config.context[:pubsub] || conn.private[:phoenix_endpoint]

    if pubsub do
      put_in(config, [:context, :pubsub], pubsub)
    else
      config
    end
  end

  defp update_config(config, :raw_options, %{private: %{absinthe: absinthe}}) do
    raw_options = Map.take(absinthe, @raw_options) |> Map.to_list()
    update_in(config.raw_options, &Keyword.merge(&1, raw_options))
  end

  defp update_config(config, :init_options, %{private: %{absinthe: absinthe}}) do
    Map.merge(config, Map.take(absinthe, @init_options -- [:context | @raw_options]))
  end

  defp update_config(config, :context, %{private: %{absinthe: %{context: context}}}) do
    update_in(config.context, &Map.merge(&1, context))
  end

  defp update_config(config, _, _conn) do
    config
  end

  def subscribe(conn, topic, %{context: %{pubsub: pubsub}} = config) do
    pubsub.subscribe(topic)

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> send_chunked(200)
    |> subscribe_loop(topic, config)
  end

  defp subscribe_loop(conn, topic, config) do
    receive do
      %{event: "subscription:data", payload: %{result: result}} ->
        case chunk(conn, encode_chunk!(result, config)) do
          {:ok, conn} ->
            subscribe_loop(conn, topic, config)

          {:error, _} ->
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

          {:error, _} ->
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
  @spec put_options(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def put_options(%Plug.Conn{private: %{absinthe: absinthe}} = conn, opts) do
    opts = Map.merge(absinthe, Enum.into(opts, %{}))
    Plug.Conn.put_private(conn, :absinthe, opts)
  end

  def put_options(conn, opts) do
    Plug.Conn.put_private(conn, :absinthe, Enum.into(opts, %{}))
  end

  @doc """
  Adds key-value pairs into Absinthe context.

  ## Examples

      iex> Absinthe.Plug.assign_context(conn, current_user: user)
      %Plug.Conn{}
  """
  @spec assign_context(Plug.Conn.t(), Keyword.t() | map) :: Plug.Conn.t()
  def assign_context(%Plug.Conn{private: %{absinthe: absinthe}} = conn, assigns) do
    context =
      absinthe
      |> Map.get(:context, %{})
      |> Map.merge(Map.new(assigns))

    put_options(conn, context: context)
  end

  def assign_context(conn, assigns) do
    put_options(conn, context: Map.new(assigns))
  end

  @doc """
  Same as `assign_context/2` except one key-value pair is assigned.
  """
  @spec assign_context(Plug.Conn.t(), atom, any) :: Plug.Conn.t()
  def assign_context(conn, key, value) do
    assign_context(conn, [{key, value}])
  end

  @doc false
  @spec execute(Plug.Conn.t(), map) :: {Plug.Conn.t(), any}
  def execute(conn, config) do
    conn_info = %{
      conn_private: (conn.private[:absinthe] || %{}) |> Map.put(:http_method, conn.method)
    }

    with {:ok, conn, request} <- Request.parse(conn, config),
         {:ok, request} <- ensure_processable(request, config) do
      run_request(request, conn, conn_info, config)
    else
      result ->
        {conn, result}
    end
  end

  @doc false
  @spec ensure_processable(Request.t(), map) :: {:ok, Request.t()} | {:input_error, String.t()}
  def ensure_processable(request, config) do
    with {:ok, request} <- ensure_documents(request, config) do
      ensure_document_provider(request)
    end
  end

  @spec ensure_documents(Request.t(), map) :: {:ok, Request.t()} | {:input_error, String.t()}
  defp ensure_documents(%{queries: []}, config) do
    {:input_error, config.no_query_message}
  end

  defp ensure_documents(%{queries: queries} = request, config) do
    Enum.reduce_while(queries, {:ok, request}, fn query, _acc ->
      query_status =
        case query do
          {:input_error, error_msg} -> {:input_error, error_msg}
          query -> ensure_document(query, config)
        end

      case query_status do
        {:ok, _query} -> {:cont, {:ok, request}}
        {:input_error, error_msg} -> {:halt, {:input_error, error_msg}}
      end
    end)
  end

  @spec ensure_document(Request.Query.t(), map) ::
          {:ok, Request.Query.t()} | {:input_error, String.t()}
  defp ensure_document(%{document: nil}, config) do
    {:input_error, config.no_query_message}
  end

  defp ensure_document(%{document: _} = query, _) do
    {:ok, query}
  end

  @spec ensure_document_provider(Request.t()) :: {:ok, Request.t()} | {:input_error, String.t()}
  defp ensure_document_provider(%{queries: queries} = request) do
    if Enum.all?(queries, &Map.has_key?(&1, :document_provider)) do
      {:ok, request}
    else
      {:input_error, "No document provider found to handle this request"}
    end
  end

  @doc false
  def run_request(%{batch: true, queries: queries} = request, conn, conn_info, config) do
    Request.log(request, config.log_level)
    {conn, results} = Absinthe.Plug.Batch.Runner.run(queries, conn, conn_info, config)

    results =
      results
      |> Enum.zip(request.extra_keys)
      |> Enum.map(fn {result, extra_keys} ->
        result =
          if config.transport_batch_payload_key,
            do: %{payload: result},
            else: result

        Map.merge(extra_keys, result)
      end)

    {conn, {:ok, results}}
  end

  def run_request(%{batch: false, queries: [query]} = request, conn, conn_info, config) do
    Request.log(request, config.log_level)
    run_query(query, conn, conn_info, config)
  end

  defp run_query(query, conn, conn_info, config) do
    %{document: document, pipeline: pipeline} =
      Request.Query.add_pipeline(query, conn_info, config)

    case Absinthe.Pipeline.run(document, pipeline) do
      {:ok, %{result: result} = bp, _} ->
        conn = apply_before_send(conn, [bp], config)
        {conn, {:ok, result}}

      val ->
        {conn, val}
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
  @spec default_pipeline(map, Keyword.t()) :: Absinthe.Pipeline.t()
  def default_pipeline(config, pipeline_opts) do
    config.schema_mod
    |> Absinthe.Pipeline.for_document(pipeline_opts)
    |> Absinthe.Pipeline.insert_after(
      Absinthe.Phase.Document.CurrentOperation,
      [
        {Absinthe.Plug.Validation.HTTPMethod, method: config.conn_private.http_method}
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
  @spec default_document_providers(map) :: [Absinthe.Plug.DocumentProvider.t()]
  def default_document_providers(_) do
    [Absinthe.Plug.DocumentProvider.Default]
  end

  #
  # SERIALIZATION
  #

  @doc false
  @spec encode(Plug.Conn.t(), 200 | 400 | 405 | 500, map | list, map) :: Plug.Conn.t() | no_return
  def encode(conn, status, body, %{
        serializer: %{module: mod, opts: opts},
        content_type: content_type
      }) do
    conn
    |> put_resp_content_type(content_type)
    |> send_resp(status, mod.encode!(body, opts))
  end

  @doc false
  def encode_json!(value, %{json_codec: json_codec}) do
    json_codec.module.encode!(value, json_codec.opts)
  end

  @doc false
  def error_result(message), do: %{"errors" => [%{"message" => message}]}

  # `encode_chunk!/2`
  #
  # When option `standard_sse` is set to TRUE, it will addopt the new standard.
  # Otherwise, it will use legacy behaviour. This config is for keepoing
  # backwards compatibility, but everyone is encouraged to adopt the standard.
  #
  #
  # The encoded response additionally contains an event segment `event: next` and
  # the data is prefixed with a `data:` field, indicating data segment.
  #
  # This structure is consistent with GraphQL over S[erver-Sent Events Protocol][1]
  # specification and [official SSE standard][2].
  #
  # [1]: https://github.com/enisdenjo/graphql-sse/blob/master/PROTOCOL.md#next-event
  # [2]: https://html.spec.whatwg.org/multipage/server-sent-events.html

  defp encode_chunk!(result, config) do
    if config.standard_sse,
      do: "event: next\ndata: #{encode_json!(result, config)}\n\n",
      else: "#{encode_json!(result, config)}\n\n"
  end
end
