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

  # Determine the response media type for a request's `Accept` header value(s).
  #
  # Accepts the list returned by `Plug.Conn.get_req_header(conn, "accept")`, a raw
  # header string, or `nil`. Returns `{:ok, :graphql_response_json}`,
  # `{:ok, :json}`, or `:not_acceptable`.
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

  # The bare media type string for a negotiated media type. The charset is
  # intentionally omitted; `Plug.Conn.put_resp_content_type/3` appends
  # `; charset=utf-8`.
  @spec media_type_string(media_type) :: String.t()
  def media_type_string(:graphql_response_json), do: @graphql_response_json
  def media_type_string(:json), do: @json

  # The value for the `accept` response header on a `406 Not Acceptable`
  # response, listing the media types this server can produce.
  @spec supported_media_types() :: String.t()
  def supported_media_types do
    "#{@graphql_response_json}; charset=utf-8, #{@json}; charset=utf-8"
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
