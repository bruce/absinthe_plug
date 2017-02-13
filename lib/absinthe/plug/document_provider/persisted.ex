defmodule Absinthe.Plug.DocumentProvider.Persisted do
  @behaviour Absinthe.Plug.DocumentProvider

  def load(params, body, opts) do
    do_load(params, body, Map.new(opts))
  end

  defp do_load(params, body, %{"id" => document_id}) do

  end
  defp do_load(_, _, _) do
    nil
  end

end