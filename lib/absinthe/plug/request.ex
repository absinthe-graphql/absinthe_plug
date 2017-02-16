defmodule Absinthe.Plug.Request do
  @moduledoc false

  import Plug.Conn

  @enforce_keys [
    :adapter,
    :context,
    :document,
    :operation_name,
    :params,
    :root_value,
    :variables,
  ]

  defstruct [
    :adapter,
    :context,
    :document,
    :operation_name,
    :params,
    :root_value,
    :variables,
    pipeline: [],
    document: nil,
    document_provider: nil,
    document_provider_key: nil,
  ]


  @type t :: %__MODULE__{
    adapter: Absinthe.Adapter.t,
    context: map,
    document: nil | String.t | Absinthe.Blueprint.t,
    params: map,
    operation_name: nil | String.t,
    root_value: any,
    variables: map,
    document_provider: nil | Absinthe.Plug.DocumentProvider.t,
    document_provider_key: any,
    pipeline: Absinthe.Pipeline.t,
  }

  @spec parse(Plug.Conn.t, map) :: {:ok, t} | {:input_error, String.t}
  def parse(conn, config) do
    with {conn, {body, params}} <- extract_body_and_params(conn),
               {:ok, variables} <- extract_variables(params, config),
                        adapter <- config.adapter,
                   raw_document <- extract_raw_document(body, params),
                 operation_name <- extract_operation_name(params),
                        context <- extract_context(conn, config),
                     root_value <- extract_root_value(conn) do
      %__MODULE__{
        adapter: adapter,
        document: raw_document,
        params: params,
        variables: variables,
        operation_name: operation_name,
        context: context,
        root_value: root_value
      }
      |> add_pipeline(conn, config)
      |> provide_document(config)
    end
  end


  #
  # BODY / PARAMS
  #

  @spec extract_body_and_params(Plug.Conn.t) :: {Plug.Conn.t, {String.t, map}}
  defp extract_body_and_params(%{body_params: %{"query" => _}} = conn) do
    conn = fetch_query_params(conn)
    {conn, {"", conn.params}}
  end
  defp extract_body_and_params(conn) do
    {:ok, body, conn} = read_body(conn)
    conn = fetch_query_params(conn)
    {conn, {body, conn.params}}
  end

  #
  # OPERATION NAME
  #

  @spec extract_operation_name(map) :: nil | String.t
  defp extract_operation_name(params) do
    params["operationName"]
    |> decode_operation_name
  end

  # GraphQL.js treats an empty operation name as no operation name.
  @spec decode_operation_name(nil | String.t) :: nil | String.t
  defp decode_operation_name(""), do: nil
  defp decode_operation_name(name), do: name

  #
  # VARIABLES
  #

  @spec extract_variables(map, map) :: {:ok, map} | {:input_error, String.t}
  defp extract_variables(params, %{json_codec: json_codec}) do
    Map.get(params, "variables", "{}")
    |> decode_variables(json_codec)
  end
  defp extract_variables(_, _) do
    {:error, "No json_codec available"}
  end

  @spec decode_variables(any, map) :: {:ok, map} | {:input_error, String.t}
  defp decode_variables(%{} = variables, _), do: {:ok, variables}
  defp decode_variables("", _), do: {:ok, %{}}
  defp decode_variables("null", _), do: {:ok, %{}}
  defp decode_variables(nil, _), do: {:ok, %{}}
  defp decode_variables(variables, codec) do
    case codec.module.decode(variables) do
      {:ok, results} ->
        {:ok, results}
      _ ->
        {:input_error, "The variable values could not be decoded"}
    end
  end

  #
  # DOCUMENT
  #

  @spec extract_raw_document(nil | String.t, map) :: nil | String.t
  defp extract_raw_document(body, params) do
    Map.get(params, "query", body)
    |> normalize_raw_document
  end

  @spec normalize_raw_document(nil | String.t) :: nil | String.t
  defp normalize_raw_document(""), do: nil
  defp normalize_raw_document(doc), do: doc

  #
  # CONTEXT
  #

  @spec extract_context(Plug.Conn.t, map) :: map
  defp extract_context(conn, config) do
    config.context
    |> Map.merge(conn.private[:absinthe][:context] || %{})
    |> Map.merge(uploaded_files(conn))
  end

  @spec uploaded_files(Plug.Conn.t) :: map
  defp uploaded_files(conn) do
    files =
      conn.params
      |> Enum.filter(&match?({_, %Plug.Upload{}}, &1))
      |> Map.new

    %{
      __absinthe_plug__: %{
        uploads: files
      }
    }
  end

  #
  # ROOT VALUE
  #

  @spec extract_root_value(Plug.Conn.t) :: any
  defp extract_root_value(conn) do
    conn.private[:absinthe][:root_value] || %{}
  end

  #
  # DOCUMENT PROVIDERS
  #

  @spec calculate_document_providers(map) :: [Absinthe.Plug.DocumentProvider.t]
  defp calculate_document_providers(%{document_providers: {module, fun}} = config) do
    apply(module, fun, [config])
  end
  defp calculate_document_providers(%{document_providers: simple_value}) do
    List.wrap(simple_value)
  end

  @spec ensure_document_providers!([Absinthe.Plug.DocumentProvider.t]) :: [Absinthe.Plug.DocumentProvider.t] | no_return
  defp ensure_document_providers!([]) do
    raise "No document providers found to process request"
  end
  defp ensure_document_providers!(provided) do
    provided
  end

  @spec provide_document(t, map) :: {:ok, t} | {:input_error, String.t}
  defp provide_document(request, config) do
    calculate_document_providers(config)
    |> ensure_document_providers!()
    |> Absinthe.Plug.DocumentProvider.process(request)
  end

  #
  # PIPELINE
  #

  @spec add_pipeline(t, Plug.Conn.t, map) :: t
  defp add_pipeline(request, conn, config) do
    private = conn.private[:absinthe] || %{}
    private = Map.put(private, :http_method, conn.method)
    config = Map.put(config, :conn_private, private)

    simplified_input = request |> Map.from_struct |> Keyword.new

    {module, fun} = config.pipeline
    pipeline = apply(module, fun, [config, simplified_input])
    %{request | pipeline: pipeline}
  end

end