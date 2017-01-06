defmodule Absinthe.Plug.BatchTest do
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

  # old tests
  test "single batched query in relay-network-layer format works" do
    opts = Absinthe.Plug.Batch.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.Batch.call(opts)

    assert resp_body == @foo_result
  end

  test "single batched query in relay-network-layer format works with variables" do
    opts = Absinthe.Plug.Batch.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @variable_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.Batch.call(opts)

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
    opts = Absinthe.Plug.Batch.init(schema: TestSchema)

    assert %{status: 400, resp_body: resp_body} = conn(:get, "/", @mutation)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.Batch.call(opts)

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
    opts = Absinthe.Plug.Batch.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.Batch.call(opts)

    assert resp_body == @foo_result
  end

  @fragment_query_with_undefined_field """
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
        namep
      }",
    "variables": {}
  }]
  """
  @fragment_query_with_undefined_field_result "[{\"payload\":{\"data\":{\"item\":{\"name\":\"Foo\"}}},\"id\":\"1\"},{\"payload\":{\"errors\":[{\"message\":\"Cannot query field \\\"namep\\\" on type \\\"Item\\\". Did you mean \\\"name\\\"?\",\"locations\":[{\"line\":7,\"column\":0}]}]},\"id\":\"2\"}]"

  test "can include fragments with undefined fields" do
    opts = Absinthe.Plug.Batch.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query_with_undefined_field)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.Batch.call(opts)

    assert resp_body == @fragment_query_with_undefined_field_result
  end

  @fragment_query_with_undefined_variable """
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
    "query": "query P($id: ID!) {
        item(id: $id) {
          ...Named
        }
      }
      fragment Named on Item {
        name
      }",
    "variables": {"idx": "foo"}
  }]
  """
  @fragment_query_with_undefined_variable_result "[{\"payload\":{\"data\":{\"item\":{\"name\":\"Foo\"}}},\"id\":\"1\"},{\"payload\":{\"errors\":[{\"message\":\"In argument \\\"id\\\": Expected type \\\"ID!\\\", found null.\",\"locations\":[{\"line\":2,\"column\":0}]}]},\"id\":\"2\"}]"

  test "can include fragments with undefined variable" do
    opts = Absinthe.Plug.Batch.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query_with_undefined_variable)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.Batch.call(opts)

    assert resp_body == @fragment_query_with_undefined_variable_result
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

