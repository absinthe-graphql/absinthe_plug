defmodule Absinthe.Plug.DocumentProvider.CompiledTest do
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema
  alias Absinthe.Plug.DocumentProvider.Compiled

  defmodule ExtractedDocuments do
    use Absinthe.Plug.DocumentProvider.Compiled

    @fixture Path.join([File.cwd!(), "test/support/fixtures/extracted_queries.json"])

    provide(
      File.read!(@fixture)
      |> Jason.decode!()
      |> Map.new(fn {k, v} -> {v, k} end)
    )
  end

  defmodule ExtractedValueDocument do
    use Absinthe.Plug.DocumentProvider.Compiled

    @fixture Path.join([File.cwd!(), "test/support/fixtures/extracted_query.txt"])

    provide(%{
      1 => File.read!(@fixture)
    })
  end

  @query """
  query FooQuery($id: ID!) {
    item(id: $id) {
      name
    }
  }
  """
  @result ~s({"data":{"item":{"name":"Foo"}}})
  test "works using documents provided as literals" do
    opts =
      Absinthe.Plug.init(
        schema: TestSchema,
        document_providers: [Absinthe.Plug.TestLiteralDocuments]
      )

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"id" => "1", "variables" => %{"id" => "foo"}})
             |> put_req_header("content-type", "application/graphql")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert resp_body == @result
  end

  test "context passed correctly to resolvers with the default document provider" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    query = """
    query GetUser {
      user
    }
    """

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"query" => query})
             |> Absinthe.Plug.put_options(context: %{user: "Foo"})
             |> put_req_header("content-type", "application/graphql")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert resp_body == ~s({"data":{"user":"Foo"}})
  end

  test "context passed correctly to resolvers with documents provided as literals" do
    opts =
      Absinthe.Plug.init(
        schema: TestSchema,
        document_providers: [Absinthe.Plug.TestLiteralDocuments]
      )

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"id" => "2"})
             |> Absinthe.Plug.put_options(context: %{user: "Foo"})
             |> put_req_header("content-type", "application/graphql")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert resp_body == ~s({"data":{"user":"Foo"}})
  end

  test "works using documents loaded from an extracted_queries.json" do
    opts =
      Absinthe.Plug.init(schema: TestSchema, document_providers: [__MODULE__.ExtractedDocuments])

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"id" => "1", "variables" => %{"id" => "foo"}})
             |> put_req_header("content-type", "application/graphql")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert resp_body == @result
  end

  test "works using documents loaded from an extracted_query.json" do
    opts =
      Absinthe.Plug.init(
        schema: TestSchema,
        document_providers: [__MODULE__.ExtractedValueDocument]
      )

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"id" => "1", "variables" => %{"id" => "foo"}})
             |> put_req_header("content-type", "application/graphql")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert resp_body == @result
  end

  test ".get compiled" do
    assert %Absinthe.Blueprint{} = Compiled.get(Absinthe.Plug.TestLiteralDocuments, "1")

    assert %Absinthe.Blueprint{} =
             Compiled.get(Absinthe.Plug.TestLiteralDocuments, "1", :compiled)
  end

  test ".get source" do
    assert @query == Compiled.get(Absinthe.Plug.TestLiteralDocuments, "1", :source)
  end

  test "telemetry events executed", context do
    :telemetry.attach_many(
      context.test,
      [
        [:absinthe, :execute, :operation, :start],
        [:absinthe, :execute, :operation, :stop]
      ],
      fn event, measurements, metadata, config ->
        send(self(), {event, measurements, metadata, config})
      end,
      %{}
    )

    opts =
      Absinthe.Plug.init(
        schema: TestSchema,
        document_providers: [Absinthe.Plug.TestLiteralDocuments]
      )

    assert %{status: 200, resp_body: resp_body} =
             conn(:post, "/", %{"id" => "2"})
             |> Absinthe.Plug.put_options(context: %{user: "Foo"})
             |> put_req_header("content-type", "application/graphql")
             |> plug_parser
             |> Absinthe.Plug.call(opts)

    assert_receive {[:absinthe, :execute, :operation, :start], _, %{id: id}, _config}
    assert_receive {[:absinthe, :execute, :operation, :stop], measurements, %{id: ^id}, _config}

    assert is_number(measurements[:duration])

    :telemetry.detach(context.test)
  end
end
