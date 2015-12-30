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

  @result ~s({"data":{"item":{"name":"Foo"}}})

  test "content-type application/graphql works" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/graphql")
    |> AbsinthePlug.call(opts)

    assert resp_body == @result
  end

  test "content-type application/x-www-urlencoded works" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> AbsinthePlug.call(opts)

    assert resp_body == @result
  end

  test "content-type application/json works" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @query}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> AbsinthePlug.call(opts)

    assert resp_body == @result
  end

  @mutation """
  mutation AddItem {
    addItem(name: "Baz") {
      name
    }
  }
  """

  test "mutation with get fails" do
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 405, resp_body: resp_body} = conn(:get, "/", query: @mutation)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> AbsinthePlug.call(opts)

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
    opts = AbsinthePlug.init(schema: TestSchema)

    assert %{status: 400, resp_body: resp_body} = conn(:get, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-urlencoded")
    |> plug_parser
    |> AbsinthePlug.call(opts)

    assert %{"errors" => [%{"message" => _}]} = resp_body |> Poison.decode!
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
