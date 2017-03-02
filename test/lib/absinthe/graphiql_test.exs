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

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end

end
