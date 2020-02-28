defmodule Absinthe.Plug.Batch.Runner do
  @moduledoc false

  def run(queries, conn, config) do
    queries = Enum.with_index(queries)

    {valid_queries, invalid_queries} =
      Enum.split_with(queries, fn
        {%{prepared: {:ok, _, _}}, _} -> true
        {%{prepared: {:error, _, _}}, _} -> false
      end)

    valid_results = build_valid_results(valid_queries, config.schema_mod)
    invalid_results = build_invalid_results(invalid_queries)

    bps = restore_order(valid_results, invalid_results)
    conn = Absinthe.Plug.apply_before_send(conn, bps, config)
    results = for bp <- bps, do: bp.result
    {conn, results}
  end

  defp restore_order(valid_results, invalid_results) do
    (valid_results ++ invalid_results)
    |> Enum.sort_by(fn {i, _q} -> i end)
    |> Enum.map(fn {_i, q} -> q end)
  end

  defp build_valid_results(valid_queries, schema) do
    blueprints =
      Enum.map(valid_queries, fn
        {%{prepared: {:ok, bp, _query}}, _index} -> bp
      end)

    blueprints
    |> Absinthe.Pipeline.BatchResolver.run(schema: schema)
    |> Enum.zip(valid_queries)
    |> Enum.map(fn {bp, {query, i}} ->
      {i, build_result(bp, query)}
    end)
  end

  defp build_invalid_results(invalid_queries) do
    Enum.map(invalid_queries, fn {%{prepared: {:error, bp, _}} = query, i} ->
      {i, build_result(bp, query)}
    end)
  end

  defp build_result(bp, query) do
    case Absinthe.Pipeline.run(bp, result_pipeline(query)) do
      {:ok, bp, _} ->
        bp

      _ ->
        %{result: %{errors: ["could not produce a valid JSON result"]}}
    end
  end

  defp result_pipeline(%{pipeline: pipeline}) do
    pipeline
    |> Absinthe.Pipeline.from(Absinthe.Phase.Document.Execution.Resolution)
    |> Enum.drop(1)
  end
end
