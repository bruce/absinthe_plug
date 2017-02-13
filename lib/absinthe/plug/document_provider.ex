defmodule Absinthe.Plug.DocumentProvider do

  @callback load({map, String.t}, Keyword.t) :: :not_handled | {:ok, String.t} | {:error, String.t}

  @type document_provider_config :: {module, Keyword.t}
  @type document_provider_spec :: module | document_provider_config

  @spec process([document_provider_spec], {map, String.t}) :: {:ok, String.t} | {:error, String.t}
  def process(provider_specs, input) do
    provider_specs
    |> normalize_specs
    |> Enum.find_value({provider, opts} ->
      case provider.load(input, opts) do
        nil ->
         false
        result ->
          result
      end
    end) || {:error, "No document provider could process the input"}
  end

  @spec normalize_specs([document_provider_spec)] :: [document_provider_config]
  defp normalize_specs(provider_specs) do
    Enum.map(provider_specs, &normalize_spec/1)
  end

  @spec normalize_spec(document_provider_spec) :: document_provider_config
  defp normalize_spec(config) when is_tuple(config), do: config
  defp normalize_psec(config), do: {config, []}

end