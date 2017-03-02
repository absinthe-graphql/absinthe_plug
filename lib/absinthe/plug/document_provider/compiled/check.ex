defmodule Absinthe.Plug.DocumentProvider.Compiled.Check do
  @moduledoc false

  alias Absinthe.{Blueprint, Phase}

  use Absinthe.Phase

  @doc """
  Run the validation.
  """
  @spec run(Blueprint.t, Keyword.t) :: Phase.result_t
  def run(input, opts) do
    do_run(input, Map.new(opts))
  end

  @spec do_run(Blueprint.t, map) :: Phase.result_t | no_return
  def do_run(input, %{id: id, module: module}) do
    {input, errors} = Blueprint.prewalk(input, [], &handle_node/2)
    case errors do
      [] ->
        {:ok, input}
      found ->
        raise format_errors(found, id, module)
    end
  end

  # Collect the validation errors from nodes
  @spec handle_node(Blueprint.node_t, [Phase.Error.t]) :: {Blueprint.node_t, [Phase.Error.t | String.t]}
  defp handle_node(%{errors: errs} = node, acc) do
    {node, acc ++ errs}
  end
  defp handle_node(node, acc) do
    {node, acc}
  end

  defp format_errors(errors, id, module) do
    Absinthe.Plug.DocumentProvider.Compiled.Writer.error_message(
      id,
      module,
      Enum.map(errors, &format_error/1)
    )
  end

  def format_error(%{locations: [%{line: line}|_], message: message, phase: phase}) do
    "On line #{line}: #{message} (#{phase})"
  end
  def format_error(error) do
    "#{inspect(error)}"
  end

end