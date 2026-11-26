defmodule Absinthe.Plug.ContentNegotiationTest do
  use ExUnit.Case, async: true

  alias Absinthe.Plug.ContentNegotiation

  describe "negotiate/1 with a missing or wildcard Accept" do
    test "nil defaults to legacy application/json" do
      assert ContentNegotiation.negotiate(nil) == {:ok, :json}
    end

    test "empty list defaults to legacy application/json" do
      assert ContentNegotiation.negotiate([]) == {:ok, :json}
    end

    test "empty string defaults to legacy application/json" do
      assert ContentNegotiation.negotiate("") == {:ok, :json}
    end

    test "*/* resolves to legacy application/json" do
      assert ContentNegotiation.negotiate("*/*") == {:ok, :json}
    end

    test "application/* resolves to legacy application/json" do
      assert ContentNegotiation.negotiate("application/*") == {:ok, :json}
    end
  end

  describe "negotiate/1 with application/graphql-response+json" do
    test "resolves to graphql-response+json" do
      assert ContentNegotiation.negotiate("application/graphql-response+json") ==
               {:ok, :graphql_response_json}
    end

    test "allows an explicit utf-8 charset" do
      assert ContentNegotiation.negotiate("application/graphql-response+json; charset=utf-8") ==
               {:ok, :graphql_response_json}
    end

    test "does not match a non-utf-8 charset" do
      assert ContentNegotiation.negotiate("application/graphql-response+json; charset=latin-1") ==
               :not_acceptable
    end

    test "is case- and whitespace-insensitive" do
      assert ContentNegotiation.negotiate("  Application/GraphQL-Response+JSON  ") ==
               {:ok, :graphql_response_json}
    end
  end

  describe "negotiate/1 with application/json" do
    test "resolves to application/json" do
      assert ContentNegotiation.negotiate("application/json") == {:ok, :json}
    end

    test "allows utf8 and utf-8 charsets" do
      assert ContentNegotiation.negotiate("application/json; charset=utf8") == {:ok, :json}
      assert ContentNegotiation.negotiate("application/json; charset=utf-8") == {:ok, :json}
    end
  end

  describe "negotiate/1 ordering (first match wins, q ignored)" do
    test "graphql-response+json listed first wins" do
      assert ContentNegotiation.negotiate(
               "application/graphql-response+json, application/json;q=0.9"
             ) == {:ok, :graphql_response_json}
    end

    test "application/json listed first wins even if graphql-response+json follows" do
      assert ContentNegotiation.negotiate("application/json, application/graphql-response+json") ==
               {:ok, :json}
    end

    test "skips an unsupported type to reach a supported one" do
      assert ContentNegotiation.negotiate("text/html, application/graphql-response+json") ==
               {:ok, :graphql_response_json}
    end

    test "joins multiple Accept header values" do
      assert ContentNegotiation.negotiate(["text/html", "application/json"]) == {:ok, :json}
    end
  end

  describe "negotiate/1 with nothing acceptable" do
    test "returns :not_acceptable" do
      assert ContentNegotiation.negotiate("text/html") == :not_acceptable
      assert ContentNegotiation.negotiate("text/plain, image/png") == :not_acceptable
    end
  end
end
