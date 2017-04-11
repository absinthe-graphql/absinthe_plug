defmodule Absinthe.Plug.Request do
  @moduledoc """
  This struct is the default return type of Request.parse.
  It contains parsed Request structs -- typically just one,
  but when `batched` is set to true, it can be multiple.
  
  extra_keys: e.g. %{"id": ...} sent by react-relay-network-layer,
              which need to be merged back into the list of final results
              before sending it to the client
  """

  import Plug.Conn
  alias Absinthe.Plug.Request.Query

  @enforce_keys [
    :adapter,
    :context,
    :schema,
  ]

  defstruct [
    :adapter,
    :context,
    :schema,
    queries: [],
    batched: false,
    extra_keys: [],
  ]

  @type t :: %__MODULE__{
    queries: list(Absinthe.Plug.Request.Query.t),
    batched: boolean(),
    extra_keys: list(map()),
    adapter: Absinthe.Adapter.t,
    context: map,
    schema: Absinthe.Schema.t,
  }

  @spec parse(Plug.Conn.t, map) :: {:ok, t} | {:input_error, String.t}
  def parse(conn, config) do
    request_params = %{
      conn: conn,
      root_value: extract_root_value(conn),
    }

    with {conn, {body, params}} <- extract_body_and_params(conn) do
      # Phoenix puts parsed params under the "_json" key when the
      # structure is an array; otherwise it's just the keys themselves,
      # and they may sit in the body or in the params
      is_batched = Map.has_key?(params, "_json")
      make_request({body, params}, request_params, conn, config, is_batched)
    end
  end

  @spec make_request({String.t, map}, map, map, map, boolean) :: %__MODULE__{}
  def make_request({_body, params}, request_params, conn, config, _is_batched = true) do
    queries = Enum.map(params["_json"], fn query ->
      Query.parse({"", query}, request_params, conn, config)
    end)

    extra_keys = Enum.map(params["_json"], fn query ->
      Map.drop(query, ["query", "variables"])
    end)

    request = %__MODULE__{
      queries: queries,
      batched: true,
      extra_keys: extra_keys,
      context: extract_context(conn, config),
      schema: config.schema_mod,
      adapter: config.adapter,
    }
    {:ok, request}
  end
  def make_request({body, params}, request_params, conn, config, _is_batched = false) do
    queries =
      {body, params}
      |> Query.parse(request_params, conn, config)
      |> List.wrap

    request = %__MODULE__{
      queries: queries,
      batched: false,
      context: extract_context(conn, config),
      schema: config.schema_mod,
      adapter: config.adapter,
    }

    {:ok, request}
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
  # CONTEXT
  #

  @spec extract_context(Plug.Conn.t, map) :: map
  defp extract_context(conn, config) do
    config.context
    |> Map.merge(conn.private[:absinthe][:context] || %{})
    |> Map.merge(uploaded_files(conn))
  end

  #
  # UPLOADED FILES
  #

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

  @spec log(t) :: :ok
  def log(request, level \\ :debug) do
    Enum.each(request.queries, &Query.log(&1, request, level))
    :ok
  end
end
