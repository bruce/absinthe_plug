defmodule Absinthe.Plug.DocumentProvider.Default do
  @behaviour Absinthe.Plug.DocumentProvider

  @doc false
  @spec pipeline(Absinthe.Plug.Request.t) :: Absinthe.Pipeline.t
  def pipeline(%{pipeline: as_configured}), do: as_configured

  @doc false
  @spec process(Absinthe.Plug.Request.t, Keyword.t) :: Absinthe.DocumentProvider.result
  def process(%{document: nil} = request, _), do: {:cont, request}
  def process(%{document: _} = request, _), do: {:halt, request}

end