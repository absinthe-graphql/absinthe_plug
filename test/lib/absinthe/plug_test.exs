defmodule Absinthe.PlugTest do
  use Absinthe.Plug.TestCase
  alias Absinthe.Plug.TestSchema
  alias Absinthe.Plug.TestPubSub

  @foo_result ~s({"data":{"item":{"name":"Foo"}}})
  @bar_result ~s({"data":{"item":{"name":"Bar"}}})

  @variable_query """
  query FooQuery($id: ID!){
    item(id: $id) {
      name
    }
  }
  """

  test "returns 400 with invalid variables syntax" do
    opts = Absinthe.Plug.init(schema: TestSchema)
    assert %{status: 400} = conn(:post, ~s(/?variables={invalid_syntax}), @variable_query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)
  end

  @query """
  {
    item(id: "foo") {
      name
    }
  }
  """

  test "content-type application/graphql works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/graphql works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, ~s(/?variables={"id":"foo"}), @variable_query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/x-www-form-urlencoded works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/x-www-form-urlencoded works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, ~s(/?variables={"id":"foo"}), query: @variable_query)
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/json works" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @query}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/json works with variables" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @variable_query, variables: %{id: "foo"}}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "content-type application/json works with empty operation name" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: @query, operationName: ""}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  @mutation """
  mutation AddItem {
    addItem(name: "Baz") {
      name
    }
  }
  """

  test "mutation with get fails" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 405, resp_body: resp_body} = conn(:get, "/", query: @mutation)
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    message = "Can only perform a mutation from a POST request"
    assert %{"errors" => [%{"message" => ^message}]} = resp_body |> Poison.decode!
  end

  @query """
  {
    item(bad) {
      name
    }
  }
  """

  test "empty document returns :no_query_message" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 400, resp_body: resp_body} = conn(:get, "/", query: "")
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    message = opts[:no_query_message]
    assert %{"errors" => [%{"message" => ^message}]} = resp_body |> Poison.decode!
  end

  test "document with error returns validation errors" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:get, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert %{"errors" => [%{"message" => _}]} = resp_body |> Poison.decode!
  end

  @complex_query """
  query ComplexQuery {
      complex
  }
  """

  test "document with too much complexity returns analysis errors" do
    opts = Absinthe.Plug.init(schema: TestSchema, analyze_complexity: true, max_complexity: 99)

    assert %{status: 200, resp_body: resp_body} = conn(:get, "/", query: @complex_query)
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert %{"errors" => [%{"message" => "Field complex is too complex" <> _} | _]} = resp_body |> Poison.decode!
  end

  @query """
  {
    item(id: "foo") {
      name
    }
  }
  """
  test "Handle an accidentally double encoded JSON body" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    double_encoded_query =
    %{query: @query}
    |> Poison.encode!()
    |> Poison.encode!()

    assert %{status: 400} = conn(:post, "/", double_encoded_query)
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.call(opts)
  end

  @fragment_query """
  query Q {
    item(id: "foo") {
      ...Named
    }
  }
  fragment Named on Item {
    name
  }
  """

  test "can include fragments" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", @fragment_query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  @multiple_ops_query """
  query Foo {
    item(id: "foo") {
      ...Named
    }
  }
  query Bar {
    item(id: "bar") {
      ...Named
    }
  }
  fragment Named on Item {
    name
  }
  """

  test "can select an operation by name" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: status, resp_body: resp_body} = conn(:post, "/?operationName=Foo", @multiple_ops_query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert 200 == status
    assert resp_body == @foo_result

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/?operationName=Bar", @multiple_ops_query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @bar_result
  end

  test "it can use the root value" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    query = "{field_on_root_value}"

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", Poison.encode!(%{query: query, operationName: ""}))
    |> put_req_header("content-type", "application/json")
    |> plug_parser
    |> Absinthe.Plug.put_options(root_value: %{field_on_root_value: "foo"})
    |> Absinthe.Plug.call(opts)

    assert resp_body == "{\"data\":{\"field_on_root_value\":\"foo\"}}"
  end

  describe "file uploads" do
    setup [:basic_opts]

    test "work with a valid required upload", %{opts: opts} do
      query = """
      {uploadTest(fileA: "a")}
      """

      upload = %Plug.Upload{}

      assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"query" => query, "a" => upload})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"data" => %{"uploadTest" => "file_a"}}
    end

    test "work with multiple uploads", %{opts: opts} do
      query = """
      {uploadTest(fileA: "a", fileB: "b")}
      """

      upload = %Plug.Upload{}

      assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"query" => query, "a" => upload, "b" => upload})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"data" => %{"uploadTest" => "file_a, file_b"}}
    end

    test "work with variables", %{opts: opts} do
      query = """
      query ($auth: String){uploadTest(fileA: "a", fileB: "b", auth: $auth)}
      """

      upload = %Plug.Upload{}
      variables = Poison.encode!(%{auth: "foo"})
      assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"query" => query, "a" => upload, "b" => upload, "variables" => variables})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"data" => %{"uploadTest" => "auth, file_a, file_b"}}
    end

    test "error when no argument is given with a valid required upload", %{opts: opts} do
      query = """
      {uploadTest}
      """

      upload = %Plug.Upload{}

      assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"query" => query, "a" => upload})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"errors" => [%{"locations" => [%{"column" => 0, "line" => 1}],
                "message" => "In argument \"fileA\": Expected type \"Upload!\", found null."}]}
    end

    test "error properly when file name is given but it isn't uploaded as well", %{opts: opts} do
      query = """
      {uploadTest(fileA: "a")}
      """

      assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"query" => query})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"errors" => [%{"locations" => [%{"column" => 0, "line" => 1}], "message" => "Argument \"fileA\" has invalid value \"a\"."}]}
    end

    test "file upload works with null input", %{opts: opts} do
      query = """
      {uploadTest(fileB: null, fileA: "a")}
      """

      upload = %Plug.Upload{}

      assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{
        "query" => query,
        "a" => upload
      })
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"data" => %{"uploadTest" => "file_a, file_b"}}
    end
  end

  test "it works with basic documents and complexity limits" do
    opts = Absinthe.Plug.init(schema: TestSchema, max_complexity: 100, analyze_complexity: true)

    query = "{expensive}"

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"query" => query})
    |> put_req_header("content-type", "multipart/form-data")
    |> call(opts)

    expected = %{"errors" => [%{"locations" => [%{"column" => 0, "line" => 1}],
                 "message" => "Field expensive is too complex: complexity is 1000 and maximum is 100"},
               %{"locations" => [%{"column" => 0, "line" => 1}],
                 "message" => "Operation is too complex: complexity is 1000 and maximum is 100"}]}

    assert expected == resp_body
  end

  test "Subscriptions over HTTP with Server Sent Events chunked response" do
    TestPubSub.start_link
    Absinthe.Subscription.start_link(TestPubSub)

    query = "subscription {update}"
    opts = Absinthe.Plug.init(schema: TestSchema, pubsub: TestPubSub)
    request =
      Task.async(fn ->
        conn(:post, "/", query: query)
        |> put_req_header("content-type", "application/json")
        |> plug_parser
        |> Absinthe.Plug.call(opts)
      end)

    Process.sleep(200)
    Absinthe.Subscription.publish(TestPubSub, "FOO", update: "*")
    Absinthe.Subscription.publish(TestPubSub, "BAR", update: "*")
    send request.pid, :close

    conn = Task.await(request)
    {_module, state} = conn.adapter
    events =
      state.chunks
      |> String.split
      |> Enum.map(&Poison.decode!/1)

    assert length(events) == 2
    assert Enum.member?(events, %{"data" => %{"update" => "FOO"}})
    assert Enum.member?(events, %{"data" => %{"update" => "BAR"}})
  end

  describe "put_options/2" do
    test "with a pristine connection it sets the values as provided" do
      conn =
        conn(:post, "/")
        |> Absinthe.Plug.put_options(context: %{current_user: %{id: 1}})

      assert conn.private.absinthe.context.current_user.id == 1
    end

    test "sets multiple values at once" do
      conn =
        conn(:post, "/")
        |> Absinthe.Plug.put_options(root_value: %{field_on_root_value: "foo"}, context: %{current_user: %{id: 1}})

      assert conn.private.absinthe.context.current_user.id == 1
      assert conn.private.absinthe.root_value.field_on_root_value == "foo"
    end

    test "doesn't wipe out previously set options if called twice" do
      conn =
        conn(:post, "/")
        |> Absinthe.Plug.put_options(root_value: %{field_on_root_value: "foo"})
        |> Absinthe.Plug.put_options(context: %{current_user: %{id: 1}})

      assert conn.private.absinthe.context.current_user.id == 1
      assert conn.private.absinthe.root_value.field_on_root_value == "foo"
    end
  end

  test "before_send with single query" do
    opts = Absinthe.Plug.init(schema: TestSchema, before_send: {__MODULE__, :test_before_send})

    assert %{status: 200} = conn = conn(:post, "/", "{item(id: 1) { name }}")
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert_receive({:before_send, val})

    assert %Absinthe.Blueprint{} = val
    assert conn.private[:user_id] == 1
  end

  def test_before_send(conn, val) do
    send self(), {:before_send, val} # just for easy testing
    conn
    |> put_private(:user_id, 1)
  end

  defp basic_opts(context) do
    Map.put(context, :opts, Absinthe.Plug.init(schema: TestSchema))
  end

end
