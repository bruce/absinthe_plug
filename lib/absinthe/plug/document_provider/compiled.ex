defmodule Absinthe.Plug.DocumentProvider.Compiled do

  @moduledoc """

  Provide pre-compiled documents for retrieval via the "id" parameter.

  ### Examples

  Define a document provider module and `use` this module:

      defmodule MyApp.Schema.Documents do
        use Absinthe.Plug.DocumentProvider.Compiled

        # ... Configure here

      end

  You can provide documents as literals within the module, by key, using the `provide/2` macro:

      provide "item", "query Item($id: ID!) { item(id: $id) { name } }"

  You can also load a map of key value pairs using `provide/1`.

      provide %{
        "item" => "query Item($id: ID!) { item(id: $id) { name } }",
        "time" => "{ currentTime }"
      }

  This can be used to support loading queries extracted using Apollo's [persistgraphql](https://github.com/apollographql/persistgraphql) tool
  by parsing the file and inverting the key/value pairs.

      provide File.read!("/path/to/extracted_queries.json")
      |> Poison.decode!
      |> Map.new(fn {k, v} -> {v, k} end)

  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Absinthe.Plug.DocumentProvider

      @before_compile {unquote(__MODULE__.Writer), :write}
      @absinthe_documents_to_compile %{}

      # Can be overridden in the document provider module
      @compilation_pipeline Absinthe.Pipeline.for_document(nil, jump_phases: false)
      |> Absinthe.Pipeline.before(Absinthe.Phase.Document.Variables)

      import unquote(__MODULE__), only: [provide: 2, provide: 1]

      def load(input, _) do
        do_load(input)
      end

      defp do_load(%{params: %{"id" => document_id}} = input) do
        case __document_provider_doc__(document_id) do
          nil ->
            {:cont, input}
          document ->
            {:halt, %{input | document: document, document_provider_key: document_id}}
        end
      end
      defp do_load(input, _) do
        {:cont, input}
      end

      @doc """
      Determine the remaining pipeline for an input with a pre-compiled
      document.

      Usually this can be changed simply by setting `@compilation_pipeline` in
      your document provider. This may need to be overridden if your compilation
      phase is not a subset of the full pipeline.
      """
      def pipeline(%{pipeline: as_configured}) do
        as_configured
        |> Absinthe.Pipeline.from(__document_provider_last_compilation_pipeline_phase__)
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
  Lookup a compiled document by id.

  ## Examples

      iex> lookup(CompiledProvider, "provided")
      #Absinthe.Blueprint<>

      iex> lookup(CompiledProvider, "not-provided")
      nil

  """
  @spec lookup(module, String.t) :: nil | Absinthe.Blueprint.t
  def lookup(compiled_document_provider, id) do
    compiled_document_provider.__document_provider_doc__(id)
  end

  @doc ~s"""
  Lookup the raw text of a compiled document by id.

  ## Examples

      iex> text(CompiledProvider, "provided")
      \"""
      query ShowItem($id: ID!) {
        item(id: $id) { name }
      }
      \"""

      iex> text(CompiledProvider, "not-provided")
      nil

  """
  @spec text(module, String.t) :: nil | String.t
  def text(compiled_document_provider, id) do
    compiled_document_provider.__document_provider_text__(id)
  end

end