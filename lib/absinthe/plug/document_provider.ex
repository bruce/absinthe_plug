defmodule Absinthe.Plug.DocumentProvider do
  @moduledoc """
  A document provider is a module that, given a GraphQL request, determines
  what document should be executed and how the configured pipeline should be
  applied to that document.

  ## Configuring

  Configuration of your document providers occurs on initialization of
  `Absinthe.Plug`; see that module's documentation of the `:document_providers`
  option for more details.

  ## Making Your Own

  `Absinthe.Plug.DocumentProvider` is a behaviour, and any module that
  implements its callbacks can function as a document provider for
  `Absinthe.Plug`.

  See the documentation for the behaviour callbacks and the implementation of
  the document providers that are defined in this package for more information.

  - `Absinthe.Plug.DocumentProvider.Default`
  - `Absinthe.Plug.DocumentProvider.Compiled`
  """

  @typedoc """
  The configuration for a document provider (when it needs options)
  """
  @type with_options :: {module, Keyword.t}

  @typedoc """
  A configuration for a document provider, which can take two forms:

  - `module` when options do not need to be passed to the document provider.
  - `{module, Keyword.t}` when options are needed by the document provider.
  """
  @type t :: module | with_options

  @typedoc """
  When the request is not handled by this document provider (so processing should
  continue to the next one):

      {:cont, Absinthe.Plug.Request.t}

  When the request has been processed by this document provider:

      {:halt, Absinthe.Plug.Request.t}

  Note that if no document providers set the request `document`, no document execution
  will occur and an error will be returned to the client.
  """
  @type result :: {:halt, Absinthe.Plug.Request.t} | {:cont, Absinthe.Plug.Request.t}

  @doc """
  Given a request, determine what part of its configured pipeline
  should be applied during execution.
  """
  @callback pipeline(Absinthe.Plug.Request.t) :: Absinthe.Pipeline.t

  @doc """
  Given a request, attempt to process it with this document provider.

  ## Return Types

  See the documentation for the `Absinthe.Plug.DocumentProvider.result` type.
  """
  @callback process(Absinthe.Plug.Request.t, Keyword.t) :: result

  @doc false
  @spec process([t], Absinthe.Plug.Request.t) :: {:ok, Absinthe.Plug.Request.t} | {:input_error, String.t}
  # Process an request through the given list of valid document providers and return an
  # error for the client if the request was unable to be processed.
  def process(document_providers, request) do
    document_providers
    |> normalize
    |> Enum.reduce_while(request, fn {mod, opts} = provider, acc ->
      case mod.process(acc, opts) do
        {:halt, result} ->
          {:halt, %{result | document_provider: provider}}
        cont ->
          cont
      end
    end)
    |> case do
      nil ->
        {:input_error, "No document provider could process the request"}
      request ->
        {:ok, request}
    end
  end

  @doc false
  @spec pipeline(Absinthe.Plug.Request.t) :: Absinthe.Pipeline.t
  # Determine the remaining pipeline for request, based on the associated
  # document provider.
  def pipeline(%{document_provider: {mod, _}} = request) do
    mod.pipeline(request)
  end

  # Normalize plain module references to document providers to the fully declared
  # configuration that includes a keyword list.
  @spec normalize([t]) :: [with_options]
  defp normalize(document_providers) do
    Enum.map(document_providers, &do_normalize/1)
  end

  @spec do_normalize(t) :: with_options
  defp do_normalize(config) when is_tuple(config), do: config
  defp do_normalize(config), do: {config, []}

end