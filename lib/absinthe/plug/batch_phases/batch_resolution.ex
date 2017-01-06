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
  # use Absinthe.Phase

  @spec run([Blueprint.t], Keyword.t) :: Phase.result_t
  def run(blueprints, options \\ []) do
    schema = options[:schema]

    fields_from_operations = get_and_mark_operation_fields(blueprints)

    # put things together
    grouped_blueprint = %Absinthe.Blueprint{
      schema: schema,
      operations: [
        %Absinthe.Blueprint.Document.Operation{
          current: true,
          fields: fields_from_operations,
          name: "__merged_batch_operation__",
          type: :query,
          schema_node: Absinthe.Schema.lookup_type(schema, :query),
        }
      ]
    }

    {:ok, resolved_grouped_blueprint} = Absinthe.Phase.Document.Execution.Resolution.run(grouped_blueprint, options)
    grouped_result_fields = resolved_grouped_blueprint.resolution.result.fields

    # split them back apart
    for blueprint <- blueprints do
      {query_id, _} = blueprint.flags.query_id

      this_operations_results = Enum.filter(grouped_result_fields, fn field ->
        match?({^query_id, _}, field.emitter.flags.query_id)
      end)

      operation = Absinthe.Blueprint.current_operation(blueprint)

      result_object = %Absinthe.Blueprint.Document.Resolution.Object{
        fields: this_operations_results,
        emitter: operation,
        root_value: Keyword.get(options, :root_value, %{}),
      }
      put_in(blueprint.resolution.result, result_object)
    end
  end

  defp get_and_mark_operation_fields(blueprints) do
    for blueprint <- blueprints,
    operation = Absinthe.Blueprint.current_operation(blueprint),
    field <- operation.fields do
      {query_id, _} = blueprint.flags.query_id

      Absinthe.Blueprint.put_flag(field, :query_id, {query_id, __MODULE__})
    end
  end
end
