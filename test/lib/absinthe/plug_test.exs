defmodule Absinthe.PlugTest do
  use Absinthe.Plug.TestCase
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

    assert resp_body == "Can only perform a mutation from a POST request"
  end

  @query """
  {
    item(bad) {
      name
    }
  }
  """

  test "document with error returns validation errors" do
    opts = Absinthe.Plug.init(schema: TestSchema)

    assert %{status: 400, resp_body: resp_body} = conn(:get, "/", query: @query)
    |> put_req_header("content-type", "application/x-www-form-urlencoded")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert %{"errors" => [%{"message" => _}]} = resp_body |> Poison.decode!
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
    |> put_private(:absinthe, %{root_value: %{field_on_root_value: "foo"}})
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

    test "error when no argument is given with a valid required upload", %{opts: opts} do
      query = """
      {uploadTest}
      """

      upload = %Plug.Upload{}

      assert %{status: 400, resp_body: resp_body} = conn(:post, "/", %{"query" => query, "a" => upload})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"errors" => [%{"locations" => [%{"column" => 0, "line" => 1}],
                "message" => "In argument \"fileA\": Expected type \"Upload!\", found null."}]}
    end

    test "error properly when file name is given but it isn't uploaded as well", %{opts: opts} do
      query = """
      {uploadTest(fileA: "a")}
      """

      assert %{status: 400, resp_body: resp_body} = conn(:post, "/", %{"query" => query})
      |> put_req_header("content-type", "multipart/form-data")
      |> call(opts)

      assert resp_body == %{"errors" => [%{"locations" => [%{"column" => 0, "line" => 1}], "message" => "Argument \"fileA\" has invalid value \"a\"."}]}
    end
  end

  defp basic_opts(context) do
    Map.put(context, :opts, Absinthe.Plug.init(schema: TestSchema))
  end

end
