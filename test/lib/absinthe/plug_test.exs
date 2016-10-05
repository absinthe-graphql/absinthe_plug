defmodule Absinthe.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Absinthe.Plug.TestSchema

  @foo_result ~s({"data":{"item":{"name":"Foo"}}})
  @bar_result ~s({"data":{"item":{"name":"Bar"}}})

  @variable_query """
  query FooQuery($id: ID!){
    item(id: $id) {
      name
    }
  }
  """

  @query """
  {
    item(id: "foo") {
      name
    }
  }
  """

  test "content-type application/graphql works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/graphql")
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/graphql works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, ~s(/?variables={"id":"foo"}), @variable_query)
    |> put_req_header("content-type", "application/graphql")
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/x-www-urlencoded works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/x-www-urlencoded works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, ~s(/?variables={"id":"foo"}), query: @variable_query)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/json works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @query}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/json works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @variable_query, variables: %{id: "foo"}}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/json works with empty operation name" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @query, operationName: ""}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  @mutation """
  mutation AddItem {
    addItem(name: "Baz") {
      name
    }
  }
  """

  test "mutation with get fails" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 405, resp_body: resp_body} = conn(:get, "/", query: @mutation)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == "Can only perform a mutation from a POST request"
  end

  @query """
  {
    item(bad) {
      name
    }
  }
  """

  test "document with error returns errors" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 400, resp_body: resp_body} = conn(:get, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert %{"errors" => [%{"message" => _}]} = resp_body |> Poison.decode!
  end


  @fragment_query """
  query Q {
    item(id: "foo") {
      ...Named
    }
  }
  fragment Named on Item {
    name
  }
  """

  test "can include fragments" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query)
    |> put_req_header("content-type", "application/graphql")
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  @multiple_ops_query """
  query Foo {
    item(id: "foo") {
      ...Named
    }
  }
  query Bar {
    item(id: "bar") {
      ...Named
    }
  }
  fragment Named on Item {
    name
  }
  """

  test "can select an operation by name" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: status, resp_body: resp_body} = conn(:post, "/?operationName=Foo", @multiple_ops_query)
    |> put_req_header("content-type", "application/graphql")
    |> Absinthe.Plug.call(opts)

    assert 200 == status
    assert resp_body == @foo_result

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/?operationName=Bar", @multiple_ops_query)
    |> put_req_header("content-type", "application/graphql")
    |> Absinthe.Plug.call(opts)

    assert resp_body == @bar_result
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end
end
