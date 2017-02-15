defmodule Absinthe.Plug.DocumentProvider do

  @callback load({map, Absinthe.Plug.Input.t}, Keyword.t) :: {:cont, Absinthe.Plug.Input.t} | {:error, String.t}

  @type config_entry :: {module, Keyword.t}
  @type simple_config_entry :: module | config_entry

  @spec process([simple_config_entry], Absinthe.Plug.Input.t) :: {:ok, Absinthe.Plug.Input.t} | {:error, String.t}
  def process(provider_configs, input) do
    provider_configs
    |> normalize_configs
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

  @spec normalize_configs([simple_config_entry]) :: [config_entry]
  defp normalize_configs(provider_configs) do
    Enum.map(provider_configs, &normalize_config/1)
  end

  @spec normalize_config(simple_config_entry) :: config_entry
  defp normalize_config(config) when is_tuple(config), do: config
  defp normalize_config(config), do: {config, []}

end