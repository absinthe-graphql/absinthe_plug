defmodule Absinthe.Plug.Request.Query do
  @moduledoc false

  # A struct containing, among a bunch of config params,
  # the raw GraphQL document and variables that make up the meat
  # of a GraphQL request. A GraphQL request can contain multiple Queries.
  # Queries are fed through a DocumentProvider, and then passed into
  # the pipeline(s) for processing.

  @enforce_keys [
    :document,
    :operation_name,
    :root_value,
    :variables,
    :raw_options,
    :params,
  ]

  defstruct [
    :document,
    :operation_name,
    :root_value,
    :variables,
    :raw_options,
    :params,
    :adapter,
    :context,
    :schema,
    document: nil,
    document_provider_key: nil,
    pipeline: [],
    document_provider: nil,
  ]

  @type t :: %__MODULE__{
    operation_name: nil | String.t,
    root_value: any,
    variables: map,
    raw_options: Keyword.t,
    document: nil | String.t | Absinthe.Blueprint.t,
    document_provider_key: any,
    pipeline: Absinthe.Pipeline.t,
    document_provider: nil | Absinthe.Plug.DocumentProvider.t,
    params: map,
    adapter: Absinthe.Adapter.t,
    context: map,
    schema: Absinthe.Schema.t,
  }

  def parse(body, params, config) do
    with raw_document <- extract_raw_document(body, params), # either from
     {:ok, variables} <- extract_variables(params, config),
       operation_name <- extract_operation_name(params) do

      %__MODULE__{
        document: raw_document,
        operation_name: operation_name,
        raw_options: config.raw_options,
        variables: variables,
        context: config.context,
        adapter: config.adapter,
        root_value: config.root_value,
        schema: config.schema_mod,
        params: params,
      }
      |> provide_document(config)
    end
  end

  def add_pipeline(query, conn_info, config) do
    config = Map.merge(config, conn_info)
    opts = query |> to_pipeline_opts

    {module, fun} = config.pipeline
    pipeline = apply(module, fun, [config, opts])

    pipeline =
      %{query | pipeline: pipeline}
      |> Absinthe.Plug.DocumentProvider.pipeline

    %{query | pipeline: pipeline}
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
  # DOCUMENT PROVIDERS
  #

  @spec calculate_document_providers(map) :: [Absinthe.Plug.DocumentProvider.t, ...]
  defp calculate_document_providers(%{document_providers: {module, fun}} = config) when is_atom(fun) do
    apply(module, fun, [config])
  end
  defp calculate_document_providers(%{document_providers: simple_value}) do
    List.wrap(simple_value)
  end

  @spec ensure_document_providers!(providers) :: providers when providers: [Absinthe.Plug.DocumentProvider.t, ...]
  defp ensure_document_providers!([]) do
    raise "No document providers found to process request"
  end
  defp ensure_document_providers!(provided) do
    provided
  end

  @spec provide_document(t, map) :: t
  defp provide_document(query, config) do
    calculate_document_providers(config)
    |> ensure_document_providers!()
    |> Absinthe.Plug.DocumentProvider.process(query)
  end

  @spec to_pipeline_opts(t) :: Keyword.t
  def to_pipeline_opts(query) do
    {with_raw_options, opts} =
      query
      |> Map.from_struct
      |> Map.to_list
      |> Keyword.split([:raw_options])
    Keyword.merge(opts, with_raw_options[:raw_options])
  end

  #
  # LOGGING
  #

  @doc false
  @spec log(t, Logger.level) :: :ok
  def log(query, level) do
    Absinthe.Logger.log_run(level, {
      query.document,
      query.schema,
      query.pipeline,
      to_pipeline_opts(query),
    })
  end
end
