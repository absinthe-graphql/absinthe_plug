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

  test "default_headers option works with arity 0" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema, default_headers: {__MODULE__, :graphiql_default_headers})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status

    header_json = [
      %{"name" => "Authorization", "value" => "Basic Zm9vOmJhcg=="},
      %{"name" => "X-CSRF-Token", "value" => "foobarbaz"}
    ] |> Jason.encode!(pretty: true)

    assert body |> String.contains?("defaultHeaders: " <> header_json)
  end

  test "default_headers option works with a function of arity 1" do
    token = "Zm9vOmJhcg=="
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema, default_headers: {__MODULE__, :graphiql_default_headers_with_conn})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> assign(:token, token)
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status

    header_json = [
      %{"name" => "Authorization", "value" => "Bearer Zm9vOmJhcg=="}
    ] |> Jason.encode!(pretty: true)

    assert body |> String.contains?("defaultHeaders: " <> header_json)
  end

  test "default_url option works a function of arity 0" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema,
      default_url: {__MODULE__, :graphiql_default_url})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultUrl: '#{graphiql_default_url()}'")
  end

  test "default_url option works a function of arity 1" do
    url = "http://myapp.com/graphql"
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema,
      default_url: {__MODULE__, :graphiql_default_url_with_conn})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> assign(:graphql_url, url)
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultUrl: '#{url}'")
  end

  test "default_url option works with a string" do
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

  test "socket_url option works a function of arity 0" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema,
      socket_url: {__MODULE__, :graphiql_socket_url})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultWebsocketUrl: '#{graphiql_socket_url()}'")
  end

  test "socket_url option works a function of arity 1" do
    url = "http://myapp.com/graphql"
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema,
      socket_url: {__MODULE__, :graphiql_socket_url_with_conn})

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> assign(:graphql_socket_url, url)
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultWebsocketUrl: '#{url}'")
  end

  test "socket_url option works with a string" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema,
      socket_url: graphiql_socket_url())

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultWebsocketUrl: '#{graphiql_socket_url()}'")
  end

  test "socket_url and socket unspecified" do
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema)

    assert %{status: status, resp_body: body} = conn(:get, "/")
    |> plug_parser
    |> put_req_header("accept", "text/html")
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
    assert String.contains?(body, "defaultWebsocketUrl: ''")
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason
    )
    Plug.Parsers.call(conn, opts)
  end

  def graphiql_default_headers do
    %{
      "Authorization" => "Basic Zm9vOmJhcg==",
      "X-CSRF-Token" => "foobarbaz"
    }
  end

  def graphiql_default_headers_with_conn(conn) do
    %{
      "Authorization" => "Bearer #{conn.assigns[:token]}"
    }
  end

  def graphiql_default_url, do: "https://api.foobarbaz.test"
  def graphiql_default_url_with_conn(conn), do: conn.assigns[:graphql_url]

  def graphiql_socket_url, do: "wss://socket.foobarbaz.test"
  def graphiql_socket_url_with_conn(conn), do: conn.assigns[:graphql_socket_url]
end
