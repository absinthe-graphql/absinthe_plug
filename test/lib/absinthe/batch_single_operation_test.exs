defmodule Absinthe.BatchSingleOperationTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Absinthe.Plug.TestSchema

  @foo_result ~s([{"payload":{"data":{"item":{"name":"Foo"}}},"id":"1"},{"payload":{"data":{"item":{"name":"Foo"}}},"id":"2"}])
  @bar_result ~s({"data":{"item":{"name":"Bar"}}})

  @variable_query """
  [{
    "id": "1",
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "foo"}
  }, {
    "id": "2",
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "foo"}
  }]
  """

  @query """
  [{
    "id": "1",
    "query": "query Index { item(id: \\"foo\\") { name } }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query Index { item(id: \\"foo\\") { name } }",
    "variables": {}
  }]
  """

  test "single batched query in relay-network-layer format works" do
    opts = Absinthe.Plug.BatchSingleOperation.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.BatchSingleOperation.call(opts)

    assert resp_body == @foo_result
  end

  test "single batched query in relay-network-layer format works with variables" do
    opts = Absinthe.Plug.BatchSingleOperation.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @variable_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.BatchSingleOperation.call(opts)

    assert resp_body == @foo_result
  end
  
  @mutation """
  [{
    "id": "1",
    "query": "mutation AddItem { addItem(name: \\"Baz\\") { name } }",
    "variables": {}
  }]
  """

  test "mutation with get fails" do
    opts = Absinthe.Plug.BatchSingleOperation.init(schema: TestSchema)

    assert %{status: 405, resp_body: resp_body} = conn(:get, "/", @mutation)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.BatchSingleOperation.call(opts)

    assert resp_body == "Can only perform batch queries from a POST request"
  end

  @fragment_query """
  [{
    "id": "1",
    "query": "query Q {
        item(id: \\"foo\\") {
          ...Named
        }
      }
      fragment Named on Item {
        name
      }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query P {
        item(id: \\"foo\\") {
          ...Named
        }
      }
      fragment Named on Item {
        name
      }",
    "variables": {}
  }]
  """

  test "can include fragments" do
    opts = Absinthe.Plug.BatchSingleOperation.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.BatchSingleOperation.call(opts)

    assert resp_body == @foo_result
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:json],
      pass: ["*/*"],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end
end
