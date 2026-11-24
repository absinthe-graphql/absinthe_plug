defmodule Absinthe.Plug.Response do
  @moduledoc false

  # Response policy for the GraphQL over HTTP specification.
  #
  # https://http-spec.graphql.org/September2026/#sec-Status-Codes
  #
  # `classify/2` maps a GraphQL result (plus the blueprint's validation errors,
  # needed only to tell a document parse failure from a validation failure) to an
  # outcome atom. `status/2` maps an outcome and the negotiated response media
  # type to an HTTP status code.
  #
  # These functions describe spec-mode behaviour only; the legacy (non spec)
  # response path does not consult them.

  @type outcome ::
          :ok
          | :partial
          | :json_parse_error
          | :not_well_formed
          | :document_parse_error
          | :validation_error
          | :method_not_allowed
          | :unsupported_media_type
          | :not_acceptable

  @doc """
  Classify a GraphQL result map.

  The second argument is the blueprint's `execution.validation_errors` list (used
  only to distinguish a GraphQL document parse failure, which the spec maps to
  `400`, from a validation failure, which maps to `422`). It defaults to `[]`.

  Request-level failures that happen before execution (unparseable JSON bodies,
  malformed requests) are classified by the caller, not here.
  """
  @spec classify(map, list) :: outcome
  def classify(result, validation_errors \\ []) do
    case result do
      %{data: _, errors: _} ->
        :partial

      %{data: _} ->
        :ok

      %{errors: _} ->
        if Enum.any?(validation_errors, &match?(%{phase: Absinthe.Phase.Parse}, &1)) do
          :document_parse_error
        else
          :validation_error
        end
    end
  end

  @doc """
  Map an outcome and the negotiated response media type to an HTTP status code.

  Partial success (data present alongside errors) is the only outcome whose
  status depends on the media type: `294` under `application/graphql-response+json`
  and `200` under `application/json`, since `294`'s "treat as 200" guarantee only
  holds for clients that opted into the `graphql-response+json` media type.
  """
  @spec status(outcome, Absinthe.Plug.ContentNegotiation.media_type()) :: 200..599
  def status(outcome, media_type) do
    case {outcome, media_type} do
      {:ok, _} -> 200
      {:partial, :graphql_response_json} -> 294
      {:partial, :json} -> 200
      {:json_parse_error, _} -> 400
      {:document_parse_error, _} -> 400
      {:not_well_formed, _} -> 422
      {:validation_error, _} -> 422
      {:method_not_allowed, _} -> 405
      {:unsupported_media_type, _} -> 415
      {:not_acceptable, _} -> 406
    end
  end
end
