defmodule Absinthe.Plug.Validation.HTTPMethod do
  @moduledoc false

  use Absinthe.Phase

  alias Absinthe.Blueprint

  @post_only [:mutation]

  def run(blueprint, options) do
    do_run(blueprint, Map.new(options))
  end

  defp do_run(blueprint, %{method: "POST"}) do
    {:ok, blueprint}
  end
  defp do_run(blueprint, _) do
    case Blueprint.current_operation(blueprint) do
      %{type: type} when type in @post_only ->
        {:error, {:http_method, "Can only perform a #{type} from a POST request"}}
      _ ->
        {:ok, blueprint}
    end
  end

end
