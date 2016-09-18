defmodule Absinthe.Plug.GraphiQLTest do
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
    opts = Absinthe.Plug.GraphiQL.init(schema: TestSchema)

    assert %{status: status, resp_body: msg} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.GraphiQL.call(opts)

    assert 200 == status
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
