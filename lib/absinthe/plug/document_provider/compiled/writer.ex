defmodule Absinthe.Plug.DocumentProvider.Compiled.Writer do

  @moduledoc false

  defmacro write(env) do
    [
      quoted_lookups(env),
      quoted_lookup_fallthrough,
      quoted_texts(env),
      quoted_text_fallthrough(),
      quoted_pipeline_tools()
    ]
  end

  @spec quoted_lookups(Macro.Env.t) :: Macro.t
  defp quoted_lookups(env) do
    docs = Module.get_attribute(env.module, :absinthe_documents_to_compile)
    compilation_pipeline = Module.get_attribute(env.module, :compilation_pipeline)
    for {id, document_text} <- docs do
      case Absinthe.Pipeline.run(document_text, compilation_pipeline) do
        {:ok, result, _} ->
          document = Macro.escape(result)
          quote do
            def __document_provider_doc__(unquote(id)), do: unquote(document)
          end
        {:error, message, _} ->
          raise ~s(Error compiling document "#{id}" for document provider #{env.module}: #{message})
      end
    end
  end

  @spec quoted_lookup_fallthrough() :: Macro.t
  defp quoted_lookup_fallthrough() do
    quote do
      def __document_provider_doc__(_), do: nil
    end
  end

  @spec quoted_texts(Macro.Env.t) :: Macro.t
  defp quoted_texts(env) do
    docs = Module.get_attribute(env.module, :absinthe_documents_to_compile)
    for {id, document_text} <- docs do
      quote do
        def __document_provider_text__(unquote(id)), do: unquote(document_text)
      end
    end
  end

  @spec quoted_text_fallthrough() :: Macro.t
  defp quoted_text_fallthrough() do
    quote do
      def __document_provider_text__(_), do: nil
    end
  end

  @spec quoted_pipeline_tools() :: Macro.t
  defp quoted_pipeline_tools() do
    quote do
      def __document_provider_last_compilation_pipeline_phase__() do
        @compilation_pipeline
        |> List.last
        |> case do
          {mod, _} ->
            mod
          mod ->
            mod
        end
      end
    end
  end

end