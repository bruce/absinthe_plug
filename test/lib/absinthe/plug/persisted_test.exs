defmodule Absinthe.Plug.PersistedTest do
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

  test "returns 400 with invalid variables syntax" do
    opts = Absinthe.Plug.init(schema: TestSchema)
    assert %{status: 400} = conn(:post, ~s(/?variables={invalid_syntax}), @variable_query)
    |> put_req_header("content-type", "application/graphql")
    |> plug_parser
    |> Absinthe.Plug.call(opts)
  end

  defp plug_parser(conn) do
    opts = Plug.Parsers.init(
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      json_decoder: Poison
    )
    Plug.Parsers.call(conn, opts)
  end

end