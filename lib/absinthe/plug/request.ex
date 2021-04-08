defmodule Absinthe.Plug.Request do
  @moduledoc false

  # This struct is the default return type of Request.parse.
  # It contains parsed Request structs -- typically just one,
  # but when `batched` is set to true, it can be multiple.
  #
  # extra_keys: e.g. %{"id": ...} sent by react-relay-network-layer,
  #             which need to be merged back into the list of final results
  #             before sending it to the client

  import Plug.Conn
  alias Absinthe.Plug.Request.Query

  defstruct queries: [],
            batch: false,
            extra_keys: []

  @type t :: %__MODULE__{
          queries: list(Absinthe.Plug.Request.Query.t()),
          batch: boolean(),
          extra_keys: list(map())
        }

  @spec parse(Plug.Conn.t(), map) :: {:ok, Plug.Conn.t(), t} | {:input_error, String.t()}
  def parse(conn, config) do
    root_value =
      config
      |> Map.get(:root_value, %{})
      |> Map.merge(extract_root_value(conn))

    context =
      config
      |> Map.get(:context, %{})
      |> Map.merge(extract_context(conn, config))

    config = Map.merge(config, %{root_value: root_value, context: context})

    config =
      (conn.private[:absinthe] || %{})
      |> Enum.reduce(config, fn
        # keys we already handled
        {k, _}, config when k in [:context, :root_value] ->
          config

        {k, v}, config ->
          Map.put(config, k, v)
      end)

    with {:ok, conn, body, params} <- extract_body_and_params(conn, config),
         true <- valid_request?(params) do
      {:ok, conn, build_request(body, params, config, batch?: is_batch?(params))}
    end
  end

  # Plug puts parsed params under the "_json" key when the
  # structure is not a map; otherwise it's just the keys themselves,
  # and they may sit in the body or in the params

  defp is_batch?(params) do
    Map.has_key?(params, "_json") && is_list(params["_json"])
  end

  defp valid_request?(%{"_json" => json}) when is_list(json) do
    Enum.all?(json, &is_map(&1)) ||
      {:input_error, "Invalid request structure. Expecting a list of objects."}
  end

  defp valid_request?(%{"_json" => json}) when is_binary(json) do
    {:input_error, "Invalid request structure. Expecting an object or list of objects."}
  end

  defp valid_request?(_params), do: true

  defp build_request(_body, params, config, batch?: true) do
    queries =
      Enum.map(params["_json"], fn query ->
        Query.parse("", query, config)
      end)

    extra_keys =
      Enum.map(params["_json"], fn query ->
        Map.drop(query, ["query", "variables"])
      end)

    %__MODULE__{
      queries: queries,
      batch: true,
      extra_keys: extra_keys
    }
  end

  defp build_request(body, params, config, batch?: false) do
    queries =
      body
      |> Query.parse(params, config)
      |> List.wrap()

    %__MODULE__{
      queries: queries,
      batch: false
    }
  end

  #
  # BODY / PARAMS
  #

  @spec extract_body_and_params(Plug.Conn.t(), map()) :: {:ok, Plug.Conn.t(), String.t(), map()}
  defp extract_body_and_params(%{body_params: %{"query" => _}} = conn, _config) do
    conn = fetch_query_params(conn)
    {:ok, conn, "", conn.params}
  end

  defp extract_body_and_params(%{body_params: %{"_json" => _}} = conn, config) do
    extract_body_and_params_batched(conn, "", config)
  end

  defp extract_body_and_params(conn, config) do
    with {:ok, body, conn} <- read_body(conn) do
      extract_body_and_params_batched(conn, body, config)
    end
  end

  defp convert_operations_param(conn = %{params: %{"operations" => operations}})
       when is_binary(operations) do
    put_in(conn.params["_json"], conn.params["operations"])
    |> Map.delete("operations")
  end

  defp convert_operations_param(conn), do: conn

  defp extract_body_and_params_batched(conn, body, config) do
    conn =
      conn
      |> fetch_query_params()
      |> convert_operations_param()

    with %{"_json" => string} = params when is_binary(string) <- conn.params,
         {:ok, decoded} <- config.json_codec.module.decode(string) do
      {:ok, conn, body, %{params | "_json" => decoded}}
    else
      {:error, {:invalid, token, pos}} ->
        {:input_error, "Could not parse JSON. Invalid token `#{token}` at position #{pos}"}

      {:error, %{__exception__: true} = exception} ->
        {:input_error, "Could not parse JSON. #{Exception.message(exception)}"}

      %{} ->
        {:ok, conn, body, conn.params}
    end
  end

  #
  # CONTEXT
  #

  @spec extract_context(Plug.Conn.t(), map) :: map
  defp extract_context(conn, config) do
    config.context
    |> Map.merge(conn.private[:absinthe][:context] || %{})
    |> Map.merge(uploaded_files(conn))
  end

  #
  # UPLOADED FILES
  #

  @spec uploaded_files(Plug.Conn.t()) :: map
  defp uploaded_files(conn) do
    files =
      conn.params
      |> Enum.filter(&match?({_, %Plug.Upload{}}, &1))
      |> Map.new()

    %{
      __absinthe_plug__: %{
        uploads: files
      }
    }
  end

  #
  # ROOT VALUE
  #

  @spec extract_root_value(Plug.Conn.t()) :: any
  defp extract_root_value(conn) do
    conn.private[:absinthe][:root_value] || %{}
  end

  @spec log(t, atom) :: :ok
  def log(request, level) do
    Enum.each(request.queries, &Query.log(&1, level))
    :ok
  end
end
