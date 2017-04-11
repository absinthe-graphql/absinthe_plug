defmodule Absinthe.Plug.Batch.Runner do

  @moduledoc false

  alias Absinthe.Plug.Request

  def run(queries, conn, config) do
    # prepared_queries = prepare(queries, conn, config)
    for query <- queries do
      Absinthe.Plug.run_query(query, conn, config)
    end
  end

  # defp prepare(queries, conn, config) do
  #   for query <- queries do
  #     query
  #     |> Request.Query.add_pipeline(conn, config)
  #   end
  # end
  #
  # defp prep_pipeline(%{pipeline: pipeline}) do
  #   query.pipeline
  #   |> Absinthe.Pipeline.before(Absinthe.Phase.Document.Execution.Resolution)
  # end
end
