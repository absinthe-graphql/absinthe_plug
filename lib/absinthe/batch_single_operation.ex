defmodule Absinthe.Plug.BatchSingleOperation do
  @moduledoc """
  Support for React-Relay-Network-Layer's batched GraphQL requests,
  to be used with https://github.com/nodkz/react-relay-network-layer.
  Consult the README of that project for detailed usage information.

  This module is a variation on Absinthe.Plug.Batch. In this module, the operations in queries
  are joined together into one operation.

  This solves the transport side of https://github.com/facebook/relay/issues/724 in practice.

  You can integrate this into your Phoenix router in combination with a
  "vanilla" Absinthe.Plug, like so:

  ```
  scope "/graphql", Absinthe do
    pipe_through [:your_favorite_auth, :other_stuff]
    get "/batch", Plug.BatchSingleOperation, schema: App.Schema
    post "/batch", Plug.BatchSingleOperation, schema: App.Schema
    get "/", Plug, schema: App.Schema
    post "/", Plug, schema: App.Schema
  end
  ```
  """

  @behaviour Plug
  import Plug.Conn
  require Logger

  @type opts :: [
    schema: atom,
    adapter: atom,
    path: binary,
    context: map,
    json_codec: atom | {atom, Keyword.t}
  ]

  @doc """
  Sets up and validates the Absinthe schema
  """
  @spec init(opts :: opts) :: map
  defdelegate init(opts), to: Absinthe.Plug

  @doc """
  Parses, validates, resolves, and executes the given Graphql Document
  """
  def call(conn, config) do
    conn
    |> execute(config)
    |> Absinthe.Plug.handle_result(config)
  end

  @doc false
  def execute(conn, config) do
    result_list = with {:ok, prepared_queries} <- prepare(conn, config),
      parsed_prepared_queries <- parse_prepared_queries(prepared_queries) do

      # put all parsed queries into one
      concatenated_selections = parsed_prepared_queries
        |> Enum.map(&get_selections_from_query/1)
        |> List.flatten
      
      concatenated_fragments = parsed_prepared_queries
        |> Enum.map(&get_fragments_from_query/1)
        |> List.flatten

      concatenated_variable_definitions = parsed_prepared_queries
        |> Enum.map(&get_variable_definitions_from_query/1)
        |> List.flatten

      joined_variables = parsed_prepared_queries
        |> Enum.reduce(%{}, fn ({_id, _doc, %{variables: variables}}, joined_variables) -> 
          Map.merge(joined_variables, variables)
        end)

      joined_doc = %Absinthe.Language.Document{
        definitions: ([
          %Absinthe.Language.OperationDefinition{
            directives: [],
            loc: %{start_line: 1},
            name: "joined_query",
            operation: :query,
            selection_set: %Absinthe.Language.SelectionSet{loc: %{end_line: 5, start_line: 1}, selections: concatenated_selections},
            variable_definitions: concatenated_variable_definitions
          },
        ] ++ concatenated_fragments),
        loc: nil
      }

      joined_absinthe_opts = %{adapter: nil, context: %{}, operation_name: "joined_query", variables: joined_variables}

      query_results = case Absinthe.run(joined_doc, config.schema_mod, joined_absinthe_opts) do
        {:ok, result} -> into_batch_format(result)
        {:error, msg} -> %{payload: %{error: msg}}
      end

      {:ok, query_results}
    end

    {conn, result_list}
  end

  defp get_operation_definition_from_doc(doc) do
    operation_definition = doc.definitions
      |> Enum.find(fn   # grab the OperationDefinition struct, not the fragments
         %Absinthe.Language.OperationDefinition{} -> true
         _ -> false
      end)
  end

  defp get_selections_from_query({_id, doc, _opts}) do
    get_operation_definition_from_doc(doc).selection_set.selections
  end

  defp get_variable_definitions_from_query({_id, doc, _opts}) do
    get_operation_definition_from_doc(doc).variable_definitions
  end

  defp get_fragments_from_query({_id, doc, _opts}) do
    doc.definitions
    |> Enum.filter(fn   # grab the Fragment structs, not the OperationDefinition
       %Absinthe.Language.Fragment{} -> true
       _ -> false
    end)
  end

  defp into_batch_format(%{data: result}) do
    result
    |> Enum.map(fn {full_alias, field_value} ->
      [original_id, field_name, old_alias] = full_alias
        |> String.split("-", parts: 3)

      data = if String.length(old_alias) > 0 do
        %{old_alias => field_value}
      else
        %{field_name => field_value}
      end

      %{payload: %{data: data}, id: original_id}
    end)
  end

  @doc false
  def prepare(conn, config) do
    with "POST" <- conn.method, queries <- conn.params["_json"] do
      Logger.debug("""
      Batched GraphQL Documents:
      #{inspect(queries)}
      """)

      prepared_queries = case queries do
        nil -> [{:input_error, "No queries found"}]
        queries -> Enum.map(queries, &prepare_query(conn, config, &1))
      end

      prepared_queries
      |> Enum.filter_map(fn
        {:ok, _, _, _} -> false
        {_, _msg} -> true
      end, fn {_, msg} -> msg end)
      |> case do
        [] -> {:ok, prepared_queries}
        msgs -> {:input_error, Enum.join(msgs, "; ")}
      end
    else
      "GET" -> {:http_error, "Can only perform batch queries from a POST request"}
    end
  end

  defp prepare_query(conn, config, %{"query" => query, "variables" => variables, "id" => id}) do
    with {:ok, operation_name} <- get_operation_name(query),
    {:ok, _doc} <- validate_input(query) do
      renamed_variables = variables
        |> Enum.map(fn {var_name, var_val} -> {"var" <> id <> var_name, var_val} end)
        |> Enum.into(%{})
      query_with_renamed_variables = variables
        |> Enum.reduce(query, fn ({var_name, _}, q) ->
          String.replace(q, "$" <> var_name, "$var" <> id <> var_name)
        end)

      absinthe_opts = %{
        variables: renamed_variables,
        adapter: config.adapter,
        context: Map.merge(config.context, conn.private[:absinthe][:context] || %{}),
        operation_name: operation_name
      }

      {:ok, id, query_with_renamed_variables, absinthe_opts}
    end
  end

  def parse_prepared_queries(prepared_queries) do
    prepared_queries
    |> Enum.map(fn {:ok, id, query, absinthe_opts} ->
      with {:ok, doc} <- Absinthe.parse(query) do
        doc = doc
          |> add_alias(id)
          |> rename_fragments(id)

        {id, doc, absinthe_opts}
      end
    end)
  end

  defp add_alias(doc, id) do
    # Takes the top-level fields and gives them an alias starting with the query
    # id. This is so we can later identify which of the resolved fields belong
    # to which query. The exact alias will be "id-fieldname-oldalias".
    {operation_definition, index} = doc.definitions
      |> Enum.with_index
      |> Enum.find_value(fn   # grab the OperationDefinition struct, not the fragments
         {%Absinthe.Language.OperationDefinition{}=d, i} -> {d, i}
         _ -> false
      end)

    updated_selections = operation_definition.selection_set.selections
      |> Enum.map(fn selection -> 
        old_alias = selection.alias || ""
        new_alias = id <> "-" <> selection.name <> "-" <> old_alias
        Map.put(selection, :alias, new_alias)
      end)

    updated_operation_definition = put_in(
      operation_definition,
      [Access.key(:selection_set), Access.key(:selections)],
      updated_selections)

    put_in(doc, [Access.key(:definitions), Access.at(index)], updated_operation_definition)
  end

  defp rename_fragments(doc, id) do
    # This traverses the selection_set.selections in the OperationDefinition and
    # all of the Absinthe.Language.Fragments and renames each fragment to "id-fragmentname".
    # It also does so with all references to Fragments (i.e.
    # Absinthe.Language.FragmentSpread).

    {[operation_definition], fragments} = doc.definitions
      |> Enum.partition(fn
        %Absinthe.Language.OperationDefinition{} -> true
        _ -> false
      end)

    updated_operation_definition = operation_definition
      |> rename_fragment_spreads(id)
    updated_fragments = fragments
      |> Enum.map(&(rename_fragment(&1, id)))
      |> Enum.map(&(rename_fragment_spreads(&1, id)))

    doc
    |> put_in([Access.key(:definitions)], [updated_operation_definition | updated_fragments])
  end

  defp rename_fragment_spreads(%{selection_set: %{selections: _selections}}=field, id) do
    update_in(field, [Access.key(:selection_set), Access.key(:selections), Access.all()], fn
      %Absinthe.Language.FragmentSpread{} = fs -> Map.put(fs, :name, id <> "-frag-" <> fs.name)
      sub_field -> rename_fragment_spreads(sub_field, id)
    end)
  end
  defp rename_fragment_spreads(%{selection_set: nil}=field, _id), do: field

  defp rename_fragment(%{name: name}=fragment, id) do
    put_in(fragment, [Access.key(:name)], id <> "-frag-" <> name)
  end

  defp validate_input(nil), do: {:input_error, "No query document supplied"}
  defp validate_input(""), do: {:input_error, "No query document supplied"}
  defp validate_input(doc), do: {:ok, doc}

  defp get_operation_name(query) do
    ~r"(query|subscription|mutation)\s+(\w+)\s*(\(|\{)"
    |> Regex.scan(query, capture: :all_but_first)
    |> hd
    |> case do
      [_, operation_name, _] -> {:ok, operation_name}
      _ -> {:input_error, "Invalid operation name"}
    end
  end

  @doc false
  def json(conn, status, body, json_codec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_codec.module.encode!(body, json_codec.opts))
  end
end
