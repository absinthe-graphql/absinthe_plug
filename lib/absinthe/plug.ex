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
        schema: MyApp.Schema

  If you want only `Absinthe.Plug` to serve a particular route, configure your
  router like:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Poison

      forward "/api", Absinthe.Plug,
        schema: MyApp.Schema

  See the documentation on `Absinthe.Plug.init/1` and the `Absinthe.Plug.opts`
  type for information on the available options.

  To add support for a GraphiQL interface, add a configuration for
  `Absinthe.Plug.GraphiQL`:

      forward "/graphiql",
        Absinthe.Plug.GraphiQL,
        schema: MyApp.Schema,

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

  @typedoc """
  - `:adapter` -- (Optional) Absinthe adapter to use (default: `Absinthe.Adapter.LanguageConventions`).
  - `:context` -- (Optional) Initial value for the Absinthe context, available to resolvers. (default: `%{}`).
  - `:no_query_message` -- (Optional) Message to return to the client if no query is provided (default: "No query document supplied").
  - `:json_codec` -- (Optional) A `module` or `{module, Keyword.t}` dictating which JSON codec should be used (default: `Poison`).
  - `:pipeline` -- (Optional) `{module, atom}` reference to a 2-arity function that will be called to generate the processing pipeline. (default: `{Absinthe.Plug, :default_pipeline}`).
  - `:document_providers` -- (Optional) A `{module, atom}` reference to a 1-arity function that will be called to determine the document providers that will be used to process the request. (default: `{Absinthe.Plug, :default_document_providers}`, which configures `Absinthe.Plug.DocumentProvider.Default` as the lone document provider). A simple list of document providers can also be given. See `Absinthe.Plug.DocumentProvider` for more information about document providers, their role in procesing requests, and how you can define and configure your own.
  - `:schema` -- (Required, if not handled by Mix.Config) The Absinthe schema to use. If a module name is not provided, `Application.get_env(:absinthe, :schema)` will be attempt to find one.
  """
  @type opts :: [
    schema: module,
    adapter: module,
    context: map,
    json_codec: module | {module, Keyword.t},
    pipeline: {module, atom},
    no_query_message: String.t,
    document_providers: [Absinthe.Plug.DocumentProvider.t]
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

    schema_mod = opts |> get_schema

    %{
      adapter: adapter,
      context: context,
      document_providers: document_providers,
      json_codec: json_codec,
      no_query_message: no_query_message,
      pipeline: pipeline,
      schema_mod: schema_mod,
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
  def call(conn, %{json_codec: json_codec} = config) do
    {conn, result} = conn |> execute(config)

    case result do
      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:ok, %{data: _} = result} ->
        conn
        |> json(200, result, json_codec)

      {:ok, %{errors: _} = result} ->
        conn
        |> json(400, result, json_codec)

      {:error, {:http_method, text}, _} ->
        conn
        |> send_resp(405, text)

      {:error, error, _} when is_binary(error) ->
        conn
        |> send_resp(500, error)

    end
  end

  @doc false
  @spec execute(Plug.Conn.t, map) :: {Plug.Conn.t, any}
  def execute(conn, config) do
    with {:ok, request} <- Absinthe.Plug.Request.parse(conn, config),
         {:ok, request} <- ensure_document(request, config) do
      run_request(request, conn)
    else
      result ->
        {conn, result}
    end
  end

  @spec ensure_document(Absinthe.Plug.Request.t, map) :: {:ok, Absinthe.Plug.Request.t} | {:input_error, String.t}
  defp ensure_document(%{document: nil}, config) do
    {:input_error, config.no_query_message}
  end
  defp ensure_document(request, _) do
    {:ok, request}
  end

  @spec run_request(Absinthe.Plug.Request.t, Plug.Conn.t) :: {Plug.Conn.t, any}
  defp run_request(request, conn) do
    case Absinthe.Pipeline.run(request.document, Absinthe.Plug.DocumentProvider.pipeline(request)) do
      {:ok, result, _} ->
        {conn, {:ok, result}}
      other ->
        {conn, other}
    end
  end

  #
  # PIPELINE
  #

  @doc false
  @spec default_pipeline(map, Keyword.t) :: Absinthe.Pipeline.t
  def default_pipeline(config, input_for_pipeline) do
    config.schema_mod
    |> Absinthe.Pipeline.for_document(input_for_pipeline)
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Document.CurrentOperation,
      {Absinthe.Plug.Validation.HTTPMethod, method: config.conn_private.http_method}
    )
  end

  #
  # DOCUMENT PROVIDERS
  #

  @doc false
  @spec default_document_providers(map) :: [Absinthe.Plug.DocumentProvider.t]
  def default_document_providers(_) do
    [Absinthe.Plug.DocumentProvider.Default]
  end

  #
  # SERIALIZATION
  #

  @doc false
  @spec json(Plug.Conn.t, 200 | 400 | 405 | 500, String.t, map) :: Plug.Conn.t | no_return
  def json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end

end
