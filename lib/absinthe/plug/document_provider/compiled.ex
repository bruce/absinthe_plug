defmodule Absinthe.Plug.DocumentProvider.Compiled do

  @moduledoc """

  Provide pre-compiled documents for retrieval by looking up a parameter key.

  Important: This module shouldn't be used as a document provider itself, but
  as a toolkit to build one. See the examples below.

  ### Examples

  Define a new module and `use Absinthe.Plug.DocumentProvider.Compiled`:

      defmodule MyApp.Schema.Documents do
        use Absinthe.Plug.DocumentProvider.Compiled

        # ... Configure here

      end

  You can provide documents as literals within the module, by key, using the
  `provide/2` macro:

      provide "item", "query Item($id: ID!) { item(id: $id) { name } }"

  You can also load a map of key value pairs using `provide/1`.

      provide %{
        "item" => "query Item($id: ID!) { item(id: $id) { name } }",
        "time" => "{ currentTime }"
      }

  This can be used to support loading documents extracted using Apollo's
  [persistgraphql](https://github.com/apollographql/persistgraphql) tool by
  parsing the file and inverting the key/value pairs.

      provide File.read!("/path/to/extracted_queries.json")
      |> Poison.decode!
      |> Map.new(fn {k, v} -> {v, k} end)

  By default, the request parameter that will be used to lookup documents is
  `"id"`. You can change this by passing a `:key_param` option to `use`, e.g.:

      use Absinthe.Plug.DocumentProvider.Compiled, key_param: "lookup_key"

  """

  defmacro __using__(opts) do
    key_param = Keyword.get(opts, :key_param, "id") |> to_string
    quote do
      @behaviour Absinthe.Plug.DocumentProvider

      @before_compile {unquote(__MODULE__.Writer), :write}
      @absinthe_documents_to_compile %{}

      # Can be overridden in the document provider module
      @compilation_pipeline Absinthe.Pipeline.for_document(nil, jump_phases: false)
      |> Absinthe.Pipeline.before(Absinthe.Phase.Document.Variables)

      import unquote(__MODULE__), only: [provide: 2, provide: 1]

      def process(request, _) do
        do_process(request)
      end

      defp do_process(%{params: %{unquote(key_param) => document_key}} = request) do
        case __absinthe_plug_doc__(:compiled, document_key) do
          nil ->
            {:cont, request}
          document ->
            {:halt, %{request | document: document, document_provider_key: document_key}}
        end
      end
      defp do_process(request, _) do
        {:cont, request}
      end

      @doc """
      Determine the remaining pipeline for an request with a pre-compiled
      document.

      Usually this can be changed simply by setting `@compilation_pipeline` in
      your document provider. This may need to be overridden if your compilation
      phase is not a subset of the full pipeline.
      """
      def pipeline(%{pipeline: as_configured}) do
        as_configured
        |> Absinthe.Pipeline.from(__absinthe_plug_doc__(:remaining_pipeline))
      end

      defoverridable [pipeline: 1]

    end
  end

  @doc ~s"""
  Provide a GraphQL document for a given ID.

  Note that the ID will be coerced to strings to ensure compatibility with the expected request parameter.

  For more information, see the module-level documentation.

  ## Examples

      provide "foo", \"""
        query ShowItem($id: ID!) {
          item(id: $id) { name }
        }
      \"""

  """
  @spec provide(any, String.t) :: Macro.t
  defmacro provide(id, document_text) do
    quote do
      @absinthe_documents_to_compile Map.put(@absinthe_documents_to_compile, to_string(unquote(id)), unquote(document_text))
    end
  end

  @doc ~s"""
  Provide multiple GraphQL documents by ID.

  Note that IDs will be coerced to strings to ensure compatibility with the expected request parameter.

  For more information, see the module-level documentation.

  ## Examples

      provide %{
        "item" => "query Item($id: ID!) { item(id: $id) { name } }",
        "time" => "{ currentTime }"
      }

  """
  @spec provide(%{any => String.t}) :: Macro.t
  defmacro provide(documents) do
    quote do
      @absinthe_documents_to_compile Map.merge(
        @absinthe_documents_to_compile,
        Map.new(
          unquote(documents),
          &{to_string(elem(&1, 0)), elem(&1, 1)}
        )
      )
    end
  end


  @doc """
  Lookup a document by id.

  ## Examples

  Get a compiled document:

      iex> get(CompiledProvider, "provided")
      #Absinthe.Blueprint<>

  With an explicit `:compiled` flag:

      iex> get(CompiledProvider, "provided", :compiled)
      #Absinthe.Blueprint<>

  Get the source:

      iex> get(CompiledProvider, "provided", :source)
      "query Item { item { name } }"

  When a value isn't present:

      iex> get(CompiledProvider, "not-provided")
      nil

  """
  @spec get(module, String.t, :compiled | :source) :: nil | Absinthe.Blueprint.t
  def get(dp, id, format \\ :compiled)
  def get(dp, id, :compiled) do
    dp.__absinthe_plug_doc__(:compiled, id)
  end
  def get(dp, id, :source) do
    dp.__absinthe_plug_doc__(:source, id)
  end
end