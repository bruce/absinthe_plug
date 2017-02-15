defmodule Absinthe.Plug.DocumentProvider.Compiled do

  defmacro __using__(opts) do
    quote do
      @behaviour Absinthe.Plug.DocumentProvider

      @absinthe_documents_to_compile %{}
      @before_compile {unquote(__MODULE__), :compile_documents!}

      import unquote(__MODULE__), only: :macros

      def load(input, _) do
        do_load(input)
      end

      defp do_load(%{params: %{"id" => document_id}} = input) do
        case lookup(document_id) do
          nil ->
            {:cont, input}
          document ->
            {:halt, %{input | document: document, document_provider_key: document_id}}
        end
      end
      defp do_load(input, _) do
        {:cont, input}
      end

    end
  end

  defp compilation_pipeline() do
    Absinthe.Pipeline.for_document([])
    |> Absinthe.Pipeline.before(Absinthe.Phase.Document.Variables)
    |> List.insert_at(-1, {Absinthe.Phase.Document.Validation.Result, []})
  end

  defmacro compile_documents!(env) do
    pipeline = Module.get_attribute(env.module, :absinthe_compilation_pipeline)
    for {name, document_text} <- Module.get_attribute(env.module, :absinthe_documents_to_compile) do
      case Absinthe.Pipeline.run(document_text, pipeline) do
        {:ok, result, _} ->
          quote do
            def lookup(unquote(name)), do: unquote(result)
          end
        {:error, message} ->
          raise ~S(Error compiling document "#{name}" for module #{env.module}: #{message})
      end
    end ++ quote do
      def lookup(_), do: nil
    end
  end

  @spec provide(String.t, String.t) :: Macro.t
  defmacro provide(name, document_text) do
    quote do
      @absinthe_documents_to_compile Map.put(@absinthe_documents_to_compile, unquote(name), unquote(document_text))
    end
  end

end