defmodule Absinthe.Plug.GraphqlOverHttpTest do
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema

  @graphql_response_json "application/graphql-response+json"
  @json "application/json"

  @valid_query "{ item(id: \"foo\") { name } }"
  # `nonexistent` is not a field on Item -> validation failure (not a parse failure).
  @validation_error_query "{ item(id: \"foo\") { nonexistent } }"
  # An unclosed selection set -> document parse failure.
  @parse_error_query "{"
  # The `user` field resolves to an error with no context user, yielding
  # `data: %{"user" => nil}` alongside an `errors` entry (partial success).
  @partial_query "{ user }"

  defp opts(extra \\ []) do
    Absinthe.Plug.init([schema: TestSchema, graphql_over_http: true] ++ extra)
  end

  defp post(query, accept) do
    conn(:post, "/", Jason.encode!(%{query: query}))
    |> put_req_header("content-type", @json)
    |> maybe_accept(accept)
    |> plug_parser()
    |> Absinthe.Plug.call(opts())
  end

  defp maybe_accept(conn, nil), do: conn
  defp maybe_accept(conn, accept), do: put_req_header(conn, "accept", accept)

  defp content_type(conn), do: conn |> get_resp_header("content-type") |> List.first()

  describe "Accept: application/graphql-response+json" do
    test "a successful query is 200 with the graphql-response+json content type" do
      conn = post(@valid_query, @graphql_response_json)
      assert conn.status == 200
      assert content_type(conn) == "#{@graphql_response_json}; charset=utf-8"
      assert Jason.decode!(conn.resp_body) == %{"data" => %{"item" => %{"name" => "Foo"}}}
    end

    test "a validation failure is 422" do
      conn = post(@validation_error_query, @graphql_response_json)
      assert conn.status == 422
      assert content_type(conn) == "#{@graphql_response_json}; charset=utf-8"
      assert %{"errors" => [_ | _]} = Jason.decode!(conn.resp_body)
      refute Map.has_key?(Jason.decode!(conn.resp_body), "data")
    end

    test "a document parse failure is 400" do
      conn = post(@parse_error_query, @graphql_response_json)
      assert conn.status == 400
      assert content_type(conn) == "#{@graphql_response_json}; charset=utf-8"
    end

    test "partial success (data and errors) is 294" do
      conn = post(@partial_query, @graphql_response_json)
      assert conn.status == 294
      body = Jason.decode!(conn.resp_body)
      assert body["data"] == %{"user" => nil}
      assert [_ | _] = body["errors"]
    end
  end

  describe "Accept: application/json (legacy client)" do
    test "a successful query is 200 with the application/json content type" do
      conn = post(@valid_query, @json)
      assert conn.status == 200
      assert content_type(conn) == "#{@json}; charset=utf-8"
    end

    test "partial success is 200, not 294" do
      conn = post(@partial_query, @json)
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["data"] == %{"user" => nil}
    end

    test "a validation failure is still 422" do
      conn = post(@validation_error_query, @json)
      assert conn.status == 422
    end
  end

  describe "Accept negotiation edge cases" do
    test "a missing Accept header is treated as legacy application/json" do
      conn = post(@valid_query, nil)
      assert conn.status == 200
      assert content_type(conn) == "#{@json}; charset=utf-8"
    end

    test "an unacceptable Accept header is 406 with an accept response header" do
      conn = post(@valid_query, "text/html")
      assert conn.status == 406

      assert get_resp_header(conn, "accept") == [
               "#{@graphql_response_json}; charset=utf-8, #{@json}; charset=utf-8"
             ]
    end

    test "graphql-response+json is chosen when listed ahead of application/json" do
      conn = post(@valid_query, "#{@graphql_response_json}, #{@json};q=0.9")
      assert conn.status == 200
      assert content_type(conn) == "#{@graphql_response_json}; charset=utf-8"
    end
  end

  describe "HTTP method" do
    @mutation "mutation { addItem { name } }"

    test "a mutation over GET is 405 with an Allow header" do
      conn =
        conn(:get, "/", query: @mutation)
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> put_req_header("accept", @graphql_response_json)
        |> plug_parser()
        |> Absinthe.Plug.call(opts())

      assert conn.status == 405
      assert get_resp_header(conn, "allow") == ["GET, POST"]
      assert content_type(conn) == "#{@graphql_response_json}; charset=utf-8"
    end
  end

  describe "with graphql_over_http disabled (legacy default)" do
    test "a validation failure is 200, not 422" do
      conn =
        conn(:post, "/", Jason.encode!(%{query: @validation_error_query}))
        |> put_req_header("content-type", @json)
        |> put_req_header("accept", @graphql_response_json)
        |> plug_parser()
        |> Absinthe.Plug.call(Absinthe.Plug.init(schema: TestSchema))

      assert conn.status == 200
    end
  end
end
