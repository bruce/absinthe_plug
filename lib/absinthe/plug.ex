defmodule Absinthe.Plug do
  @moduledoc """
  A plug for using Absinthe

  See [The Guides](http://absinthe-graphql.org/guides/plug-phoenix/) for usage details

  ## Uploaded File Support

  Absinthe.Plug can be used to support uploading of files. This is a schema that
  has a mutation field supporting multiple files. Note that we have to import
  types from Absinthe.Plug.Types in order to get this scalar type:

  ```elixir
  defmodule MyApp.Schema do
    use Absinthe.Schema

    import_types Absinthe.Plug.Types

    mutation do
      field :upload_file, :string do
        arg :users, non_null(:upload)
        arg :metadata, :upload

        resolve fn args, _ ->
          args.users # this is a `%Plug.Upload{}` struct.

          {:ok, "success"}
        end
      end
    end
  end
  ```

  Next it's best to look at how one submits such a query over HTTP. You need to
  use the `multipart/form-data` content type. From there we need

  1) a `query` parameter holding out GraphQL document
  2) optional variables parameter for JSON encoded variables
  3) optional operationName parameter to specify the operation
  4) a query key for each file that will be uploaded.

  An example of using this with curl would look like:
  ```
  curl -X POST \\
  -F query="{files(users: \"users_csv\", metadata: \"metadata_json\")}" \\
  -F users_csv=@users.csv \\
  -F metadata_json=@metadata.json \\
  localhost:4000/graphql
  ```

  Note how there is a correspondance between the value of the `:users` argument
  and the `-F` form part of the associated file.

  The advantage of doing uploads this way instead of merely just putting them in
  the context is that if the file is simply in the context there isn't a way in
  the schema to mark it as required. It also wouldn't show up in the documentation
  as an argument that is required for a field.

  By treating uploads as regular arguments we get all the usual GraphQL argument
  validation.
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
    document_providers: [Absinthe.Plug.DocumentProvider.config_entry]
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
    with {:ok, input} <- Absinthe.Plug.Input.parse(conn, config),
         {:ok, input} <- ensure_document(input, config) do
      run_input(input, conn)
    else
      result ->
        {conn, result}
    end
  end

  defp ensure_document(%{document: nil}, config) do
    {:input_error, config.no_query_message}
  end
  defp ensure_document(input, _) do
    {:ok, input}
  end

  defp run_input(input, conn) do
    case Absinthe.Pipeline.run(input.document, input.configured_pipeline) do
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
  @spec default_document_providers(map) :: [Absinthe.Plug.DocumentProvider.simple_config_entry]
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
