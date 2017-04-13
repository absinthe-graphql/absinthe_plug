defmodule Absinthe.Plug.DocumentProviderTest do
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema

  @query """
  query FooQuery($id: ID!) {
    item(id: $id) {
      name
    }
  }
  """

  defmodule OtherDocumentProvider do
    @behaviour Absinthe.Plug.DocumentProvider

    @doc false
    @spec pipeline(Absinthe.Plug.Request.t) :: Absinthe.Pipeline.t
    def pipeline(%{pipeline: as_configured}), do: as_configured

    @doc false
    @spec process(Absinthe.Plug.Request.t, Keyword.t) :: Absinthe.DocumentProvider.result
    def process(%{document: nil} = request, _), do: {:cont, request}
    def process(%{document: _} = request, _), do: {:halt, request}
  end

  test "can process with default document providers" do
    opts = Absinthe.Plug.init(schema: TestSchema)
    assert %{status: 200} = request(opts)
  end

  test "can process with document providers specified as a list" do
    opts = Absinthe.Plug.init(schema: TestSchema, document_providers: [OtherDocumentProvider])
    assert %{status: 200} = request(opts)
  end

  test "can process with document providers specified as a single atom" do
    opts = Absinthe.Plug.init(schema: TestSchema, document_providers: OtherDocumentProvider)
    assert %{status: 200} = request(opts)
  end

  test "can process with document providers specified as a function reference" do
    opts = Absinthe.Plug.init(schema: TestSchema, document_providers: {__MODULE__, :calculate_document_providers})
    assert %{status: 200} = request(opts)
  end

  test "cannot process without any document providers" do
    opts = Absinthe.Plug.init(schema: TestSchema, document_providers: [])
    assert_raise RuntimeError, fn -> request(opts) end
  end

  defp request(opts) do
    conn(:get, "/",  %{"query" => @query, "variables" => %{"id" => "foo"}})
    |> plug_parser
    |> Absinthe.Plug.call(opts)
  end

  def calculate_document_providers(_) do
    [OtherDocumentProvider]
  end

end