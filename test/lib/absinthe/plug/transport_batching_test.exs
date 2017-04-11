defmodule Absinthe.Plug.TransportBatchingTest do
  use ExUnit.Case, async: true
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema

  @relay_foo_result ~s([{"payload":{"id":"1","data":{"item":{"name":"Foo"}}}},{"payload":{"id":"2","data":{"item":{"name":"Bar"}}}}])

  @relay_variable_query """
  [{
    "id": "1",
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "foo"}
  }, {
    "id": "2",
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "bar"}
  }]
  """

  @relay_query """
  [{
    "id": "1",
    "query": "query Index { item(id: \\"foo\\") { name } }",
    "variables": {}
  }, {
    "id": "2",
    "query": "query Index { item(id: \\"bar\\") { name } }",
    "variables": {}
  }]
  """

  @apollo_foo_result ~s([{"payload":{"data":{"item":{"name":"Foo"}}}},{"payload":{"data":{"item":{"name":"Bar"}}}}])

  @apollo_variable_query """
  [{
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "foo"}
  }, {
    "query": "query FooQuery($id: ID!){ item(id: $id) { name } }",
    "variables": {"id": "bar"}
  }]
  """

  @apollo_query """
  [{
    "query": "query Index { item(id: \\"foo\\") { name } }",
    "variables": {}
  }, {
    "query": "query Index { item(id: \\"bar\\") { name } }",
    "variables": {}
  }]
  """

  # SIMPLE QUERIES
  test "single batched query in relay-network-layer format works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @relay_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @relay_foo_result
  end

  test "single batched query in relay-network-layer format works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @relay_variable_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @relay_foo_result
  end

  test "single batched query in apollo format works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @apollo_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @apollo_foo_result
  end

  test "single batched query in apollo format works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @apollo_variable_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @apollo_foo_result
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
        item(id: \\"bar\\") {
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
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @relay_foo_result
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
  @fragment_query_with_undefined_field_result ~s([{"payload":{"id":"1","data":{"item":{"name":"Foo"}}}},{"payload":{"id":"2","errors":[{"message":"Cannot query field \\\"namep\\\" on type \\\"Item\\\". Did you mean \\\"name\\\"?","locations":[{"line":7,"column":0}]}]}}])

  test "can include fragments with undefined fields" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query_with_undefined_field)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

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

  @fragment_query_with_undefined_variable_result ~s([{"payload":{"id":"1","data":{"item":{"name":"Foo"}}}},{"payload":{"id":"2","errors":[{"message":"In argument \\\"id\\\": Expected type \\\"ID!\\\", found null.","locations":[{"line":2,"column":0}]}]}}])

  test "can include fragments with undefined variable" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query_with_undefined_variable)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @fragment_query_with_undefined_variable_result
  end
end
