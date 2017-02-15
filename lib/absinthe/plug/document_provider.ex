defmodule Absinthe.Plug.DocumentProvider do

  @callback pipeline(Absinthe.Plug.Input.t) :: Absinthe.Pipeline.t
  @callback load({map, Absinthe.Plug.Input.t}, Keyword.t) :: {:cont, Absinthe.Plug.Input.t} | {:error, String.t}

  @type with_options :: {module, Keyword.t}
  @type t :: module | with_options

  @spec process([t], Absinthe.Plug.Input.t) :: {:ok, Absinthe.Plug.Input.t} | {:input_error, String.t}
  def process(document_providers, input) do
    document_providers
    |> normalize
    |> Enum.reduce_while(input, fn {mod, opts} = provider, acc ->
      case mod.load(acc, opts) do
        {:halt, result} ->
          {:halt, %{result | document_provider: provider}}
        cont ->
          cont
      end
    end)
    |> case do
      nil ->
        {:input_error, "No document provider could process the input"}
      input ->
        {:ok, input}
    end
  end

  @doc """
  Determine the remaining pipeline for input, based on the associated document provider.
  """
  @spec pipeline(Absinthe.Plug.Input.t) :: Absinthe.Pipeline.t
  def pipeline(%{document_provider: {mod, _}} = input) do
    mod.pipeline(input)
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