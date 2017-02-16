defmodule Absinthe.Plug do
  @moduledoc """
  A plug for using Absinthe

  See [The Guides](http://absinthe-graphql.org/guides/plug-phoenix/) for usage details.
  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  @type function_name :: atom

  @type opts :: [
    schema: atom,
    adapter: atom,
    path: binary,
    context: map,
    json_codec: atom | {atom, Keyword.t},
    pipeline: {Module.t, function_name},
    no_query_message: binary,
    document_providers: [Absinthe.Plug.DocumentProvider.t]
  ]

  @doc """
  Sets up and validates the Absinthe schema
  """
  @spec init(opts :: opts) :: map
  def init(opts) do
    adapter = Keyword.get(opts, :adapter)
    context = Keyword.get(opts, :context, %{})

    no_query_message = Keyword.get(opts, :no_query_message, "No query document supplied")

    pipeline = Keyword.get(opts, :pipeline, {__MODULE__, :default_pipeline})
    document_providers = Keyword.get(opts, :document_providers, {__MODULE__, :default_document_providers})

    json_codec = case Keyword.get(opts, :json_codec, Poison) do
      module when is_atom(module) -> %{module: module, opts: []}
      other -> other
    end

    schema_mod = opts |> get_schema

    %{
      adapter: adapter,
      context: context,
      document_providers: document_providers,
      json_codec: json_codec,
      no_query_message: no_query_message,
      pipeline: pipeline,
      schema_mod: schema_mod,
    }
  end

  defp get_schema(opts) do
    default = Application.get_env(:absinthe, :schema)
    schema = Keyword.get(opts, :schema, default)
    try do
      Absinthe.Schema.types(schema)
    rescue
      UndefinedFunctionError ->
        raise ArgumentError, "The supplied schema: #{inspect schema} is not a valid Absinthe Schema"
    end
    schema
  end

  @doc """
  Parses, validates, resolves, and executes the given Graphql Document
  """
  def call(conn, %{json_codec: json_codec} = config) do
    {conn, result} = conn |> execute(config)

    case result do
      {:input_error, msg} ->
        conn
        |> send_resp(400, msg)

      {:ok, %{data: _} = result} ->
        conn
        |> json(200, result, json_codec)

      {:ok, %{errors: _} = result} ->
        conn
        |> json(400, result, json_codec)

      {:error, {:http_method, text}, _} ->
        conn
        |> send_resp(405, text)

      {:error, error, _} when is_binary(error) ->
        conn
        |> send_resp(500, error)

    end
  end

  @doc false
  def execute(conn, config) do
    with {:ok, request} <- Absinthe.Plug.Request.parse(conn, config),
         {:ok, request} <- ensure_document(request, config) do
      run_request(request, conn)
    else
      result ->
        {conn, result}
    end
  end

  defp ensure_document(%{document: nil}, config) do
    {:input_error, config.no_query_message}
  end
  defp ensure_document(request, _) do
    {:ok, request}
  end

  defp run_request(request, conn) do
    case Absinthe.Pipeline.run(request.document, Absinthe.Plug.DocumentProvider.pipeline(request)) do
      {:ok, result, _} ->
        {conn, {:ok, result}}
      other ->
        {conn, other}
    end
  end

  #
  # PIPELINE
  #

  @doc false
  def default_pipeline(config, input_for_pipeline) do
    config.schema_mod
    |> Absinthe.Pipeline.for_document(input_for_pipeline)
    |> Absinthe.Pipeline.insert_after(Absinthe.Phase.Document.CurrentOperation,
      {Absinthe.Plug.Validation.HTTPMethod, method: config.conn_private.http_method}
    )
  end

  #
  # DOCUMENT PROVIDERS
  #

  @doc false
  @spec default_document_providers(map) :: [Absinthe.Plug.DocumentProvider.t]
  def default_document_providers(_) do
    [Absinthe.Plug.DocumentProvider.Default]
  end

  #
  # SERIALIZATION
  #

  @doc false
  def json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end

end
