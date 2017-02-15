defmodule Absinthe.Plug.DocumentProvider.Default do
  @behaviour Absinthe.Plug.DocumentProvider

  @doc false
  @spec pipeline(Absinthe.Plug.Input.t) :: Absinthe.Pipeline.t
  def pipeline(%{pipeline: as_configured}), do: as_configured

  @doc false
  @spec load(Absinthe.Plug.Input.t, Keyword.t) :: {:cont, Absinthe.Plug.Input.t} | {:halt, Absinthe.Plug.Input.t}
  def load(%{document: nil} = input, _), do: {:cont, input}
  def load(%{document: _} = input, _), do: {:halt, input}

end