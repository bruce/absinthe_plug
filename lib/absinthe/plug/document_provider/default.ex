defmodule Absinthe.Plug.DocumentProvider.Default do
  @behaviour Absinthe.Plug.DocumentProvider

  def load(%{document: nil} = input, _), do: {:cont, input}
  def load(%{document: doc} = input, _), do: {:halt, input}

end