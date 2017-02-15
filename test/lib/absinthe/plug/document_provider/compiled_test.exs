defmodule Absinthe.Plug.DocumentProvider.CompiledTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Absinthe.Plug.TestSchema

  defmodule LiteralDocuments do
    use Absinthe.Plug.DocumentProvider.Compiled

    provide "1", """
    query FooQuery($id: ID!){
      item(id: $id) {
        name
      }
    }
    """

  end

  defmodule ExtractedDocuments do
    use Absinthe.Plug.DocumentProvider.Compiled

    @fixture Path.join([File.cwd!, "test/support/fixtures/extracted_queries.json"])

    provide File.read!(@fixture)
    |> Poison.decode!
    |> Map.new(fn {k, v} -> {v, k} end)

  end

  @foo_result ~s({"data":{"item":{"name":"Foo"}}})

  test "works using documents provided as literals" do
    opts = Absinthe.Plug.init(schema: TestSchema, document_providers: {__MODULE__, :literal})

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"id" => "1", "variables" => %{"id" => "foo"}})
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  test "works using documents loaded from an extracted_queries.json" do
    opts = Absinthe.Plug.init(schema: TestSchema, document_providers: {__MODULE__, :extracted})

    assert %{status: 200, resp_body: resp_body} = conn(:post, "/", %{"id" => "1", "variables" => %{"id" => "foo"}})
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)

    assert resp_body == @foo_result
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end

  def literal(_) do
    [__MODULE__.LiteralDocuments]
  end

  def extracted(_) do
    [__MODULE__.ExtractedDocuments]
  end

end