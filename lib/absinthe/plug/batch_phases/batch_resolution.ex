defmodule Absinthe.Plug.Batch.BatchResolutionPhase do
  @moduledoc false

  # Merges a list of queries in the shape of [%{query_string, opts, id}, ...] into a
  # single Absinthe-executable query, to be passed to the default for_document
  # pipeline for execution.
  #
  # In order to allow us to tease apart the results once the query has been
  # executed, this module performs a few transformations:
  #
  # - Variables are renamed, from "varname" to "var_<id>_varname"
  # - Fragments are renamed, from "fragname" to "frag_<id>_fragname"
  # - Aliases are added to 
  #
  # Note that no validation occurs in this phase.

  alias Absinthe.{Blueprint, Phase}

  alias Absinthe.Phase
  use Absinthe.Phase

  @spec run([Blueprint.t], Keyword.t) :: Phase.result_t
  def run(blueprints, options \\ []) do

    all_fields = blueprints
      |> get_all_fields

    new_blueprint = %Absinthe.Blueprint{
      schema: hd(blueprints).schema,
      errors: Enum.reduce(blueprints, [], fn (bp, e) -> bp.errors ++ e end),
      operations: [
        %Absinthe.Blueprint.Document.Operation{
          current: true,
          fields: all_fields,
          name: "__merged_batch_operation",
          type: hd(hd(blueprints).operations).type,
          schema_node: hd(hd(blueprints).operations).schema_node,
        }
      ]
    }

    {:ok, resolved} = Absinthe.Phase.Document.Execution.Resolution.run(new_blueprint, options)
    result_data = resolved.resolution.result.fields

    results = for blueprint <- blueprints do
        query_id = blueprint.flags.query_id
        this_operations_results = Enum.filter(result_data, fn data ->
          data.emitter.flags.query_id == query_id
        end)

        result_object = %Absinthe.Blueprint.Document.Resolution.Object{
          fields: this_operations_results,
          emitter: get_emitter_from_results(this_operations_results),
          root_value: Keyword.get(options, :root_value, %{})
        }
        put_in(blueprint.resolution.result, result_object)
      end

    {:ok, results}
  end

  defp get_all_fields(blueprints) do
    blueprints
    |> Enum.map(&get_fields_with_query_id/1)
    |> Enum.reduce([], fn (fields, all_fields) ->
      fields ++ all_fields
    end)
  end

  defp get_fields_with_query_id(%{flags: %{query_id: query_id}, operations: operations}) do
    operation = operations
      |> Enum.find(&(&1.current))

    fields = for field <- operation.fields do
      Absinthe.Blueprint.put_flag(field, :query_id, query_id)
    end
    fields
  end

  defp get_emitter_from_results(results) do
    first_result = List.first(results)
    unless is_nil(first_result) do
      Map.get(first_result, :emitter, nil)
    else
      nil
    end
  end
end
