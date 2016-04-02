defmodule Absinthe.Plug do
  @moduledoc """
  A plug for using Absinthe

  See [The Guides](http://absinthe-graphql.org/guides/plug-phoenix/) for usage details
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
  def init(opts) do
    adapter = Keyword.get(opts, :adapter)
    context = Keyword.get(opts, :context, %{})

    json_codec = case Keyword.get(opts, :json_codec, Poison) do
      module when is_atom(module) -> %{module: module, opts: []}
      other -> other
    end

    schema_mod = opts |> get_schema

    %{adapter: adapter, schema_mod: schema_mod, context: context, json_codec: json_codec}
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
    conn
    |> execute(config)
    |> case do
      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:ok, result} ->
        conn
        |> json(200, result, json_codec)

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

  @doc false
  def execute(conn, config)do
    with {:ok, input, opts} <- prepare(conn, config),
    {:ok, doc} <- Absinthe.parse(input),
    :ok <- validate_http_method(conn, doc) do
      Absinthe.run(doc, config.schema_mod, opts)
    end
  end

  @doc false
  def prepare(conn, %{json_codec: json_codec} = config) do
    {body, conn} = load_body_and_params(conn)

    raw_input = Map.get(conn.params, "query", body)

    Logger.debug("""
    GraphQL Document:
    #{raw_input}
    """)

    input = case raw_input do
      nil -> {:input_error, "No query document supplied"}
      "" -> {:input_error, "No query document supplied"}
      doc -> {:ok, doc}
    end
    variables = Map.get(conn.params, "variables") || "{}"
    operation_name = conn.params["operationName"]

    with {:ok, input} <- input,
      {:ok, variables} <- decode_variables(variables, json_codec) do
        absinthe_opts = %{
          variables: variables,
          adapter: config.adapter,
          context: Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
          operation_name: operation_name}
        {:ok, input, absinthe_opts}
    end
  end

  defp decode_variables(%{} = variables, _), do: {:ok, variables}
  defp decode_variables("", _), do: {:ok, %{}}
  defp decode_variables("null", _), do: {:ok, %{}}
  defp decode_variables(nil, _), do: {:ok, %{}}
  defp decode_variables(variables, codec), do: codec.module.decode(variables)

  defp load_body_and_params(conn) do
    case get_req_header(conn, "content-type") do
      ["application/graphql"] ->
        {:ok, body, conn} = read_body(conn)
        {body, conn |> fetch_query_params}
      _ -> {"", conn}
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
