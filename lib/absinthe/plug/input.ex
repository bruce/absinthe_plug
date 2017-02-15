defmodule Absinthe.Plug.Input do

  import Plug.Conn

  @enforce_keys [
    :context,
    :document,
    :operation_name,
    :params,
    :root_value,
    :variables,
  ]

  defstruct [
    :context,
    :document,
    :operation_name,
    :params,
    :root_value,
    :variables,
    configured_pipeline: [],
    document: nil,
    document_provider: nil,
    document_provider_key: nil,
  ]


  @type t :: %__MODULE__{
    context: map,
    document: nil | String.t | Absinthe.Blueprint.t,
    params: map,
    operation_name: nil | String.t,
    root_value: any,
    variables: map,
    document_provider: nil | Absinthe.Plug.DocumentProvider.config_entry,
    document_provider_key: any,
    configured_pipeline: [Absinthe.Pipeline.t],
  }

  def parse(conn, config) do
    with {conn, {body, params}} <- extract_body_and_params(conn),
               {:ok, variables} <- extract_variables(params, config),
                   raw_document <- extract_raw_document(body, params),
                 operation_name <- extract_operation_name(params),
                        context <- extract_context(conn, config),
                     root_value <- extract_root_value(conn) do
      %__MODULE__{
        document: raw_document,
        params: params,
        variables: variables,
        operation_name: operation_name,
        context: context,
        root_value: root_value
      }
      |> add_configured_pipeline(conn, config)
      |> provide_document(config)
    end
  end


  #
  # BODY / PARAMS
  #

  def extract_body_and_params(%{body_params: %{"query" => _}} = conn) do
    conn = fetch_query_params(conn)
    {conn, {"", conn.params}}
  end
  def extract_body_and_params(conn) do
    case get_req_header(conn, "content-type") do
      ["application/graphql"] ->
        {:ok, body, conn} = read_body(conn)
        conn = fetch_query_params(conn)
        {conn, {body, conn.params}}
      _ ->
        {conn, {"", conn.params}}
    end
  end

  #
  # OPERATION NAME
  #

  defp extract_operation_name(params) do
    params["operationName"]
    |> decode_operation_name
  end

  # GraphQL.js treats an empty operation name as no operation name.
  defp decode_operation_name(""), do: nil
  defp decode_operation_name(name), do: name

  #
  # VARIABLES
  #

  defp extract_variables(params, %{json_codec: json_codec}) do
    Map.get(params, "variables", "{}")
    |> decode_variables(json_codec)
  end
  defp extract_variables(_, _) do
    {:error, "No json_codec available"}
  end

  defp decode_variables(%{} = variables, _), do: {:ok, variables}
  defp decode_variables("", _), do: {:ok, %{}}
  defp decode_variables("null", _), do: {:ok, %{}}
  defp decode_variables(nil, _), do: {:ok, %{}}
  defp decode_variables(variables, codec) do
    case codec.module.decode(variables) do
      {:ok, results} ->
        {:ok, results}
      _ ->
        {:input_error, "The variable values could not be decoded"}
    end
  end

  #
  # DOCUMENT
  #

  defp extract_raw_document(body, params) do
    raw_document = Map.get(params, "query", body)
    |> normalize_raw_document
  end

  defp normalize_raw_document(""), do: nil
  defp normalize_raw_document(doc), do: doc

  #
  # CONTEXT
  #

  defp extract_context(conn, config) do
    config.context
    |> Map.merge(conn.private[:absinthe][:context] || %{})
    |> Map.merge(uploaded_files(conn))
  end

  defp uploaded_files(conn) do
    files =
      conn.params
      |> Enum.filter(&match?({_, %Plug.Upload{}}, &1))
      |> Map.new

    %{
      __absinthe_plug__: %{
        uploads: files
      }
    }
  end

  #
  # ROOT VALUE
  #

  def extract_root_value(conn) do
    conn.private[:absinthe][:root_value] || %{}
  end

  #
  # DOCUMENT PROVIDERS
  #

  @doc false
  defp calculate_document_providers(config) do
    {module, fun} = config.document_providers
    apply(module, fun, [config])
  end

  def provide_document(input, config) do
    calculate_document_providers(config)
    |> Absinthe.Plug.DocumentProvider.process(input)
  end

  #
  # PIPELINE
  #

  @doc false
  def add_configured_pipeline(input, conn, config) do
    private = conn.private[:absinthe] || %{}
    private = Map.put(private, :http_method, conn.method)
    config = Map.put(config, :conn_private, private)

    simplified_input = input |> Map.from_struct |> Keyword.new

    {module, fun} = config.pipeline
    configured_pipeline = apply(module, fun, [config, simplified_input])
    %{input | configured_pipeline: configured_pipeline}
  end

end