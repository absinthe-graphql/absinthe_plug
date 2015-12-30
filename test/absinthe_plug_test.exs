defmodule AbsinthePlugTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias AbsinthePlug.TestSchema

  @query """
  {
    item(id: "foo") {
      name
    }
  }
  """

  test "content-type application/graphql works" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/graphql")
    |> AbsinthePlug.call(opts)

    assert resp_body == ~s({"data":{"item":{"name":"Foo"}}})
  end

  test "content-type application/x-www-urlencoded works" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> AbsinthePlug.call(opts)

    assert resp_body == ~s({"data":{"item":{"name":"Foo"}}})
  end

  test "content-type application/json works" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @query}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> AbsinthePlug.call(opts)

    assert resp_body == ~s({"data":{"item":{"name":"Foo"}}})
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
