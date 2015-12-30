defmodule AbsinthePlug do
  @behaviour Plug
  import Plug.Conn

  def init(opts) do
    adapter = Keyword.get(opts, :adapter, Absinthe.Adapter.Passthrough)
    context = Keyword.get(opts, :context, %{})

    json_codec = case Keyword.get(opts, :json_codec, Poison) do
      module when is_atom(module) -> %{module: module, opts: []}
      other -> other
    end

    schema = opts
    |> Keyword.fetch!(:schema)
    |> Absinthe.Schema.verify
    |> case do
      {:ok, schema} -> schema
      {:error, errors} -> raise ArgumentError, errors |> Enum.join("\n")
    end

    %{schema: schema, adapter: adapter, context: context, json_codec: json_codec}
  end

  def call(conn, %{context: context} = config) do
    IO.puts "YOOOO"
    {input, variables, operation_name} = case get_req_header(conn, "content-type") do
      "application/json" ->
        # if it doesn't have query it should do an http error 400 "Must provide query string."
        # TODO: make variables and operationName optional
        %{"query" => input, "variables" => variables, "operationName" => operation_name} = conn.params
        {input, variables, operation_name}
      "application/x-www-form-urlencoded" ->
        %{"query" => input, "variables" => variables, "operationName" => operation_name} = conn.params
        {input, variables, operation_name}
      "application/graphql" ->
        input = conn.body
        %{"variables" => variables, "operationName" => operation_name} = conn.params
        {input, variables, operation_name}
    end

    context = Map.merge(context, conn.private.blah)
    opts = %{variables: variables, adapter: config.adapter, context: context, operation_name: operation_name}
    do_call(conn, input, config.schema, opts, config)
  end

  def do_call(conn, input, schema, opts, %{json_codec: json_codec}) do
    with {:ok, doc} <- Absinthe.parse(input),
      :ok <- validate_single_operation(doc),
      :ok <- validate_http_method(conn, doc),
      :ok <- Absinthe.validate(doc, schema),
      {:ok, result} <- Absinthe.execute(doc, schema, opts) do

      {:ok, result}
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

  defp json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end

  # This is a temporarily limitation
  defp validate_single_operation(%{definitions: [_]}), do: :ok
  defp validate_single_operation(_), do: {:http_error, "Can only accept one operation per query (temporary)"}

  defp validate_http_method(%{method: "GET"}, %{definitions: [%{operation: operation}]})
    when operation in ~w(mutation subscription)a do

    {:http_error, "Can only perform a #{operation} from a POST request"}
  end
  defp validate_http_method(_, _), do: :ok
end
