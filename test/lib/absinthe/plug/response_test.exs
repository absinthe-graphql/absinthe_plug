defmodule Absinthe.Plug.ResponseTest do
  use ExUnit.Case, async: true

  alias Absinthe.Plug.Response

  describe "classify/2" do
    test "data without errors is :ok" do
      assert Response.classify(%{data: %{"foo" => "bar"}}) == :ok
    end

    test "null data without errors is :ok" do
      assert Response.classify(%{data: nil}) == :ok
    end

    test "data with errors is :partial" do
      assert Response.classify(%{data: %{"foo" => nil}, errors: [%{message: "boom"}]}) == :partial
    end

    test "null data with errors is :partial" do
      assert Response.classify(%{data: nil, errors: [%{message: "boom"}]}) == :partial
    end

    test "errors without data and a parse-phase error is :document_parse_error" do
      validation_errors = [%{phase: Absinthe.Phase.Parse, message: "syntax error"}]

      assert Response.classify(%{errors: [%{message: "x"}]}, validation_errors) ==
               :document_parse_error
    end

    test "errors without data and non-parse errors is :validation_error" do
      validation_errors = [
        %{phase: Absinthe.Phase.Document.Validation.FieldsOnCorrectType, message: "x"}
      ]

      assert Response.classify(%{errors: [%{message: "x"}]}, validation_errors) ==
               :validation_error
    end

    test "errors without data and no validation errors defaults to :validation_error" do
      assert Response.classify(%{errors: [%{message: "x"}]}) == :validation_error
    end

    test "a parse error anywhere in the list wins" do
      validation_errors = [
        %{phase: Absinthe.Phase.Document.Validation.Result},
        %{phase: Absinthe.Phase.Parse}
      ]

      assert Response.classify(%{errors: [%{message: "x"}]}, validation_errors) ==
               :document_parse_error
    end
  end

  describe "status/2" do
    test ":ok is always 200" do
      assert Response.status(:ok, :graphql_response_json) == 200
      assert Response.status(:ok, :json) == 200
    end

    test ":partial is 294 under graphql-response+json and 200 under json" do
      assert Response.status(:partial, :graphql_response_json) == 294
      assert Response.status(:partial, :json) == 200
    end

    test "request errors map to their spec status regardless of media type" do
      for media_type <- [:graphql_response_json, :json] do
        assert Response.status(:json_parse_error, media_type) == 400
        assert Response.status(:document_parse_error, media_type) == 400
        assert Response.status(:not_well_formed, media_type) == 422
        assert Response.status(:validation_error, media_type) == 422
        assert Response.status(:method_not_allowed, media_type) == 405
        assert Response.status(:unsupported_media_type, media_type) == 415
        assert Response.status(:not_acceptable, media_type) == 406
      end
    end
  end
end
