defmodule Absinthe.Plug.GraphiQLTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Absinthe.Plug.TestSchema

  @query """
  {
    item(id: "foo") {
      name
    }
  }
  """

  test "accept: text/html works" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema)

    assert %{status: status} = conn(:post, "/", @query)
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
  end

  test "default_headers option works" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema, default_headers: {__MODULE__, :graphiql_default_headers})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status

    header_json = [
      %{"name" => "Authorization", "value" => "Basic Zm9vOmJhcg=="},
      %{"name" => "X-CSRF-Token", "value" => "foobarbaz"}
    ] |> Poison.encode!(pretty: true)

    assert body |> String.contains?("defaultHeaders: " <> header_json)
  end

  test "default_url option works" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema,
      default_url: graphiql_default_url())

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultUrl: '#{graphiql_default_url()}'")
  end

  test "default_url unspecified" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema)

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body,
      "defaultUrl: window.location.origin + window.location.pathname")
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end

  def graphiql_default_headers do
    %{
      "Authorization" => "Basic Zm9vOmJhcg==",
      "X-CSRF-Token" => "foobarbaz"
    }
  end

  def graphiql_default_url do
    "https://api.foobarbaz.test"
  end
end
