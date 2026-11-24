defmodule Absinthe.Plug.ContentNegotiation do
  @moduledoc false

  # Accept-header content negotiation for the GraphQL over HTTP specification.
  #
  # https://http-spec.graphql.org/
  #
  # This mirrors the behaviour of the reference implementation's audit suite
  # (graphql-http, src/handler.ts): entries are evaluated in the order they are
  # listed and the first match wins. The `q` weight parameter is intentionally
  # not honoured (the reference implementation ignores it as well), so clients
  # that want `application/graphql-response+json` must list it ahead of
  # `application/json`.
  #
  # A missing or empty Accept header is treated as `*/*`, which resolves to the
  # legacy `application/json` media type to maximise compatibility with existing
  # clients.

  @graphql_response_json "application/graphql-response+json"
  @json "application/json"

  @type media_type :: :graphql_response_json | :json
  @type result :: {:ok, media_type} | :not_acceptable

  @doc """
  Determine the response media type for a request's `Accept` header value(s).

  Accepts the list returned by `Plug.Conn.get_req_header(conn, "accept")`, a raw
  header string, or `nil`. Returns `{:ok, :graphql_response_json}`,
  `{:ok, :json}`, or `:not_acceptable`.
  """
  @spec negotiate([String.t()] | String.t() | nil) :: result
  def negotiate(nil), do: negotiate("*/*")
  def negotiate([]), do: negotiate("*/*")
  def negotiate(accept) when is_list(accept), do: negotiate(Enum.join(accept, ","))
  def negotiate(""), do: negotiate("*/*")

  def negotiate(accept) when is_binary(accept) do
    accept
    |> String.replace(~r/\s/, "")
    |> String.downcase()
    |> String.split(",")
    |> Enum.find_value(:not_acceptable, &match_media_type/1)
  end

  @spec match_media_type(String.t()) :: {:ok, media_type} | nil
  defp match_media_type(entry) do
    [media_type | params] = String.split(entry, ";")
    charset = Enum.find(params, "charset=utf-8", &String.starts_with?(&1, "charset="))

    cond do
      media_type == @graphql_response_json and charset == "charset=utf-8" ->
        {:ok, :graphql_response_json}

      media_type in [@json, "application/*", "*/*"] and
          charset in ["charset=utf-8", "charset=utf8"] ->
        {:ok, :json}

      true ->
        nil
    end
  end
end
