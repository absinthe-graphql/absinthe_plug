defmodule Absinthe.Plug.TransportBatchingTest do
  use ExUnit.Case, async: true
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema

  @relay_foo_result [
    %{"id" => "1", "payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{"id" => "2", "payload" => %{"data" => %{"item" => %{"name" => "Bar"}}}}
  ]

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

  @apollo_foo_result [
    %{"payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{"payload" => %{"data" => %{"item" => %{"name" => "Bar"}}}}
  ]

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
    |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body
  end

  test "single batched query in relay-network-layer format works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @relay_variable_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body
  end

  test "single batched query in apollo format works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @apollo_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    assert @apollo_foo_result == resp_body
  end

  test "single batched query in apollo format works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @apollo_variable_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    assert @apollo_foo_result == resp_body
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
    |> absinthe_plug(opts)

    assert @relay_foo_result == resp_body
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
  @fragment_query_with_undefined_field_result [
    %{"id" => "1", "payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
    %{"id" => "2", "payload" => %{"errors" => [
      %{
        "locations" => [%{"column" => 0, "line" => 7}],
        "message" => "Cannot query field \"namep\" on type \"Item\". Did you mean \"name\"?"
      }
    ]}}
  ]

  test "can include fragments with undefined fields" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query_with_undefined_field)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    assert @fragment_query_with_undefined_field_result == resp_body
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

  @fragment_query_with_undefined_variable_result [%{"id" => "1",
     "payload" => %{"data" => %{"item" => %{"name" => "Foo"}}}},
   %{"id" => "2",
     "payload" => %{"errors" => [%{"locations" => [%{"column" => 0,
             "line" => 2}],
          "message" => "In argument \"id\": Expected type \"ID!\", found null."}]}}]

  test "can include fragments with undefined variable" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query_with_undefined_variable)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    assert @fragment_query_with_undefined_variable_result == resp_body
  end

  test "it can use resolution batching across documents" do
    {:ok, pid} = Counter.start_link(0)
    opts = Absinthe.Plug.init(schema: TestSchema, context: %{counter: pid})

    payload = """
      [{
        "id": "1",
        "query": "{ pingCounter }",
        "variables": {}
      }, {
        "id": "2",
        "query": "{ pingCounter }",
        "variables": {}
      }]
      """

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", payload)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    expected = [
      %{"id" => "1", "payload" => %{"data" => %{"pingCounter" => 1}}},
      %{"id" => "2", "payload" => %{"data" => %{"pingCounter" => 1}}}
    ]

    assert expected == resp_body

    assert 1 == Counter.read(pid)
  end

  test "it can handle batches where some docs have errors" do
    {:ok, pid} = Counter.start_link(0)
    opts = Absinthe.Plug.init(schema: TestSchema, context: %{counter: pid})

    payload = """
      [{
        "id": "1",
        "query": "{asdf }",
        "variables": {}
      }, {
        "id": "2",
        "query": "{ pingCounter }",
        "variables": {"id": "bar"}
      }]
      """

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", payload)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    expected = [
      %{"id" => "1","payload" => %{"errors" => [%{"locations" => [%{"column" => 0, "line" => 1}],
        "message" => "Cannot query field \"asdf\" on type \"RootQueryType\"."}]}},
      %{"id" => "2", "payload" => %{"data" => %{"pingCounter" => 1}}}
    ]

    assert expected == resp_body

    assert 1 == Counter.read(pid)
  end

  test "it handles complexity errors" do
    opts = Absinthe.Plug.init(schema: TestSchema, max_complexity: 100, analyze_complexity: true)

    payload = """
      [{
        "id": "1",
        "query": "{ expensive }",
        "variables": {}
      }, {
        "id": "2",
        "query": "{ expensive }",
        "variables": {"id": "bar"}
      }]
      """

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", payload)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> absinthe_plug(opts)

    expected = [%{"id" => "1",
               "payload" => %{"errors" => [%{"locations" => [%{"column" => 0,
                       "line" => 1}],
                    "message" => "Field expensive is too complex: complexity is 1000 and maximum is 100"},
                  %{"locations" => [%{"column" => 0, "line" => 1}],
                    "message" => "Operation is too complex: complexity is 1000 and maximum is 100"}]}},
             %{"id" => "2",
               "payload" => %{"errors" => [%{"locations" => [%{"column" => 0,
                       "line" => 1}],
                    "message" => "Field expensive is too complex: complexity is 1000 and maximum is 100"},
                  %{"locations" => [%{"column" => 0, "line" => 1}],
                    "message" => "Operation is too complex: complexity is 1000 and maximum is 100"}]}}]

    assert expected == resp_body
  end

  defp absinthe_plug(conn, opts) do
    %{resp_body: body} = conn = Absinthe.Plug.call(conn, opts)

    case Poison.decode(body) do
      {:ok, parsed} -> %{conn | resp_body: parsed}
      _ -> conn
    end
  end
end
