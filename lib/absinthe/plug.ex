defmodule Absinthe.Plug do
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
    adapter = Keyword.get(opts, :adapter, Absinthe.Adapter.Passthrough)
    context = Keyword.get(opts, :context, %{})

    json_codec = case Keyword.get(opts, :json_codec, Poison) do
      module when is_atom(module) -> %{module: module, opts: []}
      other -> other
    end

    schema_mod = case Keyword.fetch!(opts, :schema) do
      schema_mod when is_atom(schema_mod) -> schema_mod
      _ -> raise ArgumentError, "The schema: should be the module holding your schema"
    end

    schema_mod
    |> Absinthe.Schema.verify
    |> case do
      {:ok, _} -> _
      {:error, errors} -> raise ArgumentError, errors |> Enum.join("\n")
    end

    %{schema_mod: schema_mod, adapter: adapter, context: context, json_codec: json_codec}
  end

  @doc """
  Parses, validates, resolves, and executes the given Graphql Document
  """
  def call(conn, %{json_codec: json_codec} = config) do
    {body, conn} = load_body_and_params(conn)

    input = Map.get(conn.params, "query", body || :input_error)
    variables = Map.get(conn.params, "variables") || "{}"
    operation_name = conn.params["operationName"]

    Logger.debug("""
    GraphQL Document:
    #{input}
    """)

    with input when is_binary(input) <- input,
      {:ok, variables} <- json_codec.module.decode(variables) do
        %{variables: variables,
          adapter: config.adapter,
          context: Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
          operation_name: operation_name}
    end
    |> case do
      %{} = opts ->
        do_call(conn, input, config.schema_mod, opts, config)
      :input_error ->
        conn
        |> send_resp(400, "Either the `query` parameter or the request body should contain a graphql document")
      {:error, _} ->
        conn
        |> send_resp(400, "The variables parameter must be valid JSON")
    end
  end

  def do_call(conn, input, schema_mod, opts, %{json_codec: json_codec}) do
    schema = Absinthe.Plug.Cache.get(schema_mod)

    with {:ok, doc} <- Absinthe.parse(input),
      :ok <- validate_http_method(conn, doc) do
        %Absinthe.Execution{schema: schema, document: doc}
        |> Absinthe.Execution.run(opts)
    end
    |> case do
      {:ok, result} ->
        conn
        |> json(200, result, json_codec)

      {:http_error, text} ->
        conn
        |> send_resp(405, text)

      {:error, %{message: message, locations: locations}} ->
        conn
        |> json(400, %{errors: [%{message: message, locations: locations}]}, json_codec)
    end
  end

  defp load_body_and_params(conn) do
    case get_req_header(conn, "content-type") do
      ["application/graphql"] ->
        {:ok, body, conn} = read_body(conn)
        {body, conn |> fetch_query_params}
      _ -> {"", conn}
    end
  end

  defp json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end

  defp validate_http_method(%{method: "GET"}, %{definitions: [%{operation: operation}]})
    when operation in ~w(mutation subscription)a do

    {:http_error, "Can only perform a #{operation} from a POST request"}
  end
  defp validate_http_method(_, _), do: :ok
end
